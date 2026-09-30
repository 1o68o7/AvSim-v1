import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../onboarding/routing.dart';
import 'config.dart';
import 'supabase_boot.dart';

/// Query `door` survivant à un cold start (le store local n'a pas la porte).
String redirectToFor(OnboardingDoor door) =>
    '${SyncConfig.redirect}?door=${door.name}';

/// Contrat mockable : Google OAuth + magic link + deep link unifié.
abstract class AuthBackend {
  Future<bool> startGoogle({required String redirectTo});
  Future<void> startMagicLink({
    required String email,
    required String redirectTo,
  });
  Future<bool> recoverSession(Uri uri);
  String? currentUserId();
}

class LiveAuthBackend implements AuthBackend {
  @override
  Future<bool> startGoogle({required String redirectTo}) async {
    final client = supabaseOrNull();
    if (client == null) return false;
    // Extension supabase_flutter sur GoTrueClient (nécessite client typé).
    return client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
  }

  @override
  Future<void> startMagicLink({
    required String email,
    required String redirectTo,
  }) async {
    final client = supabaseOrNull();
    if (client == null) {
      throw StateError('supabase disabled');
    }
    await client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: redirectTo,
    );
  }

  @override
  Future<bool> recoverSession(Uri uri) async {
    final client = supabaseOrNull();
    if (client == null) return false;
    try {
      await client.auth.getSessionFromUrl(uri);
    } catch (_) {
      // Session déjà posée par le SDK, ou lien invalide.
    }
    return currentUserId() != null;
  }

  @override
  String? currentUserId() => supabaseOrNull()?.auth.currentUser?.id;
}

bool isAuthCallback(Uri uri) =>
    uri.scheme == 'datarow' &&
    uri.host == 'auth' &&
    (uri.path == '/callback' || uri.path.startsWith('/callback'));

/// Google = chemin nominal. Magic link = fallback. Même redirect.
class AuthGoogle {
  AuthGoogle({AuthBackend? backend}) : backend = backend ?? LiveAuthBackend();

  final AuthBackend backend;

  /// `google` | `magic` | null
  String? lastMethod;
  String? sessionUserId;
  OnboardingDoor lastDoor = OnboardingDoor.rower;

  Future<bool> signInWithGoogle({
    OnboardingDoor door = OnboardingDoor.rower,
  }) async {
    lastDoor = door;
    lastMethod = 'google';
    final ok = await backend.startGoogle(redirectTo: redirectToFor(door));
    sessionUserId = backend.currentUserId();
    return ok || sessionUserId != null;
  }

  Future<bool> signInWithMagicLink(
    String email, {
    OnboardingDoor door = OnboardingDoor.rower,
  }) async {
    lastDoor = door;
    lastMethod = 'magic';
    await backend.startMagicLink(
      email: email.trim(),
      redirectTo: redirectToFor(door),
    );
    return true;
  }

  Future<bool> handleDeepLink(Uri uri) async {
    if (!isAuthCallback(uri) && uri.path != '/auth/callback') return false;
    final params = <String, String>{...uri.queryParameters};
    if (uri.fragment.isNotEmpty) {
      params.addAll(Uri.splitQueryString(uri.fragment));
    }
    if ((params['error'] ?? params['error_code'] ?? '').isNotEmpty) {
      return false;
    }
    final door = params['door'];
    if (door == 'club') lastDoor = OnboardingDoor.club;
    if (door == 'rower') lastDoor = OnboardingDoor.rower;
    final ok = await backend.recoverSession(uri);
    sessionUserId = backend.currentUserId();
    return ok;
  }

  /// Déconnexion cloud. Ne touche ni profils locaux ni SessionStore.
  Future<void> signOut() async {
    try {
      await supabaseOrNull()?.auth.signOut();
    } catch (_) {}
    sessionUserId = null;
    lastMethod = null;
  }
}

final authGoogleProvider = Provider<AuthGoogle>((ref) => AuthGoogle());
