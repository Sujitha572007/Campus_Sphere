import 'package:firebase_core/firebase_core.dart' as core;



import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'qr_ticket.dart';

class AdminCheckinScreen extends StatefulWidget {
  const AdminCheckinScreen({
    super.key,
    required this.eventId,
    required this.title,
  });

  final String eventId;
  final String title;

  @override
  State<AdminCheckinScreen> createState() => _AdminCheckinScreenState();
}

class _AdminCheckinScreenState extends State<AdminCheckinScreen> {
  final code = TextEditingController();

  bool camera = false;
  bool busy = false;
  String result = '';

  bool get cameraSupported =>
      kIsWeb ||
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ].contains(defaultTargetPlatform);

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> verify(String raw) async {
    if (busy || raw.trim().isEmpty) {
      return;
    }

    setState(() {
      busy = true;
      camera = false;
      result = 'Checking ticket…';
    });

    try {
      final ticket = TicketCode.parse(raw.trim());

      if (ticket.eventId != widget.eventId) {
        throw StateError('This ticket is for a different event.');
      }

      final db = FirebaseFirestore.instance;
      final activeAdmin = FirebaseAuth.instance.currentUser;
      if (activeAdmin == null) {
        throw StateError('Please log in as an admin again.');
      }
      final role = await db.collection('users').doc(activeAdmin.uid).get();
      if (role.data()?['role'] != 'admin') {
        throw StateError('This account is not an approved admin.');
      }

      final profile = await db.collection('users').doc(ticket.studentId).get();

      if (!mounted) {
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm student check-in'),
          content: Text(
            '${profile.data()?['name'] ?? 'Student'}\n'
            '${profile.data()?['email'] ?? ticket.studentId}\n\n'
            '${widget.title}\n'
            'Check the student identity before admitting.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Check in'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        if (mounted) {
          setState(() => result = 'Check-in not recorded.');
        }

        return;
      }

      final adminUid = FirebaseAuth.instance.currentUser?.uid;

      if (adminUid == null) {
        throw StateError('Please log in again.');
      }

      final eventRef = db.collection('events').doc(ticket.eventId);

      final regRef = db
          .collection('users')
          .doc(ticket.studentId)
          .collection('registrations')
          .doc(ticket.eventId);

      final attendanceRef = db
          .collection('users')
          .doc(ticket.studentId)
          .collection('checkins')
          .doc(ticket.eventId);

      final outcome = await db.runTransaction<String>((transaction) async {
        final event = (await transaction.get(eventRef)).data();
        final registration = (await transaction.get(regRef)).data();
        final attendance = await transaction.get(attendanceRef);
        final preference = await transaction.get(
          db
              .collection('users')
              .doc(ticket.studentId)
              .collection('preferences')
              .doc('settings'),
        );

        if (registration == null ||
            registration['status'] != 'registered' ||
            registration['ticketToken'] != ticket.token ||
            registration['eventId'] != ticket.eventId ||
            registration['studentId'] != ticket.studentId) {
          throw StateError('Invalid ticket or missing registration.');
        }

        if (attendance.exists) {
          return 'Already checked in. No duplicate attendance recorded.';
        }

        if (event == null || event['status'] != 'scheduled') {
          throw StateError(
            'Check-in is unavailable for cancelled or completed events.',
          );
        }

        final start = event['startAt'];
        final end = event['endAt'];
        final now = DateTime.now();

        if (start is! Timestamp ||
            end is! Timestamp ||
            !end.toDate().isAfter(start.toDate()) ||
            now.isBefore(start.toDate().subtract(const Duration(hours: 2))) ||
            now.isAfter(end.toDate())) {
          throw StateError(
            'Check-in opens two hours before the event '
            'and closes at its end time.',
          );
        }

        transaction.set(attendanceRef, {
          'eventId': ticket.eventId,
          'studentId': ticket.studentId,
          'checkedInAt': FieldValue.serverTimestamp(),
          'checkedInBy': adminUid,
        });

        if (preference.data()?['inAppNotifications'] != false) {
          transaction.set(
            db
                .collection('users')
                .doc(ticket.studentId)
                .collection('notifications')
                .doc('checkin-${ticket.eventId}'),
            {
              'type': 'checkin',
              'eventId': ticket.eventId,
              'title': 'Attendance recorded',
              'body': 'You have checked in for ${event['title']}.',
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
        }
        return '${profile.data()?['name'] ?? 'Student'} successfully checked in! Attendance is saved.';
      });

      if (mounted) {
        setState(() => result = outcome);
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => result = error.message);
      }
    } on StateError catch (error) {
      if (mounted) {
        setState(() => result = error.message);
      }
    } on core.FirebaseException catch (error) {
      if (mounted) {
        final hint = error.code == 'permission-denied'
            ? 'Check that the updated Firestore rules are deployed and this account has role admin.'
            : error.code == 'unavailable'
            ? 'Reconnect to the internet and retry.'
            : error.code == 'failed-precondition'
            ? 'Check the Firebase error details below.'
            : 'Retry after checking the event and your connection.';
        setState(
          () => result =
              'Check-in failed (${error.code}). $hint\n${error.message ?? ''}',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => result = 'Check-in failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event check-in')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Scan a student ticket or paste its copied code. '
                  'Check-in opens 2 hours before the event '
                  'and closes at the event end time.',
                ),
                const SizedBox(height: 16),
                if (camera)
                  SizedBox(
                    height: 320,
                    child: MobileScanner(
                      onDetect: (capture) {
                        for (final barcode in capture.barcodes) {
                          final raw = barcode.rawValue;

                          if (raw != null && !busy) {
                            verify(raw);
                            break;
                          }
                        }
                      },
                      errorBuilder: (context, error) => const Center(
                        child: Text(
                          'Camera unavailable. Allow camera access '
                          'or paste the ticket code below.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                if (cameraSupported)
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => setState(() => camera = !camera),
                    icon: Icon(camera ? Icons.stop : Icons.qr_code_scanner),
                    label: Text(camera ? 'Stop camera' : 'Scan next ticket'),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: code,
                  enabled: !busy,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Paste ticket code',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: busy ? null : () => verify(code.text),
                  child: const Text('Verify and check in'),
                ),
                if (busy) const LinearProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  result,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
