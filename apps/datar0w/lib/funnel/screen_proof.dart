import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/deck_theme.dart';
import 'controller.dart';
import 'models.dart';

/// DR-FR-6 — Preuve (temps, split, cadence, watts, DF).
class FunnelProofScreen extends ConsumerWidget {
  const FunnelProofScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final funnel = ref.watch(funnelProvider);
    final log = funnel.lastResult;
    final target = funnel.profile?.targetSplit500s;
    final distLabel = log == null
        ? '—'
        : (ErgDistance.fromMeters(log.distM)?.label ?? '${log.distM} m');
    final timeLabel = log == null ? '—' : formatErgTime(log.durationS);
    final splitLabel = log == null ? '—' : formatErgTime(log.split500S);
    final vsTarget = (log == null || target == null)
        ? null
        : log.split500S - target;
    final onTarget = vsTarget != null && vsTarget <= 0;

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
                      'PB $distLabel',
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
              _Kpi(label: 'Split moy.', value: '$splitLabel /500 m'),
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
                  'Partiel gardé — pas un PB.',
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
