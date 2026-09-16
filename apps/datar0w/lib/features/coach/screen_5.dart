import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

class CoachLiveScreen extends StatelessWidget {
  const CoachLiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeckScaffold(
      title: 'COACH LIVE',
      subtitle: 'réf. rameur · carte lot E/F',
      landscapeHint: true,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Join code = lot F. Carte OSM = lots E/F.',
              style: TextStyle(color: DeckColors.label),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.coachReplay),
              child: const Text('REPLAY COACH (6)'),
            ),
            const SizedBox(height: 8),
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
