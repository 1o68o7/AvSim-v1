import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/calendar/screen_calendar.dart';
import 'features/calendar/screen_event.dart';
import 'features/calendar/screen_waters.dart';
import 'features/health/screen_consent.dart';
import 'features/coach/screen_5.dart';
import 'features/coach/screen_join.dart';
import 'features/cox/screen_cox.dart';
import 'features/identity/screen_boat_edit.dart';
import 'features/identity/screen_club.dart';
import 'features/identity/screen_crew.dart';
import 'features/identity/screen_devices.dart';
import 'features/identity/screen_physio.dart';
import 'features/identity/screen_home_roles.dart';
import 'features/identity/screen_home_rower.dart';
import 'features/identity/screen_import.dart';
import 'features/identity/screen_plus.dart';
import 'features/identity/screen_rower_edit.dart';
import 'features/identity/screen_club_sessions.dart';
import 'features/identity/screen_settings.dart';
import 'features/identity/screen_spinoscope.dart';
import 'features/identity/screen_who.dart';
import 'features/ops/screen_departure.dart';
import 'features/ops/screen_impact.dart';
import 'features/ops/screen_in.dart';
import 'features/ops/screen_out.dart';
import 'features/live/screen_3.dart';
import 'features/presession/screen_2a.dart';
import 'features/quai/screen_7.dart';
import 'features/replay/screen_6.dart';
import 'features/replay/screen_6r.dart';
import 'features/replay/screen_sessions.dart';
import 'features/tare/screen_2b.dart';
import 'identity/controller.dart';
import 'identity/models.dart';
import 'onboarding/routing.dart';
import 'onboarding/screen_club_discover.dart';
import 'onboarding/screen_club_home.dart';
import 'onboarding/screen_club_join.dart';
import 'onboarding/screen_rower.dart';
import 'session/boat_class.dart';
import 'sync/auth_callback_screen.dart';
import 'sync/auth_google.dart';
import 'sync/auth_screen.dart';
import 'widgets/safe_route.dart';

/// Guard écriture club : rameur/cox → `/home/rower` + SnackBar.
String? _staffToolsRedirect(BuildContext context, GoRouterState state) {
  if (!isClubStaffToolsPath(state.uri.path)) return null;
  try {
    final snap = ProviderScope.containerOf(context).read(identityProvider);
    final denied = clubStaffToolsRedirect(snap);
    if (denied != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          const SnackBar(content: Text('Réservé au club')),
        );
      });
    }
    return denied;
  } catch (_) {
    return AppRoutes.homeRower;
  }
}

/// try/catch builder → Page introuvable (pas de lock orientation ici :
/// le lock portrait hub de #72 cassait le paysage live/cox).
Widget _hub(String dest, Widget child) => SafeRoute(
      dest: dest,
      builder: (_) => child,
    );

abstract final class AppRoutes {
  /// Porte club froide (cold start).
  static const discover = '/discover';
  static const identity = '/identity';
  static const identityEdit = '/identity/edit';
  static const rowerOnboard = '/onboarding/rower';
  static const homeRower = '/home/rower';
  static const homeCox = '/home/cox';
  static const homeCoach = '/home/coach';
  static const homeIntendant = '/home/intendant';
  static const homeDirector = '/home/director';
  static const homeTreasurer = '/home/treasurer';
  static const homeAdmin = '/home/admin';
  static const club = '/club';
  static const clubBoat = '/club/boat';
  static const clubImport = '/club/import';
  static const clubSessions = '/club/sessions';
  static const spinoscope = '/spinoscope';
  static const crew = '/crew';
  static const opsOut = '/ops/out';
  static const opsIn = '/ops/in';
  static const opsDeparture = '/ops/departure';
  static const opsMaintenance = '/ops/maintenance';
  static const profile = '/';
  static const presession = '/presession';
  static const tare = '/tare';
  static const live = '/live';
  static const cox = '/cox';
  static const coachJoin = '/coach-join';
  static const coachLive = '/coach';
  static const coachReplay = '/replay-coach';
  static const rowerReplay = '/replay';
  static const sessions = '/sessions';
  static const plus = '/plus';
  static const quai = '/quai';
  static const auth = '/auth';
  static const authCallback = '/auth/callback';
  static const clubLogin = '/club/login';
  static const clubJoin = '/club/join';
  static const settings = '/settings';
  static const calendar = '/calendar';
  static const waters = '/waters';
  static const consent = '/consent';
  static const devices = '/devices';
  static const physio = '/physio';

  /// Après tare : barreur → `/cox`, rameur → `/live`. Écrans distincts.
  static String afterTare(CrewRole role) =>
      role == CrewRole.cox ? cox : live;
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.discover,
  errorBuilder: (context, state) {
    final uri = state.uri;
    if (isAuthCallback(uri) ||
        uri.path == AppRoutes.authCallback ||
        uri.path.endsWith('/auth/callback')) {
      return AuthCallbackScreen(uri: uri);
    }
    // Throw builder / route inconnue : visible, pas de snap-back /identity.
    return PageIntrouvableScreen(
      dest: uri.toString(),
      error: state.error,
    );
  },
  routes: [
    GoRoute(
      path: AppRoutes.discover,
      name: '0-discover',
      builder: (context, state) =>
          _hub(AppRoutes.discover, const ClubDiscoverScreen()),
    ),
    GoRoute(
      path: AppRoutes.identity,
      name: '0-identity',
      builder: (context, state) =>
          _hub(AppRoutes.identity, const IdentityListScreen()),
    ),
    GoRoute(
      path: AppRoutes.identityEdit,
      name: '0-identity-edit',
      builder: (context, state) => _hub(
            AppRoutes.identityEdit,
            RowerEditScreen(
              rowerId: state.uri.queryParameters['id'],
            ),
          ),
    ),
    GoRoute(
      path: AppRoutes.rowerOnboard,
      name: 'onboarding-rower',
      builder: (context, state) =>
          _hub(AppRoutes.rowerOnboard, const RowerOnboardingScreen()),
    ),
    GoRoute(
      path: AppRoutes.homeRower,
      name: 'home-rower',
      builder: (context, state) =>
          _hub(AppRoutes.homeRower, const HomeRowerScreen()),
    ),
    GoRoute(
      path: AppRoutes.homeCox,
      name: 'home-cox',
      builder: (context, state) =>
          _hub(AppRoutes.homeCox, const HomeCoxScreen()),
    ),
    GoRoute(
      path: AppRoutes.homeCoach,
      name: 'home-coach',
      builder: (context, state) =>
          _hub(AppRoutes.homeCoach, const HomeCoachScreen()),
    ),
    GoRoute(
      path: AppRoutes.homeIntendant,
      name: 'home-intendant',
      builder: (context, state) => _hub(
            AppRoutes.homeIntendant,
            const ClubRoleHomeScreen(role: ClubMemberRole.intendant),
          ),
    ),
    GoRoute(
      path: AppRoutes.homeDirector,
      name: 'home-director',
      builder: (context, state) => _hub(
            AppRoutes.homeDirector,
            const ClubRoleHomeScreen(role: ClubMemberRole.director),
          ),
    ),
    GoRoute(
      path: AppRoutes.homeTreasurer,
      name: 'home-treasurer',
      builder: (context, state) => _hub(
            AppRoutes.homeTreasurer,
            const ClubRoleHomeScreen(role: ClubMemberRole.treasurer),
          ),
    ),
    GoRoute(
      path: AppRoutes.homeAdmin,
      name: 'home-admin',
      builder: (context, state) => _hub(
            AppRoutes.homeAdmin,
            const ClubRoleHomeScreen(role: ClubMemberRole.admin),
          ),
    ),
    GoRoute(
      path: AppRoutes.club,
      name: 'club',
      builder: (context, state) => const ClubScreen(),
    ),
    GoRoute(
      path: AppRoutes.clubBoat,
      name: 'club-boat',
      builder: (context, state) => BoatEditScreen(
        boatId: state.uri.queryParameters['id'],
      ),
    ),
    GoRoute(
      path: AppRoutes.clubImport,
      name: 'club-import',
      redirect: _staffToolsRedirect,
      builder: (context, state) => const ClubImportScreen(),
    ),
    GoRoute(
      path: AppRoutes.clubSessions,
      name: 'club-sessions',
      redirect: _staffToolsRedirect,
      builder: (context, state) =>
          _hub(AppRoutes.clubSessions, const ClubSessionsScreen()),
    ),
    GoRoute(
      path: '${AppRoutes.clubSessions}/:code',
      name: 'club-session-detail',
      redirect: _staffToolsRedirect,
      builder: (context, state) => _hub(
            '${AppRoutes.clubSessions}/:code',
            ClubSessionDetailScreen(
              code: state.pathParameters['code'] ?? '',
            ),
          ),
    ),
    GoRoute(
      path: AppRoutes.spinoscope,
      name: 'spinoscope',
      builder: (context, state) => const SpinoscopeScreen(),
    ),
    GoRoute(
      path: AppRoutes.crew,
      name: 'crew',
      redirect: _staffToolsRedirect,
      builder: (context, state) => const CrewScreen(),
    ),
    GoRoute(
      path: AppRoutes.opsOut,
      name: 'ops-out',
      redirect: _staffToolsRedirect,
      builder: (context, state) => const OpsOutScreen(),
    ),
    GoRoute(
      path: AppRoutes.opsIn,
      name: 'ops-in',
      redirect: _staffToolsRedirect,
      builder: (context, state) => const OpsInScreen(),
    ),
    GoRoute(
      path: AppRoutes.opsDeparture,
      name: 'ops-departure',
      redirect: _staffToolsRedirect,
      builder: (context, state) => const OpsDepartureScreen(),
    ),
    GoRoute(
      path: AppRoutes.opsMaintenance,
      name: 'ops-maintenance',
      redirect: _staffToolsRedirect,
      builder: (context, state) => const MaintenanceQueueScreen(),
    ),
    // `/` n’est plus ProfileScreen — redirect métier ou porte club.
    GoRoute(
      path: AppRoutes.profile,
      name: '1-root-redirect',
      redirect: (context, state) {
        try {
          final snap =
              ProviderScope.containerOf(context).read(identityProvider);
          return resolveRootRedirect(snap);
        } catch (_) {
          return AppRoutes.discover;
        }
      },
    ),
    GoRoute(
      path: AppRoutes.presession,
      name: '2a-presession',
      builder: (context, state) => const PresessionScreen(),
    ),
    GoRoute(
      path: AppRoutes.tare,
      name: '2b-tare',
      builder: (context, state) => const TareScreen(),
    ),
    GoRoute(
      path: AppRoutes.live,
      name: '3-live',
      builder: (context, state) => const LiveScreen(),
    ),
    GoRoute(
      path: AppRoutes.cox,
      name: '3-cox',
      builder: (context, state) => const CoxLiveScreen(),
    ),
    GoRoute(
      path: AppRoutes.coachJoin,
      name: 'coach-join',
      builder: (context, state) => const CoachJoinScreen(),
    ),
    GoRoute(
      path: AppRoutes.coachLive,
      name: '5-coach-live',
      builder: (context, state) => const CoachLiveScreen(),
    ),
    GoRoute(
      path: AppRoutes.coachReplay,
      name: '6-coach-replay',
      builder: (context, state) => CoachReplayScreen(
        sessionId: state.uri.queryParameters['id'],
      ),
    ),
    GoRoute(
      path: AppRoutes.rowerReplay,
      name: '6r-replay-rameur',
      builder: (context, state) => RowerReplayScreen(
        sessionId: state.uri.queryParameters['id'],
      ),
    ),
    GoRoute(
      path: AppRoutes.sessions,
      name: 'sessions',
      builder: (context, state) => SessionHistoryScreen(
        fromCoach: state.uri.queryParameters['from'] == 'coach',
        roleFilter: state.uri.queryParameters['role'],
        codeFilter: state.uri.queryParameters['code'],
      ),
    ),
    GoRoute(
      path: '${AppRoutes.sessions}/:id',
      redirect: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return '${AppRoutes.rowerReplay}?id=${Uri.encodeQueryComponent(id)}';
      },
    ),
    GoRoute(
      path: AppRoutes.plus,
      name: 'plus',
      builder: (context, state) =>
          _hub(AppRoutes.plus, const PlusScreen()),
    ),
    GoRoute(
      path: AppRoutes.quai,
      name: '7-quai',
      builder: (context, state) => const QuaiScreen(),
    ),
    GoRoute(
      path: AppRoutes.auth,
      name: 'auth',
      builder: (context, state) =>
          _hub(AppRoutes.auth, const AuthScreen()),
    ),
    GoRoute(
      path: AppRoutes.authCallback,
      name: 'auth-callback',
      builder: (context, state) => AuthCallbackScreen(uri: state.uri),
    ),
    GoRoute(
      path: AppRoutes.settings,
      name: 'settings',
      builder: (context, state) =>
          _hub(AppRoutes.settings, const SettingsScreen()),
    ),
    GoRoute(
      path: AppRoutes.clubLogin,
      name: 'club-login',
      redirect: (context, state) => AppRoutes.auth,
    ),
    GoRoute(
      path: AppRoutes.clubJoin,
      name: 'club-join',
      builder: (context, state) => const ClubJoinScreen(),
    ),
    GoRoute(
      path: AppRoutes.calendar,
      name: 'calendar',
      builder: (context, state) => const CalendarScreen(),
    ),
    GoRoute(
      path: '/calendar/:id',
      name: 'calendar-event',
      builder: (context, state) => EventSheetScreen(
        eventId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: AppRoutes.waters,
      name: 'waters',
      builder: (context, state) => const WatersScreen(),
    ),
    GoRoute(
      path: AppRoutes.consent,
      name: 'consent',
      builder: (context, state) => const ConsentScreen(),
    ),
    GoRoute(
      path: AppRoutes.devices,
      name: 'devices',
      builder: (context, state) => const DevicesScreen(),
    ),
    GoRoute(
      path: AppRoutes.physio,
      name: 'physio',
      builder: (context, state) => const PhysioScreen(),
    ),
  ],
);
