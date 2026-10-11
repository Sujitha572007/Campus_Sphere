import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const CampusSphereApp());
}

class CampusSphereApp extends StatefulWidget {
  const CampusSphereApp({super.key});

  @override
  State<CampusSphereApp> createState() => _CampusSphereAppState();
}

class _CampusSphereAppState extends State<CampusSphereApp> {
  StreamSubscription<User?>? authSubscription;
  StreamSubscription? preferencesSubscription;
  int preferenceGeneration = 0;
  @override
  void initState() {
    super.initState();
    authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) async {
      final generation = ++preferenceGeneration;
      await preferencesSubscription?.cancel();
      if (!mounted || generation != preferenceGeneration) {
        return;
      }
      appTheme.value = ThemeMode.system;
      if (!mounted || user == null) {
        return;
      }
      preferencesSubscription = settingsRef().snapshots().listen((snapshot) {
        if (generation != preferenceGeneration || !mounted) {
          return;
        }
        final theme = snapshot.data()?['theme'];
        appTheme.value = theme == 'dark'
            ? ThemeMode.dark
            : theme == 'light'
            ? ThemeMode.light
            : ThemeMode.system;
      }, onError: (Object _) {});
    });
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    preferencesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appTheme,
      builder: (context, mode, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'CampusSphere',
        themeMode: mode,
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFB83268),
            brightness: Brightness.dark,
          ),
        ),
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFFFFBFC),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB83268)),
        ),
        home: const WelcomeScreen(),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'SVECW • CAMPUS LIFE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    height: 120,
                    width: 120,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFCE4ED),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      size: 64,
                      color: Color(0xFFB83268),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'CampusSphere',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your campus. Your community.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFB83268),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Discover your clubs. Find your events.\n'
                    'Explore your campus.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 36),
                  const FeatureCard(
                    icon: Icons.groups_rounded,
                    title: 'Find your community',
                    text: 'Explore clubs that match your interests.',
                  ),
                  const SizedBox(height: 12),
                  const FeatureCard(
                    icon: Icons.event_rounded,
                    title: 'Make every event count',
                    text: 'Discover activities and manage registrations.',
                  ),
                  const SizedBox(height: 12),
                  const FeatureCard(
                    icon: Icons.explore_rounded,
                    title: 'Explore campus',
                    text: 'Find campus places and event venues.',
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB83268),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Made for the SVECW community',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1DFE6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFCEAF1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFFB83268), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
