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

    return DeckScaffold(
      title: 'ACCUEIL RAMEUR',
      subtitle: rower?.displayName ?? 'sans profil',
      leading: TextButton(
        onPressed: () => context.go(AppRoutes.profile),
        child: const Text('Retour'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: asg == null || boat == null
                  ? const _EmptyAssignment()
                  : _AssignedCard(boat: boat, assignment: asg),
            ),
            if (maint.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Ta coque est en maintenance.',
                  style: const TextStyle(color: DeckColors.amber),
                ),
              ),
            if (showClub)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClubBanner(club: club, compact: true),
              ),
            FilledButton(
              onPressed: () => _continue(context, ref),
              child: const Text('CONTINUER'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAssignment extends StatelessWidget {
  const _EmptyAssignment();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Pas d’affectation aujourd’hui.\n'
        'Le coach compose l’équipage.\n'
        'Continuer ouvre le choix de classe et de siège.',
        textAlign: TextAlign.center,
        style: TextStyle(color: DeckColors.muted, height: 1.4),
      ),
    );
  }
}

class _AssignedCard extends StatelessWidget {
  const _AssignedCard({required this.boat, required this.assignment});

  final ParkBoat boat;
  final Assignment assignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: DeckColors.hairline),
          color: DeckColors.surfaceHigh,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              boat.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              boat.classe,
              style: const TextStyle(color: DeckColors.label, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              assignmentChip(assignment),
              style: const TextStyle(color: DeckColors.amber, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
