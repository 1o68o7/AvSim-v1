import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../calendar/loisir_store.dart';
import '../../identity/controller.dart';
import '../../router.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

class PhysioScreen extends ConsumerWidget {
  const PhysioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rower = ref.watch(identityProvider).activeRower;
    return DeckScaffold(
      title: 'MES CONSTANTES',
      subtitle: 'informatif · pas médical',
      leading: TextButton(
        onPressed: () => context.go(AppRoutes.homeRower),
        child: const Text('Retour'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const Text(
            'READINESS',
            style: TextStyle(
              color: DeckColors.label,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '—',
            style: TextStyle(fontSize: 48, fontWeight: FontWeight.w700),
          ),
          const Text(
            'Pas assez de séances avec FC pour un score.',
            style: TextStyle(color: DeckColors.muted),
          ),
          const SizedBox(height: 24),
          const Text(
            'DERNIÈRE SÉANCE',
            style: TextStyle(
              color: DeckColors.label,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          const Text(
            'Courbe FC + cadence + V sol : voir replay après STOP.',
            style: TextStyle(color: DeckColors.muted, height: 1.4),
          ),
          const SizedBox(height: 24),
          const Text(
            'PARCOURS',
            style: TextStyle(
              color: DeckColors.label,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          FutureBuilder(
            future: LoisirStore().list(),
            builder: (context, snap) {
              final mine = (snap.data ?? const [])
                  .where((p) => rower == null || p.rowerId == rower.id)
                  .toList();
              if (mine.isEmpty) {
                return const Text(
                  'Aucune régate / rando / master signalé.',
                  style: TextStyle(color: DeckColors.muted),
                );
              }
              return Column(
                children: [
                  for (final p in mine)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.type),
                      subtitle: Text(p.tempsCourse ?? p.eventId),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
