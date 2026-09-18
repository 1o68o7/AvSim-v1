import 'package:go_router/go_router.dart';

import 'features/coach/screen_5.dart';
import 'features/coach/screen_join.dart';
import 'features/cox/screen_cox.dart';
import 'features/live/screen_3.dart';
import 'features/presession/screen_2a.dart';
import 'features/profile/screen_1.dart';
import 'features/quai/screen_7.dart';
import 'features/replay/screen_6.dart';
import 'features/replay/screen_6r.dart';
import 'features/tare/screen_2b.dart';
import 'session/boat_class.dart';

abstract final class AppRoutes {
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
  /// Après tare : barreur → `/cox`, rameur → `/live`. Écrans distincts.
  static String afterTare(CrewRole role) =>
      role == CrewRole.cox ? cox : live;
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.profile,
  routes: [
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
  ],
);
