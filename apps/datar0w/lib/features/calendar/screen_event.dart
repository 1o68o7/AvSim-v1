import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../calendar/catalog.dart';
import '../../identity/controller.dart';
import '../../identity/models.dart';
import '../../maps/deck_tiles.dart';
import '../../router.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

class EventSheetScreen extends ConsumerWidget {
  const EventSheetScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rower = ref.watch(identityProvider).activeRower;
    return FutureBuilder<CalendarCatalog>(
      future: CalendarCatalog.load(),
      builder: (context, snap) {
        final e = snap.data?.eventById(eventId);
        if (e == null) {
          return DeckScaffold(
            title: 'ÉVÉNEMENT',
            leading: TextButton(
              onPressed: () => context.go(AppRoutes.calendar),
              child: const Text('Retour'),
            ),
            body: const Center(child: Text('Inconnu')),
          );
        }
        final al = rower?.level == RowerLevel.loisir;
        final blocked = al && e.licenceRequise == 'AC' && !e.openToLoisir;
        return DeckScaffold(
          title: e.typeLabel.toUpperCase(),
          subtitle: e.city,
          leading: TextButton(
            onPressed: () => context.go(AppRoutes.calendar),
            child: const Text('Retour'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                e.start.toIso8601String().split('T').first,
                style: const TextStyle(color: DeckColors.muted),
              ),
              if (blocked)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Licence loisir — compétition réservée à une licence compétition.',
                    style: TextStyle(color: DeckColors.amber),
                  ),
                )
              else if (al)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Ta licence loisir t’autorise cet événement.',
                    style: TextStyle(color: DeckColors.tribord),
                  ),
                ),
              if (e.definitionLoisir != null) ...[
                const SizedBox(height: 8),
                Text(
                  e.definitionLoisir!,
                  style: const TextStyle(color: DeckColors.label, height: 1.3),
                ),
              ],
              if (e.lat != null && e.lon != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 160,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(e.lat!, e.lon!),
                      initialZoom: 11,
                    ),
                    children: [
                      DeckMapTiles.layer(),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(e.lat!, e.lon!),
                            width: 24,
                            height: 24,
                            child: const Icon(
                              Icons.place,
                              color: DeckColors.amber,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Text(
                  DeckMapTiles.attribution,
                  style: TextStyle(color: DeckColors.muted, fontSize: 10),
                ),
              ],
              if (e.url != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => launchUrl(Uri.parse(e.url!)),
                  child: const Text('INSCRIPTION (LIEN)'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
