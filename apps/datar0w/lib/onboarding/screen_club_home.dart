import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../identity/controller.dart';
import '../identity/models.dart';
import '../router.dart';
import '../theme/deck_theme.dart';
import '../widgets/club_banner.dart';
import '../widgets/deck_shell.dart';
import '../widgets/deck_widgets.dart';

/// DR-40 — Aujourd'hui staff (shell 3 onglets).
/// Cartes filtrées par rôle club (IA) — pas de sélecteur de rôle à l'écran.
class ClubRoleHomeScreen extends ConsumerWidget {
  const ClubRoleHomeScreen({super.key, required this.role});

  final ClubMemberRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(identityProvider);
    final club = snap.activeClub;
    final roleLabel = role.labelFr;

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
                  club?.name ?? 'Club',
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
                  roleLabel,
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
                    const DeckHonestChip(
                      kind: DeckHonestKind.local,
                      label: 'Base locale',
                    ),
                    DeckHonestChip(
                      kind: DeckHonestKind.club,
                      label: roleLabel,
                    ),
                  ],
                ),
                if (club != null) ...[
                  const SizedBox(height: 12),
                  ClubBanner(club: club, compact: true),
                ],
                const SizedBox(height: 16),
                // admin : tout
                if (role == ClubMemberRole.admin) ...[
                  _StaffCard(
                    icon: Icons.upload_file_outlined,
                    title: 'Import cabane',
                    subtitle: 'Bateaux et rameurs CSV',
                    onTap: () => context.go(AppRoutes.clubImport),
                  ),
                  const SizedBox(height: 10),
                  _StaffCard(
                    icon: Icons.how_to_reg_outlined,
                    title: 'Demandes',
                    subtitle: 'Rejoindre / rôles',
                    onTap: () => context.go(AppRoutes.clubJoin),
                  ),
                  const SizedBox(height: 10),
                  _StaffCard(
                    icon: Icons.cloud_outlined,
                    title: 'Séances du club',
                    subtitle: 'session_meta cloud',
                    onTap: () => context.go(AppRoutes.clubSessions),
                  ),
                  const SizedBox(height: 10),
                  _StaffCard(
                    icon: Icons.group_outlined,
                    title: 'Composition',
                    subtitle: 'Équipage',
                    onTap: () => context.go(AppRoutes.crew),
                  ),
                  const SizedBox(height: 10),
                  _StaffCard(
                    icon: Icons.event_outlined,
                    title: 'Calendrier',
                    subtitle: 'Événements',
                    onTap: () => context.go(AppRoutes.calendar),
                  ),
                  const SizedBox(height: 16),
                ],
                // director : demandes + séances club
                if (role == ClubMemberRole.director) ...[
                  _StaffCard(
                    icon: Icons.how_to_reg_outlined,
                    title: 'Demandes',
                    subtitle: 'Rejoindre / rôles',
                    onTap: () => context.go(AppRoutes.clubJoin),
                  ),
                  const SizedBox(height: 10),
                  _StaffCard(
                    icon: Icons.cloud_outlined,
                    title: 'Séances du club',
                    subtitle: 'session_meta cloud',
                    onTap: () => context.go(AppRoutes.clubSessions),
                  ),
                  const SizedBox(height: 16),
                ],
                // intendant : parc + maintenance + import bateaux
                if (role == ClubMemberRole.intendant) ...[
                  _StaffCard(
                    icon: Icons.logout,
                    title: 'Sortir',
                    subtitle: 'Check-out parc',
                    onTap: () => context.go(AppRoutes.opsOut),
                  ),
                  const SizedBox(height: 10),
                  _StaffCard(
                    icon: Icons.login,
                    title: 'Rentrer',
                    subtitle: 'Check-in parc',
                    onTap: () => context.go(AppRoutes.opsIn),
                  ),
                  const SizedBox(height: 10),
                  _StaffCard(
                    icon: Icons.build_outlined,
                    title: 'Maintenance',
                    subtitle: 'Impacts et avaries',
                    onTap: () => context.go(AppRoutes.opsMaintenance),
                  ),
                  const SizedBox(height: 10),
                  _StaffCard(
                    icon: Icons.upload_file_outlined,
                    title: 'Import bateaux',
                    subtitle: 'CSV parc',
                    onTap: () => context.go(AppRoutes.clubImport),
                  ),
                  const SizedBox(height: 16),
                ],
                // treasurer : pas de DR-42 téléphone
                if (role == ClubMemberRole.treasurer) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DeckColors.surface,
                      borderRadius: DeckRadii.cardAll,
                      border: Border.all(color: DeckColors.hairline),
                    ),
                    child: const Text(
                      'Cotisations / budget : plus tard.',
                      style: TextStyle(
                        fontFamily: DeckType.ui,
                        fontSize: 14,
                        color: DeckColors.volt,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _StaffCard(
                    icon: Icons.cloud_outlined,
                    title: 'Séances du club',
                    subtitle: 'session_meta cloud',
                    onTap: () => context.go(AppRoutes.clubSessions),
                  ),
                  const SizedBox(height: 16),
                ],
                _StaffCard(
                  icon: Icons.apartment_outlined,
                  title: 'Club',
                  subtitle: club?.name ?? 'Parc et fiche club',
                  onTap: () => context.go(AppRoutes.club),
                ),
                const SizedBox(height: 10),
                _StaffCard(
                  icon: Icons.history,
                  title: 'Mes séances',
                  subtitle: 'Replay local',
                  onTap: () => context.go(AppRoutes.sessions),
                ),
                const SizedBox(height: 16),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontFamily: DeckType.ui,
                      fontSize: 13,
                      color: DeckColors.label,
                    ),
                    children: [
                      const TextSpan(
                        text: 'Tu rames ou entraînes ? Retrouve ton profil dans ',
                      ),
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

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DeckColors.surface,
      borderRadius: DeckRadii.cardAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: DeckRadii.cardAll,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: DeckRadii.cardAll,
            border: Border.all(color: DeckColors.hairline),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: DeckColors.tribord),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: DeckType.ui,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: DeckColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: DeckType.ui,
                        color: DeckColors.label,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: DeckColors.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
