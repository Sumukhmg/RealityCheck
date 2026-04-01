import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _nameController = TextEditingController();
  final _mottoController = TextEditingController();
  bool _isInitializing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mottoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "IDENTITY PROTOCOL",
                style: TextStyle(color: Color(0xFFFF4500), fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12),
              ),
              const SizedBox(height: 8),
              const Text(
                "ESTABLISH\nYOUR AVATAR",
                style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, height: 1.0),
              ),
              const SizedBox(height: 40),
              
              // INPUTS
              _buildInputLabel("AGENT CODENAME"),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: "E.G. SUMUKH_L",
                  hintStyle: TextStyle(color: Colors.white10),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF4500))),
                ),
              ),
              const SizedBox(height: 30),
              
              _buildInputLabel("THE MISSION (PERSONAL MOTTO)"),
              TextField(
                controller: _mottoController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: "I WILL NOT LET THE DIGITAL GHOST REPLACE MY PHYSICAL PRESENCE.",
                  hintStyle: TextStyle(color: Colors.white10),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF4500))),
                ),
              ),
              const SizedBox(height: 50),
              
              // WARNING BOX
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  border: Border(left: BorderSide(color: Color(0xFFFF4500), width: 5)),
                ),
                child: const Text(
                  "ONCE INITIALIZED, THE PROTOCOL IS LIVE. YOUR ACTIVITY WILL BE SYNCHRONIZED WITH THE SQUAD.",
                  style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, height: 1.4),
                ),
              ),
              const SizedBox(height: 60),
              
              // SUBMIT
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isInitializing ? null : () async {
                    if (_nameController.text.isEmpty || _mottoController.text.isEmpty) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("COMPLETE THE PROTOCOL FIELDS."), backgroundColor: Color(0xFFFF4500)));
                       return;
                    }
                    setState(() => _isInitializing = true);
                    final firebase = context.read<FirebaseService>();
                    final uid = firebase.currentUid;
                    if (uid != null) {
                       await firebase.createUserProfile(uid, _nameController.text.trim(), _mottoController.text.trim());
                       // The main screen StreamBuilder will pick up the existence and switch
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4500),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  child: _isInitializing 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text("INITIALIZE PROTOCOL", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1));
  }
}
