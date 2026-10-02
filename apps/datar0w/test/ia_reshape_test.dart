import 'dart:io';

import 'package:datar0w/features/identity/screen_home_rower.dart';
import 'package:datar0w/features/identity/screen_who.dart';
import 'package:datar0w/features/presession/screen_2a.dart';
import 'package:datar0w/features/profile/screen_1.dart';
import 'package:datar0w/features/quai/screen_7.dart';
import 'package:datar0w/features/tare/screen_2b.dart';
import 'package:datar0w/identity/controller.dart';
import 'package:datar0w/identity/models.dart';
import 'package:datar0w/identity/store.dart';
import 'package:datar0w/onboarding/routing.dart';
import 'package:datar0w/onboarding/screen_club_home.dart';
import 'package:datar0w/router.dart';
import 'package:datar0w/session/boat_config.dart';
import 'package:datar0w/sync/auth_google.dart';
import 'package:datar0w/sync/auth_screen.dart';
import 'package:datar0w/widgets/nav_swipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'identity_test_helpers.dart';

class _RowerIdentity extends IdentityController {
  _RowerIdentity(this.rower);
  final Rower rower;

  @override
  IdentitySnapshot build() => IdentitySnapshot(
        rowers: [rower],
        prefs: IdentityPrefs(
          activeRowerId: rower.id,
          clubRole: ClubMemberRole.rower,
        ),
      );
}

class _AdminIdentity extends IdentityController {
  @override
  IdentitySnapshot build() => IdentitySnapshot(
        prefs: IdentityPrefs(
          activeClubId: 'c1',
          clubRole: ClubMemberRole.admin,
        ),
      );
}

class _EmptyIdentity extends IdentityController {
  @override
  IdentitySnapshot build() => const IdentitySnapshot();
}

GoRouter _testRouter({required String initial}) {
  return GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: AppRoutes.identity,
        builder: (context, state) => const IdentityListScreen(),
      ),
      GoRoute(
        path: AppRoutes.homeRower,
        builder: (context, state) => const HomeRowerScreen(),
      ),
      GoRoute(
        path: AppRoutes.homeCox,
        builder: (context, state) => const Scaffold(body: Text('HOME_COX')),
      ),
      GoRoute(
        path: AppRoutes.homeCoach,
        builder: (context, state) => const Scaffold(body: Text('HOME_COACH')),
      ),
      GoRoute(
        path: AppRoutes.homeAdmin,
        builder: (context, state) =>
            const ClubRoleHomeScreen(role: ClubMemberRole.admin),
      ),
      GoRoute(
        path: AppRoutes.profile,
        redirect: (context, state) {
          final snap =
              ProviderScope.containerOf(context).read(identityProvider);
          return resolveRootRedirect(snap);
        },
      ),
      GoRoute(
        path: AppRoutes.clubImport,
        redirect: (context, state) {
          final snap =
              ProviderScope.containerOf(context).read(identityProvider);
          return clubStaffToolsRedirect(snap);
        },
        builder: (context, state) => const Scaffold(body: Text('IMPORT')),
      ),
      GoRoute(
        path: AppRoutes.clubLogin,
        redirect: (context, state) => AppRoutes.auth,
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.quai,
        builder: (context, state) => const QuaiScreen(),
      ),
      GoRoute(
        path: AppRoutes.live,
        builder: (context, state) => const Scaffold(body: Text('LIVE')),
      ),
      GoRoute(
        path: AppRoutes.cox,
        builder: (context, state) => const Scaffold(body: Text('COX')),
      ),
      GoRoute(
        path: AppRoutes.coachLive,
        builder: (context, state) => const Scaffold(body: Text('COACH')),
      ),
    ],
  );
}

void main() {
  test('1. initialLocation == /identity', () {
    expect(AppRoutes.identity, '/identity');
    // Contrat router.dart : GoRouter(initialLocation: AppRoutes.identity).
  });

  test('resolveRootRedirect : staff / rower / vide', () {
    final rower = Rower.create(
      displayName: 'Ada',
      birthDate: DateTime.utc(2000),
    );
    expect(
      resolveRootRedirect(
        IdentitySnapshot(
          rowers: [rower],
          prefs: IdentityPrefs(
            activeRowerId: rower.id,
            clubRole: ClubMemberRole.rower,
          ),
        ),
      ),
      AppRoutes.homeRower,
    );
    expect(
      resolveRootRedirect(
        IdentitySnapshot(
          prefs: IdentityPrefs(
            activeClubId: 'c',
            clubRole: ClubMemberRole.admin,
          ),
        ),
      ),
      AppRoutes.homeAdmin,
    );
    expect(resolveRootRedirect(const IdentitySnapshot()), AppRoutes.identity);
  });

  testWidgets('2. go(/) profil rameur → /home/rower, pas ProfileScreen',
      (tester) async {
    final rower = Rower.create(
      displayName: 'Ada',
      birthDate: DateTime.utc(2000),
    );
    final container = ProviderContainer(
      overrides: [
        identityStoreOverride(),
        identityProvider.overrideWith(() => _RowerIdentity(rower)),
      ],
    );
    addTearDown(container.dispose);
    final router = _testRouter(initial: AppRoutes.profile);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsNothing);
    // Stitch DR-20 : titre hub « Aujourd'hui » (shell + AppBar).
    expect(find.text("Aujourd'hui"), findsWidgets);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.homeRower,
    );
  });

  testWidgets('3. go(/) sans profil → /identity', (tester) async {
    final container = ProviderContainer(
      overrides: [
        identityStoreOverride(),
        identityProvider.overrideWith(_EmptyIdentity.new),
      ],
    );
    addTearDown(container.dispose);
    final router = _testRouter(initial: AppRoutes.profile);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.identity,
    );
    // Stitch : écran profils (ex Hangar « QUI RAME »).
    expect(find.text('Profils'), findsOneWidget);
  });

  testWidgets('4. staff admin go(/) → /home/admin', (tester) async {
    final container = ProviderContainer(
      overrides: [
        identityStoreOverride(),
        identityProvider.overrideWith(_AdminIdentity.new),
      ],
    );
    addTearDown(container.dispose);
    final router = _testRouter(initial: AppRoutes.profile);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.homeAdmin,
    );
    // Stitch DR-40 : hub staff « Aujourd'hui » (shell + AppBar).
    expect(find.text("Aujourd'hui"), findsWidgets);
  });

  testWidgets('5. quai Retour accueil selon rôle séance', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rower = Rower.create(
      displayName: 'Ada',
      birthDate: DateTime.utc(2000),
    );
    for (final entry in [
      // Hub rameur Stitch : « Aujourd'hui » (plusieurs occurrences shell).
      (CrewRole.rower, AppRoutes.homeRower, "Aujourd'hui", true),
      (CrewRole.cox, AppRoutes.homeCox, 'HOME_COX', false),
      (CrewRole.coach, AppRoutes.homeCoach, 'HOME_COACH', false),
    ]) {
      final container = ProviderContainer(
        overrides: [
          identityStoreOverride(),
          identityProvider.overrideWith(() => _RowerIdentity(rower)),
        ],
      );
      addTearDown(container.dispose);
      container.read(boatConfigProvider.notifier).setRole(entry.$1);
      final router = _testRouter(initial: AppRoutes.quai);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Retour accueil'));
      await tester.tap(find.text('Retour accueil'));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        entry.$2,
        reason: 'role ${entry.$1}',
      );
      expect(
        find.text(entry.$3),
        entry.$4 ? findsWidgets : findsOneWidget,
      );
    }
  });

  testWidgets('6. rameur go(/club/import) → /home/rower', (tester) async {
    final rower = Rower.create(
      displayName: 'Ada',
      birthDate: DateTime.utc(2000),
    );
    final container = ProviderContainer(
      overrides: [
        identityStoreOverride(),
        identityProvider.overrideWith(() => _RowerIdentity(rower)),
      ],
    );
    addTearDown(container.dispose);
    final router = _testRouter(initial: AppRoutes.clubImport);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.homeRower,
    );
    expect(find.text('IMPORT'), findsNothing);
  });

  test('7. signOut ne wipe pas un dossier séance', () async {
    final dir = Directory.systemTemp.createTempSync('datar0w_sess_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final marker = File('${dir.path}/samples.jsonl')
      ..writeAsStringSync('{"t":1}\n');
    final auth = AuthGoogle();
    await auth.signOut();
    expect(marker.existsSync(), isTrue);
    expect(marker.readAsStringSync(), contains('"t":1'));
  });

  test('8. live / cox / coach : navSwipeBlocked', () {
    expect(navSwipeBlocked(AppRoutes.live), isTrue);
    expect(navSwipeBlocked(AppRoutes.cox), isTrue);
    expect(navSwipeBlocked(AppRoutes.coachLive), isTrue);
  });

  testWidgets('9. titres visibles : pas de 2A / 2B / Écran 6', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PresessionScreen()),
      ),
    );
    expect(find.textContaining('2A'), findsNothing);
    expect(find.textContaining('Écran 6'), findsNothing);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: TareScreen()),
      ),
    );
    await tester.pump();
    expect(find.textContaining('2B'), findsNothing);
  });

  testWidgets('10. /club/login redirect /auth', (tester) async {
    final router = _testRouter(initial: AppRoutes.clubLogin);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityStoreOverride()],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.auth,
    );
  });

  test('sessionRoleHome', () {
    expect(sessionRoleHome(CrewRole.rower), AppRoutes.homeRower);
    expect(sessionRoleHome(CrewRole.cox), AppRoutes.homeCox);
    expect(sessionRoleHome(CrewRole.coach), AppRoutes.homeCoach);
  });
}
