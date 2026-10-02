import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../calendar/catalog.dart';
import '../../maps/deck_tiles.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import '../../widgets/deck_widgets.dart';

/// DR-45 — Plans d'eau (Stitch).
class WatersScreen extends StatelessWidget {
  const WatersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeckScaffold(
      title: 'Plans d’eau',
      subtitle: 'Cartographie & bassins · catalogue local',
      body: FutureBuilder<CalendarCatalog>(
        future: CalendarCatalog.load(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final waters = snap.data!.waters;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: waters.length,
            itemBuilder: (context, i) {
              final w = waters[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: DeckColors.surface,
                  borderRadius: DeckRadii.cardAll,
                  child: InkWell(
                    borderRadius: DeckRadii.cardAll,
                    onTap: w.lat == null
                        ? null
                        : () => showDialog<void>(
                              context: context,
                              builder: (ctx) => Dialog(
                                backgroundColor: DeckColors.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: DeckRadii.cardAll,
                                ),
                                child: SizedBox(
                                  height: 260,
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          14, 12, 8, 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                w.name,
                                                style: const TextStyle(
                                                  fontFamily: DeckType.ui,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              icon: const Icon(Icons.close),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: FlutterMap(
                                          options: MapOptions(
                                            initialCenter:
                                                LatLng(w.lat!, w.lon!),
                                            initialZoom: 12,
                                          ),
                                          children: [
                                            DeckMapTiles.layer(),
                                            MarkerLayer(
                                              markers: [
                                                Marker(
                                                  point: LatLng(
                                                    w.lat!,
                                                    w.lon!,
                                                  ),
                                                  width: 24,
                                                  height: 24,
                                                  child: const Icon(
                                                    Icons.water,
                                                    color: DeckColors.volt,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: DeckRadii.cardAll,
                        border: Border.all(color: DeckColors.hairline),
                      ),
                      child: Row(
                        children: [
                          const DeckIconBox(
                            icon: Icons.water,
                            accent: true,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w.name,
                                  style: const TextStyle(
                                    fontFamily: DeckType.ui,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  '${w.city ?? '—'} · ${w.type}',
                                  style: const TextStyle(
                                    fontFamily: DeckType.ui,
                                    color: DeckColors.label,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (w.lat != null)
                            const Icon(
                              Icons.map_outlined,
                              color: DeckColors.volt,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
