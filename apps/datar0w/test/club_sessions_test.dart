import 'package:datar0w/features/identity/screen_club_sessions.dart';
import 'package:datar0w/identity/controller.dart';
import 'package:datar0w/identity/models.dart';
import 'package:datar0w/identity/store.dart';
import 'package:datar0w/onboarding/routing.dart';
import 'package:datar0w/router.dart';
import 'package:datar0w/sync/club_sessions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'identity_test_helpers.dart';

class _StaffIdentity extends IdentityController {
  @override
  IdentitySnapshot build() => IdentitySnapshot(
        prefs: IdentityPrefs(
          activeClubId: 'club-1',
          clubRole: ClubMemberRole.admin,
        ),
      );
}

class _RowerIdentity extends IdentityController {
  @override
  IdentitySnapshot build() => IdentitySnapshot(
        prefs: IdentityPrefs(
          activeClubId: 'club-1',
          clubRole: ClubMemberRole.rower,
        ),
      );
}

void main() {
  test('isClubStaffRole', () {
    expect(isClubStaffRole('admin'), isTrue);
    expect(isClubStaffRole('coach'), isTrue);
    expect(isClubStaffRole('rower'), isFalse);
    expect(isClubStaffRole('cox'), isFalse);
  });

  test('ClubSessionMeta sizeLabel + cadence null', () {
    const m = ClubSessionMeta(
      syncId: 's',
      code: 'QEPSSL',
      clubId: 'c1',
      byteSize: 53000,
    );
    expect(m.sizeLabel, '52 Ko');
    expect(m.cadenceSpm, isNull);
  });

  testWidgets('ST-05 liste vide', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityStoreOverride(),
          identityProvider.overrideWith(_StaffIdentity.new),
          clubSessionRemoteProvider.overrideWithValue(
            MemoryClubSessionRemote(),
          ),
        ],
        child: const MaterialApp(home: ClubSessionsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SÉANCES DU CLUB'), findsOneWidget);
    expect(
      find.textContaining('Aucune séance cloud'),
      findsOneWidget,
    );
  });

  testWidgets('ST-05 liste + tap → fiche ST-06', (tester) async {
    final remote = MemoryClubSessionRemote([
      ClubSessionMeta(
        syncId: 's1',
        code: 'QEPSSL',
        clubId: 'club-1',
        byteSize: 54321,
        syncedAt: DateTime.utc(2026, 9, 30, 12),
      ),
    ]);
    final router = GoRouter(
      initialLocation: AppRoutes.clubSessions,
      routes: [
        GoRoute(
          path: AppRoutes.clubSessions,
          builder: (_, _) => const ClubSessionsScreen(),
        ),
        GoRoute(
          path: '${AppRoutes.clubSessions}/:code',
          builder: (c, s) =>
              ClubSessionDetailScreen(code: s.pathParameters['code']!),
        ),
        GoRoute(
          path: AppRoutes.homeAdmin,
          builder: (_, _) => const Text('ADMIN'),
        ),
        GoRoute(
          path: AppRoutes.homeRower,
          builder: (_, _) => const Text('ROWER'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityStoreOverride(),
          identityProvider.overrideWith(_StaffIdentity.new),
          clubSessionRemoteProvider.overrideWithValue(remote),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('QEPSSL'), findsOneWidget);
    expect(find.text('CLOUD'), findsOneWidget);
    await tester.tap(find.text('QEPSSL'));
    await tester.pumpAndSettle();
    expect(find.textContaining('cadence non mesurée'), findsOneWidget);
    expect(find.text('QEPSSL'), findsWidgets);
  });

  testWidgets('rameur → redirect hors /club/sessions', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.clubSessions,
      routes: [
        GoRoute(
          path: AppRoutes.clubSessions,
          builder: (_, _) => const ClubSessionsScreen(),
        ),
        GoRoute(
          path: AppRoutes.homeRower,
          builder: (_, _) => const Text('HOME-ROWER'),
        ),
        GoRoute(
          path: AppRoutes.homeAdmin,
          builder: (_, _) => const Text('ADMIN'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityStoreOverride(),
          identityProvider.overrideWith(_RowerIdentity.new),
          clubSessionRemoteProvider.overrideWithValue(
            MemoryClubSessionRemote(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('HOME-ROWER'), findsOneWidget);
  });
}
