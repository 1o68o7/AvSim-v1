import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';

/// Init no-op si dart-define absents (mode local I1–I5).
Future<void> bootSupabase() async {
  if (!SyncConfig.enabled) return;
  await Supabase.initialize(
    url: SyncConfig.url,
    publishableKey: SyncConfig.anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
}

SupabaseClient? supabaseOrNull() {
  if (!SyncConfig.enabled) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}
