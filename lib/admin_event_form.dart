import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'events_feed.dart';

// Campus form dates always represent India time, independent of device timezone.
DateTime? parseCampusDate(String input) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})$')
      .firstMatch(input.trim());
  if (match == null) {
    return null;
  }
  final values = List.generate(5, (i) => int.parse(match.group(i + 1)!));
  final date = DateTime.utc(
    values[0],
    values[1],
    values[2],
    values[3],
    values[4],
  );
  if (date.year != values[0] ||
      date.month != values[1] ||
      date.day != values[2] ||
      date.hour != values[3] ||
      date.minute != values[4] ||
      values[0] < 2000 ||
      values[0] > 2100) {
    return null;
  }
  return date.subtract(const Duration(hours: 5, minutes: 30));
}

String campusDateInput(DateTime? date) {
  if (date == null) {
    return '';
  }
  final d = indiaTime(date);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

class AdminEventForm extends StatefulWidget {
  const AdminEventForm({super.key, this.eventId});
  final String? eventId;
  @override
  State<AdminEventForm> createState() => _AdminEventFormState();
}

class _AdminEventFormState extends State<AdminEventForm> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{
    for (final key in [
      'title',
      'description',
      'venue',
      'eventType',
      'imageUrl',
      'startAt',
      'endAt',
      'registrationDeadline',
      'capacity',
      'certificateDetails',
      'cashPrize',
      'prizeDetails',
      'completedAt',
    ])
      key: TextEditingController(),
  };
  List<QueryDocumentSnapshot<Map<String, dynamic>>> clubs = [];
  String? clubId;
  String status = 'scheduled';
  bool open = true;
  bool featured = false;
  bool demo = false;
  bool certificate = false;
  bool loading = true;
  bool saving = false;
  String? error;
  Set<int> years = {1, 2, 3, 4};
  final eventRef = FirebaseFirestore.instance.collection('events');

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final clubList = await FirebaseFirestore.instance
          .collection('clubs')
          .orderBy('name')
          .get();
      Map<String, dynamic>? data;
      if (widget.eventId != null) {
        data = (await eventRef.doc(widget.eventId).get()).data();
        if (data == null) {
          throw StateError('This event no longer exists.');
        }
      }
      if (!mounted) {
        return;
      }
      clubs = clubList.docs;
      fields['capacity']!.text = '0';
      fields['cashPrize']!.text = '0';
      fields['eventType']!.text = 'Workshop';
      if (data != null) {
        for (final key in fields.keys) {
          if ([
            'startAt',
            'endAt',
            'registrationDeadline',
            'completedAt',
          ].contains(key)) {
            fields[key]!.text = campusDateInput(eventDate(data, key));
          } else {
            fields[key]!.text = '${data[key] ?? ''}';
          }
        }
        if (fields['capacity']!.text.isEmpty) {
          fields['capacity']!.text = '0';
        }
        if (fields['cashPrize']!.text.isEmpty) {
          fields['cashPrize']!.text = '0';
        }
        clubId = data['clubId'] as String?;
        status = data['status'] as String? ?? 'scheduled';
        open = data['registrationOpen'] == true;
        featured = data['featured'] == true;
        demo = data['isDemo'] == true;
        certificate = data['offersCertificate'] == true;
        years = (data['eligibleYears'] as List? ?? []).whereType<int>().toSet();
        if (years.isEmpty) {
          years = {1, 2, 3, 4};
        }
      }
      setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error =
              'Could not load form. Check your connection and admin access. $e';
        });
      }
    }
  }

  Widget input(
    String key,
    String label, {
    bool required = false,
    int lines = 1,
    bool date = false,
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: fields[key],
        enabled: !saving,
        maxLines: lines,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          helperText: date ? 'India time • YYYY-MM-DD HH:mm (24-hour)' : null,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (required && text.isEmpty) {
            return 'This field is required';
          }
          if (date && text.isNotEmpty && parseCampusDate(text) == null) {
            return 'Enter a valid date: YYYY-MM-DD HH:mm';
          }
          if (key == 'capacity' &&
              (int.tryParse(text) == null || int.parse(text) < 0)) {
            return 'Enter a whole number, zero or greater';
          }
          if (key == 'cashPrize' &&
              (double.tryParse(text) == null ||
                  !double.parse(text).isFinite ||
                  double.parse(text) < 0)) {
            return 'Enter a valid amount, zero or greater';
          }
          if (key == 'imageUrl' && text.isNotEmpty) {
            final uri = Uri.tryParse(text);
            if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
              return 'Use a valid HTTPS image URL';
            }
          }
          if (text.length > (key == 'description' ? 10000 : 2000)) {
            return 'This field is too long';
          }
          return null;
        },
      ),
    );
  }

  Future<void> save() async {
    if (saving || !(form.currentState?.validate() ?? false)) {
      return;
    }
    final selectedClubs = clubs.where((doc) => doc.id == clubId);
    if (selectedClubs.isEmpty || years.isEmpty) {
      notify('Select a club and at least one eligible year.');
      return;
    }
    final start = parseCampusDate(fields['startAt']!.text)!;
    final end = parseCampusDate(fields['endAt']!.text)!;
    final deadline = parseCampusDate(fields['registrationDeadline']!.text);
    final completion = parseCampusDate(fields['completedAt']!.text);
    if (!end.isAfter(start)) {
      notify('End time must be after start time.');
      return;
    }
    if (deadline != null && deadline.isAfter(start)) {
      notify('Registration deadline must be at or before the start.');
      return;
    }
    if (completion != null && completion.isAfter(DateTime.now())) {
      notify('Completion time cannot be in the future.');
      return;
    }
    if (status == 'scheduled' && completion != null) {
      notify('Clear completion time for a scheduled event.');
      return;
    }
    final club = selectedClubs.first.data();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final capacity = int.parse(fields['capacity']!.text.trim());
    setState(() => saving = true);
    try {
      final values = <String, dynamic>{
        for (final key in [
          'title',
          'description',
          'venue',
          'eventType',
          'imageUrl',
          'certificateDetails',
          'prizeDetails',
        ])
          key: fields[key]!.text.trim(),
        'clubId': clubId,
        'clubName': club['name'],
        'category': club['category'],
        'startAt': Timestamp.fromDate(start),
        'endAt': Timestamp.fromDate(end),
        'registrationDeadline': deadline == null
            ? null
            : Timestamp.fromDate(deadline),
        'capacity': capacity,
        'eligibleYears': years.toList()..sort(),
        'offersCertificate': certificate,
        'cashPrize': double.parse(fields['cashPrize']!.text.trim()),
        'currency': 'INR',
        'status': status,
        'registrationOpen': status == 'scheduled' && open,
        'featured': featured,
        'isDemo': demo,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      };
      final ref = widget.eventId == null
          ? eventRef.doc()
          : eventRef.doc(widget.eventId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final current = await transaction.get(ref);
        if (widget.eventId != null && !current.exists) {
          throw StateError('The event was deleted.');
        }
        final before = current.data();
        final count = before?['registeredCount'] as int? ?? 0;
        if (capacity > 0 && capacity < count) {
          throw StateError(
            'Capacity cannot be below $count existing registrations.',
          );
        }
        if (count > 0 && before?['clubId'] != clubId) {
          throw StateError(
            'Cannot change organizing club after students register.',
          );
        }
        if (status == 'completed') {
          values['completedAt'] = completion != null
              ? Timestamp.fromDate(completion)
              : before?['completedAt'] ?? FieldValue.serverTimestamp();
        } else if (widget.eventId != null) {
          values['completedAt'] = FieldValue.delete();
        }
        if (widget.eventId == null) {
          transaction.set(ref, {
            ...values,
            'registeredCount': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': uid,
          });
        } else {
          transaction.update(ref, values);
        }
      });
      if (!mounted) {
        return;
      }
      notify('Event saved successfully.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        notify(
          e is StateError ? e.message.toString() : 'Could not save. Check admin access, connection, and event fields.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  void notify(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.eventId == null ? 'Add event' : 'Edit event'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(error!),
              ),
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Form(
                  key: form,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      input('title', 'Event title', required: true),
                      DropdownButtonFormField<String>(
                        initialValue: clubs.any((doc) => doc.id == clubId)
                            ? clubId
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Organizing club',
                          border: OutlineInputBorder(),
                        ),
                        items: clubs
                            .map(
                              (doc) => DropdownMenuItem(
                                value: doc.id,
                                child: Text('${doc.data()['name']}'),
                              ),
                            )
                            .toList(),
                        validator: (value) =>
                            value == null ? 'Select a club' : null,
                        onChanged: saving
                            ? null
                            : (value) => setState(() => clubId = value),
                      ),
                      const SizedBox(height: 18),
                      input(
                        'description',
                        'Description',
                        required: true,
                        lines: 4,
                      ),
                      input('eventType', 'Event type', required: true),
                      input('venue', 'Venue', required: true),
                      input('imageUrl', 'Poster/image URL (optional)'),
                      input(
                        'startAt',
                        'Start date and time',
                        required: true,
                        date: true,
                      ),
                      input(
                        'endAt',
                        'End date and time',
                        required: true,
                        date: true,
                      ),
                      input(
                        'registrationDeadline',
                        'Registration deadline (optional)',
                        date: true,
                      ),
                      input(
                        'capacity',
                        'Capacity (0 = unlimited)',
                        number: true,
                      ),
                      const Text('Eligible study years'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (int year = 1; year <= 4; year++)
                            FilterChip(
                              label: Text('Year $year'),
                              selected: years.contains(year),
                              onSelected: saving
                                  ? null
                                  : (selected) => setState(() {
                                      if (selected) {
                                        years.add(year);
                                      } else {
                                        years.remove(year);
                                      }
                                    }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SwitchListTile(
                        title: const Text('Certificate offered'),
                        value: certificate,
                        onChanged: saving
                            ? null
                            : (v) => setState(() => certificate = v),
                      ),
                      input('certificateDetails', 'Certificate details'),
                      input(
                        'cashPrize',
                        'Cash prize in INR (0 = none)',
                        number: true,
                      ),
                      input('prizeDetails', 'Prize details'),
                      DropdownButtonFormField<String>(
                        initialValue:
                            [
                              'scheduled',
                              'completed',
                              'cancelled',
                            ].contains(status)
                            ? status
                            : 'scheduled',
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'scheduled',
                            child: Text('Scheduled'),
                          ),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Text('Completed'),
                          ),
                          DropdownMenuItem(
                            value: 'cancelled',
                            child: Text('Cancelled'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (v) => setState(() => status = v!),
                      ),
                      const SizedBox(height: 18),
                      if (status == 'completed')
                        input(
                          'completedAt',
                          'Completion time (blank = now)',
                          date: true,
                        ),
                      SwitchListTile(
                        title: const Text('Registration open'),
                        value: status == 'scheduled' && open,
                        onChanged: saving || status != 'scheduled'
                            ? null
                            : (v) => setState(() => open = v),
                      ),
                      SwitchListTile(
                        title: const Text('Featured on home page'),
                        value: featured,
                        onChanged: saving
                            ? null
                            : (v) => setState(() => featured = v),
                      ),
                      SwitchListTile(
                        title: const Text('Fictional demo event'),
                        value: demo,
                        onChanged: saving
                            ? null
                            : (v) => setState(() => demo = v),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: saving ? null : save,
                        child: Text(saving ? 'Saving…' : 'Save event'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
