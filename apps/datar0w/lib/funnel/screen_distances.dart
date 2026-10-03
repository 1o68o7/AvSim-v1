import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/deck_theme.dart';
import 'controller.dart';
import 'models.dart';

/// Distances FFA indoor — PB locales + entrée preview.
class FunnelDistancesScreen extends ConsumerWidget {
  const FunnelDistancesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(funnelProvider).logs;
    final distances = ErgDistance.values;
    final lot4Extra = ErgPiece.lot4Catalog
        .where(
          (p) => !distances.any((d) => d.meters == p.logDistM),
        )
        .toList();

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
          'Distances FFA',
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
              'Erg · records locaux sur ce téléphone',
              style: DeckType.uiLabel(color: DeckColors.label),
            ),
            const SizedBox(height: 16),
            for (final dist in distances) ...[
              _DistanceTile(
                label: dist.label,
                pbS: personalBestSeconds(logs, dist.meters),
                unlocked: isLot4Unlocked(
                  ErgPiece.fromDistanceMeters(dist.meters),
                  logs,
                ),
                lockHint: lot4UnlockHint(
                  ErgPiece.fromDistanceMeters(dist.meters),
                ),
                onTap: () => _open(ref, context, dist.meters),
              ),
              const SizedBox(height: 10),
            ],
            if (lot4Extra.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Brevets km',
                style: const TextStyle(
                  fontFamily: DeckType.ui,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DeckColors.text,
                ),
              ),
              const SizedBox(height: 12),
              for (final piece in lot4Extra) ...[
                _DistanceTile(
                  label: piece.label,
                  pbS: personalBestSeconds(logs, piece.logDistM),
                  unlocked: isLot4Unlocked(piece, logs),
                  lockHint: lot4UnlockHint(piece),
                  onTap: isLot4Unlocked(piece, logs)
                      ? () => _openPiece(ref, context, piece)
                      : null,
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _open(WidgetRef ref, BuildContext context, int meters) {
    final piece = ErgPiece.fromDistanceMeters(meters);
    final unlocked = isLot4Unlocked(piece, ref.read(funnelProvider).logs);
    if (!unlocked) return;
    _openPiece(ref, context, piece);
  }

  void _openPiece(WidgetRef ref, BuildContext context, ErgPiece piece) {
    ref.read(funnelProvider.notifier).setActivePiece(
          piece: piece,
          dragFactor: ref.read(funnelProvider).profile?.dragFactor,
        );
    context.go('${AppRoutes.funnelPreview}?piece=${piece.id}');
  }
}

class _DistanceTile extends StatelessWidget {
  const _DistanceTile({
    required this.label,
    required this.pbS,
    required this.unlocked,
    this.lockHint = '',
    this.onTap,
  });

  final String label;
  final double? pbS;
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
        onTap: unlocked ? onTap : null,
        borderRadius: DeckRadii.cardAll,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: DeckRadii.cardAll,
            border: Border.all(color: DeckColors.hairline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: DeckType.ui,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: muted ? DeckColors.muted : DeckColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      muted
                          ? (lockHint.isEmpty ? 'Verrouillé' : lockHint)
                          : (pbS == null
                              ? 'Pas de PB'
                              : 'PB · ${formatErgTime(pbS!)}'),
                      style: DeckType.labelMono(
                        size: 11,
                        color: DeckColors.label,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                muted ? Icons.lock_outline : Icons.chevron_right,
                color: DeckColors.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
