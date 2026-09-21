import 'package:flutter/material.dart';

import '../theme/deck_theme.dart';

/// Bandeau mode compétition — téléphone interdit en bateau (FFA / World Rowing).
class CompetitionBanner extends StatelessWidget {
  const CompetitionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: DeckColors.amber),
      ),
      child: const Text(
        'MODE COMPÉTITION — tel au quai. Patch autonome + log flash. '
        'Pas de 4G en course. Sync après amarrage.',
        style: TextStyle(color: DeckColors.amber, fontSize: 12, height: 1.35),
      ),
    );
  }
}
