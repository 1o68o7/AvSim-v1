enum DeviceType { patchDorsal, chestStrap, armBand, watch, other }

class ConnectedDevice {
  const ConnectedDevice({
    required this.id,
    required this.rowerId,
    required this.type,
    required this.name,
    this.bleId,
    this.isPrimary = false,
    required this.pairedAt,
    this.lastSeenAt,
    this.lastBattery,
  });

  final String id;
  final String rowerId;
  final DeviceType type;
  final String name;
  final String? bleId;
  final bool isPrimary;
  final DateTime pairedAt;
  final DateTime? lastSeenAt;
  final int? lastBattery;

  Map<String, dynamic> toJson() => {
        'id': id,
        'rowerId': rowerId,
        'type': type.name,
        'name': name,
        'bleId': bleId,
        'isPrimary': isPrimary,
        'pairedAt': pairedAt.toUtc().toIso8601String(),
        'lastSeenAt': lastSeenAt?.toUtc().toIso8601String(),
        'lastBattery': lastBattery,
      };

  static ConnectedDevice fromJson(Map<String, dynamic> j) => ConnectedDevice(
        id: j['id'] as String,
        rowerId: j['rowerId'] as String,
        type: DeviceType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => DeviceType.other,
        ),
        name: j['name'] as String? ?? '',
        bleId: j['bleId'] as String?,
        isPrimary: j['isPrimary'] == true,
        pairedAt: DateTime.parse(j['pairedAt'] as String),
        lastSeenAt: j['lastSeenAt'] == null
            ? null
            : DateTime.parse(j['lastSeenAt'] as String),
        lastBattery: (j['lastBattery'] as num?)?.toInt(),
      );
}
