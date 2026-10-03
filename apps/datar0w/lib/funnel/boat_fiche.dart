import 'dart:convert';

import '../identity/models.dart';
import 'lot5_models.dart';

/// Token fiche bateau (deep link). Expire en fin de créneau. Pas de PII licence.
class BoatFichePayload {
  const BoatFichePayload({
    required this.tokenId,
    required this.clubId,
    required this.clubName,
    required this.boatId,
    required this.boatName,
    required this.boatClass,
    required this.seats,
    required this.cox,
    required this.plannedAt,
    required this.expiresAt,
    required this.confirmedSeats,
    required this.freeSeatIndexes,
    this.revoked = false,
  });

  final String tokenId;
  final String clubId;
  final String clubName;
  final String boatId;
  final String boatName;
  final String boatClass;
  final int seats;
  final bool cox;
  final DateTime plannedAt;
  final DateTime expiresAt;
  /// Sièges déjà pris : seat_index → display (prénom seul, pas licence).
  final Map<int, String> confirmedSeats;
  final List<int> freeSeatIndexes;
  final bool revoked;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());
  bool get isValid => !revoked && !isExpired;

  int get freeCount => freeSeatIndexes.length;

  String shareHeadline() {
    final hh = plannedAt.hour.toString().padLeft(2, '0');
    final mm = plannedAt.minute.toString().padLeft(2, '0');
    final free = freeCount == 1 ? '1 siège libre' : '$freeCount sièges libres';
    return '$boatClass · $hh:$mm · $free';
  }

  Map<String, dynamic> toJson() => {
        'tokenId': tokenId,
        'clubId': clubId,
        'clubName': clubName,
        'boatId': boatId,
        'boatName': boatName,
        'boatClass': boatClass,
        'seats': seats,
        'cox': cox,
        'plannedAt': plannedAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'confirmedSeats': {
          for (final e in confirmedSeats.entries) '${e.key}': e.value,
        },
        'freeSeatIndexes': freeSeatIndexes,
        'revoked': revoked,
      };

  static BoatFichePayload fromJson(Map<String, dynamic> j) {
    final confirmedRaw = j['confirmedSeats'];
    final confirmed = <int, String>{};
    if (confirmedRaw is Map) {
      for (final e in confirmedRaw.entries) {
        final k = int.tryParse('${e.key}');
        if (k != null) confirmed[k] = '${e.value}';
      }
    }
    final freeRaw = j['freeSeatIndexes'];
    final free = <int>[];
    if (freeRaw is List) {
      for (final e in freeRaw) {
        final n = (e as num?)?.toInt();
        if (n != null) free.add(n);
      }
    }
    return BoatFichePayload(
      tokenId: j['tokenId'] as String,
      clubId: j['clubId'] as String,
      clubName: j['clubName'] as String? ?? '',
      boatId: j['boatId'] as String,
      boatName: j['boatName'] as String? ?? '',
      boatClass: j['boatClass'] as String? ?? '',
      seats: (j['seats'] as num?)?.toInt() ?? 0,
      cox: j['cox'] == true,
      plannedAt: DateTime.parse(j['plannedAt'] as String),
      expiresAt: DateTime.parse(j['expiresAt'] as String),
      confirmedSeats: confirmed,
      freeSeatIndexes: free,
      revoked: j['revoked'] == true,
    );
  }

  BoatFichePayload copyWith({
    Map<int, String>? confirmedSeats,
    List<int>? freeSeatIndexes,
    bool? revoked,
  }) =>
      BoatFichePayload(
        tokenId: tokenId,
        clubId: clubId,
        clubName: clubName,
        boatId: boatId,
        boatName: boatName,
        boatClass: boatClass,
        seats: seats,
        cox: cox,
        plannedAt: plannedAt,
        expiresAt: expiresAt,
        confirmedSeats: confirmedSeats ?? this.confirmedSeats,
        freeSeatIndexes: freeSeatIndexes ?? this.freeSeatIndexes,
        revoked: revoked ?? this.revoked,
      );
}

/// Encode payload → token URL-safe (pas de table cloud dédiée).
String encodeFicheToken(BoatFichePayload payload) {
  final json = jsonEncode(payload.toJson());
  return base64Url.encode(utf8.encode(json)).replaceAll('=', '');
}

BoatFichePayload? decodeFicheToken(String token) {
  try {
    var t = token.trim();
    while (t.length % 4 != 0) {
      t = '$t=';
    }
    final json = utf8.decode(base64Url.decode(t));
    final map = jsonDecode(json);
    if (map is! Map) return null;
    return BoatFichePayload.fromJson(Map<String, dynamic>.from(map));
  } catch (_) {
    return null;
  }
}

String ficheDeepLink(String token) => 'datarow://fiche/$token';

String ficheHttpsLink(String token) => 'https://datar0w.app/fiche/$token';

String ficheShareText(BoatFichePayload payload, String token) =>
    '${payload.shareHeadline()}\n${ficheHttpsLink(token)}';

/// Construit la fiche depuis plan + bateau + assignments (sans PII sensible).
BoatFichePayload buildFicheFromPlan({
  required String tokenId,
  required Club club,
  required ParkBoat boat,
  required WaterOutingPlan plan,
  required List<Assignment> assignments,
  required String Function(String rowerId) displayNameOf,
}) {
  final taken = <int>{};
  final confirmed = <int, String>{};
  for (final a in assignments) {
    final idx = a.seatIndex;
    if (idx == null || a.role == 'cox') continue;
    if (plan.seatStates[a.rowerId] == SeatConfirmState.confirmed ||
        plan.seatStates[a.rowerId] == null) {
      taken.add(idx);
      // Prénom seul — jamais licence / naissance / poids.
      final name = displayNameOf(a.rowerId).split(' ').first;
      confirmed[idx] = name;
    }
  }
  final free = <int>[
    for (var i = 1; i <= boat.seats; i++)
      if (!taken.contains(i)) i,
  ];
  // Expire à la fin du créneau (+2 h de marge si heure pile).
  final expires = plan.plannedAt.add(const Duration(hours: 2)).toUtc();
  return BoatFichePayload(
    tokenId: tokenId,
    clubId: club.id,
    clubName: club.name,
    boatId: boat.id,
    boatName: boat.name,
    boatClass: boat.classe,
    seats: boat.seats,
    cox: boat.cox,
    plannedAt: plan.plannedAt,
    expiresAt: expires,
    confirmedSeats: confirmed,
    freeSeatIndexes: free,
  );
}
