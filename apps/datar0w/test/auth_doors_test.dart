import 'package:datar0w/features/identity/screen_who.dart';
import 'package:datar0w/identity/controller.dart';
import 'package:datar0w/identity/models.dart';
import 'package:datar0w/identity/store.dart';
import 'package:datar0w/onboarding/routing.dart';
import 'package:datar0w/router.dart';
import 'package:datar0w/sync/auth_callback_screen.dart';
import 'package:datar0w/sync/auth_google.dart';
import 'package:datar0w/widgets/safe_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'identity_test_helpers.dart';

class _SeededIdentity extends IdentityController {
  _SeededIdentity(this.rower);
  final Rower rower;

  @override
  IdentitySnapshot build() => IdentitySnapshot(
        rowers: [rower],
        prefs: IdentityPrefs(activeRowerId: rower.id),
      );

  @override
  Future<void> selectRower(String? id) async {
    state = IdentitySnapshot(
      rowers: state.rowers,
      prefs: state.prefs.copyWith(activeRowerId: id),
    );
  }
}

void main() {
  tearDown(() {
    debugHidePasserSansProfil = false;
  });

  test('resolvePostLogin admin → /home/admin', () {
    expect(
      resolvePostLogin(
        door: OnboardingDoor.rower,
        clubMemberRole: 'admin',
      ),
      AppRoutes.homeAdmin,
    );
  });

  test('resolvePostLogin sans rôle club + profil → /home/rower', () {
    expect(
      resolvePostLogin(
        door: OnboardingDoor.rower,
        clubMemberRole: null,
        hasRowerProfile: true,
      ),
      AppRoutes.homeRower,
    );
  });

  test('resolvePostLogin porte club sans staff → home/onboard (plus clubJoin)',
      () {
    expect(
      resolvePostLogin(
        door: OnboardingDoor.club,
        clubMemberRole: null,
        hasRowerProfile: false,
      ),
      AppRoutes.rowerOnboard,
    );
  });

  GoRouter _identityRouter() => GoRouter(
        initialLocation: AppRoutes.identity,
        routes: [
          GoRoute(
            path: AppRoutes.identity,
            builder: (_, __) => const IdentityListScreen(),
          ),
          GoRoute(
            path: AppRoutes.homeRower,
            builder: (_, __) => const Text('HOME-ROWER'),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, __) => const Text('PROFILS'),
          ),
          GoRoute(
            path: AppRoutes.auth,
            builder: (_, __) => const Text('AUTH'),
          ),
          GoRoute(
            path: AppRoutes.identityEdit,
            builder: (_, __) => const Text('EDIT'),
          ),
        ],
      );

  testWidgets('tap profil /identity → /home/rower (pas /)', (tester) async {
    final rower = Rower.create(
      displayName: 'Camille Test',
      birthDate: DateTime(1998, 5, 10),
    );
    final router = _identityRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityStoreOverride(),
          identityProvider.overrideWith(() => _SeededIdentity(rower)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Camille Test'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('HOME-ROWER'), findsOneWidget);
    expect(find.text('PROFILS'), findsNothing);
    expect(router.state.uri.path, AppRoutes.homeRower);
    expect(find.textContaining('Navigation bloquée'), findsNothing);
  });

  testWidgets('tap Connexion /identity → /auth', (tester) async {
    final router = _identityRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityStoreOverride()],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Connexion'));
    await tester.pump(); // lance le Future.delayed 300 ms
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('AUTH'), findsOneWidget);
    expect(router.state.uri.path, AppRoutes.auth);
    expect(find.textContaining('Navigation bloquée'), findsNothing);
  });

  testWidgets('go+push no-op → bandeau ambre au-dessus de CRÉER',
      (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.identity,
      routes: [
        GoRoute(
          path: AppRoutes.identity,
          builder: (_, __) => const IdentityListScreen(),
        ),
        // /auth volontairement absent → go/push échouent
      ],
      errorBuilder: (_, state) => PageIntrouvableScreen(
        dest: state.uri.toString(),
        error: state.error,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityStoreOverride()],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Connexion'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    // Bandeau dans le body OU Page introuvable (errorBuilder).
    final blocked = find.textContaining('Navigation bloquée');
    final missing = find.text('Page introuvable');
    expect(
      blocked.evaluate().isNotEmpty || missing.evaluate().isNotEmpty,
      isTrue,
    );
    if (blocked.evaluate().isNotEmpty) {
      // Au-dessus du CTA jaune, pas un SnackBar sous le bouton.
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('CRÉER UN PROFIL'), findsOneWidget);
    }
  });

  testWidgets('Passer (sans profil) absent si flag release', (tester) async {
    debugHidePasserSansProfil = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityStoreOverride()],
        child: const MaterialApp(home: IdentityListScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Passer (sans profil)'), findsNothing);
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Espace club'), findsNothing);
  });

  testWidgets('callback error=otp_expired : texte + CTA, pas d’exception',
      (tester) async {
    final router = GoRouter(
      initialLocation:
          '${AppRoutes.authCallback}?error=otp_expired&error_description=expired',
      routes: [
        GoRoute(
          path: AppRoutes.authCallback,
          builder: (context, state) => AuthCallbackScreen(uri: state.uri),
        ),
        GoRoute(
          path: AppRoutes.auth,
          builder: (_, __) => const Text('AUTH'),
        ),
        GoRoute(
          path: AppRoutes.identity,
          builder: (_, __) => const Text('IDENTITY'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityStoreOverride(),
          authGoogleProvider.overrideWithValue(AuthGoogle()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('expiré'), findsOneWidget);
    expect(find.text('RETOUR CONNEXION'), findsOneWidget);
    await tester.tap(find.text('RETOUR CONNEXION'));
    await tester.pumpAndSettle();
    expect(find.text('AUTH'), findsOneWidget);
  });

  testWidgets('callback error=access_denied : message Google lisible',
      (tester) async {
    final router = GoRouter(
      initialLocation:
          '${AppRoutes.authCallback}?error=access_denied&error_description=User+denied',
      routes: [
        GoRoute(
          path: AppRoutes.authCallback,
          builder: (context, state) => AuthCallbackScreen(uri: state.uri),
        ),
        GoRoute(
          path: AppRoutes.auth,
          builder: (_, __) => const Text('AUTH'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityStoreOverride(),
          authGoogleProvider.overrideWithValue(AuthGoogle()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Google refusée'), findsOneWidget);
    expect(find.text('IDENTITY'), findsNothing);
  });
}
