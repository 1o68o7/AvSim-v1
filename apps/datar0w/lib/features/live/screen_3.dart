import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../live/layout_controller.dart';
import '../../live/layout_model.dart';
import '../../identity/device_store.dart';
import '../../identity/devices.dart';
import '../../router.dart';
import '../../session/boat_config.dart';
import '../../session/double_press_stop.dart';
import '../../session/heel.dart';
import '../../session/live_hub.dart';
import '../../session/rower_orientation.dart';
import '../../session/session_sync.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/heel_gauge.dart';
import '../../widgets/live_affordances.dart';

/// Live rameur — DR-52 Gîte paysage (Stitch cockpit 844×390).
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
  String _patchChip = 'patch —';

  @override
  void initState() {
    super.initState();
    unawaited(lockRowerLandscape());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPatch());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref
        .read(liveHubProvider.notifier)
        .setDisplayRotation(displayRotationDegOf(context));
  }

  Future<void> _loadPatch() async {
    try {
      final list = await ref.read(deviceStoreProvider).list();
      final p = list.where((d) => d.isPatch);
      if (!mounted) return;
      setState(() {
        _patchChip = p.isEmpty
            ? 'patch —'
            : 'patch ${p.first.patchLink?.label ?? 'pairé'}';
      });
    } catch (_) {
      if (mounted) setState(() => _patchChip = 'patch —');
    }
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
    final layout = ref.watch(liveLayoutProvider);
    final boat = ref.watch(boatConfigProvider);
    final mode = boat.sessionMode;
    final gite = s.displayGiteDeg ?? s.giteDeg;
    final alert = s.tareOk ? heelAlertFor(gite) : HeelAlert.none;
    if (alert != _lastAlert) {
      if (_lastAlert == HeelAlert.none && alert != HeelAlert.none) {
        HapticFeedback.vibrate();
      }
      _lastAlert = alert;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _Dr52AlertBar(
                  alert: alert,
                  giteDeg: gite,
                  sessionId: s.code,
                  layoutButton: LiveLayoutButton(
                    onPressed: () => setState(() => _panel = !_panel),
                  ),
                ),
                if (mode == SessionMode.competition)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 2, 8, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'MODE COMPÉTITION — tel au quai',
                        style: TextStyle(
                          color: DeckColors.volt,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _LeftColumn(
                          s: s,
                          boat: boat,
                          patchChip: _patchChip,
                        ),
                      ),
                      Container(width: 1, color: const Color(0xFF454934)),
                      Expanded(
                        flex: 6,
                        child: _CenterColumn(gite: gite, alert: alert),
                      ),
                      Container(width: 1, color: const Color(0xFF454934)),
                      Expanded(
                        flex: 3,
                        child: _RightColumn(
                          s: s,
                          stopArmed: _stopArmed,
                          onStop: _onStop,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_panel) _customize(layout),
            StopArmedBanner(visible: _stopArmed),
          ],
        ),
      ),
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
                  const SizedBox(height: 8),
                  Text(
                    'DR-52 cockpit fixe — presets conservés pour tare / coach.',
                    style: DeckType.uiLabel(size: 12),
                    textAlign: TextAlign.center,
                  ),
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

// —— Bandeau alerte Volt (Stitch header h-9) ——

class _Dr52AlertBar extends StatelessWidget {
  const _Dr52AlertBar({
    required this.alert,
    required this.giteDeg,
    required this.sessionId,
    required this.layoutButton,
  });

  final HeelAlert alert;
  final double? giteDeg;
  final String? sessionId;
  final Widget layoutButton;

  @override
  Widget build(BuildContext context) {
    final hot = alert != HeelAlert.none;
    final g = giteDeg;
    final side = alert == HeelAlert.tribord
        ? 'TRIBORD'
        : alert == HeelAlert.babord
            ? 'BÂBORD'
            : null;
    final gStr = g == null
        ? '—'
        : '${g >= 0 ? '+' : ''}${g.toStringAsFixed(1)}°';
    final msg = hot
        ? 'ALERTE DÉRIVE // GÎTE : TROP $side ($gStr)'
        : 'LIVE';
    final id = sessionId == null || sessionId!.isEmpty
        ? 'HUD'
        : 'ID: ${sessionId!}';

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: hot ? DeckColors.volt : DeckColors.surface,
                border: const Border(
                  bottom: BorderSide(color: Color(0xFF454934)),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  if (hot)
                    const Icon(Icons.warning, size: 18, color: DeckColors.onVolt),
                  if (hot) const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      msg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: DeckType.mono,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: hot ? DeckColors.onVolt : DeckColors.text,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (hot) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: DeckColors.onVolt,
                        borderRadius: DeckRadii.chipAll,
                      ),
                      child: Text(
                        'SEUIL EXCÉDÉ',
                        style: DeckType.labelMono(
                          color: DeckColors.volt,
                          size: 10,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    id,
                    style: DeckType.labelMono(
                      color: hot
                          ? DeckColors.onVolt.withValues(alpha: 0.9)
                          : DeckColors.label,
                      size: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ColoredBox(
            color: hot ? DeckColors.volt : DeckColors.surface,
            child: layoutButton,
          ),
        ],
      ),
    );
  }
}

// —— Colonne gauche : cadence / vitesse / distance ——

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({
    required this.s,
    required this.boat,
    required this.patchChip,
  });

  final LiveHubState s;
  final BoatConfig boat;
  final String patchChip;

  @override
  Widget build(BuildContext context) {
    final spm = s.cadenceSpm;
    final sog = s.sog;
    final kmh = sog == null ? null : sog * 3.6;
    final split = _split500(sog);
    final km = s.distM / 1000;
    final classLive = '${boat.info.code.toUpperCase()} LIVE';

    return ColoredBox(
      color: const Color(0xFF131313),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Pod(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Cadence',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DeckType.uiLabel(color: DeckColors.label),
                        ),
                      ),
                      if (spm != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: DeckColors.tribord.withValues(alpha: 0.12),
                            borderRadius: DeckRadii.chipAll,
                          ),
                          child: Text(
                            'SPM',
                            style: DeckType.labelMono(
                              color: DeckColors.tribord,
                              size: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          spm == null ? '—' : spm.toStringAsFixed(0),
                          style: DeckType.metric(
                            size: 44,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'COUPS/MIN',
                              style: DeckType.labelMono(size: 10),
                            ),
                            Text(
                              patchChip,
                              style: DeckType.labelMono(
                                color: DeckColors.volt.withValues(alpha: 0.85),
                                size: 9,
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
            const SizedBox(height: 6),
            _Pod(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Vitesse fond',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DeckType.uiLabel(color: DeckColors.label, size: 12),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: DeckColors.surfaceHighest,
                          borderRadius: DeckRadii.chipAll,
                          border: Border.all(
                            color: DeckColors.hairline.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          'GPS',
                          style: DeckType.labelMono(
                            color: DeckColors.volt,
                            size: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          sog == null ? '—' : sog.toStringAsFixed(1),
                          style: DeckType.metric(size: 28),
                        ),
                        const SizedBox(width: 4),
                        Text('m/s', style: DeckType.labelMono(size: 12)),
                        const SizedBox(width: 8),
                        Text(
                          kmh == null ? '—' : '${kmh.toStringAsFixed(1)} km/h',
                          style: DeckType.labelMono(
                            color: DeckColors.tribord,
                            size: 12,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(height: 1, color: DeckColors.hairline.withValues(alpha: 0.4)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Split /500m',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DeckType.labelMono(size: 10),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        split,
                        style: DeckType.labelMono(
                          color: DeckColors.text,
                          size: 12,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: DeckColors.hairline.withValues(alpha: 0.45),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    km.toStringAsFixed(2),
                    style: DeckType.labelMono(
                      color: DeckColors.text,
                      size: 13,
                      weight: FontWeight.w700,
                    ),
                  ),
                  Text(' KM', style: DeckType.labelMono(size: 10)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: DeckColors.surfaceHighest,
                      borderRadius: DeckRadii.chipAll,
                    ),
                    child: Text(
                      classLive,
                      style: DeckType.labelMono(
                        color: DeckColors.text,
                        size: 10,
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

  static String _split500(double? sogMps) {
    if (sogMps == null || sogMps <= 0.05) return '—';
    final sec = 500 / sogMps;
    final m = sec ~/ 60;
    final s = sec - m * 60;
    return '$m:${s.toStringAsFixed(1).padLeft(4, '0')}';
  }
}

// —— Colonne centrale : inclinometre ——

class _CenterColumn extends StatelessWidget {
  const _CenterColumn({required this.gite, required this.alert});

  final double? gite;
  final HeelAlert alert;

  @override
  Widget build(BuildContext context) {
    final v = gite;
    final signed = v == null
        ? '—'
        : '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}°';
    final drift = alert == HeelAlert.none
        ? (v == null
            ? 'TARE'
            : (v.abs() < 0.3
                ? 'STABLE'
                : (v >= 0 ? 'TRIBORD' : 'BÂBORD')))
        : (alert == HeelAlert.tribord
            ? 'TRIBORD // DÉRIVE'
            : 'BÂBORD // DÉRIVE');
    final driftHot = alert != HeelAlert.none;

    return ColoredBox(
      color: const Color(0xFF0E0E0E),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'GÎTE COQUE',
                  style: DeckType.labelMono(
                    color: DeckColors.text,
                    size: 12,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: DeckColors.surfaceHighest,
                    borderRadius: DeckRadii.chipAll,
                  ),
                  child: Text(
                    'IMU',
                    style: DeckType.labelMono(color: DeckColors.volt, size: 9),
                  ),
                ),
                const Spacer(),
                Text(
                  'Tolérance ±3.0°',
                  style: DeckType.labelMono(size: 10),
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              height: 1,
              color: DeckColors.hairline.withValues(alpha: 0.4),
            ),
            const HeelLabels(),
            const SizedBox(height: 4),
            Expanded(
              child: HeelGauge(
                giteDeg: v ?? 0,
                showHorizonCaption: true,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: DeckColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: DeckColors.tribord.withValues(alpha: 0.55),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Angle actuel',
                    style: DeckType.labelMono(size: 10),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    signed,
                    style: DeckType.metric(
                      size: 26,
                      color: DeckColors.tribord,
                    ),
                  ),
                  const Spacer(),
                  if (driftHot)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: const BoxDecoration(
                        color: DeckColors.tribord,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: driftHot ? DeckColors.onVolt : DeckColors.surfaceHighest,
                      borderRadius: DeckRadii.chipAll,
                    ),
                    child: Text(
                      drift,
                      style: DeckType.labelMono(
                        color: driftHot ? DeckColors.volt : DeckColors.text,
                        size: 10,
                        weight: FontWeight.w700,
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

// —— Colonne droite : télémétrie / cardio / STOP ——

class _RightColumn extends StatelessWidget {
  const _RightColumn({
    required this.s,
    required this.stopArmed,
    required this.onStop,
  });

  final LiveHubState s;
  final bool stopArmed;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final gpsOk = !s.gpsLost && s.locationOk;
    final imuOk = s.rollDeg != null && s.tareOk;
    final netOk = s.net != 'hors ligne';
    final hr = s.hrBpm;
    final batt = s.batt;
    final hrFrac = hr == null ? 0.0 : (hr / 200).clamp(0.0, 1.0);

    return ColoredBox(
      color: const Color(0xFF131313),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Pod(
              child: Column(
                children: [
                  _StatusRow(
                    label: 'GPS',
                    value: gpsOk ? 'FIX' : (s.gpsLost ? 'PERDU' : '…'),
                    ok: gpsOk,
                  ),
                  const SizedBox(height: 4),
                  _StatusRow(
                    label: 'IMU',
                    value: imuOk ? 'SYNC' : '—',
                    ok: imuOk,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      height: 1,
                      color: DeckColors.hairline.withValues(alpha: 0.35),
                    ),
                  ),
                  _StatusRow(
                    label: 'RÉSEAU',
                    value: s.net.toUpperCase(),
                    ok: netOk,
                    valueColor: DeckColors.text,
                  ),
                  const SizedBox(height: 4),
                  _StatusRow(
                    label: 'BATTERIE',
                    value: batt == null ? '—' : '$batt%',
                    ok: batt != null && batt > 20,
                    valueColor: DeckColors.text,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _Pod(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'Cardio-fréq.',
                        style: DeckType.uiLabel(color: DeckColors.label),
                      ),
                      const Spacer(),
                      Text(
                        hr == null ? '—' : _hrZone(hr),
                        style: DeckType.labelMono(
                          color: DeckColors.volt,
                          size: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        hr?.toString() ?? '—',
                        style: DeckType.metric(size: 22),
                      ),
                      const Spacer(),
                      Text('BPM', style: DeckType.labelMono(size: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: hrFrac,
                      minHeight: 4,
                      backgroundColor: DeckColors.surfaceHighest,
                      color: DeckColors.volt,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      stopArmed ? DeckColors.babord : DeckColors.text,
                  backgroundColor: DeckColors.surfaceHighest,
                  side: BorderSide(
                    color: stopArmed
                        ? DeckColors.babord
                        : DeckColors.babord.withValues(alpha: 0.75),
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.zero,
                ),
                onPressed: onStop,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.stop_circle_outlined,
                        size: 20,
                        color: DeckColors.babord,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        stopArmed ? 'STOP · RETOUCHER' : 'STOP / FIN',
                        style: DeckType.labelMono(
                          color: DeckColors.text,
                          size: 12,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _hrZone(int bpm) {
    if (bpm >= 170) return 'Z5';
    if (bpm >= 155) return 'Z4 SEUIL';
    if (bpm >= 140) return 'Z3';
    if (bpm >= 120) return 'Z2';
    return 'Z1';
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.ok,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool ok;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final fg = valueColor ?? (ok ? DeckColors.tribord : DeckColors.label);
    return Row(
      children: [
        Text(label, style: DeckType.labelMono(size: 10)),
        const Spacer(),
        if (ok) ...[
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: DeckColors.tribord,
              shape: BoxShape.circle,
            ),
          ),
        ],
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: DeckType.labelMono(
              color: fg,
              size: 10,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Pod extends StatelessWidget {
  const _Pod({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF454934).withValues(alpha: 0.4),
        ),
      ),
      child: child,
    );
  }
}
