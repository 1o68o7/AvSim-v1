import 'dart:io';

import 'package:datar0w/live/layout_model.dart';
import 'package:datar0w/live/layout_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('layout JSON round-trip + preset sécurité par défaut', () async {
    final dir = Directory(
      '/tmp/datar0w-lay-${DateTime.now().microsecondsSinceEpoch}',
    );
    final store = LayoutStore(root: dir);
    final missing = await store.load('r1');
    expect(missing.preset, LivePreset.securite);
    expect(missing.blocks, contains(LiveBlock.gite));
    final saved = missing.withPreset(LivePreset.performance);
    await store.save(saved);
    final back = await store.load('r1');
    expect(back.preset, LivePreset.performance);
    expect(back.blocks.length, lessThanOrEqualTo(3));
    final nav = back.withPreset(LivePreset.navigation);
    final offline = RowerLayout(
      rowerId: nav.rowerId,
      preset: nav.preset,
      blocks: nav.blocks,
      mapEnabled: false,
      updatedAt: DateTime.now().toUtc(),
    );
    expect(offline.visible, [LiveBlock.gite, LiveBlock.vsol]);
  });
}
