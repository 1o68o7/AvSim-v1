import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

/// Tare 30 s + offset = lot C. Ici navigation + axe BÂBORD | TRIBORD.
class TareScreen extends StatelessWidget {
  const TareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeckScaffold(
      title: 'DATAROW / 2B',
      subtitle: 'Tare gîte — lot C',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Bateau à quai, coque calée. Ne pas bouger.',
              style: TextStyle(color: DeckColors.label),
            ),
            const SizedBox(height: 24),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('BÂBORD', style: TextStyle(color: Color(0xFFE05353))),
                Text('TRIBORD', style: TextStyle(color: Color(0xFF46C275))),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '0.0°',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.w700),
            ),
            const Text(
              'référentiel rameur',
              style: TextStyle(color: DeckColors.label, fontSize: 11),
            ),
            const Spacer(),
            const Text(
              'STATUT : non faite (tare 30 s au lot C)',
              style: TextStyle(color: DeckColors.label),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go(AppRoutes.live),
              child: const Text('DÉMARRER LA SESSION (DEV LOT B)'),
            ),
          ],
        ),
      ),
    );
  }
}
