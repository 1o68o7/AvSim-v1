import 'package:datar0w/identity/controller.dart';
import 'package:datar0w/identity/models.dart';
import 'package:datar0w/onboarding/screen_rower.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'identity_test_helpers.dart';

void main() {
  test('profil 1er login : licence optionnelle, solo, pas bloquant', () async {
    final container = ProviderContainer(
      overrides: [identityStoreOverride()],
    );
    addTearDown(container.dispose);
    await container.read(identityProvider.notifier).completeRowerOnboarding(
          displayName: 'Ada',
          birthDate: DateTime.utc(1998, 5, 10),
          sex: RowerSex.f,
        );
    final snap = container.read(identityProvider);
    expect(snap.rowers.single.displayName, 'Ada');
    expect(snap.rowers.single.ffaLicence, isNull);
    expect(snap.prefs.clubRole, ClubMemberRole.rower);
    final json = snap.rowers.single.toJson();
    expect(json.containsKey('ffaLicence'), isFalse);
    expect(Rower.fromJson(json).ffaLicence, isNull);
  });

  test('join_club par code local + je barre aussi → cox', () async {
    final container = ProviderContainer(
      overrides: [identityStoreOverride()],
    );
    addTearDown(container.dispose);
    final n = container.read(identityProvider.notifier);
    await n.saveClub(Club.create(name: 'CNB', shortCode: 'CNB'));
    await n.completeRowerOnboarding(
      displayName: 'Lina',
      birthDate: DateTime.utc(2001, 4, 4),
      clubCode: 'cnb',
      coxToo: true,
      ffaLicence: '  ',
    );
    final snap = container.read(identityProvider);
    expect(snap.activeClub?.shortCode, 'CNB');
    expect(snap.prefs.clubRole, ClubMemberRole.cox);
    expect(snap.rowers.single.ffaLicence, isNull);
    expect(snap.rowers.single.clubId, snap.activeClub?.id);
  });

  testWidgets('écran : licence non bloquante + catégorie lecture seule',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityStoreOverride()],
        child: const MaterialApp(home: RowerOnboardingScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('TON PROFIL RAMEUR'), findsOneWidget);
    expect(find.text('Licence FFA (optionnel)'), findsOneWidget);
    expect(find.textContaining('Catégorie FFA'), findsOneWidget);
    expect(find.text('Je rame seul (loisir)'), findsOneWidget);
    expect(find.text('Je barre aussi'), findsOneWidget);
  });
}
