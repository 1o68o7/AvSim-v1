import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'model.dart';

class SessionApi {
  SessionApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static String? get base {
    const dart = String.fromEnvironment('DATAROW_API_BASE');
    if (dart.isNotEmpty) return dart;
    return Platform.environment['DATAROW_API_BASE'];
  }

  static bool get enabled => (base ?? '').isNotEmpty;

  Uri _u(String path) => Uri.parse('${base!.replaceAll(RegExp(r'/$'), '')}$path');

  Future<void> createSession({
    required String id,
    required String code,
  }) async {
    if (!enabled) return;
    try {
      await _client.post(
        _u('/datarow/sessions'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'id': id, 'code': code}),
      );
    } catch (_) {}
  }

  Future<void> tick({required String id, required SessionSample sample}) async {
    if (!enabled) return;
    try {
      await _client.post(
        _u('/datarow/sessions/$id/tick'),
        headers: {'content-type': 'application/json'},
        body: sample.toJsonLine(),
      );
    } catch (_) {}
  }

  Future<void> note({
    required String id,
    required Map<String, dynamic> note,
  }) async {
    if (!enabled) return;
    try {
      await _client.post(
        _u('/datarow/sessions/$id/notes'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode(note),
      );
    } catch (_) {}
  }
}
