import 'package:flutter_map/flutter_map.dart';

/// Tuiles OSM (pas de clé). Attribution OpenFreeMap / OSM (cadrage I.6).
/// Style vectoriel `tiles.openfreemap.org/styles/dark` = MapLibre, pas flutter_map.
abstract final class DeckMapTiles {
  static const urlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const attribution =
      'OpenFreeMap © OpenMapTiles · Data © OpenStreetMap';
  static const userAgentPackageName = 'io.datar0w.datar0w';

  static TileLayer layer() => TileLayer(
        urlTemplate: urlTemplate,
        userAgentPackageName: userAgentPackageName,
      );
}
