import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../identity/controller.dart';
import '../identity/models.dart';
import '../onboarding/routing.dart';
import '../router.dart';
import '../theme/deck_theme.dart';
import '../widgets/deck_widgets.dart';
import '../widgets/sign_out_button.dart';
import 'auth_google.dart';
import 'auth_session.dart';
import 'config.dart';
import 'supabase_boot.dart';

/// DR-10 — Connexion (session ON / OFF).
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  String? _msg;
  bool _busy = false;
  bool _linkOpen = false;
  /// Formulaire magic link replié (DR-10 / auth_google).
  bool _emailOpen = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  AuthGoogle get _auth => ref.read(authGoogleProvider);

  String? get _uid =>
      _auth.sessionUserId ?? supabaseOrNull()?.auth.currentUser?.id;

  String? get _emailLabel {
    final e = supabaseOrNull()?.auth.currentUser?.email;
    return (e != null && e.isNotEmpty) ? e : null;
  }

  void _snackCloudUnavailable() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Cloud indisponible')),
      );
    setState(() => _msg = 'Cloud indisponible');
  }

  Future<void> _goPostLogin() async {
    final uid = _uid;
    if (uid != null) {
      await ref.read(identityProvider.notifier).hydrateFromCloud(uid);
      await ref.read(identityProvider.notifier).ensureActiveClubFromMembership();
    }
    if (!mounted) return;
    final dest = destinationAfterAuth(
      door: OnboardingDoor.rower,
      snap: ref.read(identityProvider),
      sessionUserId: uid,
    );
    context.go(dest);
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      if (supabaseOrNull() == null) {
        _snackCloudUnavailable();
        return;
      }
      final ok = await _auth.signInWithGoogle(door: OnboardingDoor.rower);
      if (!mounted) return;
      if (_auth.sessionUserId != null) {
        await _goPostLogin();
        return;
      }
      setState(() {
        _msg = ok
            ? 'Connexion Google lancée. Reviens via datarow://auth/callback'
            : 'Google indisponible. Essaie par email.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _msg = 'Google indisponible.');
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Cloud indisponible')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _magic() async {
    final mail = _email.text.trim();
    if (mail.isEmpty) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      if (supabaseOrNull() == null) {
        _snackCloudUnavailable();
        return;
      }
      await _auth.signInWithMagicLink(mail, door: OnboardingDoor.rower);
      setState(() => _msg = 'Lien envoyé. Ouvre le mail sur ce téléphone.');
    } catch (e) {
      setState(() => _msg = 'Envoi impossible.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _link(String rowerId) async {
    final uid = _uid;
    if (uid == null) return;
    final rower = ref.read(identityProvider).rowerById(rowerId);
    if (rower == null) return;
    await ref.read(identityProvider.notifier).saveRower(
          rower.copyWith(userId: uid, updatedAt: DateTime.now().toUtc()),
        );
    setState(() => _msg = 'Profil rattaché au compte.');
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(identityProvider);
    final uid = _uid;
    final email = _emailLabel;
    final sessionOn = uid != null;

    return Scaffold(
      backgroundColor: DeckColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => context.go(AppRoutes.identity),
                icon: const Icon(Icons.close, color: DeckColors.text),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: const [
                DeckHonestChip(kind: DeckHonestKind.club, label: 'SESSION CLUB'),
                DeckHonestChip(kind: DeckHonestKind.local, label: 'LOCAL SYNC'),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'DATAR0W // TELEMETRY DECK',
              style: DeckType.labelMono(color: DeckColors.volt, size: 11),
            ),
            const SizedBox(height: 8),
            const Text(
              'CONNEXION',
              style: TextStyle(
                fontFamily: DeckType.ui,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.64,
                color: DeckColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sessionOn
                  ? 'Compte cloud actif — synchronise sorties et équipages.'
                  : 'Associez votre compte pour synchroniser vos sorties, bateaux, '
                      'capteurs et équipages sur tous vos appareils.',
              style: const TextStyle(
                fontFamily: DeckType.ui,
                fontSize: 14,
                height: 1.45,
                color: DeckColors.label,
              ),
            ),
            const SizedBox(height: 24),
            if (!SyncConfig.enabled && !sessionOn) ...[
              const Text(
                'mode local',
                style: TextStyle(
                  fontFamily: DeckType.ui,
                  color: DeckColors.volt,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Pas de clés cloud. Tout reste sur cet appareil.',
                  style: TextStyle(color: DeckColors.muted, height: 1.4),
                ),
              ),
            ],
            if (sessionOn)
              _SessionOnBody(
                email: email,
                busy: _busy,
                linkOpen: _linkOpen,
                rowers: snap.rowers,
                uid: uid,
                onContinue: _busy ? null : _goPostLogin,
                onToggleLink: () => setState(() => _linkOpen = !_linkOpen),
                onLinkRower: _link,
              )
            else
              _SessionOffBody(
                email: _email,
                busy: _busy,
                emailOpen: _emailOpen,
                onGoogle: _busy ? null : _google,
                onToggleEmail: () => setState(() => _emailOpen = !_emailOpen),
                onMagic: _busy ? null : _magic,
              ),
            if (_msg != null) ...[
              const SizedBox(height: 16),
              Text(_msg!, style: const TextStyle(color: DeckColors.volt)),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DeckColors.surface,
                borderRadius: DeckRadii.cardAll,
                border: Border.all(color: DeckColors.hairline),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MODE HORS-LIGNE & LOCAL FIRST',
                    style: TextStyle(
                      fontFamily: DeckType.ui,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.4,
                      color: DeckColors.volt,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Pas de connexion au ponton ? DataR0w fonctionne en local. '
                    'Télémétrie et séances restent sur ce téléphone.',
                    style: TextStyle(
                      fontFamily: DeckType.ui,
                      fontSize: 13,
                      height: 1.4,
                      color: DeckColors.label,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ST-01 — session ouverte.
class _SessionOnBody extends StatelessWidget {
  const _SessionOnBody({
    required this.email,
    required this.busy,
    required this.linkOpen,
    required this.rowers,
    required this.uid,
    required this.onContinue,
    required this.onToggleLink,
    required this.onLinkRower,
  });

  final String? email;
  final bool busy;
  final bool linkOpen;
  final List<Rower> rowers;
  final String uid;
  final VoidCallback? onContinue;
  final VoidCallback onToggleLink;
  final Future<void> Function(String rowerId) onLinkRower;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: DeckRadii.cardAll,
            border: Border.all(color: DeckColors.tribord.withValues(alpha: 0.45)),
            color: DeckColors.tribord.withValues(alpha: 0.08),
          ),
          child: Text(
            email == null ? 'Connecté' : 'Connecté en tant que $email',
            style: const TextStyle(
              color: DeckColors.tribord,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: onContinue,
            child: const Text('CONTINUER'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy ? null : onToggleLink,
          child: Text(
            linkOpen ? 'Masquer les profils' : 'Rattacher ce téléphone',
          ),
        ),
        if (linkOpen) ...[
          const SizedBox(height: 4),
          const Text(
            'Choisis un profil local à lier à ce compte :',
            style: TextStyle(color: DeckColors.label, fontSize: 12),
          ),
          for (final r in rowers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(r.displayName),
              subtitle: Text(r.userId == uid ? 'rattaché' : 'local'),
              onTap: busy ? null : () => onLinkRower(r.id),
            ),
        ],
        const SizedBox(height: 8),
        const SignOutButton(outlined: true, label: 'DÉCONNEXION'),
        const SizedBox(height: 12),
        const Text(
          'Tes séances restent sur ce téléphone.',
          style: TextStyle(color: DeckColors.muted, fontSize: 12, height: 1.35),
        ),
      ],
    );
  }
}

/// ST-02 — pas de session. Magic link derrière « par email ».
class _SessionOffBody extends StatelessWidget {
  const _SessionOffBody({
    required this.email,
    required this.busy,
    required this.emailOpen,
    required this.onGoogle,
    required this.onToggleEmail,
    required this.onMagic,
  });

  final TextEditingController email;
  final bool busy;
  final bool emailOpen;
  final VoidCallback? onGoogle;
  final VoidCallback onToggleEmail;
  final VoidCallback? onMagic;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: onGoogle,
            icon: const Icon(Icons.g_mobiledata, size: 28),
            label: const Text('CONTINUER AVEC GOOGLE'),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'OU PAR EMAIL SÉCURISÉ',
          textAlign: TextAlign.center,
          style: DeckType.labelMono(color: DeckColors.label, size: 10),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: busy ? null : onToggleEmail,
          child: const Text('par email'),
        ),
        if (emailOpen) ...[
          const SizedBox(height: 12),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Adresse email adhérent / athlète',
              hintText: 'toi@club.fr',
              prefixIcon: Icon(Icons.alternate_email),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: onMagic,
              icon: const Icon(Icons.bolt),
              label: const Text('ENVOYER LE LIEN'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connexion instantanée en un clic depuis votre boîte de réception.',
            style: TextStyle(
              fontFamily: DeckType.ui,
              fontSize: 12,
              color: DeckColors.label,
              height: 1.35,
            ),
          ),
        ],
        if (kDebugMode) ...[
          const SizedBox(height: 28),
          TextButton(
            onPressed: busy ? null : () => context.go(AppRoutes.identity),
            child: const Text(
              'Continuer en mode invité local (Sans compte)',
              style: TextStyle(fontSize: 13, color: DeckColors.muted),
            ),
          ),
          // Ancre legacy tests debug.
          TextButton(
            onPressed: busy ? null : () => context.go(AppRoutes.identity),
            child: const Text(
              'Sans compte',
              style: TextStyle(fontSize: 12, color: DeckColors.muted),
            ),
          ),
        ],
      ],
    );
  }
}
