import 'package:datar0w/features/cox/screen_cox.dart';
import 'package:datar0w/features/presession/screen_2a.dart';
import 'package:datar0w/features/tare/screen_2b.dart';
import 'package:datar0w/router.dart';
import 'package:datar0w/session/boat_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'identity_test_helpers.dart';

void main() {
  test('BARREUR après tare → /cox, rameur → /live', () {
    expect(AppRoutes.sessions, '/sessions');
    expect(AppRoutes.rowerReplay, '/replay');
    expect(AppRoutes.afterTare(CrewRole.cox), AppRoutes.cox);
    expect(AppRoutes.afterTare(CrewRole.rower), AppRoutes.live);
    expect(AppRoutes.afterTare(CrewRole.cox), isNot(AppRoutes.live));
  });

  testWidgets('2A : Retour profil + pas de suffixe 2 000 m', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PresessionScreen()),
      ),
    );
    expect(find.text('Retour'), findsWidgets);
    expect(find.text('2 000 m'), findsNothing);
  });

  testWidgets('2B : Retour profil absent pendant la tare', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: TareScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Retour'), findsWidgets);
    await tester.tap(find.text('TARE GÎTE'));
    await tester.pump();
    expect(find.text('Retour'), findsNothing);
  });

  testWidgets('BARREUR 8+ : /cox affiche l’écran barreur, pas le live rameur',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ov = identityStoreOverride();
    final container = ProviderContainer(overrides: [ov]);
    addTearDown(container.dispose);
    container.read(boatConfigProvider.notifier).setRole(CrewRole.cox);
    container.read(boatConfigProvider.notifier).setClasse('8+');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CoxLiveScreen()),
      ),
    );
    await tester.pump();
    expect(find.textContaining('BARREUR'), findsWidgets);
    expect(find.text('réf. barreur'), findsOneWidget);
    expect(find.text('réf. rameur'), findsNothing);
  });
}
