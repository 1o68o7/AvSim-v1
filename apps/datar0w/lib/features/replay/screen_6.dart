import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

class CoachReplayScreen extends StatelessWidget {
  const CoachReplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeckScaffold(
      title: 'COACH REPLAY',
      subtitle: '2 courbes : cadence · V sol',
      landscapeHint: true,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Source unique : sessions/{id}/samples.jsonl (lot B).',
              style: TextStyle(color: DeckColors.label),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.go(AppRoutes.profile),
              child: const Text('Retour profils'),
            ),
          ],
        ),
      ),
    );
  }
}
