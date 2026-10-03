import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/deck_theme.dart';
import 'controller.dart';
import 'models.dart';

/// DR-FR-5 / DR-FR-R — Player erg (MVP chrono + saisie manuelle, Lot 1+2).
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
  int _legIndex = 0; // relay / intervals
  final List<double> _legTimes = [];

  ErgPiece get _piece => ref.read(funnelProvider).resolvedPiece;

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
    final piece = _piece;
    final sec = _elapsed.inMilliseconds / 1000.0;

    if (piece.kind == ErgPieceKind.duration) {
      final target = (piece.durationS ?? 300).toDouble();
      final complete = sec >= target * 0.95;
      await ref.read(funnelProvider.notifier).finishSession(
            piece: piece,
            durationS: sec > 0 ? sec : target,
            cadence: piece.targetCadence?.toDouble(),
            complete: complete,
          );
      if (!mounted) return;
      context.go(AppRoutes.funnelProof);
      return;
    }

    if (piece.kind == ErgPieceKind.intervals) {
      final blockS = (piece.durationS ?? 60).toDouble();
      _legTimes.add(sec > 0 ? sec : blockS);
      if (_legIndex + 1 < piece.blockCount) {
        setState(() {
          _legIndex += 1;
          _elapsed = Duration.zero;
          _startedAt = null;
          _running = false;
        });
        return;
      }
      final total = _legTimes.fold<double>(0, (a, b) => a + b);
      await ref.read(funnelProvider.notifier).finishSession(
            piece: piece,
            durationS: total,
            complete: true,
            blockCadences: piece.blockCadences,
            cadence: piece.blockCadences.isEmpty
                ? null
                : piece.blockCadences.reduce((a, b) => a + b) /
                    piece.blockCadences.length,
          );
      if (!mounted) return;
      context.go(AppRoutes.funnelProof);
      return;
    }

    if (piece.kind == ErgPieceKind.relay) {
      _legTimes.add(sec > 0 ? sec : 90);
      if (_legIndex + 1 < piece.blockCount) {
        setState(() {
          _legIndex += 1;
          _elapsed = Duration.zero;
          _startedAt = null;
          _running = false;
        });
        return;
      }
      final total = _legTimes.fold<double>(0, (a, b) => a + b);
      await ref.read(funnelProvider.notifier).finishSession(
            piece: piece,
            durationS: total,
            complete: true,
          );
      if (!mounted) return;
      context.go(AppRoutes.funnelProof);
      return;
    }

    // Distance (incl. 1 000 m annoncé).
    await _finishDistanceDialog(piece, sec);
  }

  Future<void> _finishDistanceDialog(ErgPiece piece, double sec) async {
    final timeCtrl = TextEditingController(
      text: sec > 0 ? formatErgTime(sec) : '',
    );
    final distCtrl = TextEditingController(
      text: piece.announcedMinM != null ? '1000' : '',
    );
    final result = await showDialog<(double, bool, int?)>(
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
                controller: timeCtrl,
                autofocus: true,
                keyboardType: TextInputType.datetime,
                style: DeckType.metric(size: 28),
                decoration: const InputDecoration(hintText: '7:44'),
              ),
              if (piece.announcedMinM != null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: distCtrl,
                  keyboardType: TextInputType.number,
                  style: DeckType.metric(size: 22),
                  decoration: InputDecoration(
                    hintText:
                        '${piece.announcedMinM}–${piece.announcedMaxM} m',
                    labelText: 'Distance réalisée (m)',
                    labelStyle: const TextStyle(color: DeckColors.label),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final parsed = _parseTime(timeCtrl.text) ?? sec;
                final realized = int.tryParse(distCtrl.text.trim());
                Navigator.pop(ctx, (parsed, false, realized));
              },
              child: const Text('Garder le partiel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = _parseTime(timeCtrl.text) ?? sec;
                final realized = int.tryParse(distCtrl.text.trim());
                Navigator.pop(ctx, (parsed, true, realized));
              },
              child: const Text('Distance complète'),
            ),
          ],
        );
      },
    );
    timeCtrl.dispose();
    distCtrl.dispose();
    if (result == null || !mounted) return;
    final (durationS, completeFlag, realized) = result;
    var complete = completeFlag;
    if (piece.announcedMinM != null && realized != null) {
      complete = complete && announced1000InBand(realized);
    }
    await ref.read(funnelProvider.notifier).finishSession(
          piece: piece,
          durationS: durationS,
          complete: complete,
          realizedDistM: realized,
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
    final piece = funnel.resolvedPiece;
    final target = funnel.profile?.targetSplit500s;
    final elapsedS = _elapsed.inMilliseconds / 1000.0;
    final cadenceHint = piece.kind == ErgPieceKind.intervals
        ? (piece.blockCadences.length > _legIndex
            ? piece.blockCadences[_legIndex]
            : null)
        : piece.targetCadence;

    String heroLabel;
    String heroValue;
    if (piece.kind == ErgPieceKind.duration ||
        piece.kind == ErgPieceKind.intervals) {
      heroLabel = 'Temps';
      heroValue = formatErgTime(elapsedS);
    } else {
      heroLabel = 'Split';
      final distM = piece.kind == ErgPieceKind.relay
          ? (piece.blockDistM ?? 500)
          : (piece.distM ?? 500);
      final estPace = target ?? 120.0;
      final projectedDist = elapsedS > 0
          ? (elapsedS / estPace * 500).clamp(0, distM.toDouble())
          : 0.0;
      final liveSplit = elapsedS > 1 && projectedDist > 10
          ? split500Seconds(durationS: elapsedS, distM: projectedDist.round())
          : (target ?? 0);
      heroValue = liveSplit > 0 ? formatErgTime(liveSplit) : '—';
    }

    final stopLabel = (piece.kind == ErgPieceKind.relay ||
            piece.kind == ErgPieceKind.intervals) &&
            _legIndex + 1 < piece.blockCount
        ? 'Jambe suivante'
        : 'Stop';

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
          piece.label,
          style: const TextStyle(
            fontFamily: DeckType.ui,
            fontWeight: FontWeight.w600,
            color: DeckColors.text,
          ),
        ),
        actions: [
          if (piece.kind == ErgPieceKind.relay ||
              piece.kind == ErgPieceKind.intervals)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  'Jambe ${_legIndex + 1} / ${piece.blockCount}',
                  key: const Key('funnel-player-leg'),
                  style: DeckType.labelMono(size: 11, color: DeckColors.volt),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                heroLabel,
                style: DeckType.uiLabel(color: DeckColors.label),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                heroValue,
                style: DeckType.metric(size: 56, weight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              if (cadenceHint != null)
                Text(
                  'cadence $cadenceHint',
                  style: DeckType.labelMono(size: 12),
                  textAlign: TextAlign.center,
                ),
              if (piece.kind == ErgPieceKind.relay) ...[
                const SizedBox(height: 20),
                _RelayBar(
                  count: piece.blockCount,
                  current: _legIndex,
                  doneTimes: _legTimes,
                ),
              ],
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _Sec(
                      label: 'Temps',
                      value: formatErgTime(elapsedS),
                    ),
                  ),
                  Expanded(
                    child: _Sec(
                      label: 'Cadence',
                      value: cadenceHint?.toString() ?? '—',
                    ),
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
                    child:
                        Text(_elapsed == Duration.zero ? 'Start' : 'Reprendre'),
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
                    child: Text(stopLabel),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelayBar extends StatelessWidget {
  const _RelayBar({
    required this.count,
    required this.current,
    required this.doneTimes,
  });

  final int count;
  final int current;
  final List<double> doneTimes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i < current
                        ? DeckColors.volt
                        : (i == current
                            ? DeckColors.volt.withValues(alpha: 0.45)
                            : DeckColors.hairline),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Text(
                  i < doneTimes.length
                      ? formatErgTime(doneTimes[i])
                      : (i == current ? 'en cours' : '—'),
                  style: DeckType.labelMono(size: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ],
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
