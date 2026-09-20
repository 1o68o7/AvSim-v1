import 'identity_cloud.dart';
import 'supabase_boot.dart';

class SupabaseIdentityCloud implements IdentityCloud {
  @override
  bool get enabled => supabaseOrNull() != null;

  @override
  Future<void> upsert(String table, Map<String, dynamic> row) async {
    final c = supabaseOrNull();
    if (c == null) return;
    await c.from(table).upsert(row);
  }

  @override
  Future<void> delete(String table, String id) async {
    final c = supabaseOrNull();
    if (c == null) return;
    await c.from(table).delete().eq('id', id);
  }

  @override
  Future<List<Map<String, dynamic>>> pull(String table, DateTime since) async {
    final c = supabaseOrNull();
    if (c == null) return [];
    final data = await c
        .from(table)
        .select()
        .gt('updated_at', since.toUtc().toIso8601String());
    return (data as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
