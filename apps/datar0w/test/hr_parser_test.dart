import 'package:datar0w/sensors/ble/hr_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FC 8 bits', () {
    final r = parseHeartRateMeasurement([0x00, 72]);
    expect(r.bpm, 72);
    expect(r.contact, isFalse);
  });

  test('FC 16 bits', () {
    final r = parseHeartRateMeasurement([0x01, 0x2C, 0x01]);
    expect(r.bpm, 300);
  });

  test('FC + RR', () {
    final r = parseHeartRateMeasurement([0x10, 80, 0x00, 0x04]);
    expect(r.bpm, 80);
    expect(r.rrIntervalsMs, isNotEmpty);
  });
}
