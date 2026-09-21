import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../calendar/catalog.dart';
import '../../maps/deck_tiles.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

class WatersScreen extends StatelessWidget {
  const WatersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeckScaffold(
      title: 'PLANS D’EAU',
      subtitle: 'catalogue local',
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
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(w.name),
                subtitle: Text('${w.city ?? '—'} · ${w.type}'),
                onTap: w.lat == null
                    ? null
                    : () => showDialog<void>(
                          context: context,
                          builder: (ctx) => Dialog(
                            backgroundColor: DeckColors.surface,
                            child: SizedBox(
                              height: 240,
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: LatLng(w.lat!, w.lon!),
                                  initialZoom: 12,
                                ),
                                children: [
                                  DeckMapTiles.layer(),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: LatLng(w.lat!, w.lon!),
                                        width: 24,
                                        height: 24,
                                        child: const Icon(
                                          Icons.water,
                                          color: DeckColors.amber,
                                        ),
                                      ),
                                    ],
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
