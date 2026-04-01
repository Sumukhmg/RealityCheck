"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.evaluateStreaks = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();
/**
 * Midnight Cron Job that runs daily to evaluate group streaks and personal streaks.
 * Timezone: Automatically handles the "midnight", but usually scheduled in a specific timezone like 'America/New_York'.
 */
exports.evaluateStreaks = functions.pubsub.schedule("0 0 * * *").timeZone("America/New_York").onRun(async (context) => {
    var _a, _b, _c;
    const now = new Date();
    // Usually you would query logs for "yesterday"
    const yesterday = new Date(now);
    yesterday.setDate(yesterday.getDate() - 1);
    const dateStr = `${yesterday.getFullYear()}-${String(yesterday.getMonth() + 1).padStart(2, '0')}-${String(yesterday.getDate()).padStart(2, '0')}`;
    const groupsSnapshot = await db.collection("groups").get();
    for (const groupDoc of groupsSnapshot.docs) {
        const groupData = groupDoc.data();
        const members = groupData.members || [];
        let groupFailed = false;
        let failingMemberName = "";
        let excessMinutes = 0;
        let minMinutes = 99999;
        let dailySaintUid = "";
        const memberCounts = members.length;
        for (const uid of members) {
            // Fetch user profile
            const userRef = db.collection("users").doc(uid);
            const userSnap = await userRef.get();
            if (!userSnap.exists)
                continue;
            const userData = userSnap.data();
            const currentLimit = (userData === null || userData === void 0 ? void 0 : userData.current_limit) || 120;
            const nextDayLimit = (userData === null || userData === void 0 ? void 0 : userData.next_day_limit) || currentLimit;
            // Fetch their log for yesterday
            const logRef = userRef.collection("daily_logs").doc(dateStr);
            const logSnap = await logRef.get();
            let minutesUsed = 0;
            if (logSnap.exists) {
                minutesUsed = ((_a = logSnap.data()) === null || _a === void 0 ? void 0 : _a.minutes_used) || 0;
            }
            // Track Daily Saint
            if (minutesUsed < minMinutes) {
                minMinutes = minutesUsed;
                dailySaintUid = uid;
            }
            let updateData = {
                current_limit: nextDayLimit,
                has_locked_next_day: false,
            };
            if (minutesUsed > currentLimit && currentLimit > 0) {
                // Failed personal streak! (Only fail if they actually had an active limit)
                groupFailed = true;
                failingMemberName = (userData === null || userData === void 0 ? void 0 : userData.username) || "Unknown";
                excessMinutes = minutesUsed - currentLimit;
                updateData.personal_streak = 0;
            }
            else if (currentLimit > 0) {
                // Succeeded personal streak!
                const currentStreak = (userData === null || userData === void 0 ? void 0 : userData.personal_streak) || 0;
                updateData.personal_streak = currentStreak + 1;
            }
            // Apply all daily reset changes to the user document in one call
            await userRef.update(updateData);
        }
        // Award Daily Saint (only if >= 2 members)
        if (memberCounts >= 2 && dailySaintUid) {
            const saintRef = db.collection("users").doc(dailySaintUid);
            const saintSnap = await saintRef.get();
            const currentSaintDays = ((_b = saintSnap.data()) === null || _b === void 0 ? void 0 : _b.days_at_num1) || 0;
            await saintRef.update({ days_at_num1: currentSaintDays + 1 });
        }
        // Weekly Reset (Sunday Midnight)
        if (now.getDay() === 0) { // Sunday
            let weeklyMinAvg = 99999;
            let weeklySaintUid = "";
            for (const uid of members) {
                const logs = await db.collection("users").doc(uid).collection("daily_logs")
                    .orderBy("date", "desc")
                    .limit(7)
                    .get();
                let total = 0;
                logs.forEach(l => total += (l.data().minutes_used || 0));
                const avg = total / 7;
                if (avg < weeklyMinAvg) {
                    weeklyMinAvg = avg;
                    weeklySaintUid = uid;
                }
            }
            if (memberCounts >= 2 && weeklySaintUid) {
                const wSaintRef = db.collection("users").doc(weeklySaintUid);
                const wSaintSnap = await wSaintRef.get();
                const currentWeeks = ((_c = wSaintSnap.data()) === null || _c === void 0 ? void 0 : _c.weeks_at_num1) || 0;
                await wSaintRef.update({ weeks_at_num1: currentWeeks + 1 });
            }
        }
        if (groupFailed) {
            // Wall of Shame!
            await groupDoc.ref.update({ collective_streak: 0 });
            const payload = {
                notification: {
                    title: "STREAK DEAD.",
                    body: `Group Streak Dead. ${failingMemberName.toUpperCase()} spent ${excessMinutes} mins too long.`,
                },
            };
            await admin.messaging().sendToTopic(`group_${groupDoc.id}`, payload);
        }
        else {
            // Group Succeeded!
            const currentGroupStreak = groupData.collective_streak || 0;
            await groupDoc.ref.update({ collective_streak: currentGroupStreak + 1 });
            const payload = {
                notification: {
                    title: "YOU SURVIVED.",
                    body: `Group Streak is now ${currentGroupStreak + 1}.`,
                },
            };
            await admin.messaging().sendToTopic(`group_${groupDoc.id}`, payload);
        }
    }
    console.log("Streak evaluation completed for all groups.");
    return null;
});
//# sourceMappingURL=index.js.map