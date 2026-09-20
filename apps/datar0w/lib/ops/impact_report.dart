import '../identity/id.dart';

enum ImpactStatus { open, cleared }

extension ImpactStatusX on ImpactStatus {
  String get wire => name;

  static ImpactStatus parse(String? raw) =>
      raw == 'cleared' ? ImpactStatus.cleared : ImpactStatus.open;
}

class ImpactReport {
  const ImpactReport({
    required this.id,
    required this.boatId,
    this.photoPath,
    required this.note,
    required this.reportedBy,
    required this.reportedAt,
    this.status = ImpactStatus.open,
  });

  final String id;
  final String boatId;
  final String? photoPath;
  final String note;
  final String reportedBy;
  final DateTime reportedAt;
  final ImpactStatus status;

  ImpactReport copyWith({
    String? photoPath,
    String? note,
    ImpactStatus? status,
  }) {
    return ImpactReport(
      id: id,
      boatId: boatId,
      photoPath: photoPath ?? this.photoPath,
      note: note ?? this.note,
      reportedBy: reportedBy,
      reportedAt: reportedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'boatId': boatId,
        'photoPath': photoPath,
        'note': note,
        'reportedBy': reportedBy,
        'reportedAt': reportedAt.toUtc().toIso8601String(),
        'status': status.wire,
      };

  static ImpactReport fromJson(Map<String, dynamic> j) => ImpactReport(
        id: j['id'] as String,
        boatId: j['boatId'] as String,
        photoPath: j['photoPath'] as String?,
        note: j['note'] as String? ?? '',
        reportedBy: j['reportedBy'] as String,
        reportedAt: DateTime.parse(j['reportedAt'] as String),
        status: ImpactStatusX.parse(j['status'] as String?),
      );

  static ImpactReport create({
    required String boatId,
    required String reportedBy,
    String note = '',
    String? photoPath,
  }) {
    return ImpactReport(
      id: newIdentityId(),
      boatId: boatId,
      photoPath: photoPath,
      note: note,
      reportedBy: reportedBy,
      reportedAt: DateTime.now().toUtc(),
    );
  }
}

class OpsNotice {
  const OpsNotice({
    required this.id,
    required this.rowerId,
    required this.message,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final String rowerId;
  final String message;
  final DateTime createdAt;
  final bool read;

  OpsNotice copyWith({bool? read}) => OpsNotice(
        id: id,
        rowerId: rowerId,
        message: message,
        createdAt: createdAt,
        read: read ?? this.read,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'rowerId': rowerId,
        'message': message,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'read': read,
      };

  static OpsNotice fromJson(Map<String, dynamic> j) => OpsNotice(
        id: j['id'] as String,
        rowerId: j['rowerId'] as String,
        message: j['message'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
        read: j['read'] as bool? ?? false,
      );

  static OpsNotice create({
    required String rowerId,
    required String message,
  }) {
    return OpsNotice(
      id: newIdentityId(),
      rowerId: rowerId,
      message: message,
      createdAt: DateTime.now().toUtc(),
    );
  }
}
