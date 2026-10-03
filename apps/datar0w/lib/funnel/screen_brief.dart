import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/deck_theme.dart';
import 'controller.dart';
import 'models.dart';

/// Brief pré-play — cale-pieds, damper→DF, écran /500.
class FunnelBriefScreen extends ConsumerWidget {
  const FunnelBriefScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final funnel = ref.watch(funnelProvider);
    final piece = funnel.resolvedPiece;
    final df = funnel.activeDragFactor ?? funnel.profile?.dragFactor ?? 115;
    final label = piece.label;

    final items = [
      ('Cale-pieds', 'Réglés, sangles fermées.'),
      ('Damper → DF', 'Viser DF $df. Le cran seul ne suffit pas.'),
      (
        piece.kind == ErgPieceKind.duration ||
                piece.kind == ErgPieceKind.intervals
            ? 'Écran cadence'
            : 'Écran /500 m',
        piece.kind == ErgPieceKind.duration ||
                piece.kind == ErgPieceKind.intervals
            ? 'Cadence cible visible. Split en secondaire.'
            : 'Affiche le split, la cadence et les watts.',
      ),
    ];

    return Scaffold(
      backgroundColor: DeckColors.bg,
      appBar: AppBar(
        backgroundColor: DeckColors.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DeckColors.text),
          onPressed: () => context.go(AppRoutes.funnelPreview),
        ),
        title: Text(
          'Brief · $label',
          style: const TextStyle(
            fontFamily: DeckType.ui,
            fontWeight: FontWeight.w600,
            color: DeckColors.text,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: DeckColors.surface,
                    borderRadius: DeckRadii.cardAll,
                    border: Border.all(color: DeckColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${i + 1}. ${items[i].$1}',
                        style: const TextStyle(
                          fontFamily: DeckType.ui,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: DeckColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].$2,
                        style: const TextStyle(
                          fontFamily: DeckType.ui,
                          fontSize: 14,
                          color: DeckColors.label,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              const Spacer(),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () => context.go(AppRoutes.funnelPlayer),
                  child: const Text('C’est parti'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
