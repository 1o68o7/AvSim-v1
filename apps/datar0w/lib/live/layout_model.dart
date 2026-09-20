enum LivePreset { securite, performance, cardio, navigation, complet, custom }

enum LiveBlock { gite, vsol, distance, spm, hr, spo2, map }

extension LivePresetX on LivePreset {
  String get wire => name;
  String get label => switch (this) {
        LivePreset.securite => 'Sécurité',
        LivePreset.performance => 'Performance',
        LivePreset.cardio => 'Cardio',
        LivePreset.navigation => 'Navigation',
        LivePreset.complet => 'Complet',
        LivePreset.custom => 'Perso',
      };

  static LivePreset parse(String? raw) {
    for (final p in LivePreset.values) {
      if (p.name == raw) return p;
    }
    return LivePreset.securite;
  }

  List<LiveBlock> get blocks => switch (this) {
        LivePreset.securite => [LiveBlock.gite],
        LivePreset.performance => [
            LiveBlock.vsol,
            LiveBlock.distance,
            LiveBlock.spm,
          ],
        LivePreset.cardio => [LiveBlock.hr, LiveBlock.spo2, LiveBlock.gite],
        LivePreset.navigation => [
            LiveBlock.map,
            LiveBlock.vsol,
            LiveBlock.distance,
          ],
        LivePreset.complet => [LiveBlock.gite, LiveBlock.vsol, LiveBlock.hr],
        LivePreset.custom => [LiveBlock.gite, LiveBlock.vsol],
      };
}

class RowerLayout {
  const RowerLayout({
    required this.rowerId,
    this.preset = LivePreset.securite,
    this.blocks = const [LiveBlock.gite],
    this.mapEnabled = true,
    required this.updatedAt,
  });

  final String rowerId;
  final LivePreset preset;
  final List<LiveBlock> blocks;
  final bool mapEnabled;
  final DateTime updatedAt;

  List<LiveBlock> get visible {
    var list = blocks.take(3).toList();
    if (preset == LivePreset.navigation && !mapEnabled) {
      list = [LiveBlock.gite, LiveBlock.vsol];
    }
    return list;
  }

  Map<String, dynamic> toJson() => {
        'rowerId': rowerId,
        'preset': preset.wire,
        'blocks': blocks.map((b) => b.name).toList(),
        'mapEnabled': mapEnabled,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  static RowerLayout fromJson(Map<String, dynamic> j) {
    final blocks = <LiveBlock>[];
    for (final raw in (j['blocks'] as List? ?? const [])) {
      for (final b in LiveBlock.values) {
        if (b.name == raw) blocks.add(b);
      }
    }
    return RowerLayout(
      rowerId: j['rowerId'] as String? ?? 'anon',
      preset: LivePresetX.parse(j['preset'] as String?),
      blocks: blocks.isEmpty ? LivePreset.securite.blocks : blocks,
      mapEnabled: j['mapEnabled'] != false,
      updatedAt: DateTime.parse(j['updatedAt'] as String),
    );
  }

  static RowerLayout security(String rowerId) => RowerLayout(
        rowerId: rowerId,
        preset: LivePreset.securite,
        blocks: LivePreset.securite.blocks,
        updatedAt: DateTime.now().toUtc(),
      );

  RowerLayout withPreset(LivePreset p) => RowerLayout(
        rowerId: rowerId,
        preset: p,
        blocks: p.blocks,
        mapEnabled: mapEnabled,
        updatedAt: DateTime.now().toUtc(),
      );
}
