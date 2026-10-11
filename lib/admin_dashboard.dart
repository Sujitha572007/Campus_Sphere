import 'attendance_screen.dart';
import 'settings_screen.dart';
import 'admin_checkin.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_event_form.dart';
import 'events_feed.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late final events = FirebaseFirestore.instance
      .collection('events')
      .snapshots();

  String search = '';
  String filter = 'All';
  final busy = <String>{};
  bool signingOut = false;

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> logout() async {
    setState(() => signingOut = true);

    try {
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        widget.onSignedOut();
      }
    } catch (_) {
      if (mounted) {
        setState(() => signingOut = false);
        message('Logout failed. Please retry.');
      }
    }
  }

  void edit([String? id]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminEventForm(eventId: id)),
    );
  }

  Future<void> change(String id, String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$action event?'),
        content: Text(
          action == 'Delete'
              ? 'Permanently delete this event? Only events with zero '
                    'registrations can be deleted.'
              : action == 'Complete'
              ? 'Mark the event completed now and close registration?'
              : 'Cancel this event and close registration? Existing '
                    'registrations will remain visible to students.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      message('Please log in again.');
      return;
    }

    setState(() => busy.add(id));

    try {
      final ref = FirebaseFirestore.instance.collection('events').doc(id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final current = await transaction.get(ref);
        final data = current.data();

        if (data == null) {
          throw StateError('This event no longer exists.');
        }

        if (action == 'Delete') {
          if (data['registeredCount'] != 0) {
            throw StateError(
              'This event has registrations. Cancel it instead.',
            );
          }

          transaction.delete(ref);
        } else {
          final changes = <String, dynamic>{
            'status': action == 'Complete' ? 'completed' : 'cancelled',
            'registrationOpen': false,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': user.uid,
          };

          if (action == 'Complete') {
            changes['completedAt'] = FieldValue.serverTimestamp();
          }

          transaction.update(ref, changes);
        }
      });

      if (mounted) {
        message(action == 'Delete' ? 'Event deleted.' : 'Event updated.');
      }
    } catch (error) {
      if (mounted) {
        message(
          error is StateError
              ? error.message.toString()
              : 'Could not update event. Check admin access and connection.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy.remove(id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFC),
      appBar: AppBar(
        title: const Text('CampusSphere • Admin'),
        actions: [
          IconButton(
            tooltip: 'Admin access requests',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminRequestsScreen()),
            ),
            icon: const Icon(Icons.manage_accounts_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Settings')),
                  body: const SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: SettingsPanel(),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: signingOut ? null : logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add event'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: events,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Could not load events. Publish the admin rules '
                      'and check your role.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final documents = snapshot.data!.docs;

              final total = documents.fold<int>(
                0,
                (totalCount, doc) =>
                    totalCount +
                    ((doc.data()['registeredCount'] as num?)?.toInt() ?? 0),
              );

              final now = DateTime.now();

              final visible =
                  documents.where((doc) {
                    final data = doc.data();

                    final status = data['status'] == 'cancelled'
                        ? 'Cancelled'
                        : eventIsCompleted(data, now)
                        ? 'Completed'
                        : 'Upcoming';

                    final searchText =
                        '${data['title'] ?? ''} ${data['clubName'] ?? ''}'
                            .toLowerCase();

                    return (filter == 'All' || filter == status) &&
                        searchText.contains(search);
                  }).toList()..sort(
                    (a, b) => (eventDate(b.data(), 'startAt') ?? DateTime(2000))
                        .compareTo(
                          eventDate(a.data(), 'startAt') ?? DateTime(2000),
                        ),
                  );

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  const Text(
                    'Manage campus events',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${documents.length} events • '
                    '$total registrations (across events)',
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search events or clubs',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        search = value.trim().toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['All', 'Upcoming', 'Completed', 'Cancelled'].map(
                      (value) {
                        return ChoiceChip(
                          label: Text(value),
                          selected: filter == value,
                          onSelected: (_) {
                            setState(() => filter = value);
                          },
                        );
                      },
                    ).toList(),
                  ),
                  const SizedBox(height: 16),
                  if (visible.isEmpty)
                    const Text('No events match this filter.'),
                  for (final doc in visible)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (doc.data()['isDemo'] == true)
                              const Text(
                                'DEMO EVENT',
                                style: TextStyle(color: Color(0xFFB83268)),
                              ),
                            Text(
                              eventText(doc.data(), 'title'),
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${eventText(doc.data(), 'clubName')} • '
                              '${formatEventDate(eventDate(doc.data(), 'startAt'))}',
                            ),
                            Text(
                              '${eventStatusLabel(doc.data())} • '
                              '${doc.data()['registeredCount'] ?? 0} '
                              'registered',
                            ),
                            AttendedCount(eventId: doc.id),
                            const SizedBox(height: 12),
                            if (busy.contains(doc.id))
                              const LinearProgressIndicator(),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: const Text('Scan QR'),
                                  onPressed: doc.data()['status'] == 'scheduled'
                                      ? () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AdminCheckinScreen(
                                              eventId: doc.id,
                                              title: eventText(
                                                doc.data(),
                                                'title',
                                              ),
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                OutlinedButton.icon(
                                  onPressed: busy.contains(doc.id)
                                      ? null
                                      : () => edit(doc.id),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Edit'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdminRegistrationsScreen(
                                        eventId: doc.id,
                                        title: eventText(doc.data(), 'title'),
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.people_outline),
                                  label: const Text('Registered students'),
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.fact_check_outlined),
                                  label: const Text('Attendance list'),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AttendanceScreen(
                                        eventId: doc.id,
                                        title: eventText(doc.data(), 'title'),
                                      ),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed:
                                      busy.contains(doc.id) ||
                                          doc.data()['status'] != 'scheduled'
                                      ? null
                                      : () => change(doc.id, 'Complete'),
                                  child: const Text('Mark completed'),
                                ),
                                TextButton(
                                  onPressed:
                                      busy.contains(doc.id) ||
                                          doc.data()['status'] == 'cancelled'
                                      ? null
                                      : () => change(doc.id, 'Cancel'),
                                  child: const Text('Cancel event'),
                                ),
                                TextButton(
                                  onPressed:
                                      busy.contains(doc.id) ||
                                          doc.data()['registeredCount'] != 0
                                      ? null
                                      : () => change(doc.id, 'Delete'),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class AdminRegistrationsScreen extends StatefulWidget {
  const AdminRegistrationsScreen({
    super.key,
    required this.eventId,
    required this.title,
  });

  final String eventId;
  final String title;

  @override
  State<AdminRegistrationsScreen> createState() =>
      _AdminRegistrationsScreenState();
}

class _AdminRegistrationsScreenState extends State<AdminRegistrationsScreen> {
  late final registrations = FirebaseFirestore.instance
      .collectionGroup('registrations')
      .where('eventId', isEqualTo: widget.eventId)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registered students')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: registrations,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                'Could not load registrations. Check admin access '
                'and the collection-group index.\n${snapshot.error}',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.toList()
            ..sort(
              (a, b) => (eventDate(b.data(), 'registeredAt') ?? DateTime(2000))
                  .compareTo(
                    eventDate(a.data(), 'registeredAt') ?? DateTime(2000),
                  ),
            );

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text('${docs.length} registered students'),
              const SizedBox(height: 16),
              if (docs.isEmpty) const Text('No students registered yet.'),
              for (final doc in docs)
                RegisteredStudentTile(
                  key: ValueKey(doc.reference.path),
                  registration: doc.data(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class RegisteredStudentTile extends StatefulWidget {
  const RegisteredStudentTile({super.key, required this.registration});

  final Map<String, dynamic> registration;

  @override
  State<RegisteredStudentTile> createState() => _RegisteredStudentTileState();
}

class _RegisteredStudentTileState extends State<RegisteredStudentTile> {
  late final profile = FirebaseFirestore.instance
      .collection('users')
      .doc(widget.registration['studentId'] as String)
      .get();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: profile,
      builder: (context, snapshot) {
        final user = snapshot.data?.data();
        final date = eventDate(widget.registration, 'registeredAt');

        final name =
            user?['name'] as String? ??
            (snapshot.hasError
                ? 'Profile could not be loaded'
                : snapshot.connectionState == ConnectionState.waiting
                ? 'Loading student…'
                : 'Student profile unavailable');

        return Card(
          child: ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(name),
            subtitle: Text(
              '${user?['email'] ?? widget.registration['studentId']}\n'
              'Year ${widget.registration['studentYear']} • '
              '${formatEventDate(date)} '
              '${formatEventTime(date)} IST',
            ),
            trailing: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.registration['studentId'] as String)
                  .collection('checkins')
                  .doc(widget.registration['eventId'] as String)
                  .snapshots(),
              builder: (context, attendance) => Tooltip(
                message: attendance.hasError
                    ? 'Attendance unavailable'
                    : attendance.data?.exists == true
                    ? 'Attended • ${formatEventDate(eventDate(attendance.data!.data()!, 'checkedInAt'))} ${formatEventTime(eventDate(attendance.data!.data()!, 'checkedInAt'))} IST'
                    : 'Not checked in',
                child: Icon(
                  attendance.data?.exists == true
                      ? Icons.verified
                      : Icons.pending_outlined,
                  color: attendance.data?.exists == true
                      ? Colors.green
                      : Colors.grey,
                ),
              ),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  late final requests = FirebaseFirestore.instance
      .collection('admin_requests')
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin access requests')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: requests,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load requests.'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Only the Firebase project owner approves access: '
                'set users/{UID}.role to admin in Firebase Console. '
                'Requests do not grant privileges.',
              ),
              const SizedBox(height: 16),
              if (snapshot.data!.docs.isEmpty)
                const Text('No admin requests yet.'),
              for (final doc in snapshot.data!.docs)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      '${doc.data()['name']}\n'
                      '${doc.data()['email']}\n'
                      'UID: ${doc.id}\n'
                      'Request status: ${doc.data()['status']}',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
