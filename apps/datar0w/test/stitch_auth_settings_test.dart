import 'package:datar0w/features/identity/screen_settings.dart';
import 'package:datar0w/router.dart';
import 'package:datar0w/sync/auth_google.dart';
import 'package:datar0w/sync/auth_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'identity_test_helpers.dart';

class _FakeBackend implements AuthBackend {
  String? userId;

  @override
  Future<bool> startGoogle({required String redirectTo}) async => false;

  @override
  Future<void> startMagicLink({
    required String email,
    required String redirectTo,
  }) async {}

  @override
  Future<bool> recoverSession(Uri uri) async => userId != null;

  @override
  String? currentUserId() => userId;
}

void main() {
  testWidgets('ST-02 session OFF : Google + email, pas Espace club',
      (tester) async {
    final auth = AuthGoogle(backend: _FakeBackend());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityStoreOverride(),
          authGoogleProvider.overrideWithValue(auth),
        ],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('CONNEXION'), findsOneWidget);
    expect(find.text('CONTINUER AVEC GOOGLE'), findsOneWidget);
    expect(find.text('par email'), findsOneWidget);
    expect(find.text('ENVOYER LE LIEN'), findsNothing);
    await tester.tap(find.text('par email'));
    await tester.pump();
    expect(find.text('ENVOYER LE LIEN'), findsOneWidget);
    expect(find.textContaining('Espace club'), findsNothing);
    expect(find.text('CONTINUER'), findsNothing);
    if (kDebugMode) {
      expect(find.text('Sans compte'), findsOneWidget);
    }
  });

  testWidgets('ST-01 session ON : Continuer + Rattacher + Déconnexion',
      (tester) async {
    final backend = _FakeBackend()..userId = 'u-1';
    final auth = AuthGoogle(backend: backend)..sessionUserId = 'u-1';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityStoreOverride(),
          authGoogleProvider.overrideWithValue(auth),
        ],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Connecté'), findsOneWidget);
    expect(find.text('CONTINUER'), findsOneWidget);
    expect(find.text('Rattacher ce téléphone'), findsOneWidget);
    expect(find.text('DÉCONNEXION'), findsOneWidget);
    expect(find.text('CONTINUER AVEC GOOGLE'), findsNothing);
  });

  testWidgets('ST-10 /settings : lignes + déconnexion dialog', (tester) async {
    final backend = _FakeBackend()..userId = 'u-1';
    final auth = AuthGoogle(backend: backend)..sessionUserId = 'u-1';
    final router = GoRouter(
      initialLocation: AppRoutes.settings,
      routes: [
        GoRoute(
          path: AppRoutes.settings,
          builder: (_, _) => const SettingsScreen(),
        ),
        GoRoute(
          path: AppRoutes.identity,
          builder: (_, _) => const Text('IDENTITY'),
        ),
        GoRoute(
          path: AppRoutes.auth,
          builder: (_, _) => const Text('AUTH'),
        ),
        GoRoute(
          path: AppRoutes.homeRower,
          builder: (_, _) => const Text('HOME'),
        ),
        GoRoute(
          path: AppRoutes.identityEdit,
          builder: (_, _) => const Text('EDIT'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityStoreOverride(),
          authGoogleProvider.overrideWithValue(auth),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Réglages'), findsOneWidget);
    expect(find.text('Profil local'), findsOneWidget);
    expect(find.text('Compte'), findsOneWidget);
    expect(find.text('Capteurs'), findsOneWidget);
    expect(find.text('Objets connectés'), findsOneWidget);
    expect(find.textContaining('séances restent'), findsWidgets);
    expect(find.text('Déconnexion'), findsOneWidget);
    await tester.tap(find.text('Déconnexion'));
    await tester.pumpAndSettle();
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Déconnecter'), findsOneWidget);
  });
}
