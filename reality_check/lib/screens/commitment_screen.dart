import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:vibration/vibration.dart';
import '../services/firebase_service.dart';
import '../models/user_profile.dart';

class CommitmentScreen extends StatefulWidget {
  const CommitmentScreen({super.key});

  @override
  State<CommitmentScreen> createState() => _CommitmentScreenState();
}

class _CommitmentScreenState extends State<CommitmentScreen> {
  double _hours = 0.5;
  late Timer _timer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateRemainingTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _calculateRemainingTime();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _calculateRemainingTime() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _remainingTime = midnight.difference(now);
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<FirebaseService>().currentUid;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.screenshot_monitor_sharp, color: Color(0xFFFF4500), size: 28),
                        const Text(
                          "REALITY CHECK",
                          style: TextStyle(
                            color: Color(0xFFFF4500),
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 2,
                          ),
                        ),
                        const Icon(Icons.wifi_sharp, color: Colors.white54, size: 24),
                      ],
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      "SYSTEM PROTOCOL 04 // LIMITS",
                      style: TextStyle(
                        color: Color(0xFFFF4500),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Text(
                      "COMMITMENT\nENGINE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        height: 0.9,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(width: 80, height: 4, color: const Color(0xFFFF4500)),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              if (uid != null)
                StreamBuilder<UserProfile?>(
                  stream: context.read<FirebaseService>().streamUserProfile(uid),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF4500)));
                    final profile = snapshot.data!;

                    if (profile.hasLockedNextDay) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Container(
                          padding: const EdgeInsets.all(30),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A1A1A),
                            border: Border(left: BorderSide(color: Colors.green, width: 4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.lock_sharp, color: Colors.green.shade400, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    "COMMITMENT SECURED",
                                    style: TextStyle(color: Colors.green.shade400, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                "YOUR LIMIT PROTOCOL FOR TOMORROW HAS BEEN LOCKED INTO THE SYSTEM DATABANKS.",
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                "${profile.nextDayLimit ~/ 60} HRS ${(profile.nextDayLimit % 60).toString().padLeft(2, '0')} MIN",
                                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        // THE ADVANCE RULE CARD
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A1A1A),
                              border: Border(left: BorderSide(color: Color(0xFFFF4500), width: 4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFE57373), size: 18),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "THE ADVANCE RULE",
                                      style: TextStyle(
                                        color: Color(0xFFE57373),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  "YOU MUST SET YOUR LIMIT BEFORE 11:59 PM OR THE SYSTEM WILL CHOOSE FOR YOU.",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    const Text(
                                      "REMAINING TIME: ",
                                      style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      _formatDuration(_remainingTime),
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: Container(height: 1, color: Colors.white10)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // SELECTION CARD
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Container(
                            padding: const EdgeInsets.all(30),
                            color: const Color(0xFF1E1E1E),
                            child: Column(
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("CURRENT SELECTION", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text("SYSTEM", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                                        Text("STATUS", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: _hours < 1 ? "30" : _hours.toInt().toString().padLeft(2, '0'),
                                            style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Colors.white),
                                          ),
                                          TextSpan(
                                            text: _hours < 1 ? " MINS" : " HOURS",
                                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Text(
                                      "AWAITING\nLOCK",
                                      style: TextStyle(color: Color(0xFFFF4500), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
                                      textAlign: TextAlign.right,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 30),
                                // RULER SLIDER
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 60,
                                    activeTrackColor: Colors.transparent,
                                    inactiveTrackColor: Colors.transparent,
                                    thumbColor: const Color(0xFFFF4500),
                                    thumbShape: const RectangularSliderThumbShape(enabledThumbRadius: 30, thumbHeight: 70, thumbWidth: 40),
                                    overlayShape: SliderComponentShape.noOverlay,
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Custom Ruler Background
                                      Container(
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          border: Border.all(color: Colors.white10),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: List.generate(12, (index) => Container(width: 2, height: index % 3 == 0 ? 30 : 15, color: Colors.white10)),
                                        ),
                                      ),
                                      Slider(
                                        value: _hours,
                                        min: 0.5,
                                        max: 12.0,
                                        divisions: 23, // Every 30 mins
                                        onChanged: (val) {
                                          setState(() {
                                            _hours = val;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("01 HOUR", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
                                    Text("06 HOURS", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
                                    Text("12 HOURS", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // LOCK IN BUTTON - truly edge-to-edge, no padding
                        GestureDetector(
                          onTap: () async {
                            final int mins = (_hours * 60).toInt();
                            
                            // Always set for tomorrow
                            await context.read<FirebaseService>().updateNextDayLimit(uid, mins);
                            
                            // IMMEDIATELY UNLOCK DASHBOARD FOR NEW RECRUITS!
                            if (profile.currentLimit == 0) {
                               await FirebaseFirestore.instance.collection('users').doc(uid).update({'current_limit': mins});
                            }
                            
                            if (mounted) {
                              Vibration.vibrate(duration: 200);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(profile.currentLimit == 0 ? "PROTOCOL INITIALIZED. DASHBOARD UNLOCKED." : "COMMITMENT LOCKED FOR TOMORROW."),
                                  backgroundColor: const Color(0xFFFF4500),
                                )
                              );
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            height: 100,
                            color: const Color(0xFFFF4500),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "LOCK IN COMMITMENT",
                                  style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
                                ),
                                Text(
                                  "IRREVERSIBLE ACTION",
                                  style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

              const SizedBox(height: 30),

              // PREVIOUS COMMITMENT
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    _buildStatCard(Icons.history_sharp, "PREVIOUS COMMITMENT", "06:30 HRS"),
                    const SizedBox(height: 15),
                    _buildStatCard(Icons.trending_up_sharp, "GLOBAL AVERAGE", "07:15 HRS"),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF151515),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF8A80), size: 24),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}

class RectangularSliderThumbShape extends SliderComponentShape {
  final double enabledThumbRadius;
  final double thumbHeight;
  final double thumbWidth;

  const RectangularSliderThumbShape({
    this.enabledThumbRadius = 10.0,
    this.thumbHeight = 60.0,
    this.thumbWidth = 20.0,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(thumbWidth, thumbHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    final paint = Paint()
      ..color = sliderTheme.thumbColor ?? Colors.red
      ..style = PaintingStyle.fill;

    // Add glowing effect
    final shadowPaint = Paint()
      ..color = (sliderTheme.thumbColor ?? Colors.red).withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final rect = Rect.fromCenter(center: center, width: thumbWidth, height: thumbHeight);
    canvas.drawRect(rect.inflate(5), shadowPaint);
    canvas.drawRect(rect, paint);
  }
}
