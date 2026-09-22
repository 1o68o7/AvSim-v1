import 'package:datar0w/features/identity/screen_club.dart';
import 'package:datar0w/features/identity/screen_crew.dart';
import 'package:datar0w/features/identity/screen_home_roles.dart';
import 'package:datar0w/features/identity/screen_import.dart';
import 'package:datar0w/features/identity/screen_spinoscope.dart';
import 'package:datar0w/features/identity/screen_who.dart';
import 'package:datar0w/identity/controller.dart';
import 'package:datar0w/identity/models.dart';
import 'package:datar0w/session/boat_config.dart';
import 'package:datar0w/widgets/club_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'identity_test_helpers.dart';

class _SeededIdentity extends IdentityController {
  @override
  IdentitySnapshot build() {
    return IdentitySnapshot(
      rowers: [
        Rower.create(
          displayName: 'Camille Test',
          birthDate: DateTime(1998, 5, 10),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('Qui rame : passer sans profil visible', (tester) async {
    final ov = identityStoreOverride();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ov],
        child: const MaterialApp(home: IdentityListScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Passer (sans profil)'), findsOneWidget);
  });

  testWidgets('profil local listé sur Qui rame', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityStoreOverride(),
          identityProvider.overrideWith(_SeededIdentity.new),
        ],
        child: const MaterialApp(home: IdentityListScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Camille Test'), findsOneWidget);
  });

  testWidgets('club : pas de + Ajouter hors coach', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityStoreOverride()],
        child: const MaterialApp(home: ClubScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('+ Ajouter'), findsNothing);
    expect(find.text('ENREGISTRER LE CLUB'), findsNothing);
    expect(find.text('IMPORTER UN FICHIER'), findsNothing);
  });

  testWidgets('import coach : chips Parc / Rameurs', (tester) async {
    final container = ProviderContainer(
      overrides: [identityStoreOverride()],
    );
    addTearDown(container.dispose);
    container.read(boatConfigProvider.notifier).setRole(CrewRole.coach);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ClubImportScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('PARC'), findsOneWidget);
    expect(find.text('RAMEURS'), findsOneWidget);
    await tester.tap(find.text('RAMEURS'));
    await tester.pump();
    expect(find.text('TÉLÉCHARGER LE MODÈLE CSV'), findsOneWidget);
    expect(find.text('IMPORTER UN FICHIER'), findsOneWidget);
    expect(find.text('CHARGER LA BASE BORDEAUX'), findsOneWidget);
  });

  testWidgets('import : hors coach → réservé', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityStoreOverride()],
        child: const MaterialApp(home: ClubImportScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Réservé au coach.'), findsOneWidget);
    expect(find.text('CONFIRMER L’IMPORT'), findsNothing);
  });

  testWidgets('composition : hors coach → réservé', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityStoreOverride()],
        child: const MaterialApp(home: CrewScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Réservé au coach.'), findsOneWidget);
    expect(find.text('ENREGISTRER L’ÉQUIPAGE'), findsNothing);
  });

  testWidgets('spinoscope : vitrine effectif', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityStoreOverride(), opsStoreOverride()],
        child: const MaterialApp(home: SpinoscopeScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('EFFECTIF'), findsOneWidget);
    expect(find.text('COUPETTES'), findsOneWidget);
  });

  testWidgets('chip ~N licenciés (estimation club)', (tester) async {
    final club = Club.create(name: 'CN Test').copyWith(licenceCountApprox: 140);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ClubBanner(club: club)),
      ),
    );
    expect(find.text('~140 licenciés'), findsOneWidget);
  });

  testWidgets('accueil coach : Composer Rejoindre Parc', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeCoachScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('COMPOSER'), findsOneWidget);
    expect(find.text('REJOINDRE'), findsOneWidget);
    expect(find.text('PARC'), findsOneWidget);
    expect(find.text('SORTIR'), findsOneWidget);
    expect(find.text('RENTRER'), findsOneWidget);
    expect(find.text('DÉPART'), findsOneWidget);
    expect(find.text('MAINTENANCE'), findsOneWidget);
    expect(find.text('SPINOSCOPE'), findsOneWidget);
  });
}
