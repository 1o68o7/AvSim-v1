import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'model.dart';

class SessionMeta {
  const SessionMeta({
    required this.id,
    this.classe = '1x',
    this.bassin,
    this.tareOffset,
    this.code,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String classe;
  final String? bassin;
  final double? tareOffset;
  final String? code;
  final String? startedAt;
  final String? endedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'classe': classe,
        'bassin': bassin,
        'tareOffsetDeg': tareOffset,
        'tare_offset': tareOffset,
        'code': code,
        'started_at': startedAt,
        'ended_at': endedAt,
      };

  static SessionMeta fromJson(Map<String, dynamic> j) => SessionMeta(
        id: j['id'] as String,
        classe: j['classe'] as String? ?? '1x',
        bassin: j['bassin'] as String?,
        tareOffset: (j['tareOffsetDeg'] as num?)?.toDouble() ??
            (j['tare_offset'] as num?)?.toDouble(),
        code: j['code'] as String?,
        startedAt: j['started_at'] as String?,
        endedAt: j['ended_at'] as String?,
      );
}

class SessionStore {
  SessionStore(this.id);

  final String id;
  IOSink? _sink;
  IOSink? _imuSink;
  Directory? directory;
  SessionMeta? meta;

  static Future<Directory> sessionsRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/sessions');
    await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> open({
    required double tareOffset,
    String? code,
    String? bassin,
  }) async {
    final root = await sessionsRoot();
    final dir = Directory('${root.path}/$id');
    await dir.create(recursive: true);
    directory = dir;
    meta = SessionMeta(
      id: id,
      tareOffset: tareOffset,
      code: code,
      bassin: bassin,
      startedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _writeMeta();
    _sink = File('${dir.path}/samples.jsonl').openWrite(mode: FileMode.append);
    _imuSink = File('${dir.path}/imu.jsonl').openWrite(mode: FileMode.append);
    return dir;
  }

  Future<void> appendNote(Map<String, dynamic> note) async {
    final dir = directory;
    if (dir == null) return;
    final f = File('${dir.path}/notes.json');
    var list = <dynamic>[];
    if (f.existsSync()) {
      final raw = jsonDecode(await f.readAsString());
      if (raw is List) list = List<dynamic>.from(raw);
    }
    list.add(note);
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(list));
  }

  Future<void> _writeMeta() async {
    final dir = directory;
    final m = meta;
    if (dir == null || m == null) return;
    await File('${dir.path}/meta.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(m.toJson()),
    );
  }

  Future<void> markEnded() async {
    final m = meta;
    if (m == null) return;
    meta = SessionMeta(
      id: m.id,
      classe: m.classe,
      bassin: m.bassin,
      tareOffset: m.tareOffset,
      code: m.code,
      startedAt: m.startedAt,
      endedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _writeMeta();
  }

  void append(SessionSample sample) {
    _sink?.writeln(sample.toJsonLine());
  }

  void appendImuLine(String jsonLine) {
    _imuSink?.writeln(jsonLine);
  }

  Future<void> close() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    await _imuSink?.flush();
    await _imuSink?.close();
    _imuSink = null;
  }

  static Future<List<SessionSample>> loadSamples(String sessionId) async {
    final root = await sessionsRoot();
    final file = File('${root.path}/$sessionId/samples.jsonl');
    if (!file.existsSync()) return [];
    final lines = await file.readAsLines();
    final out = <SessionSample>[];
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      out.add(SessionSample.fromJson(
        jsonDecode(t) as Map<String, dynamic>,
      ));
    }
    return out;
  }

  static Future<void> appendNoteToId(
    String sessionId,
    Map<String, dynamic> note,
  ) async {
    final root = await sessionsRoot();
    final store = SessionStore(sessionId);
    store.directory = Directory('${root.path}/$sessionId');
    if (!store.directory!.existsSync()) return;
    await store.appendNote(note);
  }

  static Future<List<SessionNote>> loadNotes(String sessionId) async {
    final root = await sessionsRoot();
    final file = File('${root.path}/$sessionId/notes.json');
    if (!file.existsSync()) return [];
    final raw = jsonDecode(await file.readAsString());
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => SessionNote.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<SessionMeta?> loadMeta(String sessionId) async {
    final root = await sessionsRoot();
    final file = File('${root.path}/$sessionId/meta.json');
    if (!file.existsSync()) return null;
    return SessionMeta.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  static Future<String?> findIdByCode(String code) async {
    final root = await sessionsRoot();
    if (!root.existsSync()) return null;
    final needle = code.trim().toUpperCase();
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final metaFile = File('${entity.path}/meta.json');
      if (!metaFile.existsSync()) continue;
      final meta = SessionMeta.fromJson(
        jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>,
      );
      if (meta.code?.toUpperCase() == needle) return meta.id;
    }
    return null;
  }

  static Future<String?> latestId() async {
    final root = await sessionsRoot();
    if (!root.existsSync()) return null;
    final dirs = root
        .listSync()
        .whereType<Directory>()
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return dirs.isEmpty ? null : p.basename(dirs.first.path);
  }
}
