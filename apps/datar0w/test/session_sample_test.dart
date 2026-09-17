import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:datar0w/sensors/geo.dart';
import 'package:datar0w/session/model.dart';
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
}
