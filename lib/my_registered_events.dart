import 'qr_ticket.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'events_feed.dart';

class MyRegisteredEvents extends StatefulWidget {
  const MyRegisteredEvents({super.key});

  @override
  State<MyRegisteredEvents> createState() => _MyRegisteredEventsState();
}

class _MyRegisteredEventsState extends State<MyRegisteredEvents> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? registrations;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      registrations = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('registrations')
          .orderBy('registeredAt', descending: true)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (registrations == null) {
      return const Text('Please log in to view registrations.');
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: registrations,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Could not load registrations. Check Firestore rules.',
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final documents = snapshot.data!.docs;

        if (documents.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'You have not registered for any events yet.',
              style: TextStyle(color: Color(0xFF765B68)),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${documents.length} registered events'),
            const SizedBox(height: 16),
            for (final document in documents)
              RegisteredEventItem(
                key: ValueKey(document.id),
                eventId: document.id,
              ),
          ],
        );
      },
    );
  }
}

class RegisteredEventItem extends StatefulWidget {
  const RegisteredEventItem({super.key, required this.eventId});

  final String eventId;

  @override
  State<RegisteredEventItem> createState() => _RegisteredEventItemState();
}

class _RegisteredEventItemState extends State<RegisteredEventItem> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> event;

  @override
  void initState() {
    super.initState();

    event = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: event,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Could not load a registered event.'),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          );
        }

        final data = snapshot.data!.data();

        if (data == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('A registered event is no longer available.'),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                data['status'] == 'cancelled'
                    ? 'CANCELLED EVENT • Registration retained'
                    : 'REGISTERED',
                style: const TextStyle(
                  color: Color(0xFFB83268),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (data['status'] != 'cancelled')
              OutlinedButton.icon(
                icon: const Icon(Icons.qr_code),
                label: const Text('View QR ticket'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QrTicketScreen(eventId: widget.eventId),
                  ),
                ),
              ),
            RegistrationEmailStatus(eventId: widget.eventId),
            EventCard(
              data: data,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailsScreen(eventId: widget.eventId),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class RegistrationEmailStatus extends StatelessWidget {
  const RegistrationEmailStatus({super.key, required this.eventId});
  final String eventId;
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('email_receipts')
        .doc(eventId)
        .snapshots(),
    builder: (context, snapshot) {
      final status = snapshot.data?.data()?['status'];
      final label = status == 'sent'
          ? 'Confirmation email sent. Check your inbox or spam folder.'
          : status == 'queued'
          ? 'Confirmation email queued.'
          : status == 'failed'
          ? 'Email could not be sent. Your event registration is still confirmed.'
          : status == 'skipped'
          ? 'Email confirmation not requested.'
          : 'Registration confirmed. No email delivery status is available yet.';
      return label.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(label),
            );
    },
  );
}
