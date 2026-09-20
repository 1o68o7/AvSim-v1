import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';

/// Init no-op si dart-define absents (mode local).
Future<void> bootSupabase() async {
  if (!SyncConfig.enabled) return;
  try {
    await Supabase.initialize(
      url: SyncConfig.url,
      publishableKey: SyncConfig.anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  } catch (_) {
    // Pas de crash : l’app reste en local.
  }
}

dynamic supabaseOrNull() {
  if (!SyncConfig.enabled) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}
