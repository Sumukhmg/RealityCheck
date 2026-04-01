import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_profile.dart';
import '../models/daily_log.dart';
import '../models/group.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '628197242248-2lb8p1cbqtmelkdfujeb5mjft46okkuh.apps.googleusercontent.com',
  );

  // Authentication
  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      print("Auth error: \$e");
      return null;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      print("Google Sign-In Error: ${e.toString()}");
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print("Google Sign-Out Error: $e");
    }
    await _auth.signOut();
  }

  // Current User
  String? get currentUid => _auth.currentUser?.uid;

  Future<bool> profileExists(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists;
  }

  // Profiles
  Future<void> createUserProfile(String uid, String username, String mission) async {
    final profile = UserProfile(
      uid: uid,
      username: username,
      personalStreak: 0,
      currentLimit: 0, // 0 means staging
      nextDayLimit: 120,
      hasLockedNextDay: false,
      createdAt: DateTime.now(),
      daysAtNum1: 0,
      weeksAtNum1: 0,
      missionStatement: mission,
    );
    await _db.collection('users').doc(uid).set(profile.toFirestore());
  }

  Stream<UserProfile?> streamUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (snap.exists) return UserProfile.fromFirestore(snap);
      return null;
    });
  }

  Future<void> updateNextDayLimit(String uid, int limitMinutes) async {
    await _db.collection('users').doc(uid).update({
      'next_day_limit': limitMinutes,
      'has_locked_next_day': true,
    });
  }

  Future<void> updateDarkStatus(String uid, bool isDark) async {
    await _db.collection('users').doc(uid).update({
      'is_dark': isDark,
    });
  }

  Future<void> updateProfile(String uid, String username, String mission) async {
    await _db.collection('users').doc(uid).update({
      'username': username,
      'mission_statement': mission,
    });
    
    // Notify group! Find which group(s) this user is in.
    final groupsSnap = await _db.collection('groups').where('members', arrayContains: uid).get();
    for (var groupDoc in groupsSnap.docs) {
      await _db.collection('groups').doc(groupDoc.id).collection('notifications').add({
        'uid': uid,
        'username': username,
        'message': "REWRITTEN PROTOCOL: $username has updated their profile mission.",
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'group_event',
      });
    }
  }

  Future<String?> uploadProfilePicture(String uid, File imageFile) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('profile_pictures').child('$uid.jpg');
      await storageRef.putFile(imageFile);
      final downloadUrl = await storageRef.getDownloadURL();
      await _db.collection('users').doc(uid).update({'photo_url': downloadUrl});

      try {
        await _auth.currentUser?.updatePhotoURL(downloadUrl);
      } catch (_) {}
      
      return downloadUrl;
    } catch (e) {
      print("Upload Error: $e");
      return null;
    }
  }

  // Daily Logs
  Future<void> logDailyUsage(String uid, int minutesUsed, int limitAtTime, bool wasSuccessful) async {
    final now = DateTime.now();
    final logId = "\${now.year}-\${now.month.toString().padLeft(2, '0')}-\${now.day.toString().padLeft(2, '0')}";
    final logRef = _db.collection('users').doc(uid).collection('daily_logs').doc(logId);

    final log = DailyLog(
      id: logId,
      date: now,
      minutesUsed: minutesUsed,
      limitAtTime: limitAtTime,
      wasSuccessful: wasSuccessful,
    );

    await logRef.set(log.toFirestore(), SetOptions(merge: true));
    
    // If failure, notify groups too!
    if (!wasSuccessful) {
       final groupsSnap = await _db.collection('groups').where('members', arrayContains: uid).get();
       for (var groupDoc in groupsSnap.docs) {
         await _db.collection('groups').doc(groupDoc.id).collection('notifications').add({
           'uid': uid,
           'message': "STREAK COLLAPSE: ${uid} has failed their daily protocol.",
           'timestamp': FieldValue.serverTimestamp(),
           'type': 'group_event',
           'is_warning': true,
         });
       }
    }
  }

  // Groups
  Stream<Group?> streamGroup(String groupId) {
    return _db.collection('groups').doc(groupId).snapshots().map((snap) {
      if (snap.exists) return Group.fromFirestore(snap);
      return null;
    });
  }

  Stream<QuerySnapshot> streamGroupNotifications(String groupId) {
     return _db.collection('groups').doc(groupId).collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots();
  }

  Future<List<UserProfile>> getGroupMembers(String groupId) async {
    final groupDoc = await _db.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) return [];
    
    final group = Group.fromFirestore(groupDoc);
    if (group.members.isEmpty) return [];

    final membersSnap = await _db
        .collection('users')
        .where(FieldPath.documentId, whereIn: group.members)
        .get();
        
    return membersSnap.docs.map((doc) => UserProfile.fromFirestore(doc)).toList();
  }

  Future<void> seedUsers() async {
    final List<Map<String, dynamic>> users = [
      {"name": "Naomi Fleury", "img": "https://randomuser.me/api/portraits/women/54.jpg"},
      {"name": "Vincent Simmmons", "img": "https://randomuser.me/api/portraits/men/47.jpg"},
      {"name": "Hector Jensen", "img": "https://randomuser.me/api/portraits/men/14.jpg"},
      {"name": "Mia Walker", "img": "https://randomuser.me/api/portraits/women/77.jpg"},
      {"name": "Sophie Hunter", "img": "https://randomuser.me/api/portraits/women/32.jpg"},
      {"name": "Lotta Skarshaug", "img": "https://randomuser.me/api/portraits/women/39.jpg"},
      {"name": "Alexander Thomsen", "img": "https://randomuser.me/api/portraits/men/43.jpg"},
      {"name": "Kurilo Pasichnik", "img": "https://randomuser.me/api/portraits/men/99.jpg"},
      {"name": "Oliveiros Duarte", "img": "https://randomuser.me/api/portraits/men/37.jpg"},
      {"name": "Nicolás Zarate", "img": "https://randomuser.me/api/portraits/men/8.jpg"},
    ];

    print("--- SEEDING 10 USERS INTO FIRESTORE ---");
    for (int i = 0; i < users.length; i++) {
        final u = users[i];
        final uid = "seed_user_$i";
        await _db.collection('users').doc(uid).set({
          'username': u['name'],
          'personal_streak': 0,
          'current_limit': 120, // 2 hours
          'next_day_limit': 120,
          'is_dark': false,
          'has_locked_next_day': true,
          'created_at': FieldValue.serverTimestamp(),
          'days_at_num1': 0,
          'weeks_at_num1': 0,
          'mission_statement': "I WILL NOT LET MY DIGITAL GHOST REPLACE MY PHYSICAL PRESENCE.",
          'photo_url': u['img'],
        });
        
        final now = DateTime.now();
        final logId = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        await _db.collection('users').doc(uid).collection('daily_logs').doc(logId).set({
           'id': logId,
           'date': Timestamp.fromDate(now),
           'minutes_used': (40 + i * 12), // unique randomish scores for the leaderboard
           'limit_at_time': 120,
           'was_successful': true,
        });
    }
    print("--- 10 USERS SEEDED SUCCESSFULLY ---");
  }
}

