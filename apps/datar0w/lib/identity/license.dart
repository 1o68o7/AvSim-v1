/// Licence FFA (table `licenses`). PDF jamais stocké.

enum LicenseSource { pdf, ocr, manual }

extension LicenseSourceX on LicenseSource {
  String get wire => name;
  static LicenseSource parse(String? raw) {
    for (final v in LicenseSource.values) {
      if (v.name == raw) return v;
    }
    return LicenseSource.manual;
  }
}

class FfaLicense {
  const FfaLicense({
    required this.id,
    required this.rowerId,
    this.licenseNumber,
    this.licenseType,
    this.validUntil,
    this.ffaCode,
    this.category,
    this.surclassement = false,
    this.handiClassification,
    this.source = LicenseSource.manual,
    this.myffaVerified = false,
  });

  final String id;
  final String rowerId;
  final String? licenseNumber;
  final String? licenseType;
  final DateTime? validUntil;
  final String? ffaCode;
  final String? category;
  final bool surclassement;
  final String? handiClassification;
  final LicenseSource source;
  final bool myffaVerified;

  bool get isAl =>
      (licenseType ?? '').toUpperCase().contains('AL') ||
      (licenseType ?? '').toLowerCase().contains('loisir');

  bool get isExpired {
    final v = validUntil;
    if (v == null) return false;
    final today = DateTime.now();
    final d = DateTime(today.year, today.month, today.day);
    final until = DateTime(v.year, v.month, v.day);
    return until.isBefore(d);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rowerId': rowerId,
        if (licenseNumber != null) 'licenseNumber': licenseNumber,
        if (licenseType != null) 'licenseType': licenseType,
        if (validUntil != null)
          'validUntil': validUntil!.toIso8601String().split('T').first,
        if (ffaCode != null) 'ffaCode': ffaCode,
        if (category != null) 'category': category,
        'surclassement': surclassement,
        if (handiClassification != null)
          'handiClassification': handiClassification,
        'source': source.wire,
        'myffaVerified': myffaVerified,
      };

  Map<String, dynamic> toSql() => {
        'id': id,
        'rower_id': rowerId,
        if (licenseNumber != null) 'license_number': licenseNumber,
        if (licenseType != null) 'license_type': licenseType,
        if (validUntil != null)
          'valid_until': validUntil!.toIso8601String().split('T').first,
        if (ffaCode != null) 'ffa_code': ffaCode,
        if (category != null) 'category': category,
        'surclassement': surclassement,
        if (handiClassification != null)
          'handi_classification': handiClassification,
        'source': source.wire,
        'myffa_verified': myffaVerified,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  static FfaLicense fromJson(Map<String, dynamic> j) => FfaLicense(
        id: j['id'] as String,
        rowerId: (j['rowerId'] ?? j['rower_id']) as String,
        licenseNumber: (j['licenseNumber'] ?? j['license_number']) as String?,
        licenseType: (j['licenseType'] ?? j['license_type']) as String?,
        validUntil: _date(j['validUntil'] ?? j['valid_until']),
        ffaCode: (j['ffaCode'] ?? j['ffa_code']) as String?,
        category: j['category'] as String?,
        surclassement: j['surclassement'] == true,
        handiClassification:
            (j['handiClassification'] ?? j['handi_classification']) as String?,
        source: LicenseSourceX.parse(j['source'] as String?),
        myffaVerified: j['myffaVerified'] == true || j['myffa_verified'] == true,
      );

  static DateTime? _date(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse('$raw');
  }
}

/// Résultat parse PDF avant confirmation (pas encore écrit).
class LicenseDraft {
  const LicenseDraft({
    this.firstName,
    this.lastName,
    this.birthDate,
    this.sex,
    this.licenseNumber,
    this.licenseType,
    this.validUntil,
    this.ffaCode,
    this.clubName,
    this.category,
    this.surclassement = false,
    this.handiClassification,
    this.source = LicenseSource.pdf,
    this.doubtfulFields = const {},
  });

  final String? firstName;
  final String? lastName;
  final DateTime? birthDate;
  final String? sex; // M / F
  final String? licenseNumber;
  final String? licenseType;
  final DateTime? validUntil;
  final String? ffaCode;
  final String? clubName;
  final String? category;
  final bool surclassement;
  final String? handiClassification;
  final LicenseSource source;
  final Set<String> doubtfulFields;

  String get displayName {
    final parts = [
      if (firstName != null && firstName!.trim().isNotEmpty) firstName!.trim(),
      if (lastName != null && lastName!.trim().isNotEmpty) lastName!.trim(),
    ];
    return parts.join(' ');
  }

  bool get isReadable =>
      (licenseNumber != null && licenseNumber!.trim().isNotEmpty) ||
      (ffaCode != null && ffaCode!.trim().isNotEmpty);

  bool isDoubtful(String field) => doubtfulFields.contains(field);
}
