import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../identity/models.dart';
import '../../router.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

class IdentityListScreen extends ConsumerWidget {
  const IdentityListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(identityProvider);
    return DeckScaffold(
      title: 'QUI RAME ?',
      subtitle: 'Profil local · pas de mot de passe',
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
                      onPressed: () => ref
                          .read(identityProvider.notifier)
                          .deleteRower(r.id),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
