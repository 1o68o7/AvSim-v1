import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/deck_theme.dart';
import 'deck_widgets.dart';

class DeckScaffold extends StatelessWidget {
  const DeckScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.landscapeHint = false,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final bool landscapeHint;
  /// Optionnel — ne pas poser sur le live paysage.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DeckColors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: leading == null ? 0 : 128,
        leading: leading,
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

class DeckBackToProfile extends StatelessWidget {
  const DeckBackToProfile({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () => context.go(AppRoutes.profile),
      child: Text(
        'Retour profil',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: compact ? 10 : 12),
      ),
    );
  }
}
