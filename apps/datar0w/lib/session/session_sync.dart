import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../theme/deck_theme.dart';

import 'session_pack.dart';
import 'store.dart';
import '../sync/outbox_db.dart';

const kLocalRetentionFifo = 30;
const kSoftDeleteDays = 30;

class UploadResult {
  const UploadResult({
    required this.ok,
    this.acked = false,
    this.nextOffset = 0,
    this.error,
  });

  final bool ok;
  final bool acked;
  final int nextOffset;
  final String? error;
}

abstract class TelemetryGateway {
  Future<UploadResult> uploadAndUpsert({
    required OutboxRow row,
    required SessionPack pack,
    required Map<String, dynamic> meta,
  });
}

/// Pas d’ACK → pas de purge. Fail-soft (log + retry).
class SilentTelemetryGateway implements TelemetryGateway {
  const SilentTelemetryGateway();

  @override
  Future<UploadResult> uploadAndUpsert({
    required OutboxRow row,
    required SessionPack pack,
    required Map<String, dynamic> meta,
  }) async =>
      const UploadResult(ok: false, error: 'sync off');
}

String newSyncId() {
  final b = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
      '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}

class SessionSync {
  SessionSync({
    required this.db,
    this.gateway = const SilentTelemetryGateway(),
    this.now,
  });

  static TelemetryGateway Function() resolveGateway =
      () => const SilentTelemetryGateway();

  final OutboxDb db;
  TelemetryGateway gateway;
  DateTime Function()? now;

  DateTime _now() => now?.call() ?? DateTime.now().toUtc();

  static SessionSync? _shared;

  static Future<SessionSync> instance() async {
    if (_shared != null) return _shared!;
    try {
      return await openLocal();
    } catch (_) {
      return _shared ??= SessionSync(db: OutboxDb.memory());
    }
  }

  static SessionSync shared() {
    return _shared ??= SessionSync(db: OutboxDb.memory());
  }

  @visibleForTesting
  static void debugReplace(SessionSync? s) => _shared = s;

  static Future<SessionSync> openLocal() async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File(p.join(docs.path, 'datar0w', 'session_outbox.sqlite'));
    final sync = SessionSync(
      db: OutboxDb.openFile(file),
      gateway: resolveGateway(),
    );
    _shared = sync;
    return sync;
  }

  /// Après STOP. N’écrit rien dans `sessions/` (pack en lecture).
  Future<OutboxRow> enqueueAfterStop(String sessionId, {Directory? dir}) async {
    Directory sessionDir;
    if (dir != null) {
      sessionDir = dir;
    } else {
      final root = await SessionStore.sessionsRootIfPresent();
      if (root == null) {
        throw StateError('pas de sessions/');
      }
      sessionDir = Directory(p.join(root.path, sessionId));
    }
    final existing = db.byPath(sessionDir.path);
    if (existing != null) return existing;
    final pack = packSessionDir(sessionDir);
    final row = OutboxRow(
      syncId: newSyncId(),
      path: sessionDir.path,
      sha256: pack.sha256hex,
    );
    return db.insertIdempotent(row);
  }

  /// Re-push du même sync_id : no-op si déjà en file / ACK.
  Future<OutboxRow?> enqueueSame(String syncId) async {
    return db.bySyncId(syncId);
  }

  Future<void> drain() async {
    final due = db.due(_now());
    for (final row in due) {
      await _push(row, manual: false);
    }
    await applyLocalRetentionFifo();
  }

  Future<void> retryManual() async {
    for (final row in db.all()) {
      if (row.acked) continue;
      if (row.attempts >= 3) {
        await _push(row, manual: true);
      }
    }
  }

  int get unsyncedBannerCount => db.bannerCount();

  Future<void> _push(OutboxRow row, {required bool manual}) async {
    final dir = Directory(row.path);
    if (!dir.existsSync()) {
      db.save(row.copyWith(
        attempts: row.attempts + 1,
        lastError: 'dir missing',
        nextRetryAt: _now().add(outboxBackoff(row.attempts + 1)),
      ));
      return;
    }
    final pack = packSessionDir(dir);
    Map<String, dynamic> meta = {};
    final metaFile = File(p.join(dir.path, 'meta.json'));
    if (metaFile.existsSync()) {
      try {
        final raw = jsonDecode(metaFile.readAsStringSync());
        if (raw is Map) meta = Map<String, dynamic>.from(raw);
      } catch (_) {}
    }
    try {
      final res = await gateway.uploadAndUpsert(
        row: row.copyWith(sha256: pack.sha256hex, uploadOffset: row.uploadOffset),
        pack: pack,
        meta: meta,
      );
      if (res.acked) {
        db.save(row.copyWith(
          acked: true,
          ackedAt: _now(),
          sha256: pack.sha256hex,
          lastError: null,
          uploadOffset: 0,
        ));
        return;
      }
      if (res.ok && res.nextOffset > 0 && !res.acked) {
        db.save(row.copyWith(
          sha256: pack.sha256hex,
          uploadOffset: res.nextOffset,
          lastError: res.error,
        ));
        return;
      }
      final attempts = row.attempts + 1;
      db.save(row.copyWith(
        attempts: attempts,
        lastError: res.error ?? 'nack',
        sha256: pack.sha256hex,
        nextRetryAt: manual ? _now() : _now().add(outboxBackoff(attempts)),
      ));
    } catch (e) {
      final attempts = row.attempts + 1;
      db.save(row.copyWith(
        attempts: attempts,
        lastError: '$e',
        nextRetryAt: _now().add(outboxBackoff(attempts)),
      ));
    }
  }

  /// FIFO 30 séances ACK : soft-delete local (horodatage), **pas** d’unlink.
  Future<void> applyLocalRetentionFifo() async {
    final acked = db.all().where((r) => r.acked && r.localDeletedAt == null).toList()
      ..sort((a, b) => (a.ackedAt ?? DateTime(0)).compareTo(b.ackedAt ?? DateTime(0)));
    if (acked.length <= kLocalRetentionFifo) return;
    final extra = acked.length - kLocalRetentionFifo;
    for (var i = 0; i < extra; i++) {
      db.save(acked[i].copyWith(localDeletedAt: _now()));
    }
  }

  /// Jamais d’unlink, même après [kSoftDeleteDays].
  static bool mayUnlinkLocal(OutboxRow row, DateTime now) {
    if (row.localDeletedAt == null) return false;
    final _ = now.difference(row.localDeletedAt!);
    return false;
  }
}

class SessionSyncHost extends StatefulWidget {
  const SessionSyncHost({super.key, required this.child, this.sync});

  final Widget child;
  final SessionSync? sync;

  @override
  State<SessionSyncHost> createState() => _SessionSyncHostState();
}

class _SessionSyncHostState extends State<SessionSyncHost>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _net;
  SessionSync? _sync;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  Future<void> _boot() async {
    try {
      _sync = widget.sync ?? await SessionSync.openLocal();
      await _sync!.drain();
      if (mounted) setState(() {});
    } catch (_) {}
    try {
      _net = Connectivity().onConnectivityChanged.listen((_) {
        unawaited(_sync?.drain());
      });
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_sync?.drain());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_net?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = _sync?.unsyncedBannerCount ?? 0;
    final banner = n <= 0
        ? null
        : Material(
            color: DeckColors.amber,
            child: SafeArea(
              bottom: false,
              child: InkWell(
                onTap: () async {
                  await _sync?.retryManual();
                  if (mounted) setState(() {});
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    n == 1
                        ? '1 séance non synchronisée — renvoyer'
                        : '$n séances non synchronisées — renvoyer',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: DeckColors.onAlert,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          );
    if (banner == null) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned(top: 0, left: 0, right: 0, child: banner),
      ],
    );
  }
}
