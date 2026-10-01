import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../identity/controller.dart';
import '../router.dart';
import '../theme/deck_theme.dart';
import '../widgets/deck_scaffold.dart';
import 'auth_google.dart';
import 'auth_session.dart';

/// Absorbe `/auth/callback` et `datarow://auth/callback` (query + fragment).
class AuthCallbackScreen extends ConsumerStatefulWidget {
  const AuthCallbackScreen({super.key, required this.uri});

  final Uri uri;

  @override
  ConsumerState<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends ConsumerState<AuthCallbackScreen> {
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handle());
  }

  Map<String, String> _params(Uri uri) {
    final out = <String, String>{...uri.queryParameters};
    final frag = uri.fragment;
    if (frag.isNotEmpty) {
      out.addAll(Uri.splitQueryString(frag));
    }
    return out;
  }

  String _friendlyError(Map<String, String> params) {
    final code = (params['error'] ?? params['error_code'] ?? '').trim();
    var desc = (params['error_description'] ?? '').trim();
    if (desc.isNotEmpty) {
      try {
        desc = Uri.decodeComponent(desc.replaceAll('+', ' '));
      } catch (_) {}
    }
    final lower = '$code $desc'.toLowerCase();
    if (lower.contains('access_denied')) {
      return 'Connexion Google refusée ou annulée.';
    }
    if (lower.contains('otp') || lower.contains('expired')) {
      return 'Lien expiré. Renvoie un lien depuis Connexion.';
    }
    if (code.isNotEmpty && desc.isNotEmpty) return '$desc ($code)';
    if (desc.isNotEmpty) return desc;
    if (code.isNotEmpty) return 'Connexion impossible ($code).';
    return 'Connexion impossible.';
  }

  Future<void> _handle() async {
    final params = _params(widget.uri);
    final errKey = params['error'] ?? params['error_code'];
    if (errKey != null && errKey.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(params);
        _busy = false;
      });
      return;
    }

    final auth = ref.read(authGoogleProvider);
    final ok = await auth.handleDeepLink(widget.uri);
    if (!mounted) return;
    if (!ok || auth.sessionUserId == null) {
      setState(() {
        _error = 'Lien invalide ou expiré.';
        _busy = false;
      });
      return;
    }
    final uid = auth.sessionUserId;
    if (uid != null) {
      await ref.read(identityProvider.notifier).hydrateFromCloud(uid);
      await ref.read(identityProvider.notifier).ensureActiveClubFromMembership();
    }
    if (!mounted) return;
    final dest = destinationAfterAuth(
      door: auth.lastDoor,
      snap: ref.read(identityProvider),
      sessionUserId: uid,
    );
    context.go(dest);
  }

  @override
  Widget build(BuildContext context) {
    return DeckScaffold(
      title: 'CONNEXION',
      subtitle: 'retour auth',
      showRetour: false,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _busy
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _error ?? 'Connexion impossible.',
                    style: const TextStyle(
                      color: DeckColors.volt,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go(AppRoutes.auth),
                    child: const Text('RETOUR CONNEXION'),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.identity),
                    child: const Text('Accueil'),
                  ),
                ],
              ),
      ),
    );
  }
}
