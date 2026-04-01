import 'package:flutter/services.dart';

class UsageStatsService {
  static const MethodChannel _channel = MethodChannel('com.sumukhmg.realitycheck/usagestats');

  /// Requests the user to grant Usage Access Permission
  Future<void> requestUsagePermission() async {
    try {
      await _channel.invokeMethod('requestUsagePermission');
    } on PlatformException catch (_) {
      print("Failed to request permission.");
    }
  }

  /// Checks if Usage Access Permission is granted.
  /// Used for Anti-Cheat monitoring.
  Future<bool> checkUsagePermission() async {
    try {
      final bool hasPermission = await _channel.invokeMethod('checkUsagePermission');
      return hasPermission;
    } on PlatformException catch (_) {
      print("Failed to check permission.");
      return false;
    }
  }

  /// Retrieves today's total foreground usage time in minutes.
  Future<int> getTodayUsageMinutes() async {
    try {
      final int minutes = await _channel.invokeMethod('getTodayUsage');
      return minutes;
    } on PlatformException catch (_) {
      print("Failed to get usage.");
      return 0;
    }
  }
}
