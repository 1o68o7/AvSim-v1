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

  @override
  Widget build(BuildContext context) {
    final Widget? lead = leading ??
        (showRetour
            ? DeckRetour(
                alwaysGo: retourToProfile ? AppRoutes.profile : null,
                fallback: retourFallback,
              )
            : null);
    return Scaffold(
      backgroundColor: DeckColors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: lead == null ? 0 : 128,
        leading: lead,
        toolbarHeight: subtitle != null ? 72 : 64,
        title: Column(
          children: [
            const DataR0wMark(compact: true),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: DeckColors.label,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 11,
                  color: DeckColors.label,
                  letterSpacing: 0.8,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, color: DeckColors.hairline),
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
