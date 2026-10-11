import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'event_registration.dart';

String eventText(Map<String, dynamic> data, String key) {
  final value = data[key];
  return value is String ? value.trim() : '';
}

DateTime? eventDate(Map<String, dynamic> data, String key) {
  final value = data[key];
  return value is Timestamp ? value.toDate() : null;
}

// Display campus times in India.
DateTime indiaTime(DateTime date) {
  return date.toUtc().add(const Duration(hours: 5, minutes: 30));
}

String formatEventDate(DateTime? date) {
  if (date == null) {
    return 'Date unavailable';
  }

  final value = indiaTime(date);

  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';
}

String formatEventTime(DateTime? date) {
  if (date == null) {
    return 'Time unavailable';
  }

  final value = indiaTime(date);
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $period';
}

String eligibleYearText(Map<String, dynamic> data) {
  final years = data['eligibleYears'];

  if (years is! List) {
    return 'Not specified';
  }
  if (years.isEmpty) {
    return 'All study years';
  }

  const labels = {1: '1st year', 2: '2nd year', 3: '3rd year', 4: '4th year'};

  return years.map((year) => labels[year] ?? '$year').join(', ');
}

bool eventIsCompleted(Map<String, dynamic> data, DateTime now) {
  final end = eventDate(data, 'endAt');

  return eventText(data, 'status') == 'completed' ||
      (end != null && !end.isAfter(now));
}

String eventStatusLabel(Map<String, dynamic> data) {
  final status = eventText(data, 'status');

  if (status == 'cancelled') {
    return 'Cancelled';
  }

  if (eventIsCompleted(data, DateTime.now())) {
    return 'Completed';
  }

  return EventRegistrationService.closedReason(data, DateTime.now()) ??
      'Registration open';
}

class EventsFeed extends StatefulWidget {
  const EventsFeed({
    super.key,
    this.clubId,
    this.past = false,
    this.featuredOnly = false,
    this.limit,
  }) : assert(limit == null || limit >= 0);

  final String? clubId;
  final bool past;
  final bool featuredOnly;
  final int? limit;

  @override
  State<EventsFeed> createState() => _EventsFeedState();
}

class _EventsFeedState extends State<EventsFeed> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> events;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    connect();

    // Refresh event classification when time passes.
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void connect() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'events',
    );

    if (widget.clubId != null) {
      query = query.where('clubId', isEqualTo: widget.clubId);
    }

    events = query.snapshots();
  }

  @override
  void didUpdateWidget(covariant EventsFeed oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.clubId != widget.clubId) {
      connect();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // Discard old results when switching between clubs.
      key: ValueKey(widget.clubId),
      stream: events,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Could not load events. Check your connection '
              'and Firestore rules.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final now = DateTime.now();

        final results = snapshot.data!.docs.where((document) {
          final data = document.data();
          final start = eventDate(data, 'startAt');
          final end = eventDate(data, 'endAt');
          final status = eventText(data, 'status');

          if (start == null || end == null || !end.isAfter(start)) {
            return false;
          }

          // Cancelled events remain accessible in My Registered Events.
          if (status != 'scheduled' && status != 'completed') {
            return false;
          }

          if (widget.featuredOnly && data['featured'] != true) {
            return false;
          }

          final completed = eventIsCompleted(data, now);

          return widget.past ? completed : !completed;
        }).toList();

        results.sort((a, b) {
          final first = widget.past
              ? eventDate(a.data(), 'completedAt') ??
                    eventDate(a.data(), 'endAt')!
              : eventDate(a.data(), 'startAt')!;

          final second = widget.past
              ? eventDate(b.data(), 'completedAt') ??
                    eventDate(b.data(), 'endAt')!
              : eventDate(b.data(), 'startAt')!;

          // Past: latest completion first.
          // Upcoming: earliest start first.
          final comparison = widget.past
              ? second.compareTo(first)
              : first.compareTo(second);

          return comparison != 0 ? comparison : a.id.compareTo(b.id);
        });

        // Apply the preview limit after sorting.
        final visible = widget.limit == null
            ? results
            : results.take(widget.limit!).toList();

        if (visible.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              widget.past
                  ? 'No past events yet.'
                  : widget.featuredOnly
                  ? 'No featured events at the moment.'
                  : 'No upcoming events at the moment.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return Column(
          children: [
            for (final document in visible)
              EventCard(
                key: ValueKey(document.id),
                data: document.data(),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventDetailsScreen(eventId: document.id),
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

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start = eventDate(data, 'startAt');
    final image = eventText(data, 'imageUrl');

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFF1DFE6)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (image.isNotEmpty)
              Image.network(
                image,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data['isDemo'] == true)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        'DEMO EVENT',
                        style: TextStyle(
                          color: Color(0xFFB83268),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Text(
                    eventText(data, 'title'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    eventText(data, 'clubName'),
                    style: const TextStyle(
                      color: Color(0xFFB83268),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    eventText(data, 'description'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${formatEventDate(start)} • '
                    '${formatEventTime(start)} IST',
                  ),
                  const SizedBox(height: 6),
                  Text(eventText(data, 'venue')),
                  const SizedBox(height: 12),
                  Text(
                    eventStatusLabel(data),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Text(
                        'View event details',
                        style: TextStyle(color: Color(0xFFB83268)),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: Color(0xFFB83268),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> event;
  Timer? timer;

  @override
  void initState() {
    super.initState();

    event = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .snapshots();

    timer = Timer.periodic(const Duration(minutes: 1), (_) {
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

  Widget detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.isEmpty ? 'Not specified' : value,
            style: const TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFC),
      appBar: AppBar(title: const Text('Event Details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: event,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load this event.'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data();

          if (data == null) {
            return const Center(
              child: Text('This event is no longer available.'),
            );
          }

          final start = eventDate(data, 'startAt');
          final end = eventDate(data, 'endAt');
          final completedAt = eventDate(data, 'completedAt');
          final deadline = eventDate(data, 'registrationDeadline');
          final image = eventText(data, 'imageUrl');
          final capacity = data['capacity'];

          final completed = eventIsCompleted(data, DateTime.now());
          final cancelled = eventText(data, 'status') == 'cancelled';

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (data['isDemo'] == true)
                    const Card(
                      color: Color(0xFFFCEAF1),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Demo event: dates, venues, certificates, '
                          'and prizes are fictional test data. '
                          'Registration here is for testing.',
                        ),
                      ),
                    ),
                  if (image.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        image,
                        height: 220,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stack) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    eventText(data, 'title'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  detail('Organizing club', eventText(data, 'clubName')),
                  detail('Description', eventText(data, 'description')),
                  detail('Category', eventText(data, 'category')),
                  detail('Event type', eventText(data, 'eventType')),
                  detail('Date', formatEventDate(start)),
                  detail(
                    'Time',
                    '${formatEventTime(start)} – '
                        '${formatEventTime(end)} IST',
                  ),
                  if (start != null &&
                      end != null &&
                      formatEventDate(start) != formatEventDate(end))
                    detail('End date', formatEventDate(end)),
                  detail('Venue', eventText(data, 'venue')),
                  detail('Eligible students', eligibleYearText(data)),
                  detail('Certificate', eventText(data, 'certificateDetails')),
                  detail('Prizes', eventText(data, 'prizeDetails')),
                  detail(
                    'Registration deadline',
                    deadline == null
                        ? 'No separate deadline specified'
                        : '${formatEventDate(deadline)} • '
                              '${formatEventTime(deadline)} IST',
                  ),
                  detail(
                    'Capacity',
                    capacity == null || capacity == 0
                        ? 'No capacity limit'
                        : '$capacity participants',
                  ),
                  detail(
                    'Registered participants',
                    '${data['registeredCount'] ?? 0}',
                  ),
                  detail(
                    'Event status',
                    cancelled
                        ? 'Cancelled'
                        : completed
                        ? 'Completed'
                        : eventText(data, 'status'),
                  ),
                  if (completed && !cancelled)
                    detail(
                      'Completed on',
                      '${formatEventDate(completedAt ?? end)} • '
                          '${formatEventTime(completedAt ?? end)} IST',
                    ),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Your registration',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  EventRegistrationPanel(
                    key: ValueKey(widget.eventId),
                    eventId: widget.eventId,
                    eventData: data,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
