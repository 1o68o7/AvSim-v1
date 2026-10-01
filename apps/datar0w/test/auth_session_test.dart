import 'dart:async';

import 'package:datar0w/identity/controller.dart';
import 'package:datar0w/identity/models.dart';
import 'package:datar0w/identity/store.dart';
import 'package:datar0w/onboarding/routing.dart';
import 'package:datar0w/router.dart';
import 'package:datar0w/sync/auth_callback_screen.dart';
import 'package:datar0w/sync/auth_google.dart';
import 'package:datar0w/sync/auth_links.dart';
import 'package:datar0w/sync/auth_session.dart';
import 'package:datar0w/sync/club_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'identity_test_helpers.dart';

class _FakeBackend implements AuthBackend {
  String? userId = 'user-link';

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

class _MemLinks implements AuthLinkSource {
  _MemLinks({this.seed});

  final Uri? seed;
  final controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> initialLink() async => seed;

  @override
  Stream<Uri> get links => controller.stream;
}

GoRouter _router(String initial) => GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: AppRoutes.auth,
          builder: (_, _) => const Text('AUTH'),
        ),
        GoRoute(
          path: AppRoutes.clubLogin,
          builder: (_, _) => const Text('CLUB-LOGIN'),
        ),
        GoRoute(
          path: AppRoutes.rowerOnboard,
          builder: (_, _) => const Text('ONBOARD'),
        ),
        GoRoute(
          path: AppRoutes.clubJoin,
          builder: (_, _) => const Text('CLUB-JOIN'),
        ),
        GoRoute(
          path: AppRoutes.homeRower,
          builder: (_, _) => const Text('HOME-ROWER'),
        ),
        GoRoute(
          path: AppRoutes.homeAdmin,
          builder: (_, _) => const Text('HOME-ADMIN'),
        ),
        GoRoute(
          path: AppRoutes.live,
          builder: (_, _) => const Text('LIVE'),
        ),
        GoRoute(
          path: AppRoutes.identity,
          builder: (_, _) => const Text('IDENTITY'),
        ),
      ],
    );

Future<void> _pump({
  required WidgetTester tester,
  required GoRouter router,
  required AuthGoogle auth,
  required AuthLinkSource links,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        identityStoreOverride(),
        clubRemoteOverride(MemoryClubRemote()),
        authGoogleProvider.overrideWithValue(auth),
        authLinkSourceProvider.overrideWithValue(links),
      ],
      child: AuthSessionBinder(
        router: router,
        child: MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// FakeAsync ne complète pas l’I/O IdentityStore — il faut [runAsync].
Future<void> _emitAuthLink(WidgetTester tester, _MemLinks links, Uri uri) async {
  await tester.runAsync(() async {
    links.controller.add(uri);
    // hydrateFromCloud + ensureActiveClub (disque) puis go().
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pumpAndSettle();
}

void main() {
  test('destinationAfterAuth avec rôle rameur par défaut', () {
    const empty = IdentitySnapshot();
    expect(empty.prefs.clubRole, ClubMemberRole.rower);
    expect(
      destinationAfterAuth(
        door: OnboardingDoor.rower,
        snap: empty,
        sessionUserId: 'u1',
      ),
      AppRoutes.rowerOnboard,
    );
    // Porte club anonyme : plus de /club/join — même branche rameur.
    expect(
      destinationAfterAuth(
        door: OnboardingDoor.club,
        snap: empty,
        sessionUserId: 'u1',
      ),
      AppRoutes.rowerOnboard,
    );
  });

  test('destinationAfterAuth staff seulement si club actif', () {
    const snap = IdentitySnapshot(
      prefs: IdentityPrefs(
        activeClubId: 'c1',
        clubRole: ClubMemberRole.admin,
      ),
    );
    expect(
      destinationAfterAuth(
        door: OnboardingDoor.rower,
        snap: snap,
        sessionUserId: 'u1',
      ),
      AppRoutes.homeAdmin,
    );
  });

  test('canRedirectAfterAuth protège live/cox/coach + identity sans deep link',
      () {
    expect(canRedirectAfterAuth(AppRoutes.auth), isTrue);
    expect(canRedirectAfterAuth(AppRoutes.identity), isFalse);
    expect(
      canRedirectAfterAuth(AppRoutes.identity, fromDeepLink: true),
      isTrue,
    );
    expect(canRedirectAfterAuth(AppRoutes.live), isFalse);
    expect(canRedirectAfterAuth(AppRoutes.cox), isFalse);
    expect(canRedirectAfterAuth(AppRoutes.coachLive), isFalse);
  });

  testWidgets('callback depuis /auth → onboarding rameur', (tester) async {
    final router = _router(AppRoutes.auth);
    final links = _MemLinks();
    await _pump(
      tester: tester,
      router: router,
      auth: AuthGoogle(backend: _FakeBackend()),
      links: links,
    );
    expect(find.text('AUTH'), findsOneWidget);
    await _emitAuthLink(
      tester,
      links,
      Uri.parse('datarow://auth/callback?code=pkce&door=rower'),
    );
    expect(find.text('ONBOARD'), findsOneWidget);
    addTearDown(links.controller.close);
  });

  testWidgets('callback door=club sans staff → onboard rameur', (tester) async {
    final router = _router(AppRoutes.auth);
    final links = _MemLinks();
    await _pump(
      tester: tester,
      router: router,
      auth: AuthGoogle(backend: _FakeBackend()),
      links: links,
    );
    await _emitAuthLink(
      tester,
      links,
      Uri.parse('datarow://auth/callback?code=pkce&door=club'),
    );
    expect(find.text('ONBOARD'), findsOneWidget);
    expect(find.text('CLUB-JOIN'), findsNothing);
    addTearDown(links.controller.close);
  });

  testWidgets('callback n’arrache pas /live', (tester) async {
    final router = _router(AppRoutes.live);
    final links = _MemLinks();
    await _pump(
      tester: tester,
      router: router,
      auth: AuthGoogle(backend: _FakeBackend()),
      links: links,
    );
    await _emitAuthLink(
      tester,
      links,
      Uri.parse('datarow://auth/callback?code=pkce'),
    );
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('ONBOARD'), findsNothing);
    addTearDown(links.controller.close);
  });

  testWidgets('cold start callback depuis /identity → post-login',
      (tester) async {
    final router = _router(AppRoutes.identity);
    final links = _MemLinks(
      seed: Uri.parse('datarow://auth/callback?code=pkce&door=rower'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityStoreOverride(),
          clubRemoteOverride(MemoryClubRemote()),
          authGoogleProvider.overrideWithValue(
            AuthGoogle(backend: _FakeBackend()),
          ),
          authLinkSourceProvider.overrideWithValue(links),
        ],
        child: AuthSessionBinder(
          router: router,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    // 1er frame → post-frame _consumeInitial ; I/O dans runAsync.
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pumpAndSettle();
    expect(find.text('ONBOARD'), findsOneWidget);
    addTearDown(links.controller.close);
  });

  testWidgets('error= depuis deep link → /auth/callback, pas /identity',
      (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.identity,
      routes: [
        GoRoute(
          path: AppRoutes.identity,
          builder: (_, _) => const Text('IDENTITY'),
        ),
        GoRoute(
          path: AppRoutes.authCallback,
          builder: (context, state) => AuthCallbackScreen(uri: state.uri),
        ),
        GoRoute(
          path: AppRoutes.auth,
          builder: (_, _) => const Text('AUTH'),
        ),
      ],
    );
    final links = _MemLinks();
    await _pump(
      tester: tester,
      router: router,
      auth: AuthGoogle(backend: _FakeBackend()),
      links: links,
    );
    expect(find.text('IDENTITY'), findsOneWidget);
    // error= → go sync, pas d’hydrate.
    links.controller.add(
      Uri.parse(
        'datarow://auth/callback?error=access_denied&error_description=denied',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Google refusée'), findsOneWidget);
    expect(find.text('IDENTITY'), findsNothing);
    addTearDown(links.controller.close);
  });
}

