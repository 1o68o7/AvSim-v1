import 'dart:math';

const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String generateSessionCode([Random? rng]) {
  final r = rng ?? Random.secure();
  final buf = StringBuffer();
  for (var i = 0; i < 6; i++) {
    buf.write(_alphabet[r.nextInt(_alphabet.length)]);
  }
  return buf.toString();
}
