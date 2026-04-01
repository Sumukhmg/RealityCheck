import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        children: [
          // GRID BACKGROUND PATTERN
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: CustomPaint(
                painter: GridPainter(),
              ),
            ),
          ),
          // MAIN CONTENT
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // TOP LOGO ROW
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFFF4500), width: 1.5)),
                        child: const Icon(Icons.shield_sharp, color: Color(0xFFFF4500), size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "REALITY CHECK",
                        style: TextStyle(color: Color(0xFFFF4500), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // HERO LOGO
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white10, width: 1),
                      color: Colors.black,
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Image.asset('assets/images/hero_logo.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 50),
                  // HERO TEXT
                  Column(
                    children: [
                      const Text(
                        "REALITY",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 4,
                        ),
                      ),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFFF4500), Color(0xFFFF8C00)],
                        ).createShader(bounds),
                        child: const Text(
                          "CHECK",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 8,
                            height: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  // PROTOCOL BOX
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E1E1E),
                      border: Border(left: BorderSide(color: Color(0xFFFF4500), width: 5)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "SYSTEM PROTOCOL 01:",
                          style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "RECLAIM YOUR REALITY.",
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // LOGIN BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        // START REAL GOOGLE SIGN IN
                        await context.read<FirebaseService>().signInWithGoogle();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4500),
                        foregroundColor: Colors.black,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        elevation: 0,
                      ).copyWith(
                        side: WidgetStateProperty.all(const BorderSide(color: Color(0xFFFF4500), width: 0)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           Icon(Icons.login_sharp, fontWeight: FontWeight.bold),
                           SizedBox(width: 12),
                           Text("LOGIN WITH GOOGLE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "AUTHORIZED PERSONNEL ONLY",
                    style: TextStyle(color: Colors.white12, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.5;

    const spacing = 30.0;
    for (double i = 0; i < size.width; i += spacing) {
      for (double j = 0; j < size.height; j += spacing) {
         canvas.drawCircle(Offset(i, j), 0.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
