import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PhysioRecord {
  const PhysioRecord({
    this.consent = false,
    this.shareWithCoach = false,
    this.consentAt,
    this.restingHr,
    this.hrvMs,
    this.notes,
    this.rowerId,
    this.clubId,
    this.userId,
  });

  final bool consent;
  final bool shareWithCoach;
  final DateTime? consentAt;
  final int? restingHr;
  final int? hrvMs;
  final String? notes;
  final String? rowerId;
  final String? clubId;
  final String? userId;

  Map<String, dynamic> toJson() => {
        'consent': consent,
        'shareWithCoach': shareWithCoach,
        'consentAt': consentAt?.toUtc().toIso8601String(),
        'restingHr': restingHr,
        'hrvMs': hrvMs,
        'notes': notes,
        'rowerId': rowerId,
        'clubId': clubId,
        'userId': userId,
      };

  Map<String, dynamic> toSql() => {
        'club_id': clubId,
        'rower_id': rowerId,
        'user_id': userId,
        'consent_at': consent ? consentAt?.toUtc().toIso8601String() : null,
        'share_with_coach': shareWithCoach,
        'resting_hr': restingHr,
        'hrv_ms': hrvMs,
        'notes': notes,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  PhysioRecord copyWith({
    bool? consent,
    bool? shareWithCoach,
    DateTime? consentAt,
    int? restingHr,
    int? hrvMs,
    String? notes,
    String? rowerId,
    String? clubId,
    String? userId,
  }) =>
      PhysioRecord(
        consent: consent ?? this.consent,
        shareWithCoach: shareWithCoach ?? this.shareWithCoach,
        consentAt: consentAt ?? this.consentAt,
        restingHr: restingHr ?? this.restingHr,
        hrvMs: hrvMs ?? this.hrvMs,
        notes: notes ?? this.notes,
        rowerId: rowerId ?? this.rowerId,
        clubId: clubId ?? this.clubId,
        userId: userId ?? this.userId,
      );

  static PhysioRecord fromJson(Map<String, dynamic> j) => PhysioRecord(
        consent: j['consent'] == true,
        shareWithCoach: j['shareWithCoach'] == true,
        consentAt: j['consentAt'] == null
            ? null
            : DateTime.tryParse(j['consentAt'] as String),
        restingHr: (j['restingHr'] as num?)?.toInt(),
        hrvMs: (j['hrvMs'] as num?)?.toInt(),
        notes: j['notes'] as String?,
        rowerId: j['rowerId'] as String?,
        clubId: j['clubId'] as String?,
        userId: j['userId'] as String?,
      );
}

class PhysioStore {
  PhysioStore({this.root});
  final Directory? root;

  Future<File> _file() async {
    final dir = root ??
        Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'datar0w'),
        );
    await dir.create(recursive: true);
    return File(p.join(dir.path, 'rower_physio.json'));
  }

  Future<PhysioRecord> load() async {
    final f = await _file();
    if (!f.existsSync()) return const PhysioRecord();
    return PhysioRecord.fromJson(
      jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
    );
  }

  Future<void> save(PhysioRecord r) async {
    await (await _file()).writeAsString(jsonEncode(r.toJson()));
  }
}

/// Miroir SQL 0006 (tests hors Postgres).
bool rlsCanWritePhysio({
  required String authUid,
  required String rowUserId,
}) =>
    authUid == rowUserId;

bool rlsCanReadPhysio({
  required String authUid,
  required String rowUserId,
  required bool shareWithCoach,
  required String role,
  required bool sameClub,
}) {
  if (authUid == rowUserId) return true;
  if (!sameClub) return false;
  if (!shareWithCoach) return false;
  return role == 'coach' || role == 'admin';
}

bool rlsCanWriteSessionMeta({
  required String authUid,
  required String ownerUserId,
  required bool sameClub,
}) =>
    sameClub && authUid == ownerUserId;
