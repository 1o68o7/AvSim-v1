import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'boat_class.dart';
export 'boat_class.dart';

class BoatConfig {
  const BoatConfig({
    this.classe = '1x',
    this.seatIndex = 1,
    this.role = CrewRole.rower,
    this.bassin = 'Bassin de Mantes-la-Jolie',
  });

  final String classe;
  final int seatIndex;
  final CrewRole role;
  final String bassin;

  BoatClassInfo get info => BoatClassInfo.of(classe);

  int get seats => info.seats;

  bool get coxed => info.coxed;

  /// 1 = stroke / nage. Indéfini pour le barreur (siège rameur).
  int get clampedSeat {
    final n = seats;
    if (seatIndex < 1) return 1;
    if (seatIndex > n) return n;
    return seatIndex;
  }

  /// Sièges du bateau non occupés par ce téléphone (local / poll API).
  List<int> get waitingSeats {
    if (role != CrewRole.rower) {
      return [for (var i = 1; i <= seats; i++) i];
    }
    return [for (var i = 1; i <= seats; i++) if (i != clampedSeat) i];
  }

  Map<String, dynamic> toMetaFields() => {
        'class': classe,
        'seats': seats,
        'cox': coxed,
        'role': role.wire,
        'seatIndex': clampedSeat,
      };

  BoatConfig copyWith({
    String? classe,
    int? seatIndex,
    CrewRole? role,
    String? bassin,
  }) {
    final next = BoatConfig(
      classe: classe ?? this.classe,
      seatIndex: seatIndex ?? this.seatIndex,
      role: role ?? this.role,
      bassin: bassin ?? this.bassin,
    );
    return BoatConfig(
      classe: next.classe,
      seatIndex: next.clampedSeat,
      role: next.role,
      bassin: next.bassin,
    );
  }
}

class BoatConfigNotifier extends Notifier<BoatConfig> {
  @override
  BoatConfig build() => const BoatConfig();

  void setClasse(String code) {
    state = state.copyWith(classe: BoatClassInfo.of(code).code, seatIndex: 1);
  }

  void setSeat(int i) => state = state.copyWith(seatIndex: i);

  void setRole(CrewRole role) => state = state.copyWith(role: role);

  void setBassin(String v) => state = state.copyWith(bassin: v);
}

final boatConfigProvider =
    NotifierProvider<BoatConfigNotifier, BoatConfig>(BoatConfigNotifier.new);
