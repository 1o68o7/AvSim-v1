import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/deck_theme.dart';
import 'controller.dart';
import 'models.dart';

/// DR-FR-A — Ateliers brevet FFA, relais, endurance / brevets km.
class FunnelAteliersScreen extends ConsumerWidget {
  const FunnelAteliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(funnelProvider).logs;

    return Scaffold(
      backgroundColor: DeckColors.bg,
      appBar: AppBar(
        backgroundColor: DeckColors.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DeckColors.text),
          onPressed: () => context.go(AppRoutes.homeRower),
        ),
        title: const Text(
          'Ateliers brevet',
          style: TextStyle(
            fontFamily: DeckType.ui,
            fontWeight: FontWeight.w600,
            color: DeckColors.text,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text(
              'Formats FFA indoor — pas une bibliothèque libre',
              style: DeckType.uiLabel(color: DeckColors.label),
            ),
            const SizedBox(height: 16),
            for (final piece in ErgPiece.lot2Catalog) ...[
              _AtelierCard(
                piece: piece,
                unlocked: true,
                onTap: () => _open(ref, context, piece),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 20),
            Text(
              'Endurance & brevets km',
              style: const TextStyle(
                fontFamily: DeckType.ui,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: DeckColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '5 000 · 6 000 · 10 · 21 · 42 km',
              style: DeckType.uiLabel(size: 12, color: DeckColors.muted),
            ),
            const SizedBox(height: 12),
            for (final piece in ErgPiece.lot4Catalog) ...[
              _AtelierCard(
                key: Key('funnel-lot4-${piece.id}'),
                piece: piece,
                unlocked: isLot4Unlocked(piece, logs),
                lockHint: lot4UnlockHint(piece),
                onTap: isLot4Unlocked(piece, logs)
                    ? () => _open(ref, context, piece)
                    : null,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            Text(
              'Le 500 m pace boat cadence 24 est dans le Plan.',
              style: DeckType.uiLabel(size: 12, color: DeckColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _open(WidgetRef ref, BuildContext context, ErgPiece piece) {
    ref.read(funnelProvider.notifier).setActivePiece(
          piece: piece,
          dragFactor: ref.read(funnelProvider).profile?.dragFactor,
        );
    context.go('${AppRoutes.funnelPreview}?piece=${piece.id}');
  }
}

class _AtelierCard extends StatelessWidget {
  const _AtelierCard({
    super.key,
    required this.piece,
    required this.unlocked,
    this.lockHint = '',
    this.onTap,
  });

  final ErgPiece piece;
  final bool unlocked;
  final String lockHint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = !unlocked;
    return Material(
      color: DeckColors.surface,
      borderRadius: DeckRadii.cardAll,
      child: InkWell(
        borderRadius: DeckRadii.cardAll,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: DeckRadii.cardAll,
            border: Border.all(
              color: muted ? DeckColors.hairline : DeckColors.hairline,
            ),
          ),
          child: Opacity(
            opacity: muted ? 0.55 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        piece.label,
                        style: const TextStyle(
                          fontFamily: DeckType.ui,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: DeckColors.text,
                        ),
                      ),
                    ),
                    if (muted)
                      Text(
                        'Verrouillé',
                        style: DeckType.labelMono(
                          size: 11,
                          color: DeckColors.muted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  muted && lockHint.isNotEmpty
                      ? lockHint
                      : (piece.cues.isEmpty ? '' : piece.cues.first),
                  style: const TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 14,
                    color: DeckColors.label,
                  ),
                ),
                if (piece.kpiHint.isNotEmpty && unlocked) ...[
                  const SizedBox(height: 8),
                  Text(
                    piece.kpiHint,
                    style: DeckType.labelMono(size: 11),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
