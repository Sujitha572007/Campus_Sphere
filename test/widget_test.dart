import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_sphere/main.dart';
import 'package:campus_sphere/admin_event_form.dart';

void main() {
  testWidgets('Welcome screen displays CampusSphere', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    expect(find.text('CampusSphere'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
  test('India event input converts to UTC and round trips', () {
    final date = parseCampusDate('2026-10-10 14:30');
    expect(date, DateTime.utc(2026, 10, 10, 9));
    expect(campusDateInput(date), '2026-10-10 14:30');
  });
  test('Reject invalid dates and normalized overflow', () {
    expect(parseCampusDate('2026-02-30 10:00'), isNull);
    expect(parseCampusDate('2026-10-10 24:00'), isNull);
    expect(parseCampusDate('10/10/2026 10:00'), isNull);
    expect(parseCampusDate('2026-10-10 10:60'), isNull);
  });
}
