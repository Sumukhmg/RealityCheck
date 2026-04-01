import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String username;
  final int personalStreak;
  final int currentLimit; // in minutes
  final int nextDayLimit; // in minutes
  final bool isDark;
  final bool hasLockedNextDay;
  final DateTime? createdAt;
  final int daysAtNum1;
  final int weeksAtNum1;
  final String missionStatement;
  final String? photoUrl;

  UserProfile({
    required this.uid,
    required this.username,
    required this.personalStreak,
    required this.currentLimit,
    required this.nextDayLimit,
    this.isDark = false,
    this.hasLockedNextDay = false,
    this.createdAt,
    this.daysAtNum1 = 0,
    this.weeksAtNum1 = 0,
    this.missionStatement = "I WILL NOT LET MY DIGITAL GHOST REPLACE MY PHYSICAL PRESENCE.",
    this.photoUrl,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      username: data['username'] ?? '',
      personalStreak: data['personal_streak'] ?? 0,
      currentLimit: data['current_limit'] ?? 120, // default 2 hours
      nextDayLimit: data['next_day_limit'] ?? 120,
      isDark: data['is_dark'] ?? false,
      hasLockedNextDay: data['has_locked_next_day'] ?? false,
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      daysAtNum1: data['days_at_num1'] ?? 0,
      weeksAtNum1: data['weeks_at_num1'] ?? 0,
      missionStatement: data['mission_statement'] ?? "I WILL NOT LET MY DIGITAL GHOST REPLACE MY PHYSICAL PRESENCE.",
      photoUrl: data['photo_url'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'personal_streak': personalStreak,
      'current_limit': currentLimit,
      'next_day_limit': nextDayLimit,
      'is_dark': isDark,
      'has_locked_next_day': hasLockedNextDay,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'days_at_num1': daysAtNum1,
      'weeks_at_num1': weeksAtNum1,
      'mission_statement': missionStatement,
      'photo_url': photoUrl,
    };
  }
}
