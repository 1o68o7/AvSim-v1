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
    return DeckScaffold(
      title: 'DATAROW / 2B',
      subtitle: boat.isCox
          ? 'Tare gîte · ${boat.info.code.toUpperCase()} barreur ${boat.coxPosition.wire} · réf. barreur'
          : 'Tare gîte · ${boat.info.code.toUpperCase()} siège ${boat.clampedSeat}/${boat.seats} · réf. rameur',
      leading: running ? null : const DeckBackToProfile(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  Text(
                    state.imuHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: state.imuOk ? DeckColors.tribord : DeckColors.amber,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bateau à quai, coque calée. Penchez le téléphone : le chiffre doit bouger. Puis tare = ce niveau devient 0°.',
                    style: TextStyle(color: DeckColors.label),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  HeelLabels(perspective: persp),
                  const SizedBox(height: 8),
                  Text(
                    '${shown.toStringAsFixed(1)}°',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'NIVEAU TÉLÉPHONE  ·  lissé 12 Hz',
                    style: TextStyle(color: DeckColors.label, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  HeelGauge(giteDeg: shown, perspective: persp),
                  const SizedBox(height: 8),
                  const Text(
                    'TOLÉRANCE  σ < 0,2°  ·  3–30 s  ·  clamp ±15° après tare',
                    style: TextStyle(color: DeckColors.label, fontSize: 11),
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
                _TareCta(state: state),
                const SizedBox(height: 8),
                Text(
                  'STATUT ÉTALONNAGE : ${_statusLine(state)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: DeckColors.label,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: state.tareOk ? onStart : null,
                  child: const Text('DÉMARRER LA SESSION'),
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
      TareStatus.running => 'ÉTALONNAGE ACTIF',
      TareStatus.ok => 'TARE OK',
      TareStatus.approx => 'TARE FAIBLE',
      TareStatus.failed => 'RECOMMENCER',
      TareStatus.none => 'TARE NON FAITE',
    };
    return Scaffold(
      backgroundColor: DeckColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (!running) ...[
                      const DeckBackToProfile(compact: true),
                      const SizedBox(width: 4),
                    ],
                    Container(
                      width: 8,
                      height: 8,
                      color: DeckColors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        boat.isCox
                            ? 'DATAROW / 2B · TARE GÎTE · ${boat.info.code.toUpperCase()} barreur ${boat.coxPosition.wire} · Bateau à quai, coque calée.'
                            : 'DATAROW / 2B · TARE GÎTE · ${boat.info.code.toUpperCase()} siège ${boat.clampedSeat}/${boat.seats} · Bateau à quai, coque calée.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: DeckColors.amber,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 1.2,
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
                          const Text(
                            'LECTURE ASSIETTE LIVE',
                            style: TextStyle(
                              color: DeckColors.label,
                              fontSize: 10,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            state.imuHint,
                            style: TextStyle(
                              color: state.imuOk
                                  ? DeckColors.tribord
                                  : DeckColors.amber,
                              fontSize: 10,
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
                                    const Text(
                                      'GÎTE INSTANTANÉE',
                                      style: TextStyle(
                                        color: DeckColors.amber,
                                        fontSize: 9,
                                        letterSpacing: 1.4,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: shown.toStringAsFixed(1),
                                            style: const TextStyle(
                                              fontSize: 52,
                                              fontWeight: FontWeight.w800,
                                              height: 1,
                                              fontFeatures: [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                          const TextSpan(
                                            text: ' °',
                                            style: TextStyle(
                                              color: DeckColors.amber,
                                              fontSize: 28,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'NIVEAU TÉLÉPHONE  ·  12 Hz',
                                      style: TextStyle(
                                        color: state.imuOk
                                            ? DeckColors.tribord
                                            : DeckColors.label,
                                        fontSize: 9,
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
                                ? 'BÂBORD gauche écran  ·  σ < 0,2°  ·  3–30 s'
                                : 'TRIBORD gauche écran  ·  σ < 0,2°  ·  3–30 s',
                            style: const TextStyle(
                              color: DeckColors.label,
                              fontSize: 9,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _MiniTelemetry(
                                  label: 'TANGAGE (PITCH)',
                                  value: state.pitchDeg == null
                                      ? '—'
                                      : '${state.pitchDeg!.toStringAsFixed(1)}°',
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: _MiniTelemetry(
                                  label: 'LACET (YAW)',
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
                          const Text(
                            'SÉQUENCE D\'ÉTALONNAGE',
                            style: TextStyle(
                              color: DeckColors.amber,
                              fontSize: 10,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
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
                                        style: const TextStyle(
                                          color: DeckColors.amber,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      LinearProgressIndicator(
                                        value: _tareProgress(state),
                                        color: DeckColors.amber,
                                        backgroundColor: DeckColors.hairline,
                                        minHeight: 6,
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Acquisition IMU filtrée 12 Hz (pas 100 Hz brut)',
                                        style: TextStyle(
                                          color: DeckColors.label,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          _TareCta(state: state),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(color: DeckColors.hairline),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'STATUT ÉTALONNAGE',
                                  style: TextStyle(
                                    color: DeckColors.label,
                                    fontSize: 9,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _statusLine(state),
                                  style: TextStyle(
                                    color: state.tareStatus == TareStatus.ok
                                        ? DeckColors.tribord
                                        : state.tareStatus == TareStatus.approx
                                            ? DeckColors.amber
                                            : DeckColors.label,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: state.tareOk ? onStart : null,
                            child: const Text('DÉMARRER LA SESSION'),
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
  const _TareCta({required this.state});

  final LiveHubState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = state.tareStatus == TareStatus.running;
    return FilledButton(
      onPressed: running
          ? null
          : () => ref.read(liveHubProvider.notifier).beginTare(),
      child: Text(
        state.tareStatus == TareStatus.failed
            ? 'RECOMMENCER TARE'
            : running
                ? 'TARE EN COURS… ${state.tareElapsedS} s'
                : 'TARE GÎTE',
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
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 1.1,
            ),
          ),
          Text(sub, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 9)),
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
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: DeckColors.label,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
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

String _statusLine(LiveHubState s) {
  return switch (s.tareStatus) {
    TareStatus.none => 'NON FAITE',
    TareStatus.running =>
      'EN COURS  ${s.tareElapsedS} s  ·  ${s.tareSampleCount} éch. IMU  ·  σ < 0,2° sur 3 s',
    TareStatus.ok =>
      'OK  offset ${s.tareOffset!.toStringAsFixed(2)}°  σ ${s.tareSigma?.toStringAsFixed(3)}°  ·  ${s.tareDurationS?.toStringAsFixed(1) ?? s.tareElapsedS} s',
    TareStatus.approx =>
      'TARE APPROXIMATIVE  offset ${s.tareOffset?.toStringAsFixed(2)}°  σ ${s.tareSigma?.toStringAsFixed(2)}°  ·  Démarrer autorisé',
    TareStatus.failed => 'RECOMMENCER  ${s.imuHint}',
  };
}
