import 'package:datar0w/features/profile/screen_1.dart';
import 'package:datar0w/funnel/lot5_models.dart';
import 'package:datar0w/funnel/models.dart';
import 'package:datar0w/identity/controller.dart';
import 'package:datar0w/identity/models.dart';
import 'package:datar0w/identity/store.dart';
import 'package:datar0w/router.dart';
import 'package:datar0w/session/boat_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'identity_test_helpers.dart';

void main() {
  test('AppRoutes.role picker vs profile root redirect', () {
    expect(AppRoutes.role, '/role');
    expect(AppRoutes.profile, '/');
    expect(AppRoutes.funnelDistances, '/funnel/distances');
  });

  test('canCheckoutOps by clubRole alone (session rower ok)', () {
    const snap = IdentitySnapshot(
      prefs: IdentityPrefs(clubRole: ClubMemberRole.coach),
    );
    expect(canCheckoutOps(snap, CrewRole.rower), isTrue);
  });

  test('canComposeCrew true for admin', () {
    const snap = IdentitySnapshot(
      prefs: IdentityPrefs(clubRole: ClubMemberRole.admin),
    );
    expect(canComposeCrew(snap), isTrue);
  });

  test('ergReplacement / distances smoke', () {
    expect(ErgDistance.m5000.meters, 5000);
    final piece = ergReplacementForWater(
      waterDistM: 5000,
      frame: PracticeFrame.competition,
    );
    expect(piece.logDistM, 5000);
  });

  testWidgets('GoRoute /role montre ProfileScreen', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.role,
      routes: [
        GoRoute(
          path: AppRoutes.role,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: AppRoutes.homeRower,
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: AppRoutes.homeCoach,
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: AppRoutes.homeCox,
          builder: (context, state) => const SizedBox.shrink(),
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

    expect(
      find.text('Rôle bateau').evaluate().isNotEmpty ||
          find.text('RAMEUR').evaluate().isNotEmpty,
      isTrue,
    );
  });
}
