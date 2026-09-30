import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/deck_theme.dart';

/// Écran d’erreur navigation — même copy que [GoRouter.errorBuilder].
/// Ne ramène PAS silencieusement vers `/identity`.
class PageIntrouvableScreen extends StatelessWidget {
  const PageIntrouvableScreen({
    super.key,
    required this.dest,
    this.error,
  });

  final String dest;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DeckColors.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Page introuvable',
                style: TextStyle(
                  color: DeckColors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                dest,
                textAlign: TextAlign.center,
                style: const TextStyle(color: DeckColors.amber, fontSize: 13),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: DeckColors.muted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => GoRouter.of(context).go('/identity'),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// try/catch autour du builder : throw → [PageIntrouvableScreen], pas snap-back.
class SafeRoute extends StatelessWidget {
  const SafeRoute({
    super.key,
    required this.dest,
    required this.builder,
  });

  final String dest;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    try {
      return builder(context);
    } catch (e, st) {
      debugPrint('[route:$dest] build failed: $e\n$st');
      return PageIntrouvableScreen(dest: dest, error: e);
    }
  }
}
