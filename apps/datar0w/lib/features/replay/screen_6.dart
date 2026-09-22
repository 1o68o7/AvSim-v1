import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import 'replay_load.dart';

class CoachReplayScreen extends StatelessWidget {
  const CoachReplayScreen({super.key, this.sessionId});

  final String? sessionId;

  @override
  Widget build(BuildContext context) {
    final id = sessionId?.trim();
    final hasId = id != null && id.isNotEmpty;
    return ReplayLoadScreen(
      title: 'COACH REPLAY',
      sessionId: hasId ? id : null,
      onBack: () => context.go(
        hasId ? '${AppRoutes.sessions}?from=coach' : AppRoutes.profile,
      ),
      showEval: true,
      allowImport: true,
    );
  }
}
