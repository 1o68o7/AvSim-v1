import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

/// Live rameur. Overlay GPS + roll = lot B. Alerte écran 4 = bandeau [DeckColors.alert].
class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeckScaffold(
      title: 'LIVE 1X',
      subtitle: 'sol — pas eau · cadence nullable',
      landscapeHint: true,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cadence  —',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const Text(
              'Pas de SOG 10 Hz. Pastille GPS au lot B.',
              style: TextStyle(color: DeckColors.label),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.quai),
              child: const Text('STOP → QUAI (placeholder lot A)'),
            ),
          ],
        ),
      ),
    );
  }
}
