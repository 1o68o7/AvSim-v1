import 'dart:math';

import 'package:flutter/material.dart';

import '../session/heel.dart';
import '../theme/deck_theme.dart';

class HeelLabels extends StatelessWidget {
  const HeelLabels({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'TRIBORD',
          style: TextStyle(
            color: DeckColors.tribord,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        Text(
          'réf. rameur',
          style: TextStyle(color: DeckColors.label, fontSize: 10),
        ),
        Text(
          'BÂBORD',
          style: TextStyle(
            color: DeckColors.babord,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

/// Jauge + horizon : + à gauche (tribord / vert).
class HeelGauge extends StatelessWidget {
  const HeelGauge({super.key, required this.giteDeg});

  final double giteDeg;

  @override
  Widget build(BuildContext context) {
    final v = clampHeel(giteDeg);
    final x = heelAlignmentX(v);
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: CustomPaint(
            painter: _HorizonPainter(giteDeg: v),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(height: 4, color: DeckColors.hairline),
              Align(
                alignment: Alignment(x, 0),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: v >= 0 ? DeckColors.tribord : DeckColors.babord,
                    border: Border.all(color: DeckColors.text),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HorizonPainter extends CustomPainter {
  _HorizonPainter({required this.giteDeg});

  final double giteDeg;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(giteDeg * pi / 180);
    final line = Paint()
      ..color = DeckColors.amber
      ..strokeWidth = 2;
    canvas.drawLine(Offset(-size.width / 2 + 8, 0), Offset(size.width / 2 - 8, 0), line);
    canvas.drawCircle(Offset.zero, 3, Paint()..color = DeckColors.text);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HorizonPainter old) => old.giteDeg != giteDeg;
}
