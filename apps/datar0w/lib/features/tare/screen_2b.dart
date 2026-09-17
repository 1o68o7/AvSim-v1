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
    unawaited(lockRowerLandscape());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(liveHubProvider.notifier).listenImu();
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
    final status = switch (s.tareStatus) {
      TareStatus.none => 'NON FAITE',
      TareStatus.running => 'EN COURS  ${s.tareElapsedS} s / 30',
      TareStatus.ok =>
        'OK  offset ${s.tareOffset!.toStringAsFixed(2)}°  σ ${s.tareSigma?.toStringAsFixed(3)}°',
      TareStatus.failed =>
        'RECOMMENCER  σ ${s.tareSigma?.toStringAsFixed(2) ?? '—'}°  (≥ 0,2°)',
    };

    return DeckScaffold(
      title: 'DATAROW / 2B',
      subtitle: 'Tare gîte · réf. rameur',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Bateau à quai, coque calée. Ne pas bouger.',
              style: TextStyle(color: DeckColors.label),
            ),
            const SizedBox(height: 16),
            const HeelLabels(),
            const SizedBox(height: 8),
            Text(
              '${shown.toStringAsFixed(1)}°',
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700),
            ),
            const Text(
              'LECTURE LISSÉE  ±0,15°  ·  12 Hz',
              style: TextStyle(color: DeckColors.label, fontSize: 11),
            ),
            const SizedBox(height: 12),
            HeelGauge(giteDeg: shown),
            const SizedBox(height: 8),
            const Text(
              'TOLÉRANCE  σ < 0,2°  ·  30 s  ·  clamp ±15°',
              style: TextStyle(color: DeckColors.label, fontSize: 11),
            ),
            const Spacer(),
            FilledButton(
              onPressed: s.tareStatus == TareStatus.running
                  ? null
                  : () => ref.read(liveHubProvider.notifier).beginTare(),
              child: Text(
                s.tareStatus == TareStatus.failed
                    ? 'RECOMMENCER TARE (30 S)'
                    : 'TARE GÎTE (30 S)',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'STATUT ÉTALONNAGE : $status',
              textAlign: TextAlign.center,
              style: const TextStyle(color: DeckColors.label, fontSize: 12),
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
    );
  }
}
