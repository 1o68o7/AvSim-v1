import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../identity/format.dart';
import '../../ops/alignment.dart';
import '../../ops/boat_out.dart';
import '../../ops/controller.dart';
import '../../ops/service.dart';
import '../../router.dart';
import '../../session/boat_config.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

class OpsDepartureScreen extends ConsumerWidget {
  const OpsDepartureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(boatConfigProvider).role;
    final ident = ref.watch(identityProvider);
    final ops = ref.watch(opsProvider);
    if (role != CrewRole.coach || !canCheckoutOps(ident, role)) {
      return const DeckScaffold(
        title: 'DÉPART',
        body: Center(
          child: Text(
            'Réservé au coach.',
            style: TextStyle(color: DeckColors.muted),
          ),
        ),
      );
    }

    final rows = sortDeparture([
      for (final o in ops.activeOuts)
        if (ident.boatById(o.boatId) != null)
          DepartureRow(
            out: o,
            boat: ident.boatById(o.boatId)!,
            crew: ident.assignmentsForBoat(o.boatId),
            oarLabel: ops.oarSetById(o.oarSetId)?.label ?? '—',
          ),
    ]);

    return DeckScaffold(
      title: 'DÉPART',
      subtitle: 'Alignement · 8+ d’abord',
      leading: TextButton(
        onPressed: () => context.go(AppRoutes.homeCoach),
        child: const Text('Retour'),
      ),
      body: rows.isEmpty
          ? const Center(
              child: Text(
                'Aucune coque sortie.',
                style: TextStyle(color: DeckColors.muted),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final r = rows[i];
                final until = formatPlannedEnd(r.out.plannedEnd);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: DeckColors.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${i + 1}. ${r.boat.name}  ${r.boat.classe}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          r.out.status.wire +
                              (until.isEmpty ? '' : ' · prévu $until'),
                          style: const TextStyle(
                            color: DeckColors.amber,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Pelles : ${r.oarLabel}',
                          style: const TextStyle(
                            color: DeckColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final a in r.crew)
                          Text(
                            a.role == 'cox'
                                ? 'Barreur · ${ident.rowerById(a.rowerId)?.displayName ?? a.rowerId}'
                                : '${assignmentChip(a)} · ${ident.rowerById(a.rowerId)?.displayName ?? a.rowerId}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (r.out.status.wire == 'reserved') ...[
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => ref
                                .read(opsProvider.notifier)
                                .markDeparted(r.out.id),
                            child: const Text('MARQUER PARTI'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
