import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import 'replay_load.dart';

/// DR-56 — Replay flotte coach (Stitch).
class CoachReplayScreen extends StatelessWidget {
  const CoachReplayScreen({super.key, this.sessionId});

  final String? sessionId;

  @override
  Widget build(BuildContext context) {
    final id = sessionId?.trim();
    final hasId = id != null && id.isNotEmpty;
    return ReplayLoadScreen(
      title: 'Replay flotte',
      sessionId: hasId ? id : null,
      onBack: () => context.go(
        hasId ? '${AppRoutes.sessions}?from=coach' : AppRoutes.role,
      ),
      showEval: true,
      allowImport: true,
    );
  }
}
