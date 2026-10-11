import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'explore_svecw.dart';
import 'campus_map.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'clubs_directory.dart';
import 'events_feed.dart';
import 'my_registered_events.dart';

const campusPink = Color(0xFFB83268);
const campusBackground = Color(0xFFFFFBFC);
const campusText = Color(0xFF322530);
const campusMuted = Color(0xFF765B68);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final search = TextEditingController();

  final sections = const [
    'Home',
    'All Clubs',
    'Upcoming Events',
    'Past Events',
    'Explore SVECW',
    'Campus Map',
    'My Registered Events',
    'My Profile',
    'Notifications',
    'Settings',
  ];

  final sectionIcons = const [
    Icons.home_rounded,
    Icons.groups_rounded,
    Icons.event_rounded,
    Icons.history_rounded,
    Icons.explore_rounded,
    Icons.map_rounded,
    Icons.event_available_rounded,
    Icons.person_rounded,
    Icons.notifications_rounded,
    Icons.settings_rounded,
  ];

  final categories = const [
    'Technical',
    'Cultural',
    'Sports',
    'Arts and Creativity',
    'Media and Communication',
    'Literary',
    'Social Service',
    'Environmental and Sustainability',
    'Music and Performing Arts',
    'Innovation and Entrepreneurship',
  ];

  int selected = 0;
  String? roomBlock;
  int? roomFloor;
  bool signingOut = false;

  String? selectedCategory;
  String? searchQuery;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? profile;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      profile = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots();
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void openSection(int index, {String? category, String? block, int? floor}) {
    FocusScope.of(context).unfocus();

    setState(() {
      selected = index;
      roomBlock = block;
      roomFloor = floor;
      selectedCategory = category;
      searchQuery = null;
    });
  }

  void submitSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      searchQuery = query;
      selectedCategory = null;
    });
  }

  Future<void> logout() async {
    if (signingOut) {
      return;
    }

    setState(() => signingOut = true);

    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) {
        return;
      }
      widget.onSignedOut();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => signingOut = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not log out. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: profile,
      builder: (context, snapshot) {
        final user = FirebaseAuth.instance.currentUser;
        final data = snapshot.data?.data();

        final savedName = data?['name'];
        final authName = user?.displayName?.trim() ?? '';

        final name = savedName is String && savedName.trim().isNotEmpty
            ? savedName.trim()
            : authName.isNotEmpty
            ? authName
            : 'Student';

        final email = user?.email ?? '';

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            title: const Text(
              'CampusSphere',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              NotificationBell(onPressed: () => openSection(8)),
              IconButton(
                tooltip: 'My Profile',
                onPressed: () => openSection(7),
                icon: const Icon(Icons.account_circle_outlined),
              ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: Drawer(
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surface,
                          child: Icon(
                            Icons.school_rounded,
                            color: campusPink,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          email,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'SVECW • Student',
                          style: TextStyle(color: campusPink),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        for (int i = 0; i < sections.length; i++)
                          if (i == 4)
                            ExpansionTile(
                              leading: const Icon(Icons.explore_outlined),
                              title: const Text('Explore SVECW'),
                              children: [
                                ListTile(
                                  title: const Text('All rooms and facilities'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    openSection(4);
                                  },
                                ),
                                for (final block in ['A', 'B', 'C', 'D'])
                                  ExpansionTile(
                                    title: Text('$block Block'),
                                    children: [
                                      for (var floor = 0; floor < 3; floor++)
                                        ListTile(
                                          title: Text(floorNames[floor]),
                                          onTap: () {
                                            Navigator.pop(context);
                                            openSection(
                                              4,
                                              block: block,
                                              floor: floor,
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ListTile(
                                  title: const Text(
                                    'Jewel Labs & Seetha Auditorium',
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    openSection(4, block: 'Independent');
                                  },
                                ),
                              ],
                            )
                          else
                            ListTile(
                              leading: Icon(sectionIcons[i]),
                              title: Text(sections[i]),
                              selected: selected == i && searchQuery == null,
                              selectedColor: campusPink,
                              selectedTileColor: const Color(0xFFFCEAF1),
                              onTap: () {
                                Navigator.pop(context);
                                openSection(i);
                              },
                            ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(
                            Icons.logout_rounded,
                            color: campusPink,
                          ),
                          title: Text(
                            signingOut ? 'Logging out...' : 'Logout',
                            style: const TextStyle(color: campusPink),
                          ),
                          enabled: !signingOut,
                          onTap: () {
                            Navigator.pop(context);
                            logout();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: ListView(
                  key: ValueKey(
                    'section-$selected-$selectedCategory-$searchQuery',
                  ),
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (snapshot.hasError)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Could not load your saved profile.',
                          style: TextStyle(color: campusPink),
                        ),
                      ),
                    if (searchQuery != null)
                      searchPage()
                    else if (selected == 0)
                      dashboard(name)
                    else if (selected == 7)
                      profilePage(name, email)
                    else
                      sectionPage(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget dashboard(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: Theme.of(context).brightness == Brightness.dark
                  ? [
                      Theme.of(context).colorScheme.surfaceContainerHigh,
                      Theme.of(context).colorScheme.surface,
                    ]
                  : const [Color(0xFFFCE4ED), Color(0xFFFFF4F8)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SVECW • CAMPUS LIFE',
                style: TextStyle(
                  color: campusPink,
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Hello, $name!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your campus. Your community.',
                style: TextStyle(
                  color: campusPink,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Discover your clubs. Find your events.\n'
                'Navigate your campus.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: search,
          textInputAction: TextInputAction.search,
          onSubmitted: submitSearch,
          decoration: InputDecoration(
            hintText: 'Search clubs, events, campus places',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              tooltip: 'Search',
              onPressed: () => submitSearch(search.text),
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFF1DFE6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFF1DFE6)),
            ),
          ),
        ),
        const SizedBox(height: 28),
        heading('Your campus, one tap away'),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 800
                ? 4
                : constraints.maxWidth >= 480
                ? 2
                : 1;

            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                quickCard(
                  width,
                  Icons.groups_rounded,
                  'Discover Clubs',
                  'Find your community',
                  1,
                ),
                quickCard(
                  width,
                  Icons.event_rounded,
                  'Upcoming Events',
                  'Explore campus activities',
                  2,
                ),
                quickCard(
                  width,
                  Icons.near_me_rounded,
                  'Campus Navigation',
                  'Find your destination',
                  5,
                ),
                quickCard(
                  width,
                  Icons.confirmation_number_rounded,
                  'My Registrations',
                  'Access your saved events',
                  6,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        heading('Explore club categories', index: 1),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final category in categories)
              ActionChip(
                label: Text(category),
                backgroundColor: Theme.of(context).colorScheme.surface,
                side: const BorderSide(color: Color(0xFFF1DFE6)),
                onPressed: () => openSection(1, category: category),
              ),
          ],
        ),
        const SizedBox(height: 28),
        heading('Featured events', index: 2),
        const EventsFeed(
          key: ValueKey('home-featured-events'),
          featuredOnly: true,
          limit: 3,
        ),
        const SizedBox(height: 28),
        heading('Upcoming events', index: 2),
        const EventsFeed(key: ValueKey('home-upcoming-events'), limit: 3),
        const SizedBox(height: 28),
        heading('Popular campus spots', index: 4),
        const DashboardNotice(
          icon: Icons.location_on_outlined,
          title: 'Explore your campus',
          text:
              'Verified campus places and their locations '
              'will appear here.',
        ),
        const SizedBox(height: 28),
        heading('Notifications & updates', index: 8),
        const NotificationsPanel(preview: true),
      ],
    );
  }

  Widget heading(String title, {int? index}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          if (index != null)
            TextButton(
              onPressed: () => openSection(index),
              child: const Text('View all'),
            ),
        ],
      ),
    );
  }

  Widget quickCard(
    double width,
    IconData icon,
    String title,
    String subtitle,
    int index,
  ) {
    return SizedBox(
      width: width,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFF1DFE6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openSection(index),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFFCEAF1),
                  child: Icon(icon, color: campusPink),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget profilePage(String name, String email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading('My Profile'),
        DashboardNotice(
          icon: Icons.person_rounded,
          title: name,
          text: '$email\nSVECW student account',
        ),
        const SizedBox(height: 24),
        heading('My Registered Events'),
        const MyRegisteredEvents(key: ValueKey('profile-registered-events')),
      ],
    );
  }

  Widget searchPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => openSection(0),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back to home'),
        ),
        const SizedBox(height: 12),
        heading('Search: $searchQuery'),
        const DashboardNotice(
          icon: Icons.search_rounded,
          title: 'Campus search',
          text:
              'Global search has not been connected yet. '
              'You can search clubs inside All Clubs.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => openSection(1),
              icon: const Icon(Icons.groups_rounded),
              label: const Text('Search All Clubs'),
            ),
            OutlinedButton.icon(
              onPressed: () => openSection(2),
              icon: const Icon(Icons.event_rounded),
              label: const Text('Browse Events'),
            ),
          ],
        ),
      ],
    );
  }

  Widget sectionPage() {
    final descriptions = {
      4: 'Verified campus places will be added here.',
      5:
          'The campus map and verified destinations '
          'have not been added yet.',
      8:
          'Event notifications and reminders '
          'have not been connected yet.',
      9:
          'Notification and appearance preferences '
          'will be added here.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(sections[selected]),
        if (selectedCategory != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Chip(
              label: Text(selectedCategory!),
              onDeleted: () {
                setState(() => selectedCategory = null);
              },
            ),
          ),
        if (selected == 1)
          ClubsDirectory(
            key: ValueKey(selectedCategory),
            category: selectedCategory,
          )
        else if (selected == 2)
          const EventsFeed(key: ValueKey('upcoming-events'))
        else if (selected == 3)
          const EventsFeed(key: ValueKey('past-events'), past: true)
        else if (selected == 4)
          ExploreSvecw(
            key: ValueKey('$roomBlock-$roomFloor'),
            initialBlock: roomBlock,
            initialFloor: roomFloor,
          )
        else if (selected == 5)
          const CampusMap()
        else if (selected == 6)
          const MyRegisteredEvents(key: ValueKey('my-registered-events'))
        else if (selected == 8)
          const NotificationsPanel()
        else if (selected == 9)
          const SettingsPanel()
        else
          DashboardNotice(
            icon: sectionIcons[selected],
            title: sections[selected],
            text: descriptions[selected] ?? '',
          ),
      ],
    );
  }
}

class DashboardNotice extends StatelessWidget {
  const DashboardNotice({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1DFE6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFFCEAF1),
            child: Icon(icon, color: campusPink),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  text,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
