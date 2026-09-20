import '../identity/id.dart';

enum OarSource { club, personal }

extension OarSourceX on OarSource {
  String get wire => name;

  static OarSource parse(String? raw) =>
      raw == 'personal' ? OarSource.personal : OarSource.club;
}

class OarItem {
  const OarItem({
    required this.spec,
    this.qty = 1,
    this.source = OarSource.club,
  });

  final String spec;
  final int qty;
  final OarSource source;

  Map<String, dynamic> toJson() => {
        'spec': spec,
        'qty': qty,
        'source': source.wire,
      };

  static OarItem fromJson(Map<String, dynamic> j) => OarItem(
        spec: j['spec'] as String? ?? '',
        qty: (j['qty'] as num?)?.toInt() ?? 1,
        source: OarSourceX.parse(j['source'] as String?),
      );
}

/// Jeu de pelles de sortie : sous-ensemble du rack, figé au check-out.
class OarSet {
  const OarSet({
    required this.id,
    required this.boatId,
    required this.items,
    required this.checkedOutAt,
    this.frozen = true,
  });

  final String id;
  final String boatId;
  final List<OarItem> items;
  final DateTime checkedOutAt;
  final bool frozen;

  Map<String, dynamic> toJson() => {
        'id': id,
        'boatId': boatId,
        'items': items.map((e) => e.toJson()).toList(),
        'checkedOutAt': checkedOutAt.toUtc().toIso8601String(),
        'frozen': frozen,
      };

  static OarSet fromJson(Map<String, dynamic> j) => OarSet(
        id: j['id'] as String,
        boatId: j['boatId'] as String,
        items: (j['items'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => OarItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        checkedOutAt: DateTime.parse(j['checkedOutAt'] as String),
        frozen: j['frozen'] as bool? ?? true,
      );

  static OarSet create({
    required String boatId,
    required List<OarItem> items,
    DateTime? checkedOutAt,
    bool frozen = true,
  }) {
    return OarSet(
      id: newIdentityId(),
      boatId: boatId,
      items: List.unmodifiable(items),
      checkedOutAt: checkedOutAt ?? DateTime.now().toUtc(),
      frozen: frozen,
    );
  }

  /// Specs club doivent figurer sur le rack. Les pelles perso sont libres.
  bool isSubsetOfRack(List<String> rack) {
    for (final it in items) {
      if (it.source == OarSource.personal) continue;
      if (!rack.contains(it.spec)) return false;
    }
    return true;
  }

  String get label => items
      .map((e) => '${e.spec}×${e.qty}${e.source == OarSource.personal ? ' (perso)' : ''}')
      .join(', ');
}
