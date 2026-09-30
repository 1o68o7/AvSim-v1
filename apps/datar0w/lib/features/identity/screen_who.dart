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

/// Log + garde : si la location n’a pas bougé après 300 ms → SnackBar visible
/// (pas d’adb / logcat sur le terrain).
Future<void> goFromIdentity(BuildContext context, String dest) async {
  final router = GoRouter.of(context);
  final from = router.state.uri.path;
  Object? goError;
  debugPrint('[identity] go BEFORE path=$from dest=$dest');
  try {
    router.go(dest);
  } catch (e, st) {
    goError = e;
    debugPrint('[identity] go THROW $e\n$st');
  }
  await Future<void>.delayed(const Duration(milliseconds: 300));
  if (!context.mounted) return;
  final after = router.state.uri.path;
  debugPrint('[identity] go AFTER  path=$after (wanted $dest)');
  if (after == dest) return;
  final err = goError ?? 'reste sur $after';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Navigation bloquée : $dest $err')),
  );
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
                      try {
                        await ref
                            .read(identityProvider.notifier)
                            .selectRower(r.id);
                        if (!context.mounted) return;
                        final dest = isRowerProfilePlayable(r)
                            ? AppRoutes.homeRower
                            : AppRoutes.rowerOnboard;
                        await goFromIdentity(context, dest);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Navigation bloquée : ${AppRoutes.homeRower} $e',
                            ),
                          ),
                        );
                      }
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
                  onPressed: () async {
                    try {
                      await goFromIdentity(context, AppRoutes.identityEdit);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Navigation bloquée : ${AppRoutes.identityEdit} $e',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('CRÉER UN PROFIL'),
                ),
                if (allowPasserSansProfil) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      try {
                        await ref
                            .read(identityProvider.notifier)
                            .selectRower(null);
                        if (context.mounted) {
                          await goFromIdentity(context, AppRoutes.profile);
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Navigation bloquée : ${AppRoutes.profile} $e',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Passer (sans profil)'),
                  ),
                ],
                TextButton(
                  onPressed: () async {
                    try {
                      await goFromIdentity(context, AppRoutes.auth);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Navigation bloquée : ${AppRoutes.auth} $e',
                          ),
                        ),
                      );
                    }
                  },
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
