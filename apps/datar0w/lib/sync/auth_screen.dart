import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../identity/controller.dart';
import '../router.dart';
import '../theme/deck_theme.dart';
import '../widgets/deck_scaffold.dart';
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

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _magic() async {
    final client = supabaseOrNull();
    final mail = _email.text.trim();
    if (client == null || mail.isEmpty) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await client.auth.signInWithOtp(
        email: mail,
        emailRedirectTo: SyncConfig.redirect,
      );
      setState(() => _msg = 'Lien envoyé. Ouvre le mail sur ce téléphone.');
    } catch (_) {
      setState(() => _msg = 'Envoi impossible. Mode local inchangé.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _link(String rowerId) async {
    final uid = supabaseOrNull()?.auth.currentUser?.id as String?;
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
    final uid = supabaseOrNull()?.auth.currentUser?.id;
    return DeckScaffold(
      title: 'COMPTE CLUB',
      subtitle: SyncConfig.enabled ? 'lien e-mail · optionnel' : 'mode local',
      retourFallback: AppRoutes.identity,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (!SyncConfig.enabled)
            const Text(
              'Pas de clés cloud. « Passer (sans profil) » reste disponible. '
              'Rien n’est envoyé.',
              style: TextStyle(color: DeckColors.muted, height: 1.4),
            )
          else ...[
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _magic,
              child: const Text('ENVOYER LE LIEN'),
            ),
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
