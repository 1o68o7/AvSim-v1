import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../session/model.dart';
import '../../session/store.dart';
import '../../session/summary.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_widgets.dart';

class ReplayBody extends StatefulWidget {
  const ReplayBody({
    super.key,
    required this.samples,
    this.notes = const [],
    this.meta,
    this.title = 'REPLAY',
  });

  final List<SessionSample> samples;
  final List<SessionNote> notes;
  final SessionMeta? meta;
  final String title;

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
        : (cur.giteDeg! >= 0 ? 'TRIBORDS' : 'BÂBORD');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(
            children: [
              Text(
                widget.meta?.code == null
                    ? 'SÉANCE  1X'
                    : 'SÉANCE  ${widget.meta!.code}  ·  1X',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              DeckStatusChip(label: 'FICHIER CHARGÉ', ok: true),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final landscape = c.maxWidth > 640;
              final map = FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 15,
                  backgroundColor: DeckColors.bg,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'io.datar0w.datar0w',
                  ),
                  PolylineLayer(
                    polylines: [
                      for (final seg in segs)
                        if (seg.length >= 2)
                          Polyline(
                            points: seg,
                            color: DeckColors.amber,
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
                              color: DeckColors.amber,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              );
              final curves = Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Container(width: 12, height: 2, color: DeckColors.amber),
                        const SizedBox(width: 6),
                        const Text(
                          'CADENCE (SPM)',
                          style: TextStyle(
                            color: DeckColors.amber,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(width: 12, height: 2, color: Colors.white),
                        const SizedBox(width: 6),
                        const Text(
                          'V. SOL (m/s)',
                          style: TextStyle(fontSize: 10),
                        ),
                        const Spacer(),
                        Text(
                          '${formatDuration(elapsed)} / ${formatDuration(total)}',
                          style: const TextStyle(
                            color: DeckColors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CustomPaint(
                      painter: _CurvesPainter(
                        samples: _samples,
                        index: i,
                        notes: widget.notes,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              );
              final values = _CursorPanel(
                cur: cur,
                dCad: dCad,
                giteSide: giteSide,
                notes: widget.notes,
                noteIdx: noteIdx,
                onJump: _jumpToNote,
                elapsed: elapsed,
              );
              if (landscape) {
                return Row(
                  children: [
                    Expanded(
                      flex: 7,
                      child: Column(
                        children: [
                          Expanded(flex: 4, child: map),
                          Expanded(flex: 5, child: curves),
                        ],
                      ),
                    ),
                    Container(width: 1, color: DeckColors.hairline),
                    SizedBox(width: 236, child: values),
                  ],
                );
              }
              return Column(
                children: [
                  Expanded(flex: 3, child: map),
                  Expanded(flex: 2, child: curves),
                  SizedBox(height: 168, child: values),
                ],
              );
            },
          ),
        ),
        Slider(
          value: i.toDouble(),
          min: 0,
          max: (_samples.length - 1).toDouble(),
          divisions: _samples.length > 1 ? _samples.length - 1 : 1,
          activeColor: DeckColors.amber,
          onChanged: (v) {
            setState(() => _index = v.round());
            _moveMap();
          },
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            'MODE REPLAY  ·  sol — pas eau  ·  cadence — si absente',
            style: TextStyle(color: DeckColors.label, fontSize: 10),
          ),
        ),
      ],
    );
  }
}

class _CursorPanel extends StatelessWidget {
  const _CursorPanel({
    required this.cur,
    required this.dCad,
    required this.giteSide,
    required this.notes,
    required this.noteIdx,
    required this.onJump,
    required this.elapsed,
  });

  final SessionSample cur;
  final double? dCad;
  final String giteSide;
  final List<SessionNote> notes;
  final int noteIdx;
  final void Function(int) onJump;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InstrumentPod(
            label: 'VALEURS AU CURSEUR  (${formatDuration(elapsed)})',
            value: '',
            child: Column(
              children: [
                _kv(
                  'CADENCE',
                  cur.cadenceSpm == null
                      ? '—'
                      : '${cur.cadenceSpm!.toStringAsFixed(0)} SPM',
                  DeckColors.amber,
                ),
                _kv(
                  'V. SOL (GPS)',
                  cur.sog == null
                      ? '—'
                      : '${cur.sog!.toStringAsFixed(2)} m/s',
                  DeckColors.text,
                ),
                _kv(
                  'DISTANCE',
                  '${(cur.distM / 1000).toStringAsFixed(3)} km',
                  DeckColors.text,
                ),
                _kv(
                  'GÎTE',
                  cur.giteDeg == null
                      ? '—'
                      : '${cur.giteDeg!.toStringAsFixed(1)}° $giteSide',
                  (cur.giteDeg ?? 0) >= 0
                      ? DeckColors.tribord
                      : DeckColors.babord,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dCad == null
                ? 'Δ CADENCE  —'
                : 'Δ CADENCE  ${dCad! >= 0 ? '+' : ''}${dCad!.toStringAsFixed(0)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: DeckColors.amber,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          if (notes.isNotEmpty)
            Wrap(
              spacing: 6,
              children: [
                for (var n = 0; n < notes.length; n++)
                  OutlinedButton(
                    onPressed: () => onJump(n),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      foregroundColor: n == noteIdx
                          ? DeckColors.onAlert
                          : DeckColors.amber,
                      backgroundColor:
                          n == noteIdx ? DeckColors.amber : Colors.transparent,
                    ),
                    child: Text('NOTE ${n + 1}'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, Color c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            k,
            style: const TextStyle(color: DeckColors.label, fontSize: 10),
          ),
          const Spacer(),
          Text(
            v,
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w700,
              fontSize: 11,
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
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF090C10));
    _line(
      canvas,
      size,
      samples.map((s) => s.cadenceSpm).toList(),
      DeckColors.amber,
    );
    _line(
      canvas,
      size,
      samples.map((s) => s.sog).toList(),
      Colors.white70,
    );
    final t0 = samples.first.t;
    final spanT = (samples.last.t - t0).clamp(1, 1 << 30);
    for (var n = 0; n < notes.length; n++) {
      final x = ((notes[n].t - t0) / spanT).clamp(0.0, 1.0) * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = DeckColors.amber.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
    }
    final x = index / (samples.length - 1) * size.width;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = DeckColors.amber
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
