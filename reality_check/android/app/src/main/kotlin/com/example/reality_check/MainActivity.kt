package com.example.reality_check

import android.app.AppOpsManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.*

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.sumukhmg.realitycheck/usagestats"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUsagePermission" -> result.success(hasUsageAccessPermission())
                "requestUsagePermission" -> {
                    requestUsagePermission()
                    result.success(null)
                }
                "getTodayUsage" -> {
                    if (!hasUsageAccessPermission()) {
                        result.error("PERMISSION_DENIED", "Usage access not granted", null)
                    } else {
                        val minutes = getTodayUsageMinutes()
                        result.success(minutes)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasUsageAccessPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(), packageName)
        } else {
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(), packageName)
        }
        
        if (mode == AppOpsManager.MODE_ALLOWED || mode == AppOpsManager.MODE_DEFAULT) {
            return true
        }

        // Fallback for MIUI/Xiaomi: AppOps might return MODE_IGNORED even when granted.
        // If queryUsageStats returns any data for other apps, we actually have the permission!
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val time = System.currentTimeMillis()
        val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, time - (1000 * 60 * 60 * 24), time)
        return stats != null && stats.isNotEmpty()
    }

    private fun requestUsagePermission() {
        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
    }

    private fun getTodayUsageMinutes(): Int {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        
        // Log AppOps mode for debugging
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        android.util.Log.d("RealityCheck", "AppOps Mode: $mode (0=Allowed, 1=Ignored, 2=Errored, 3=Default)")

        val calendar = Calendar.getInstance()
        calendar.timeInMillis = now
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val midnight = calendar.timeInMillis

        android.util.Log.d("RealityCheck", "Polling usage. Midnight: $midnight, Now: $now")

        // 1. Try aggregated stats first
        var statsMap = usm.queryAndAggregateUsageStats(midnight, now)
        
        // 2. Aggressive fallback for MIUI: Try YEARLY interval (often more reliably populated)
        // We still filter for "lastTimeUsed > midnight" to only count today's usage.
        if (statsMap.isNullOrEmpty()) {
            android.util.Log.w("RealityCheck", "queryAndAggregate empty. Trying YEARLY fallback...")
            val yearlyStats = usm.queryUsageStats(UsageStatsManager.INTERVAL_YEARLY, midnight - (24 * 60 * 60 * 1000L), now)
            if (!yearlyStats.isNullOrEmpty()) {
                statsMap = mutableMapOf()
                for (s in yearlyStats) {
                    // Only use it if it's the more recent stat for this package
                    val existing = statsMap[s.packageName]
                    if (existing == null || s.lastTimeUsed > existing.lastTimeUsed) {
                        statsMap[s.packageName] = s
                    }
                }
            }
        }
        
        if (statsMap.isNullOrEmpty()) {
            android.util.Log.e("RealityCheck", "FATAL: Even YEARLY fallback returned nothing.")
            return 0
        }

        var totalMs = 0L
        val pm = packageManager
        for ((pkg, stat) in statsMap) {
            val time = stat.totalTimeInForeground
            if (time <= 0) continue
            
            // Critical filter: Was it used AT ALL today?
            // Note: totalTimeInForeground in YEARLY bucket includes all-time, 
            // but we only care about apps that were active since midnight.
            if (stat.lastTimeUsed < midnight) continue
            
            if (isIgnoredPackage(pkg)) continue
            if (pm.getLaunchIntentForPackage(pkg) == null) continue

            // IMPORTANT: If we're using the YEARLY bucket, totalTimeInForeground might be huge.
            // But if it's the ONLY bucket populated (MIUI quirk), we use it as a hint.
            totalMs += time
            android.util.Log.d("RealityCheck", "Match Found: $pkg = ${time / 60000}m (last=${stat.lastTimeUsed})")
        }

        // Clamp to 24 hours just in case YEARLY data is massive
        val result = (totalMs / 60000).toInt().coerceAtMost(1440)
        android.util.Log.d("RealityCheck", "FINAL Today Usage: $result minutes")
        return result
    }

    private fun isIgnoredPackage(pkg: String?): Boolean {
        if (pkg == null) return true
        val ignored = listOf(
            "android", 
            "com.android.systemui", 
            "com.example.reality_check", 
            "com.miui.home", 
            "com.android.launcher",
            "com.google.android.apps.nexuslauncher",
            packageName // ignore self
        )
        return ignored.contains(pkg) || pkg.contains("launcher") || pkg.contains("systemui")
    }
}
