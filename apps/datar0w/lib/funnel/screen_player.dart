import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/deck_theme.dart';
import 'controller.dart';
import 'models.dart';

/// DR-FR-5 — Player erg (MVP chrono + saisie manuelle).
class FunnelPlayerScreen extends ConsumerStatefulWidget {
  const FunnelPlayerScreen({super.key});

  @override
  ConsumerState<FunnelPlayerScreen> createState() => _FunnelPlayerScreenState();
}

class _FunnelPlayerScreenState extends ConsumerState<FunnelPlayerScreen> {
  Timer? _timer;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  bool _running = false;

  int get _distM {
    final f = ref.read(funnelProvider);
    return f.activeDistM ?? f.profile?.playDistanceM ?? 500;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (_startedAt == null) return;
    setState(() {
      _elapsed = DateTime.now().difference(_startedAt!);
    });
  }

  void _start() {
    _startedAt = DateTime.now().subtract(_elapsed);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
    setState(() => _running = true);
  }

  Future<void> _stop() async {
    _timer?.cancel();
    setState(() => _running = false);
    final sec = _elapsed.inMilliseconds / 1000.0;
    final ctrl = TextEditingController(
      text: sec > 0 ? formatErgTime(sec) : '',
    );
    final result = await showDialog<(double, bool)>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: DeckColors.surface,
          title: const Text(
            'Temps final',
            style: TextStyle(color: DeckColors.text),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Saisie moniteur (m:ss ou mm:ss).',
                style: TextStyle(color: DeckColors.label, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.datetime,
                style: DeckType.metric(size: 28),
                decoration: const InputDecoration(hintText: '7:44'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final parsed = _parseTime(ctrl.text) ?? sec;
                Navigator.pop(ctx, (parsed, false));
              },
              child: const Text('Garder le partiel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = _parseTime(ctrl.text) ?? sec;
                Navigator.pop(ctx, (parsed, true));
              },
              child: const Text('Distance complète'),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    if (result == null || !mounted) return;
    final (durationS, complete) = result;
    await ref.read(funnelProvider.notifier).finishSession(
          distM: _distM,
          durationS: durationS,
          complete: complete,
        );
    if (!mounted) return;
    context.go(AppRoutes.funnelProof);
  }

  /// Parse `m:ss`, `mm:ss` ou `h:mm:ss`.
  static double? _parseTime(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final parts = t.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]);
      final s = double.tryParse(parts[1]);
      if (m == null || s == null) return null;
      return m * 60 + s;
    }
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final s = double.tryParse(parts[2]);
      if (h == null || m == null || s == null) return null;
      return h * 3600 + m * 60 + s;
    }
    return double.tryParse(t);
  }

  @override
  Widget build(BuildContext context) {
    final funnel = ref.watch(funnelProvider);
    final distM = funnel.activeDistM ?? funnel.profile?.playDistanceM ?? 500;
    final target = funnel.profile?.targetSplit500s;
    final elapsedS = _elapsed.inMilliseconds / 1000.0;
    // Progression approximative sans capteur : temps écoulé vs cible × distance.
    final estPace = target ?? 120.0;
    final projectedDist =
        elapsedS > 0 ? (elapsedS / estPace * 500).clamp(0, distM.toDouble()) : 0.0;
    final remaining = (distM - projectedDist).clamp(0, distM.toDouble());
    final liveSplit = elapsedS > 1 && projectedDist > 10
        ? split500Seconds(durationS: elapsedS, distM: projectedDist.round())
        : (target ?? 0);
    final vsTarget = target == null || liveSplit <= 0
        ? null
        : liveSplit - target;

    return Scaffold(
      backgroundColor: DeckColors.bgTactical,
      appBar: AppBar(
        backgroundColor: DeckColors.bgTactical,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: DeckColors.text),
          onPressed: () => context.go(AppRoutes.homeRower),
        ),
        title: Text(
          ErgDistance.fromMeters(distM)?.label ?? '$distM m',
          style: const TextStyle(
            fontFamily: DeckType.ui,
            fontWeight: FontWeight.w600,
            color: DeckColors.text,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Split',
                style: DeckType.uiLabel(color: DeckColors.label),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                liveSplit > 0 ? formatErgTime(liveSplit) : '—',
                style: DeckType.metric(
                  size: 56,
                  weight: FontWeight.w700,
                  color: vsTarget == null
                      ? DeckColors.text
                      : (vsTarget <= 0 ? DeckColors.tribord : DeckColors.babord),
                ),
                textAlign: TextAlign.center,
              ),
              if (target != null)
                Text(
                  'cible ${formatErgTime(target)}',
                  style: DeckType.labelMono(size: 12),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _Sec(
                      label: 'Restant',
                      value: '${remaining.round()} m',
                    ),
                  ),
                  Expanded(
                    child: _Sec(
                      label: 'Temps',
                      value: formatErgTime(elapsedS),
                    ),
                  ),
                  const Expanded(
                    child: _Sec(label: 'Cadence', value: '—'),
                  ),
                  const Expanded(
                    child: _Sec(label: 'Watts', value: '—'),
                  ),
                ],
              ),
              const Spacer(),
              if (!_running)
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _start,
                    child: Text(_elapsed == Duration.zero ? 'Start' : 'Reprendre'),
                  ),
                )
              else
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: DeckColors.babord,
                      foregroundColor: DeckColors.text,
                    ),
                    onPressed: _stop,
                    child: const Text('Stop'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sec extends StatelessWidget {
  const _Sec({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: DeckType.uiLabel(size: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: DeckType.metric(size: 16, weight: FontWeight.w600),
        ),
      ],
    );
  }
}
