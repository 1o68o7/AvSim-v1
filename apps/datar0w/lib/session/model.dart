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

  static SessionSample fromJson(Map<String, dynamic> j) {
    return SessionSample(
      t: (j['t'] as num).toInt(),
      lat: (j['lat'] as num?)?.toDouble(),
      lon: (j['lon'] as num?)?.toDouble(),
      alt: (j['alt'] as num?)?.toDouble(),
      sog: (j['sog'] as num?)?.toDouble(),
      cog: (j['cog'] as num?)?.toDouble(),
      accH: (j['acc_h'] as num?)?.toDouble(),
      distM: (j['dist_m'] as num?)?.toDouble() ?? 0,
      giteDeg: (j['gite_deg'] as num?)?.toDouble(),
      pitchDeg: (j['pitch_deg'] as num?)?.toDouble(),
      cadenceSpm: (j['cadence_spm'] as num?)?.toDouble(),
      batt: (j['batt'] as num?)?.toInt(),
      net: j['net'] as String? ?? 'hors ligne',
    );
  }
}

/// Repère coach (`notes.json`) — jamais inventé.
class SessionNote {
  const SessionNote({
    required this.t,
    this.lat,
    this.lon,
    this.sog,
    this.distM,
    this.giteDeg,
  });

  final int t;
  final double? lat;
  final double? lon;
  final double? sog;
  final double? distM;
  final double? giteDeg;

  static SessionNote fromJson(Map<String, dynamic> j) => SessionNote(
        t: (j['t'] as num).toInt(),
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        sog: (j['sog'] as num?)?.toDouble(),
        distM: (j['dist_m'] as num?)?.toDouble(),
        giteDeg: (j['gite_deg'] as num?)?.toDouble(),
      );
}
