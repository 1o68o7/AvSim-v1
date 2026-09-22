import 'dart:io';

import 'package:datar0w/session/session_pack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('datar0w_pack_');
    await File('${dir.path}/meta.json').writeAsString('{"id":"s1"}');
    await File('${dir.path}/samples.jsonl').writeAsString('{"t":1}\n');
    await File('${dir.path}/imu.jsonl').writeAsString('{"t":2}\n');
    await File('${dir.path}/notes.json').writeAsString('[]');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('hash stable pour le même contenu', () {
    final a = packSessionDir(dir);
    final b = packSessionDir(dir);
    expect(a.sha256hex, b.sha256hex);
    expect(a.sha256hex.length, 64);
  });

  test('round-trip unzip', () async {
    final pack = packSessionDir(dir);
    final out = await Directory.systemTemp.createTemp('datar0w_unpack_');
    addTearDown(() => out.delete(recursive: true));
    unpackSessionBytes(pack.bytes, out);
    expect(File('${out.path}/meta.json').readAsStringSync(), '{"id":"s1"}');
    expect(File('${out.path}/samples.jsonl').readAsStringSync(), '{"t":1}\n');
    expect(File('${out.path}/imu.jsonl').existsSync(), isTrue);
    expect(File('${out.path}/notes.json').existsSync(), isTrue);
  });
}
