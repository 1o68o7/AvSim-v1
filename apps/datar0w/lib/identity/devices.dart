enum DeviceType { patchDorsal, chestStrap, armBand, watch, other }

enum PatchLinkState { scan, paired, logLocal, syncQuai }

extension PatchLinkStateX on PatchLinkState {
  String get label => switch (this) {
        PatchLinkState.scan => 'scan',
        PatchLinkState.paired => 'pairé',
        PatchLinkState.logLocal => 'log local',
        PatchLinkState.syncQuai => 'sync quai',
      };
}

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
    this.patchLink,
    this.feedbackCadence = false,
    this.feedbackGite = false,
    this.feedbackHr = false,
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
  final PatchLinkState? patchLink;
  final bool feedbackCadence;
  final bool feedbackGite;
  final bool feedbackHr;

  bool get isPatch => type == DeviceType.patchDorsal;

  ConnectedDevice copyWith({
    DeviceType? type,
    String? name,
    String? bleId,
    bool? isPrimary,
    DateTime? lastSeenAt,
    int? lastBattery,
    PatchLinkState? patchLink,
    bool? feedbackCadence,
    bool? feedbackGite,
    bool? feedbackHr,
  }) {
    return ConnectedDevice(
      id: id,
      rowerId: rowerId,
      type: type ?? this.type,
      name: name ?? this.name,
      bleId: bleId ?? this.bleId,
      isPrimary: isPrimary ?? this.isPrimary,
      pairedAt: pairedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastBattery: lastBattery ?? this.lastBattery,
      patchLink: patchLink ?? this.patchLink,
      feedbackCadence: feedbackCadence ?? this.feedbackCadence,
      feedbackGite: feedbackGite ?? this.feedbackGite,
      feedbackHr: feedbackHr ?? this.feedbackHr,
    );
  }

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
        if (patchLink != null) 'patchLink': patchLink!.name,
        'feedbackCadence': feedbackCadence,
        'feedbackGite': feedbackGite,
        'feedbackHr': feedbackHr,
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
        patchLink: _patchLink(j['patchLink'] as String?),
        feedbackCadence: j['feedbackCadence'] == true,
        feedbackGite: j['feedbackGite'] == true,
        feedbackHr: j['feedbackHr'] == true,
      );
}

PatchLinkState? _patchLink(String? raw) {
  if (raw == null) return null;
  for (final e in PatchLinkState.values) {
    if (e.name == raw) return e;
  }
  return null;
}
