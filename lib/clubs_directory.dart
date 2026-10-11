import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'events_feed.dart';

class ClubsDirectory extends StatefulWidget {
  const ClubsDirectory({super.key, this.category});

  final String? category;

  @override
  State<ClubsDirectory> createState() => _ClubsDirectoryState();
}

class _ClubsDirectoryState extends State<ClubsDirectory> {
  final search = TextEditingController();
  String query = '';

  late final Stream<QuerySnapshot<Map<String, dynamic>>> clubs;

  @override
  void initState() {
    super.initState();

    clubs = FirebaseFirestore.instance
        .collection('clubs')
        .orderBy('name')
        .snapshots();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  String field(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is String ? value.trim() : '';
  }

  void openClub(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClubDetailsScreen(clubId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Find a community that matches your interests.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: search,
          onChanged: (value) {
            setState(() => query = value.trim().toLowerCase());
          },
          decoration: InputDecoration(
            hintText: 'Search clubs',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      search.clear();
                      setState(() => query = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFF1DFE6)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: clubs,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const ClubNotice(
                icon: Icons.cloud_off_rounded,
                text:
                    'Could not load clubs. Check your connection '
                    'and published Firestore rules.',
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final documents = snapshot.data!.docs;

            final results = documents.where((document) {
              final data = document.data();

              final matchesCategory =
                  widget.category == null ||
                  field(data, 'category') == widget.category;

              final searchable = [
                field(data, 'name'),
                field(data, 'category'),
                field(data, 'shortDescription'),
                field(data, 'description'),
              ].join(' ').toLowerCase();

              return matchesCategory && searchable.contains(query);
            }).toList();

            if (results.isEmpty) {
              return ClubNotice(
                icon: Icons.groups_outlined,
                text: documents.isEmpty
                    ? 'No clubs have been added yet.'
                    : 'No clubs match this search or category.',
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${results.length} '
                  '${results.length == 1 ? 'club' : 'clubs'}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (final document in results)
                  Padding(
                    key: ValueKey(document.id),
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Card(
                      color: Theme.of(context).colorScheme.surface,
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Color(0xFFF1DFE6)),
                      ),
                      child: InkWell(
                        onTap: () => openClub(document.id),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClubImage(
                                url: field(document.data(), 'imageUrl'),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      field(document.data(), 'name'),
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      field(
                                        document.data(),
                                        'shortDescription',
                                      ),
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      field(document.data(), 'category'),
                                      style: const TextStyle(
                                        color: Color(0xFFB83268),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFFB83268),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class ClubImage extends StatelessWidget {
  const ClubImage({super.key, required this.url, this.size = 56});

  final String url;
  final double size;

  Widget fallback(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        Icons.groups_rounded,
        color: const Color(0xFFB83268),
        size: size * 0.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return fallback(context);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => fallback(context),
      ),
    );
  }
}

class ClubDetailsScreen extends StatefulWidget {
  const ClubDetailsScreen({super.key, required this.clubId});

  final String clubId;

  @override
  State<ClubDetailsScreen> createState() => _ClubDetailsScreenState();
}

class _ClubDetailsScreenState extends State<ClubDetailsScreen> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> club;

  @override
  void initState() {
    super.initState();

    club = FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .snapshots();
  }

  String field(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is String ? value.trim() : '';
  }

  Widget heading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget section(String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading(title),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFC),
      appBar: AppBar(
        title: const Text('Club Profile'),
        backgroundColor: const Color(0xFFFFFBFC),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: club,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: ClubNotice(
                icon: Icons.cloud_off_rounded,
                text: 'Could not load this club. Please try again.',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data();

          if (data == null) {
            return const Center(
              child: ClubNotice(
                icon: Icons.groups_outlined,
                text: 'This club is no longer available.',
              ),
            );
          }

          final mentor = field(data, 'mentor');
          final coordinator = field(data, 'coordinator');
          final contact = field(data, 'contact');
          final activities = field(data, 'activities');
          final description = field(data, 'description');

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClubImage(url: field(data, 'imageUrl'), size: 80),
                        const SizedBox(height: 20),
                        Text(
                          field(data, 'name'),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          field(data, 'category'),
                          style: const TextStyle(
                            color: Color(0xFFB83268),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          field(data, 'shortDescription'),
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  section(
                    'About the club',
                    description.isEmpty
                        ? 'A description has not been added yet.'
                        : description,
                  ),
                  if (activities.isNotEmpty)
                    section('Activities and purpose', activities),
                  section(
                    'Mentor',
                    mentor.isEmpty
                        ? 'Mentor details have not been added yet.'
                        : mentor,
                  ),
                  section(
                    'Club Coordinator',
                    coordinator.isEmpty
                        ? 'Coordinator details have not been added yet.'
                        : coordinator,
                  ),
                  section(
                    'Contact',
                    contact.isEmpty
                        ? 'Contact details have not been added yet.'
                        : contact,
                  ),

                  // All upcoming events belonging to this club.
                  heading('Upcoming Events'),
                  EventsFeed(
                    key: ValueKey('club-upcoming-${widget.clubId}'),
                    clubId: widget.clubId,
                  ),
                  const SizedBox(height: 28),

                  // Only the latest three completed events.
                  heading('Latest Past Events'),
                  EventsFeed(
                    key: ValueKey('club-past-${widget.clubId}'),
                    clubId: widget.clubId,
                    past: true,
                    limit: 3,
                  ),
                  const SizedBox(height: 28),

                  section(
                    'Announcements',
                    'The announcements feed has not been connected yet.',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ClubNotice extends StatelessWidget {
  const ClubNotice({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0xFFB83268)),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
