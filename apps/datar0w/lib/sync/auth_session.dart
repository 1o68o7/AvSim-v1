import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../identity/controller.dart';
import '../onboarding/routing.dart';
import '../router.dart';
import 'auth_google.dart';
import 'auth_links.dart';
import 'supabase_boot.dart';

/// Pas d'Accueil injecté sur live / cox / coach, même après un callback.
bool canRedirectAfterAuth(String path) =>
    path != AppRoutes.live &&
    path != AppRoutes.cox &&
    path != AppRoutes.coachLive;

OnboardingDoor doorFromPath(String path, OnboardingDoor fallback) {
  if (path == AppRoutes.clubLogin) return OnboardingDoor.club;
  if (path == AppRoutes.auth) return OnboardingDoor.rower;
  return fallback;
}

/// Rôle club seulement si un club actif est posé — le défaut `admin` du
/// store ne doit pas envoyer un rameur Google vers `/home/admin`.
String destinationAfterAuth({
  required OnboardingDoor door,
  required IdentitySnapshot snap,
  String? sessionUserId,
}) {
  final uid = sessionUserId;
  final linked =
      uid != null && snap.rowers.any((r) => r.userId == uid);
  final hasProfile = linked || snap.prefs.activeRowerId != null;
  final role =
      snap.prefs.activeClubId != null ? snap.prefs.clubRole.name : null;
  return resolvePostLogin(
    door: door,
    clubMemberRole: role,
    hasRowerProfile: hasProfile,
  );
}

String routerPath(GoRouter router) {
  final cfg = router.routerDelegate.currentConfiguration;
  if (cfg.isEmpty) return '';
  return cfg.uri.path;
}

/// Écoute `datarow://auth/callback` + session Supabase, puis `go` post-login.
class AuthSessionBinder extends ConsumerStatefulWidget {
  const AuthSessionBinder({
    super.key,
    required this.child,
    this.router,
  });

  final Widget child;
  final GoRouter? router;

  @override
  ConsumerState<AuthSessionBinder> createState() => _AuthSessionBinderState();
}

class _AuthSessionBinderState extends ConsumerState<AuthSessionBinder> {
  StreamSubscription<Uri>? _links;
  StreamSubscription<dynamic>? _auth;

  GoRouter get _router => widget.router ?? appRouter;

  @override
  void initState() {
    super.initState();
    final source = ref.read(authLinkSourceProvider);
    _links = source.links.listen((uri) => unawaited(_onLink(uri)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_consumeInitial(source));
    });
  }

  Future<void> _consumeInitial(AuthLinkSource source) async {
    if (!mounted) return;
    try {
      final initial = await source.initialLink();
      if (initial != null) await _onLink(initial);
    } catch (_) {}
    _listenAuth();
  }

  void _listenAuth() {
    final client = supabaseOrNull();
    if (client == null) return;
    try {
      _auth = client.auth.onAuthStateChange.listen((data) {
        final event = '${data.event}';
        if (!event.contains('signedIn') &&
            !event.contains('tokenRefreshed')) {
          return;
        }
        final auth = ref.read(authGoogleProvider);
        auth.sessionUserId = auth.backend.currentUserId();
        if (auth.sessionUserId != null) _goPostLogin();
      });
    } catch (_) {}
  }

  Future<void> _onLink(Uri uri) async {
    final auth = ref.read(authGoogleProvider);
    final ok = await auth.handleDeepLink(uri);
    if (!ok || !mounted) return;
    _goPostLogin();
  }

  void _goPostLogin() {
    final path = routerPath(_router);
    if (!canRedirectAfterAuth(path)) return;
    final auth = ref.read(authGoogleProvider);
    final door = doorFromPath(path, auth.lastDoor);
    final dest = destinationAfterAuth(
      door: door,
      snap: ref.read(identityProvider),
      sessionUserId: auth.sessionUserId,
    );
    _router.go(dest);
  }

  @override
  void dispose() {
    unawaited(_links?.cancel());
    unawaited(_auth?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
