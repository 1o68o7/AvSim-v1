import 'package:datar0w/sync/auth_screen.dart';
import 'package:datar0w/sync/config.dart';
import 'package:datar0w/sync/supabase_boot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'identity_test_helpers.dart';

void main() {
  test('sans dart-define, cloud désactivé (mode local)', () {
    expect(SyncConfig.enabled, isFalse);
    expect(SyncConfig.url, isEmpty);
    expect(SyncConfig.anonKey, isEmpty);
    expect(SyncConfig.redirect, 'datarow://auth/callback');
  });

  test('supabaseOrNull typé SupabaseClient? (pas dynamic)', () {
    // Régression P0 : dynamic cassait l’extension signInWithOAuth.
    final client = supabaseOrNull();
    expect(client, isNull);
    expect(client, isA<SupabaseClient?>());
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

  testWidgets('Google sans client → SnackBar Cloud indisponible', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityStoreOverride()],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('CONTINUER AVEC GOOGLE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Cloud indisponible'), findsWidgets);
    expect(supabaseOrNull(), isNull);
  });
}
