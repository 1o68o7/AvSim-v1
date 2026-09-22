import 'dart:io';

import 'package:datar0w/session/share_files.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('datar0w_share_');
    await File('${dir.path}/samples.jsonl').writeAsString('{"t":1}\n');
    await File('${dir.path}/meta.json').writeAsString('{"id":"x"}');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('share samples + meta, imu si < 20 Mio', () async {
    await File('${dir.path}/imu.jsonl').writeAsString('{"t":1}\n');
    final files = sessionShareFiles(dir);
    expect(files.map((f) => f.uri.pathSegments.last).toList(), [
      'samples.jsonl',
      'meta.json',
      'imu.jsonl',
    ]);
  });

  test('imu trop gros exclu', () async {
    final imu = File('${dir.path}/imu.jsonl');
    final raf = imu.openSync(mode: FileMode.write);
    raf.truncateSync(kImuShareMaxBytes);
    raf.closeSync();
    final files = sessionShareFiles(dir);
    expect(files.map((f) => f.uri.pathSegments.last), isNot(contains('imu.jsonl')));
    expect(files.length, 2);
  });
}
