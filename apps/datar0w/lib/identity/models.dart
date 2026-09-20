import '../session/boat_class.dart';
import 'ffa_categories.dart';
import 'id.dart';
import 'is_lightweight.dart';

enum RowerSex { m, f, x }

extension RowerSexX on RowerSex {
  String get wire => switch (this) {
        RowerSex.m => 'M',
        RowerSex.f => 'F',
        RowerSex.x => 'X',
      };

  static RowerSex parse(String? raw) {
    switch (raw) {
      case 'F':
        return RowerSex.f;
      case 'X':
        return RowerSex.x;
      default:
        return RowerSex.m;
    }
  }
}

enum SidePref { babord, tribord, none }

extension SidePrefX on SidePref {
  String get wire => switch (this) {
        SidePref.babord => 'babord',
        SidePref.tribord => 'tribord',
        SidePref.none => 'none',
      };

  static SidePref parse(String? raw) {
    switch (raw) {
      case 'babord':
        return SidePref.babord;
      case 'tribord':
        return SidePref.tribord;
      default:
        return SidePref.none;
    }
  }
}

enum RowerLevel { loisir, competiteur, inconnu }

extension RowerLevelX on RowerLevel {
  String get wire => switch (this) {
        RowerLevel.loisir => 'loisir',
        RowerLevel.competiteur => 'competiteur',
        RowerLevel.inconnu => 'inconnu',
      };

  static RowerLevel parse(String? raw) {
    switch (raw) {
      case 'loisir':
        return RowerLevel.loisir;
      case 'competiteur':
        return RowerLevel.competiteur;
      default:
        return RowerLevel.inconnu;
    }
  }
}

enum BoatParkStatus { ready, maintenance, out }

extension BoatParkStatusX on BoatParkStatus {
  String get wire => name;

  static BoatParkStatus parse(String? raw) {
    switch (raw) {
      case 'maintenance':
        return BoatParkStatus.maintenance;
      case 'out':
        return BoatParkStatus.out;
      default:
        return BoatParkStatus.ready;
    }
  }
}

class Rower {
  const Rower({
    required this.id,
    required this.displayName,
    required this.birthDate,
    this.sex = RowerSex.m,
    this.weightKg,
    this.heightCm,
    this.sidePref = SidePref.none,
    this.oarSpec,
    this.level = RowerLevel.inconnu,
    this.clubId,
    this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String displayName;
  final DateTime birthDate;
  final RowerSex sex;
  final double? weightKg;
  final double? heightCm;
  final SidePref sidePref;
  final String? oarSpec;
  final RowerLevel level;
  final String? clubId;
  final String? userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  AgeCategory category({DateTime? now, int? seasonYear}) =>
      ageCategory(birthDate, now: now, seasonYear: seasonYear);

  bool get lightweight =>
      isLightweight(sex: sex.wire, weightKg: weightKg);

  Rower copyWith({
    String? displayName,
    DateTime? birthDate,
    RowerSex? sex,
    double? weightKg,
    bool clearWeight = false,
    double? heightCm,
    bool clearHeight = false,
    SidePref? sidePref,
    String? oarSpec,
    bool clearOar = false,
    RowerLevel? level,
    String? clubId,
    bool clearClub = false,
    String? userId,
    bool clearUser = false,
    DateTime? updatedAt,
  }) {
    return Rower(
      id: id,
      displayName: displayName ?? this.displayName,
      birthDate: birthDate ?? this.birthDate,
      sex: sex ?? this.sex,
      weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
      heightCm: clearHeight ? null : (heightCm ?? this.heightCm),
      sidePref: sidePref ?? this.sidePref,
      oarSpec: clearOar ? null : (oarSpec ?? this.oarSpec),
      level: level ?? this.level,
      clubId: clearClub ? null : (clubId ?? this.clubId),
      userId: clearUser ? null : (userId ?? this.userId),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'birthDate': birthDate.toUtc().toIso8601String().split('T').first,
        'sex': sex.wire,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'sidePref': sidePref.wire,
        'oarSpec': oarSpec,
        'level': level.wire,
        'clubId': clubId,
        'userId': userId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  static Rower fromJson(Map<String, dynamic> j) {
    return Rower(
      id: j['id'] as String,
      displayName: j['displayName'] as String? ?? '',
      birthDate: DateTime.parse(j['birthDate'] as String),
      sex: RowerSexX.parse(j['sex'] as String?),
      weightKg: (j['weightKg'] as num?)?.toDouble(),
      heightCm: (j['heightCm'] as num?)?.toDouble(),
      sidePref: SidePrefX.parse(j['sidePref'] as String?),
      oarSpec: j['oarSpec'] as String?,
      level: RowerLevelX.parse(j['level'] as String?),
      clubId: j['clubId'] as String?,
      userId: j['userId'] as String?,
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
    );
  }

  static Rower create({
    required String displayName,
    required DateTime birthDate,
    RowerSex sex = RowerSex.m,
  }) {
    final now = DateTime.now().toUtc();
    return Rower(
      id: newIdentityId(),
      displayName: displayName,
      birthDate: birthDate,
      sex: sex,
      createdAt: now,
      updatedAt: now,
    );
  }
}

class Club {
  const Club({
    required this.id,
    required this.name,
    this.shortCode,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? shortCode;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'shortCode': shortCode,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  static Club fromJson(Map<String, dynamic> j) => Club(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        shortCode: j['shortCode'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  Club copyWith({String? name, String? shortCode, bool clearCode = false}) {
    return Club(
      id: id,
      name: name ?? this.name,
      shortCode: clearCode ? null : (shortCode ?? this.shortCode),
      createdAt: createdAt,
    );
  }

  static Club create({required String name, String? shortCode}) {
    return Club(
      id: newIdentityId(),
      name: name,
      shortCode: shortCode,
      createdAt: DateTime.now().toUtc(),
    );
  }
}

class ParkBoat {
  const ParkBoat({
    required this.id,
    required this.clubId,
    required this.name,
    required this.classe,
    required this.seats,
    required this.cox,
    this.oarRack = const [],
    this.status = BoatParkStatus.ready,
  });

  final String id;
  final String clubId;
  final String name;
  final String classe;
  final int seats;
  final bool cox;
  final List<String> oarRack;
  final BoatParkStatus status;

  BoatClassInfo get info => BoatClassInfo.of(classe);

  ParkBoat copyWith({
    String? name,
    String? classe,
    List<String>? oarRack,
    BoatParkStatus? status,
  }) {
    final info = BoatClassInfo.of(classe ?? this.classe);
    return ParkBoat(
      id: id,
      clubId: clubId,
      name: name ?? this.name,
      classe: info.code,
      seats: info.seats,
      cox: info.coxed,
      oarRack: oarRack ?? this.oarRack,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'clubId': clubId,
        'name': name,
        'class': classe,
        'seats': seats,
        'cox': cox,
        'oarRack': oarRack,
        'status': status.wire,
      };

  static ParkBoat fromJson(Map<String, dynamic> j) {
    final classe =
        (j['class'] as String?) ?? (j['classe'] as String?) ?? '1x';
    final info = BoatClassInfo.of(classe);
    return ParkBoat(
      id: j['id'] as String,
      clubId: j['clubId'] as String,
      name: j['name'] as String? ?? '',
      classe: info.code,
      seats: (j['seats'] as num?)?.toInt() ?? info.seats,
      cox: j['cox'] as bool? ?? info.coxed,
      oarRack: (j['oarRack'] as List?)?.map((e) => '$e').toList() ?? const [],
      status: BoatParkStatusX.parse(j['status'] as String?),
    );
  }

  static ParkBoat create({
    required String clubId,
    required String name,
    required String classe,
    List<String> oarRack = const [],
    BoatParkStatus status = BoatParkStatus.ready,
  }) {
    final info = BoatClassInfo.of(classe);
    return ParkBoat(
      id: newIdentityId(),
      clubId: clubId,
      name: name,
      classe: info.code,
      seats: info.seats,
      cox: info.coxed,
      oarRack: oarRack,
      status: status,
    );
  }
}

class Assignment {
  const Assignment({
    required this.id,
    required this.boatId,
    this.seatIndex,
    required this.rowerId,
    required this.side,
    this.oars = const [],
    this.role = 'rower',
    this.coxPosition,
    required this.createdAt,
  });

  final String id;
  final String boatId;
  final int? seatIndex;
  final String rowerId;
  final SidePref side;
  final List<String> oars;
  final String role;
  final String? coxPosition;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'boatId': boatId,
        'seatIndex': seatIndex,
        'rowerId': rowerId,
        'side': side.wire,
        'oars': oars,
        'role': role,
        'coxPosition': coxPosition,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  static Assignment fromJson(Map<String, dynamic> j) => Assignment(
        id: j['id'] as String,
        boatId: j['boatId'] as String,
        seatIndex: (j['seatIndex'] as num?)?.toInt(),
        rowerId: j['rowerId'] as String,
        side: SidePrefX.parse(j['side'] as String?),
        oars: (j['oars'] as List?)?.map((e) => '$e').toList() ?? const [],
        role: j['role'] as String? ?? 'rower',
        coxPosition: j['coxPosition'] as String?,
        createdAt: j['createdAt'] is String
            ? DateTime.parse(j['createdAt'] as String)
            : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  static Assignment create({
    required String boatId,
    required String rowerId,
    required SidePref side,
    int? seatIndex,
    List<String> oars = const [],
    String role = 'rower',
    String? coxPosition,
    DateTime? createdAt,
  }) {
    return Assignment(
      id: newIdentityId(),
      boatId: boatId,
      seatIndex: role == 'cox' ? null : seatIndex,
      rowerId: rowerId,
      side: side,
      oars: oars,
      role: role,
      coxPosition: coxPosition,
      createdAt: createdAt ?? DateTime.now().toUtc(),
    );
  }
}

bool sameLocalDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}
