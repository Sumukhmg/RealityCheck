import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
    );

    final androidImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Store a notification in Firestore for the feed
  static Future<void> storeNotification({
    required String message,
    required String type, // 'personal' or 'group'
    bool isWarning = false,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .add({
      'message': message,
      'type': type,
      'is_warning': isWarning,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> showBrutalistWarning(int thresholdPercent, int remainingMinutes) async {
    if (!_initialized) await initialize();

    String title;
    String body;

    if (thresholdPercent <= 0) {
      title = "FAILURE IMMINENT.";
      body = "0 MINUTES REMAINING. YOU HAVE LOST CONTROL.";
      _triggerMassiveVibration();
    } else {
      title = "$thresholdPercent% HUMANITY REMAINING.";
      body = "$remainingMinutes MINUTES UNTIL SYSTEM LOCK. REDUCE FEED INTAKE.";
    }

    // Store to Firestore feed
    await storeNotification(
      message: thresholdPercent <= 0
          ? "You hit 0%. FAILURE."
          : "$thresholdPercent% humanity remaining. $remainingMinutes min left.",
      type: 'personal',
      isWarning: thresholdPercent <= 20,
    );

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'reality_check_alerts',
      'Reality Check Integrity Alerts',
      channelDescription: 'Critical alerts for screen time limits.',
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      playSound: true,
      color: Color(0xFFFF4500),
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      id: thresholdPercent,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  /// Seed some sample personal + group notifications for testing
  static Future<void> seedNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final personalMessages = [
      {'msg': 'You hit 80% humanity remaining. 24 min left.', 'warn': false},
      {'msg': '60% humanity remaining. 18 min left.', 'warn': false},
      {'msg': '40% humanity remaining. 12 min left.', 'warn': true},
      {'msg': '20% humanity remaining. 6 min left.', 'warn': true},
      {'msg': 'FAILURE. You exceeded your limit.', 'warn': true},
      {'msg': 'You earned PRIME HUMAN status yesterday.', 'warn': false},
      {'msg': 'Personal streak extended to 5 DAYS.', 'warn': false},
    ];

    final groupMessages = [
      {'msg': 'Group streak reset. Reason: PRAMODH.', 'warn': true},
      {'msg': 'AGENT 5913 joined the squad.', 'warn': false},
      {'msg': 'AGENT 1024 exceeded limit by 42 min.', 'warn': true},
      {'msg': 'Group integrity dropped to 54%.', 'warn': true},
      {'msg': 'AGENT 2077 earned SAINT status.', 'warn': false},
      {'msg': 'New weekly record: avg 3.2 HRS.', 'warn': false},
      {'msg': 'AGENT 3301 revoked permissions. COWARD.', 'warn': true},
    ];

    final batch = FirebaseFirestore.instance.batch();
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications');

    for (int i = 0; i < personalMessages.length; i++) {
      final ref = col.doc();
      batch.set(ref, {
        'message': personalMessages[i]['msg'],
        'type': 'personal',
        'is_warning': personalMessages[i]['warn'],
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: i + 1))),
      });
    }

    for (int i = 0; i < groupMessages.length; i++) {
      final ref = col.doc();
      batch.set(ref, {
        'message': groupMessages[i]['msg'],
        'type': 'group',
        'is_warning': groupMessages[i]['warn'],
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: i + 1, minutes: 30))),
      });
    }

    await batch.commit();
  }

  static void _triggerMassiveVibration() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 1000]);
    }
  }
}

