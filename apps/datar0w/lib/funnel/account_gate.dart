import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../identity/controller.dart';
import '../onboarding/routing.dart';
import '../sync/auth_google.dart';
import '../sync/config.dart';
import '../sync/supabase_boot.dart';
import '../theme/deck_theme.dart';

/// Compte Google demandé à « Garder ce temps » / « Partager la fiche », pas à l’écran 0.
class AccountGate {
  AccountGate._();

  static String? sessionUserId(WidgetRef ref) {
    final auth = ref.read(authGoogleProvider);
    return auth.sessionUserId ?? supabaseOrNull()?.auth.currentUser?.id;
  }

  static bool isSignedIn(WidgetRef ref) {
    final uid = sessionUserId(ref);
    return uid != null && uid.isNotEmpty;
  }

  /// Affiche la feuille Google (+ magic link replié). Retourne true si session.
  static Future<bool> ensureSignedIn(
    BuildContext context,
    WidgetRef ref, {
    required String reason,
  }) async {
    if (isSignedIn(ref)) return true;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: DeckColors.surface,
      isScrollControlled: true,
      builder: (ctx) => _AccountSheet(reason: reason),
    );
    return ok == true && isSignedIn(ref);
  }

  /// Rattache auth.users.id → rowers.user_id (pas de second profil).
  static Future<void> attachActiveRower(WidgetRef ref) async {
    final uid = sessionUserId(ref);
    if (uid == null) return;
    final snap = ref.read(identityProvider);
    final rower = snap.activeRower;
    if (rower == null) return;
    if (rower.userId == uid) return;
    // Si un autre rameur local a déjà ce user_id → bascule actif, ne duplique pas.
    for (final r in snap.rowers) {
      if (r.userId == uid && r.id != rower.id) {
        await ref.read(identityProvider.notifier).selectRower(r.id);
        return;
      }
    }
    await ref.read(identityProvider.notifier).saveRower(
          rower.copyWith(userId: uid, updatedAt: DateTime.now().toUtc()),
        );
    await ref.read(identityProvider.notifier).linkRowerUserIdCloud(
          rowerId: rower.id,
          userId: uid,
        );
  }
}

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet({required this.reason});
  final String reason;

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _magicOpen = false;
  String? _msg;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      if (supabaseOrNull() == null && !SyncConfig.enabled) {
        setState(() => _msg = 'Cloud indisponible');
        return;
      }
      final ok = await ref
          .read(authGoogleProvider)
          .signInWithGoogle(door: OnboardingDoor.rower);
      final uid = AccountGate.sessionUserId(ref);
      if (uid != null) {
        await AccountGate.attachActiveRower(ref);
        if (mounted) Navigator.pop(context, true);
        return;
      }
      setState(() {
        _msg = ok
            ? 'Connexion Google lancée. Reviens via le lien.'
            : 'Google indisponible. Essaie par email.';
      });
    } catch (_) {
      setState(() => _msg = 'Google indisponible.');
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
      await ref
          .read(authGoogleProvider)
          .signInWithMagicLink(mail, door: OnboardingDoor.rower);
      setState(() => _msg = 'Lien envoyé. Ouvre le mail sur ce téléphone.');
    } catch (_) {
      setState(() => _msg = 'Envoi impossible.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.reason,
            style: const TextStyle(
              fontFamily: DeckType.ui,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: DeckColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Un compte pour rattacher ce profil. Pas de mot de passe.',
            style: DeckType.uiLabel(color: DeckColors.label),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton(
              key: const Key('account-gate-google'),
              onPressed: _busy ? null : _google,
              child: const Text('Continuer avec Google'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() => _magicOpen = !_magicOpen),
            child: Text(
              _magicOpen ? 'Masquer l’email' : 'Recevoir un lien par email',
              style: const TextStyle(color: DeckColors.muted),
            ),
          ),
          if (_magicOpen) ...[
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: DeckColors.text),
              decoration: const InputDecoration(
                hintText: 'email@exemple.fr',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _magic,
              child: const Text('Envoyer le lien'),
            ),
          ],
          if (_msg != null) ...[
            const SizedBox(height: 12),
            Text(_msg!, style: DeckType.uiLabel(color: DeckColors.amber)),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Plus tard',
              style: TextStyle(color: DeckColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
