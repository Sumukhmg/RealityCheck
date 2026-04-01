import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String groupId;
  final String groupName;
  final int collectiveStreak;
  final List<String> members; // user UIDs

  Group({
    required this.groupId,
    required this.groupName,
    required this.collectiveStreak,
    required this.members,
  });

  factory Group.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Group(
      groupId: doc.id,
      groupName: data['group_name'] ?? '',
      collectiveStreak: data['collective_streak'] ?? 0,
      members: List<String>.from(data['members'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'group_name': groupName,
      'collective_streak': collectiveStreak,
      'members': members,
    };
  }
}
