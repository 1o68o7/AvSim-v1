import 'package:go_router/go_router.dart';

import 'features/coach/screen_5.dart';
import 'features/coach/screen_join.dart';
import 'features/cox/screen_cox.dart';
import 'features/identity/screen_boat_edit.dart';
import 'features/identity/screen_club.dart';
import 'features/identity/screen_crew.dart';
import 'features/identity/screen_home_roles.dart';
import 'features/identity/screen_home_rower.dart';
import 'features/identity/screen_import.dart';
import 'features/identity/screen_rower_edit.dart';
import 'features/identity/screen_spinoscope.dart';
import 'features/identity/screen_who.dart';
import 'features/ops/screen_departure.dart';
import 'features/ops/screen_impact.dart';
import 'features/ops/screen_in.dart';
import 'features/ops/screen_out.dart';
import 'features/live/screen_3.dart';
import 'features/presession/screen_2a.dart';
import 'features/profile/screen_1.dart';
import 'features/quai/screen_7.dart';
import 'features/replay/screen_6.dart';
import 'features/replay/screen_6r.dart';
import 'features/tare/screen_2b.dart';
import 'session/boat_class.dart';
import 'sync/auth_screen.dart';

abstract final class AppRoutes {
  static const identity = '/identity';
  static const identityEdit = '/identity/edit';
  static const homeRower = '/home/rower';
  static const homeCox = '/home/cox';
  static const homeCoach = '/home/coach';
  static const club = '/club';
  static const clubBoat = '/club/boat';
  static const clubImport = '/club/import';
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
  static const quai = '/quai';
  static const auth = '/auth';

  /// Après tare : barreur → `/cox`, rameur → `/live`. Écrans distincts.
  static String afterTare(CrewRole role) =>
      role == CrewRole.cox ? cox : live;
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.identity,
  routes: [
    GoRoute(
      path: AppRoutes.identity,
      name: '0-identity',
      builder: (context, state) => const IdentityListScreen(),
    ),
    GoRoute(
      path: AppRoutes.identityEdit,
      name: '0-identity-edit',
      builder: (context, state) => RowerEditScreen(
        rowerId: state.uri.queryParameters['id'],
      ),
    ),
    GoRoute(
      path: AppRoutes.homeRower,
      name: 'home-rower',
      builder: (context, state) => const HomeRowerScreen(),
    ),
    GoRoute(
      path: AppRoutes.homeCox,
      name: 'home-cox',
      builder: (context, state) => const HomeCoxScreen(),
    ),
    GoRoute(
      path: AppRoutes.homeCoach,
      name: 'home-coach',
      builder: (context, state) => const HomeCoachScreen(),
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
      builder: (context, state) => const ClubImportScreen(),
    ),
    GoRoute(
      path: AppRoutes.spinoscope,
      name: 'spinoscope',
      builder: (context, state) => const SpinoscopeScreen(),
    ),
    GoRoute(
      path: AppRoutes.crew,
      name: 'crew',
      builder: (context, state) => const CrewScreen(),
    ),
    GoRoute(
      path: AppRoutes.opsOut,
      name: 'ops-out',
      builder: (context, state) => const OpsOutScreen(),
    ),
    GoRoute(
      path: AppRoutes.opsIn,
      name: 'ops-in',
      builder: (context, state) => const OpsInScreen(),
    ),
    GoRoute(
      path: AppRoutes.opsDeparture,
      name: 'ops-departure',
      builder: (context, state) => const OpsDepartureScreen(),
    ),
    GoRoute(
      path: AppRoutes.opsMaintenance,
      name: 'ops-maintenance',
      builder: (context, state) => const MaintenanceQueueScreen(),
    ),
    GoRoute(
      path: AppRoutes.profile,
      name: '1-profils',
      builder: (context, state) => const ProfileScreen(),
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
      builder: (context, state) => const CoachReplayScreen(),
    ),
    GoRoute(
      path: AppRoutes.rowerReplay,
      name: '6r-replay-rameur',
      builder: (context, state) => const RowerReplayScreen(),
    ),
    GoRoute(
      path: AppRoutes.quai,
      name: '7-quai',
      builder: (context, state) => const QuaiScreen(),
    ),
    GoRoute(
      path: AppRoutes.auth,
      name: 'auth',
      builder: (context, state) => const AuthScreen(),
    ),
  ],
);
