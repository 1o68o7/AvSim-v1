import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/deck_theme.dart';

/// Cercle 30 s (Stitch 2B HUD).
class TareRing extends StatelessWidget {
  const TareRing({
    super.key,
    required this.elapsedS,
    this.size = 64,
  });

  final int elapsedS;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = (elapsedS / 30).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(progress: p),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${elapsedS}s',
                style: const TextStyle(
                  color: DeckColors.amber,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  height: 1,
                ),
              ),
              const Text(
                '/ 30s',
                style: TextStyle(
                  color: DeckColors.label,
                  fontSize: 8,
                  height: 1.2,
                ),
              ),
            ],
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
