import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

class QuaiScreen extends StatelessWidget {
  const QuaiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeckScaffold(
      title: 'QUAI',
      subtitle: 'fin de séance',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Durée · distance GPS · cadence moy. · gîte RMS',
              style: TextStyle(color: DeckColors.label),
            ),
            const SizedBox(height: 12),
            const Text(
              'en attente réseau',
              style: TextStyle(color: DeckColors.amber),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => context.go(AppRoutes.rowerReplay),
              child: const Text('REPLAY RAMEUR'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.profile),
              child: const Text('RETOUR ACCUEIL'),
            ),
          ],
        ),
      ),
    );
  }
}
