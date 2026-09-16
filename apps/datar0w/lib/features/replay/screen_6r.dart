import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

class RowerReplayScreen extends StatelessWidget {
  const RowerReplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeckScaffold(
      title: 'REPLAY RAMEUR',
      subtitle: 'carte + V + distance au curseur',
      landscapeHint: true,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Même fichier que le coach, sans colonne évaluation.',
              style: TextStyle(color: DeckColors.label),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.go(AppRoutes.quai),
              child: const Text('Retour quai'),
            ),
          ],
        ),
      ),
    );
  }
}
