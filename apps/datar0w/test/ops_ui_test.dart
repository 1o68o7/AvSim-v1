import 'package:datar0w/features/identity/screen_crew.dart';
import 'package:datar0w/features/identity/screen_home_roles.dart';
import 'package:datar0w/features/ops/screen_departure.dart';
import 'package:datar0w/features/ops/screen_impact.dart';
import 'package:datar0w/features/ops/screen_in.dart';
import 'package:datar0w/features/ops/screen_out.dart';
import 'package:datar0w/identity/controller.dart';
import 'package:datar0w/identity/models.dart';
import 'package:datar0w/identity/store.dart';
import 'package:datar0w/session/boat_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'identity_test_helpers.dart';

class _ParkIdentity extends IdentityController {
  @override
  IdentitySnapshot build() {
    final club = Club.create(name: 'CN Test', shortCode: 'CNT');
    final ready = ParkBoat.create(
      clubId: club.id,
      name: 'Hudson',
      classe: '4x',
    );
    final out = ParkBoat.create(
      clubId: club.id,
      name: 'Empacher',
      classe: '8+',
      status: BoatParkStatus.out,
    );
    return IdentitySnapshot(
      clubs: [club],
      boats: [ready, out],
      prefs: IdentityPrefs(activeClubId: club.id),
    );
  }
}

void main() {
  testWidgets('accueil coach : Sortir Rentrer', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeCoachScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('SORTIR'), findsOneWidget);
    expect(find.text('RENTRER'), findsOneWidget);
    expect(find.text('DÉPART'), findsOneWidget);
    expect(find.text('MAINTENANCE'), findsOneWidget);
    expect(find.text('SPINOSCOPE'), findsOneWidget);
  });

  testWidgets('sortie : hors coach → réservé', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityStoreOverride(), opsStoreOverride()],
        child: const MaterialApp(home: OpsOutScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Réservé au coach.'), findsOneWidget);
    expect(find.text('SORTIR'), findsNothing);
  });

  testWidgets('retour : hors coach → réservé', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityStoreOverride(), opsStoreOverride()],
        child: const MaterialApp(home: OpsInScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Réservé au coach.'), findsOneWidget);
  });

  testWidgets('composition : coque sortie grisée', (tester) async {
    final container = ProviderContainer(
      overrides: [
        identityStoreOverride(),
        opsStoreOverride(),
        identityProvider.overrideWith(_ParkIdentity.new),
      ],
    );
    addTearDown(container.dispose);
    container.read(boatConfigProvider.notifier).setRole(CrewRole.coach);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CrewScreen()),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Empacher — sortie'), findsOneWidget);
    expect(find.textContaining('Hudson'), findsOneWidget);
  });

  testWidgets('départ : hors coach → réservé', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityStoreOverride(), opsStoreOverride()],
        child: const MaterialApp(home: OpsDepartureScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Réservé au coach.'), findsOneWidget);
  });

  testWidgets('maintenance : file vide', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityStoreOverride(), opsStoreOverride()],
        child: const MaterialApp(home: MaintenanceQueueScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Aucun signalement ouvert.'), findsOneWidget);
  });
}
