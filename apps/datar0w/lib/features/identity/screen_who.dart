import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../identity/models.dart';
import '../../router.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

Future<void> _confirmDeleteRower(
  BuildContext context,
  WidgetRef ref,
  Rower rower,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final err = Theme.of(ctx).colorScheme.error;
      return AlertDialog(
        backgroundColor: DeckColors.surface,
        title: const Text('Supprimer ce profil ?'),
        content: Text(
          '« ${rower.displayName} » sera retiré de ce téléphone. '
          'Action locale, irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ANNULER'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: err),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('SUPPRIMER'),
          ),
        ],
      );
    },
  );
  if (ok == true && context.mounted) {
    await ref.read(identityProvider.notifier).deleteRower(rower.id);
  }
}

class IdentityListScreen extends ConsumerWidget {
  const IdentityListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(identityProvider);
    return DeckScaffold(
      title: 'QUI RAME ?',
      subtitle: 'Profil local · pas de mot de passe',
      showRetour: false,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                const Text(
                  'IDENTITÉ SUR CE TÉLÉPHONE',
                  style: TextStyle(
                    color: DeckColors.label,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                if (snap.rowers.isEmpty)
                  const Text(
                    'Aucun profil. Crée-en un ou passe (mode loisir).',
                    style: TextStyle(color: DeckColors.muted),
                  ),
                for (final r in snap.rowers)
                  ListTile(
                    selected: snap.prefs.activeRowerId == r.id,
                    title: Text(r.displayName),
                    subtitle: Text(
                      '${r.category().code} · ${r.sex.wire}'
                      '${r.lightweight ? ' · léger' : ''}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Supprimer le profil',
                      onPressed: () => _confirmDeleteRower(context, ref, r),
                    ),
                    onTap: () async {
                      await ref.read(identityProvider.notifier).selectRower(r.id);
                      if (context.mounted) context.go(AppRoutes.profile);
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: () => context.go(AppRoutes.identityEdit),
                  child: const Text('CRÉER UN PROFIL'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    await ref.read(identityProvider.notifier).selectRower(null);
                    if (context.mounted) context.go(AppRoutes.profile);
                  },
                  child: const Text('Passer (sans profil)'),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.auth),
                  child: const Text('Connexion'),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.clubLogin),
                  child: const Text('Espace club'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
