class HrReading {
  const HrReading({
    required this.bpm,
    this.contact = false,
    this.rrIntervalsMs = const [],
  });

  final int bpm;
  final bool contact;
  final List<int> rrIntervalsMs;
}

/// GATT Heart Rate Measurement (0x2A37).
HrReading parseHeartRateMeasurement(List<int> data) {
  if (data.isEmpty) {
    throw FormatException('payload vide');
  }
  final flags = data[0];
  final u16 = flags & 0x01 != 0;
  final contact = flags & 0x06 == 0x06;
  var i = 1;
  late int bpm;
  if (u16) {
    if (data.length < 3) throw FormatException('bpm 16 bits tronqué');
    bpm = data[1] | (data[2] << 8);
    i = 3;
  } else {
    if (data.length < 2) throw FormatException('bpm 8 bits tronqué');
    bpm = data[1];
    i = 2;
  }
  if (flags & 0x08 != 0) i += 2; // energy expended
  final rr = <int>[];
  if (flags & 0x10 != 0) {
    while (i + 1 < data.length) {
      final raw = data[i] | (data[i + 1] << 8);
      rr.add((raw * 1000 / 1024).round());
      i += 2;
    }
  }
  return HrReading(bpm: bpm, contact: contact, rrIntervalsMs: rr);
}
