import 'dart:ui';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'commitment_screen.dart';
import 'profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true, // Crucial for floating nav bar to blur the content behind it
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          LeaderboardScreen(),
          CommitmentScreen(),
          ProfileScreen(), 
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF151515).withOpacity(0.7),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white10, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.grid_view_sharp, "DASH"),
                    _buildNavItem(1, Icons.emoji_events_sharp, "RANKS"),
                    _buildNavItem(2, Icons.shutter_speed_sharp, "LIMITS"),
                    _buildNavItem(3, Icons.account_circle_sharp, "PROFILE"),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutExpo,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFF4500).withOpacity(0.25) : Colors.transparent,
              borderRadius: BorderRadius.circular(25),
              border: isSelected ? Border.all(color: const Color(0xFFFF4500).withOpacity(0.5), width: 1.5) : Border.all(color: Colors.transparent, width: 1.5),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: const Color(0xFFFF4500).withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ] : [],
            ),
            child: Icon(
              icon,
              color: isSelected ? const Color(0xFFFF4500) : Colors.white54,
              size: 26,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFFFF4500) : Colors.white54,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
