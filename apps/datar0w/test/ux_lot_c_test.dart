import 'package:datar0w/features/live/screen_3.dart';
import 'package:datar0w/widgets/live_affordances.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpLive(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LiveScreen())),
    );
    await tester.pump();
  }

  testWidgets('live : Layout visible, pas d’Accueil', (tester) async {
    await pumpLive(tester);
    expect(find.text('Layout'), findsOneWidget);
    expect(find.text('Accueil'), findsNothing);
    expect(find.text('Retour'), findsNothing);
    final box = tester.getSize(find.byType(LiveLayoutButton));
    expect(box.width, greaterThanOrEqualTo(48));
    expect(box.height, greaterThanOrEqualTo(48));
  });

  testWidgets('live : 1er STOP affiche Encore une fois pour arrêter', (tester) async {
    await pumpLive(tester);
    expect(find.text(kStopArmedMessage), findsNothing);
    await tester.tap(find.textContaining('TOUCHER 2×'));
    await tester.pump();
    expect(find.text(kStopArmedMessage), findsOneWidget);
    expect(find.text('Accueil'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });
}
