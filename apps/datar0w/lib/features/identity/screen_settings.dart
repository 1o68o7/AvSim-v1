import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../onboarding/routing.dart';
import '../../router.dart';
import '../../sync/auth_google.dart';
import '../../sync/supabase_boot.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import '../../widgets/sign_out_button.dart';

/// ST-10 — Réglages + déconnexion (tokens only, JSONL intacts).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String? _uid(WidgetRef ref) {
    final auth = ref.watch(authGoogleProvider);
    return auth.sessionUserId ?? supabaseOrNull()?.auth.currentUser?.id;
  }

  String? _email() {
    final e = supabaseOrNull()?.auth.currentUser?.email;
    return (e != null && e.isNotEmpty) ? e : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(identityProvider);
    final uid = _uid(ref);
    final email = _email();
    final rower = snap.activeRower;

    return DeckScaffold(
      title: 'RÉGLAGES',
      subtitle: 'compte · téléphone',
      retourFallback: homeRouteForClubMemberRole(snap.prefs.clubRole),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _SettingsTile(
            label: 'Profil local',
            value: rower?.displayName ?? 'Aucun profil actif',
            onTap: () => context.go(
              rower == null
                  ? AppRoutes.identity
                  : '${AppRoutes.identityEdit}?id=${Uri.encodeQueryComponent(rower.id)}',
            ),
          ),
          const Divider(height: 1, color: DeckColors.hairline),
          _SettingsTile(
            label: 'Compte cloud',
            value: uid == null
                ? 'Non connecté'
                : (email ?? 'Session active'),
            onTap: () => context.go(AppRoutes.auth),
          ),
          const Divider(height: 1, color: DeckColors.hairline),
          _SettingsTile(
            label: 'Capteurs',
            value: 'Bientôt',
            onTap: () => context.go(AppRoutes.devices),
          ),
          const Divider(height: 1, color: DeckColors.hairline),
          _SettingsTile(
            label: 'Données de santé',
            value: 'Consentement et constantes',
            onTap: () => context.go(AppRoutes.consent),
          ),
          const Divider(height: 1, color: DeckColors.hairline),
          const SizedBox(height: 24),
          if (uid != null) ...[
            const Text(
              'Déconnexion',
              style: TextStyle(
                color: DeckColors.label,
                fontSize: 12,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tes séances restent sur ce téléphone.',
              style: TextStyle(color: DeckColors.muted, height: 1.35),
            ),
            const SizedBox(height: 12),
            const SignOutButton(outlined: true, label: 'DÉCONNEXION'),
          ] else ...[
            FilledButton(
              onPressed: () => context.go(AppRoutes.auth),
              child: const Text('CONNEXION'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.label,
    required this.value,
    this.onTap,
    this.enabled = true,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: enabled && onTap != null,
      onTap: enabled ? onTap : null,
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          color: enabled ? DeckColors.label : DeckColors.muted,
        ),
      ),
      trailing: enabled && onTap != null
          ? const Icon(Icons.chevron_right, color: DeckColors.label)
          : null,
      minVerticalPadding: 16,
    );
  }
}
