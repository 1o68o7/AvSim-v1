import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../identity/controller.dart';
import '../router.dart';
import '../theme/deck_theme.dart';
import 'lot5_controller.dart';
import 'lot5_models.dart';

/// Dispos du jour — matin / midi / soir · eau / erg / les deux.
class FunnelDisposScreen extends ConsumerWidget {
  const FunnelDisposScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rower = ref.watch(identityProvider).activeRower;
    final lot5 = ref.watch(lot5Provider);
    final today = lot5.dispos
        .where((d) => d.day == localDayKey() && d.rowerId == (rower?.id ?? ''))
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
          'Mes dispos',
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
                'Créneaux du jour — expire ce soir',
                style: DeckType.uiLabel(color: DeckColors.label),
              ),
              const SizedBox(height: 16),
              if (rower == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Aucun rameur actif — créneaux en lecture seule.',
                    style: DeckType.uiLabel(color: DeckColors.muted),
                  ),
                ),
              for (final slot in DispoSlot.values) ...[
                _SlotCard(
                  slot: slot,
                  current: () {
                    for (final d in today) {
                      if (d.slot == slot) return d.mode;
                    }
                    return null;
                  }(),
                  onPick: rower == null
                      ? null
                      : (mode) {
                          ref.read(lot5Provider.notifier).setDispo(
                                rowerId: rower.id,
                                slot: slot,
                                mode: mode,
                              );
                        },
                ),
                const SizedBox(height: 10),
              ],
              const Spacer(),
              Text(
                'La composition se filtre d’abord dans ton groupe de club.',
                style: DeckType.uiLabel(size: 12, color: DeckColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.current,
    this.onPick,
  });

  final DispoSlot slot;
  final DispoMode? current;
  final ValueChanged<DispoMode>? onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('funnel-dispo-${slot.wire}'),
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
            slot.label,
            style: const TextStyle(
              fontFamily: DeckType.ui,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: DeckColors.text,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final mode in DispoMode.values)
                ChoiceChip(
                  label: Text(mode.label),
                  selected: current == mode,
                  onSelected: onPick == null ? null : (_) => onPick!(mode),
                  selectedColor: DeckColors.volt.withValues(alpha: 0.25),
                  labelStyle: TextStyle(
                    fontFamily: DeckType.ui,
                    color: current == mode ? DeckColors.volt : DeckColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: DeckColors.surfaceHighest,
                  side: BorderSide(
                    color: current == mode ? DeckColors.volt : DeckColors.hairline,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
