import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/deck_theme.dart';
import 'controller.dart';
import 'models.dart';

/// DR-FR-A — Ateliers brevet FFA + relais 4×500 (Lot 2).
class FunnelAteliersScreen extends ConsumerWidget {
  const FunnelAteliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                onTap: () {
                  ref.read(funnelProvider.notifier).setActivePiece(
                        piece: piece,
                        dragFactor: ref.read(funnelProvider).profile?.dragFactor,
                      );
                  context.go(
                    '${AppRoutes.funnelPreview}?piece=${piece.id}',
                  );
                },
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
}

class _AtelierCard extends StatelessWidget {
  const _AtelierCard({required this.piece, required this.onTap});

  final ErgPiece piece;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            border: Border.all(color: DeckColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                piece.label,
                style: const TextStyle(
                  fontFamily: DeckType.ui,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: DeckColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                piece.cues.isEmpty ? '' : piece.cues.first,
                style: const TextStyle(
                  fontFamily: DeckType.ui,
                  fontSize: 14,
                  color: DeckColors.label,
                ),
              ),
              if (piece.kpiHint.isNotEmpty) ...[
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
    );
  }
}
