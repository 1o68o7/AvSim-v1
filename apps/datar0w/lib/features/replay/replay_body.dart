import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../session/model.dart';
import '../../session/store.dart';
import '../../session/summary.dart';
import '../../theme/deck_theme.dart';
import '../../maps/deck_tiles.dart';
import '../../widgets/deck_widgets.dart';

class ReplayBody extends StatefulWidget {
  const ReplayBody({
    super.key,
    required this.samples,
    this.notes = const [],
    this.meta,
    this.title = 'Replay',
    this.showEval = true,
    this.sourceLabel,
    this.onShare,
  });

  final List<SessionSample> samples;
  final List<SessionNote> notes;
  final SessionMeta? meta;
  final String title;
  final bool showEval;
  final String? sourceLabel;
  /// Partage fichiers locaux — pas de données inventées.
  final VoidCallback? onShare;

  @override
  State<ReplayBody> createState() => _ReplayBodyState();
}

class _ReplayBodyState extends State<ReplayBody> {
  final _map = MapController();
  int _index = 0;

  List<SessionSample> get _samples => widget.samples;

  int _nearestNoteIndex(int t) {
    if (widget.notes.isEmpty) return -1;
    var best = 0;
    var bestD = (widget.notes.first.t - t).abs();
    for (var i = 1; i < widget.notes.length; i++) {
      final d = (widget.notes[i].t - t).abs();
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  void _jumpToNote(int noteIdx) {
    if (noteIdx < 0 || noteIdx >= widget.notes.length || _samples.isEmpty) {
      return;
    }
    final nt = widget.notes[noteIdx].t;
    var best = 0;
    var bestD = (_samples.first.t - nt).abs();
    for (var i = 1; i < _samples.length; i++) {
      final d = (_samples[i].t - nt).abs();
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    setState(() => _index = best);
    _moveMap();
  }

  void _moveMap() {
    if (_samples.isEmpty) return;
    final s = _samples[_index.clamp(0, _samples.length - 1)];
    if (s.lat != null && s.lon != null) {
      try {
        _map.move(LatLng(s.lat!, s.lon!), _map.camera.zoom);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_samples.isEmpty) {
      return const Center(
        child: Text(
          'Aucun samples.jsonl',
          style: TextStyle(color: DeckColors.label),
        ),
      );
    }
    final i = _index.clamp(0, _samples.length - 1);
    final cur = _samples[i];
    final segs = gpsSegments(_samples);
    final hasFix = cur.lat != null && cur.lon != null;
    final center = hasFix
        ? LatLng(cur.lat!, cur.lon!)
        : (segs.isNotEmpty
            ? segs.first.first
            : const LatLng(48.86, 2.35));
    final t0 = _samples.first.t;
    final tEnd = _samples.last.t;
    final elapsed = Duration(milliseconds: math.max(0, cur.t - t0));
    final total = Duration(milliseconds: math.max(0, tEnd - t0));
    final noteIdx = _nearestNoteIndex(cur.t);
    double? firstCad;
    for (final s in _samples) {
      if (s.cadenceSpm != null) {
        firstCad = s.cadenceSpm;
        break;
      }
    }
    final dCad = (cur.cadenceSpm != null && firstCad != null)
        ? cur.cadenceSpm! - firstCad
        : null;
    final giteSide = cur.giteDeg == null
        ? ''
        : (cur.giteDeg! >= 0 ? 'Tribord' : 'Bâbord');
    final summary = SessionSummary.fromSamples(_samples);
    final sessionLabel = widget.meta?.code == null
        ? 'Séance'
        : '${widget.meta!.code} · ${widget.meta!.classe}';

    final map = ClipRRect(
      borderRadius: DeckRadii.cardAll,
      child: FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCenter: center,
          initialZoom: 15,
          backgroundColor: DeckColors.bg,
        ),
        children: [
          TileLayer(
            urlTemplate: DeckMapTiles.urlTemplate,
            userAgentPackageName: DeckMapTiles.userAgentPackageName,
          ),
          PolylineLayer(
            polylines: [
              for (final seg in segs)
                if (seg.length >= 2)
                  Polyline(
                    points: seg,
                    color: DeckColors.volt,
                    strokeWidth: 3,
                  ),
            ],
          ),
          if (hasFix)
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(cur.lat!, cur.lon!),
                  width: 16,
                  height: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: DeckColors.volt,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );

    final curves = Container(
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: DeckRadii.cardAll,
        border: Border.all(color: DeckColors.hairline),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, size: 18, color: DeckColors.volt),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Graphiques synchronisés',
                  style: TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DeckColors.text,
                  ),
                ),
              ),
              Container(width: 10, height: 2, color: DeckColors.tribord),
              const SizedBox(width: 4),
              Text(
                'Cadence',
                style: DeckType.labelMono(size: 9),
              ),
              const SizedBox(width: 8),
              Container(width: 10, height: 2, color: DeckColors.volt),
              const SizedBox(width: 4),
              Text(
                'Vitesse',
                style: DeckType.labelMono(size: 9),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: DeckRadii.buttonAll,
              child: CustomPaint(
                painter: _CurvesPainter(
                  samples: _samples,
                  index: i,
                  notes: widget.notes,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );

    final metrics = _CursorMetrics(
      cur: cur,
      dCad: dCad,
      giteSide: giteSide,
      elapsed: elapsed,
    );

    final scrubber = Container(
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: DeckRadii.cardAll,
        border: Border.all(color: DeckColors.hairline),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                formatDuration(elapsed),
                style: DeckType.metric(size: 18, weight: FontWeight.w600),
              ),
              Text(
                ' / ${formatDuration(total)}',
                style: DeckType.labelMono(size: 11),
              ),
              const Spacer(),
              Text(
                '${(cur.distM).round()} m',
                style: DeckType.metric(
                  size: 14,
                  weight: FontWeight.w600,
                  color: DeckColors.volt,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: i.toDouble(),
              min: 0,
              max: (_samples.length - 1).toDouble(),
              divisions: _samples.length > 1 ? _samples.length - 1 : 1,
              activeColor: DeckColors.volt,
              inactiveColor: DeckColors.surfaceHighest,
              onChanged: (v) {
                setState(() => _index = v.round());
                _moveMap();
              },
            ),
          ),
        ],
      ),
    );

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sessionLabel,
                  style: const TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: DeckColors.text,
                  ),
                ),
              ),
              DeckStatusChip(
                label: widget.sourceLabel ?? 'Fichier chargé',
                ok: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Séance replay',
                      style: DeckType.uiLabel(size: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary.distM <= 0
                          ? '—'
                          : '${summary.distM.round()} m',
                      style: DeckType.metric(
                        size: 28,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Temps global',
                    style: DeckType.uiLabel(size: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDuration(summary.duration),
                    style: DeckType.metric(
                      size: 16,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    final evalBlock = widget.showEval && widget.notes.isNotEmpty
        ? _EvalFleetSection(
            notes: widget.notes,
            noteIdx: noteIdx,
            dCad: dCad,
            onJump: _jumpToNote,
            t0: t0,
          )
        : (widget.showEval
            ? Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  dCad == null
                      ? 'Δ cadence  —'
                      : 'Δ cadence  ${dCad >= 0 ? '+' : ''}${dCad.toStringAsFixed(0)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: DeckType.ui,
                    color: DeckColors.volt,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              )
            : const SizedBox.shrink());

    final export = _ExportShareCard(onShare: widget.onShare);

    final disclaimer = Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: DeckRadii.buttonAll,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: DeckColors.label),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mode replay · Vitesse sol GPS — pas vitesse eau · '
              'Cadence « — » si absente · Stockage local',
              style: DeckType.uiLabel(size: 11),
            ),
          ),
        ],
      ),
    );

    return Column(
      children: [
        header,
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final landscape = c.maxWidth > 640;
              if (landscape) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 7,
                        child: Column(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: DeckRadii.cardAll,
                                  border:
                                      Border.all(color: DeckColors.hairline),
                                ),
                                child: map,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(flex: 5, child: curves),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 260,
                        child: ListView(
                          children: [
                            metrics,
                            evalBlock,
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                children: [
                  SizedBox(
                    height: 200,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: DeckRadii.cardAll,
                        border: Border.all(color: DeckColors.hairline),
                      ),
                      child: map,
                    ),
                  ),
                  const SizedBox(height: 10),
                  scrubber,
                  const SizedBox(height: 10),
                  metrics,
                  evalBlock,
                  const SizedBox(height: 10),
                  SizedBox(height: 160, child: curves),
                  const SizedBox(height: 10),
                  disclaimer,
                  export,
                ],
              );
            },
          ),
        ),
        if (MediaQuery.sizeOf(context).width > 640) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: scrubber,
          ),
          disclaimer,
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: export,
          ),
        ],
      ],
    );
  }
}

class _CursorMetrics extends StatelessWidget {
  const _CursorMetrics({
    required this.cur,
    required this.dCad,
    required this.giteSide,
    required this.elapsed,
  });

  final SessionSample cur;
  final double? dCad;
  final String giteSide;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final cad = cur.cadenceSpm;
    final sog = cur.sog;
    final gite = cur.giteDeg;
    final giteColor = (gite ?? 0) >= 0 ? DeckColors.tribord : DeckColors.babord;

    return Container(
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: DeckRadii.cardAll,
        border: Border.all(color: DeckColors.hairline),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, size: 18, color: DeckColors.volt),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Valeurs au curseur (${formatDuration(elapsed)})',
                  style: const TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DeckColors.text,
                  ),
                ),
              ),
              DeckStatusChip(label: 'instantané', ok: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Cadence',
                  unit: 'spm',
                  value: cad == null ? '—' : cad.toStringAsFixed(0),
                  accent: DeckColors.tribord,
                  footnote: dCad == null
                      ? null
                      : 'Δ ${dCad! >= 0 ? '+' : ''}${dCad!.toStringAsFixed(0)}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Vitesse sol GPS',
                  unit: 'm/s',
                  value: sog == null ? '—' : sog.toStringAsFixed(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Distance cumulée',
                  unit: 'm',
                  value: cur.distM.round().toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Gîte de coque',
                  unit: giteSide.isEmpty ? '°' : giteSide,
                  value: gite == null
                      ? '—'
                      : '${gite >= 0 ? '+' : ''}${gite.toStringAsFixed(1)}°',
                  accent: gite == null ? null : giteColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.unit,
    this.accent,
    this.footnote,
  });

  final String label;
  final String value;
  final String? unit;
  final Color? accent;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: DeckColors.surfaceHigh,
        borderRadius: DeckRadii.buttonAll,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DeckType.uiLabel(size: 11),
                ),
              ),
              if (unit != null)
                Text(
                  unit!,
                  style: DeckType.labelMono(size: 9),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: DeckType.metric(
              size: 22,
              weight: FontWeight.w700,
              color: accent ?? DeckColors.text,
            ),
          ),
          if (footnote != null) ...[
            const SizedBox(height: 2),
            Text(
              footnote!,
              style: DeckType.labelMono(
                color: DeckColors.volt,
                size: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EvalFleetSection extends StatelessWidget {
  const _EvalFleetSection({
    required this.notes,
    required this.noteIdx,
    required this.dCad,
    required this.onJump,
    required this.t0,
  });

  final List<SessionNote> notes;
  final int noteIdx;
  final double? dCad;
  final void Function(int) onJump;
  final int t0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
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
              const Icon(Icons.hub_outlined, size: 18, color: DeckColors.volt),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Éval / repères flotte',
                  style: TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DeckColors.text,
                  ),
                ),
              ),
              Text(
                '${notes.length} note${notes.length > 1 ? 's' : ''}',
                style: DeckType.labelMono(size: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dCad == null
                ? 'Δ cadence  —'
                : 'Δ cadence  ${dCad! >= 0 ? '+' : ''}${dCad!.toStringAsFixed(0)}',
            style: const TextStyle(
              fontFamily: DeckType.ui,
              color: DeckColors.volt,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var n = 0; n < notes.length; n++)
                OutlinedButton(
                  onPressed: () => onJump(n),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    foregroundColor: n == noteIdx
                        ? DeckColors.onVolt
                        : DeckColors.volt,
                    backgroundColor:
                        n == noteIdx ? DeckColors.volt : Colors.transparent,
                    side: BorderSide(
                      color: n == noteIdx
                          ? DeckColors.volt
                          : DeckColors.hairline,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: DeckRadii.buttonAll,
                    ),
                  ),
                  child: Text(
                    't=${formatDuration(Duration(milliseconds: math.max(0, notes[n].t - t0)))}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportShareCard extends StatelessWidget {
  const _ExportShareCard({this.onShare});

  final VoidCallback? onShare;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Exporter / partager',
            style: DeckType.uiLabel(
              color: DeckColors.label,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Fichiers locaux de la séance (samples + meta) — aucune donnée inventée.',
            style: DeckType.uiLabel(size: 11),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Partager les données'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurvesPainter extends CustomPainter {
  _CurvesPainter({
    required this.samples,
    required this.index,
    required this.notes,
  });

  final List<SessionSample> samples;
  final int index;
  final List<SessionNote> notes;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF090C10),
    );
    _line(
      canvas,
      size,
      samples.map((s) => s.cadenceSpm).toList(),
      DeckColors.tribord,
    );
    _line(
      canvas,
      size,
      samples.map((s) => s.sog).toList(),
      DeckColors.volt,
    );
    if (samples.any((s) => s.hrBpm != null)) {
      _line(
        canvas,
        size,
        samples.map((s) => s.hrBpm?.toDouble()).toList(),
        DeckColors.babord,
      );
    }
    final t0 = samples.first.t;
    final spanT = (samples.last.t - t0).clamp(1, 1 << 30);
    for (var n = 0; n < notes.length; n++) {
      final x = ((notes[n].t - t0) / spanT).clamp(0.0, 1.0) * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = DeckColors.volt.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
    }
    final x = index / (samples.length - 1) * size.width;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = DeckColors.volt
        ..strokeWidth = 1.2,
    );
  }

  void _line(Canvas canvas, Size size, List<double?> ys, Color color) {
    final finite = ys.whereType<double>().toList();
    if (finite.isEmpty) return;
    final minY = finite.reduce(math.min);
    final maxY = finite.reduce(math.max);
    final span = (maxY - minY).abs() < 1e-6 ? 1.0 : maxY - minY;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    ui.Path? path;
    for (var i = 0; i < ys.length; i++) {
      final yv = ys[i];
      if (yv == null) {
        if (path != null) {
          canvas.drawPath(path, paint);
          path = null;
        }
        continue;
      }
      final x = i / (ys.length - 1) * size.width;
      final y = size.height - (yv - minY) / span * size.height;
      if (path == null) {
        path = ui.Path()..moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    if (path != null) canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CurvesPainter old) =>
      old.index != index || old.samples != samples || old.notes != notes;
}
