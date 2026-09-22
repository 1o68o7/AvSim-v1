import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import 'replay_load.dart';

class RowerReplayScreen extends StatelessWidget {
  const RowerReplayScreen({super.key, this.sessionId});

  final String? sessionId;

  @override
  Widget build(BuildContext context) {
    final id = sessionId?.trim();
    final hasId = id != null && id.isNotEmpty;
    return ReplayLoadScreen(
      title: 'REPLAY RAMEUR',
      sessionId: hasId ? id : null,
      onBack: () => context.go(hasId ? AppRoutes.sessions : AppRoutes.quai),
      showEval: false,
      allowImport: true,
    );
  }
}
