import 'dart:convert';
import 'dart:io';

import 'package:datar0w/calendar/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalogue FFA curaté : flags loisir, pas de PII', () {
    final raw = jsonDecode(
      File('assets/ffa_calendar_2026.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final events = (raw['events'] as List)
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(events, isNotEmpty);
    final fb = events.firstWhere((e) => e.id.contains('fontainebleau'));
    expect(fb.openToLoisir, isTrue);
    expect(fb.definitionLoisir, isNotNull);
    final blob = jsonEncode(raw).toLowerCase();
    expect(blob.contains('@'), isFalse);
    expect(blob.contains('naissance'), isFalse);
  });
}
