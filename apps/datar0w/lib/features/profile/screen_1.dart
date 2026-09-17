import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../session/rower_orientation.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    unawaited(unlockRowerOrientations());
    return DeckScaffold(
      title: 'DataR0w',
      subtitle: 'Sélection profil',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          const Text(
            'POSTE DE CONTRÔLE TÉLÉMÉTRIQUE',
            style: TextStyle(
              color: DeckColors.label,
              fontSize: 11,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _RoleCard(
            title: 'RAMEUR',
            subtitle: 'Instrument embarqué · Vue cale-pied',
            highlighted: true,
            onTap: () => context.go(AppRoutes.presession),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            title: 'COACH',
            subtitle: 'Suivi direct bord de bassin',
            onTap: () => context.go(AppRoutes.coachJoin),
          ),
          const SizedBox(height: 12),
          const _RoleCard(
            title: 'BARREUR',
            subtitle: "besoin d'un bateau barré",
            locked: true,
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
    this.onTap,
    this.highlighted = false,
    this.locked = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool highlighted;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Material(
        color: DeckColors.surfaceHigh,
        child: InkWell(
          onTap: locked ? null : onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: highlighted ? DeckColors.amber : DeckColors.hairline,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (highlighted)
                  Container(
                    width: 4,
                    height: 48,
                    color: DeckColors.amber,
                    margin: const EdgeInsets.only(right: 12),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: locked ? DeckColors.label : DeckColors.text,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: DeckColors.label,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  locked ? Icons.lock_outline : Icons.arrow_forward,
                  color: highlighted ? DeckColors.amber : DeckColors.label,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
