import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'events_feed.dart';

CollectionReference<Map<String, dynamic>> notificationRef() => FirebaseFirestore
    .instance
    .collection('users')
    .doc(FirebaseAuth.instance.currentUser!.uid)
    .collection('notifications');

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: notificationRef().where('read', isEqualTo: false).snapshots(),
        builder: (context, snapshot) => IconButton(
          tooltip: 'Notifications',
          onPressed: onPressed,
          icon: Badge(
            isLabelVisible: (snapshot.data?.size ?? 0) > 0,
            label: Text('${snapshot.data?.size ?? 0}'),
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
      );
}

class NotificationsPanel extends StatefulWidget {
  const NotificationsPanel({super.key, this.preview = false});
  final bool preview;
  @override
  State<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<NotificationsPanel> {
  late final stream = notificationRef()
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots();
  bool busy = false;
  Future<void> markRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    setState(() => busy = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in docs) {
        if (doc.data()['read'] != true) {
          batch.update(doc.reference, {'read': true});
        }
      }
      await batch.commit();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not mark notifications read.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text(
          'Could not load notifications. Check connection and published rules.',
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final docs = snapshot.data!.docs;
      if (docs.isEmpty) {
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'You’re all caught up. New registration and event updates will appear here.',
            ),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.preview)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: busy ? null : () => markRead(docs),
                child: const Text('Mark these notifications read'),
              ),
            ),
          for (final doc in widget.preview ? docs.take(3) : docs)
            Card(
              child: ListTile(
                leading: Icon(
                  doc.data()['type'] == 'checkin'
                      ? Icons.verified_outlined
                      : Icons.notifications_active_outlined,
                  color: doc.data()['read'] == true
                      ? Colors.grey
                      : Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  '${doc.data()['title'] ?? 'Campus update'}',
                  style: TextStyle(
                    fontWeight: doc.data()['read'] == true
                        ? FontWeight.normal
                        : FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${doc.data()['body'] ?? ''}\n${formatEventDate(eventDate(doc.data(), 'createdAt'))} • ${formatEventTime(eventDate(doc.data(), 'createdAt'))} IST',
                ),
                isThreeLine: true,
                onTap: busy
                    ? null
                    : () async {
                        await markRead([doc]);
                        final eventId = doc.data()['eventId'];
                        if (!context.mounted ||
                            eventId is! String ||
                            eventId.isEmpty) {
                          return;
                        }
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EventDetailsScreen(eventId: eventId),
                          ),
                        );
                      },
              ),
            ),
        ],
      );
    },
  );
}
