import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'events_feed.dart';

String newTicketToken() {
  final random = Random.secure();
  return base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}

String ticketPayload(String eventId, String uid, String token) => jsonEncode({
  'app': 'CampusSphere',
  'version': 1,
  'eventId': eventId,
  'studentId': uid,
  'token': token,
});

class TicketCode {
  const TicketCode(this.eventId, this.studentId, this.token);
  final String eventId;
  final String studentId;
  final String token;
  static TicketCode parse(String raw) {
    if (raw.length > 2048) {
      throw const FormatException('Invalid ticket.');
    }
    final data = jsonDecode(raw);
    if (data is! Map || data['app'] != 'CampusSphere' || data['version'] != 1) {
      throw const FormatException('This is not a CampusSphere ticket.');
    }
    for (final key in ['eventId', 'studentId']) {
      if (data[key] is! String ||
          (data[key] as String).isEmpty ||
          (data[key] as String).length > 200 ||
          (data[key] as String).contains('/')) {
        throw const FormatException('Invalid ticket identifier.');
      }
    }
    if (data['token'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(data['token'] as String)) {
      throw const FormatException('Invalid ticket token.');
    }
    return TicketCode(
      data['eventId'] as String,
      data['studentId'] as String,
      data['token'] as String,
    );
  }
}

class QrTicketScreen extends StatefulWidget {
  const QrTicketScreen({super.key, required this.eventId});
  final String eventId;
  @override
  State<QrTicketScreen> createState() => _QrTicketScreenState();
}

class _QrTicketScreenState extends State<QrTicketScreen> {
  late final ticket = prepare();
  Future<String> prepare() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Please log in again.');
    }
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('registrations')
        .doc(widget.eventId);
    return FirebaseFirestore.instance.runTransaction<String>((
      transaction,
    ) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (data == null || data['status'] != 'registered') {
        throw StateError('No valid registration found.');
      }
      var token = data['ticketToken'] as String?;
      if (token == null) {
        token = newTicketToken();
        transaction.update(ref, {'ticketToken': token});
      }
      return ticketPayload(widget.eventId, uid, token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('My event ticket')),
      body: uid == null
          ? const Center(child: Text('Please log in.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('events')
                            .doc(widget.eventId)
                            .snapshots(),
                        builder: (context, event) {
                          if (event.hasError) {
                            return const Text(
                              'Event details could not be loaded.',
                            );
                          }
                          if (!event.hasData) {
                            return const LinearProgressIndicator();
                          }
                          final data = event.data!.data();
                          if (data == null) {
                            return const Text('Event is no longer available.');
                          }
                          if (data['status'] == 'cancelled') {
                            return const Text(
                              'Event cancelled. This ticket cannot be used for admission.',
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                eventText(data, 'title'),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(eventText(data, 'clubName')),
                              Text(
                                '${formatEventDate(eventDate(data, 'startAt'))} • ${formatEventTime(eventDate(data, 'startAt'))} IST',
                              ),
                              Text(eventText(data, 'venue')),
                              const SizedBox(height: 20),
                              FutureBuilder<String>(
                                future: ticket,
                                builder: (context, snapshot) {
                                  if (snapshot.hasError) {
                                    return const Text(
                                      'Could not load ticket. Check connection and published QR rules, then reopen this screen.',
                                    );
                                  }
                                  if (!snapshot.hasData) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  return Column(
                                    children: [
                                      Container(
                                        color: Colors.white,
                                        padding: const EdgeInsets.all(16),
                                        child: QrImageView(
                                          data: snapshot.data!,
                                          size: 260,
                                          backgroundColor: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Show this ticket to the event organizer. Keep it private.',
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.copy),
                                        label: const Text('Copy ticket code'),
                                        onPressed: () async {
                                          await Clipboard.setData(
                                            ClipboardData(text: snapshot.data!),
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Ticket code copied.',
                                                    ),
                                                  ),
                                                );
                                          }
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('checkins')
                            .doc(widget.eventId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Text(
                              'Attendance status could not be loaded.',
                            );
                          }
                          if (!snapshot.hasData) {
                            return const LinearProgressIndicator();
                          }
                          final data = snapshot.data!.data();
                          return Text(
                            data == null
                                ? 'Not checked in yet.'
                                : 'Checked in • ${formatEventDate(eventDate(data, 'checkedInAt'))} ${formatEventTime(eventDate(data, 'checkedInAt'))} IST',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB83268),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
