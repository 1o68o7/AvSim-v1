import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../identity/controller.dart';
import '../router.dart';
import '../theme/deck_theme.dart';
import '../widgets/deck_scaffold.dart';
import 'auth_google.dart';
import 'config.dart';
import 'supabase_boot.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.clubDoor = false});

  /// Porte club (`/club/login`) : pas de « sans compte ».
  final bool clubDoor;

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
      final ok = await _auth.signInWithGoogle();
      setState(() {
        _msg = ok
            ? 'Connexion Google lancée.'
            : 'Google indisponible. Essaie par email.';
      });
    } catch (_) {
      setState(() => _msg = 'Google indisponible. Essaie par email.');
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
      await _auth.signInWithMagicLink(mail);
      setState(() => _msg = 'Lien envoyé. Ouvre le mail sur ce téléphone.');
    } catch (_) {
      setState(() => _msg = 'Envoi impossible. Mode local inchangé.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _link(String rowerId) async {
    final uid = _auth.sessionUserId ??
        supabaseOrNull()?.auth.currentUser?.id as String?;
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
    final uid = _auth.sessionUserId ?? supabaseOrNull()?.auth.currentUser?.id;
    return DeckScaffold(
      title: widget.clubDoor ? 'ESPACE CLUB' : 'CONNEXION',
      subtitle: widget.clubDoor
          ? 'Google obligatoire · email en secours'
          : (SyncConfig.enabled ? 'Google · email en secours' : 'mode local'),
      retourFallback: AppRoutes.identity,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (!SyncConfig.enabled)
            const Text(
              'Pas de clés cloud. « Passer (sans profil) » reste disponible. '
              'Rien n’est envoyé.',
              style: TextStyle(color: DeckColors.muted, height: 1.4),
            ),
          const SizedBox(height: 12),
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
          if (uid != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Connecté — rattache un profil local :',
              style: TextStyle(color: DeckColors.tribord, fontSize: 12),
            ),
            for (final r in snap.rowers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r.displayName),
                subtitle: Text(r.userId == uid ? 'rattaché' : 'local'),
                onTap: () => _link(r.id),
              ),
          ],
          if (_msg != null) ...[
            const SizedBox(height: 16),
            Text(_msg!, style: const TextStyle(color: DeckColors.amber)),
          ],
          if (!widget.clubDoor) ...[
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.go(AppRoutes.profile),
              child: const Text('Sans compte (loisir)'),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.clubLogin),
              child: const Text('Espace club'),
            ),
          ],
        ],
      ),
    );
  }
}
