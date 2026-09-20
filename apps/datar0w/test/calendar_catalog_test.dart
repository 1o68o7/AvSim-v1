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
    expect(events.length, greaterThanOrEqualTo(6));
    expect(
      events.any((e) => e.type == 'randonnee' && e.labellise == 'RandonAviron'),
      isTrue,
    );
    expect(events.any((e) => e.type == 'master'), isTrue);
    expect(raw['source'], 'curated');
    final fb = events.firstWhere((e) => e.id.contains('fontainebleau'));
    expect(fb.openToLoisir, isTrue);
    expect(fb.definitionLoisir, isNotNull);
    final blob = jsonEncode(raw).toLowerCase();
    expect(blob.contains('ffaviron.fr/api'), isFalse);
    expect(blob.contains('@'), isFalse);
    expect(blob.contains('naissance'), isFalse);
  });
}
