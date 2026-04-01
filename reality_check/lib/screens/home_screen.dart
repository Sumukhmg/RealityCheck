import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../services/usage_stats_service.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../models/user_profile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _usageMinutes = 0;
  bool _hasPermission = false;
  Timer? _pollingTimer;
  String? _authError;
  final Set<int> _notifiedThresholds = {};

  bool _showAllPersonal = false;
  bool _showAllGroup = false;

  int _groupRemainingMins = 0;
  double _groupProgress = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final stats = context.read<UsageStatsService>();
    final firebase = context.read<FirebaseService>();
    final perm = await stats.checkUsagePermission();
    
    // Sync is_dark status to Firestore for Anti-Cheat
    final uid = firebase.currentUid;
    if (uid != null) {
      await firebase.updateDarkStatus(uid, !perm);
    }

    int min = 0;
    if (perm) {
      min = await stats.getTodayUsageMinutes();
    }
    
    debugPrint("🔍 [REALITY CHECK] Permission: $perm | Usage Minutes: $min");
    
    if (mounted) {
      setState(() {
        _hasPermission = perm;
        _usageMinutes = min;
      });
    }

    // Trigger Notification Logic Live
    if (uid != null) {
       final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
       if (doc.exists) {
          final currentLimit = doc.data()?['current_limit'] as int? ?? 120;
          final int remainingMins = (currentLimit - min).clamp(0, currentLimit);
          
          if (currentLimit > 0) {
            final double percentRemaining = remainingMins / currentLimit;
            
            int thresholdHit = -1;
            if (percentRemaining <= 0.0) thresholdHit = 0;
            else if (percentRemaining <= 0.20) thresholdHit = 20;
            else if (percentRemaining <= 0.40) thresholdHit = 40;
            else if (percentRemaining <= 0.60) thresholdHit = 60;
            else if (percentRemaining <= 0.80) thresholdHit = 80;

            if (thresholdHit != -1 && !_notifiedThresholds.contains(thresholdHit)) {
               _notifiedThresholds.add(thresholdHit);
               NotificationService.showBrutalistWarning(thresholdHit, remainingMins);
            }
          }
       }
       
       // Calculate Group Dial Data
       _fetchGroupStats(uid);
    }
  }

  Future<void> _fetchGroupStats(String uid) async {
    try {
      final groupsSnap = await FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: uid)
          .limit(1)
          .get();

      if (groupsSnap.docs.isNotEmpty) {
        final doc = groupsSnap.docs.first;
        final members = List<String>.from(doc.data()['members'] ?? []);
        
        final now = DateTime.now();
        final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        
        int totalLimit = 0;
        int totalRemaining = 0;
        
        if (members.isNotEmpty) {
           final batches = <List<String>>[];
           for (var i = 0; i < members.length; i += 10) {
              batches.add(members.sublist(i, i + 10 > members.length ? members.length : i + 10));
           }
           
           for (var batch in batches) {
             final usersSnap = await FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: batch).get();
             for (var uDoc in usersSnap.docs) {
               final limit = uDoc.data()['current_limit'] as int? ?? 120;
               final logSnap = await FirebaseFirestore.instance.collection('users').doc(uDoc.id).collection('daily_logs').doc(todayStr).get();
               final minsUsed = logSnap.exists ? (logSnap.data()?['minutes_used'] as int? ?? 0) : 0;
               
               // For current user, use live real-time usage! If not, use background sync usage.
               final finalMinsUsed = (uDoc.id == uid) ? _usageMinutes : minsUsed;
               
               totalLimit += limit;
               totalRemaining += max(0, limit - finalMinsUsed);
             }
           }
        }
        
        if (mounted) {
           setState(() {
              if (totalLimit == 0 || members.isEmpty) {
                 _groupRemainingMins = 0;
                 _groupProgress = 1.0;
              } else {
                 _groupRemainingMins = totalRemaining ~/ members.length;
                 _groupProgress = (totalRemaining / totalLimit).clamp(0.0, 1.0);
              }
           });
        }
      }
    } catch (e) {
      debugPrint("Group stats error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebase = context.read<FirebaseService>();
    final uid = firebase.currentUid ?? '';
    
    if (_authError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(_authError!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFF4500), fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5)),
          ),
        ),
      );
    }

    if (uid.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF4500)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('INTEGRITY DASHBOARD', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<UserProfile?>(
        stream: firebase.streamUserProfile(uid),
        builder: (context, userSnap) {
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF4500)));
          
          final profile = userSnap.data!;
          final int limit = profile.currentLimit;
          final bool hasLocked = profile.hasLockedNextDay;
          
          if (limit == 0 || !hasLocked) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.security_sharp, color: Color(0xFFFF4500), size: 64),
                    const SizedBox(height: 20),
                    const Text(
                      "SYSTEM STANDBY",
                      style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2),
                    ),
                    const SizedBox(height: 8),
                    Container(width: 60, height: 4, color: const Color(0xFFFF4500)),
                    const SizedBox(height: 30),
                    Text(
                      limit == 0 ? "CHALLENGE INITIALIZES AT 12:00 AM" : "DASHBOARD LOCKED UNTIL TOMORROW SECURED",
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _buildMidnightCountdown(),
                    const SizedBox(height: 40),
                    Text(
                      limit == 0 ? "GO TO 'LIMITS' TO SET YOUR FIRST COMMITMENT." : "GO TO 'LIMITS' TO LOCK IN TOMORROW'S CYCLE.",
                      style: const TextStyle(color: Color(0xFFFF4500), fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            );
          }

          final double personalProgress = _hasPermission ? (_usageMinutes / limit).clamp(0.0, 1.0) : 0;
          final int personalRemainingMins = max(0, limit - _usageMinutes);

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_hasPermission)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      color: const Color(0xFFFF4500),
                      child: Column(
                        children: [
                          const Text("ANTI-CHEAT TRIGGERED", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 18)),
                          const SizedBox(height: 8),
                          const Text("You must grant Usage Access for the app to function."),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () async {
                              await context.read<UsageStatsService>().requestUsagePermission();
                              _loadData();
                            },
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                            child: const Text("FIX PERMISSIONS"),
                          )
                        ],
                      ),
                    ),

                  // TOP SECTION: DUAL DIALS
                  Row(
                    children: [
                      // PERSONAL DIAL
                      Expanded(
                        child: Column(
                          children: [
                            const Text("PERSONAL", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white54)),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 120,
                              child: BrutalistDial(
                                progress: personalProgress,
                                valueText: personalRemainingMins < 60 ? "${personalRemainingMins}M" : "${personalRemainingMins ~/ 60}H ${personalRemainingMins % 60}M".replaceAll(' 0M', ''),
                                labelText: "REMAINING",
                                color: personalProgress >= 0.9 ? const Color(0xFFFF4500) : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // GROUP DIAL
                      Expanded(
                        child: Column(
                          children: [
                            const Text("GROUP AVG", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white54)),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 120,
                              child: BrutalistDial(
                                progress: 1.0 - _groupProgress,
                                valueText: _groupRemainingMins < 60 ? "${_groupRemainingMins}M" : "${_groupRemainingMins ~/ 60}H ${_groupRemainingMins % 60}M".replaceAll(' 0M', ''),
                                labelText: "REMAINING",
                                color: (1.0 - _groupProgress) >= 0.9 ? const Color(0xFFFF4500) : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 40),

                  // PERSONAL FEED SECTION
                  const Text("PERSONAL FEED", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, color: Colors.white54)),
                  const SizedBox(height: 16),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('notifications')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator(color: Color(0xFFFF4500))),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text("ERROR: ${snapshot.error}", style: const TextStyle(color: Color(0xFFFF4500), fontSize: 12)));
                      }
                      final allDocs = snapshot.data?.docs ?? [];
                      final personalDocs = allDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['type'] == 'personal';
                      }).toList();
                      final displayDocs = _showAllPersonal ? personalDocs : personalDocs.take(5).toList();

                      if (displayDocs.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          color: Colors.white10,
                          child: const Center(
                            child: Text("NO PERSONAL ALERTS YET.", style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...displayDocs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final isWarning = data['is_warning'] == true;
                            return _buildFeedCard(
                              (data['message'] ?? '').toString(),
                              isWarning: isWarning,
                            );
                          }),
                          if (!_showAllPersonal && personalDocs.length > 5)
                            GestureDetector(
                              onTap: () => setState(() => _showAllPersonal = true),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                color: Colors.white10,
                                child: const Center(
                                  child: Text("VIEW MORE →", style: TextStyle(color: Color(0xFFFF4500), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14)),
                                ),
                              ),
                            ),
                          if (_showAllPersonal && personalDocs.length > 5)
                            GestureDetector(
                              onTap: () => setState(() => _showAllPersonal = false),
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

                  const SizedBox(height: 30),
                  
                  // GROUP FEED SECTION
                  const Text("GROUP FEED", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, color: Colors.white54)),
                  const SizedBox(height: 16),
                  
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('groups')
                        .where('members', arrayContains: uid)
                        .snapshots(),
                    builder: (context, groupsSnap) {
                      if (!groupsSnap.hasData || groupsSnap.data!.docs.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          color: Colors.white10,
                          child: const Center(child: Text("NOT IN A SQUAD.", style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 2))),
                        );
                      }
                      
                      final groupId = groupsSnap.data!.docs.first.id;
                      
                      return StreamBuilder<QuerySnapshot>(
                        stream: context.read<FirebaseService>().streamGroupNotifications(groupId),
                        builder: (context, feedSnap) {
                          if (feedSnap.connectionState == ConnectionState.waiting) return const SizedBox();
                          
                          final allDocs = feedSnap.data?.docs ?? [];
                          final displayDocs = _showAllGroup ? allDocs : allDocs.take(5).toList();

                          if (displayDocs.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              color: Colors.white10,
                              child: const Center(child: Text("SQUAD RECON: NO ACTIVITY.", style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 2))),
                            );
                          }
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ...displayDocs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final isWarning = data['is_warning'] == true;
                                return _buildFeedCard(
                                  (data['message'] ?? '').toString(),
                                  isWarning: isWarning,
                                );
                              }).toList(),
                              if (!_showAllGroup && allDocs.length > 5)
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
                              if (_showAllGroup && allDocs.length > 5)
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
                      );
                    },
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildFeedCard(String message, {required bool isWarning}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWarning ? const Color(0xFFFF4500) : Colors.white10,
        border: Border(left: BorderSide(color: isWarning ? Colors.black : Colors.white54, width: 4)),
      ),
      child: Text(
        message.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          color: isWarning ? Colors.black : Colors.white,
        ),
      ),
    );
  }

  Widget _buildMidnightCountdown() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final diff = midnight.difference(now);
    
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hrs = twoDigits(diff.inHours);
    final mins = twoDigits(diff.inMinutes.remainder(60));
    final secs = twoDigits(diff.inSeconds.remainder(60));
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white10),
        color: const Color(0xFF151515),
      ),
      child: Text(
        "$hrs : $mins : $secs",
        style: const TextStyle(
          color: Color(0xFFFF4500),
          fontSize: 32,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          letterSpacing: 4,
        ),
      ),
    );
  }
}

class BrutalistDial extends StatelessWidget {
  final double progress;
  final String valueText;
  final String labelText;
  final Color color;

  const BrutalistDial({
    super.key,
    required this.progress,
    required this.valueText,
    required this.labelText,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth < constraints.maxHeight ? constraints.maxWidth : constraints.maxHeight;
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: DialPainter(progress: progress, color: color),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      valueText,
                      style: TextStyle(
                        fontSize: size * 0.35,
                        fontWeight: FontWeight.w900,
                        color: color,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      labelText,
                      style: TextStyle(
                        fontSize: size * 0.08,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: color.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class DialPainter extends CustomPainter {
  final double progress;
  final Color color;

  DialPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    final bgPaint = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.square;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 7), -pi, pi, false, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.square;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 7), -pi, pi * progress, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
