import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final appTheme = ValueNotifier<ThemeMode>(ThemeMode.system);

DocumentReference<Map<String, dynamic>> settingsRef() => FirebaseFirestore
    .instance
    .collection('users')
    .doc(FirebaseAuth.instance.currentUser!.uid)
    .collection('preferences')
    .doc('settings');

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key});
  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late final stream = settingsRef().snapshots();
  bool saving = false;
  Future<void> save(Map<String, dynamic> values) async {
    setState(() => saving = true);
    try {
      await settingsRef().set(values, SetOptions(merge: true));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save settings. Try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> resetPassword() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || saving) {
      return;
    }
    setState(() => saving = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to $email.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not send reset email. Try again later.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text('Could not load settings. Check your connection.');
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final d = snapshot.data?.data() ?? {};
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (saving) const LinearProgressIndicator(),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.tune),
                    title: Text('Make CampusSphere yours'),
                    subtitle: Text('Preferences are saved to your account.'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue:
                        ['system', 'light', 'dark'].contains(d['theme'])
                        ? d['theme'] as String
                        : 'system',
                    key: ValueKey(d['theme']),
                    decoration: const InputDecoration(labelText: 'Appearance'),
                    items: const [
                      DropdownMenuItem(
                        value: 'system',
                        child: Text('Use device theme'),
                      ),
                      DropdownMenuItem(value: 'light', child: Text('Light')),
                      DropdownMenuItem(value: 'dark', child: Text('Dark')),
                    ],
                    onChanged: saving
                        ? null
                        : (v) {
                            if (v != null) {
                              save({'theme': v});
                            }
                          },
                  ),
                  SwitchListTile(
                    title: const Text('In-app notifications'),
                    subtitle: const Text(
                      'Registration, attendance and event updates',
                    ),
                    value: d['inAppNotifications'] != false,
                    onChanged: saving
                        ? null
                        : (v) => save({'inAppNotifications': v}),
                  ),
                  SwitchListTile(
                    title: const Text('Registration emails'),
                    subtitle: const Text(
                      'Receive event confirmations by email',
                    ),
                    value: d['emailConfirmations'] != false,
                    onChanged: saving
                        ? null
                        : (v) => save({'emailConfirmations': v}),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('Reset password'),
              subtitle: Text(FirebaseAuth.instance.currentUser?.email ?? ''),
              trailing: const Icon(Icons.chevron_right),
              onTap: saving ? null : resetPassword,
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.school_outlined),
              title: Text('CampusSphere • 1.0'),
              subtitle: Text(
                'Discover your clubs. Find your events. Navigate your campus.\nMade for the SVECW community.',
              ),
            ),
          ),
        ],
      );
    },
  );
}
