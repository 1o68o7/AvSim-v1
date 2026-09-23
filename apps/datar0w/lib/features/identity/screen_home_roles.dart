import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../identity/models.dart';
import '../../router.dart';
import '../../session/boat_config.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/club_banner.dart';
import '../../widgets/deck_scaffold.dart';
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

    return DeckScaffold(
      title: 'ACCUEIL BARREUR',
      subtitle: boat?.name ?? 'sans affectation',
      retourFallback: AppRoutes.profile,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (asg == null || boat == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Pas d’affectation barreur.\n'
                'Continuer : classe barrée + rôle (pré-session).',
                textAlign: TextAlign.center,
                style: TextStyle(color: DeckColors.muted, height: 1.4),
              ),
            )
          else ...[
            DeckSectionLabel(
              'Affectation coque',
              trailing: Text(
                boat.classe.toUpperCase(),
                style: const TextStyle(
                  color: DeckColors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DeckColors.surfaceHigh,
                border: Border.all(color: DeckColors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DeckFactCell(label: 'Bâtiment', value: boat.name),
                  const SizedBox(height: 14),
                  const Text(
                    'POSTE DU BARREUR',
                    style: TextStyle(
                      color: DeckColors.label,
                      fontSize: 9,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _CoxPosChip(
                          label: 'AVANT (PROUE)',
                          selected: !coxRear,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CoxPosChip(
                          label: 'ARRIÈRE (POUPE)',
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
                      color: DeckColors.amber.withValues(alpha: 0.12),
                      child: const Text(
                        'Poste barreur obligatoire sur cette classe. '
                        'Lecture seule — composition coach.',
                        style: TextStyle(
                          color: DeckColors.amber,
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
            const DeckSectionLabel('Composition équipage (lecture seule)'),
            const SizedBox(height: 8),
            for (final a in crew.where((x) => x.role != 'cox'))
              _CrewRow(
                title: snap.rowerById(a.rowerId)?.displayName ?? a.rowerId,
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
          const SizedBox(height: 12),
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
            child: const Text('CONTINUER VERS LA SÉANCE'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go(AppRoutes.club),
            child: const Text('REVOIR LE PARC COQUES'),
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
        color: selected ? DeckColors.amber : DeckColors.bg,
        border: Border.all(
          color: selected ? DeckColors.amber : DeckColors.hairline,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected ? DeckColors.onAlert : DeckColors.label,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
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
        color: you ? DeckColors.amber.withValues(alpha: 0.1) : DeckColors.bg,
        border: Border.all(
          color: you ? DeckColors.amber : DeckColors.hairline,
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
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
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

class HomeCoachScreen extends ConsumerWidget {
  const HomeCoachScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(identityProvider);
    final club = snap.activeClub;
    final rowers = club == null
        ? snap.rowers
        : snap.rowers.where((r) => r.clubId == club.id).toList();
    final boats = snap.boatsForClub(club?.id);
    final preview = rowers.take(4).toList();

    return DeckScaffold(
      title: 'ACCUEIL COACH',
      subtitle: club?.name ?? 'Composition · parc · live',
      retourFallback: AppRoutes.profile,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (club != null) ...[
            ClubBanner(club: club),
            const SizedBox(height: 16),
          ],
          _CoachAction(
            icon: Icons.group_add,
            title: 'COMPOSER UN ÉQUIPAGE',
            subtitle: 'Affectation bancs & répartition tribord / bâbord',
            onTap: () => context.go(AppRoutes.crew),
            primary: true,
          ),
          _CoachAction(
            icon: Icons.sensors,
            title: 'REJOINDRE UNE SÉANCE',
            subtitle: 'Connexion télémétrie bateau en direct',
            onTap: () => context.go(AppRoutes.coachJoin),
          ),
          const SizedBox(height: 8),
          DeckSectionLabel(
            'Rameurs du club',
            trailing: Text(
              '${rowers.length}',
              style: const TextStyle(
                color: DeckColors.amber,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (preview.isEmpty)
            const Text(
              'Aucun rameur — importe ou crée des profils.',
              style: TextStyle(color: DeckColors.muted),
            )
          else
            for (final r in preview)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: DeckColors.hairline),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.displayName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${r.category().code} · ${r.sex.wire}'
                              '${r.weightKg == null ? '' : ' · ${r.weightKg!.toStringAsFixed(0)} kg'}',
                              style: const TextStyle(
                                color: DeckColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (r.sidePref != SidePref.none) DeckSideChip(r.sidePref),
                    ],
                  ),
                ),
              ),
          TextButton(
            onPressed: () => context.go(AppRoutes.identity),
            child: Text(
              rowers.isEmpty
                  ? 'VOIR LES PROFILS'
                  : 'VOIR TOUS LES RAMEURS (${rowers.length})',
            ),
          ),
          const SizedBox(height: 8),
          DeckSectionLabel(
            'Parc à bateaux',
            trailing: Text(
              '${boats.length} coques',
              style: const TextStyle(color: DeckColors.label, fontSize: 11),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.club),
            child: const Text('PARC'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.opsOut),
            child: const Text('SORTIR'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.opsIn),
            child: const Text('RENTRER'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.opsDeparture),
            child: const Text('DÉPART'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.opsMaintenance),
            child: const Text('MAINTENANCE'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.spinoscope),
            child: const Text('SPINOSCOPE'),
          ),
          const SizedBox(height: 8),
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
          TextButton(
            onPressed: () => context.go(AppRoutes.profile),
            child: const Text('CHANGER DE PROFIL'),
          ),
        ],
      ),
    );
  }
}

class _CoachAction extends StatelessWidget {
  const _CoachAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: primary ? DeckColors.amber : DeckColors.surfaceHigh,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(
                color: primary ? DeckColors.amber : DeckColors.hairline,
              ),
            ),
            child: Row(
              children: [
                DeckIconBox(icon: icon, accent: !primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: primary
                              ? DeckColors.onAlert
                              : DeckColors.text,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: primary
                              ? DeckColors.onAlert.withValues(alpha: 0.7)
                              : DeckColors.muted,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  color: primary ? DeckColors.onAlert : DeckColors.label,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
