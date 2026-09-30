import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../sync/auth_google.dart';
import '../sync/supabase_boot.dart';

/// Visible seulement si une session auth est posée. Pas de wipe local.
class SignOutButton extends ConsumerWidget {
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authGoogleProvider);
    final uid = auth.sessionUserId ?? supabaseOrNull()?.auth.currentUser?.id;
    if (uid == null) return const SizedBox.shrink();
    return TextButton(
      onPressed: () async {
        await auth.signOut();
        if (context.mounted) context.go(AppRoutes.identity);
      },
      child: const Text('Se déconnecter'),
    );
  }
}
