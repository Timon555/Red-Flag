import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/nearby_screen.dart';
import 'screens/red_flags_screen.dart';
import 'services/profile_service.dart';
import 'verdict_style.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RedFlagApp());
}

class RedFlagApp extends StatelessWidget {
  const RedFlagApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Red Flag',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: redFlagRed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: redFlagRed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const StartupGate(),
    );
  }
}

/// Connects to Firebase, signs in anonymously and sends first-time users to
/// pick their red flags before anything else.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late Future<RedFlagProfile> _startup = _start();

  Future<RedFlagProfile> _start() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) await auth.signInAnonymously();
    return ProfileService().load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RedFlagProfile>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 48),
                    const SizedBox(height: 16),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() => _startup = _start()),
                      child: const Text('Nochmal versuchen'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: Icon(Icons.flag, size: 64, color: redFlagRed)),
          );
        }
        final profile = snapshot.data!;
        if (profile.isEmpty) {
          return RedFlagsScreen(
            initial: profile,
            firstRun: true,
            onSaved: (saved) => setState(() => _startup = Future.value(saved)),
          );
        }
        return NearbyScreen(profile: profile);
      },
    );
  }
}
