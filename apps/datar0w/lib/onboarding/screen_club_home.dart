import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../identity/controller.dart';
import '../identity/models.dart';
import '../router.dart';
import '../theme/deck_theme.dart';
import '../widgets/deck_scaffold.dart';
import '../widgets/deck_widgets.dart';

/// DR-40 — Aujourd’hui staff (Stitch Deck Volt).
class ClubRoleHomeScreen extends ConsumerWidget {
  const ClubRoleHomeScreen({super.key, required this.role});

  final ClubMemberRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(identityProvider);
    final club = snap.activeClub;
    final title = switch (role) {
      ClubMemberRole.intendant => 'Aujourd’hui intendant',
      ClubMemberRole.director => 'Aujourd’hui direction',
      ClubMemberRole.treasurer => 'Aujourd’hui trésorerie',
      ClubMemberRole.admin => 'Aujourd’hui staff',
      _ => 'Aujourd’hui club',
    };
    return DeckScaffold(
      title: title,
      subtitle: club?.name ?? role.name,
      retourFallback: AppRoutes.identity,
      actions: [
        IconButton(
          tooltip: 'Réglages',
          onPressed: () => context.go(AppRoutes.settings),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            club?.name ?? 'Club',
            style: const TextStyle(
              fontFamily: DeckType.ui,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            role.name,
            style: const TextStyle(
              fontFamily: DeckType.ui,
              color: DeckColors.label,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 8,
            children: [
              DeckHonestChip(kind: DeckHonestKind.cloud, label: 'Club cloud'),
              DeckHonestChip(kind: DeckHonestKind.local, label: 'Base locale'),
            ],
          ),
          const SizedBox(height: 16),
          if (role == ClubMemberRole.admin ||
              role == ClubMemberRole.director) ...[
            _StaffCard(
              title: 'Import cabane',
              subtitle: 'Bateaux et rameurs CSV',
              onTap: () => context.go(AppRoutes.clubImport),
            ),
            const SizedBox(height: 10),
            _StaffCard(
              title: 'Demandes',
              subtitle: 'Rejoindre / rôles',
              onTap: () => context.go(AppRoutes.clubJoin),
            ),
            const SizedBox(height: 10),
            _StaffCard(
              title: 'Séances cloud',
              subtitle: 'Séances synchronisées du club',
              onTap: () => context.go(AppRoutes.clubSessions),
            ),
            const SizedBox(height: 16),
          ],
          if (role == ClubMemberRole.treasurer)
            const Text(
              'Cotisations / budget : plus tard.',
              style: TextStyle(color: DeckColors.volt),
            ),
          if (role == ClubMemberRole.intendant) ...[
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.opsOut),
              child: const Text('Sortir'),
            ),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.opsIn),
              child: const Text('Rentrer'),
            ),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.opsMaintenance),
              child: const Text('Maintenance'),
            ),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.clubImport),
              child: const Text('Import parc'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.clubSessions),
              child: const Text('Séances cloud'),
            ),
          ],
          if (role == ClubMemberRole.admin) ...[
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.crew),
              child: const Text('Composition'),
            ),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.calendar),
              child: const Text('Calendrier'),
            ),
          ],
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.club),
            child: const Text('Club'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.sessions),
            child: const Text('Mes séances'),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.settings),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: DeckRadii.cardAll,
            border: Border.all(color: DeckColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: DeckType.ui,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: DeckColors.label, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
