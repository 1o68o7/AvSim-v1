import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../router.dart';
import '../../session/heel.dart';
import '../../session/live_hub.dart';
import '../../session/model.dart';
import '../../session/rower_orientation.dart';
import '../../session/store.dart';
import '../../session/summary.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/heel_banner.dart';
import '../../widgets/heel_gauge.dart';

class CoachLiveScreen extends ConsumerStatefulWidget {
  const CoachLiveScreen({super.key});

  @override
  ConsumerState<CoachLiveScreen> createState() => _CoachLiveScreenState();
}

class _CoachLiveScreenState extends ConsumerState<CoachLiveScreen> {
  List<SessionSample> _fileSamples = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadFile());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref
        .read(liveHubProvider.notifier)
        .setDisplayRotation(displayRotationDegOf(context));
  }

  Future<void> _maybeLoadFile() async {
    final hub = ref.read(liveHubProvider);
    final id = hub.coachSessionId ?? hub.sessionId;
    if (id == null) return;
    if (hub.logging && hub.sessionId == id) return;
    final samples = await SessionStore.loadSamples(id);
    if (mounted) setState(() => _fileSamples = samples);
  }

  @override
  Widget build(BuildContext context) {
    final hub = ref.watch(liveHubProvider);
    final live = hub.logging &&
        hub.sessionId != null &&
        (hub.coachSessionId == null || hub.coachSessionId == hub.sessionId);
    final samples = live
        ? ref.read(liveHubProvider.notifier).recorded
        : _fileSamples;
    final last = samples.isEmpty ? null : samples.last;
    final giteUi = live
        ? (hub.displayGiteDeg ?? hub.giteDeg)
        : last?.giteDeg;
    final alert = live
        ? (hub.tareOk ? heelAlertFor(giteUi) : HeelAlert.none)
        : heelAlertFor(giteUi);
    final sog = live ? hub.sog : last?.sog;
    final dist = live ? hub.distM : last?.distM ?? 0;
    final lat = live ? hub.lat : last?.lat;
    final lon = live ? hub.lon : last?.lon;
    final segs = gpsSegments(samples);
    final center = (lat != null && lon != null)
        ? LatLng(lat, lon)
        : (segs.isNotEmpty ? segs.first.first : const LatLng(48.86, 2.35));

    return Scaffold(
      backgroundColor: DeckColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            HeelBanner(alert: alert),
            Expanded(
              child: Row(
          children: [
            Expanded(
              flex: 6,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 15,
                  backgroundColor: DeckColors.bg,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'io.datar0w.datar0w',
                  ),
                  PolylineLayer(
                    polylines: [
                      for (final seg in segs)
                        if (seg.length >= 2)
                          Polyline(
                            points: seg,
                            color: DeckColors.amber,
                            strokeWidth: 3,
                          ),
                    ],
                  ),
                  if (lat != null && lon != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(lat, lon),
                          width: 14,
                          height: 14,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: DeckColors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'COACH LIVE',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          live ? 'LIVE' : 'FICHIER',
                          style: const TextStyle(
                            color: DeckColors.amber,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'réf. rameur  ·  sol — pas eau',
                      style: TextStyle(color: DeckColors.label, fontSize: 10),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'CADENCE  —',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'V SOL  ${sog == null ? '—' : '${sog.toStringAsFixed(2)} m/s'}',
                    ),
                    Text('DIST  ${(dist / 1000).toStringAsFixed(3)} km'),
                    Text(
                      'GÎTE  ${giteUi == null ? '—' : '${giteUi.toStringAsFixed(1)}°'}',
                    ),
                    const SizedBox(height: 8),
                    const HeelLabels(),
                    HeelGauge(giteDeg: giteUi ?? 0),
                    const Spacer(),
                    FilledButton(
                      onPressed: live
                          ? () => ref.read(liveHubProvider.notifier).annotate()
                          : null,
                      child: const Text('ANNOTER'),
                    ),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.coachReplay),
                      child: const Text('Replay'),
                    ),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.profile),
                      child: const Text('Retour'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
            ),
          ],
        ),
      ),
    );
  }
}
