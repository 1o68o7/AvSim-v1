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
import '../../widgets/deck_widgets.dart';

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

String _sexShort(RowerSex s) => switch (s) {
      RowerSex.m => 'H',
      RowerSex.f => 'F',
      RowerSex.x => 'X',
    };

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

/// DR-01 — Qui est là (Stitch).
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

  Future<void> _openRower(Rower r) async {
    try {
      await ref.read(identityProvider.notifier).selectRower(r.id);
      if (!mounted) return;
      final dest = isRowerProfilePlayable(r)
          ? AppRoutes.homeRower
          : AppRoutes.rowerOnboard;
      await _nav(dest);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastNavError = 'Navigation bloquée : ${AppRoutes.homeRower} $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(identityProvider);
    final club = snap.activeClub;
    final activeId = snap.prefs.activeRowerId;

    return DeckScaffold(
      title: 'Qui est là',
      subtitle: 'Profil local · pas de mot de passe',
      showRetour: false,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: DeckColors.tribord,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Télémétrie prête',
                      style: DeckType.labelMono(color: DeckColors.label),
                    ),
                    const Spacer(),
                    const DeckHonestChip(kind: DeckHonestKind.local),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Qui est là',
                  style: TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.64,
                    height: 40 / 32,
                    color: DeckColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Un téléphone = une place de bateau. Les autres sièges '
                  'ont leur propre appareil.',
                  style: TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 14,
                    height: 1.4,
                    color: DeckColors.label,
                  ),
                ),
                const SizedBox(height: 20),
                if (snap.rowers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DeckColors.surface,
                      borderRadius: DeckRadii.cardAll,
                      border: Border.all(color: DeckColors.hairline),
                    ),
                    child: const Text(
                      'Aucun profil. Crée-en un ou connecte-toi.',
                      style: TextStyle(
                        fontFamily: DeckType.ui,
                        color: DeckColors.label,
                        fontSize: 14,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < snap.rowers.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _ProfileCard(
                      rower: snap.rowers[i],
                      seatHint: 'S${i + 1}',
                      selected: activeId == snap.rowers[i].id,
                      primary: i == 0 || activeId == snap.rowers[i].id,
                      clubName: club?.name,
                      onOpen: () => _openRower(snap.rowers[i]),
                      onDelete: () =>
                          _confirmDeleteRower(context, ref, snap.rowers[i]),
                    ),
                  ],
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
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () => _nav(AppRoutes.identityEdit),
                    icon: const Icon(Icons.add, size: 22),
                    label: const Text('Créer un profil'),
                  ),
                ),
                if (allowPasserSansProfil) ...[
                  const SizedBox(height: 4),
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
                  child: const Text(
                    'J\'ai déjà un compte club (Connexion)',
                  ),
                ),
                const SizedBox(height: 4),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 15,
                      color: DeckColors.label,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Données stockées localement sur ce téléphone.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: DeckType.ui,
                          fontSize: 12,
                          color: DeckColors.label,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.rower,
    required this.seatHint,
    required this.selected,
    required this.primary,
    required this.onOpen,
    required this.onDelete,
    this.clubName,
  });

  final Rower rower;
  final String seatHint;
  final bool selected;
  final bool primary;
  final String? clubName;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cat = rower.category();
    final catChip = '${cat.code} ${_sexShort(rower.sex)}';
    final clubLine = (clubName != null && clubName!.isNotEmpty)
        ? clubName!
        : 'Profil local';

    return Material(
      color: DeckColors.surface,
      borderRadius: DeckRadii.cardAll,
      child: InkWell(
        borderRadius: DeckRadii.cardAll,
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: DeckRadii.cardAll,
            border: Border.all(
              color: selected ? DeckColors.volt : DeckColors.hairline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: DeckColors.surfaceHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _initials(rower.displayName),
                          style: const TextStyle(
                            fontFamily: DeckType.ui,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: DeckColors.text,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: DeckColors.bg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            seatHint,
                            style: DeckType.labelMono(
                              color: DeckColors.text,
                              size: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rower.displayName,
                          style: const TextStyle(
                            fontFamily: DeckType.ui,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: DeckColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: DeckColors.surfaceHighest,
                                borderRadius: DeckRadii.chipAll,
                              ),
                              child: Text(
                                catChip,
                                style: DeckType.labelMono(
                                  color: DeckColors.label,
                                  size: 10,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  clubName != null
                                      ? Icons.kayaking
                                      : Icons.smartphone,
                                  size: 14,
                                  color: DeckColors.label,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    clubLine,
                                    style: const TextStyle(
                                      fontFamily: DeckType.ui,
                                      fontSize: 12,
                                      color: DeckColors.label,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Supprimer le profil',
                    onPressed: onDelete,
                  ),
                ],
              ),
              if (primary) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: onOpen,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Ouvrir Aujourd'hui"),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ),
              ] else
                const Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.chevron_right,
                    color: DeckColors.label,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
