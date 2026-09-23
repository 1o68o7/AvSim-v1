import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../session/boat_config.dart';
import '../theme/deck_theme.dart';
import 'deck_widgets.dart';

/// Hub d’accueil selon le rôle séance.
String deckRoleHub(CrewRole role) => switch (role) {
      CrewRole.rower => AppRoutes.homeRower,
      CrewRole.cox => AppRoutes.homeCox,
      CrewRole.coach => AppRoutes.homeCoach,
    };

/// Convention §2.4 : pop si possible, sinon hub rôle (ou [alwaysGo] / [fallback]).
void performDeckRetour(
  BuildContext context,
  WidgetRef ref, {
  String? alwaysGo,
  String? fallback,
}) {
  final router = GoRouter.maybeOf(context);
  if (alwaysGo != null) {
    if (router != null) {
      router.go(alwaysGo);
    }
    return;
  }
  if (router != null && router.canPop()) {
    router.pop();
    return;
  }
  final dest = fallback ?? deckRoleHub(ref.read(boatConfigProvider).role);
  if (router != null) {
    router.go(dest);
    return;
  }
  Navigator.maybeOf(context)?.maybePop();
}

/// Header Stitch Marine Avionics : `DATAR0W / TITRE` (pas de jargon STAGE/SYS).
/// Lot A : titres humains, pas de préfixe « DATAR0W / » dans le Text du titre.
class DeckAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DeckAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.centerBrandOnly = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  /// Écran profils Stitch : marque centrée seule (pas de slash-titre).
  final bool centerBrandOnly;

  static const double kToolbar = 56;

  @override
  Size get preferredSize => Size.fromHeight(
        (subtitle != null && !centerBrandOnly ? 64 : kToolbar) + 1,
      );

  @override
  Widget build(BuildContext context) {
    final height = subtitle != null && !centerBrandOnly ? 64.0 : kToolbar;
    final Widget titleRow;
    if (centerBrandOnly) {
      titleRow = const Center(child: DataR0wMark(compact: true));
    } else {
      titleRow = Row(
        children: [
          const DataR0wMark(compact: true),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '/',
              style: TextStyle(
                color: DeckColors.hairline,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: DeckColors.text,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: DeckColors.label,
                      letterSpacing: 0.8,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: DeckColors.bg,
      foregroundColor: DeckColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerBrandOnly,
      titleSpacing: 0,
      toolbarHeight: height,
      leadingWidth: leading == null ? 0 : 72,
      leading: leading == null
          ? null
          : Align(alignment: Alignment.centerLeft, child: leading),
      title: titleRow,
      actions: actions,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: DeckColors.hairline),
      ),
    );
  }
}

/// Bandeau paysage live/cox/coach : même `DATAR0W / TITRE`, sans Retour (GEL).
class DeckSessionHeader extends StatelessWidget {
  const DeckSessionHeader({
    super.key,
    required this.title,
    this.trailing = const [],
  });

  final String title;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const DataR0wMark(compact: true),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '/',
                    style: TextStyle(
                      color: DeckColors.hairline,
                      fontSize: 12,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: DeckColors.text,
                    ),
                  ),
                ),
                if (trailing.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ...trailing,
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: DeckColors.hairline),
      ],
    );
  }
}

class DeckScaffold extends StatelessWidget {
  const DeckScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.landscapeHint = false,
    this.leading,
    this.showRetour = true,
    this.retourToProfile = false,
    this.retourFallback,
    this.actions,
    this.centerBrandOnly = false,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final bool landscapeHint;
  /// Si non null, remplace le Retour automatique. Live / cox / coach : ne pas poser.
  final Widget? leading;
  /// Faux sur `/identity` et tare en cours.
  final bool showRetour;
  /// Gate « Réservé au coach » → toujours `/`.
  final bool retourToProfile;
  /// Si pas de pop : cette route plutôt que le hub rôle (homes → `/`).
  final String? retourFallback;
  final List<Widget>? actions;
  /// Profils Stitch : marque seule centrée.
  final bool centerBrandOnly;

  @override
  Widget build(BuildContext context) {
    final Widget? lead = leading ??
        (showRetour && !centerBrandOnly
            ? DeckRetour(
                alwaysGo: retourToProfile ? AppRoutes.profile : null,
                fallback: retourFallback,
              )
            : null);
    return Scaffold(
      backgroundColor: DeckColors.bg,
      appBar: DeckAppBar(
        title: title,
        subtitle: subtitle,
        leading: lead,
        actions: actions,
        centerBrandOnly: centerBrandOnly,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (landscapeHint)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Cale-pied · paysage 844×390 (lock après Démarrer, lot D)',
                style: TextStyle(color: DeckColors.label, fontSize: 11),
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class DeckRetour extends ConsumerWidget {
  const DeckRetour({
    super.key,
    this.compact = false,
    this.alwaysGo,
    this.fallback,
  });

  final bool compact;
  final String? alwaysGo;
  final String? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () => performDeckRetour(
        context,
        ref,
        alwaysGo: alwaysGo,
        fallback: fallback,
      ),
      child: Text(
        'Retour',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: compact ? 10 : 12),
      ),
    );
  }
}

/// @Deprecated alias — même convention que [DeckRetour] vers `/`.
class DeckBackToProfile extends StatelessWidget {
  const DeckBackToProfile({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DeckRetour(compact: compact, alwaysGo: AppRoutes.profile);
  }
}
