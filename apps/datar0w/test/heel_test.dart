import 'package:datar0w/session/heel.dart';
import 'package:datar0w/theme/deck_theme.dart';
import 'package:datar0w/widgets/heel_banner.dart';
import 'package:datar0w/widgets/heel_gauge.dart';
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
    expect(rowerGiteFromImu(2), 2);
    expect(heelAlignmentX(5), lessThan(0));
    expect(heelAlignmentX(5, perspective: HeelPerspective.cox), greaterThan(0));
    expect(heelAlertFor(4.0), HeelAlert.tribord);
    expect(heelAlertFor(-4.0), HeelAlert.babord);
    expect(heelAlertFor(1.0), HeelAlert.none);
  });

  test('accéléro : gauche écran en bas = + tribords (portrait et paysage 90°)', () {
    // Portrait, téléphone debout (ay = ciel) : +ax = droite appareil = droite écran = gauche en bas.
    expect(screenHeelDeg(3, 9.8, 0, displayRotationDeg: 0), greaterThan(0));
    expect(screenHeelDeg(-3, 9.8, 0, displayRotationDeg: 0), lessThan(0));
    expect(screenHeelDeg(0, 9.8, 0, displayRotationDeg: 0), closeTo(0, 1e-9));
    // Paysage 90° (haut appareil = gauche écran) : repos ax = ciel ; gauche en bas = ay < 0.
    expect(screenHeelDeg(9.8, -3, 0, displayRotationDeg: 90), greaterThan(0));
    expect(screenHeelDeg(9.8, 3, 0, displayRotationDeg: 90), lessThan(0));
    expect(
      heelAlertFor(screenHeelDeg(9.8, -4, 0, displayRotationDeg: 90)),
      HeelAlert.tribord,
    );
    expect(
      heelAlertFor(screenHeelDeg(9.8, 4, 0, displayRotationDeg: 90)),
      HeelAlert.babord,
    );
  });

  test('couleurs bâbord rouge / tribord vert, alerte semi-transparente', () {
    expect(DeckColors.babord, const Color(0xFFE05353));
    expect(DeckColors.tribord, const Color(0xFF46C275));
    expect(DeckColors.tribordAlert, const Color(0xFF0F5C32));
    expect(DeckColors.tribord.toARGB32(), isNot(0xFF00E676));
    expect(
      HeelBanner.backgroundFor(HeelAlert.tribord).a,
      closeTo(0.80, 0.02),
    );
    expect(
      HeelBanner.backgroundFor(HeelAlert.babord).a,
      closeTo(0.80, 0.02),
    );
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
    f.reset();
    expect(f.filteredDeg, isNull);
  });

  testWidgets('bandeau trop tribords et trop bâbord, overlay', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HeelBanner(alert: HeelAlert.tribord)),
    );
    await tester.pump();
    expect(find.text('GÎTE — trop tribords'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: HeelBanner(alert: HeelAlert.babord)),
    );
    await tester.pump();
    expect(find.text('GÎTE — trop bâbord'), findsOneWidget);
  });

  testWidgets('bandeau overlay ne pousse pas le layout', (tester) async {
    const bodyKey = Key('live-body');
    Future<void> pumpAlert(HeelAlert a) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeelAlertOverlay(
              alert: a,
              child: const Column(
                children: [
                  SizedBox(key: bodyKey, height: 80, width: double.infinity),
                ],
              ),
            ),
          ),
        ),
      );
    }

    await pumpAlert(HeelAlert.none);
    await tester.pump();
    final y0 = tester.getTopLeft(find.byKey(bodyKey)).dy;
    await pumpAlert(HeelAlert.babord);
    await tester.pumpAndSettle();
    final y1 = tester.getTopLeft(find.byKey(bodyKey)).dy;
    expect(y1, y0);
    expect(find.text('GÎTE — trop bâbord'), findsOneWidget);

    await pumpAlert(HeelAlert.tribord);
    await tester.pumpAndSettle();
    expect(find.text('GÎTE — trop tribords'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(bodyKey)).dy, y0);
  });

  testWidgets('barreur : BÂBORD à gauche, TRIBORD à droite, réf. barreur', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HeelLabels(perspective: HeelPerspective.cox),
        ),
      ),
    );
    expect(find.text('réf. barreur'), findsOneWidget);
    expect(find.text('réf. rameur'), findsNothing);
    final ba = tester.getTopLeft(find.text('BÂBORD')).dx;
    final tri = tester.getTopLeft(find.text('TRIBORD')).dx;
    expect(ba < tri, isTrue);
  });
}
