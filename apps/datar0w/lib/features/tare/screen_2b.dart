import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../session/boat_config.dart';
import '../../session/heel.dart';
import '../../session/live_hub.dart';
import '../../session/rower_orientation.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import '../../widgets/deck_widgets.dart';
import '../../widgets/heel_gauge.dart';
import '../../widgets/tare_ring.dart';

/// DR-51 — Tare (Stitch).
class TareScreen extends ConsumerStatefulWidget {
  const TareScreen({super.key});

  @override
  ConsumerState<TareScreen> createState() => _TareScreenState();
}

class _TareScreenState extends ConsumerState<TareScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hub = ref.read(liveHubProvider.notifier);
      hub.setDisplayRotation(displayRotationDegOf(context));
      unawaited(hub.listenImu());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref
        .read(liveHubProvider.notifier)
        .setDisplayRotation(displayRotationDegOf(context));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(liveHubProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final landscape = constraints.maxWidth > constraints.maxHeight &&
            constraints.maxWidth >= 640;
        if (landscape) {
          return _LandscapeHud(state: s, onStart: _startSession);
        }
        return _PortraitTare(state: s, onStart: _startSession);
      },
    );
  }

  Future<void> _startSession() async {
    final ok = await ref.read(liveHubProvider.notifier).startSession();
    if (!mounted || !ok) return;
    final role = ref.read(boatConfigProvider).role;
    context.go(AppRoutes.afterTare(role));
  }
}

class _PortraitTare extends ConsumerWidget {
  const _PortraitTare({required this.state, required this.onStart});

  final LiveHubState state;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boat = ref.watch(boatConfigProvider);
    final shown = state.displayGiteDeg ?? 0;
    final running = state.tareStatus == TareStatus.running;
    final persp =
        boat.isCox ? HeelPerspective.cox : HeelPerspective.rower;
    final pitch = state.pitchDeg;
    return DeckScaffold(
      title: 'Tare',
      subtitle: boat.isCox
          ? '${boat.info.code} barreur ${boat.coxPosition.wire} · réf. barreur'
          : '${boat.info.code} siège ${boat.clampedSeat}/${boat.seats} · réf. rameur',
      showRetour: !running,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      DeckStatusChip(
                        label: 'Portrait · Capteurs IMU',
                        ok: state.imuOk,
                        alert: !state.imuOk,
                      ),
                      const Spacer(),
                      Text(
                        '12 Hz',
                        style: DeckType.labelMono(size: 11),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.sensors,
                        size: 14,
                        color: DeckColors.label,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: DeckColors.surface,
                      borderRadius: DeckRadii.cardAll,
                      border: Border.all(color: DeckColors.hairline),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DeckIconBox(
                          icon: Icons.screen_rotation_alt,
                          accent: true,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mise à zéro du pont',
                                style: TextStyle(
                                  fontFamily: DeckType.ui,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: DeckColors.text,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Pose le téléphone à plat, dans l’axe du bateau. '
                                'Ne le touche plus.',
                                style: TextStyle(
                                  fontFamily: DeckType.ui,
                                  fontSize: 14,
                                  height: 1.35,
                                  color: DeckColors.label,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _TareMountWarning(),
                  const SizedBox(height: 8),
                  Text(
                    state.imuHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: DeckType.ui,
                      color: state.imuOk ? DeckColors.tribord : DeckColors.volt,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: DeckColors.surface,
                      borderRadius: DeckRadii.cardAll,
                      border: Border.all(color: DeckColors.hairline),
                    ),
                    child: Column(
                      children: [
                        HeelLabels(perspective: persp),
                        const SizedBox(height: 8),
                        Text(
                          '${shown.toStringAsFixed(1)}°',
                          style: DeckType.metric(size: 48, weight: FontWeight.w700),
                        ),
                        Text(
                          'Gîte transversale · lissée 12 Hz',
                          style: DeckType.labelMono(size: 10),
                        ),
                        const SizedBox(height: 12),
                        HeelGauge(giteDeg: shown, perspective: persp),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricPod(
                                label: 'Assiette longitudinale',
                                value: pitch == null
                                    ? '—'
                                    : pitch.toStringAsFixed(1),
                                unit: '°',
                                status: pitch != null && pitch.abs() < 2
                                    ? 'Dans la cible'
                                    : 'À stabiliser',
                                ok: pitch != null && pitch.abs() < 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MetricPod(
                                label: 'Gîte transversale',
                                value: shown.toStringAsFixed(1),
                                unit: '°',
                                status: state.tareOk
                                    ? 'Stable'
                                    : running
                                        ? 'Étalonnage…'
                                        : 'En attente',
                                ok: state.tareOk,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: DeckColors.surface,
                      borderRadius: DeckRadii.buttonAll,
                      border: Border.all(color: DeckColors.hairline),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: state.tareOk
                                ? DeckColors.tribord
                                : running
                                    ? DeckColors.volt
                                    : DeckColors.label,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _readyBanner(state),
                            style: DeckType.labelMono(
                              color: state.tareOk
                                  ? DeckColors.tribord
                                  : DeckColors.label,
                              size: 11,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _statusLine(state),
                          style: DeckType.labelMono(size: 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: DeckColors.label),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Toute rotation ou bascule du téléphone annulera la tare.',
                          style: TextStyle(
                            fontFamily: DeckType.ui,
                            color: DeckColors.label,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (running || state.tareOk)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: TareRing(
                        progress: _tareProgress(state),
                        caption: _tareRingCaption(state),
                        done: state.tareOk,
                      ),
                    ),
                  ),
                _TareCta(state: state, landscape: false),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: state.tareOk ? onStart : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'Démarrer l’enregistrement',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: DeckType.ui,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: running
                      ? null
                      : () => performDeckRetour(
                            context,
                            ref,
                            alwaysGo: AppRoutes.presession,
                          ),
                  child: const Text('Annuler et revenir à la préparation'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LandscapeHud extends ConsumerWidget {
  const _LandscapeHud({required this.state, required this.onStart});

  final LiveHubState state;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boat = ref.watch(boatConfigProvider);
    final cox = boat.isCox;
    final shown = state.displayGiteDeg ?? 0;
    final running = state.tareStatus == TareStatus.running;
    final chip = switch (state.tareStatus) {
      TareStatus.running => 'Étalonnage actif',
      TareStatus.ok => 'Tare OK',
      TareStatus.approx => 'Tare faible',
      TareStatus.failed => 'Recommencer',
      TareStatus.none => 'Tare non faite',
    };
    return Scaffold(
      backgroundColor: DeckColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (!running) ...[
                      const DeckRetour(compact: true),
                      const SizedBox(width: 4),
                    ],
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: DeckColors.volt,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        boat.isCox
                            ? 'Tare · ${boat.info.code} barreur ${boat.coxPosition.wire} · bateau à quai'
                            : 'Tare · ${boat.info.code} siège ${boat.clampedSeat}/${boat.seats} · bateau à quai',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: DeckType.ui,
                          color: DeckColors.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DeckStatusChip(
                      label: chip,
                      ok: state.tareOk,
                      alert: running || state.tareStatus == TareStatus.failed,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: DeckColors.hairline),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 55,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const DeckSectionLabel('Lecture assiette live'),
                          Text(
                            state.imuHint,
                            style: TextStyle(
                              fontFamily: DeckType.ui,
                              color: state.imuOk
                                  ? DeckColors.tribord
                                  : DeckColors.volt,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _SideBadge(
                                label: cox ? 'BÂBORD' : 'TRIBORD',
                                sub: cox ? '-15.0°' : '+15.0°',
                                color: cox ? DeckColors.babord : DeckColors.tribord,
                                left: true,
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      'Gîte instantanée',
                                      style: DeckType.uiLabel(
                                        color: DeckColors.volt,
                                        size: 11,
                                      ),
                                    ),
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: shown.toStringAsFixed(1),
                                            style: DeckType.metric(
                                              size: 48,
                                              weight: FontWeight.w800,
                                              height: 1,
                                            ),
                                          ),
                                          const TextSpan(
                                            text: ' °',
                                            style: TextStyle(
                                              fontFamily: DeckType.mono,
                                              color: DeckColors.volt,
                                              fontSize: 24,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'Niveau téléphone · 12 Hz',
                                      style: DeckType.labelMono(
                                        color: state.imuOk
                                            ? DeckColors.tribord
                                            : DeckColors.label,
                                        size: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _SideBadge(
                                label: cox ? 'TRIBORD' : 'BÂBORD',
                                sub: cox ? '+15.0°' : '-15.0°',
                                color: cox ? DeckColors.tribord : DeckColors.babord,
                                left: false,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: HeelGauge(
                              giteDeg: shown,
                              perspective: cox
                                  ? HeelPerspective.cox
                                  : HeelPerspective.rower,
                            ),
                          ),
                          Text(
                            cox
                                ? 'Bâbord gauche écran · σ < 0,2° · 3–30 s'
                                : 'Tribord gauche écran · σ < 0,2° · 3–30 s',
                            style: DeckType.labelMono(size: 10),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _MiniTelemetry(
                                  label: 'Tangage (pitch)',
                                  value: state.pitchDeg == null
                                      ? '—'
                                      : '${state.pitchDeg!.toStringAsFixed(1)}°',
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: _MiniTelemetry(
                                  label: 'Lacet (yaw)',
                                  value: '—',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(width: 1, color: DeckColors.hairline),
                  Expanded(
                    flex: 45,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const DeckSectionLabel('Séquence d’étalonnage'),
                            const SizedBox(height: 8),
                            const _TareMountWarning(),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: DeckColors.surface,
                                borderRadius: DeckRadii.cardAll,
                                border: Border.all(color: DeckColors.hairline),
                              ),
                              child: Row(
                                children: [
                                  TareRing(
                                    progress: _tareProgress(state),
                                    caption: _tareRingCaption(state),
                                    done: state.tareOk,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          running
                                              ? '${(_tareProgress(state) * 100).round()}%'
                                              : state.tareOk
                                                  ? '100%'
                                                  : '0%',
                                          textAlign: TextAlign.right,
                                          style: DeckType.labelMono(
                                            color: DeckColors.volt,
                                            size: 11,
                                            weight: FontWeight.w700,
                                          ),
                                        ),
                                        LinearProgressIndicator(
                                          value: _tareProgress(state),
                                          color: DeckColors.volt,
                                          backgroundColor: DeckColors.hairline,
                                          minHeight: 6,
                                          borderRadius: DeckRadii.chipAll,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Acquisition IMU filtrée 12 Hz',
                                          style: DeckType.labelMono(size: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            _TareCta(state: state, landscape: true),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: DeckColors.surface,
                                borderRadius: DeckRadii.cardAll,
                                border: Border.all(color: DeckColors.hairline),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Statut étalonnage',
                                    style: DeckType.uiLabel(size: 11),
                                  ),
                                  Text(
                                    _statusLine(state),
                                    style: TextStyle(
                                      fontFamily: DeckType.ui,
                                      color: state.tareStatus == TareStatus.ok
                                          ? DeckColors.tribord
                                          : state.tareStatus ==
                                                  TareStatus.approx
                                              ? DeckColors.volt
                                              : DeckColors.label,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: state.tareOk ? onStart : null,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                              child: const Text('Démarrer l’enregistrement'),
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

class _TareCta extends ConsumerWidget {
  const _TareCta({required this.state, required this.landscape});

  final LiveHubState state;
  final bool landscape;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = state.tareStatus == TareStatus.running;
    return FilledButton(
      onPressed: running || !landscape
          ? null
          : () => ref.read(liveHubProvider.notifier).beginTare(),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
      child: Text(
        !landscape
            ? 'Tourner en paysage pour tarer'
            : state.tareStatus == TareStatus.failed
                ? 'Recommencer la tare'
                : running
                    ? 'Tare en cours… ${state.tareElapsedS} s'
                    : 'Tare gîte',
      ),
    );
  }
}

class _TareMountWarning extends StatelessWidget {
  const _TareMountWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DeckColors.amberWash,
        borderRadius: DeckRadii.cardAll,
        border: Border.all(color: DeckColors.volt),
      ),
      child: const Text(
        'Position de séance — La tare mémorise le niveau actuel du téléphone. '
        'Fixez-le d’abord comme en live (cale-pied, écran paysage, haut du tel à gauche). '
        'Ne pas tarer à la verticale à la main : le zéro resterait celui du portrait.',
        style: TextStyle(
          fontFamily: DeckType.ui,
          color: DeckColors.volt,
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }
}

class _MetricPod extends StatelessWidget {
  const _MetricPod({
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
    required this.ok,
  });

  final String label;
  final String value;
  final String unit;
  final String status;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: DeckColors.surfaceHigh,
        borderRadius: DeckRadii.buttonAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: DeckType.uiLabel(size: 11)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: DeckType.metric(size: 28)),
              const SizedBox(width: 2),
              Text(unit, style: DeckType.labelMono(size: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle : Icons.lock_outline,
                size: 14,
                color: ok ? DeckColors.tribord : DeckColors.label,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  status,
                  style: DeckType.labelMono(
                    color: ok ? DeckColors.tribord : DeckColors.label,
                    size: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SideBadge extends StatelessWidget {
  const _SideBadge({
    required this.label,
    required this.sub,
    required this.color,
    required this.left,
  });

  final String label;
  final String sub;
  final Color color;
  final bool left;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: DeckRadii.buttonAll,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: DeckType.labelMono(
              color: color,
              size: 10,
              weight: FontWeight.w700,
            ),
          ),
          Text(
            sub,
            style: TextStyle(
              fontFamily: DeckType.mono,
              color: color.withValues(alpha: 0.8),
              fontSize: 9,
            ),
          ),
          Icon(
            left ? Icons.arrow_back : Icons.arrow_forward,
            color: color,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class _MiniTelemetry extends StatelessWidget {
  const _MiniTelemetry({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: DeckRadii.buttonAll,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: DeckType.uiLabel(size: 11),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: DeckType.mono,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

double _tareProgress(LiveHubState s) {
  if (s.tareOk) return 1;
  if (s.tareStatus != TareStatus.running) return 0;
  return (s.tareElapsedS / 30).clamp(0.0, 1.0);
}

String _tareRingCaption(LiveHubState s) {
  return switch (s.tareStatus) {
    TareStatus.running => '… stabilise',
    TareStatus.ok || TareStatus.approx => 'OK',
    TareStatus.failed => '—',
    TareStatus.none => 'tare',
  };
}

String _readyBanner(LiveHubState s) {
  return switch (s.tareStatus) {
    TareStatus.ok || TareStatus.approx => 'Stabilisé · prêt pour le départ',
    TareStatus.running => 'Étalonnage en cours',
    TareStatus.failed => 'Échec · recommencer',
    TareStatus.none => 'En attente de tare paysage',
  };
}

String _statusLine(LiveHubState s) {
  return switch (s.tareStatus) {
    TareStatus.none => 'Non faite',
    TareStatus.running =>
      'En cours  ${s.tareElapsedS} s  ·  ${s.tareSampleCount} éch. IMU  ·  σ < 0,2° sur 3 s',
    TareStatus.ok =>
      'OK  offset ${s.tareOffset!.toStringAsFixed(2)}°  σ ${s.tareSigma?.toStringAsFixed(3)}°  ·  ${s.tareDurationS?.toStringAsFixed(1) ?? s.tareElapsedS} s',
    TareStatus.approx =>
      'Tare approximative  offset ${s.tareOffset?.toStringAsFixed(2)}°  σ ${s.tareSigma?.toStringAsFixed(2)}°  ·  Démarrer autorisé',
    TareStatus.failed => 'Recommencer  ${s.imuHint}',
  };
}
