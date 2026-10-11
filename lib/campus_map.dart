import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'explore_svecw.dart';

const campusReference = LatLng(16.5645537, 81.5222806);

class CampusMap extends StatefulWidget {
  const CampusMap({super.key, this.manage = false});
  final bool manage;
  @override
  State<CampusMap> createState() => _CampusMapState();
}

class _CampusMapState extends State<CampusMap> {
  final controller = MapController();
  late final places = FirebaseFirestore.instance
      .collection('campus_places')
      .snapshots();
  String search = '';
  QueryDocumentSnapshot<Map<String, dynamic>>? selected;
  double zoom = 17;
  void selectPlace(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    setState(() {
      selected = doc;
      zoom = 18.5;
    });
    controller.move(
      LatLng(
        (doc.data()['latitude'] as num).toDouble(),
        (doc.data()['longitude'] as num).toDouble(),
      ),
      zoom,
    );
  }

  void zoomBy(double delta) {
    setState(() => zoom = (zoom + delta).clamp(15.0, 19.0));
    controller.move(controller.camera.center, zoom);
  }

  bool saving = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> openMap(LatLng point) async {
    try {
      final opened = await launchUrl(
        Uri.https(
          'www.google.com',
          point == campusReference ? '/maps/search/' : '/maps/dir/',
          {
            'api': '1',
            if (point == campusReference)
              'query': '${point.latitude},${point.longitude}'
            else ...{
              'destination': '${point.latitude},${point.longitude}',
              'travelmode': 'walking',
            },
          },
        ),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        message('Could not open Google Maps.');
      }
    } catch (_) {
      message('Could not open Google Maps.');
    }
  }

  Future<void> saveMarker(LatLng point) async {
    if (!widget.manage || saving) {
      return;
    }
    final name = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a verified place'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Use the exact building entrance. Examples: A Block, B Block, Jewel Labs, Seetha Auditorium.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Place name'),
            ),
            Text(
              '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final label = name.text.trim();
    name.dispose();
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => saving = true);
    try {
      // A stable name-derived ID lets admins reposition an existing place.
      final id = Uri.encodeComponent(label.toLowerCase());
      await FirebaseFirestore.instance.collection('campus_places').doc(id).set({
        'name': label,
        'latitude': point.latitude,
        'longitude': point.longitude,
        'verified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      message('Place saved. Students can now see this marker.');
    } catch (_) {
      message('Could not save place. Check admin access and connection.');
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> removeMarker(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove map marker?'),
        content: const Text('Room directory entries will be kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('campus_places')
          .doc(id)
          .delete();
    } catch (_) {
      message('Could not remove marker.');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF92244F), Color(0xFFC94D7D)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.explore_rounded, color: Colors.white, size: 32),
            SizedBox(height: 12),
            Text(
              'Find your way around campus',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Choose a place, explore its rooms, or open directions.',
              style: TextStyle(color: Colors.white, height: 1.5),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        decoration: InputDecoration(
          hintText: 'Search mapped buildings and places',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) => setState(() {
          search = value.trim().toLowerCase();
          selected = null;
        }),
      ),
      if (widget.manage)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Tap the verified entrance on the map to save a place. Use the same name to reposition it.',
          ),
        ),
      const SizedBox(height: 12),
      if (saving) const LinearProgressIndicator(),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: places,
        builder: (context, snapshot) {
          final all =
              snapshot.data?.docs.where((doc) {
                final d = doc.data();
                return d['verified'] == true &&
                    d['latitude'] is num &&
                    d['longitude'] is num &&
                    (d['latitude'] as num).abs() <= 90 &&
                    (d['longitude'] as num).abs() <= 180;
              }).toList() ??
              [];
          all.sort(
            (a, b) => '${a.data()['name']}'.compareTo('${b.data()['name']}'),
          );
          final docs = all
              .where(
                (d) => '${d.data()['name']}'.toLowerCase().contains(search),
              )
              .toList();
          final matches = all.where((d) => d.id == selected?.id).toList();
          final current = matches.isEmpty ? null : matches.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (snapshot.hasError)
                const Text(
                  'Saved places could not be loaded. Check your connection.',
                ),
              if (!snapshot.hasData && !snapshot.hasError)
                const LinearProgressIndicator(),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).width < 600 ? 440 : 540,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: controller,
                        options: MapOptions(
                          initialCenter: campusReference,
                          initialZoom: 17,
                          minZoom: 15,
                          maxZoom: 19,
                          onPositionChanged: (camera, _) {
                            zoom = camera.zoom;
                          },
                          onTap: widget.manage
                              ? (_, point) => saveMarker(point)
                              : null,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: const String.fromEnvironment(
                              'MAP_TILE_URL',
                              defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            ),
                            userAgentPackageName: 'CampusSphere/1.0',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: campusReference,
                                width: 44,
                                height: 44,
                                child: Tooltip(
                                  message:
                                      'Reference from supplied campus link',
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.blue,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.school,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ),
                              for (final doc in docs)
                                Marker(
                                  point: LatLng(
                                    (doc.data()['latitude'] as num).toDouble(),
                                    (doc.data()['longitude'] as num).toDouble(),
                                  ),
                                  width: 150,
                                  height: 70,
                                  child: GestureDetector(
                                    onTap: () => selectPlace(doc),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: current?.id == doc.id
                                                ? const Color(0xFFB83268)
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .surface,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            '${doc.data()['name']}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: current?.id == doc.id
                                                  ? Colors.white
                                                  : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.location_on,
                                          color: Color(0xFFB83268),
                                          size: 34,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SimpleAttributionWidget(
                            source: const Text(
                              '© OpenStreetMap contributors',
                              style: TextStyle(fontSize: 11),
                            ),
                            onTap: () => launchUrl(
                              Uri.parse(
                                'https://www.openstreetmap.org/copyright',
                              ),
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text(
                              '${all.length} verified places',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Card(
                          child: Column(
                            children: [
                              IconButton(
                                tooltip: 'Zoom in',
                                onPressed: () => zoomBy(1),
                                icon: const Icon(Icons.add),
                              ),
                              IconButton(
                                tooltip: 'Zoom out',
                                onPressed: () => zoomBy(-1),
                                icon: const Icon(Icons.remove),
                              ),
                              IconButton(
                                tooltip: 'Campus overview',
                                onPressed: () {
                                  setState(() {
                                    selected = null;
                                    zoom = 17;
                                  });
                                  controller.move(campusReference, 17);
                                },
                                icon: const Icon(Icons.center_focus_strong),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (current != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.place, color: Color(0xFFB83268)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${current.data()['name']}',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close selection',
                              onPressed: () => setState(() => selected = null),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const Text('Verified campus destination'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => openMap(
                            LatLng(
                              (current.data()['latitude'] as num).toDouble(),
                              (current.data()['longitude'] as num).toDouble(),
                            ),
                          ),
                          icon: const Icon(Icons.directions_walk),
                          label: const Text('Open walking directions'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (docs.isEmpty && snapshot.hasData)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      search.isEmpty
                          ? 'Building pins will appear here after an admin verifies their locations. You can explore the floor directory below.'
                          : 'No mapped places match your search.',
                    ),
                  ),
                ),
              if (docs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final doc in docs)
                        ChoiceChip(
                          label: Text('${doc.data()['name']}'),
                          selected: current?.id == doc.id,
                          onSelected: (_) => selectPlace(doc),
                        ),
                    ],
                  ),
                ),
              if (widget.manage)
                for (final doc in docs)
                  ListTile(
                    title: Text('${doc.data()['name']}'),
                    leading: const Icon(Icons.place_outlined),
                    onTap: () => selectPlace(doc),
                    trailing: IconButton(
                      tooltip: 'Remove marker',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => removeMarker(doc.id),
                    ),
                  ),
            ],
          );
        },
      ),
      const SizedBox(height: 18),
      Text(
        'Explore buildings & floors',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final block in ['A', 'B', 'C', 'D', 'Independent'])
            ActionChip(
              avatar: Icon(
                block == 'Independent'
                    ? Icons.landscape_outlined
                    : Icons.apartment,
              ),
              label: Text(
                block == 'Independent'
                    ? 'Jewel Labs & Seetha Auditorium'
                    : '$block Block',
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: Text(
                        block == 'Independent'
                            ? 'Campus facilities'
                            : '$block Block',
                      ),
                    ),
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: ExploreSvecw(initialBlock: block),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: () => openMap(campusReference),
        icon: const Icon(Icons.open_in_new),
        label: const Text('Open campus reference in Google Maps'),
      ),
    ],
  );
}

class ManageCampusMapScreen extends StatelessWidget {
  const ManageCampusMapScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Manage campus map')),
    body: const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: CampusMap(manage: true),
    ),
  );
}
