import 'dart:math';

/// Cap magnétique 0–360°, compensé d’assiette. Ne remplace pas le COG GPS.
double? magHeadingDeg({
  required double mx,
  required double my,
  required double mz,
  required double ax,
  required double ay,
  required double az,
}) {
  final g = sqrt(ax * ax + ay * ay + az * az);
  if (g < 1) return null;
  final m = sqrt(mx * mx + my * my + mz * mz);
  if (m < 1e-6) return null;
  final roll = atan2(ay, az);
  final pitch = atan2(-ax, sqrt(ay * ay + az * az));
  final cr = cos(roll);
  final sr = sin(roll);
  final cp = cos(pitch);
  final sp = sin(pitch);
  final mx2 = mx * cp + mz * sp;
  final my2 = mx * sr * sp + my * cr - mz * sr * cp;
  var h = atan2(-my2, mx2) * 180 / pi;
  if (h < 0) h += 360;
  if (h >= 360) h -= 360;
  return h;
}
