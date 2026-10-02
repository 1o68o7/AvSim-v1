import 'package:datar0w/features/tare/screen_2b.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Tare gîte lance l’étalonnage adaptatif', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: TareScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Position de séance'), findsOneWidget);
    expect(find.text('Tourner en paysage pour tarer'), findsOneWidget);
    await tester.tap(find.text('Tourner en paysage pour tarer'));
    await tester.pump();

    expect(find.textContaining('En cours'), findsNothing);
  });

  testWidgets('2B paysage : TRIBORD à gauche, lacet —', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: TareScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('TRIBORD'), findsWidgets);
    expect(find.text('BÂBORD'), findsWidgets);
    expect(find.text('Lacet (yaw)'), findsOneWidget);
    expect(find.text('Tare gîte'), findsOneWidget);
    expect(find.textContaining('Position de séance'), findsOneWidget);
    final tri = tester.getTopLeft(find.text('TRIBORD').first).dx;
    final ba = tester.getTopLeft(find.text('BÂBORD').first).dx;
    expect(tri < ba, isTrue);
  });
}
