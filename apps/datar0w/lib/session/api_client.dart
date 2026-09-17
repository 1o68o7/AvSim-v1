import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'model.dart';

class CreatedPhoneSession {
  const CreatedPhoneSession({required this.id, required this.code});

  final String id;
  final String code;
}

class RemoteLive {
  const RemoteLive({
    required this.id,
    required this.code,
    this.sample,
    this.meta = const {},
  });

  final String id;
  final String code;
  final SessionSample? sample;
  final Map<String, dynamic> meta;
}

/// Client optionnel. `DATAROW_API_BASE` vide → no-op (fichier local inchangé).
class SessionApi {
  SessionApi({http.Client? client, this.baseOverride})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String? baseOverride;

  static const _timeout = Duration(seconds: 2);

  static String? get base {
    const dart = String.fromEnvironment('DATAROW_API_BASE');
    if (dart.isNotEmpty) return dart;
    return Platform.environment['DATAROW_API_BASE'];
  }

  static bool get enabled => (base ?? '').isNotEmpty;

  bool get active {
    final b = baseOverride ?? base;
    return b != null && b.isNotEmpty;
  }

  String? get _resolved => baseOverride ?? base;

  Uri _u(String path) =>
      Uri.parse('${_resolved!.replaceAll(RegExp(r'/$'), '')}$path');

  Future<CreatedPhoneSession?> createSession({
    required String id,
    required String code,
    Map<String, dynamic>? meta,
  }) async {
    if (!active) return null;
    try {
      final r = await _client
          .post(
            _u('/datarow/sessions'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'id': id,
              'code': code,
              'meta': ?meta,
            }),
          )
          .timeout(_timeout);
      if (r.statusCode < 200 || r.statusCode >= 300) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return CreatedPhoneSession(
        id: j['id'] as String? ?? id,
        code: j['code'] as String? ?? code,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> tick({required String id, required SessionSample sample}) async {
    if (!active) return;
    try {
      await _client
          .post(
            _u('/datarow/sessions/$id/tick'),
            headers: {'content-type': 'application/json'},
            body: sample.toJsonLine(),
          )
          .timeout(_timeout);
    } catch (_) {}
  }

  Future<CreatedPhoneSession?> lookupByCode(String code) async {
    if (!active) return null;
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return null;
    try {
      final r = await _client
          .get(_u('/datarow/sessions/by-code/$c'))
          .timeout(_timeout);
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final id = j['id'] as String?;
      final rc = j['code'] as String?;
      if (id == null || rc == null) return null;
      return CreatedPhoneSession(id: id, code: rc);
    } catch (_) {
      return null;
    }
  }

  Future<RemoteLive?> fetchLive(String id) async {
    if (!active) return null;
    try {
      final r = await _client
          .get(_u('/datarow/sessions/$id/live'))
          .timeout(_timeout);
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final sampleRaw = j['sample'];
      SessionSample? sample;
      if (sampleRaw is Map) {
        sample = SessionSample.fromJson(Map<String, dynamic>.from(sampleRaw));
      }
      return RemoteLive(
        id: j['id'] as String? ?? id,
        code: j['code'] as String? ?? '',
        sample: sample,
        meta: (j['meta'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> note({
    required String id,
    required Map<String, dynamic> note,
  }) async {
    if (!active) return;
    try {
      await _client
          .post(
            _u('/datarow/sessions/$id/notes'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(note),
          )
          .timeout(_timeout);
    } catch (_) {}
  }
}
