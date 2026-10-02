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
    expect(find.text('Rameur'), findsOneWidget);
    expect(find.text('Coach'), findsOneWidget);
    expect(find.text('Barreur'), findsOneWidget);
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
    expect(find.text('Créer un profil'), findsOneWidget);
    expect(find.text('Qui est là'), findsWidgets);
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
    expect(find.textContaining('Continuer'), findsOneWidget);
    expect(find.textContaining('Pas d’affectation'), findsOneWidget);
    expect(find.text("Aujourd'hui"), findsWidgets);
    expect(find.text('Séances'), findsOneWidget);
    expect(find.text('Ajouter'), findsNothing);
  });
}
