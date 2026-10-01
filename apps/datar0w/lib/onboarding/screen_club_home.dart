import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../identity/controller.dart';
import '../identity/models.dart';
import '../router.dart';
import '../theme/deck_theme.dart';
import '../widgets/deck_scaffold.dart';

/// ST-03 — Accueil staff. Déconnexion → `/settings`.
class ClubRoleHomeScreen extends ConsumerWidget {
  const ClubRoleHomeScreen({super.key, required this.role});

  final ClubMemberRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(identityProvider);
    final club = snap.activeClub;
    final title = switch (role) {
      ClubMemberRole.intendant => 'ACCUEIL INTENDANT',
      ClubMemberRole.director => 'ACCUEIL DIRECTEUR',
      ClubMemberRole.treasurer => 'ACCUEIL TRÉSORIER',
      ClubMemberRole.admin => 'ACCUEIL CLUB',
      _ => 'ACCUEIL CLUB',
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
            '${club?.name ?? 'Club'} · ${role.name.toUpperCase()}',
            style: const TextStyle(
              color: DeckColors.label,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
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
              child: const Text('SORTIR'),
            ),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.opsIn),
              child: const Text('RENTRER'),
            ),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.opsMaintenance),
              child: const Text('MAINTENANCE'),
            ),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.clubImport),
              child: const Text('IMPORT PARC'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.clubSessions),
              child: const Text('SÉANCES CLOUD'),
            ),
          ],
          if (role == ClubMemberRole.admin) ...[
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.crew),
              child: const Text('COMPOSITION'),
            ),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.calendar),
              child: const Text('CALENDRIER'),
            ),
          ],
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.club),
            child: const Text('CLUB'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.sessions),
            child: const Text('MES SÉANCES'),
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
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: DeckColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
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
