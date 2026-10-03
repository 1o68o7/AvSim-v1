import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/deck_theme.dart';
import 'lot5_controller.dart';
import 'lot5_models.dart';

/// Coach — fermer / rouvrir le plan d’eau (veto).
class FunnelWaterVetoScreen extends ConsumerStatefulWidget {
  const FunnelWaterVetoScreen({super.key});

  @override
  ConsumerState<FunnelWaterVetoScreen> createState() =>
      _FunnelWaterVetoScreenState();
}

class _FunnelWaterVetoScreenState extends ConsumerState<FunnelWaterVetoScreen> {
  WaterVetoReason _reason = WaterVetoReason.vent;

  @override
  Widget build(BuildContext context) {
    final lot5 = ref.watch(lot5Provider);
    final waterId = lot5.plan?.waterId ?? 'club-water';
    final active = lot5.closures
        .where((c) => c.waterId == waterId && c.activeAt(DateTime.now().toUtc()))
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
          'Plan d’eau',
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
                lot5.plan?.waterLabel ?? 'Plan d’eau club',
                style: const TextStyle(
                  fontFamily: DeckType.ui,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: DeckColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Le veto ferme le bassin pour une plage, pas un rameur.',
                style: DeckType.uiLabel(color: DeckColors.label),
              ),
              const SizedBox(height: 20),
              if (active.isNotEmpty) ...[
                for (final c in active)
                  Container(
                    key: Key('funnel-veto-active-${c.id}'),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DeckColors.surface,
                      borderRadius: DeckRadii.cardAll,
                      border: Border.all(color: DeckColors.babord),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.reasonLine,
                          style: const TextStyle(
                            fontFamily: DeckType.ui,
                            fontWeight: FontWeight.w600,
                            color: DeckColors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () =>
                              ref.read(lot5Provider.notifier).liftVeto(c.id),
                          child: const Text(
                            'Lever le veto',
                            style: TextStyle(color: DeckColors.volt),
                          ),
                        ),
                      ],
                    ),
                  ),
              ] else ...[
                Text(
                  'Motif',
                  style: DeckType.uiLabel(color: DeckColors.label),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in WaterVetoReason.values)
                      ChoiceChip(
                        label: Text(r.label),
                        selected: _reason == r,
                        onSelected: (_) => setState(() => _reason = r),
                        selectedColor: DeckColors.volt.withValues(alpha: 0.25),
                        labelStyle: TextStyle(
                          fontFamily: DeckType.ui,
                          color:
                              _reason == r ? DeckColors.volt : DeckColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: DeckColors.surfaceHighest,
                        side: BorderSide(
                          color: _reason == r
                              ? DeckColors.volt
                              : DeckColors.hairline,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const Key('funnel-veto-close'),
                    onPressed: () async {
                      await ref.read(lot5Provider.notifier).closeWater(
                            waterId: waterId,
                            reason: _reason,
                          );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Plan d’eau fermé')),
                      );
                    },
                    child: const Text('Plan d’eau fermé'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
