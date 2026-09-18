import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/deck_theme.dart';

/// Anneau de tare adaptative (3–30 s).
class TareRing extends StatelessWidget {
  const TareRing({
    super.key,
    required this.progress,
    required this.caption,
    this.done = false,
    this.size = 64,
  });

  /// 0–1, se remplit jusqu’à 30 s (ou 1.0 dès OK / approx).
  final double progress;
  final String caption;
  final bool done;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return Semantics(
      label: 'Tare gîte $caption',
      value: '${(p * 100).round()} pour cent',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(progress: p),
          child: Center(
            child: Text(
              caption,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: done ? DeckColors.tribord : DeckColors.amber,
                fontWeight: FontWeight.w700,
                fontSize: caption.length > 4 ? 8 : 11,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 5;
    final bg = Paint()
      ..color = const Color(0xFF232830)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(c, r, bg);
    final fg = Paint()
      ..color = DeckColors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
