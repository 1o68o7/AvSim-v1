import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../identity/models.dart';
import '../../router.dart';
import '../../session/boat_config.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/club_banner.dart';
import '../../widgets/deck_shell.dart';
import '../../widgets/deck_widgets.dart';

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

/// DR-53 — Aujourd'hui barreur (shell 3 onglets, comme rameur / coach).
class HomeCoxScreen extends ConsumerWidget {
  const HomeCoxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(identityProvider);
    final rower = snap.activeRower;
    final asg = rower == null ? null : snap.coxAssignmentFor(rower.id);
    final boat = snap.boatById(asg?.boatId);
    final crew =
        boat == null ? const <Assignment>[] : snap.assignmentsForBoat(boat.id);
    final coxRear = asg?.coxPosition != 'front';
    final mode = ref.watch(boatConfigProvider).sessionMode;

    return DeckTabScaffold(
      tab: DeckTab.today,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: DeckColors.bg.withValues(alpha: 0.92),
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 56,
            titleSpacing: 16,
            title: const Text(
              "Aujourd'hui",
              style: TextStyle(
                fontFamily: DeckType.ui,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: DeckColors.text,
                letterSpacing: -0.2,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Profil',
                onPressed: () => context.go(AppRoutes.settings),
                icon: const Icon(Icons.person_outline, color: DeckColors.text),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  rower?.displayName ?? 'Accueil barreur',
                  style: const TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.24,
                    color: DeckColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  boat?.name ?? 'Sans affectation barreur',
                  style: const TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 14,
                    color: DeckColors.label,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const DeckStatusChip(label: 'barreur', ok: true),
                    DeckSessionModeSwitch(
                      mode: mode,
                      onChanged: (m) => ref
                          .read(boatConfigProvider.notifier)
                          .setSessionMode(m),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (asg == null || boat == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DeckColors.surface,
                      borderRadius: DeckRadii.cardAll,
                      border: Border.all(color: DeckColors.hairline),
                    ),
                    child: const Text(
                      'Pas d’affectation barreur.\n'
                      'Continuer : classe barrée + rôle (pré-session).',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: DeckType.ui,
                        color: DeckColors.muted,
                        height: 1.4,
                        fontSize: 14,
                      ),
                    ),
                  )
                else ...[
                  DeckSectionLabel(
                    'Affectation coque',
                    trailing: Text(
                      boat.classe.toUpperCase(),
                      style: const TextStyle(
                        color: DeckColors.volt,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: DeckColors.surface,
                      borderRadius: DeckRadii.cardAll,
                      border: Border.all(color: DeckColors.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DeckFactCell(label: 'Bâtiment', value: boat.name),
                        const SizedBox(height: 14),
                        Text(
                          'Poste barreur',
                          style: DeckType.uiLabel(size: 11),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _CoxPosChip(
                                label: 'Avant',
                                selected: !coxRear,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _CoxPosChip(
                                label: 'Arrière',
                                selected: coxRear,
                              ),
                            ),
                          ],
                        ),
                        if (boat.cox) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: DeckColors.volt.withValues(alpha: 0.12),
                              borderRadius: DeckRadii.buttonAll,
                            ),
                            child: const Text(
                              'Lecture seule — composition coach.',
                              style: TextStyle(
                                fontFamily: DeckType.ui,
                                color: DeckColors.volt,
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const DeckSectionLabel(
                    'Composition équipage (lecture seule)',
                  ),
                  const SizedBox(height: 8),
                  for (final a in crew.where((x) => x.role != 'cox'))
                    _CrewRow(
                      title:
                          snap.rowerById(a.rowerId)?.displayName ?? a.rowerId,
                      subtitle: [
                        if (a.seatIndex != null) 'S${a.seatIndex}',
                        if (a.oars.isNotEmpty) a.oars.join('/'),
                      ].join(' · '),
                      side: a.side,
                    ),
                  if (rower != null)
                    _CrewRow(
                      title: rower.displayName,
                      subtitle: 'Poste actif (vous)',
                      side: SidePref.none,
                      you: true,
                    ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      continueFromAssignment(
                        ref,
                        role: CrewRole.cox,
                        assignment: asg,
                        boat: boat,
                      );
                      context.go(AppRoutes.presession);
                    },
                    child: const Text('Continuer'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go(AppRoutes.club),
                  child: const Text('Parc'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoxPosChip extends StatelessWidget {
  const _CoxPosChip({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? DeckColors.volt : DeckColors.bg,
        borderRadius: DeckRadii.buttonAll,
        border: Border.all(
          color: selected ? DeckColors.volt : DeckColors.hairline,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: DeckType.ui,
          color: selected ? DeckColors.onVolt : DeckColors.label,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _CrewRow extends StatelessWidget {
  const _CrewRow({
    required this.title,
    required this.subtitle,
    required this.side,
    this.you = false,
  });

  final String title;
  final String subtitle;
  final SidePref side;
  final bool you;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: you
            ? DeckColors.volt.withValues(alpha: 0.1)
            : DeckColors.surface,
        borderRadius: DeckRadii.cardAll,
        border: Border.all(
          color: you ? DeckColors.volt : DeckColors.hairline,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: DeckType.ui,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: DeckType.ui,
                      color: DeckColors.muted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (you)
            const DeckStatusChip(label: 'barreur', ok: true)
          else if (side != SidePref.none)
            DeckSideChip(side),
        ],
      ),
    );
  }
}

/// DR-30 — Aujourd'hui coach (shell 3 onglets).
class HomeCoachScreen extends ConsumerWidget {
  const HomeCoachScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Aligne le rôle de séance sur le hub coach (ops / crew via clubRole).
    if (ref.watch(boatConfigProvider).role != CrewRole.coach) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(boatConfigProvider.notifier).setRole(CrewRole.coach);
      });
    }
    final snap = ref.watch(identityProvider);
    final club = snap.activeClub;
    final rowers = club == null
        ? snap.rowers
        : snap.rowers.where((r) => r.clubId == club.id).toList();
    final boats = snap.boatsForClub(club?.id);
    final available = boats.length;
    final coachName = snap.activeRower?.displayName ?? 'Coach';

    return DeckTabScaffold(
      tab: DeckTab.today,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: DeckColors.bg.withValues(alpha: 0.92),
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 56,
            titleSpacing: 16,
            title: const Text(
              "Aujourd'hui",
              style: TextStyle(
                fontFamily: DeckType.ui,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: DeckColors.text,
                letterSpacing: -0.2,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Réglages',
                onPressed: () => context.go(AppRoutes.settings),
                icon: const Icon(Icons.person_outline, color: DeckColors.text),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  coachName,
                  style: const TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.24,
                    color: DeckColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  club?.name ?? 'Sans club actif',
                  style: const TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 14,
                    color: DeckColors.label,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const DeckHonestChip(
                      kind: DeckHonestKind.cloud,
                      label: 'Club cloud',
                    ),
                    DeckSessionModeSwitch(
                      mode: ref.watch(boatConfigProvider).sessionMode,
                      onChanged: (m) => ref
                          .read(boatConfigProvider.notifier)
                          .setSessionMode(m),
                    ),
                  ],
                ),
                if (club != null) ...[
                  const SizedBox(height: 12),
                  ClubBanner(club: club, compact: true),
                ],
                const SizedBox(height: 16),
                _CoachCard(
                  icon: Icons.radar,
                  title: 'Flotte en navigation',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: () => context.go(AppRoutes.coachJoin),
                          child: const Text('Rejoindre'),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.coachJoin),
                        child: const Text('Autre code'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _CoachCard(
                  icon: Icons.group_add,
                  title: 'Équipages du jour',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${rowers.length} rameurs',
                        style: const TextStyle(
                          fontFamily: DeckType.ui,
                          fontSize: 13,
                          color: DeckColors.label,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: () => context.go(AppRoutes.crew),
                          icon: const Icon(Icons.rule),
                          label: const Text('Composer'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _CoachCard(
                  icon: Icons.directions_boat,
                  title: 'Parc & ponton',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          _StatPill(label: 'Dispos', value: '$available'),
                          const SizedBox(width: 8),
                          _StatPill(label: 'Rameurs', value: '${rowers.length}'),
                          const SizedBox(width: 8),
                          const _StatPill(label: 'Maint.', value: '—'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => context.go(AppRoutes.opsOut),
                            child: const Text('Sortir'),
                          ),
                          OutlinedButton(
                            onPressed: () => context.go(AppRoutes.opsIn),
                            child: const Text('Rentrer'),
                          ),
                          OutlinedButton(
                            onPressed: () => context.go(AppRoutes.club),
                            child: const Text('Parc'),
                          ),
                          OutlinedButton(
                            onPressed: () => context.go(AppRoutes.opsDeparture),
                            child: const Text('Départ'),
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                context.go(AppRoutes.opsMaintenance),
                            child: const Text('Maintenance'),
                          ),
                          OutlinedButton(
                            onPressed: () => context.go(AppRoutes.spinoscope),
                            child: const Text('Spinoscope'),
                          ),
                          OutlinedButton(
                            onPressed: () => context.go(AppRoutes.calendar),
                            child: const Text('Calendrier'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _CoachCard(
                  icon: Icons.history_edu,
                  title: 'Débrief',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextButton(
                        onPressed: () => context.go(
                          '${AppRoutes.sessions}?from=coach',
                        ),
                        child: const Row(
                          children: [
                            Text('Mes séances'),
                            Spacer(),
                            Icon(Icons.chevron_right, size: 18),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.clubSessions),
                        child: const Text('Séances cloud'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontFamily: DeckType.ui,
                      fontSize: 13,
                      color: DeckColors.label,
                    ),
                    children: [
                      const TextSpan(text: 'Profil rameur dans '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: () => context.go(AppRoutes.plus),
                          child: const Text(
                            'Plus',
                            style: TextStyle(
                              fontFamily: DeckType.ui,
                              fontSize: 13,
                              color: DeckColors.volt,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.icon,
    required this.title,
    required this.child,
    this.badge,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: DeckRadii.cardAll,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: DeckColors.tribord),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: DeckColors.text,
                  ),
                ),
              ),
              if (badge != null)
                Text(
                  badge!,
                  style: DeckType.labelMono(color: DeckColors.label, size: 10),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: DeckColors.bg,
          borderRadius: DeckRadii.buttonAll,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: DeckType.metric(size: 20, weight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(label, style: DeckType.uiLabel(size: 11)),
          ],
        ),
      ),
    );
  }
}
