import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import 'replay_load.dart';

class RowerReplayScreen extends StatelessWidget {
  const RowerReplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ReplayLoadScreen(
      title: 'REPLAY RAMEUR',
      onBack: () => context.go(AppRoutes.quai),
      showEval: false,
      allowImport: true,
    );
  }
}
