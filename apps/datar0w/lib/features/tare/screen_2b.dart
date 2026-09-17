import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../session/live_hub.dart';
import '../../session/rower_orientation.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import '../../widgets/heel_gauge.dart';

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
    final shown = s.displayGiteDeg ?? 0;
    final running = s.tareStatus == TareStatus.running;
    final status = switch (s.tareStatus) {
      TareStatus.none => 'NON FAITE',
      TareStatus.running =>
        'EN COURS  ${s.tareElapsedS} s / 30  ·  ${s.tareSampleCount} éch. IMU',
      TareStatus.ok =>
        'OK  offset ${s.tareOffset!.toStringAsFixed(2)}°  σ ${s.tareSigma?.toStringAsFixed(3)}°',
      TareStatus.failed =>
        'RECOMMENCER  ${s.imuHint}',
    };

    return DeckScaffold(
      title: 'DATAROW / 2B',
      subtitle: 'Tare gîte · réf. rameur',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  Text(
                    s.imuHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: s.imuOk ? DeckColors.tribord : DeckColors.amber,
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
                  const HeelLabels(),
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
                  HeelGauge(giteDeg: shown),
                  const SizedBox(height: 8),
                  const Text(
                    'TOLÉRANCE  σ < 0,2°  ·  30 s  ·  clamp ±15° après tare',
                    style: TextStyle(color: DeckColors.label, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          if (running)
            LinearProgressIndicator(
              value: s.tareElapsedS / 30,
              color: DeckColors.amber,
              backgroundColor: DeckColors.hairline,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: running
                      ? null
                      : () => ref.read(liveHubProvider.notifier).beginTare(),
                  child: Text(
                    s.tareStatus == TareStatus.failed
                        ? 'RECOMMENCER TARE (30 S)'
                        : running
                            ? 'TARE EN COURS… ${s.tareElapsedS} s'
                            : 'TARE GÎTE (30 S)',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'STATUT ÉTALONNAGE : $status',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: DeckColors.label,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: s.tareOk
                      ? () async {
                          final ok = await ref
                              .read(liveHubProvider.notifier)
                              .startSession();
                          if (!context.mounted || !ok) return;
                          context.go(AppRoutes.live);
                        }
                      : null,
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
