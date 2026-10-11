import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const floorNames = ['Ground Floor', 'First Floor', 'Second Floor'];

class CampusRoom {
  const CampusRoom({
    required this.id,
    required this.block,
    required this.floor,
    required this.name,
    required this.notes,
  });
  final String id;
  final String block;
  final int floor;
  final String name;
  final String notes;
  factory CampusRoom.fromJson(Map<String, dynamic> data) => CampusRoom(
    id: data['id'] as String,
    block: data['block'] as String,
    floor: data['floor'] as int,
    name: data['name'] as String,
    notes: data['notes'] as String,
  );
}

Future<List<CampusRoom>> loadCampusRooms() async {
  final text = await rootBundle.loadString('assets/campus_rooms.json');
  return (jsonDecode(text) as List)
      .map(
        (item) => CampusRoom.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList()
    ..sort((a, b) => a.id.compareTo(b.id));
}

class ExploreSvecw extends StatefulWidget {
  const ExploreSvecw({super.key, this.initialBlock, this.initialFloor});
  final String? initialBlock;
  final int? initialFloor;
  @override
  State<ExploreSvecw> createState() => _ExploreSvecwState();
}

class _ExploreSvecwState extends State<ExploreSvecw> {
  late final rooms = loadCampusRooms();
  String? block;
  int? floor;
  String search = '';
  @override
  void initState() {
    super.initState();
    block = widget.initialBlock;
    floor = widget.initialFloor;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CampusRoom>>(
      future: rooms,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Room directory could not be loaded.');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final visible = snapshot.data!
            .where(
              (room) =>
                  (block == null || room.block == block) &&
                  (floor == null || room.floor == floor) &&
                  '${room.id} ${room.name} ${room.block} ${floorNames[room.floor]}'
                      .toLowerCase()
                      .contains(search),
            )
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Find classrooms, labs and offices by block and floor.'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search room number or name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  setState(() => search = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All blocks'),
                  selected: block == null,
                  onSelected: (_) => setState(() {
                    block = null;
                    floor = null;
                  }),
                ),
                for (final value in ['A', 'B', 'C', 'D', 'Independent'])
                  ChoiceChip(
                    label: Text(
                      value == 'Independent'
                          ? 'Other facilities'
                          : '$value Block',
                    ),
                    selected: block == value,
                    onSelected: (_) => setState(() {
                      block = value;
                      floor = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All floors'),
                  selected: floor == null,
                  onSelected: (_) => setState(() => floor = null),
                ),
                for (var i = 0; i < floorNames.length; i++)
                  ChoiceChip(
                    label: Text(floorNames[i]),
                    selected: floor == i,
                    onSelected: (_) => setState(() => floor = i),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (block == 'D')
              const Text('D Block room details will be added soon.')
            else if (block == 'C' && floor == 2)
              const Text('C Block second-floor details will be added soon.')
            else if (visible.isEmpty)
              const Text('No rooms match this search.')
            else ...[
              Text('${visible.length} places'),
              const SizedBox(height: 12),
              for (final room in visible)
                Card(
                  child: ListTile(
                    leading: Icon(
                      room.name.toLowerCase().contains('lab')
                          ? Icons.science_outlined
                          : Icons.meeting_room_outlined,
                    ),
                    title: Text(
                      room.block == 'Independent' ? room.name : room.id,
                    ),
                    subtitle: Text(
                      '${room.block == 'Independent' ? 'Separate facility' : '${room.block} Block'} • ${floorNames[room.floor]}\n${room.name.isEmpty ? 'Details not provided.' : room.name}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          room.block == 'Independent' ? room.name : room.id,
                        ),
                        content: Text(
                          '${room.name.isEmpty ? 'Details not provided.' : room.name}\n\n${room.block == 'Independent' ? 'Separate facility' : '${room.block} Block'}\n${floorNames[room.floor]}${room.notes.isEmpty ? '' : '\n\n${room.notes}'}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
