import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'model.dart';

class SessionMeta {
  const SessionMeta({
    required this.id,
    this.classe = '1x',
    this.seats = 1,
    this.cox = false,
    this.role = 'rower',
    this.seatIndex = 1,
    this.coxPosition,
    this.bassin,
    this.tareOffset,
    this.tareQuality,
    this.tareDurationS,
    this.code,
    this.startedAt,
    this.endedAt,
    this.rowerId,
    this.clubId,
    this.boatId,
    this.assignmentId,
    this.side,
  });

  final String id;
  final String classe;
  final int seats;
  final bool cox;
  final String role;
  final int? seatIndex;
  final String? coxPosition;
  final String? bassin;
  final double? tareOffset;
  final String? tareQuality;
  final double? tareDurationS;
  final String? code;
  final String? startedAt;
  final String? endedAt;
  final String? rowerId;
  final String? clubId;
  final String? boatId;
  final String? assignmentId;
  final String? side;

  Map<String, dynamic> toJson() => {
        'id': id,
        'class': classe,
        'classe': classe,
        'seats': seats,
        'cox': cox,
        'role': role,
        'seatIndex': seatIndex,
        'coxPosition': coxPosition,
        'bassin': bassin,
        'tareOffsetDeg': tareOffset,
        'tare_offset': tareOffset,
        'tareQuality': tareQuality,
        'tareDurationS': tareDurationS,
        'code': code,
        'started_at': startedAt,
        'ended_at': endedAt,
        if (rowerId != null) 'rowerId': rowerId,
        if (clubId != null) 'clubId': clubId,
        if (boatId != null) 'boatId': boatId,
        if (assignmentId != null) 'assignmentId': assignmentId,
        if (side != null) 'side': side,
      };

  static SessionMeta fromJson(Map<String, dynamic> j) => SessionMeta(
        id: j['id'] as String,
        classe: (j['class'] as String?) ?? j['classe'] as String? ?? '1x',
        seats: (j['seats'] as num?)?.toInt() ?? 1,
        cox: j['cox'] as bool? ?? false,
        role: j['role'] as String? ?? 'rower',
        seatIndex: (j['seatIndex'] as num?)?.toInt() ??
            ((j['role'] as String?) == 'cox' ? null : 1),
        coxPosition: j['coxPosition'] as String?,
        bassin: j['bassin'] as String?,
        tareOffset: (j['tareOffsetDeg'] as num?)?.toDouble() ??
            (j['tare_offset'] as num?)?.toDouble(),
        tareQuality: j['tareQuality'] as String?,
        tareDurationS: (j['tareDurationS'] as num?)?.toDouble(),
        code: j['code'] as String?,
        startedAt: j['started_at'] as String?,
        endedAt: j['ended_at'] as String?,
        rowerId: j['rowerId'] as String?,
        clubId: j['clubId'] as String?,
        boatId: j['boatId'] as String?,
        assignmentId: j['assignmentId'] as String?,
        side: j['side'] as String?,
      );

  SessionMeta copyWith({String? endedAt}) {
    return SessionMeta(
      id: id,
      classe: classe,
      seats: seats,
      cox: cox,
      role: role,
      seatIndex: seatIndex,
      coxPosition: coxPosition,
      bassin: bassin,
      tareOffset: tareOffset,
      tareQuality: tareQuality,
      tareDurationS: tareDurationS,
      code: code,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      rowerId: rowerId,
      clubId: clubId,
      boatId: boatId,
      assignmentId: assignmentId,
      side: side,
    );
  }
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
    String? tareQuality,
    double? tareDurationS,
    String? code,
    String? bassin,
    String classe = '1x',
    int seats = 1,
    bool cox = false,
    String role = 'rower',
    int? seatIndex = 1,
    String? coxPosition,
    String? rowerId,
    String? clubId,
    String? boatId,
    String? assignmentId,
    String? side,
  }) async {
    final root = await sessionsRoot();
    final dir = Directory('${root.path}/$id');
    await dir.create(recursive: true);
    directory = dir;
    meta = SessionMeta(
      id: id,
      classe: classe,
      seats: seats,
      cox: cox,
      role: role,
      seatIndex: seatIndex,
      coxPosition: coxPosition,
      rowerId: rowerId,
      clubId: clubId,
      boatId: boatId,
      assignmentId: assignmentId,
      side: side,
      tareOffset: tareOffset,
      tareQuality: tareQuality,
      tareDurationS: tareDurationS,
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
    meta = m.copyWith(endedAt: DateTime.now().toUtc().toIso8601String());
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
