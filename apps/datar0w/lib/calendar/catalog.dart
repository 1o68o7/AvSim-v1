import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

class CalendarCatalog {
  CalendarCatalog._(this.events, this.waters);

  final List<CalendarEvent> events;
  final List<WaterBody> waters;

  static CalendarCatalog? _cache;

  static Future<CalendarCatalog> load() async {
    if (_cache != null) return _cache!;
    final evRaw = jsonDecode(
      await rootBundle.loadString('assets/ffa_calendar_2026.json'),
    ) as Map<String, dynamic>;
    final wRaw = jsonDecode(
      await rootBundle.loadString('assets/waters.json'),
    ) as Map<String, dynamic>;
    final events = (evRaw['events'] as List)
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();
    events.sort((a, b) => a.start.compareTo(b.start));
    final waters = (wRaw['waters'] as List)
        .map((e) => WaterBody.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cache = CalendarCatalog._(events, waters);
  }

  CalendarEvent? eventById(String id) {
    for (final e in events) {
      if (e.id == id) return e;
    }
    return null;
  }

  WaterBody? waterById(String? id) {
    if (id == null) return null;
    for (final w in waters) {
      if (w.id == id) return w;
    }
    return null;
  }
}
