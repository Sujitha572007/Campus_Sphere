import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'role_gate.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'register_screen.dart';
import 'user_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final key = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();

  bool adminLogin = false;
  bool hide = true;
  bool loading = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> login() async {
    if (loading || !(key.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => loading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );

      final user = credential.user;

      if (user == null) {
        if (!mounted) {
          return;
        }

        message('Login could not be completed. Please try again.');
        return;
      }

      try {
        await UserService.ensureProfile(user);
        if (adminLogin) {
          final role = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (role.data()?['role'] != 'admin') {
            await UserService.requestAdminAccess(user);
          }
        }
      } on FirebaseException catch (e) {
        if (!mounted) {
          return;
        }

        if (e.code == 'permission-denied') {
          message(
            'Profile access was denied. Check your published Firestore rules.',
          );
        } else {
          message(
            'Could not load your profile. Check your connection and retry.',
          );
        }

        return;
      } catch (_) {
        if (!mounted) {
          return;
        }

        message('Could not load your profile. Please try again.');
        return;
      }

      if (!mounted) {
        return;
      }

      // Capture the navigator before removing the login screen.
      final navigator = Navigator.of(context);

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => RoleGate(
            adminLogin: adminLogin,
            onSignedOut: () {
              if (!navigator.mounted) {
                return;
              }

              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      switch (e.code) {
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          message('Incorrect email or password.');
          break;

        case 'invalid-email':
          message('Enter a valid email address.');
          break;

        case 'user-disabled':
          message('This account has been disabled.');
          break;

        case 'too-many-requests':
          message('Too many attempts. Please try again later.');
          break;

        case 'network-request-failed':
          message('Check your internet connection and try again.');
          break;

        case 'operation-not-allowed':
          message('Enable Email/Password in Firebase Authentication.');
          break;

        default:
          message(e.message ?? 'Login failed. Please try again.');
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      message('Login failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFC),
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: key,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.school_rounded,
                        size: 64,
                        color: Color(0xFFB83268),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Welcome back!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to your CampusSphere account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Student'),
                            icon: Icon(Icons.school_outlined),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Admin'),
                            icon: Icon(Icons.admin_panel_settings_outlined),
                          ),
                        ],
                        selected: {adminLogin},
                        onSelectionChanged: loading
                            ? null
                            : (value) =>
                                  setState(() => adminLogin = value.first),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: email,
                        enabled: !loading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';

                          if (text.isEmpty) {
                            return 'Enter your email';
                          }

                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(text)) {
                            return 'Enter a valid email';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: password,
                        enabled: !loading,
                        obscureText: hide,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          suffixIcon: IconButton(
                            tooltip: hide ? 'Show password' : 'Hide password',
                            onPressed: loading
                                ? null
                                : () {
                                    setState(() => hide = !hide);
                                  },
                            icon: Icon(
                              hide ? Icons.visibility : Icons.visibility_off,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter your password';
                          }

                          return null;
                        },
                        onFieldSubmitted: (_) => login(),
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: loading ? null : login,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB83268),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                adminLogin ? 'Admin Login' : 'Student Login',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RegisterScreen(
                                      adminRequest: adminLogin,
                                    ),
                                  ),
                                );
                              },
                        child: Text(
                          adminLogin
                              ? "New admin? Register for access"
                              : "Don't have an account? Register",
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
