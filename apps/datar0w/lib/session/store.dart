import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'model.dart';

class SessionStore {
  SessionStore(this.id);

  final String id;
  IOSink? _sink;
  Directory? directory;

  Future<Directory> open() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/sessions/$id');
    await dir.create(recursive: true);
    directory = dir;
    final meta = File('${dir.path}/meta.json');
    await meta.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'id': id,
        'classe': '1x',
        'tare_offset': null,
        'started_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    _sink = File('${dir.path}/samples.jsonl').openWrite(mode: FileMode.append);
    return dir;
  }

  void append(SessionSample sample) {
    _sink?.writeln(sample.toJsonLine());
  }

  Future<void> close() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }
}
