import 'package:datar0w/onboarding/routing.dart';
import 'package:datar0w/router.dart';
import 'package:datar0w/sync/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'identity_test_helpers.dart';

void main() {
  test('chemin Google + club → /home/coach', () {
    expect(
      resolvePostLogin(
        door: OnboardingDoor.club,
        clubMemberRole: 'coach',
      ),
      AppRoutes.homeCoach,
    );
    expect(
      resolvePostLogin(
        door: OnboardingDoor.club,
        clubMemberRole: 'admin',
      ),
      AppRoutes.homeCoach,
    );
  });

  test('chemin Google + rameur → profil / accueil rameur', () {
    expect(
      resolvePostLogin(
        door: OnboardingDoor.rower,
        clubMemberRole: null,
        hasRowerProfile: false,
      ),
      AppRoutes.rowerOnboard,
    );
    expect(
      resolvePostLogin(
        door: OnboardingDoor.rower,
        clubMemberRole: 'rower',
        hasRowerProfile: true,
      ),
      AppRoutes.homeRower,
    );
  });

  test('chemin sans compte → /', () {
    expect(
      resolvePostLogin(
        door: OnboardingDoor.rower,
        skipAccount: true,
      ),
      AppRoutes.profile,
    );
  });

  testWidgets('/club/login distinct de /auth', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.clubLogin,
      routes: [
        GoRoute(
          path: AppRoutes.clubLogin,
          builder: (_, __) => const AuthScreen(clubDoor: true),
        ),
        GoRoute(
          path: AppRoutes.auth,
          builder: (_, __) => const AuthScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityStoreOverride()],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    expect(find.text('ESPACE CLUB'), findsOneWidget);
    expect(find.text('Sans compte (loisir)'), findsNothing);
    expect(find.text('CONTINUER AVEC GOOGLE'), findsOneWidget);
  });
}
