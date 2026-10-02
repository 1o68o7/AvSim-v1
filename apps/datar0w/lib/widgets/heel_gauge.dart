import 'dart:math';

import 'package:flutter/material.dart';

import '../session/heel.dart';
import '../theme/deck_theme.dart';

/// 1° de gîte → 2° d’arc (ticks Stitch DR-52 ±15° ≈ ±30° géom.).
const double kHeelVisualScale = 2.0;

class HeelLabels extends StatelessWidget {
  const HeelLabels({
    super.key,
    this.perspective = HeelPerspective.rower,
  });

  final HeelPerspective perspective;

  @override
  Widget build(BuildContext context) {
    final cox = perspective == HeelPerspective.cox;
    final leftLabel = cox ? 'BÂBORD' : 'TRIBORD';
    final rightLabel = cox ? 'TRIBORD' : 'BÂBORD';
    final leftColor = cox ? DeckColors.babord : DeckColors.tribord;
    final rightColor = cox ? DeckColors.tribord : DeckColors.babord;
    return Row(
      children: [
        _SideChip(label: leftLabel, color: leftColor, leading: '◀ '),
        Expanded(
          child: Text(
            cox ? 'réf. barreur' : 'réf. rameur',
            textAlign: TextAlign.center,
            style: DeckType.labelMono(color: DeckColors.label, size: 9),
          ),
        ),
        _SideChip(label: rightLabel, color: rightColor, trailing: ' ▶'),
      ],
    );
  }
}

class _SideChip extends StatelessWidget {
  const _SideChip({
    required this.label,
    required this.color,
    this.leading = '',
    this.trailing = '',
  });

  final String label;
  final Color color;
  final String leading;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final style = DeckType.labelMono(
      color: color,
      size: 10,
      weight: FontWeight.w700,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: DeckRadii.chipAll,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading.isNotEmpty) Text(leading, style: style),
          Text(label, style: style),
          if (trailing.isNotEmpty) Text(trailing, style: style),
        ],
      ),
    );
  }
}

/// Cadran gîte avionique DR-52 — arc ±15°, aiguille + horizon coque.
/// Rameur : + = tribords = gauche écran. Barreur : côtés inversés.
class HeelGauge extends StatelessWidget {
  const HeelGauge({
    super.key,
    required this.giteDeg,
    this.perspective = HeelPerspective.rower,
    this.toleranceDeg = 3,
    this.showHorizonCaption = true,
  });

  final double giteDeg;
  final HeelPerspective perspective;
  final double toleranceDeg;
  final bool showHorizonCaption;

  @override
  Widget build(BuildContext context) {
    final v = clampHeel(giteDeg);
    // Signe écran : +gîte rameur → rotation CCW (gauche).
    final paintDeg = perspective == HeelPerspective.cox ? -v : v;
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight.isFinite && c.maxHeight > 0
            ? c.maxHeight
            : 160.0;
        return SizedBox(
          width: c.maxWidth,
          height: h,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                painter: HeelArcPainter(
                  giteDeg: paintDeg,
                  toleranceDeg: toleranceDeg,
                  // Couleurs côtés écran (après éventuelle inversion cox).
                  leftIsTribord: perspective == HeelPerspective.rower,
                ),
                child: const SizedBox.expand(),
              ),
              if (showHorizonCaption)
                Positioned(
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: DeckColors.surfaceHighest.withValues(alpha: 0.7),
                      borderRadius: DeckRadii.chipAll,
                      border: Border.all(color: DeckColors.hairline),
                    ),
                    child: Text(
                      'HORIZON COQUE 0.0°',
                      style: DeckType.labelMono(
                        color: DeckColors.text,
                        size: 9,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class HeelArcPainter extends CustomPainter {
  HeelArcPainter({
    required this.giteDeg,
    required this.toleranceDeg,
    required this.leftIsTribord,
  });

  final double giteDeg;
  final double toleranceDeg;
  final bool leftIsTribord;

  Color get _leftColor =>
      leftIsTribord ? DeckColors.tribord : DeckColors.babord;
  Color get _rightColor =>
      leftIsTribord ? DeckColors.babord : DeckColors.tribord;

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width / 2, size.height * 0.78);
    final radius = min(size.width * 0.42, size.height * 0.72);

    // Arc fond.
    final bg = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: pivot, radius: radius),
      pi,
      pi,
      false,
      bg,
    );

    // Secteur tolérance (±tol) rétroéclairé Volt.
    final tolVis = toleranceDeg * kHeelVisualScale * pi / 180;
    final safe = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..arcTo(
        Rect.fromCircle(center: pivot, radius: radius),
        -pi / 2 - tolVis,
        tolVis * 2,
        false,
      )
      ..close();
    canvas.drawPath(
      safe,
      Paint()..color = DeckColors.volt.withValues(alpha: 0.14),
    );

    // Arc gauche / droite (gradients).
    _drawSideArc(canvas, pivot, radius, left: true, color: _leftColor);
    _drawSideArc(canvas, pivot, radius, left: false, color: _rightColor);

    // Fenêtre tolérance active.
    canvas.drawArc(
      Rect.fromCircle(center: pivot, radius: radius),
      -pi / 2 - tolVis,
      tolVis * 2,
      false,
      Paint()
        ..color = DeckColors.volt
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // Graduations.
    for (final deg in [2.0, 4.0, 5.0, 8.0, 10.0, 12.0, 15.0]) {
      _tick(canvas, pivot, radius, -deg, major: deg % 5 == 0);
      _tick(canvas, pivot, radius, deg, major: deg % 5 == 0);
    }
    // 0°
    _tick(canvas, pivot, radius, 0, major: true, zero: true);

    // Horizon coque (mobile).
    final needleRad = -giteDeg * kHeelVisualScale * pi / 180;
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(needleRad);
    final horizon = Paint()
      ..color = DeckColors.volt.withValues(alpha: 0.85)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(-radius * 1.35, 0), Offset(radius * 1.35, 0), horizon
      ..strokeWidth = 1.2);
    // Ailettes.
    final wing = Paint()
      ..color = DeckColors.surface
      ..style = PaintingStyle.fill;
    final wingStroke = Paint()
      ..color = DeckColors.volt
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final x in [-radius * 0.85, radius * 0.28]) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, -2.5, radius * 0.55, 5),
        const Radius.circular(2.5),
      );
      canvas.drawRRect(r, wing);
      canvas.drawRRect(r, wingStroke);
    }
    // Quille V.
    final keel = Path()
      ..moveTo(-7, 0)
      ..lineTo(0, 8)
      ..lineTo(7, 0)
      ..close();
    canvas.drawPath(keel, Paint()..color = DeckColors.volt.withValues(alpha: 0.9));
    canvas.restore();

    // Aiguille.
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(needleRad);
    canvas.drawLine(
      Offset.zero,
      Offset(0, -radius + 8),
      Paint()
        ..color = DeckColors.volt.withValues(alpha: 0.35)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset.zero,
      Offset(0, -radius + 8),
      Paint()
        ..color = DeckColors.text
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset.zero,
      const Offset(0, 18),
      Paint()
        ..color = DeckColors.volt
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(0, 16), 3.5, Paint()..color = DeckColors.volt);
    final tip = Path()
      ..moveTo(0, -radius + 2)
      ..lineTo(-5, -radius + 14)
      ..lineTo(5, -radius + 14)
      ..close();
    canvas.drawPath(tip, Paint()..color = DeckColors.volt);
    canvas.restore();

    // Hub.
    canvas.drawCircle(
      pivot,
      22,
      Paint()..color = DeckColors.volt.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      pivot,
      10,
      Paint()
        ..color = DeckColors.surface
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      pivot,
      10,
      Paint()
        ..color = const Color(0xFF454934)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      pivot,
      6.5,
      Paint()
        ..color = DeckColors.bg
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      pivot,
      6.5,
      Paint()
        ..color = DeckColors.volt
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(pivot, 2.2, Paint()..color = DeckColors.text);
  }

  void _drawSideArc(
    Canvas canvas,
    Offset pivot,
    double radius, {
    required bool left,
    required Color color,
  }) {
    // Demi-arc : gauche π → −π/2, droite −π/2 → 0.
    final start = left ? pi : -pi / 2;
    canvas.drawArc(
      Rect.fromCircle(center: pivot, radius: radius),
      start,
      pi / 2,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _tick(
    Canvas canvas,
    Offset pivot,
    double radius,
    double heelDeg, {
    required bool major,
    bool zero = false,
  }) {
    final vis = heelDeg.abs() * kHeelVisualScale * pi / 180;
    // 0 en haut (−π/2) ; +heelDeg → droite (horaire) dans l’espace paint.
    final a = -pi / 2 + (heelDeg >= 0 ? vis : -vis);
    final outer = Offset(
      pivot.dx + cos(a) * (radius + (major ? 4 : 0)),
      pivot.dy + sin(a) * (radius + (major ? 4 : 0)),
    );
    final inner = Offset(
      pivot.dx + cos(a) * (radius - (major ? 10 : 5)),
      pivot.dy + sin(a) * (radius - (major ? 10 : 5)),
    );
    final color = zero
        ? DeckColors.volt
        : major
            ? (heelDeg < 0 ? _leftColor : _rightColor)
            : DeckColors.label.withValues(alpha: 0.7);
    canvas.drawLine(
      outer,
      inner,
      Paint()
        ..color = color
        ..strokeWidth = major ? 2 : 0.8
        ..strokeCap = StrokeCap.round,
    );
    if (major) {
      final label = zero ? '0°' : '${heelDeg.abs().toStringAsFixed(0)}°';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: DeckType.mono,
            fontSize: zero ? 9 : 8,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelR = radius + 14;
      tp.paint(
        canvas,
        Offset(
          pivot.dx + cos(a) * labelR - tp.width / 2,
          pivot.dy + sin(a) * labelR - tp.height / 2,
        ),
      );
      if (zero) {
        final tri = Path()
          ..moveTo(pivot.dx, pivot.dy - radius - 12)
          ..lineTo(pivot.dx - 3.5, pivot.dy - radius - 17)
          ..lineTo(pivot.dx + 3.5, pivot.dy - radius - 17)
          ..close();
        canvas.drawPath(tri, Paint()..color = DeckColors.volt);
      }
    }
  }

  @override
  bool shouldRepaint(covariant HeelArcPainter old) =>
      old.giteDeg != giteDeg ||
      old.toleranceDeg != toleranceDeg ||
      old.leftIsTribord != leftIsTribord;
}
