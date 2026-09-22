import '../health/physio_store.dart';
import 'config.dart';
import 'supabase_boot.dart';

/// Sync direct `rower_physio`. Fail-soft. Pas d’outbox #50.
Future<void> syncRowerPhysio(PhysioRecord r) async {
  if (!SyncConfig.enabled) return;
  if (!r.consent) return;
  final client = supabaseOrNull();
  if (client == null) return;
  if (r.rowerId == null || r.clubId == null || r.userId == null) return;
  try {
    await client.from('rower_physio').upsert(
          r.toSql(),
          onConflict: 'rower_id',
        );
  } catch (_) {}
}
