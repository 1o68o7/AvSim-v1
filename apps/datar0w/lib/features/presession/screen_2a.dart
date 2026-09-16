import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

class PresessionScreen extends StatelessWidget {
  const PresessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeckScaffold(
      title: 'DATAROW / 2A',
      subtitle: 'Pré-session · 1x verrouillé',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'CONFIGURATION SÉANCE',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Classe 1x · GPS / IMU · BLE — aucun',
              style: TextStyle(color: DeckColors.label),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => context.go(AppRoutes.tare),
              child: const Text('CONTINUER — TARE GÎTE'),
            ),
          ],
        ),
      ),
    );
  }
}
