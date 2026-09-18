import 'dart:math';

import 'package:flutter/material.dart';

import '../session/heel.dart';
import '../theme/deck_theme.dart';

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
        Flexible(
          child: Text(
            leftLabel,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: leftColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              fontSize: 11,
            ),
          ),
        ),
        Text(
          cox ? 'réf. barreur' : 'réf. rameur',
          style: const TextStyle(color: DeckColors.label, fontSize: 9),
        ),
        Flexible(
          child: Text(
            rightLabel,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: rightColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

/// Jauge + horizon. Rameur : + à gauche (tribord / vert).
/// Barreur : + (tribord / vert) à droite.
class HeelGauge extends StatelessWidget {
  const HeelGauge({
    super.key,
    required this.giteDeg,
    this.perspective = HeelPerspective.rower,
  });

  final double giteDeg;
  final HeelPerspective perspective;

  @override
  Widget build(BuildContext context) {
    final v = clampHeel(giteDeg);
    final x = heelAlignmentX(v, perspective: perspective);
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: CustomPaint(
            painter: _HorizonPainter(
              giteDeg: perspective == HeelPerspective.cox ? -v : v,
            ),
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
