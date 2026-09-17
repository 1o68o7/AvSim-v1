import 'dart:math';

import 'package:latlong2/latlong.dart';

import 'model.dart';

/// Segments GPS : un trou (lat/lon null) coupe le trait, pas d'interpolation.
List<List<LatLng>> gpsSegments(List<SessionSample> samples) {
  final segs = <List<LatLng>>[];
  var cur = <LatLng>[];
  void flush() {
    if (cur.isNotEmpty) {
      segs.add(cur);
      cur = [];
    }
  }

  for (final s in samples) {
    if (s.lat != null && s.lon != null) {
      cur.add(LatLng(s.lat!, s.lon!));
    } else {
      flush();
    }
  }
  flush();
  return segs;
}

class SessionSummary {
  const SessionSummary({
    required this.duration,
    required this.distM,
    required this.giteRms,
    this.cadenceMean,
  });

  final Duration duration;
  final double distM;
  final double giteRms;
  final double? cadenceMean;

  static SessionSummary fromSamples(List<SessionSample> samples) {
    if (samples.isEmpty) {
      return const SessionSummary(
        duration: Duration.zero,
        distM: 0,
        giteRms: 0,
      );
    }
    final duration = Duration(
      milliseconds: max(0, samples.last.t - samples.first.t),
    );
    final dist = samples.last.distM;
    final gites = samples.map((s) => s.giteDeg).whereType<double>().toList();
    var rms = 0.0;
    if (gites.isNotEmpty) {
      var acc = 0.0;
      for (final g in gites) {
        acc += g * g;
      }
      rms = sqrt(acc / gites.length);
    }
    final cads = samples.map((s) => s.cadenceSpm).whereType<double>().toList();
    final cad = cads.isEmpty
        ? null
        : cads.reduce((a, b) => a + b) / cads.length;
    return SessionSummary(
      duration: duration,
      distM: dist,
      giteRms: rms,
      cadenceMean: cad,
    );
  }
}

String formatClockRange(String? startedAt, String? endedAt) {
  String fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    final l = d.toLocal();
    final hh = l.hour.toString().padLeft(2, '0');
    final mm = l.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  if (startedAt == null && endedAt == null) return '—';
  return '${fmt(startedAt)} — ${fmt(endedAt)}';
}

String formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    return '${d.inHours}:$m:$s';
  }
  return '$m:$s';
}
