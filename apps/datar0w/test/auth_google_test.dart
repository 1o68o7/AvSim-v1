import 'package:datar0w/onboarding/routing.dart';
import 'package:datar0w/sync/auth_google.dart';
import 'package:datar0w/sync/auth_screen.dart';
import 'package:datar0w/sync/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'identity_test_helpers.dart';

class _FakeBackend implements AuthBackend {
  String? userId;
  int googleCalls = 0;
  int magicCalls = 0;
  String? lastEmail;
  Uri? lastRecover;

  String? lastRedirect;

  @override
  Future<bool> startGoogle({required String redirectTo}) async {
    googleCalls++;
    lastRedirect = redirectTo;
    expect(redirectTo, startsWith(SyncConfig.redirect));
    userId ??= 'user-google';
    return true;
  }

  @override
  Future<void> startMagicLink({
    required String email,
    required String redirectTo,
  }) async {
    magicCalls++;
    lastEmail = email;
    lastRedirect = redirectTo;
    expect(redirectTo, startsWith(SyncConfig.redirect));
  }

  @override
  Future<bool> recoverSession(Uri uri) async {
    lastRecover = uri;
    userId ??= 'user-link';
    return userId != null;
  }

  @override
  String? currentUserId() => userId;
}

void main() {
  test('signInWithGoogle pose une session (mock)', () async {
    final fake = _FakeBackend();
    final auth = AuthGoogle(backend: fake);
    expect(await auth.signInWithGoogle(), isTrue);
    expect(auth.lastMethod, 'google');
    expect(auth.sessionUserId, 'user-google');
    expect(fake.googleCalls, 1);
    expect(fake.lastRedirect, redirectToFor(OnboardingDoor.rower));
  });

  test('fallback magic link déclenché', () async {
    final fake = _FakeBackend();
    final auth = AuthGoogle(backend: fake);
    expect(await auth.signInWithMagicLink('ada@example.com'), isTrue);
    expect(auth.lastMethod, 'magic');
    expect(fake.magicCalls, 1);
    expect(fake.lastEmail, 'ada@example.com');
  });

  test('deep link unifié datarow://auth/callback', () async {
    final fake = _FakeBackend();
    final auth = AuthGoogle(backend: fake);
    final uri = Uri.parse('datarow://auth/callback?code=pkce');
    expect(isAuthCallback(uri), isTrue);
    expect(await auth.handleDeepLink(uri), isTrue);
    expect(auth.sessionUserId, 'user-link');
    expect(auth.lastDoor, OnboardingDoor.rower);

    final clubUri = Uri.parse('datarow://auth/callback?code=pkce&door=club');
    expect(await auth.handleDeepLink(clubUri), isTrue);
    expect(auth.lastDoor, OnboardingDoor.club);
    expect(
      await auth.handleDeepLink(Uri.parse('https://evil.example/callback')),
      isFalse,
    );
  });

  testWidgets('/auth : Google + par email', (tester) async {
    final fake = _FakeBackend();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityStoreOverride(),
          authGoogleProvider.overrideWithValue(AuthGoogle(backend: fake)),
        ],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('CONTINUER AVEC GOOGLE'), findsOneWidget);
    expect(find.text('par email'), findsOneWidget);
    expect(find.text('ENVOYER LE LIEN'), findsNothing);
    await tester.tap(find.text('par email'));
    await tester.pump();
    expect(find.text('ENVOYER LE LIEN'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ada@example.com');
    await tester.tap(find.text('ENVOYER LE LIEN'));
    await tester.pump();
    // Sans dart-define : pas d’appel réseau, message local.
    expect(SyncConfig.enabled, isFalse);
    expect(find.textContaining('Pas de clés cloud'), findsWidgets);
  });
}
