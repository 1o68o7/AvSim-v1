import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import 'identity_cloud.dart';
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
