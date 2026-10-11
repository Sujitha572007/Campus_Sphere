import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_dashboard.dart';
import 'home_screen.dart';

class RoleGate extends StatefulWidget {
  const RoleGate({
    super.key,
    required this.onSignedOut,
    this.adminLogin = false,
  });
  final VoidCallback onSignedOut;
  final bool adminLogin;
  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> profile;
  @override
  void initState() {
    super.initState();
    profile = FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .snapshots();
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        widget.onSignedOut();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not log out. Please retry.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: profile,
      builder: (context, snapshot) {
        if (!snapshot.hasError && !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data?.data();
        if (!snapshot.hasError && data?['role'] == 'admin') {
          return AdminDashboard(onSignedOut: widget.onSignedOut);
        }
        if (!snapshot.hasError &&
            data?['role'] == 'student' &&
            !widget.adminLogin) {
          return HomeScreen(onSignedOut: widget.onSignedOut);
        }
        return Scaffold(
          appBar: AppBar(title: const Text('CampusSphere access')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, size: 64),
                  const SizedBox(height: 20),
                  Text(
                    snapshot.hasError
                        ? 'Could not verify your account role. Check your connection and published rules.'
                        : data == null
                        ? 'Your profile is unavailable. Please log out and retry.'
                        : 'Admin access has not been approved. Ask the project owner to set your user profile role to admin in Firebase Console.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: logout,
                    child: const Text('Back to login'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
