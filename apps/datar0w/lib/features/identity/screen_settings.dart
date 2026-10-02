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
import '../../widgets/deck_widgets.dart';
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
      title: 'Réglages',
      subtitle: 'Compte · téléphone · capteurs',
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
            label: 'Mes objets',
            value: 'Sangle · patch · scan BLE',
            onTap: () => context.go(AppRoutes.devices),
          ),
          const Divider(height: 1, color: DeckColors.hairline),
          _SettingsTile(
            label: 'Journal technique BLE',
            value: 'Diagnostics bas-niveau locaux',
            onTap: () => context.go(AppRoutes.bleJournal),
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
            const SignOutButton(outlined: true, label: 'Déconnexion'),
          ] else ...[
            FilledButton(
              onPressed: () => context.go(AppRoutes.auth),
              child: const Text('Connexion'),
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
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: onTap != null,
      onTap: onTap,
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
          color: onTap != null ? DeckColors.label : DeckColors.muted,
        ),
      ),
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, color: DeckColors.label)
          : null,
      minVerticalPadding: 16,
    );
  }
}
