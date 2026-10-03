import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../session/boat_config.dart';
import '../../session/double_press_stop.dart';
import '../../session/heel.dart';
import '../../session/live_hub.dart';
import '../../session/rower_orientation.dart';
import '../../session/session_sync.dart';
import '../../session/tel_cadence.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import '../../widgets/deck_widgets.dart';
import '../../widgets/heel_banner.dart';
import '../../widgets/heel_gauge.dart';
import '../../widgets/live_affordances.dart';

/// Paysage réduit — pas de gros SPM inventé. Un tél = hub bateau (IMU/GPS)
/// ou poll API du tel qui logge.
class CoxLiveScreen extends ConsumerStatefulWidget {
  const CoxLiveScreen({super.key});

  @override
  ConsumerState<CoxLiveScreen> createState() => _CoxLiveScreenState();
}

class _CoxLiveScreenState extends ConsumerState<CoxLiveScreen> {
  final _stop = DoublePressStop();
  bool _stopArmed = false;
  HeelAlert _lastAlert = HeelAlert.none;
  LiveHub? _hub;

  @override
  void initState() {
    super.initState();
    unawaited(lockRowerLandscape());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _hub = ref.read(liveHubProvider.notifier);
      _hub!.startCoachPoll();
    });
  }

  @override
  void dispose() {
    _hub?.stopCoachPoll();
    super.dispose();
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
      hapticStopArmed();
      setState(() => _stopArmed = true);
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _stopArmed = false);
      });
      return;
    }
    final stopped = await ref.read(liveHubProvider.notifier).stop();
    if (!mounted) return;
    context.go(AppRoutes.quai);
    final sid = stopped.sessionId;
    if (sid != null) {
      unawaited(
        SessionSync.autosyncAfterStop(sid, dir: stopped.directory),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(liveHubProvider);
    final boat = ref.watch(boatConfigProvider);
    final remote = s.coachFromApi ? s.remoteSample : null;
    final gite = remote?.giteDeg ?? s.displayGiteDeg ?? s.giteDeg;
    final sog = remote?.sog ?? s.sog;
    final dist = remote?.distM ?? s.distM;
    final alert = s.tareOk || remote != null
        ? heelAlertFor(gite)
        : HeelAlert.none;
    if (alert != _lastAlert) {
      if (_lastAlert == HeelAlert.none && alert != HeelAlert.none) {
        HapticFeedback.vibrate();
      }
      _lastAlert = alert;
    }
    final tag = boat.info.code.toUpperCase();
    final cadV = formatCadenceValue(s.cadenceSpm, s.cadenceSrc);
    final cadApprox = cadenceApproxLabel(s.cadenceSrc);
    final cadLine = cadV == '—'
        ? 'Cadence —'
        : (cadApprox == null ? 'Cadence $cadV' : 'Cadence $cadV · $cadApprox');

    return Scaffold(
      backgroundColor: DeckColors.bg,
      body: HeelAlertOverlay(
        alert: alert,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
            children: [
              DeckSessionHeader(
                title: 'BARREUR  $tag',
                trailing: [
                  DeckStatusChip(label: 'Gîte', ok: gite != null),
                  const SizedBox(width: 8),
                  DeckStatusChip(
                    label: boat.coxPosition == CoxPosition.front
                        ? 'pos. avant'
                        : 'pos. arrière',
                    ok: true,
                  ),
                ],
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: InstrumentPod(
                        label: 'Vitesse',
                        value: sog == null ? '—' : sog.toStringAsFixed(1),
                        unit: 'm/s',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InstrumentPod(
                        label: 'Distance',
                        value: (dist / 1000).toStringAsFixed(2),
                        unit: 'km',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: InstrumentPod(
                        label: 'Gîte',
                        value: gite == null
                            ? 'tare'
                            : '${gite.toStringAsFixed(1)}°',
                        child: Column(
                          children: [
                            const HeelLabels(perspective: HeelPerspective.cox),
                            HeelGauge(
                              giteDeg: gite ?? 0,
                              perspective: HeelPerspective.cox,
                            ),
                            Text(
                              cadLine,
                              style: const TextStyle(
                                color: DeckColors.label,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DeckStatusChip(
                            label: s.gpsLost ? 'GPS perdu' : 'GPS',
                            ok: !s.gpsLost,
                          ),
                          const SizedBox(height: 8),
                          DeckStatusChip(label: s.net, ok: s.net != 'hors ligne'),
                          const Spacer(),
                          OutlinedButton(
                            onPressed: _onStop,
                            child: Text(
                              _stopArmed ? 'STOP\nRETOUCHER' : 'STOP\n2×',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, height: 1.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
              StopArmedBanner(visible: _stopArmed),
            ],
          ),
        ),
      ),
    );
  }
}
