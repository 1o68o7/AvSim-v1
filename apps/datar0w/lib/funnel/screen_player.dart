import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/deck_theme.dart';
import 'controller.dart';
import 'models.dart';
import 'pm5_client.dart';

/// DR-FR-5 / DR-FR-R — Player erg (+ PM5 live Lot 3).
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
  StreamSubscription<Pm5LiveTick>? _pm5Sub;
  Pm5LiveTick? _pm5;

  ErgPiece get _piece => ref.read(funnelProvider).resolvedPiece;

  @override
  void initState() {
    super.initState();
    final client = ref.read(pm5ClientProvider);
    if (client.connectedId != null) {
      _pm5Sub = client.ticks.listen((t) {
        if (mounted) setState(() => _pm5 = t);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pm5Sub?.cancel();
    unawaited(ref.read(pm5ClientProvider).stopWorkout());
    super.dispose();
  }

  void _tick() {
    if (_startedAt == null) return;
    setState(() {
      _elapsed = DateTime.now().difference(_startedAt!);
    });
  }

  Future<void> _start() async {
    _startedAt = DateTime.now().subtract(_elapsed);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
    final client = ref.read(pm5ClientProvider);
    if (client.connectedId != null) {
      final dist = _piece.logDistM > 0 ? _piece.logDistM : 2000;
      await client.startWorkout(targetDistM: dist);
    }
    setState(() => _running = true);
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await ref.read(pm5ClientProvider).stopWorkout();
    setState(() => _running = false);
    final piece = _piece;
    final sec = _pm5 != null && _pm5!.elapsedS > 0
        ? _pm5!.elapsedS
        : _elapsed.inMilliseconds / 1000.0;
    final liveCadence = _pm5?.cadence;
    final liveWatts = _pm5?.watts;
    final liveDf = _pm5?.dragFactor;

    if (piece.kind == ErgPieceKind.duration) {
      final target = (piece.durationS ?? 300).toDouble();
      final complete = sec >= target * 0.95;
      await ref.read(funnelProvider.notifier).finishSession(
            piece: piece,
            durationS: sec > 0 ? sec : target,
            cadence: liveCadence ?? piece.targetCadence?.toDouble(),
            watts: liveWatts,
            dragFactor: liveDf,
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
            cadence: liveCadence ??
                (piece.blockCadences.isEmpty
                    ? null
                    : piece.blockCadences.reduce((a, b) => a + b) /
                        piece.blockCadences.length),
            watts: liveWatts,
            dragFactor: liveDf,
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
            cadence: liveCadence,
            watts: liveWatts,
            dragFactor: liveDf,
          );
      if (!mounted) return;
      context.go(AppRoutes.funnelProof);
      return;
    }

    // Distance (incl. 1 000 m annoncé) — PM5 peut remplir sans dialogue.
    if (_pm5 != null && _pm5!.distM > 0 && _pm5!.elapsedS > 0) {
      final realized = _pm5!.distM;
      var complete = true;
      if (piece.announcedMinM != null) {
        complete = announced1000InBand(realized);
      } else if (piece.distM != null && piece.distM! > 0) {
        complete = realized >= (piece.distM! * 0.98).round();
      }
      await ref.read(funnelProvider.notifier).finishSession(
            piece: piece,
            durationS: _pm5!.elapsedS,
            complete: complete,
            cadence: liveCadence,
            watts: liveWatts,
            dragFactor: liveDf,
            realizedDistM: piece.announcedMinM != null ? realized : null,
          );
      if (!mounted) return;
      context.go(AppRoutes.funnelProof);
      return;
    }

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
    final elapsedS = _pm5 != null && _pm5!.elapsedS > 0
        ? _pm5!.elapsedS
        : _elapsed.inMilliseconds / 1000.0;
    final cadenceHint = _pm5 != null && _pm5!.cadence > 0
        ? _pm5!.cadence.round()
        : (piece.kind == ErgPieceKind.intervals
            ? (piece.blockCadences.length > _legIndex
                ? piece.blockCadences[_legIndex]
                : null)
            : piece.targetCadence);
    final dfLive = _pm5?.dragFactor ?? funnel.activeDragFactor;
    final wattsLive = _pm5 != null && _pm5!.watts > 0
        ? '${_pm5!.watts.round()}'
        : '—';

    String heroLabel;
    String heroValue;
    if (piece.kind == ErgPieceKind.duration ||
        piece.kind == ErgPieceKind.intervals) {
      heroLabel = 'Temps';
      heroValue = formatErgTime(elapsedS);
    } else {
      heroLabel = 'Split';
      if (_pm5 != null && _pm5!.split500S > 0) {
        heroValue = formatErgTime(_pm5!.split500S);
      } else {
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
              if (dfLive != null)
                Text(
                  key: const Key('funnel-player-df'),
                  'DF $dfLive${_pm5 != null ? ' · live' : ''}',
                  style: DeckType.labelMono(size: 12, color: DeckColors.volt),
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
                  Expanded(
                    child: _Sec(label: 'Watts', value: wattsLive),
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
