import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:campus_sphere/explore_svecw.dart';
import 'package:campus_sphere/qr_ticket.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Directory preserves corrected room assignments and separate facilities',
    () async {
      final rooms = await loadCampusRooms();
      expect(rooms.map((room) => room.id).toSet().length, rooms.length);
      expect(
        rooms.singleWhere((room) => room.id == 'C206').name,
        'AIML — Second Year',
      );
      for (final id in ['C207', 'C208', 'C209']) {
        expect(
          rooms.singleWhere((room) => room.id == id).name,
          'Placement Cell',
        );
      }
      expect(
        rooms.singleWhere((room) => room.id == 'jewel_labs').block,
        'Independent',
      );
      expect(
        rooms.singleWhere((room) => room.id == 'seetha_auditorium').floor,
        0,
      );
      expect(rooms.where((room) => room.block == 'D'), isEmpty);
      expect(rooms.singleWhere((room) => room.id == 'A301').name, isEmpty);
    },
  );
  test('Ticket round trip contains no name or email', () {
    final token = newTicketToken();
    final payload = ticketPayload('event1', 'student1', token);
    final decoded = TicketCode.parse(payload);
    expect(decoded.eventId, 'event1');
    expect(decoded.studentId, 'student1');
    expect(decoded.token, token);
    expect((jsonDecode(payload) as Map).keys, isNot(contains('email')));
  });
  test('Reject unrelated QR codes, malformed IDs and invalid token', () {
    expect(() => TicketCode.parse('not a ticket'), throwsFormatException);
    expect(() => TicketCode.parse('{}'), throwsFormatException);
    expect(
      () => TicketCode.parse(
        ticketPayload('events/e1', 'student', newTicketToken()),
      ),
      throwsFormatException,
    );
    expect(
      () => TicketCode.parse(ticketPayload('e1', 'student', 'short')),
      throwsFormatException,
    );
  });
}
