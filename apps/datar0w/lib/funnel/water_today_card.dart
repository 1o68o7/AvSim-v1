import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../identity/controller.dart';
import '../identity/models.dart';
import '../router.dart';
import '../theme/deck_theme.dart';
import 'lot5_controller.dart';
import 'lot5_gates.dart';
import 'lot5_models.dart';
import 'models.dart';

/// Carte du jour eau — deux portes + bascule indoor.
class WaterTodayCard extends ConsumerWidget {
  const WaterTodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lot5 = ref.watch(lot5Provider);
    final plan = lot5.plan;
    final gate = lot5.gate;
    if (plan == null || gate == null) return const SizedBox.shrink();

    final id = ref.watch(identityProvider);
    final boat = id.boatById(plan.boatId);
    final distLabel =
        ErgDistance.fromMeters(plan.distM)?.label ?? '${plan.distM} m';

    return Container(
      key: const Key('funnel-water-today'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: DeckRadii.cardAll,
        border: Border.all(
          color: gate.boatAllowed ? DeckColors.volt : DeckColors.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            plan.headline,
            style: const TextStyle(
              fontFamily: DeckType.ui,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: DeckColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            plan.waterLabel,
            style: DeckType.uiLabel(color: DeckColors.label),
          ),
          const SizedBox(height: 12),
          ..._statusLines(gate, plan, boat),
          const SizedBox(height: 14),
          ..._actions(context, ref, gate, plan, distLabel),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => context.go(AppRoutes.funnelDispos),
                child: const Text(
                  'Mes dispos',
                  style: TextStyle(color: DeckColors.muted, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => context.go(AppRoutes.funnelWaterVeto),
                child: const Text(
                  'Veto coach',
                  style: TextStyle(color: DeckColors.muted, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _statusLines(
    WaterGateResult gate,
    WaterOutingPlan plan,
    ParkBoat? boat,
  ) {
    switch (gate.kind) {
      case WaterGateKind.open:
        return [
          Text(
            '${gate.crewConfirmed}/${gate.crewNeeded} confirmés',
            style: DeckType.labelMono(size: 12, color: DeckColors.volt),
          ),
          Text(
            'Plan d’eau ouvert',
            style: DeckType.labelMono(size: 12, color: DeckColors.volt),
          ),
        ];
      case WaterGateKind.crewBroken:
        final missing = (gate.crewNeeded - gate.crewConfirmed).clamp(0, 99);
        return [
          Text(
            missing == 1
                ? 'Il manque 1 siège'
                : 'Il manque $missing sièges',
            style: const TextStyle(
              fontFamily: DeckType.ui,
              fontWeight: FontWeight.w600,
              color: DeckColors.text,
            ),
          ),
          Text(
            '${gate.crewConfirmed}/${gate.crewNeeded} confirmés',
            style: DeckType.labelMono(size: 12),
          ),
          if (gate.canDownsize)
            Text(
              'Descendre en bateau plus court possible',
              style: DeckType.uiLabel(size: 12, color: DeckColors.muted),
            ),
        ];
      case WaterGateKind.waterClosed:
        return [
          Text(
            gate.waterReason ?? 'Plan d’eau fermé',
            style: const TextStyle(
              fontFamily: DeckType.ui,
              fontWeight: FontWeight.w600,
              color: DeckColors.text,
            ),
          ),
          Text(
            indoorCancelLabel(gate.kind),
            style: DeckType.labelMono(size: 12),
          ),
        ];
      case WaterGateKind.rowerChoseErg:
        return [
          Text(
            indoorCancelLabel(gate.kind),
            style: const TextStyle(
              fontFamily: DeckType.ui,
              fontWeight: FontWeight.w600,
              color: DeckColors.text,
            ),
          ),
        ];
    }
  }

  List<Widget> _actions(
    BuildContext context,
    WidgetRef ref,
    WaterGateResult gate,
    WaterOutingPlan plan,
    String distLabel,
  ) {
    Future<void> goErg({bool confirmChoice = false}) async {
      if (confirmChoice) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: DeckColors.surface,
            title: const Text(
              'Passer sur l’erg ?',
              style: TextStyle(color: DeckColors.text),
            ),
            content: const Text(
              'Ton siège sera libéré pour la composition. L’équipage est prévenu.',
              style: TextStyle(color: DeckColors.label),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirmer'),
              ),
            ],
          ),
        );
        if (ok != true) return;
      }
      final piece = await ref.read(lot5Provider.notifier).switchToErg();
      if (!context.mounted) return;
      context.go('${AppRoutes.funnelPreview}?piece=${piece.id}');
    }

    switch (gate.kind) {
      case WaterGateKind.open:
        return [
          SizedBox(
            height: 48,
            child: FilledButton(
              key: const Key('funnel-water-je-sors'),
              onPressed: () => context.go(AppRoutes.presession),
              child: const Text('Je sors'),
            ),
          ),
          TextButton(
            key: const Key('funnel-water-passer-erg'),
            onPressed: () => goErg(confirmChoice: true),
            child: const Text(
              'Passer sur l’erg',
              style: TextStyle(color: DeckColors.muted),
            ),
          ),
        ];
      case WaterGateKind.crewBroken:
        return [
          SizedBox(
            height: 48,
            child: FilledButton(
              key: const Key('funnel-water-erg-crew'),
              onPressed: () => goErg(),
              child: Text('Faire le $distLabel sur l’erg'),
            ),
          ),
          if (gate.canDownsize)
            TextButton(
              onPressed: () => context.go(AppRoutes.crew),
              child: const Text(
                'Descendre en bateau plus court',
                style: TextStyle(color: DeckColors.muted),
              ),
            ),
          TextButton(
            onPressed: () => context.go(AppRoutes.crew),
            child: const Text(
              'Relancer',
              style: TextStyle(color: DeckColors.muted),
            ),
          ),
        ];
      case WaterGateKind.waterClosed:
        return [
          SizedBox(
            height: 48,
            child: FilledButton(
              key: const Key('funnel-water-erg-closed'),
              onPressed: () => goErg(),
              child: Text('Faire le $distLabel sur l’erg'),
            ),
          ),
        ];
      case WaterGateKind.rowerChoseErg:
        return [
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: () => goErg(),
              child: Text('Continuer le $distLabel sur l’erg'),
            ),
          ),
        ];
    }
  }
}
