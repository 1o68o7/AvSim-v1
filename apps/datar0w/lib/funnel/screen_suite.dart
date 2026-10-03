import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/deck_theme.dart';
import 'controller.dart';
import 'models.dart';

/// Suite — même pièce, 500 m, ou ateliers Lot 2.
class FunnelSuiteScreen extends ConsumerWidget {
  const FunnelSuiteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(funnelProvider).lastResult;
    final piece = ErgPiece.byId(log?.pieceId);
    final was2000 = log?.distM == ErgDistance.m2000.meters;
    final sameDist = log?.distM ?? ErgDistance.m500.meters;
    final sameLabel = piece?.label ??
        ErgDistance.fromMeters(sameDist)?.label ??
        '$sameDist m';

    return Scaffold(
      backgroundColor: DeckColors.bg,
      appBar: AppBar(
        backgroundColor: DeckColors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Suite',
          style: TextStyle(
            fontFamily: DeckType.ui,
            fontWeight: FontWeight.w600,
            color: DeckColors.text,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Prochain morceau',
                style: TextStyle(
                  fontFamily: DeckType.ui,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: DeckColors.text,
                ),
              ),
              const SizedBox(height: 16),
              _Choice(
                title: 'Même distance dans 3 jours',
                subtitle: sameLabel,
                onTap: () {
                  if (piece != null) {
                    ref.read(funnelProvider.notifier).bookNext(piece: piece);
                  } else {
                    ref
                        .read(funnelProvider.notifier)
                        .bookNext(distM: sameDist);
                  }
                  context.go(AppRoutes.homeRower);
                },
              ),
              if (was2000) ...[
                const SizedBox(height: 10),
                _Choice(
                  title: '500 m',
                  subtitle: 'Sprint, plus court',
                  onTap: () {
                    ref.read(funnelProvider.notifier).bookNext(
                          distM: ErgDistance.m500.meters,
                        );
                    context.go(AppRoutes.homeRower);
                  },
                ),
              ],
              const SizedBox(height: 10),
              _Choice(
                title: 'Ateliers brevet',
                subtitle: '5 min · 3×1 min · 1 000 m · relais 4×500',
                onTap: () => context.go(AppRoutes.funnelAteliers),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go(AppRoutes.homeRower),
                child: const Text(
                  'Plus tard',
                  style: TextStyle(color: DeckColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
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
                title,
                style: const TextStyle(
                  fontFamily: DeckType.ui,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: DeckColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: DeckType.ui,
                  fontSize: 13,
                  color: DeckColors.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
