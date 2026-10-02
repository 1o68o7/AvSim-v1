import 'package:datar0w/features/tare/screen_2b.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Tare lance l’étalonnage adaptatif', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: TareScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Coque calme'), findsOneWidget);
    expect(find.text('Tourne en paysage'), findsOneWidget);
    await tester.tap(find.text('Tourne en paysage'));
    await tester.pump();

    expect(find.textContaining('En cours'), findsNothing);
  });

  testWidgets('2B paysage : TRIBORD à gauche, sans pitch/yaw', (tester) async {
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
    expect(find.text('LACET (YAW)'), findsNothing);
    expect(find.text('TANGAGE (PITCH)'), findsNothing);
    expect(find.text('Tare'), findsWidgets);
    expect(find.textContaining('Coque calme'), findsWidgets);
    final tri = tester.getTopLeft(find.text('TRIBORD').first).dx;
    final ba = tester.getTopLeft(find.text('BÂBORD').first).dx;
    expect(tri < ba, isTrue);
  });
}
