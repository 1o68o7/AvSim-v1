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

  Future<void> _handle() async {
    final params = _params(widget.uri);
    final err = params['error'] ??
        params['error_code'] ??
        params['error_description'];
    if (err != null && err.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _error = err;
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
    final expired = (_error ?? '').toLowerCase().contains('otp') ||
        (_error ?? '').toLowerCase().contains('expired') ||
        (_error ?? '').toLowerCase().contains('access_denied');
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
                    expired
                        ? 'Lien expiré ou refusé ($_error).'
                        : 'Connexion impossible ($_error).',
                    style: const TextStyle(
                      color: DeckColors.amber,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go(AppRoutes.auth),
                    child: const Text('RENVOYER UN LIEN'),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.identity),
                    child: const Text('Retour'),
                  ),
                ],
              ),
      ),
    );
  }
}
