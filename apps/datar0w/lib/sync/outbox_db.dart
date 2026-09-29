import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

void _ensureSqliteLib() {
  open.overrideFor(OperatingSystem.linux, () {
    for (final n in [
      'libsqlite3.so.0',
      'libsqlite3.so',
      '/lib/x86_64-linux-gnu/libsqlite3.so.0',
    ]) {
      try {
        return DynamicLibrary.open(n);
      } catch (_) {}
    }
    return DynamicLibrary.open('libsqlite3.so.0');
  });
}

class OutboxRow {
  const OutboxRow({
    required this.syncId,
    required this.path,
    this.attempts = 0,
    this.nextRetryAt,
    this.lastError,
    this.sha256,
    this.uploadOffset = 0,
    this.acked = false,
    this.ackedAt,
    this.localDeletedAt,
  });

  final String syncId;
  final String path;
  final int attempts;
  final DateTime? nextRetryAt;
  final String? lastError;
  final String? sha256;
  final int uploadOffset;
  final bool acked;
  final DateTime? ackedAt;
  final DateTime? localDeletedAt;

  OutboxRow copyWith({
    int? attempts,
    DateTime? nextRetryAt,
    String? lastError,
    String? sha256,
    int? uploadOffset,
    bool? acked,
    DateTime? ackedAt,
    DateTime? localDeletedAt,
  }) =>
      OutboxRow(
        syncId: syncId,
        path: path,
        attempts: attempts ?? this.attempts,
        nextRetryAt: nextRetryAt ?? this.nextRetryAt,
        lastError: lastError ?? this.lastError,
        sha256: sha256 ?? this.sha256,
        uploadOffset: uploadOffset ?? this.uploadOffset,
        acked: acked ?? this.acked,
        ackedAt: ackedAt ?? this.ackedAt,
        localDeletedAt: localDeletedAt ?? this.localDeletedAt,
      );
}

/// Backoff 1 → 5 → 15 → 60 min (plafond 60).
Duration outboxBackoff(int attempts) {
  const mins = [1, 5, 15, 60];
  final i = attempts <= 1 ? 0 : (attempts - 1).clamp(0, mins.length - 1);
  return Duration(minutes: mins[i]);
}

class OutboxDb {
  OutboxDb(this._db);

  final Database _db;

  factory OutboxDb.memory() {
    _ensureSqliteLib();
    final db = sqlite3.openInMemory();
    _migrate(db);
    return OutboxDb(db);
  }

  factory OutboxDb.openFile(File file) {
    _ensureSqliteLib();
    file.parent.createSync(recursive: true);
    final db = sqlite3.open(file.path);
    _migrate(db);
    return OutboxDb(db);
  }

  static void _migrate(Database db) {
    db.execute('''
      create table if not exists session_outbox (
        sync_id text primary key,
        path text not null unique,
        attempts integer not null default 0,
        next_retry_at text,
        last_error text,
        sha256 text,
        upload_offset integer not null default 0,
        acked integer not null default 0,
        acked_at text,
        local_deleted_at text
      );
    ''');
  }

  void dispose() => _db.dispose();

  OutboxRow? bySyncId(String id) {
    final r = _db.select(
      'select * from session_outbox where sync_id = ?',
      [id],
    );
    if (r.isEmpty) return null;
    return _row(r.first);
  }

  OutboxRow? byPath(String path) {
    final r = _db.select(
      'select * from session_outbox where path = ?',
      [path],
    );
    if (r.isEmpty) return null;
    return _row(r.first);
  }

  List<OutboxRow> all() {
    final r = _db.select('select * from session_outbox order by sync_id');
    return [for (final e in r) _row(e)];
  }

  List<OutboxRow> due(DateTime now) {
    final iso = now.toUtc().toIso8601String();
    final r = _db.select(
      '''
      select * from session_outbox
      where acked = 0
        and (next_retry_at is null or next_retry_at <= ?)
      order by sync_id
      ''',
      [iso],
    );
    return [for (final e in r) _row(e)];
  }

  int bannerCount() {
    final r = _db.select(
      'select count(*) as n from session_outbox where acked = 0 and attempts >= 3',
    );
    return (r.first['n'] as int?) ?? 0;
  }

  /// Insert. Même path / sync_id → no-op, retourne la ligne existante.
  OutboxRow insertIdempotent(OutboxRow row) {
    final byId = bySyncId(row.syncId);
    if (byId != null) return byId;
    final byP = byPath(row.path);
    if (byP != null) return byP;
    _db.execute(
      '''
      insert into session_outbox (
        sync_id, path, attempts, next_retry_at, last_error, sha256,
        upload_offset, acked, acked_at, local_deleted_at
      ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        row.syncId,
        row.path,
        row.attempts,
        row.nextRetryAt?.toUtc().toIso8601String(),
        row.lastError,
        row.sha256,
        row.uploadOffset,
        row.acked ? 1 : 0,
        row.ackedAt?.toUtc().toIso8601String(),
        row.localDeletedAt?.toUtc().toIso8601String(),
      ],
    );
    return row;
  }

  void save(OutboxRow row) {
    _db.execute(
      '''
      update session_outbox set
        attempts = ?, next_retry_at = ?, last_error = ?, sha256 = ?,
        upload_offset = ?, acked = ?, acked_at = ?, local_deleted_at = ?
      where sync_id = ?
      ''',
      [
        row.attempts,
        row.nextRetryAt?.toUtc().toIso8601String(),
        row.lastError,
        row.sha256,
        row.uploadOffset,
        row.acked ? 1 : 0,
        row.ackedAt?.toUtc().toIso8601String(),
        row.localDeletedAt?.toUtc().toIso8601String(),
        row.syncId,
      ],
    );
  }

  static OutboxRow _row(Row e) => OutboxRow(
        syncId: e['sync_id'] as String,
        path: e['path'] as String,
        attempts: e['attempts'] as int,
        nextRetryAt: _dt(e['next_retry_at'] as String?),
        lastError: e['last_error'] as String?,
        sha256: e['sha256'] as String?,
        uploadOffset: e['upload_offset'] as int,
        acked: (e['acked'] as int) == 1,
        ackedAt: _dt(e['acked_at'] as String?),
        localDeletedAt: _dt(e['local_deleted_at'] as String?),
      );

  static DateTime? _dt(String? s) =>
      s == null || s.isEmpty ? null : DateTime.tryParse(s);
}
