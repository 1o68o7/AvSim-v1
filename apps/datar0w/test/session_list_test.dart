import 'dart:convert';
import 'dart:io';

import 'package:datar0w/session/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('datar0w_sessions_');
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<void> writeMeta(String id, Map<String, dynamic> json) async {
    final dir = Directory('${root.path}/$id');
    await dir.create(recursive: true);
    await File('${dir.path}/meta.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );
  }

  test('listSessions tri endedAt/startedAt desc, dossier vide ignoré', () async {
    await writeMeta('old', {
      'id': 'old',
      'class': '1x',
      'code': 'AAAAAA',
      'started_at': '2026-01-01T10:00:00Z',
      'ended_at': '2026-01-01T11:00:00Z',
    });
    await writeMeta('new', {
      'id': 'new',
      'class': '8+',
      'code': 'GCZEKF',
      'started_at': '2026-09-22T08:00:00Z',
      'ended_at': '2026-09-22T09:00:00Z',
    });
    await Directory('${root.path}/empty').create(recursive: true);

    final listed = await SessionStore.listSessions(root: root);
    expect(listed.map((m) => m.id).toList(), ['new', 'old']);
    expect(listed.first.code, 'GCZEKF');
    expect(
      Directory('${root.path}/empty').existsSync(),
      isTrue,
      reason: 'dossier sans meta.json non effacé',
    );
  });

  test('listSessions sans endedAt utilise startedAt', () async {
    await writeMeta('a', {
      'id': 'a',
      'started_at': '2026-03-01T00:00:00Z',
    });
    await writeMeta('b', {
      'id': 'b',
      'started_at': '2026-04-01T00:00:00Z',
    });
    final listed = await SessionStore.listSessions(root: root);
    expect(listed.map((m) => m.id).toList(), ['b', 'a']);
  });
}
