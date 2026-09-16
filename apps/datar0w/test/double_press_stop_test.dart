import 'package:datar0w/session/double_press_stop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('STOP confirme au 2e appui dans 3 s', () {
    final s = DoublePressStop();
    final t0 = DateTime.utc(2026, 9, 16, 12);
    expect(s.press(now: t0), isFalse);
    expect(s.press(now: t0.add(const Duration(seconds: 2))), isTrue);
  });

  test('STOP ignore le 2e appui hors fenêtre', () {
    final s = DoublePressStop();
    final t0 = DateTime.utc(2026, 9, 16, 12);
    expect(s.press(now: t0), isFalse);
    expect(s.press(now: t0.add(const Duration(seconds: 4))), isFalse);
  });
}
