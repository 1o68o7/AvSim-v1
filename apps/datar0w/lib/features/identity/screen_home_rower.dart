import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../identity/format.dart';
import '../../identity/models.dart';
import '../../ops/controller.dart';
import '../../ops/impact_report.dart';
import '../../router.dart';
import '../../session/boat_config.dart';
import '../identity/screen_home_roles.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/club_banner.dart';
import '../../widgets/deck_scaffold.dart';
import '../../widgets/deck_widgets.dart';

/// Accueil rameur : affectation coach (écrans 6/7) ou vide (écran 9). Pas de parc.
class HomeRowerScreen extends ConsumerWidget {
  const HomeRowerScreen({super.key});

  void _continue(BuildContext context, WidgetRef ref) {
    final snap = ref.read(identityProvider);
    final rower = snap.activeRower;
    final asg = rower == null ? null : snap.assignmentForRower(rower.id);
    continueFromAssignment(
      ref,
      role: CrewRole.rower,
      assignment: asg,
      boat: snap.boatById(asg?.boatId),
    );
    context.go(AppRoutes.presession);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ident = ref.watch(identityProvider);
    final rower = ident.activeRower;
    final asg = rower == null ? null : ident.assignmentForRower(rower.id);
    final boat = ident.boatById(asg?.boatId);
    final club = ident.activeClub;
    final showClub = club != null;
    final notices = rower == null
        ? const <OpsNotice>[]
        : ref.watch(opsProvider).noticesFor(rower.id);
    final maint = notices.where((n) => n.message.contains('maintenance'));
    final crew = boat == null
        ? const <Assignment>[]
        : ident.assignmentsForBoat(boat.id);
    Assignment? coxAsg;
    for (final a in crew) {
      if (a.role == 'cox') {
        coxAsg = a;
        break;
      }
    }
    final coxName = coxAsg == null
        ? null
        : (ident.rowerById(coxAsg.rowerId)?.displayName ?? 'barreur');

    return DeckScaffold(
      title: 'ACCUEIL RAMEUR',
      subtitle: rower?.displayName ?? 'sans profil',
      retourFallback: AppRoutes.profile,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (rower != null) ...[
            DeckSectionLabel(
              'Fiche athlète',
              trailing: asg == null
                  ? null
                  : const DeckStatusChip(label: 'affecté', ok: true),
            ),
            const SizedBox(height: 8),
            _AthleteSheet(rower: rower),
            const SizedBox(height: 20),
          ],
          if (asg == null || boat == null)
            const _EmptyAssignment()
          else ...[
            DeckSectionLabel(
              'Session en attente',
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
            _SessionCard(
              boat: boat,
              assignment: asg,
              coxName: coxName,
              crew: crew,
            ),
          ],
          if (maint.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Ta coque est en maintenance.',
                style: TextStyle(color: DeckColors.amber),
              ),
            ),
          if (showClub) ...[
            const SizedBox(height: 16),
            ClubBanner(club: club, compact: true),
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
            onPressed: () => _continue(context, ref),
            child: const Text('CONTINUER VERS LA SÉANCE'),
          ),
          if (showClub) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.club),
              child: const Text('VOIR MON CLUB'),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go(AppRoutes.sessions),
            child: const Text('MES SÉANCES'),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.devices),
            child: const Text('MES OBJETS'),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.physio),
            child: const Text('MES CONSTANTES'),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.spinoscope),
            child: const Text('SPINOSCOPE'),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.consent),
            child: const Text('DONNÉES SANTÉ'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(identityProvider.notifier).becomeCox();
              if (context.mounted) context.go(AppRoutes.homeCox);
            },
            child: const Text('Je barre aussi'),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.profile),
            child: const Text('Changer de profil'),
          ),
        ],
      ),
    );
  }
}

class _AthleteSheet extends StatelessWidget {
  const _AthleteSheet({required this.rower});

  final Rower rower;

  @override
  Widget build(BuildContext context) {
    final cat = rower.category();
    final weight = rower.weightKg == null
        ? '—'
        : rower.weightKg!.toStringAsFixed(1);
    final height = rower.heightCm == null
        ? '—'
        : '${rower.heightCm!.round()}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DeckColors.surfaceHigh,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rower.displayName.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              fontSize: 18,
            ),
          ),
          if (rower.ffaLicence != null && rower.ffaLicence!.isNotEmpty)
            Text(
              'Licence ${rower.ffaLicence}',
              style: const TextStyle(color: DeckColors.muted, fontSize: 11),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'CÔTÉ HABITUEL',
                style: TextStyle(color: DeckColors.label, fontSize: 9),
              ),
              const SizedBox(width: 12),
              DeckSideChip(rower.sidePref),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DeckFactCell(
                  label: 'Catégorie FFA',
                  value: '${cat.label} (${cat.code})',
                  hint: rower.sex.wire,
                ),
              ),
              Expanded(
                child: DeckFactCell(
                  label: 'Poids',
                  value: weight,
                  hint: weight == '—' ? null : 'KG',
                ),
              ),
              Expanded(
                child: DeckFactCell(
                  label: 'Taille',
                  value: height,
                  hint: height == '—' ? null : 'CM',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.boat,
    required this.assignment,
    required this.crew,
    this.coxName,
  });

  final ParkBoat boat;
  final Assignment assignment;
  final List<Assignment> crew;
  final String? coxName;

  @override
  Widget build(BuildContext context) {
    final seat = assignment.seatIndex;
    final oars = assignment.oars.isEmpty
        ? '—'
        : assignment.oars.join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DeckColors.surfaceHigh,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            boat.name.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DeckFactCell(
                  label: 'Poste',
                  value: seat == null ? '—' : 'Siège $seat',
                  hint: seat == 1 ? 'nage' : null,
                  accent: DeckColors.amber,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ORIENTATION',
                      style: TextStyle(
                        color: DeckColors.label,
                        fontSize: 9,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DeckSideChip(assignment.side),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DeckFactCell(
            label: 'Matériel dédié poste',
            value: oars,
          ),
          if (coxName != null) ...[
            const SizedBox(height: 12),
            DeckFactCell(
              label: 'Commande barreur',
              value: coxName!,
              hint: () {
                for (final a in crew) {
                  if (a.role == 'cox') return assignmentChip(a);
                }
                return null;
              }(),
            ),
          ],
          if (boat.seats > 1) ...[
            const SizedBox(height: 16),
            const DeckSectionLabel('Répartition latérale postes'),
            const SizedBox(height: 8),
            DeckSeatStrip(
              seats: boat.seats,
              assignments: crew,
              highlightSeat: seat,
              coxed: boat.cox,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyAssignment extends StatelessWidget {
  const _EmptyAssignment();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: DeckColors.hairline),
      ),
      child: const Column(
        children: [
          Text(
            'Pas d’affectation aujourd’hui.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Le coach compose l’équipage.\n'
            'Continuer ouvre le choix de classe et de siège.',
            textAlign: TextAlign.center,
            style: TextStyle(color: DeckColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
