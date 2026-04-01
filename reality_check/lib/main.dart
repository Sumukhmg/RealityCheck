import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/firebase_service.dart';
import 'services/usage_stats_service.dart';
import 'models/user_profile.dart'; 
import 'screens/main_layout.dart';
import 'screens/login_screen.dart';
import 'screens/setup_screen.dart'; 

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Initialize Firebase in Background Isolate
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
      } catch (e) {
        // Ignore duplicate app initialization
      }
      
      final firebaseService = FirebaseService();
      final statsService = UsageStatsService();
      final uid = firebaseService.currentUid;
      
      if (uid != null) {
        // Sync Data to Firebase
        final minutesUsed = await statsService.getTodayUsageMinutes();
        final hasPermission = await statsService.checkUsagePermission();
        
        if (!hasPermission) {
          // Anti-Cheat: User revoked permission! Mark as DARK.
          await firebaseService.updateDarkStatus(uid, true);
          await firebaseService.logDailyUsage(uid, 9999, 120, false);
        } else {
          // Normal sync
          await firebaseService.updateDarkStatus(uid, false);
          await firebaseService.logDailyUsage(uid, minutesUsed, 120, true);
        }
      }
    } catch (err) {
      print(err);
      throw Exception(err);
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // Ignore duplicate app initialization crashes
  }
  
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );
  
  // Register 15-minute sync job
  Workmanager().registerPeriodicTask(
    "1", 
    "syncUsageToFirebase",
    frequency: const Duration(minutes: 15),
  );

  // SEED THE 10 RANDOM USERS TO FIRESTORE ON NEXT BOOT
  await FirebaseService().seedUsers();

  runApp(
    MultiProvider(
      providers: [
        Provider<FirebaseService>(create: (_) => FirebaseService()),
        Provider<UsageStatsService>(create: (_) => UsageStatsService()),
      ],
      child: const RealityCheckApp(),
    ),
  );
}

class RealityCheckApp extends StatelessWidget {
  const RealityCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reality Check',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF4500), // Warning Orange
          surface: Color(0xFF1E1E1E),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white),
          bodyLarge: TextStyle(fontFamily: 'Inter', color: Colors.white70),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF0F0F0F),
              body: Center(child: CircularProgressIndicator(color: Color(0xFFFF4500))),
            );
          }
          if (authSnapshot.hasData) {
            final uid = authSnapshot.data!.uid;
            return StreamBuilder<UserProfile?>(
               stream: context.read<FirebaseService>().streamUserProfile(uid),
               builder: (context, profileSnapshot) {
                  if (profileSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(backgroundColor: Color(0xFF0F0F0F), body: Center(child: CircularProgressIndicator(color: Color(0xFFFF4500))));
                  }
                  if (!profileSnapshot.hasData || profileSnapshot.data == null) {
                    return const SetupScreen();
                  }
                  return const MainLayout();
               }
            );
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
