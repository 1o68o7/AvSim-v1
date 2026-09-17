import 'dart:math';

/// Altitude baro relative (m), quai = 0.
/// Sans API pression supportée (`sensors_plus` barometer, pas jcenter) :
/// [pHpa] / [p0Hpa] restent null → [altBaroRelM] null. Pas d’erreur.
double? altBaroRelM(double? pHpa, double? p0Hpa) {
  if (pHpa == null || p0Hpa == null || pHpa <= 0 || p0Hpa <= 0) return null;
  return 44330.77 * (1 - pow(pHpa / p0Hpa, 0.19029495));
}
