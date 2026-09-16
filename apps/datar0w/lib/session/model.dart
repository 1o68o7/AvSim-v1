import 'dart:convert';

/// Ligne 1 Hz `samples.jsonl`. Cadence toujours nullable (jamais inventée).
class SessionSample {
  const SessionSample({
    required this.t,
    this.lat,
    this.lon,
    this.alt,
    this.sog,
    this.cog,
    this.accH,
    required this.distM,
    this.giteDeg,
    this.pitchDeg,
    this.cadenceSpm,
    this.batt,
    required this.net,
  });

  final int t;
  final double? lat;
  final double? lon;
  final double? alt;
  final double? sog;
  final double? cog;
  final double? accH;
  final double distM;
  final double? giteDeg;
  final double? pitchDeg;
  final double? cadenceSpm;
  final int? batt;
  final String net;

  Map<String, dynamic> toJson() => {
        't': t,
        'lat': lat,
        'lon': lon,
        'alt': alt,
        'sog': sog,
        'cog': cog,
        'acc_h': accH,
        'dist_m': distM,
        'gite_deg': giteDeg,
        'pitch_deg': pitchDeg,
        'cadence_spm': cadenceSpm,
        'batt': batt,
        'net': net,
      };

  String toJsonLine() => jsonEncode(toJson());
}
