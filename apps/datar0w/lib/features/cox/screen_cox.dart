import 'dart:async';
import 'dart:math' as math;

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
import '../../theme/deck_theme.dart';
import '../../widgets/deck_widgets.dart';
import '../../widgets/heel_banner.dart';
import '../../widgets/heel_gauge.dart';
import '../../widgets/live_affordances.dart';

/// DR-53 — Live barreur (Stitch).
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
    unawaited(unlockRowerOrientations());
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

  static String _split500(double? sogMps) {
    if (sogMps == null || sogMps <= 0.05) return '—';
    final sec = 500 / sogMps;
    final m = sec ~/ 60;
    final s = sec - m * 60;
    return '$m:${s.toStringAsFixed(1).padLeft(4, '0')}';
  }

  static String _knots(double? sogMps) {
    if (sogMps == null) return '—';
    return (sogMps * 1.94384).toStringAsFixed(1);
  }

  static String _cardinal(double? deg) {
    if (deg == null) return '—';
    const names = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final i = ((deg % 360) / 45).round() % 8;
    return names[i];
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(liveHubProvider);
    final boat = ref.watch(boatConfigProvider);
    final remote = s.coachFromApi ? s.remoteSample : null;
    final gite = remote?.giteDeg ?? s.displayGiteDeg ?? s.giteDeg;
    final sog = remote?.sog ?? s.sog;
    final dist = remote?.distM ?? s.distM;
    final hdg = remote?.hdgMag ?? s.hdgMag;
    final cadence = remote?.cadenceSpm ?? s.cadenceSpm;
    final alert = s.tareOk || remote != null
        ? heelAlertFor(gite)
        : HeelAlert.none;
    if (alert != _lastAlert) {
      if (_lastAlert == HeelAlert.none && alert != HeelAlert.none) {
        HapticFeedback.vibrate();
      }
      _lastAlert = alert;
    }
    final tag = boat.info.code;
    final pos = boat.coxPosition == CoxPosition.front
        ? 'pointe (avant)'
        : 'pointe (arrière)';
    final giteSigned = gite == null
        ? '—'
        : '${gite >= 0 ? '+' : ''}${gite.toStringAsFixed(1)}°';
    final giteSide = gite == null
        ? (s.tareOk ? 'stable' : 'tare')
        : (gite.abs() < 0.3
            ? 'stable'
            : (gite >= 0 ? 'tribord' : 'bâbord'));
    final giteColor = gite == null || gite.abs() < 0.3
        ? DeckColors.text
        : (gite >= 0 ? DeckColors.tribord : DeckColors.babord);

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: HeelAlertOverlay(
        alert: alert,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _CoxHeader(
                    boatCode: tag,
                    gpsOk: !s.gpsLost && s.locationOk,
                  ),
                  Expanded(
                    child: ListView(
                      cacheExtent: 2400,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _VoxBar(
                          boatCode: tag,
                          position: pos,
                          gpsOk: !s.gpsLost,
                          accH: s.accH,
                        ),
                        const SizedBox(height: 8),
                        _HeelCard(
                          gite: gite,
                          giteSigned: giteSigned,
                          giteSide: giteSide,
                          giteColor: giteColor,
                        ),
                        const SizedBox(height: 12),
                        _PaceCard(
                          split: _split500(sog),
                          sog: sog,
                          knots: _knots(sog),
                          distM: dist,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _CapCard(
                                hdg: hdg,
                                cardinal: _cardinal(hdg),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: _CadenceCard(cadence: cadence)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _CorridorCard(bassin: boat.bassin, distM: dist),
                        const SizedBox(height: 12),
                        _CrewBalanceCard(seats: boat.seats),
                        const SizedBox(height: 16),
                        _StopButton(armed: _stopArmed, onPressed: _onStop),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.security,
                              size: 14,
                              color: DeckColors.label.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Verrouillage étanche · navigation prioritaire',
                              style: DeckType.labelMono(size: 10),
                            ),
                          ],
                        ),
                      ],
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

class _CoxHeader extends StatelessWidget {
  const _CoxHeader({required this.boatCode, required this.gpsOk});
  final String boatCode;
  final bool gpsOk;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E).withValues(alpha: 0.95),
        border: const Border(bottom: BorderSide(color: DeckColors.hairline)),
      ),
      child: Row(
        children: [
          Flexible(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: DeckColors.surfaceHighest,
                    borderRadius: DeckRadii.chipAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: gpsOk ? DeckColors.tribord : DeckColors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'DR-53',
                        style: DeckType.labelMono(
                          color: DeckColors.tribord,
                          size: 10,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(boatCode, style: DeckType.labelMono(size: 10)),
                    ],
                  ),
                ),
                const DeckHonestChip(kind: DeckHonestKind.local, label: 'REC LOCAL'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: DeckColors.babordWash,
                    borderRadius: DeckRadii.chipAll,
                    border: Border.all(color: DeckColors.babord.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock, size: 14, color: DeckColors.babord),
                      const SizedBox(width: 4),
                      Text(
                        'Verrouillé',
                        style: DeckType.labelMono(
                          color: DeckColors.babord,
                          size: 10,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoxBar extends StatelessWidget {
  const _VoxBar({
    required this.boatCode,
    required this.position,
    required this.gpsOk,
    required this.accH,
  });
  final String boatCode;
  final String position;
  final bool gpsOk;
  final double? accH;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF81FBA7),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Micro vox · $boatCode $position',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DeckType.labelMono(
                    color: const Color(0xFF81FBA7),
                    size: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: DeckColors.surfaceHighest,
            borderRadius: DeckRadii.chipAll,
          ),
          child: Text(
            gpsOk
                ? (accH == null ? 'GPS' : 'GPS ±${accH!.toStringAsFixed(1)} m')
                : 'GPS perdu',
            style: DeckType.labelMono(
              color: gpsOk ? DeckColors.tribord : DeckColors.amber,
              size: 10,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeelCard extends StatelessWidget {
  const _HeelCard({
    required this.gite,
    required this.giteSigned,
    required this.giteSide,
    required this.giteColor,
  });
  final double? gite;
  final String giteSigned;
  final String giteSide;
  final Color giteColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: DeckRadii.cardAll,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.balance, size: 16, color: DeckColors.volt),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Gîte coque / assiette',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DeckType.uiLabel(
                    color: DeckColors.text,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const HeelLabels(perspective: HeelPerspective.cox),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: HeelGauge(
              giteDeg: gite ?? 0,
              perspective: HeelPerspective.cox,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Gauche = bâbord',
                style: DeckType.labelMono(
                  color: DeckColors.babord,
                  size: 10,
                  weight: FontWeight.w700,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(giteSigned, style: DeckType.metric(size: 20, color: giteColor)),
                  const SizedBox(width: 6),
                  Text(giteSide, style: DeckType.labelMono(color: giteColor, size: 10)),
                ],
              ),
              Text(
                'Tribord = droite',
                style: DeckType.labelMono(
                  color: DeckColors.tribord,
                  size: 10,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaceCard extends StatelessWidget {
  const _PaceCard({
    required this.split,
    required this.sog,
    required this.knots,
    required this.distM,
  });
  final String split;
  final double? sog;
  final String knots;
  final double distM;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: DeckRadii.cardAll,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.timer, size: 18, color: DeckColors.volt),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Allure moyenne instantanée',
                  style: DeckType.uiLabel(color: DeckColors.label),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: DeckColors.volt.withValues(alpha: 0.15),
                  borderRadius: DeckRadii.chipAll,
                ),
                child: Text(
                  '/500m',
                  style: DeckType.labelMono(
                    color: DeckColors.volt,
                    size: 10,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            split,
            style: DeckType.metric(
              size: 48,
              weight: FontWeight.w700,
              color: DeckColors.volt,
              height: 52 / 48,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1B1B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    label: 'Vitesse surface',
                    value: sog == null ? '—' : sog!.toStringAsFixed(1),
                    unit: 'm/s',
                  ),
                ),
                Container(width: 1, height: 32, color: DeckColors.surfaceHighest),
                Expanded(
                  child: _MiniMetric(
                    label: 'Vitesse nœuds',
                    value: knots,
                    unit: 'kts',
                    align: TextAlign.center,
                  ),
                ),
                Container(width: 1, height: 32, color: DeckColors.surfaceHighest),
                Expanded(
                  child: _MiniMetric(
                    label: 'Distance bassin',
                    value: distM >= 1000
                        ? (distM / 1000).toStringAsFixed(2)
                        : distM.toStringAsFixed(0),
                    unit: distM >= 1000 ? 'km' : 'm',
                    align: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.unit,
    this.align = TextAlign.left,
  });
  final String label;
  final String value;
  final String unit;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align == TextAlign.right
          ? CrossAxisAlignment.end
          : align == TextAlign.center
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
      children: [
        Text(label, style: DeckType.labelMono(size: 9)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value, style: DeckType.metric(size: 18)),
                TextSpan(text: ' $unit', style: DeckType.labelMono(size: 10)),
              ],
            ),
            textAlign: align,
          ),
        ),
      ],
    );
  }
}

class _CapCard extends StatelessWidget {
  const _CapCard({required this.hdg, required this.cardinal});
  final double? hdg;
  final String cardinal;

  @override
  Widget build(BuildContext context) {
    final deg = hdg;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: DeckRadii.cardAll,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.explore, size: 16, color: DeckColors.volt),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Cap réel',
                  style: DeckType.uiLabel(color: DeckColors.label),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 64,
            height: 64,
            child: CustomPaint(
              painter: _CompassPainter(headingDeg: deg ?? 0),
              child: Center(
                child: Text(
                  cardinal,
                  style: DeckType.metric(size: 14, weight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            deg == null ? '—' : '${deg.round()}°',
            style: DeckType.metric(size: 28),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1B1B),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              deg == null ? 'Capteur mag. —' : 'Cap magnétique',
              textAlign: TextAlign.center,
              style: DeckType.labelMono(size: 9),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({required this.headingDeg});
  final double headingDeg;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = DeckColors.surfaceHighest
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(headingDeg * math.pi / 180);
    final needle = Path()
      ..moveTo(0, -r + 4)
      ..lineTo(6, 0)
      ..lineTo(0, -4)
      ..lineTo(-6, 0)
      ..close();
    canvas.drawPath(needle, Paint()..color = DeckColors.volt);
    final tail = Path()
      ..moveTo(0, r - 4)
      ..lineTo(6, 0)
      ..lineTo(0, 4)
      ..lineTo(-6, 0)
      ..close();
    canvas.drawPath(tail, Paint()..color = DeckColors.surfaceHighest);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CompassPainter old) => old.headingDeg != headingDeg;
}

class _CadenceCard extends StatelessWidget {
  const _CadenceCard({required this.cadence});
  final double? cadence;

  @override
  Widget build(BuildContext context) {
    final measured = cadence != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: DeckRadii.cardAll,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.speed, size: 16, color: DeckColors.label),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Cadence',
                  style: DeckType.uiLabel(color: DeckColors.label),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: measured ? DeckColors.tribordWash : DeckColors.babordWash,
                  borderRadius: DeckRadii.chipAll,
                ),
                child: Text(
                  measured ? 'Estimée' : 'Non mesurée',
                  style: DeckType.labelMono(
                    color: measured ? DeckColors.tribord : DeckColors.babord,
                    size: 9,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            measured ? cadence!.toStringAsFixed(0) : '—',
            style: DeckType.metric(
              size: 48,
              weight: FontWeight.w500,
              color: measured ? DeckColors.text : DeckColors.label,
              height: 52 / 48,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            measured ? 'spm (estimé tel)' : 'spm',
            style: DeckType.labelMono(size: 10),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1B1B),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 13, color: DeckColors.label.withValues(alpha: 0.9)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    measured
                        ? 'Cadence estimée téléphone — pas un capteur nage.'
                        : 'Capteur nage non synchronisé au poste barreur.',
                    style: const TextStyle(
                      fontFamily: DeckType.ui,
                      fontSize: 10,
                      height: 1.3,
                      color: DeckColors.label,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CorridorCard extends StatelessWidget {
  const _CorridorCard({required this.bassin, required this.distM});
  final String bassin;
  final double distM;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: DeckRadii.cardAll,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route, size: 16, color: DeckColors.volt),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Couloir de navigation',
                  style: DeckType.uiLabel(
                    color: DeckColors.text,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  bassin,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: DeckType.labelMono(size: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: const _CorridorPainter(),
                child: Stack(
                  children: [
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E0E0E).withValues(alpha: 0.8),
                          borderRadius: DeckRadii.chipAll,
                        ),
                        child: Text(
                          'Trace GPS · ${distM.toStringAsFixed(0)} m',
                          style: DeckType.labelMono(color: DeckColors.text, size: 10),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Text('Départ', style: DeckType.labelMono(size: 9)),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Text('Ponton', style: DeckType.labelMono(size: 9)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CorridorPainter extends CustomPainter {
  const _CorridorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0E0E0E));
    final babord = Paint()
      ..color = DeckColors.babord.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final tribord = Paint()
      ..color = DeckColors.tribord.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final center = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Paint()
      ..color = DeckColors.volt
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(20, 20), Offset(size.width - 20, 30), babord);
    canvas.drawLine(Offset(20, size.height / 2), Offset(size.width - 20, size.height / 2), center);
    canvas.drawLine(Offset(20, size.height - 20), Offset(size.width - 20, size.height - 30), tribord);
    final boat = Path()
      ..moveTo(20, size.height / 2 + 2)
      ..quadraticBezierTo(size.width * 0.45, size.height / 2 - 4, size.width * 0.7, size.height / 2);
    canvas.drawPath(boat, path);
    canvas.drawCircle(Offset(size.width * 0.7, size.height / 2), 5, Paint()..color = DeckColors.volt);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CrewBalanceCard extends StatelessWidget {
  const _CrewBalanceCard({required this.seats});
  final int seats;

  @override
  Widget build(BuildContext context) {
    final order = [for (var i = seats; i >= 1; i--) i];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: DeckRadii.cardAll,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Équilibre d’équipage',
                  style: DeckType.uiLabel(color: DeckColors.label),
                ),
              ),
              Text(
                '$seats sièges',
                style: DeckType.labelMono(color: DeckColors.tribord, size: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final seat in order) ...[
                if (seat != order.first) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1B1B),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        Text('$seat', style: DeckType.labelMono(size: 9)),
                        const SizedBox(height: 4),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: DeckColors.label.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Nage (arrière)', style: DeckType.labelMono(size: 9)),
              const Spacer(),
              Text('Proue (avant)', style: DeckType.labelMono(size: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.armed, required this.onPressed});
  final bool armed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bg = armed ? DeckColors.babord : const Color(0xFF93000A);
    final fg = armed ? Colors.white : const Color(0xFFFFDAD6);
    return Material(
      color: bg,
      borderRadius: DeckRadii.cardAll,
      child: InkWell(
        onTap: onPressed,
        borderRadius: DeckRadii.cardAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: DeckColors.babord.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.anchor, color: fg, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        armed ? 'Confirmer l’arrêt au quai' : 'Arrêt séance (2 fois)',
                        style: TextStyle(
                          fontFamily: DeckType.ui,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: armed ? Colors.white : DeckColors.babord,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        armed
                            ? 'Appuyez une 2ᵉ fois dans les 3 s'
                            : 'Deuxième appui nécessaire pour valider le quai',
                        style: TextStyle(
                          fontFamily: DeckType.ui,
                          fontSize: 12,
                          color: armed ? Colors.white.withValues(alpha: 0.85) : DeckColors.label,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: DeckColors.babord.withValues(alpha: 0.2),
                    borderRadius: DeckRadii.chipAll,
                  ),
                  child: Text(
                    armed ? '2/2' : '1/2',
                    style: DeckType.labelMono(color: fg, size: 11, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
