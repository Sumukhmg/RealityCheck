import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String? _groupId;
  Map<String, dynamic>? _groupData;
  List<Map<String, dynamic>> _membersData = [];
  bool _isLoading = true;
  final TextEditingController _usernameController = TextEditingController();
  late Timer _timer;
  Duration _nextFlush = Duration.zero;
  bool _showAllGroup = false;
  Stream<QuerySnapshot>? _notificationsStream;

  @override
  void initState() {
    super.initState();
    _fetchGroupData();
    _calculateNextFlush();
    _initNotificationsStream();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _calculateNextFlush());
    });
  }

  void _initNotificationsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      _notificationsStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _usernameController.dispose();
    super.dispose();
  }

  void _calculateNextFlush() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _nextFlush = midnight.difference(now);
  }

  String _formatCountdown(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  Future<void> _fetchGroupData() async {
    if (mounted) setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final groupsSnap = await FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: uid)
          .limit(1)
          .get();

      if (groupsSnap.docs.isNotEmpty) {
        final doc = groupsSnap.docs.first;
        _groupId = doc.id;
        _groupData = doc.data();
        await _fetchMembersStats(List<String>.from(_groupData!['members']));
      } else {
        _groupId = null;
        _groupData = null;
      }
    } catch (e) {
      debugPrint('Group fetch error: $e');
      _groupId = null;
      _groupData = null;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchMembersStats(List<String> uids) async {
    _membersData.clear();
    final now = DateTime.now();
    // Week starts on Sunday
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday % 7));
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    if (uids.isEmpty) return;

    final batches = <List<String>>[];
    for (var i = 0; i < uids.length; i += 10) {
      batches.add(uids.sublist(i, i + 10 > uids.length ? uids.length : i + 10));
    }

    for (var batch in batches) {
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      for (var userDoc in usersSnap.docs) {
        final userData = userDoc.data();
        final createdAt = (userData['created_at'] as Timestamp?)?.toDate();
        
        // Filter: If joined after current week started, they don't count for this leaderboard
        final bool isProbation = createdAt != null && createdAt.isAfter(weekStart);

        final logsSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('daily_logs')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
            .get();

        int totalWeeklyMinutes = 0;
        for (var log in logsSnap.docs) {
          totalWeeklyMinutes += (log.data()['minutes_used'] ?? 0) as int;
        }

        final dailyAvg = totalWeeklyMinutes / 7;

        userData['uid'] = userDoc.id;
        userData['weekly_minutes'] = totalWeeklyMinutes;
        userData['daily_avg'] = dailyAvg;
        userData['is_probation'] = isProbation;
        _membersData.add(userData);
      }
    }

    // Sort by daily_avg (Lowest first)
    // Probation users go to the bottom regardless of score
    _membersData.sort((a, b) {
      if (a['is_probation'] == true && b['is_probation'] == false) return 1;
      if (a['is_probation'] == false && b['is_probation'] == true) return -1;
      return (a['daily_avg'] as double).compareTo(b['daily_avg'] as double);
    });
  }

  Future<void> _addUser() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("USER NOT FOUND IN SYSTEM"), backgroundColor: Color(0xFFFF4500)),
        );
      }
      return;
    }

    final newMemberUid = query.docs.first.id;

    if (_groupId == null) {
      final docRef = await FirebaseFirestore.instance.collection('groups').add({
        'group_name': 'THE SQUAD',
        'collective_streak': 0,
        'members': [uid, newMemberUid],
      });
      _groupId = docRef.id;
    } else {
      await FirebaseFirestore.instance.collection('groups').doc(_groupId).update({
        'members': FieldValue.arrayUnion([newMemberUid])
      });
    }

    _usernameController.clear();
    FocusScope.of(context).unfocus();
    await _fetchGroupData();
  }

  String _getRankTitle(int rank, int total) {
    if (rank == 1) return "ASCENDED";
    if (rank == 2) return "DISCIPLINED";
    if (rank <= total ~/ 2) return "COMPLIANT";
    if (rank == total) return "CRITICAL";
    return "MONITORED";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF4500)))
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.screenshot_monitor_sharp, color: Color(0xFFFF4500), size: 28),
                          const Text("REALITY CHECK", style: TextStyle(color: Color(0xFFFF4500), fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 2)),
                          const Icon(Icons.wifi_sharp, color: Colors.white54, size: 24),
                        ],
                      ),
                    ),

                    // TITLE SECTION
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1A0A0A), Color(0xFF0F0F0F)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "THE CIRCLE OF HONOR",
                            style: TextStyle(color: Color(0xFFFF4500), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 3),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "LEADERBOARD",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(width: 60, height: 4, color: const Color(0xFFFF4500)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // WALL OF SHAME
                    if (_membersData.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            border: Border.all(color: const Color(0xFFFF4500).withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A0A0A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.whatshot_sharp, color: Color(0xFFFF4500), size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("WALL OF SHAME", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1, decoration: TextDecoration.lineThrough)),
                                    const SizedBox(height: 4),
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
                                        children: [
                                          const TextSpan(text: "Group Streak Dead. "),
                                          TextSpan(
                                            text: (_membersData.last['username'] ?? 'UNKNOWN').toString().toUpperCase(),
                                            style: const TextStyle(color: Color(0xFFFF4500), fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
                                          ),
                                          TextSpan(text: " spent ${_membersData.last['weekly_minutes']} minutes too long."),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
                                child: const Text("SHAME", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // LEADERBOARD ENTRIES
                    if (_membersData.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.group_off_sharp, size: 64, color: Colors.white24),
                              const SizedBox(height: 16),
                              const Text("LONE WOLF", style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w900, fontSize: 24, color: Colors.white)),
                              const SizedBox(height: 8),
                              const Text("You share no honor. Enlist someone.", style: TextStyle(color: Colors.white54)),
                              const SizedBox(height: 24),
                              _buildAddUserRow(),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      // Member cards
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: List.generate(_membersData.length, (index) {
                            final user = _membersData[index];
                            final rank = index + 1;
                            final total = _membersData.length;
                            final isFirst = rank == 1;
                            final isLast = rank == total && total > 1;
                            final isDark = user['is_dark'] == true;
                            final isProbation = user['is_probation'] == true;
                            
                            final double avg = user['daily_avg'] as double;
                            final int hrs = avg ~/ 60;
                            final int mins = (avg % 60).toInt();
                            final timeStr = "${hrs}h ${mins}m";
                            final displayScore = isDark ? "🏴" : (isProbation ? "PROBN" : timeStr);

                            final rankTitle = _getRankTitle(rank, total);
                            final username = (user['username'] ?? 'UNKNOWN').toString().toUpperCase();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GestureDetector(
                                onTap: () => _showUserDetailSheet(user),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1A1A),
                                    border: Border.all(
                                      color: isProbation 
                                          ? Colors.white10 
                                          : (isFirst
                                              ? const Color(0xFFFF4500)
                                              : isLast
                                                  ? const Color(0xFFCC0000)
                                                  : Colors.white10),
                                      width: (isFirst || isLast) && !isProbation ? 2 : 1,
                                    ),
                                  ),
                                child: Row(
                                  children: [
                                    // AVATAR
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: Colors.white10,
                                            borderRadius: BorderRadius.circular(4),
                                            image: user['photo_url'] != null && user['photo_url'].isNotEmpty
                                              ? DecorationImage(
                                                  image: NetworkImage(user['photo_url']),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                          ),
                                          child: user['photo_url'] != null && user['photo_url'].isNotEmpty
                                            ? null
                                            : Icon(
                                                Icons.person_sharp,
                                                color: isFirst ? const Color(0xFFFF4500) : Colors.white38,
                                                size: 30,
                                              ),
                                        ),
                                        if (isFirst)
                                          Positioned(
                                            top: -8,
                                            left: -4,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              color: const Color(0xFFFF4500),
                                              child: const Text("SAINT", style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900)),
                                            ),
                                          ),
                                        if (isLast)
                                          Positioned(
                                            bottom: -8,
                                            left: -4,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              color: const Color(0xFFCC0000),
                                              child: const Text("WEAK\nLINK", style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900, height: 1.1)),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    // NAME + RANK
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            username,
                                            style: TextStyle(
                                              color: isDark ? const Color(0xFFFF4500) : (isLast ? const Color(0xFFFF4500) : Colors.white),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isDark ? "STATUS: UNKNOWN / CHEATING" : (isProbation ? "JOINED MID-WEEK (PROBATION)" : "RANK ${rank.toString().padLeft(2, '0')} — $rankTitle"),
                                            style: TextStyle(
                                              color: isDark ? const Color(0xFFFF4500).withOpacity(0.5) : (isFirst && !isProbation ? const Color(0xFFFF4500) : Colors.white38),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // DISPLAY SCORE
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          displayScore,
                                          style: TextStyle(
                                            color: isDark ? const Color(0xFFFF4500) : (isLast && !isProbation ? const Color(0xFFFF4500) : Colors.white),
                                            fontSize: isDark ? 40 : (isProbation ? 18 : 24),
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          isDark ? "GONE DARK" : (isProbation ? "SCORE HIDDEN" : "AVG SCREEN TIME"),
                                          style: TextStyle(color: isDark ? const Color(0xFFFF4500) : Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                          }),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // BOTTOM STATS ROW
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          // GROUP INTEGRITY
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              color: const Color(0xFF151515),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("GROUP INTEGRITY", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                  const SizedBox(height: 8),
                                  Text(
                                    _membersData.isEmpty
                                        ? "—"
                                        : "${(_membersData.fold<double>(0, (sum, m) {
                                            final avg = m['daily_avg'] as double? ?? 0.0;
                                            final limit = (m['current_limit'] ?? 480).toDouble();
                                            final score = ((limit - avg) / limit).clamp(0.0, 1.0);
                                            return sum + score;
                                          }) / _membersData.length * 100).toInt()}%",
                                    style: const TextStyle(color: Color(0xFFFF4500), fontSize: 32, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 8),
                                  // Integrity bar
                                  Container(
                                    height: 6,
                                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(3)),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor: _membersData.isEmpty
                                            ? 0
                                            : (_membersData.fold<double>(0, (sum, m) {
                                                final avg = m['daily_avg'] as double? ?? 0.0;
                                                final limit = (m['current_limit'] ?? 480).toDouble();
                                                final score = ((limit - avg) / limit).clamp(0.0, 1.0);
                                                return sum + score;
                                              }) / _membersData.length).clamp(0.0, 1.0),
                                        child: Container(
                                          decoration: BoxDecoration(color: const Color(0xFFFF4500), borderRadius: BorderRadius.circular(3)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // NEXT FLUSH COUNTDOWN
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              color: const Color(0xFF151515),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("NEXT FLUSH", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatCountdown(_nextFlush),
                                    style: const TextStyle(color: Color(0xFFFF4500), fontSize: 28, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "CYCLE TERMINATION\nIMMINENT",
                                    style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // GROUP FEED SECTION
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text("GROUP FEED", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, color: Colors.white54)),
                          const SizedBox(height: 16),
                          if (_notificationsStream == null)
                            Container(
                              padding: const EdgeInsets.all(20),
                              color: Colors.white10,
                              child: const Center(
                                child: Text("NO GROUP ALERTS YET.", style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                              ),
                            )
                          else
                          StreamBuilder<QuerySnapshot>(
                            stream: _notificationsStream,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(color: Color(0xFFFF4500)),
                                ));
                              }
                              if (snapshot.hasError) {
                                return Center(child: Text("ERROR: ${snapshot.error}", style: const TextStyle(color: Color(0xFFFF4500), fontSize: 12)));
                              }
                              final allDocs = snapshot.data?.docs ?? [];
                              final groupDocs = allDocs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return data['type'] == 'group';
                              }).toList();
                              final displayDocs = _showAllGroup ? groupDocs : groupDocs.take(5).toList();

                              if (displayDocs.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  color: Colors.white10,
                                  child: const Center(
                                    child: Text("NO GROUP ALERTS YET.", style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                                  ),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ...displayDocs.map((doc) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    final isWarning = data['is_warning'] == true;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isWarning ? const Color(0xFFFF4500) : Colors.white10,
                                        border: Border(left: BorderSide(color: isWarning ? Colors.black : Colors.white54, width: 4)),
                                      ),
                                      child: Text(
                                        (data['message'] ?? '').toString().toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                          color: isWarning ? Colors.black : Colors.white,
                                        ),
                                      ),
                                    );
                                  }),
                                  if (!_showAllGroup && groupDocs.length > 5)
                                    GestureDetector(
                                      onTap: () => setState(() => _showAllGroup = true),
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(14),
                                        color: Colors.white10,
                                        child: const Center(
                                          child: Text("VIEW MORE →", style: TextStyle(color: Color(0xFFFF4500), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14)),
                                        ),
                                      ),
                                    ),
                                  if (_showAllGroup && groupDocs.length > 5)
                                    GestureDetector(
                                      onTap: () => setState(() => _showAllGroup = false),
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(14),
                                        color: Colors.white10,
                                        child: const Center(
                                          child: Text("VIEW LESS ←", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14)),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ADD USER (if in group already)
                    if (_groupId != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildAddUserRow(),
                      ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  void _showUserDetailSheet(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) {
        final username = (user['username'] ?? 'UNKNOWN').toString().toUpperCase();
        final daysAt1 = user['days_at_num1'] ?? 0;
        final weeksAt1 = user['weeks_at_num1'] ?? 0;
        final personalStreak = user['personal_streak'] ?? 0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              color: const Color(0xFF1A1A1A),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text("PERSONNEL DOSSIER", style: TextStyle(color: Color(0xFFFF4500), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                   const SizedBox(height: 8),
                   Text(username, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 1)),
                   const SizedBox(height: 4),
                   Container(width: 40, height: 4, color: const Color(0xFFFF4500)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  _buildStatBox("ST. DAYS", daysAt1.toString(), "NO. 1 DAYS"),
                  const SizedBox(width: 16),
                  _buildStatBox("ST. WEEKS", weeksAt1.toString(), "NO. 1 WEEKS"),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _buildStatBox("STREAK", "$personalStreak", "PERSONAL DAYS"),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.white10)),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("STATUS", style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text("ACTIVE", style: TextStyle(color: Color(0xFF00FF00), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _buildStatBox(String label, String value, String sublabel) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFFFF4500), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(sublabel, style: const TextStyle(color: Colors.white38, fontSize: 7, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildAddUserRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _usernameController,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: "ADD USERNAME",
              hintStyle: TextStyle(color: Colors.white24, letterSpacing: 2),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24, width: 2), borderRadius: BorderRadius.zero),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF4500), width: 2), borderRadius: BorderRadius.zero),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _addUser,
          child: Container(
            width: 50,
            height: 50,
            color: const Color(0xFFFF4500),
            child: const Icon(Icons.add_sharp, color: Colors.black, size: 28),
          ),
        ),
      ],
    );
  }
}
