/// Classes produit DataR0w (pas la physique AvSim).
/// Un smartphone = un hub / une place. Pas de 8 IMU simulés.
class BoatClassInfo {
  const BoatClassInfo({
    required this.code,
    required this.label,
    required this.seats,
    required this.coxed,
  });

  final String code;
  final String label;
  final int seats;
  final bool coxed;

  static const all = <BoatClassInfo>[
    BoatClassInfo(code: '1x', label: 'Skiff', seats: 1, coxed: false),
    BoatClassInfo(code: '2x', label: 'Double', seats: 2, coxed: false),
    BoatClassInfo(code: '2-', label: 'Deux de pointe', seats: 2, coxed: false),
    BoatClassInfo(code: '4x', label: 'Quatre de couple', seats: 4, coxed: false),
    BoatClassInfo(code: '4-', label: 'Quatre de pointe', seats: 4, coxed: false),
    BoatClassInfo(code: '4+', label: 'Quatre barré', seats: 4, coxed: true),
    BoatClassInfo(code: '8+', label: 'Huit', seats: 8, coxed: true),
  ];

  static const codes = ['1x', '2x', '2-', '4x', '4-', '4+', '8+'];

  static BoatClassInfo of(String code) {
    final c = code.trim();
    for (final x in all) {
      if (x.code == c) return x;
    }
    return all.first;
  }
}

enum CrewRole { rower, cox, coach }

enum CoxPosition { rear, front }

enum SessionMode { training, competition }

extension SessionModeX on SessionMode {
  String get wire =>
      this == SessionMode.competition ? 'competition' : 'training';

  String get label =>
      this == SessionMode.competition ? 'COMPÉTITION' : 'ENTRAÎNEMENT';

  static SessionMode parse(String? raw) =>
      raw == 'competition' ? SessionMode.competition : SessionMode.training;
}

extension CoxPositionX on CoxPosition {
  String get wire => this == CoxPosition.front ? 'front' : 'rear';

  static CoxPosition parse(String? raw) =>
      raw == 'front' ? CoxPosition.front : CoxPosition.rear;
}

extension CrewRoleX on CrewRole {
  String get wire {
    switch (this) {
      case CrewRole.rower:
        return 'rower';
      case CrewRole.cox:
        return 'cox';
      case CrewRole.coach:
        return 'coach';
    }
  }

  static CrewRole parse(String? raw) {
    switch (raw) {
      case 'cox':
        return CrewRole.cox;
      case 'coach':
        return CrewRole.coach;
      default:
        return CrewRole.rower;
    }
  }
}
