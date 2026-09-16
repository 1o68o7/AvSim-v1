import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../session/model.dart';
import '../../session/summary.dart';
import '../../theme/deck_theme.dart';

class ReplayBody extends StatefulWidget {
  const ReplayBody({
    super.key,
    required this.samples,
    this.title = 'REPLAY',
  });

  final List<SessionSample> samples;
  final String title;

  @override
  State<ReplayBody> createState() => _ReplayBodyState();
}

class _ReplayBodyState extends State<ReplayBody> {
  final _map = MapController();
  int _index = 0;

  List<SessionSample> get _samples => widget.samples;

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

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: FlutterMap(
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
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'V sol  ${cur.sog == null ? '—' : '${cur.sog!.toStringAsFixed(2)} m/s'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Text(
                  'dist  ${(cur.distM / 1000).toStringAsFixed(3)} km',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                hasFix ? 'fix' : 'GPS trou',
                style: const TextStyle(color: DeckColors.label, fontSize: 11),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 72,
          child: CustomPaint(
            painter: _CurvesPainter(samples: _samples, index: i),
            child: const SizedBox.expand(),
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
            final s = _samples[_index];
            if (s.lat != null && s.lon != null) {
              try {
                _map.move(LatLng(s.lat!, s.lon!), _map.camera.zoom);
              } catch (_) {}
            }
          },
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'courbes : cadence (ambre) · V sol (blanc)  ·  sol — pas eau',
            style: TextStyle(color: DeckColors.label, fontSize: 10),
          ),
        ),
      ],
    );
  }
}

class _CurvesPainter extends CustomPainter {
  _CurvesPainter({required this.samples, required this.index});

  final List<SessionSample> samples;
  final int index;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;
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
    final x = index / (samples.length - 1) * size.width;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = DeckColors.amber
        ..strokeWidth = 1,
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
      old.index != index || old.samples != samples;
}
