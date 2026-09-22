import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../identity/models.dart';
import '../router.dart';
import '../theme/deck_theme.dart';
import '../widgets/deck_scaffold.dart';

/// Accueil squelette par rôle club (pas de refonte Stitch).
class ClubRoleHomeScreen extends ConsumerWidget {
  const ClubRoleHomeScreen({super.key, required this.role});

  final ClubMemberRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = switch (role) {
      ClubMemberRole.intendant => 'ACCUEIL INTENDANT',
      ClubMemberRole.director => 'ACCUEIL DIRECTEUR',
      ClubMemberRole.treasurer => 'ACCUEIL TRÉSORIER',
      ClubMemberRole.admin => 'ACCUEIL ADMIN',
      _ => 'ACCUEIL CLUB',
    };
    return DeckScaffold(
      title: title,
      subtitle: role.wire,
      retourFallback: AppRoutes.profile,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Squelette ${role.wire} — pas d’écran Stitch neuf.',
            style: const TextStyle(color: DeckColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (role == ClubMemberRole.treasurer)
            const Text(
              'Cotisations / budget : plus tard.',
              style: TextStyle(color: DeckColors.amber),
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
          ],
          if (role == ClubMemberRole.director ||
              role == ClubMemberRole.admin) ...[
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.clubJoin),
              child: const Text('DEMANDES DE RÔLE'),
            ),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.spinoscope),
              child: const Text('SPINOSCOPE'),
            ),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.calendar),
              child: const Text('CALENDRIER'),
            ),
          ],
          if (role == ClubMemberRole.admin) ...[
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.clubImport),
              child: const Text('IMPORT'),
            ),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.crew),
              child: const Text('COMPOSITION'),
            ),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.opsOut),
              child: const Text('PARC'),
            ),
          ],
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.club),
            child: const Text('CLUB'),
          ),
        ],
      ),
    );
  }
}
