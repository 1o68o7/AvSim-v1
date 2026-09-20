import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../live/layout_controller.dart';
import '../../live/layout_model.dart';
import '../../maps/deck_tiles.dart';
import '../../router.dart';
import '../../session/double_press_stop.dart';
import '../../session/heel.dart';
import '../../session/live_hub.dart';
import '../../session/rower_orientation.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/heel_banner.dart';
import '../../widgets/heel_gauge.dart';
import '../../widgets/deck_widgets.dart';

class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  final _stop = DoublePressStop();
  bool _stopArmed = false;
  HeelAlert _lastAlert = HeelAlert.none;
  bool _panel = false;

  @override
  void initState() {
    super.initState();
    unawaited(lockRowerLandscape());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref
        .read(liveHubProvider.notifier)
        .setDisplayRotation(displayRotationDegOf(context));
  }

  Future<void> _onStop() async {
    final done = _stop.press();
    if (!done) {
      setState(() => _stopArmed = true);
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _stopArmed = false);
      });
      return;
    }
    await ref.read(liveHubProvider.notifier).stop();
    if (!mounted) return;
    context.go(AppRoutes.quai);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(liveHubProvider);
    final layout = ref.watch(liveLayoutProvider);
    final gite = s.displayGiteDeg ?? s.giteDeg;
    final alert = s.tareOk ? heelAlertFor(gite) : HeelAlert.none;
    if (alert != _lastAlert) {
      if (_lastAlert == HeelAlert.none && alert != HeelAlert.none) {
        HapticFeedback.vibrate();
      }
      _lastAlert = alert;
    }
    final mapOk = layout.mapEnabled &&
        s.net != 'hors ligne' &&
        s.lat != null &&
        s.lon != null &&
        !s.gpsLost;
    final effective = layout.preset == LivePreset.navigation && !mapOk
        ? [LiveBlock.gite, LiveBlock.vsol]
        : layout.visible;

    return Scaffold(
      backgroundColor: DeckColors.bg,
      body: HeelAlertOverlay(
        alert: alert,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _topBar(layout, s),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _blocksColumn(s, gite, effective, mapOk),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 128,
                          child: _systemColumn(s),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragEnd: (_) async {
                            HapticFeedback.lightImpact();
                            await ref.read(liveLayoutProvider.notifier).cycle();
                          },
                          child: const SizedBox(width: 60),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_panel) _customize(layout),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(RowerLayout layout, LiveHubState s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          if (s.hrBpm != null)
            Text(
              '♥ ${s.hrBpm}',
              style: TextStyle(
                color: (s.hrBpm ?? 0) > 180
                    ? DeckColors.babord
                    : DeckColors.tribord,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            const Text(
              '♥ —',
              style: TextStyle(color: DeckColors.muted, fontSize: 12),
            ),
          if (s.spo2Pct != null) ...[
            const SizedBox(width: 8),
            Text(
              'SpO2 ${s.spo2Pct}%',
              style: const TextStyle(color: DeckColors.label, fontSize: 12),
            ),
          ],
          const Spacer(),
          Semantics(
            button: true,
            label: 'Preset ${layout.preset.label}',
            child: GestureDetector(
              onTap: () => setState(() => _panel = !_panel),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: DeckColors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blocksColumn(
    LiveHubState s,
    double? gite,
    List<LiveBlock> blocks,
    bool mapOk,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Expanded(child: _block(s, gite, blocks[i], mapOk)),
          ],
        ],
      ),
    );
  }

  Widget _block(LiveHubState s, double? gite, LiveBlock b, bool mapOk) {
    switch (b) {
      case LiveBlock.gite:
        return _giteColumn(gite);
      case LiveBlock.vsol:
        return InstrumentPod(
          label: 'VITESSE SOL',
          value: s.sog == null ? '—' : s.sog!.toStringAsFixed(1),
          unit: 'M/S  ·  SOL — PAS EAU',
        );
      case LiveBlock.distance:
        return InstrumentPod(
          label: 'DISTANCE',
          value: (s.distM / 1000).toStringAsFixed(2),
          unit: 'KM',
        );
      case LiveBlock.spm:
        return InstrumentPod(
          label: 'CADENCE',
          value: s.cadenceSpm == null ? '—' : s.cadenceSpm!.toStringAsFixed(0),
          unit: 'COUPS/MIN',
        );
      case LiveBlock.hr:
        return InstrumentPod(
          label: 'FC',
          value: s.hrBpm?.toString() ?? '—',
          unit: 'BPM  ·  INFORMATIF',
        );
      case LiveBlock.spo2:
        return InstrumentPod(
          label: 'SPO2',
          value: s.spo2Pct?.toString() ?? '—',
          unit: '%  ·  APPROX.',
        );
      case LiveBlock.map:
        return mapOk ? _miniMap(s) : _giteColumn(gite);
    }
  }

  Widget _miniMap(LiveHubState s) {
    final pts = ref
        .read(liveHubProvider.notifier)
        .recorded
        .where((e) => e.lat != null && e.lon != null)
        .map((e) => LatLng(e.lat!, e.lon!))
        .toList();
    final center = LatLng(s.lat!, s.lon!);
    return InstrumentPod(
      label: 'CARTE',
      value: 'N',
      unit: DeckMapTiles.attribution,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 14,
        ),
        children: [
          DeckMapTiles.layer(),
          if (pts.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(points: pts, color: DeckColors.amber, strokeWidth: 2),
              ],
            ),
          MarkerLayer(
            markers: [
              Marker(
                point: center,
                width: 16,
                height: 16,
                child: const Icon(Icons.circle, size: 10, color: DeckColors.amber),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _giteColumn(double? gite) {
    return InstrumentPod(
      label: 'GÎTE',
      value: gite == null ? 'tare' : '${gite.toStringAsFixed(1)}°',
      child: Column(
        children: [
          const HeelLabels(),
          HeelGauge(giteDeg: gite ?? 0),
        ],
      ),
    );
  }

  Widget _systemColumn(LiveHubState s) {
    final stop = OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: _stopArmed ? DeckColors.alert : DeckColors.label,
        side: BorderSide(
          color: _stopArmed ? DeckColors.alert : DeckColors.hairline,
        ),
        minimumSize: const Size(110, 52),
      ),
      onPressed: _onStop,
      child: Text(
        _stopArmed ? 'STOP\nRETOUCHER' : 'STOP\nTOUCHER 2×',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, height: 1.2),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InstrumentPod(
          label: 'SYSTÈME',
          value: s.code ?? '—',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DeckStatusChip(
                label: s.gpsLost ? 'GPS perdu' : 'GPS',
                ok: !s.gpsLost && s.locationOk,
              ),
              const SizedBox(height: 6),
              DeckStatusChip(label: 'IMU', ok: s.rollDeg != null && s.tareOk),
              const SizedBox(height: 6),
              DeckStatusChip(label: s.net, ok: s.net != 'hors ligne'),
            ],
          ),
        ),
        const Spacer(),
        stop,
      ],
    );
  }

  Widget _customize(RowerLayout layout) {
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              color: DeckColors.surface,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('PERSONNALISER'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final p in [
                        LivePreset.securite,
                        LivePreset.performance,
                        LivePreset.cardio,
                        LivePreset.navigation,
                        LivePreset.complet,
                      ])
                        ChoiceChip(
                          label: Text(p.label),
                          selected: layout.preset == p,
                          onSelected: (_) async {
                            await ref
                                .read(liveLayoutProvider.notifier)
                                .setPreset(p);
                            setState(() => _panel = false);
                          },
                        ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => setState(() => _panel = false),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
