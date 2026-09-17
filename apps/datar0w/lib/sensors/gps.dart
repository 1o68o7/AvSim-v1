import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class GpsFix {
  const GpsFix({
    required this.lat,
    required this.lon,
    this.alt,
    this.sog,
    this.cog,
    this.accH,
    this.accV,
  });

  final double lat;
  final double lon;
  final double? alt;
  final double? sog;
  final double? cog;
  final double? accH;
  final double? accV;
}

class GpsService {
  Stream<GpsFix> stream() {
    return Geolocator.getPositionStream(locationSettings: _settings()).map(
      (p) => GpsFix(
        lat: p.latitude,
        lon: p.longitude,
        alt: p.altitude,
        sog: p.speed.isFinite ? p.speed : null,
        cog: p.heading.isFinite ? p.heading : null,
        accH: p.accuracy.isFinite ? p.accuracy : null,
        accV: p.altitudeAccuracy.isFinite ? p.altitudeAccuracy : null,
      ),
    );
  }

  static LocationSettings _settings() {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
    );
  }
}
