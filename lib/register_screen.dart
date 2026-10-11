import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.adminRequest = false});
  final bool adminRequest;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final key = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();

  bool hide = true;
  bool loading = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> register() async {
    if (loading || !key.currentState!.validate()) {
      return;
    }

    setState(() => loading = true);

    try {
      final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );

      // The account has been created even if updating the name fails.
      try {
        await result.user!.updateDisplayName(name.text.trim());
      } catch (_) {
        // Profile information can be updated later.
      }

      await UserService.ensureProfile(result.user!);
      if (widget.adminRequest) {
        await UserService.requestAdminAccess(result.user!);
      }
      // Admin requests do not grant admin privileges.
      await FirebaseAuth.instance.signOut();

      if (!mounted) {
        return;
      }

      message(
        widget.adminRequest
            ? 'Account created. Admin access requested; approval is required.'
            : 'Account created successfully! You can now log in.',
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      switch (e.code) {
        case 'email-already-in-use':
          message('An account already exists with this email. Please log in.');
          break;
        case 'invalid-email':
          message('Enter a valid email address.');
          break;
        case 'weak-password':
          message('Choose a stronger password.');
          break;
        case 'operation-not-allowed':
          message('Enable Email/Password in Firebase Authentication.');
          break;
        case 'network-request-failed':
          message('Check your internet connection and try again.');
          break;
        case 'too-many-requests':
          message('Too many attempts. Please try again later.');
          break;
        default:
          message(e.message ?? 'Registration failed. Please try again.');
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      await FirebaseAuth.instance.signOut();
      if (!mounted) {
        return;
      }
      message(
        'Could not complete registration. Try logging in if the account '
        'was already created.',
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  InputDecoration field(String text, IconData icon) {
    return InputDecoration(
      labelText: text,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 60,
                      color: Color(0xFFB83268),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Join CampusSphere',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.adminRequest
                          ? 'Register for admin access (approval required)'
                          : 'Create your student account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: name,
                      enabled: !loading,
                      textCapitalization: TextCapitalization.words,
                      decoration: field('Full name', Icons.person_outline),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your name';
                        }
                        if (value.trim().length > 100) {
                          return 'Use at most 100 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: email,
                      enabled: !loading,
                      keyboardType: TextInputType.emailAddress,
                      decoration: field('Email', Icons.email_outlined),
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
                      decoration: field('Password', Icons.lock_outline)
                          .copyWith(
                            suffixIcon: IconButton(
                              tooltip: hide ? 'Show password' : 'Hide password',
                              onPressed: () {
                                setState(() => hide = !hide);
                              },
                              icon: Icon(
                                hide ? Icons.visibility : Icons.visibility_off,
                              ),
                            ),
                          ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter a password';
                        }
                        if (value.length < 8) {
                          return 'Use at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: confirm,
                      enabled: !loading,
                      obscureText: hide,
                      decoration: field('Confirm password', Icons.lock_outline),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Confirm your password';
                        }
                        if (value != password.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => register(),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: loading ? null : register,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: loading ? null : () => Navigator.pop(context),
                      child: const Text('Already have an account? Login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
