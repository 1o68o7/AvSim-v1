/// Secrets uniquement via `--dart-define`. Jamais `service_role`.
abstract final class SyncConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const redirect = 'datarow://auth/callback';

  static bool get enabled => url.isNotEmpty && anonKey.isNotEmpty;
}
