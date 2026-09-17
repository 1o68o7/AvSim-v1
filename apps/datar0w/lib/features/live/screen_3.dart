import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final gite = s.displayGiteDeg ?? s.giteDeg;
    final alert =
        s.tareOk ? heelAlertFor(gite) : HeelAlert.none;
    if (alert != _lastAlert) {
      if (_lastAlert == HeelAlert.none && alert != HeelAlert.none) {
        HapticFeedback.vibrate();
      }
      _lastAlert = alert;
    }

    return Scaffold(
      backgroundColor: DeckColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HeelBanner(alert: alert),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final landscape = constraints.maxWidth > 640;
                  if (landscape) {
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 5, child: _metricsColumn(s, expand: true)),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: _giteColumn(gite),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 128,
                            child: _systemColumn(s, expand: true),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      SizedBox(height: 280, child: _metricsColumn(s, expand: true)),
                      const SizedBox(height: 8),
                      _giteColumn(gite),
                      const SizedBox(height: 8),
                      SizedBox(height: 220, child: _systemColumn(s, expand: true)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricsColumn(LiveHubState s, {required bool expand}) {
    return Column(
      children: [
        Expanded(
          child: InstrumentPod(
            label: 'CADENCE',
            value: s.cadenceSpm == null
                ? '—'
                : s.cadenceSpm!.toStringAsFixed(0),
            unit: s.cadenceSpm == null
                ? 'COUPS/MIN'
                : 'ESTIM. TEL  ·  COUPS/MIN',
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: InstrumentPod(
            label: 'VITESSE SOL',
            value: s.sog == null ? '—' : s.sog!.toStringAsFixed(1),
            unit: 'M/S  ·  SOL — PAS EAU',
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: InstrumentPod(
            label: 'DISTANCE',
            value: (s.distM / 1000).toStringAsFixed(2),
            unit: 'KM  ·  SKF·1X // LIVE',
          ),
        ),
      ],
    );
  }

  Widget _giteColumn(double? gite) {
    return InstrumentPod(
      label: 'GÎTE',
      value: gite == null ? 'tare' : '${gite.toStringAsFixed(1)}°',
      child: Column(
        children: [
          const Text(
            'TOLÉRANCE ±3.0°  ·  RÉF. RAMEUR',
            style: TextStyle(color: DeckColors.label, fontSize: 9),
          ),
          const SizedBox(height: 4),
          const HeelLabels(),
          HeelGauge(giteDeg: gite ?? 0),
          const SizedBox(height: 4),
          Text(
            gite == null
                ? 'TARE REQUISE'
                : (gite >= 0
                    ? 'TRIBORD  +${gite.toStringAsFixed(1)}°'
                    : 'BÂBORD  ${gite.toStringAsFixed(1)}°'),
            style: TextStyle(
              color: gite == null
                  ? DeckColors.label
                  : (gite >= 0 ? DeckColors.tribord : DeckColors.babord),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _systemColumn(LiveHubState s, {required bool expand}) {
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
          unit: 'SKF·1X',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DeckStatusChip(
                label: s.gpsLost ? 'GPS perdu' : 'GPS',
                ok: !s.gpsLost && s.locationOk,
              ),
              const SizedBox(height: 6),
              DeckStatusChip(
                label: 'IMU',
                ok: s.rollDeg != null && s.tareOk,
              ),
              const SizedBox(height: 6),
              DeckStatusChip(label: s.net, ok: s.net != 'hors ligne'),
              const SizedBox(height: 6),
              DeckStatusChip(
                label: '${s.batt ?? '—'} %',
                ok: (s.batt ?? 0) > 20,
              ),
            ],
          ),
        ),
        const Spacer(),
        stop,
      ],
    );
  }
}
