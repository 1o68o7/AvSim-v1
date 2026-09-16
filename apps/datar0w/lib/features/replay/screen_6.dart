import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import 'replay_load.dart';

class CoachReplayScreen extends StatelessWidget {
  const CoachReplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ReplayLoadScreen(
      title: 'COACH REPLAY',
      onBack: () => context.go(AppRoutes.profile),
    );
  }
}
