import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../sync/auth_google.dart';
import '../sync/supabase_boot.dart';
import '../theme/deck_theme.dart';

/// Visible seulement si une session auth est posée. Pas de wipe JSONL.
class SignOutButton extends ConsumerWidget {
  const SignOutButton({
    super.key,
    this.outlined = false,
    this.label = 'Se déconnecter',
    this.confirm = true,
  });

  final bool outlined;
  final String label;
  /// ST-10 : dialogue Annuler / Déconnecter.
  final bool confirm;

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authGoogleProvider);
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: DeckColors.surface,
          title: const Text('Déconnexion'),
          content: const Text(
            'Tes séances restent sur ce téléphone.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Déconnecter'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await auth.signOut();
    if (context.mounted) context.go(AppRoutes.identity);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authGoogleProvider);
    final uid = auth.sessionUserId ?? supabaseOrNull()?.auth.currentUser?.id;
    if (uid == null) return const SizedBox.shrink();
    if (outlined) {
      return OutlinedButton(
        onPressed: () => _run(context, ref),
        style: OutlinedButton.styleFrom(
          foregroundColor: DeckColors.error,
          side: const BorderSide(color: DeckColors.error),
        ),
        child: Text(label),
      );
    }
    return TextButton(
      onPressed: () => _run(context, ref),
      child: Text(label),
    );
  }
}
