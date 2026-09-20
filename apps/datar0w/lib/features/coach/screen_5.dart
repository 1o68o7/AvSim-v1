import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../identity/controller.dart';
import '../../identity/format.dart';
import '../../identity/models.dart';
import '../../router.dart';
import '../../session/boat_config.dart';
import '../../session/heel.dart';
import '../../session/live_hub.dart';
import '../../session/model.dart';
import '../../session/rower_orientation.dart';
import '../../session/store.dart';
import '../../session/summary.dart';
import '../../maps/deck_tiles.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_widgets.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(liveHubProvider.notifier).startCoachPoll();
      _maybeLoadFile();
    });
  }

  @override
  void dispose() {
    ref.read(liveHubProvider.notifier).stopCoachPoll();
    super.dispose();
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
    if (hub.coachFromApi) return;
    if (hub.logging && hub.sessionId == id) return;
    final samples = await SessionStore.loadSamples(id);
    if (mounted) setState(() => _fileSamples = samples);
  }

  @override
  Widget build(BuildContext context) {
    final hub = ref.watch(liveHubProvider);
    final apiLive = hub.coachFromApi && hub.remoteSample != null;
    final live = !hub.coachFromApi &&
        hub.logging &&
        hub.sessionId != null &&
        (hub.coachSessionId == null || hub.coachSessionId == hub.sessionId);
    final samples = live
        ? ref.read(liveHubProvider.notifier).recorded
        : _fileSamples;
    final last = apiLive
        ? hub.remoteSample
        : (samples.isEmpty ? null : samples.last);
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
    final coord = (lat != null && lon != null)
        ? '${lat.toStringAsFixed(4)}°, ${lon.toStringAsFixed(4)}°'
        : '—';
    final giteLabel = giteUi == null
        ? '—'
        : '${giteUi >= 0 ? '+' : ''}${giteUi.toStringAsFixed(1)}°';
    final cad = live ? hub.cadenceSpm : last?.cadenceSpm;

    return Scaffold(
      backgroundColor: DeckColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            HeelBanner(alert: alert),
            SizedBox(
              height: 32,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const DataR0wMark(compact: true),
                    const SizedBox(width: 8),
                    const Text(
                      '/  COACH LIVE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Spacer(),
                    DeckStatusChip(
                      label: live || apiLive ? 'LIVE' : 'FICHIER',
                      ok: live || apiLive,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      () {
                        final boat = ref.watch(boatConfigProvider);
                        final tag = boat.info.code.toUpperCase();
                        final seats = boat.seats > 1
                            ? '  ·  ${boat.seats} sièges'
                            : '';
                        return hub.code == null
                            ? tag
                            : '$tag  ${hub.code}$seats';
                      }(),
                      style: const TextStyle(
                        color: DeckColors.label,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: DeckColors.hairline),
            Builder(
              builder: (context) {
                final ident = ref.watch(identityProvider);
                final boatId = ident.assignments.isEmpty
                    ? null
                    : ident.assignments.last.boatId;
                final crew = boatId == null
                    ? <Assignment>[]
                    : ident.assignmentsForBoat(boatId);
                if (crew.isEmpty) return const SizedBox.shrink();
                final bits = [
                  for (final a in crew)
                    '${a.role == 'cox' ? 'barreur' : 's${a.seatIndex}'} '
                    '${ident.rowerById(a.rowerId)?.displayName ?? ''}'
                    '${a.role == 'cox' ? '' : ' ${assignmentChip(a)}'}',
                ];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  child: Text(
                    bits.join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DeckColors.label,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: center,
                            initialZoom: 15,
                            backgroundColor: DeckColors.bg,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: DeckMapTiles.urlTemplate,
                              userAgentPackageName:
                                  DeckMapTiles.userAgentPackageName,
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
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: DeckColors.bg.withValues(alpha: 0.9),
                              border: Border.all(color: DeckColors.hairline),
                            ),
                            child: const Text(
                              '▲ N   NORD EN HAUT',
                              style: TextStyle(
                                color: DeckColors.amber,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            color: DeckColors.bg.withValues(alpha: 0.92),
                            child: Text(
                              'TRACE GPS  ·  COORD $coord  ·  sol — pas eau',
                              style: const TextStyle(
                                color: DeckColors.label,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, color: DeckColors.hairline),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: SingleChildScrollView(
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              DeckStatusChip(
                                label: 'RÉF. RAMEUR',
                                ok: true,
                              ),
                              const Spacer(),
                              Text(
                                'DIST  ${(dist / 1000).toStringAsFixed(3)} km',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: InstrumentPod(
                                  label: 'CADENCE',
                                  value: cad == null
                                      ? '—'
                                      : cad.toStringAsFixed(0),
                                  unit: cad == null
                                      ? 'SPM  ·  COUP/MIN'
                                      : 'ESTIM. TEL  ·  SPM',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InstrumentPod(
                                  label: 'V. SOL (GPS)',
                                  value: sog == null
                                      ? '—'
                                      : sog.toStringAsFixed(1),
                                  unit: 'M/S  ·  SOL — PAS EAU',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          InstrumentPod(
                            label: 'GÎTE INSTANTANÉE',
                            value: giteLabel,
                            child: Column(
                              children: [
                                const HeelLabels(),
                                HeelGauge(giteDeg: giteUi ?? 0),
                                const Text(
                                  'TOLÉRANCE ±3.0°  ·  RÉF. RAMEUR',
                                  style: TextStyle(
                                    color: DeckColors.label,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: (live ||
                                    apiLive ||
                                    hub.coachSessionId != null)
                                ? () =>
                                    ref.read(liveHubProvider.notifier).annotate()
                                : null,
                            child: const Text('ANNOTER'),
                          ),
                          TextButton(
                            onPressed: () =>
                                context.go(AppRoutes.coachReplay),
                            child: const Text('REPLAY'),
                          ),
                          TextButton(
                            onPressed: () => context.go(AppRoutes.profile),
                            child: const Text('RETOUR'),
                          ),
                        ],
                      ),
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
