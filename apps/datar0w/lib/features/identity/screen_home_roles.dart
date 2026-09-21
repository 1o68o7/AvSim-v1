import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../identity/format.dart';
import '../../identity/models.dart';
import '../../router.dart';
import '../../session/boat_config.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/club_banner.dart';
import '../../widgets/deck_scaffold.dart';

void continueFromAssignment(
  WidgetRef ref, {
  required CrewRole role,
  Assignment? assignment,
  ParkBoat? boat,
}) {
  final n = ref.read(boatConfigProvider.notifier);
  if (boat != null) n.setClasse(boat.classe);
  n.setRole(role);
  if (role == CrewRole.cox) {
    if (boat == null || !boat.cox) n.setClasse('8+');
    n.setRole(CrewRole.cox);
    final pos = assignment?.coxPosition == 'front'
        ? CoxPosition.front
        : CoxPosition.rear;
    n.setCoxPosition(pos);
  } else if (assignment?.seatIndex != null) {
    n.setSeat(assignment!.seatIndex!);
  }
}

class HomeCoxScreen extends ConsumerWidget {
  const HomeCoxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(identityProvider);
    final rower = snap.activeRower;
    final asg = rower == null ? null : snap.coxAssignmentFor(rower.id);
    final boat = snap.boatById(asg?.boatId);
    final crew = boat == null ? const <Assignment>[] : snap.assignmentsForBoat(boat.id);

    return DeckScaffold(
      title: 'ACCUEIL BARREUR',
      subtitle: boat?.name ?? 'sans affectation',
      retourFallback: AppRoutes.profile,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: asg == null || boat == null
                  ? const Center(
                      child: Text(
                        'Pas d’affectation barreur.\n'
                        'Continuer : classe barrée + rôle (pré-session).',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: DeckColors.muted, height: 1.4),
                      ),
                    )
                  : ListView(
                      children: [
                        Text(
                          boat.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${boat.classe} · ${assignmentChip(asg)}',
                          style: const TextStyle(color: DeckColors.amber),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'SIÈGES (lecture)',
                          style: TextStyle(
                            color: DeckColors.label,
                            fontSize: 11,
                            letterSpacing: 1.1,
                          ),
                        ),
                        for (final a in crew.where((x) => x.role != 'cox'))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              snap.rowerById(a.rowerId)?.displayName ?? a.rowerId,
                            ),
                            subtitle: Text(assignmentChip(a)),
                          ),
                      ],
                    ),
            ),
            FilledButton(
              onPressed: () {
                continueFromAssignment(
                  ref,
                  role: CrewRole.cox,
                  assignment: asg,
                  boat: boat,
                );
                context.go(AppRoutes.presession);
              },
              child: const Text('CONTINUER'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('ENTRAÎNEMENT'),
                  selected: ref.watch(boatConfigProvider).sessionMode ==
                      SessionMode.training,
                  onSelected: (_) => ref
                      .read(boatConfigProvider.notifier)
                      .setSessionMode(SessionMode.training),
                ),
                ChoiceChip(
                  label: const Text('COMPÉTITION'),
                  selected: ref.watch(boatConfigProvider).sessionMode ==
                      SessionMode.competition,
                  onSelected: (_) => ref
                      .read(boatConfigProvider.notifier)
                      .setSessionMode(SessionMode.competition),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HomeCoachScreen extends ConsumerWidget {
  const HomeCoachScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(identityProvider).activeClub;
    return DeckScaffold(
      title: 'ACCUEIL COACH',
      subtitle: 'Composition · parc · live',
      retourFallback: AppRoutes.profile,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          if (club != null) ...[
            ClubBanner(club: club),
            const SizedBox(height: 16),
          ],
          FilledButton(
            onPressed: () => context.go(AppRoutes.crew),
            child: const Text('COMPOSER'),
          ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.coachJoin),
              child: const Text('REJOINDRE'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.club),
              child: const Text('PARC'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.opsOut),
              child: const Text('SORTIR'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.opsIn),
              child: const Text('RENTRER'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.opsDeparture),
              child: const Text('DÉPART'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.opsMaintenance),
              child: const Text('MAINTENANCE'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.spinoscope),
              child: const Text('SPINOSCOPE'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.calendar),
              child: const Text('CALENDRIER'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('ENTRAÎNEMENT'),
                  selected: ref.watch(boatConfigProvider).sessionMode ==
                      SessionMode.training,
                  onSelected: (_) => ref
                      .read(boatConfigProvider.notifier)
                      .setSessionMode(SessionMode.training),
                ),
                ChoiceChip(
                  label: const Text('COMPÉTITION'),
                  selected: ref.watch(boatConfigProvider).sessionMode ==
                      SessionMode.competition,
                  onSelected: (_) => ref
                      .read(boatConfigProvider.notifier)
                      .setSessionMode(SessionMode.competition),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
