import 'package:datar0w/features/tare/screen_2b.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TARE GÎTE lance le chrono 30 s', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: TareScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('TARE GÎTE (30 S)'), findsOneWidget);
    await tester.tap(find.text('TARE GÎTE (30 S)'));
    await tester.pump();

    expect(find.textContaining('EN COURS'), findsWidgets);
    expect(find.textContaining('TARE EN COURS'), findsOneWidget);
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
    expect(find.text('LACET (YAW)'), findsOneWidget);
    expect(find.text('TARE GÎTE (30 S)'), findsOneWidget);
    final tri = tester.getTopLeft(find.text('TRIBORD').first).dx;
    final ba = tester.getTopLeft(find.text('BÂBORD').first).dx;
    expect(tri < ba, isTrue);
  });
}
