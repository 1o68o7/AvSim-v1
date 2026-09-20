import 'package:datar0w/sync/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sans dart-define, cloud désactivé (mode local)', () {
    expect(SyncConfig.enabled, isFalse);
    expect(SyncConfig.url, isEmpty);
    expect(SyncConfig.anonKey, isEmpty);
  });
}
