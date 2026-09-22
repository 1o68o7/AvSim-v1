import 'package:datar0w/identity/controller.dart';
import 'package:datar0w/identity/models.dart';
import 'package:datar0w/onboarding/routing.dart';
import 'package:datar0w/onboarding/screen_club_home.dart';
import 'package:datar0w/onboarding/screen_club_join.dart';
import 'package:datar0w/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'identity_test_helpers.dart';

void main() {
  test('rôles étendus + homes', () {
    expect(ClubMemberRoleX.parse('treasurer'), ClubMemberRole.treasurer);
    expect(ClubMemberRoleX.parse('intendant'), ClubMemberRole.intendant);
    expect(ClubMemberRoleX.parse('director'), ClubMemberRole.director);
    expect(homeRouteForClubRole('intendant'), AppRoutes.homeIntendant);
    expect(homeRouteForClubRole('director'), AppRoutes.homeDirector);
  });

  test('créer un club → admin ; demande soumise à validation', () async {
    final container = ProviderContainer(
      overrides: [identityStoreOverride()],
    );
    addTearDown(container.dispose);
    final n = container.read(identityProvider.notifier);
    await n.createClubAsAdmin(name: 'CNB', shortCode: 'CNB');
    expect(container.read(identityProvider).prefs.clubRole, ClubMemberRole.admin);
    final req = await n.requestClubRole(
      code: 'CNB',
      role: ClubMemberRole.coach,
      userId: 'u-2',
    );
    expect(req, isNotNull);
    expect(req!.status, 'pending');
    await n.decideJoinRequest(req, accept: true);
    expect(
      container.read(identityProvider).joinRequests.single.status,
      'approved',
    );
  });

  test('rower ne valide pas une demande', () async {
    final container = ProviderContainer(
      overrides: [identityStoreOverride()],
    );
    addTearDown(container.dispose);
    final n = container.read(identityProvider.notifier);
    await n.createClubAsAdmin(name: 'A', shortCode: 'AAA');
    final req = await n.requestClubRole(
      code: 'AAA',
      role: ClubMemberRole.intendant,
      userId: 'u-3',
    );
    await n.setClubRole(ClubMemberRole.rower);
    await n.decideJoinRequest(req!, accept: true);
    expect(
      container.read(identityProvider).joinRequests.single.status,
      'pending',
    );
  });

  testWidgets('écran rejoindre / créer + home intendant', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityStoreOverride()],
        child: const MaterialApp(home: ClubJoinScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Rejoindre ou créer'), findsOneWidget);
    expect(find.text('CRÉER LE CLUB'), findsOneWidget);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityStoreOverride()],
        child: const MaterialApp(
          home: ClubRoleHomeScreen(role: ClubMemberRole.intendant),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('ACCUEIL INTENDANT'), findsOneWidget);
    expect(find.text('MAINTENANCE'), findsOneWidget);
  });
}
