import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../calendar/catalog.dart';
import '../../calendar/loisir_store.dart';
import '../../calendar/models.dart';
import '../../identity/controller.dart';
import '../../identity/models.dart';
import '../../maps/deck_tiles.dart';
import '../../router.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

class EventSheetScreen extends ConsumerStatefulWidget {
  const EventSheetScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventSheetScreen> createState() => _EventSheetScreenState();
}

class _EventSheetScreenState extends ConsumerState<EventSheetScreen> {
  final _temps = TextEditingController();
  final _place = TextEditingController();

  @override
  void dispose() {
    _temps.dispose();
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rower = ref.watch(identityProvider).activeRower;
    return FutureBuilder<CalendarCatalog>(
      future: CalendarCatalog.load(),
      builder: (context, snap) {
        final e = snap.data?.eventById(widget.eventId);
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
              if (blocked)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Licence loisir — compétition réservée à une licence compétition.',
                    style: TextStyle(color: DeckColors.amber),
                  ),
                ),
              if (e.definitionLoisir != null)
                Text(
                  e.definitionLoisir!,
                  style: const TextStyle(color: DeckColors.label, height: 1.3),
                ),
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
              ],
              if (e.url != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => launchUrl(Uri.parse(e.url!)),
                  child: const Text('INSCRIPTION (LIEN)'),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'SIGNALER MA PARTICIPATION',
                style: TextStyle(
                  color: DeckColors.label,
                  fontSize: 11,
                  letterSpacing: 1.1,
                ),
              ),
              TextField(
                controller: _temps,
                decoration:
                    const InputDecoration(labelText: 'Temps (si course)'),
              ),
              TextField(
                controller: _place,
                decoration:
                    const InputDecoration(labelText: 'Classement loisir'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: rower == null
                    ? null
                    : () async {
                        await LoisirStore().add(
                          ParticipationLoisir(
                            id: 'p-${DateTime.now().millisecondsSinceEpoch}',
                            eventId: e.id,
                            rowerId: rower.id,
                            type: e.type,
                            date: e.start,
                            tempsCourse: _temps.text.trim().isEmpty
                                ? null
                                : _temps.text.trim(),
                            classementLoisir: _place.text.trim().isEmpty
                                ? null
                                : _place.text.trim(),
                            distanceKm: e.distanceKm,
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Participation notée')),
                          );
                        }
                      },
                child: const Text('J’AI PARTICIPÉ'),
              ),
            ],
          ),
        );
      },
    );
  }
}
