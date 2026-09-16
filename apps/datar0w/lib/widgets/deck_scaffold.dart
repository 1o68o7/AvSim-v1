import 'package:flutter/material.dart';

import '../theme/deck_theme.dart';

class DeckScaffold extends StatelessWidget {
  const DeckScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.landscapeHint = false,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final bool landscapeHint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DeckColors.bg,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 10,
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
