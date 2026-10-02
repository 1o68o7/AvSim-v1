import 'package:flutter/material.dart';

import '../identity/format.dart';
import '../identity/models.dart';
import '../session/boat_config.dart';
import '../theme/deck_theme.dart';

/// Honest status badge — LOCAL / EN FILE / CLOUD / MOCK (6px radius, mono).
enum DeckHonestKind { local, enFile, cloud, mock, club }

class DeckHonestChip extends StatelessWidget {
  const DeckHonestChip({
    super.key,
    required this.kind,
    this.label,
  });

  final DeckHonestKind kind;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border, text) = switch (kind) {
      DeckHonestKind.local => (
          DeckColors.chipLocalBg,
          DeckColors.label,
          DeckColors.hairline,
          'LOCAL',
        ),
      DeckHonestKind.enFile => (
          DeckColors.amberWash,
          DeckColors.amber,
          DeckColors.amber,
          'EN FILE',
        ),
      DeckHonestKind.cloud => (
          DeckColors.tribordWash,
          DeckColors.tribord,
          DeckColors.tribord,
          'CLOUD',
        ),
      DeckHonestKind.mock => (
          DeckColors.babordWash,
          DeckColors.babord,
          DeckColors.babord,
          'DÉMO',
        ),
      DeckHonestKind.club => (
          DeckColors.amberWash,
          DeckColors.amber,
          DeckColors.amber,
          'CLUB',
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DeckRadii.chipAll,
        border: Border.all(color: border),
      ),
      child: Text(
        label ?? text,
        style: DeckType.labelMono(color: fg),
      ),
    );
  }
}

/// Pastille statut générique (ok / alerte).
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
        : ok
            ? DeckColors.tribord
            : DeckColors.hairline;
    final bg = alert
        ? DeckColors.amberWash
        : ok
            ? DeckColors.tribordWash
            : DeckColors.chipLocalBg;
    final fg = alert
        ? DeckColors.amber
        : ok
            ? DeckColors.tribord
            : DeckColors.label;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DeckRadii.chipAll,
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
              decoration: BoxDecoration(
                color: fg,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: DeckType.labelMono(color: fg, size: 10),
            ),
          ],
        ),
      ),
    );
  }
}

/// Telemetry HUD card — surface + 1px hairline, metric mono.
class InstrumentPod extends StatelessWidget {
  const InstrumentPod({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.child,
    this.flex,
    this.delta,
    this.deltaPositive,
  });

  final String label;
  final String value;
  final String? unit;
  final Widget? child;
  final int? flex;
  final String? delta;
  final bool? deltaPositive;

  @override
  Widget build(BuildContext context) {
    // Padding compact : grille live paysage 844×390.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: DeckRadii.cardAll,
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
              if (unit != null) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    unit!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: DeckType.labelMono(
                      color: DeckColors.label.withValues(alpha: 0.6),
                      size: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          if (child != null)
            child!
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: DeckType.metric(size: 28, weight: FontWeight.w700),
              ),
            ),
          if (delta != null) ...[
            const SizedBox(height: 2),
            Text(
              delta!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DeckType.labelMono(
                color: deltaPositive == true
                    ? DeckColors.tribord
                    : deltaPositive == false
                        ? DeckColors.babord
                        : DeckColors.label,
                size: 11,
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
        : (accent ? DeckColors.volt : DeckColors.label);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: DeckRadii.buttonAll,
        border: Border.all(
          color: accent ? DeckColors.volt : DeckColors.hairline,
        ),
      ),
      child: Icon(icon, size: 22, color: c),
    );
  }
}

/// Titre de section — sentence-case Inter (plus de screaming caps Hangar).
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
            text,
            style: const TextStyle(
              fontFamily: DeckType.ui,
              color: DeckColors.label,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Cellule fiche (label + valeur).
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
        Text(label, style: DeckType.uiLabel(size: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: DeckType.ui,
            color: accent ?? DeckColors.text,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        if (hint != null)
          Text(
            hint!,
            style: const TextStyle(
              fontFamily: DeckType.ui,
              color: DeckColors.muted,
              fontSize: 11,
            ),
          ),
      ],
    );
  }
}

/// Pastille côté Bâbord / Tribord.
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
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: DeckType.ui,
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
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
        SidePref.babord => 'Bâb',
        SidePref.tribord => 'Tri',
        SidePref.none => '—',
      };
      final color = hi
          ? DeckColors.onVolt
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
              color: hi ? DeckColors.volt : DeckColors.surface,
              borderRadius: DeckRadii.chipAll,
              border: Border.all(
                color: hi ? DeckColors.volt : DeckColors.hairline,
              ),
            ),
            child: Column(
              children: [
                Text(
                  '$seat',
                  style: TextStyle(
                    fontFamily: DeckType.mono,
                    color: hi ? DeckColors.onVolt : DeckColors.label,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  short,
                  style: TextStyle(
                    fontFamily: DeckType.ui,
                    color: hi ? DeckColors.onVolt : color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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
              borderRadius: DeckRadii.chipAll,
              border: Border.all(color: DeckColors.hairline),
            ),
            child: const Column(
              children: [
                Text(
                  'C',
                  style: TextStyle(
                    fontFamily: DeckType.mono,
                    color: DeckColors.label,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Cox',
                  style: TextStyle(
                    fontFamily: DeckType.ui,
                    color: DeckColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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
              'Étrave',
              style: TextStyle(
                fontFamily: DeckType.ui,
                color: DeckColors.label,
                fontSize: 11,
              ),
            ),
            Text(
              'Poupe',
              style: TextStyle(
                fontFamily: DeckType.ui,
                color: DeckColors.label,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(children: cells),
      ],
    );
  }
}

/// Marque DataR0w — accent Volt.
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
                fontFamily: DeckType.ui,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 16 : 20,
                color: DeckColors.text,
              ),
              children: const [
                TextSpan(text: 'Data'),
                TextSpan(
                  text: 'R0w',
                  style: TextStyle(color: DeckColors.volt),
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
        ..color = DeckColors.volt.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      p,
      Paint()
        ..color = DeckColors.volt
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(c, 2.5, Paint()..color = DeckColors.volt);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pilule LOCAL · EN FILE · CLOUD (DR-20).
class DeckSyncPill extends StatelessWidget {
  const DeckSyncPill({
    super.key,
    this.highlight = DeckHonestKind.local,
  });

  final DeckHonestKind highlight;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, DeckHonestKind kind) {
      final on = kind == highlight;
      final color = switch (kind) {
        DeckHonestKind.cloud => DeckColors.tribord,
        DeckHonestKind.enFile => DeckColors.amber,
        _ => on ? DeckColors.text : DeckColors.label,
      };
      return Text(
        label,
        style: DeckType.labelMono(
          color: color,
          size: 10,
          weight: on ? FontWeight.w600 : FontWeight.w500,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: DeckColors.bgTactical,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: highlight == DeckHonestKind.cloud
                  ? DeckColors.tribord
                  : highlight == DeckHonestKind.enFile
                      ? DeckColors.amber
                      : DeckColors.label,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          seg('LOCAL', DeckHonestKind.local),
          Text(' · ', style: DeckType.labelMono(size: 10)),
          seg('EN FILE', DeckHonestKind.enFile),
          Text(' · ', style: DeckType.labelMono(size: 10)),
          seg('CLOUD', DeckHonestKind.cloud),
        ],
      ),
    );
  }
}

/// Sélecteur Entraînement / Compétition (DR-20).
class DeckSessionModeSwitch extends StatelessWidget {
  const DeckSessionModeSwitch({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final SessionMode mode;
  final ValueChanged<SessionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, SessionMode value) {
      final on = mode == value;
      return GestureDetector(
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: on ? DeckColors.volt : Colors.transparent,
            borderRadius: DeckRadii.chipAll,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: DeckType.ui,
              fontSize: 13,
              fontWeight: on ? FontWeight.w600 : FontWeight.w500,
              color: on ? DeckColors.onVolt : DeckColors.label,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: DeckColors.bgTactical,
        borderRadius: DeckRadii.buttonAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chip('Entraînement', SessionMode.training),
          chip('Compétition', SessionMode.competition),
        ],
      ),
    );
  }
}
