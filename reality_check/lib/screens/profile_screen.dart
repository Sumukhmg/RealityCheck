import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_profile.dart';
import '../services/firebase_service.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _usernameController = TextEditingController();
  final _missionController = TextEditingController();
  bool _isUpdating = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _missionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(String uid) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UPLOADING IMAGE...", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Color(0xFFFF4500)));
      }
      
      final File imageFile = File(pickedFile.path);
      final downloadUrl = await context.read<FirebaseService>().uploadProfilePicture(uid, imageFile);
      
      if (mounted) {
        if (downloadUrl != null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PROFILE PHOTO SYNCHRONIZED.", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Color(0xFF00DD00)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UPLOAD FAILED.", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
        }
      }
    }
  }

  void _showEditProfileDialog(UserProfile profile) {
    _usernameController.text = profile.username;
    _missionController.text = profile.missionStatement;

    showDialog(
      context: context,
      barrierDismissible: !_isUpdating,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF151515),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              title: const Text("EDIT PROTOCOL", style: TextStyle(color: Color(0xFFFF4500), fontWeight: FontWeight.w900, letterSpacing: 2)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: "AGENT NAME",
                      labelStyle: TextStyle(color: Colors.white38, fontSize: 10),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF4500))),
                    ),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _missionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "THE MISSION (PERSONAL QUOTE)",
                      labelStyle: TextStyle(color: Colors.white38, fontSize: 10),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF4500))),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isUpdating ? null : () => Navigator.pop(context),
                  child: const Text("ABORT", style: TextStyle(color: Colors.white38)),
                ),
                ElevatedButton(
                  onPressed: _isUpdating ? null : () async {
                    setDialogState(() => _isUpdating = true);
                    await context.read<FirebaseService>().updateProfile(
                      profile.uid,
                      _usernameController.text.trim(),
                      _missionController.text.trim(),
                    );
                    if (mounted) {
                      setDialogState(() => _isUpdating = false);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4500),
                    foregroundColor: Colors.black,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  child: _isUpdating 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text("UPDATE", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebase = context.read<FirebaseService>();
    final uid = firebase.currentUid;

    if (uid == null) return const Scaffold(body: Center(child: Text("AUTH REQUIRED")));

    return StreamBuilder<UserProfile?>(
      stream: firebase.streamUserProfile(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: Color(0xFF0F0F0F), body: Center(child: CircularProgressIndicator(color: Color(0xFFFF4500))));
        }
        final profile = snapshot.data;
        if (profile == null) return const Scaffold(body: Center(child: Text("PROFILE NOT FOUND")));

        return Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text("REALITY CHECK", style: TextStyle(color: Color(0xFFFF4500), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_sharp, color: Colors.white, size: 20)),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AVATAR SECTION
                Center(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomCenter,
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onTap: () => _pickAndUploadImage(profile.uid),
                            child: Container(
                              width: 140,
                              height: 140,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4500),
                                border: Border.all(color: const Color(0xFFFF4500), width: 1),
                              ),
                              child: Container(
                                color: Colors.white10,
                                child: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                                    ? Image.network(profile.photoUrl!, fit: BoxFit.cover)
                                    : const Icon(Icons.camera_alt_sharp, size: 60, color: Colors.white38),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              color: const Color(0xFFFF4500),
                              child: const Text("ACTIVE SESSION", style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Text(
                        profile.username.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 4),
                      Text("USER ID: ARC-${profile.uid.substring(0, 5).toUpperCase()}", style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showEditProfileDialog(profile),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF4500),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text("EDIT PROTOCOL", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
                
                // INTEGRITY STATUS
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151515),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      const Text("CURRENT STATUS", style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      const SizedBox(height: 8),
                      const Text("INTEGRITY LEVEL: ASCENDED", style: TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) => Container(
                          width: 12, height: 12, margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: const Color(0xFFFFD700),
                        )),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                const Text("THE MISSION", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    border: Border(left: BorderSide(color: Color(0xFFFF4500), width: 4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "\"${profile.missionStatement.toUpperCase()}\"",
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "PROTOCOL SIGNED: ${DateFormat('yyyy.MM.dd').format(profile.createdAt ?? DateTime.now())}",
                        style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                // STAT TILES
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 1,
                  childAspectRatio: 3.5,
                  mainAxisSpacing: 12,
                  children: [
                    _buildStatTile(Icons.bolt_sharp, "${profile.personalStreak} DAYS", "PERSONAL STREAK"),
                    _buildStatTile(Icons.military_tech_sharp, "${profile.daysAtNum1} DAYS", "SAINT DAYS (#1 Rank)"),
                    _buildStatTile(Icons.emoji_events_sharp, "${profile.weeksAtNum1} WEEKS", "SAINT WEEKS (#1 Finalist)"),
                  ],
                ),

                const SizedBox(height: 30),
                // ACTIONS
                _buildActionRow(Icons.settings_sharp, "SYSTEM SETTINGS", onTap: () {}),
                const SizedBox(height: 12),
                _buildActionRow(Icons.logout_sharp, "LOGOUT SESSION", onTap: () async {
                  await context.read<FirebaseService>().signOut();
                }),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatTile(IconData icon, String value, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF151515), border: Border.all(color: Colors.white10)),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF4500), size: 28),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                ),
                Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(IconData icon, String label, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(color: const Color(0xFF1E1E1E), border: Border.all(color: Colors.white10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
            Icon(icon, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }
}
