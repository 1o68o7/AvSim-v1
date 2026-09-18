import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:datar0w/sensors/geo.dart';
import 'package:datar0w/session/model.dart';
import 'package:datar0w/session/store.dart';
import 'package:datar0w/session/summary.dart';
import 'package:datar0w/theme/deck_theme.dart';

void main() {
  test('cadence_spm JSON reste null', () {
    const s = SessionSample(t: 1710000000123, distM: 0, net: 'wifi');
    final line = s.toJsonLine();
    expect(line.contains('"cadence_spm":null'), isTrue);
    expect(line.contains('10Hz') || line.contains('10 Hz'), isFalse);
  });

  test('haversine ~1° latitude ≈ 111 km', () {
    final m = haversineMeters(lat1: 0, lon1: 0, lat2: 1, lon2: 0);
    expect(m, closeTo(111194, 200));
  });

  test('alerte gîte : ambre statut, pas cyan High-Vis', () {
    expect(DeckColors.alert, const Color(0xFFE8C547));
    expect(DeckColors.alert.toARGB32(), isNot(0xFF00E676));
  });

  test('plage horaire quai depuis meta ISO', () {
    expect(
      formatClockRange('2026-09-17T07:14:00Z', '2026-09-17T07:56:00Z'),
      contains(' — '),
    );
    expect(formatClockRange(null, null), '—');
  });

  test('SessionMeta identité optionnelle, rétro-compat', () {
    const m = SessionMeta(id: 's1');
    final j = m.toJson();
    expect(j.containsKey('rowerId'), isFalse);
    final m2 = SessionMeta.fromJson({
      'id': 's2',
      'class': '8+',
      'rowerId': 'r1',
      'side': 'babord',
      'seatIndex': 3,
    });
    expect(m2.rowerId, 'r1');
    expect(m2.side, 'babord');
    expect(m2.seatIndex, 3);
  });

  test('note coach JSON', () {
    final n = SessionNote.fromJson({
      't': 1,
      'lat': 44.8,
      'dist_m': 12.0,
    });
    expect(n.t, 1);
    expect(n.distM, 12.0);
    expect(n.sog, isNull);
  });
}
