/// Poids léger FFA (ligne) : 72,5 kg H / 59 kg F. Pas de contrôle bloquant.
bool isLightweight({required String sex, double? weightKg}) {
  if (weightKg == null) return false;
  switch (sex) {
    case 'M':
      return weightKg <= 72.5;
    case 'F':
      return weightKg <= 59.0;
    default:
      return false;
  }
}
