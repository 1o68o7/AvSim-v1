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

String _routerPath(GoRouter router) {
  try {
    return router.state.uri.path;
  } catch (e) {
    return '?($e)';
  }
}

/// Même [GoRouter] que [MaterialApp.router] via [GoRouter.of].
/// 1) `go` 2) si path ≠ dest après 300 ms → `push` 3) sinon message d’erreur.
Future<String?> navigateFromIdentity(
  BuildContext context,
  String dest,
) async {
  final router = GoRouter.of(context);
  final from = _routerPath(router);
  Object? goError;
  Object? pushError;

  debugPrint('[identity] nav BEFORE path=$from dest=$dest (go)');
  try {
    router.go(dest);
  } catch (e, st) {
    goError = e;
    debugPrint('[identity] go THROW $e\n$st');
  }

  await Future<void>.delayed(const Duration(milliseconds: 300));
  if (!context.mounted) return null;

  var after = _routerPath(router);
  if (after == dest) {
    debugPrint('[identity] go OK path=$after');
    return null;
  }
  debugPrint(
    '[identity] go no-op path=$after wanted=$dest — essai push',
  );

  try {
    await router.push(dest);
  } catch (e, st) {
    pushError = e;
    debugPrint('[identity] push THROW $e\n$st');
  }

  await Future<void>.delayed(const Duration(milliseconds: 300));
  if (!context.mounted) return null;

  after = _routerPath(router);
  if (after == dest) {
    debugPrint('[identity] push OK path=$after');
    return null;
  }

  debugPrint(
    '[identity] push no-op path=$after wanted=$dest goErr=$goError pushErr=$pushError',
  );
  final detail = pushError ?? goError ?? 'reste sur $after';
  return 'Navigation bloquée : $dest ($detail)';
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

class IdentityListScreen extends ConsumerStatefulWidget {
  const IdentityListScreen({super.key});

  @override
  ConsumerState<IdentityListScreen> createState() =>
      _IdentityListScreenState();
}

class _IdentityListScreenState extends ConsumerState<IdentityListScreen> {
  String? _lastNavError;

  Future<void> _nav(String dest) async {
    setState(() => _lastNavError = null);
    final err = await navigateFromIdentity(context, dest);
    if (!mounted) return;
    if (err != null) setState(() => _lastNavError = err);
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(identityProvider);
    return DeckScaffold(
      title: 'Profils',
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
                        if (!mounted) return;
                        final dest = isRowerProfilePlayable(r)
                            ? AppRoutes.homeRower
                            : AppRoutes.rowerOnboard;
                        await _nav(dest);
                      } catch (e) {
                        if (!mounted) return;
                        setState(() {
                          _lastNavError =
                              'Navigation bloquée : ${AppRoutes.homeRower} $e';
                        });
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
                if (_lastNavError != null) ...[
                  Text(
                    _lastNavError!,
                    style: const TextStyle(
                      color: DeckColors.volt,
                      fontSize: 16,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                FilledButton(
                  onPressed: () => _nav(AppRoutes.identityEdit),
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
                        if (mounted) await _nav(AppRoutes.profile);
                      } catch (e) {
                        if (!mounted) return;
                        setState(() {
                          _lastNavError =
                              'Navigation bloquée : ${AppRoutes.profile} $e';
                        });
                      }
                    },
                    child: const Text('Passer (sans profil)'),
                  ),
                ],
                TextButton(
                  onPressed: () => _nav(AppRoutes.auth),
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
