import 'qr_ticket.dart';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegistrationException implements Exception {
  const RegistrationException(this.message);

  final String message;
}

class EventRegistrationService {
  static String? closedReason(Map<String, dynamic> data, DateTime now) {
    if (data['status'] == 'cancelled') {
      return 'This event has been cancelled.';
    }

    if (data['status'] != 'scheduled') {
      return 'Registration is unavailable for this event.';
    }

    final start = data['startAt'];
    final end = data['endAt'];

    if (start is! Timestamp ||
        end is! Timestamp ||
        !end.toDate().isAfter(start.toDate())) {
      return 'The event dates are not configured correctly.';
    }

    if (!start.toDate().isAfter(now)) {
      return 'Registration closed: the event has started.';
    }

    if (data['registrationOpen'] != true) {
      return 'Registration is closed.';
    }

    final deadline = data['registrationDeadline'];

    if (deadline != null) {
      if (deadline is! Timestamp) {
        return 'The registration deadline is not configured correctly.';
      }

      if (!deadline.toDate().isAfter(now)) {
        return 'The registration deadline has passed.';
      }
    }

    final count = data['registeredCount'];
    final capacity = data['capacity'];

    if (count is! int || count < 0) {
      return 'The seat count is not configured correctly.';
    }

    // Missing capacity or zero means no capacity limit.
    if (capacity != null && (capacity is! int || capacity < 0)) {
      return 'The event capacity is not configured correctly.';
    }

    if (capacity is int && capacity > 0 && count >= capacity) {
      return 'This event is full.';
    }

    return null;
  }

  // true: new registration; false: already registered.
  static Future<bool> register(String eventId, int year) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw const RegistrationException('Please log in first.');
    }

    if (year < 1 || year > 4) {
      throw const RegistrationException('Select a valid study year.');
    }

    final db = FirebaseFirestore.instance;
    final eventRef = db.collection('events').doc(eventId);

    final registrationRef = db
        .collection('users')
        .doc(user.uid)
        .collection('registrations')
        .doc(eventId);

    return db.runTransaction<bool>((transaction) async {
      final eventSnapshot = await transaction.get(eventRef);
      final registrationSnapshot = await transaction.get(registrationRef);
      final preference = await transaction.get(
        db
            .collection('users')
            .doc(user.uid)
            .collection('preferences')
            .doc('settings'),
      );

      if (registrationSnapshot.exists) {
        return false;
      }

      final data = eventSnapshot.data();

      if (data == null) {
        throw const RegistrationException('This event is no longer available.');
      }

      final reason = closedReason(data, DateTime.now());

      if (reason != null) {
        throw RegistrationException(reason);
      }

      final eligibleYears = data['eligibleYears'];

      if (eligibleYears is! List) {
        throw const RegistrationException(
          'Student eligibility has not been configured.',
        );
      }

      if (eligibleYears.isNotEmpty && !eligibleYears.contains(year)) {
        throw const RegistrationException(
          'This event is not open to your selected study year.',
        );
      }

      final count = data['registeredCount'] as int;

      transaction.set(registrationRef, {
        'eventId': eventId,
        'studentId': user.uid,
        'studentYear': year,
        'status': 'registered',
        'registeredAt': FieldValue.serverTimestamp(),
        'ticketToken': newTicketToken(),
      });

      transaction.update(eventRef, {'registeredCount': count + 1});
      if (preference.data()?['inAppNotifications'] != false) {
        transaction.set(
          db
              .collection('users')
              .doc(user.uid)
              .collection('notifications')
              .doc('registration-$eventId'),
          {
            'type': 'registration',
            'eventId': eventId,
            'title': 'Registration confirmed',
            'body':
                'You are successfully registered for ${data['title']}. Your QR ticket is in My Registered Events.',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      }

      return true;
    });
  }
}

class EventRegistrationPanel extends StatefulWidget {
  const EventRegistrationPanel({
    super.key,
    required this.eventId,
    required this.eventData,
  });

  final String eventId;
  final Map<String, dynamic> eventData;

  @override
  State<EventRegistrationPanel> createState() => _EventRegistrationPanelState();
}

class _EventRegistrationPanelState extends State<EventRegistrationPanel> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? registration;
  Timer? timer;
  int? selectedYear;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      registration = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('registrations')
          .doc(widget.eventId)
          .snapshots();
    }

    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> register() async {
    final year = selectedYear;

    if (year == null) {
      message('Please select your study year.');
      return;
    }

    setState(() => saving = true);

    try {
      final created = await EventRegistrationService.register(
        widget.eventId,
        year,
      );

      if (!mounted) {
        return;
      }

      message(
        created
            ? 'You are successfully registered for this event!'
            : 'You are already registered for this event.',
      );
    } on RegistrationException catch (error) {
      if (mounted) {
        message(error.message);
      }
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      if (error.code == 'permission-denied') {
        message(
          'Registration was denied. The event may have closed or '
          'filled up. Also check that the new rules are published.',
        );
      } else if (error.code == 'unavailable') {
        message('Registration needs an internet connection. Try again.');
      } else {
        message('Could not register (${error.code}). Please try again.');
      }
    } catch (_) {
      if (mounted) {
        message('Could not register. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (registration == null) {
      return const Text('Please log in to register.');
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: registration,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Could not load your registration. Check Firestore rules.',
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.exists) {
          final cancelled = widget.eventData['status'] == 'cancelled';

          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFCEAF1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!cancelled)
                  FilledButton.icon(
                    icon: const Icon(Icons.qr_code),
                    label: const Text('View QR ticket'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QrTicketScreen(eventId: widget.eventId),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFFB83268),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        cancelled
                            ? 'You registered for this event, but it has '
                                  'since been cancelled.'
                            : 'Registered! Your registration is saved '
                                  'in My Registered Events.',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        final reason = EventRegistrationService.closedReason(
          widget.eventData,
          DateTime.now(),
        );

        final count = widget.eventData['registeredCount'];
        final capacity = widget.eventData['capacity'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (count is int && capacity is int && capacity > 0) ...[
              Text(
                'Seats available: '
                '${(capacity - count).clamp(0, capacity)} / $capacity',
              ),
              const SizedBox(height: 16),
            ],
            if (reason != null)
              Text(reason, style: const TextStyle(color: Color(0xFF765B68)))
            else ...[
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Your study year',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1st year')),
                  DropdownMenuItem(value: 2, child: Text('2nd year')),
                  DropdownMenuItem(value: 3, child: Text('3rd year')),
                  DropdownMenuItem(value: 4, child: Text('4th year')),
                ],
                onChanged: saving
                    ? null
                    : (value) => setState(() => selectedYear = value),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: saving || selectedYear == null ? null : register,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB83268),
                  minimumSize: const Size(double.infinity, 52),
                ),
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.how_to_reg_rounded),
                label: Text(saving ? 'Registering…' : 'Register'),
              ),
            ],
          ],
        );
      },
    );
  }
}
