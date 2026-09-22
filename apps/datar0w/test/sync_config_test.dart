import 'package:datar0w/sync/auth_screen.dart';
import 'package:datar0w/sync/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'identity_test_helpers.dart';

void main() {
  test('sans dart-define, cloud désactivé (mode local)', () {
    expect(SyncConfig.enabled, isFalse);
    expect(SyncConfig.url, isEmpty);
    expect(SyncConfig.anonKey, isEmpty);
    expect(SyncConfig.redirect, 'datarow://auth/callback');
  });

  testWidgets('/auth sans clés = mode local no-op', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityStoreOverride()],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('mode local'), findsOneWidget);
    expect(find.text('CONTINUER AVEC GOOGLE'), findsOneWidget);
    expect(find.text('ENVOYER LE LIEN'), findsNothing);
    expect(find.textContaining('Pas de clés cloud'), findsOneWidget);
  });
}
