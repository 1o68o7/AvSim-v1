import '../identity/models.dart';
import '../identity/store.dart';
import 'cloud_map.dart';
import 'identity_cloud.dart';
import 'lww.dart';
import 'outbox.dart';

class SyncStatus {
  const SyncStatus({
    this.lastSyncAt,
    this.online = false,
    this.pending = 0,
    this.error,
  });

  final DateTime? lastSyncAt;
  final bool online;
  final int pending;
  final String? error;

  String get chip {
    if (!online) return 'hors-ligne';
    if (error != null) return 'sync erreur';
    if (pending > 0) return 'sync $pending';
    if (lastSyncAt == null) return 'sync —';
    return 'sync OK';
  }
}

class SyncEngine {
  SyncEngine({
    required this.store,
    required this.outbox,
    required this.cloud,
  });

  final IdentityStore store;
  final SyncOutbox outbox;
  final IdentityCloud cloud;

  DateTime lastSyncAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  String? lastError;

  Future<void> push() async {
    if (!cloud.enabled) return;
    final pending = await outbox.peek();
    final kept = <OutboxOp>[];
    for (final op in pending) {
      try {
        if (op.op == 'delete') {
          await cloud.delete(op.table, op.id);
        } else {
          await cloud.upsert(op.table, op.payload);
        }
      } catch (e) {
        lastError = '$e';
        kept.add(op);
      }
    }
    await outbox.replace(kept);
  }

  Future<void> pull() async {
    if (!cloud.enabled) return;
    await _pullClubs();
    await _pullRowers();
    await _pullBoats();
    await _pullAssignments();
    lastSyncAt = DateTime.now().toUtc();
    lastError = null;
  }

  Future<void> tick() async {
    await push();
    await pull();
  }

  Future<SyncStatus> status({required bool online}) async {
    final pending = await outbox.peek();
    return SyncStatus(
      lastSyncAt: lastSyncAt.millisecondsSinceEpoch == 0 ? null : lastSyncAt,
      online: online,
      pending: pending.length,
      error: lastError,
    );
  }

  Future<void> _pullClubs() async {
    final remote = await cloud.pull('clubs', lastSyncAt);
    final local = await store.listClubs();
    for (final row in remote) {
      final r = clubFromCloud(row);
      Club? cur;
      for (final c in local) {
        if (c.id == r.id) cur = c;
      }
      if (cur == null || remoteWins(cur.updatedAt, r.updatedAt)) {
        await store.upsertClub(r, enqueue: false);
      }
    }
  }

  Future<void> _pullRowers() async {
    final remote = await cloud.pull('rowers', lastSyncAt);
    final local = await store.listRowers();
    for (final row in remote) {
      final r = rowerFromCloud(row);
      Rower? cur;
      for (final x in local) {
        if (x.id == r.id) cur = x;
      }
      if (cur == null || remoteWins(cur.updatedAt, r.updatedAt)) {
        await store.upsertRower(r, enqueue: false);
      }
    }
  }

  Future<void> _pullBoats() async {
    final remote = await cloud.pull('boats', lastSyncAt);
    final local = await store.listBoats();
    for (final row in remote) {
      final r = boatFromCloud(row);
      ParkBoat? cur;
      for (final x in local) {
        if (x.id == r.id) cur = x;
      }
      if (cur == null || remoteWins(cur.updatedAt, r.updatedAt)) {
        await store.upsertBoat(r, enqueue: false);
      }
    }
  }

  Future<void> _pullAssignments() async {
    final remote = await cloud.pull('assignments', lastSyncAt);
    final local = await store.listAssignments();
    for (final row in remote) {
      final r = assignmentFromCloud(row);
      Assignment? cur;
      for (final x in local) {
        if (x.id == r.id) cur = x;
      }
      if (cur == null || remoteWins(cur.updatedAt, r.updatedAt)) {
        await store.upsertAssignment(r, enqueue: false);
      }
    }
  }
}
