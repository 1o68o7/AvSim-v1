import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../identity/models.dart';
import '../../onboarding/routing.dart';
import '../../router.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

/// Tests : forcer le masquage « Passer » (simule release).
@visibleForTesting
bool debugHidePasserSansProfil = false;

bool get allowPasserSansProfil =>
    kDebugMode && !debugHidePasserSansProfil;

String _currentPath(BuildContext context) {
  try {
    return GoRouterState.of(context).uri.path;
  } catch (_) {
    try {
      return GoRouter.of(context).state.uri.path;
    } catch (_) {
      return '?';
    }
  }
}

/// Log avant/après pour diagnostiquer les go no-op (release OnePlus).
void goFromIdentity(BuildContext context, String dest) {
  final from = _currentPath(context);
  debugPrint('[identity] go BEFORE path=$from dest=$dest');
  context.go(dest);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) {
      debugPrint('[identity] go AFTER  unmounted (wanted $dest)');
      return;
    }
    final after = _currentPath(context);
    debugPrint('[identity] go AFTER  path=$after (wanted $dest)');
  });
}

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
                    'Aucun profil. Crée-en un ou connecte-toi.',
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
                      await ref
                          .read(identityProvider.notifier)
                          .selectRower(r.id);
                      if (!context.mounted) return;
                      final dest = isRowerProfilePlayable(r)
                          ? AppRoutes.homeRower
                          : AppRoutes.rowerOnboard;
                      goFromIdentity(context, dest);
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
                  onPressed: () =>
                      goFromIdentity(context, AppRoutes.identityEdit),
                  child: const Text('CRÉER UN PROFIL'),
                ),
                if (allowPasserSansProfil) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(identityProvider.notifier)
                          .selectRower(null);
                      if (context.mounted) {
                        goFromIdentity(context, AppRoutes.profile);
                      }
                    },
                    child: const Text('Passer (sans profil)'),
                  ),
                ],
                TextButton(
                  onPressed: () => goFromIdentity(context, AppRoutes.auth),
                  child: const Text('Connexion'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
