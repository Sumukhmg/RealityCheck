import 'package:cloud_firestore/cloud_firestore.dart';

class DailyLog {
  final String id;
  final DateTime date;
  final int minutesUsed;
  final int limitAtTime;
  final bool wasSuccessful;

  DailyLog({
    required this.id,
    required this.date,
    required this.minutesUsed,
    required this.limitAtTime,
    required this.wasSuccessful,
  });

  factory DailyLog.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return DailyLog(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      minutesUsed: data['minutes_used'] ?? 0,
      limitAtTime: data['limit_at_time'] ?? 0,
      wasSuccessful: data['was_successful'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'minutes_used': minutesUsed,
      'limit_at_time': limitAtTime,
      'was_successful': wasSuccessful,
    };
  }
}
