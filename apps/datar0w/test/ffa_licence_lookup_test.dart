import 'package:datar0w/identity/controller.dart';
import 'package:datar0w/identity/ffa_licence_lookup.dart';
import 'package:datar0w/identity/models.dart';
import 'package:datar0w/onboarding/screen_rower.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'identity_test_helpers.dart';

void main() {
  test('lookup hit / miss / vide', () {
    final hit = lookupFfaLicence('1234567a');
    expect(hit, isA<FfaLicenceFound>());
    expect((hit as FfaLicenceFound).hit.displayName, 'Ada Lovelace');
    expect(hit.hit.clubName, 'CN Bordeaux');

    expect(lookupFfaLicence('9999999Z'), isA<FfaLicenceLeisure>());
    expect(lookupFfaLicence(''), isA<FfaLicenceLeisure>());
    expect(lookupFfaLicence('  '), isA<FfaLicenceLeisure>());
  });

  test('normalize ignore espaces et casse', () {
    expect(normalizeFfaLicence(' 1234-567a '), '1234567A');
  });

  test('completeRowerOnboarding conserve licence', () async {
    final container = ProviderContainer(
      overrides: [identityStoreOverride()],
    );
    addTearDown(container.dispose);
    await container.read(identityProvider.notifier).completeRowerOnboarding(
          displayName: 'Ada',
          birthDate: DateTime.utc(1998, 5, 10),
          sex: RowerSex.f,
          ffaLicence: '1234567A',
        );
    expect(
      container.read(identityProvider).rowers.single.ffaLicence,
      '1234567A',
    );
  });

  test('completeRowerOnboarding PASSER → licence null', () async {
    final container = ProviderContainer(
      overrides: [identityStoreOverride()],
    );
    addTearDown(container.dispose);
    await container.read(identityProvider.notifier).completeRowerOnboarding(
          displayName: 'Ada',
          birthDate: DateTime.utc(1998, 5, 10),
          sex: RowerSex.f,
          ffaLicence: null,
        );
    expect(container.read(identityProvider).rowers.single.ffaLicence, isNull);
  });

  testWidgets('ST-08 étape Licence & club : helper + Passer + Finaliser',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityStoreOverride()],
        child: const MaterialApp(home: RowerOnboardingScreen()),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Ada');
    await tester.tap(find.text('Continuer'));
    await tester.pump();
    expect(find.text('Licence & club'), findsOneWidget);
    expect(find.textContaining('Loisir sans licence'), findsOneWidget);
    expect(find.textContaining('Passer cette étape'), findsOneWidget);
    expect(
      find.textContaining('Finaliser mon profil'),
      findsOneWidget,
    );
  });

  test('miss → Profil loisir (pas erreur)', () {
    final r = lookupFfaLicence('0000000X');
    expect(r, isA<FfaLicenceLeisure>());
    expect(r, isNot(isA<FfaLicenceFound>()));
  });
}
