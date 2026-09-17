import 'package:datar0w/session/heel.dart';
import 'package:datar0w/theme/deck_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('complémentaire : τ donne un poids gyro > 0,5 si dt << τ', () {
    final w = complementaryGyroWeight(dtS: 0.02, tauS: 0.32);
    expect(w, closeTo(0.32 / 0.34, 1e-9));
    expect(w, greaterThan(0.5));
  });

  test('deadband ignore le jitter < 0,15°', () {
    expect(displayDeadband(1.0, 1.10), 1.0);
    expect(displayDeadband(1.0, 1.20), 1.20);
  });

  test('+gîte = tribords = gauche écran', () {
    expect(rowerGiteFromImu(2), -2);
    expect(heelAlignmentX(5), lessThan(0));
    expect(heelAlertFor(4.0), HeelAlert.tribord);
    expect(heelAlertFor(-4.0), HeelAlert.babord);
    expect(heelAlertFor(1.0), HeelAlert.none);
  });

  test('couleurs bâbord rouge / tribord vert, pas cyan', () {
    expect(DeckColors.babord, const Color(0xFFE05353));
    expect(DeckColors.tribord, const Color(0xFF46C275));
    expect(DeckColors.tribord.toARGB32(), isNot(0xFF00E676));
  });

  test('filtre suit une marche sans rester collé au brut', () {
    final f = HeelFilter(tauS: 0.32);
    var t = DateTime.utc(2026, 1, 1);
    f.update(accelRollDeg: 0, now: t);
    for (var i = 0; i < 20; i++) {
      t = t.add(const Duration(milliseconds: 20));
      f.update(accelRollDeg: 10, now: t);
    }
    expect(f.filteredDeg!, greaterThan(2));
    expect(f.filteredDeg!, lessThan(10));
  });
}
