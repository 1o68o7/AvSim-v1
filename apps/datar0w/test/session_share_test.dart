import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:datar0w/session/share_files.dart';
import 'package:datar0w/session/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('datar0w_share_');
    await File('${dir.path}/samples.jsonl').writeAsString('{"t":1}\n');
    await File('${dir.path}/meta.json').writeAsString('{"id":"x","code":"GCZEKF"}');
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
    expect(files.every((f) => f.lengthSync() > 0), isTrue);
    expect(
      sessionShareDisplayNames(dir, 'GCZEKF'),
      contains('GCZEKF-samples.jsonl'),
    );
  });

  test('share unitaire non vide, noms lisibles', () async {
    final names = sessionShareDisplayNames(dir, 'GCZEKF');
    expect(names, isNotEmpty);
    expect(names, contains('GCZEKF-samples.jsonl'));
    expect(names, contains('GCZEKF-meta.json'));
    final copies = await copySessionShareNamed(dir, 'GCZEKF');
    expect(copies, isNotEmpty);
    expect(copies.first.name, 'GCZEKF-samples.jsonl');
    expect(File(copies.first.path).lengthSync(), greaterThan(0));
    expect(sessionShareCaption('GCZEKF'), contains('GCZEKF'));
    expect(sessionShareCaption('GCZEKF'), contains('samples.jsonl'));
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

  test('bulk 2 séances → zip contient 2 samples.jsonl', () async {
    final root = await Directory.systemTemp.createTemp('datar0w_bulk_root_');
    addTearDown(() => root.delete(recursive: true));
    Future<void> seed(String id, String code) async {
      final d = Directory('${root.path}/$id');
      await d.create(recursive: true);
      await File('${d.path}/samples.jsonl').writeAsString('{"id":"$id"}\n');
      await File('${d.path}/meta.json').writeAsString(
        jsonEncode({'id': id, 'code': code}),
      );
    }

    await seed('s1', 'GCZEKF');
    await seed('s2', 'AAAAAA');
    final listed = await SessionStore.listSessions(root: root);
    expect(listed, hasLength(2));

    final prep = zipSessionsShare([
      (dir: Directory('${root.path}/s1'), stem: 'GCZEKF'),
      (dir: Directory('${root.path}/s2'), stem: 'AAAAAA'),
    ]);
    expect(prep.tooHeavy, isFalse);
    expect(prep.bytes, isNotNull);
    final archive = ZipDecoder().decodeBytes(prep.bytes!);
    final names = archive.map((e) => e.name).toList();
    expect(names.where((n) => n.endsWith('-samples.jsonl')).length, 2);
    expect(names, contains('GCZEKF-samples.jsonl'));
    expect(names, contains('AAAAAA-samples.jsonl'));
    expect(bulkZipFileName(DateTime(2026, 9, 22)), 'datarow-seances-20260922.zip');
  });
}
