import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../router.dart';
import '../theme/deck_theme.dart';

import 'session_pack.dart';
import 'store.dart';
import '../sync/outbox_db.dart';
import '../sync/sync_identity.dart';

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
    this.resolveOwnerUserId,
    this.resolveClubId,
    this.ensureClub,
  });

  static TelemetryGateway Function() resolveGateway =
      () => const SilentTelemetryGateway();

  final OutboxDb db;
  TelemetryGateway gateway;
  DateTime Function()? now;

  /// Injecté en tests. Prod : [defaultOwnerUserId].
  final String? Function()? resolveOwnerUserId;

  /// Injecté en tests. Prod : [defaultActiveClubId].
  final String? Function()? resolveClubId;

  /// Injecté en tests. Prod : [ensureActiveClubForSync].
  final Future<String?> Function()? ensureClub;

  DateTime _now() => now?.call() ?? DateTime.now().toUtc();

  String? _ownerUserId() =>
      resolveOwnerUserId?.call() ?? defaultOwnerUserId();

  String? _clubId() => resolveClubId?.call() ?? defaultActiveClubId();

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

  bool get hasAuthAndClub {
    final uid = _ownerUserId();
    final club = _clubId();
    return uid != null &&
        uid.isNotEmpty &&
        club != null &&
        club.isNotEmpty;
  }

  /// Chaque dossier `sessions/{CODE}` non ACK → [enqueueAfterStop].
  /// Conserve le sync_id existant (idempotent par path).
  Future<int> enqueueExistingLocalSessions({Directory? root}) async {
    final base = root ?? await SessionStore.sessionsRootIfPresent();
    if (base == null || !base.existsSync()) return 0;
    var n = 0;
    await for (final entity in base.list()) {
      if (entity is! Directory) continue;
      final code = p.basename(entity.path);
      if (code.isEmpty || code.startsWith('.')) continue;
      final metaFile = File(p.join(entity.path, 'meta.json'));
      if (!metaFile.existsSync()) continue;
      final existing = db.byPath(entity.path);
      if (existing != null && existing.acked) continue;
      await enqueueAfterStop(code, dir: entity);
      n++;
    }
    return n;
  }

  Future<void> drain({bool enqueueExisting = true}) async {
    if (enqueueExisting && hasAuthAndClub) {
      try {
        await enqueueExistingLocalSessions();
      } catch (e) {
        debugPrint('enqueueExistingLocalSessions: $e');
      }
    }
    final due = db.due(_now());
    for (final row in due) {
      await _push(row, manual: false);
    }
    await applyLocalRetentionFifo();
  }

  Future<String?> _ensureClub() async {
    if (ensureClub != null) return ensureClub!();
    return ensureActiveClubForSync(resolveOwnerUserId: resolveOwnerUserId);
  }

  /// Tap « renvoyer » : ensure club (membership) → enqueue + push **toutes**
  /// les rows non-ACK (attempts 0…N).
  Future<void> retryManual() async {
    try {
      await _ensureClub();
    } catch (e) {
      debugPrint('retryManual ensureActiveClub: $e');
    }
    try {
      await enqueueExistingLocalSessions();
    } catch (e) {
      debugPrint('retryManual enqueueExistingLocalSessions: $e');
    }
    if (!hasAuthAndClub) {
      final uid = _ownerUserId();
      final err = (uid == null || uid.isEmpty) ? 'pas d\'uid' : 'pas de club';
      for (final row in db.all()) {
        if (row.acked) continue;
        // Pas de fake ACK — bandeau / outbox restent.
        db.save(row.copyWith(lastError: err));
      }
      return;
    }
    for (final row in db.all()) {
      if (row.acked) continue;
      await _push(row, manual: true);
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
  const SessionSyncHost({
    super.key,
    required this.child,
    this.sync,
    this.ensureClub,
  });

  final Widget child;
  final SessionSync? sync;

  /// Injecté en tests. Prod : [ensureActiveClubForSync].
  final Future<String?> Function()? ensureClub;

  @override
  State<SessionSyncHost> createState() => _SessionSyncHostState();
}

class _SessionSyncHostState extends State<SessionSyncHost>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _net;
  SessionSync? _sync;
  String? _bannerStatus;
  Timer? _statusTimer;
  /// CTA « Choisir un club » si uid ok mais aucun membership / prefs.
  bool _offerClubCta = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  Future<String?> _ensureClub() async {
    if (widget.ensureClub != null) return widget.ensureClub!();
    if (_sync?.ensureClub != null) return _sync!.ensureClub!();
    return ensureActiveClubForSync();
  }

  Future<void> _ensureClubAndDrain() async {
    try {
      await _ensureClub();
    } catch (e) {
      debugPrint('SessionSyncHost ensureClub: $e');
    }
    await _sync?.drain(enqueueExisting: true);
  }

  Future<void> _boot() async {
    try {
      _sync = widget.sync ?? await SessionSync.openLocal();
      await _ensureClubAndDrain();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('SessionSyncHost boot: $e');
    }
    try {
      _net = Connectivity().onConnectivityChanged.listen((_) {
        unawaited(_ensureClubAndDrain());
      });
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_ensureClubAndDrain());
    }
  }

  Future<void> _onBannerRetry() async {
    final sync = _sync;
    if (sync == null) return;
    final ackedBefore =
        sync.db.all().where((r) => r.acked).map((r) => r.syncId).toSet();
    try {
      await _ensureClub();
      if (sync.hasAuthAndClub) {
        if (mounted) setState(() => _offerClubCta = false);
        await sync.enqueueExistingLocalSessions();
        await sync.drain(enqueueExisting: true);
        await sync.retryManual();
      } else {
        await sync.retryManual();
      }
    } catch (e) {
      debugPrint('SessionSyncHost retry: $e');
    }
    if (!mounted) return;
    final newly = sync.db
        .all()
        .where((r) => r.acked && !ackedBefore.contains(r.syncId))
        .toList();
    final codes = [for (final r in newly) p.basename(r.path)];
    String? err;
    for (final r in sync.db.all()) {
      if (!r.acked && r.lastError != null && r.lastError!.isNotEmpty) {
        err = _shortSyncError(r.lastError!);
        break;
      }
    }
    _statusTimer?.cancel();
    if (err == 'pas de club') {
      // CTA persistante — pas seulement le texte 2 s.
      setState(() {
        _offerClubCta = true;
        _bannerStatus = 'pas de club — Choisir un club';
      });
      return;
    }
    final String status;
    if (codes.length == 1) {
      status = 'sync: ok ${codes.single}';
    } else if (codes.length > 1) {
      status = 'sync: ok ${codes.length}';
    } else if (err != null) {
      status = 'sync: $err';
    } else {
      status = 'sync: nack';
    }
    setState(() {
      _offerClubCta = false;
      _bannerStatus = status;
    });
    _statusTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _bannerStatus = null);
    });
  }

  /// Pas de pavé PostgREST dans le bandeau.
  static String _shortSyncError(String raw) {
    if (raw == 'pas de club' || raw == 'pas d\'uid') return raw;
    if (raw.contains('23505') ||
        raw.contains('session_meta_pkey') ||
        raw.contains('déjà')) {
      return 'déjà synchro';
    }
    if (raw.startsWith('pas de ')) return raw;
    if (raw.startsWith('storage:')) return 'storage';
    if (raw.contains('session_meta')) return 'session_meta';
    if (raw.length > 32) return raw.substring(0, 32);
    return raw;
  }

  void _onBannerTap() {
    if (_offerClubCta) {
      appRouter.go(AppRoutes.clubJoin);
      return;
    }
    if (_bannerStatus != null) return;
    unawaited(_onBannerRetry());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_net?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = _sync?.unsyncedBannerCount ?? 0;
    final status = _bannerStatus;
    final showBanner = n > 0 || status != null || _offerClubCta;
    final label = _offerClubCta
        ? (status ?? 'pas de club — Choisir un club')
        : (status ??
            (n == 1
                ? '1 séance non synchronisée — renvoyer'
                : '$n séances non synchronisées — renvoyer'));
    final banner = !showBanner
        ? null
        : Material(
            color: DeckColors.amber,
            child: SafeArea(
              bottom: false,
              child: InkWell(
                onTap: () => _onBannerTap(),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    label,
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
    // Toujours le même arbre (Stack) : basculer child↔Stack remontait
    // MaterialApp.router et recollait GoRouter sur initialLocation=/identity.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (banner != null)
          Positioned(top: 0, left: 0, right: 0, child: banner),
      ],
    );
  }
}

