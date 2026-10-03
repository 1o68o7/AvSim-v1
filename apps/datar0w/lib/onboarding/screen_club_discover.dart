import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/deck_theme.dart';
import '../widgets/deck_widgets.dart';

/// Porte club froide — vitrine publique avant identité / auth.
///
/// Calendrier · plans d’eau · rejoindre. Pas un stack profils.
class ClubDiscoverScreen extends StatelessWidget {
  const ClubDiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DeckColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DataR0wMark(),
              const SizedBox(height: 28),
              const Text(
                'Le club, avant le compte',
                style: TextStyle(
                  fontFamily: DeckType.ui,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: DeckColors.text,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Explore le plan d’eau et le calendrier. '
                'Rejoins pour ramer — licence FFA optionnelle pour l’instant.',
                style: TextStyle(
                  fontFamily: DeckType.ui,
                  fontSize: 15,
                  height: 1.45,
                  color: DeckColors.label,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go(AppRoutes.calendar),
                child: const Text('Explorer le calendrier'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.waters),
                child: const Text('Plans d’eau'),
              ),
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: () => context.go(AppRoutes.auth),
                child: const Text('Rejoindre / Connexion'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.funnelOnboard),
                child: const Text('Commencer un morceau'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go(AppRoutes.identity),
                child: const Text(
                  'Profils locaux',
                  style: TextStyle(color: DeckColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
