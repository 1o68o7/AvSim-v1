import 'dart:math';

import 'package:datar0w/session/code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('code séance 6 caractères, alphabet sans 0/O/1/I', () {
    final c = generateSessionCode(Random(1));
    expect(c.length, 6);
    expect(RegExp(r'^[A-HJ-NP-Z2-9]+$').hasMatch(c), isTrue);
  });
}
