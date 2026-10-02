import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../identity/models.dart';
import '../../router.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_shell.dart';
import '../../widgets/sign_out_button.dart';

/// Onglet Plus (shell DR) — réglages, club, objets, santé, rôles.
class PlusScreen extends ConsumerWidget {
  const PlusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(identityProvider);
    final rower = snap.activeRower;
    final club = snap.activeClub;
    final isCoach = snap.prefs.clubRole == ClubMemberRole.coach;

    return DeckTabScaffold(
      tab: DeckTab.plus,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              'Plus',
              style: TextStyle(
                fontFamily: DeckType.ui,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: DeckColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              rower?.displayName ?? 'Sans profil actif',
              style: const TextStyle(
                fontFamily: DeckType.ui,
                color: DeckColors.label,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            _PlusTile(
              icon: Icons.person_outline,
              title: 'Profil local',
              subtitle: rower?.displayName ?? 'Créer ou choisir un profil',
              onTap: () => context.go(
                rower == null
                    ? AppRoutes.identity
                    : '${AppRoutes.identityEdit}?id=${Uri.encodeQueryComponent(rower.id)}',
              ),
            ),
            _PlusTile(
              icon: Icons.settings_outlined,
              title: 'Réglages',
              subtitle: 'Compte cloud · téléphone',
              onTap: () => context.go(AppRoutes.settings),
            ),
            _PlusTile(
              icon: Icons.groups_outlined,
              title: club == null ? 'Rejoindre un club' : 'Mon club',
              subtitle: club?.name ?? 'Code club ou invitation',
              onTap: () => context.go(
                club == null ? AppRoutes.clubJoin : AppRoutes.club,
              ),
            ),
            _PlusTile(
              icon: Icons.sensors,
              title: 'Mes objets',
              subtitle: 'Capteurs BLE · journal technique',
              onTap: () => context.go(AppRoutes.devices),
            ),
            _PlusTile(
              icon: Icons.terminal,
              title: 'Journal BLE',
              subtitle: 'Diagnostics bas-niveau',
              onTap: () => context.go(AppRoutes.bleJournal),
            ),
            _PlusTile(
              icon: Icons.favorite_border,
              title: 'Données santé',
              subtitle: 'Consentement et constantes',
              onTap: () => context.go(AppRoutes.consent),
            ),
            _PlusTile(
              icon: Icons.monitor_heart_outlined,
              title: 'Mes constantes',
              subtitle: 'Physio locale',
              onTap: () => context.go(AppRoutes.physio),
            ),
            _PlusTile(
              icon: Icons.straighten,
              title: 'Spinoscope',
              subtitle: 'Mesure poste',
              onTap: () => context.go(AppRoutes.spinoscope),
            ),
            _PlusTile(
              icon: Icons.swap_horiz,
              title: 'Rôle bateau',
              subtitle: 'Rameur / coach / barreur',
              onTap: () => context.go(AppRoutes.profile),
            ),
            if (!isCoach)
              _PlusTile(
                icon: Icons.rowing,
                title: 'Je barre aussi',
                subtitle: 'Accueil barreur',
                onTap: () async {
                  await ref.read(identityProvider.notifier).becomeCox();
                  if (context.mounted) context.go(AppRoutes.homeCox);
                },
              ),
            if (isCoach)
              _PlusTile(
                icon: Icons.person,
                title: 'Profil rameur',
                subtitle: 'Tu rames aussi ?',
                onTap: () => context.go(AppRoutes.homeRower),
              ),
            _PlusTile(
              icon: Icons.badge_outlined,
              title: 'Changer de profil',
              subtitle: 'Qui est là ?',
              onTap: () => context.go(AppRoutes.identity),
            ),
            const SizedBox(height: 16),
            const SignOutButton(outlined: true),
          ],
        ),
      ),
    );
  }
}

class _PlusTile extends StatelessWidget {
  const _PlusTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: DeckColors.surface,
        borderRadius: DeckRadii.cardAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: DeckRadii.cardAll,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: DeckRadii.cardAll,
              border: Border.all(color: DeckColors.hairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: DeckColors.surfaceHighest,
                    borderRadius: DeckRadii.buttonAll,
                  ),
                  child: Icon(icon, color: DeckColors.text, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: DeckType.ui,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: DeckColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: DeckType.ui,
                          fontSize: 12,
                          color: DeckColors.label,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: DeckColors.label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
