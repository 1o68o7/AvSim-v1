import 'package:datar0w/features/live/screen_3.dart';
import 'package:datar0w/widgets/heel_gauge.dart';
import 'package:datar0w/widgets/live_affordances.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DR-52 : cockpit 3 colonnes + cadran gîte', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LiveScreen())),
    );
    await tester.pump();

    expect(find.text('GÎTE COQUE'), findsOneWidget);
    expect(find.text('Cadence'), findsOneWidget);
    expect(find.text('Vitesse fond'), findsOneWidget);
    expect(find.text('Cardio-fréq.'), findsOneWidget);
    expect(find.textContaining('STOP / FIN'), findsOneWidget);
    expect(find.text('Tolérance ±3.0°'), findsOneWidget);
    expect(find.text('Angle actuel'), findsOneWidget);
    expect(find.byType(HeelGauge), findsOneWidget);
    expect(find.byType(LiveLayoutButton), findsOneWidget);
    expect(find.text('TRIBORD'), findsWidgets);
    expect(find.text('BÂBORD'), findsWidgets);
    // Convention rameur : TRIBORD à gauche.
    final tri = tester.getTopLeft(find.text('TRIBORD').first).dx;
    final ba = tester.getTopLeft(find.text('BÂBORD').first).dx;
    expect(tri < ba, isTrue);
  });
}
