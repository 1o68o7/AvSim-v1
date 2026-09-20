import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../identity/controller.dart';
import 'cloud_map.dart';
import 'config.dart';
import 'identity_cloud.dart';
import 'supabase_boot.dart';
import 'supabase_cloud.dart';
import 'sync_engine.dart';

final identityCloudProvider = Provider<IdentityCloud>((ref) {
  if (!SyncConfig.enabled) return const NoopCloud();
  return SupabaseIdentityCloud();
});

class SyncHud extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => const SyncStatus();

  void setStatus(SyncStatus next) => state = next;
}

final syncHudProvider = NotifierProvider<SyncHud, SyncStatus>(SyncHud.new);

final assignmentsStreamProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String?>(
  (ref, clubId) {
    final client = supabaseOrNull();
    if (client == null || clubId == null || clubId.isEmpty) {
      return Stream.value(<Map<String, dynamic>>[]);
    }
    return client
        .from('assignments')
        .stream(primaryKey: const ['id'])
        .eq('club_id', clubId)
        .map(
          (rows) => rows
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
  },
);

Future<void> applyAssignmentRows(
  WidgetRef ref,
  List<Map<String, dynamic>> rows,
) async {
  final store = ref.read(identityStoreProvider);
  for (final row in rows) {
    await store.upsertAssignment(assignmentFromCloud(row), enqueue: false);
  }
  await ref.read(identityProvider.notifier).reload();
}

