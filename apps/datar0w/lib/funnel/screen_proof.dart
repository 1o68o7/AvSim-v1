import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/deck_theme.dart';
import 'controller.dart';
import 'models.dart';

/// DR-FR-6 — Preuve (temps, split, cadence, watts, DF + ateliers Lot 2).
class FunnelProofScreen extends ConsumerWidget {
  const FunnelProofScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final funnel = ref.watch(funnelProvider);
    final log = funnel.lastResult;
    final piece = ErgPiece.byId(log?.pieceId) ?? funnel.resolvedPiece;
    final target = funnel.profile?.targetSplit500s;
    final distLabel = piece.label;
    final timeLabel = log == null ? '—' : formatErgTime(log.durationS);
    final splitLabel = log == null ? '—' : formatErgTime(log.split500S);
    final vsTarget = (log == null ||
            target == null ||
            piece.kind != ErgPieceKind.distance ||
            piece.announcedMinM != null)
        ? null
        : log.split500S - target;
    final onTarget = vsTarget != null && vsTarget <= 0;
    final announcedOk = log?.realizedDistM != null &&
        piece.announcedMinM != null &&
        announced1000InBand(log!.realizedDistM!);

    return Scaffold(
      backgroundColor: DeckColors.bg,
      appBar: AppBar(
        backgroundColor: DeckColors.bg,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Text(
          'Preuve',
          style: TextStyle(
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
              Text(
                distLabel,
                style: DeckType.uiLabel(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                timeLabel,
                key: const Key('funnel-proof-time'),
                style: DeckType.metric(size: 56, weight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              if (funnel.lastWasPb && log?.complete == true) ...[
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: DeckColors.volt,
                      borderRadius: DeckRadii.chipAll,
                    ),
                    child: Text(
                      'PB ${ErgDistance.fromMeters(log!.distM)?.label ?? piece.label}',
                      style: const TextStyle(
                        fontFamily: DeckType.ui,
                        fontWeight: FontWeight.w700,
                        color: DeckColors.onVolt,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
              if (piece.kind == ErgPieceKind.duration &&
                  log?.complete == true) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Créneau tenu',
                    style: DeckType.uiLabel(
                      color: DeckColors.tribord,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (announcedOk) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Bande 990–1 010 m · ${log!.realizedDistM} m',
                    style: DeckType.uiLabel(
                      color: DeckColors.tribord,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (vsTarget != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: onTarget
                          ? DeckColors.tribordWash
                          : DeckColors.babordWash,
                      borderRadius: DeckRadii.chipAll,
                      border: Border.all(
                        color:
                            onTarget ? DeckColors.tribord : DeckColors.babord,
                      ),
                    ),
                    child: Text(
                      onTarget
                          ? 'Sous la cible · ${formatErgTime(-vsTarget)}'
                          : 'Au-dessus · +${formatErgTime(vsTarget)}',
                      style: TextStyle(
                        fontFamily: DeckType.ui,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            onTarget ? DeckColors.tribord : DeckColors.babord,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (piece.kind == ErgPieceKind.distance ||
                  piece.kind == ErgPieceKind.relay)
                _Kpi(label: 'Split moy.', value: '$splitLabel /500 m'),
              if (log?.blockCadences.isNotEmpty == true)
                _Kpi(
                  label: 'Cadences',
                  value: log!.blockCadences.join(' / '),
                )
              else
                _Kpi(
                  label: 'Cadence',
                  value: log?.cadence == null
                      ? '—'
                      : '${log!.cadence!.round()} spm',
                ),
              _Kpi(
                label: 'Watts',
                value: log?.watts == null ? '—' : '${log!.watts!.round()} W',
              ),
              _Kpi(
                label: 'Drag factor',
                value: log?.dragFactor?.toString() ?? '—',
              ),
              if (log?.complete != true) ...[
                const SizedBox(height: 12),
                Text(
                  piece.kind == ErgPieceKind.duration
                      ? 'Partiel gardé.'
                      : 'Partiel gardé — pas un PB.',
                  style: DeckType.uiLabel(color: DeckColors.amber),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () => context.go(AppRoutes.funnelSuite),
                  child: const Text('Poser la suivante'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go(AppRoutes.homeRower),
                child: const Text(
                  'Retour home',
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

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: DeckType.uiLabel())),
          Text(
            value,
            style: DeckType.metric(size: 18, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
