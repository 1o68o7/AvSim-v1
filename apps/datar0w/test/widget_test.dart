import 'package:datar0w/features/identity/screen_home_rower.dart';
import 'package:datar0w/features/identity/screen_who.dart';
import 'package:datar0w/features/profile/screen_1.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'identity_test_helpers.dart';

void main() {
  testWidgets('écran 1 profils Deck', (WidgetTester tester) async {
    final ov = identityStoreOverride();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ov],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('RAMEUR'), findsOneWidget);
    expect(find.text('COACH'), findsOneWidget);
    expect(find.text('BARREUR'), findsOneWidget);
  });

  testWidgets('Qui rame : passer sans profil', (tester) async {
    final ov = identityStoreOverride();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ov],
        child: const MaterialApp(home: IdentityListScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Passer (sans profil)'), findsOneWidget);
    expect(find.text('CRÉER UN PROFIL'), findsOneWidget);
  });

  testWidgets('accueil rameur : état vide, pas de parc', (tester) async {
    final ov = identityStoreOverride();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ov],
        child: const MaterialApp(home: HomeRowerScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('CONTINUER'), findsOneWidget);
    expect(find.textContaining('Pas d’affectation'), findsOneWidget);
    expect(find.text('MES SÉANCES'), findsOneWidget);
    expect(find.text('Ajouter'), findsNothing);
  });
}
