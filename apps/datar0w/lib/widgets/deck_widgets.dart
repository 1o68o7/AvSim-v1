import 'package:flutter/material.dart';

import '../identity/format.dart';
import '../identity/models.dart';
import '../theme/deck_theme.dart';

/// Pastille statut (Stitch : 1px hairline, pastille carrée).
class DeckStatusChip extends StatelessWidget {
  const DeckStatusChip({
    super.key,
    required this.label,
    this.ok = false,
    this.alert = false,
  });

  final String label;
  final bool ok;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final border = alert
        ? DeckColors.amber
        : DeckColors.hairline;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: alert ? DeckColors.amber : Colors.transparent,
        border: Border.all(color: border),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              color: alert
                  ? DeckColors.onAlert
                  : (ok ? DeckColors.tribord : DeckColors.hairline),
            ),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
                color: alert ? DeckColors.onAlert : DeckColors.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Enceinte instrument 1px `#2A2F36`, label haut, valeur blanche.
class InstrumentPod extends StatelessWidget {
  const InstrumentPod({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.child,
    this.flex,
  });

  final String label;
  final String value;
  final String? unit;
  final Widget? child;
  final int? flex;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        color: DeckColors.bg,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 20,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: DeckColors.label,
                fontSize: 9,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(height: 1, color: DeckColors.hairline),
          const SizedBox(height: 6),
          if (child != null)
            child!
          else ...[
            Text(
              value,
              style: const TextStyle(
                color: DeckColors.text,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
                height: 1,
              ),
            ),
            if (unit != null)
              Text(
                unit!,
                style: const TextStyle(
                  color: DeckColors.label,
                  fontSize: 9,
                  letterSpacing: 1.2,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class DeckIconBox extends StatelessWidget {
  const DeckIconBox({
    super.key,
    required this.icon,
    this.accent = false,
    this.muted = false,
  });

  final IconData icon;
  final bool accent;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = muted
        ? DeckColors.label
        : (accent ? DeckColors.amber : DeckColors.label);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: DeckColors.bg,
        border: Border.all(
          color: accent ? DeckColors.amber.withValues(alpha: 0.4) : DeckColors.hairline,
        ),
      ),
      child: Icon(icon, size: 22, color: c),
    );
  }
}

/// Titre de section Deck (Stitch hairline + letter-spacing).
class DeckSectionLabel extends StatelessWidget {
  const DeckSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: const TextStyle(
              color: DeckColors.label,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Cellule fiche (label + valeur), grille Stitch accueil / physio.
class DeckFactCell extends StatelessWidget {
  const DeckFactCell({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.accent,
  });

  final String label;
  final String value;
  final String? hint;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: DeckColors.label,
            fontSize: 9,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: accent ?? DeckColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.4,
          ),
        ),
        if (hint != null)
          Text(
            hint!,
            style: const TextStyle(color: DeckColors.muted, fontSize: 10),
          ),
      ],
    );
  }
}

/// Pastille côté BÂBORD / TRIBORD (Stitch).
class DeckSideChip extends StatelessWidget {
  const DeckSideChip(this.side, {super.key});

  final SidePref side;

  @override
  Widget build(BuildContext context) {
    final label = sideLabel(side);
    final color = switch (side) {
      SidePref.babord => DeckColors.babord,
      SidePref.tribord => DeckColors.tribord,
      SidePref.none => DeckColors.label,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

/// Répartition latérale sièges (étrave → poupe). Siège 1 = nage.
class DeckSeatStrip extends StatelessWidget {
  const DeckSeatStrip({
    super.key,
    required this.seats,
    required this.assignments,
    this.highlightSeat,
    this.coxed = false,
  });

  final int seats;
  final List<Assignment> assignments;
  final int? highlightSeat;
  final bool coxed;

  Assignment? _at(int seat) {
    for (final a in assignments) {
      if (a.role != 'cox' && a.seatIndex == seat) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[];
    for (var seat = seats; seat >= 1; seat--) {
      final a = _at(seat);
      final hi = highlightSeat == seat;
      final side = a?.side ?? SidePref.none;
      final short = switch (side) {
        SidePref.babord => 'BÂB',
        SidePref.tribord => 'TRI',
        SidePref.none => '—',
      };
      final color = hi
          ? DeckColors.amber
          : switch (side) {
              SidePref.babord => DeckColors.babord,
              SidePref.tribord => DeckColors.tribord,
              SidePref.none => DeckColors.label,
            };
      cells.add(
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: hi ? DeckColors.amber : DeckColors.bg,
              border: Border.all(
                color: hi ? DeckColors.amber : DeckColors.hairline,
              ),
            ),
            child: Column(
              children: [
                Text(
                  '$seat',
                  style: TextStyle(
                    color: hi ? DeckColors.onAlert : DeckColors.label,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  short,
                  style: TextStyle(
                    color: hi ? DeckColors.onAlert : color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (coxed) {
      cells.add(
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: DeckColors.hairline),
            ),
            child: const Column(
              children: [
                Text(
                  'C',
                  style: TextStyle(
                    color: DeckColors.label,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'COX',
                  style: TextStyle(
                    color: DeckColors.text,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ÉTRAVE',
              style: TextStyle(color: DeckColors.label, fontSize: 9),
            ),
            Text(
              'POUPE',
              style: TextStyle(color: DeckColors.label, fontSize: 9),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(children: cells),
      ],
    );
  }
}

/// Marque DataR0w (Stitch logo, DA Deck : ambre pas cyan High-Vis).
class DataR0wMark extends StatelessWidget {
  const DataR0wMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'DataR0w',
      child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(compact ? 22 : 28, compact ? 22 : 28),
          painter: _DiamondPainter(),
        ),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontSize: compact ? 16 : 20,
              color: DeckColors.text,
            ),
            children: const [
              TextSpan(text: 'DATA'),
              TextSpan(
                text: 'R0W',
                style: TextStyle(color: DeckColors.amber),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}

class _DiamondPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final p = Path()
      ..moveTo(c.dx, 2)
      ..lineTo(size.width - 2, c.dy)
      ..lineTo(c.dx, size.height - 2)
      ..lineTo(2, c.dy)
      ..close();
    canvas.drawPath(
      p,
      Paint()
        ..color = DeckColors.amber.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      p,
      Paint()
        ..color = DeckColors.amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(c, 2.5, Paint()..color = DeckColors.amber);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
