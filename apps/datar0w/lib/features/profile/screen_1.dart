import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../session/boat_config.dart';
import '../../session/rower_orientation.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import '../../widgets/deck_widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    unawaited(unlockRowerOrientations());
    final cfg = ref.watch(boatConfigProvider);
    return DeckScaffold(
      title: 'SÉLECTION PROFIL',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          const Text(
            'SÉLECTION PROFIL',
            style: TextStyle(
              color: DeckColors.label,
              fontSize: 11,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Poste de contrôle télémétrique',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _RoleCard(
            title: 'RAMEUR',
            subtitle: 'Instrument embarqué · Vue cale-pied',
            icon: Icons.speed,
            highlighted: true,
            onTap: () {
              ref.read(boatConfigProvider.notifier).setRole(CrewRole.rower);
              context.go(AppRoutes.presession);
            },
          ),
          const SizedBox(height: 12),
          _RoleCard(
            title: 'COACH',
            subtitle: 'Suivi direct bord de bassin',
            icon: Icons.sports,
            onTap: () {
              ref.read(boatConfigProvider.notifier).setRole(CrewRole.coach);
              context.go(AppRoutes.coachJoin);
            },
          ),
          const SizedBox(height: 12),
          _RoleCard(
            title: 'BARREUR',
            subtitle: 'V sol, distance, gîte bateau (4+ / 8+)',
            icon: Icons.directions_boat,
            footnote: 'un tél. = hub bateau, pas 8 IMU',
            onTap: () {
              ref.read(boatConfigProvider.notifier).setRole(CrewRole.cox);
              if (!cfg.coxed) {
                ref.read(boatConfigProvider.notifier).setClasse('8+');
              }
              context.go(AppRoutes.presession);
            },
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.highlighted = false,
    this.footnote,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool highlighted;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 1,
      child: Material(
        color: DeckColors.surfaceHigh,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: highlighted
                    ? DeckColors.amber.withValues(alpha: 0.6)
                    : DeckColors.hairline,
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (highlighted)
                    Container(width: 4, color: DeckColors.amber),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              DeckIconBox(
                                icon: icon,
                                accent: highlighted,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        color: DeckColors.text,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      style: const TextStyle(
                                        color: DeckColors.label,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward,
                                color: highlighted
                                    ? DeckColors.amber
                                    : DeckColors.label,
                                size: 20,
                              ),
                            ],
                          ),
                          if (footnote != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              footnote!.toUpperCase(),
                              style: const TextStyle(
                                color: DeckColors.label,
                                fontSize: 10,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
