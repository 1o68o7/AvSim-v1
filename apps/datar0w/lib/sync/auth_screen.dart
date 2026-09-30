import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../identity/controller.dart';
import '../onboarding/routing.dart';
import '../router.dart';
import '../theme/deck_theme.dart';
import '../widgets/deck_scaffold.dart';
import '../widgets/sign_out_button.dart';
import 'auth_google.dart';
import 'auth_session.dart';
import 'config.dart';
import 'supabase_boot.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  String? _msg;
  bool _busy = false;
  bool _emailOpen = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  AuthGoogle get _auth => ref.read(authGoogleProvider);

  String? get _uid =>
      _auth.sessionUserId ?? supabaseOrNull()?.auth.currentUser?.id as String?;

  String? get _emailLabel {
    try {
      final e = supabaseOrNull()?.auth.currentUser?.email;
      return e is String && e.isNotEmpty ? e : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _goPostLogin() async {
    final uid = _uid;
    if (uid != null) {
      await ref.read(identityProvider.notifier).hydrateFromCloud(uid);
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
      if (!SyncConfig.enabled) {
        setState(() => _msg = 'Pas de clés cloud. Mode local inchangé.');
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
            ? 'Connexion Google lancée. Reviens via le lien datarow://'
            : 'Google indisponible. Essaie par email.';
      });
    } catch (e) {
      setState(() => _msg = 'Google indisponible. $e');
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
      if (!SyncConfig.enabled) {
        setState(() => _msg = 'Pas de clés cloud. Mode local inchangé.');
        return;
      }
      await _auth.signInWithMagicLink(mail, door: OnboardingDoor.rower);
      setState(() => _msg = 'Lien envoyé. Ouvre le mail sur ce téléphone.');
    } catch (e) {
      setState(() => _msg = 'Envoi impossible. $e');
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
    return DeckScaffold(
      title: 'CONNEXION',
      subtitle: SyncConfig.enabled ? 'Google · email en secours' : 'mode local',
      retourFallback: AppRoutes.identity,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (!SyncConfig.enabled)
            const Text(
              'Pas de clés cloud. Mode local inchangé. Rien n’est envoyé.',
              style: TextStyle(color: DeckColors.muted, height: 1.4),
            ),
          const SizedBox(height: 12),
          if (uid == null) ...[
            FilledButton(
              onPressed: _busy ? null : _google,
              child: const Text('CONTINUER AVEC GOOGLE'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() => _emailOpen = true),
              child: const Text('par email'),
            ),
            if (_emailOpen) ...[
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy ? null : _magic,
                child: const Text('ENVOYER LE LIEN'),
              ),
            ],
          ] else ...[
            Text(
              email == null
                  ? 'Connecté'
                  : 'Connecté — $email',
              style: const TextStyle(
                color: DeckColors.tribord,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _goPostLogin,
              child: const Text('CONTINUER'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Rattache un profil local :',
              style: TextStyle(color: DeckColors.label, fontSize: 12),
            ),
            for (final r in snap.rowers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r.displayName),
                subtitle: Text(r.userId == uid ? 'rattaché' : 'local'),
                onTap: () => _link(r.id),
              ),
            const SignOutButton(),
          ],
          if (_msg != null) ...[
            const SizedBox(height: 16),
            Text(_msg!, style: const TextStyle(color: DeckColors.amber)),
          ],
        ],
      ),
    );
  }
}
