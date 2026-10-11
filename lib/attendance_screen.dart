import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'events_feed.dart';
import 'admin_checkin.dart';

Stream<QuerySnapshot<Map<String, dynamic>>> attendanceStream(String eventId) =>
    FirebaseFirestore.instance
        .collectionGroup('checkins')
        .where('eventId', isEqualTo: eventId)
        .snapshots();

class AttendedCount extends StatelessWidget {
  const AttendedCount({super.key, required this.eventId});
  final String eventId;
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: attendanceStream(eventId),
        builder: (context, snapshot) => Text(
          snapshot.hasError
              ? 'Attendance count unavailable: ${snapshot.error}'
              : snapshot.hasData
              ? '${snapshot.data!.size} attended'
              : 'Loading attendance…',
        ),
      );
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    required this.eventId,
    required this.title,
  });
  final String eventId;
  final String title;
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final stream = attendanceStream(widget.eventId);
  String search = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Attendance list')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: SelectableText(
              'Could not load attendance.\n${snapshot.error}',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.toList()
          ..sort(
            (a, b) => (eventDate(b.data(), 'checkedInAt') ?? DateTime(2000))
                .compareTo(
                  eventDate(a.data(), 'checkedInAt') ?? DateTime(2000),
                ),
          );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .doc(widget.eventId)
                  .snapshots(),
              builder: (context, event) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${event.data?.data()?['registeredCount'] ?? '…'} registered • ${docs.length} attended',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR'),
                    onPressed: event.data?.data()?['status'] == 'scheduled'
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminCheckinScreen(
                                eventId: widget.eventId,
                                title: widget.title,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search student name or email',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => search = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 16),
            if (docs.isEmpty) const Text('No students have checked in yet.'),
            for (final doc in docs)
              AttendanceStudent(
                key: ValueKey(doc.reference.path),
                data: doc.data(),
                search: search,
              ),
          ],
        );
      },
    ),
  );
}

class AttendanceStudent extends StatefulWidget {
  const AttendanceStudent({
    super.key,
    required this.data,
    required this.search,
  });
  final Map<String, dynamic> data;
  final String search;
  @override
  State<AttendanceStudent> createState() => _AttendanceStudentState();
}

class _AttendanceStudentState extends State<AttendanceStudent> {
  late final profile = FirebaseFirestore.instance
      .collection('users')
      .doc(widget.data['studentId'] as String)
      .get();
  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    future: profile,
    builder: (context, snapshot) {
      final d = snapshot.data?.data();
      final name =
          d?['name'] ??
          (snapshot.hasError
              ? 'Profile unavailable'
              : snapshot.connectionState == ConnectionState.waiting
              ? 'Loading student…'
              : 'Student');
      final email = d?['email'] ?? widget.data['studentId'];
      if (widget.search.isNotEmpty &&
          !'$name $email'.toLowerCase().contains(widget.search)) {
        return const SizedBox.shrink();
      }
      final at = eventDate(widget.data, 'checkedInAt');
      return Card(
        child: ListTile(
          leading: const Icon(Icons.verified, color: Colors.green),
          title: Text('$name'),
          subtitle: Text(
            '$email\nAttended • ${formatEventDate(at)} ${formatEventTime(at)} IST',
          ),
          isThreeLine: true,
        ),
      );
    },
  );
}
