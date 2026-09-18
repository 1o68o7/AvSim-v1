import 'package:flutter/material.dart';

import '../session/heel.dart';
import '../theme/deck_theme.dart';

/// Overlay haut d’écran : ne pousse pas le layout. Fond semi-transparent.
class HeelBanner extends StatefulWidget {
  const HeelBanner({super.key, required this.alert});

  final HeelAlert alert;

  static Color backgroundFor(HeelAlert alert) => switch (alert) {
        HeelAlert.babord => DeckColors.babord.withValues(alpha: 0.80),
        HeelAlert.tribord => DeckColors.tribord.withValues(alpha: 0.80),
        HeelAlert.none => Colors.transparent,
      };

  static Color foregroundFor(HeelAlert alert) => Colors.white;

  static String messageFor(HeelAlert alert) => switch (alert) {
        HeelAlert.babord => 'GÎTE — trop bâbord',
        HeelAlert.tribord => 'GÎTE — trop tribords',
        HeelAlert.none => '',
      };

  @override
  State<HeelBanner> createState() => _HeelBannerState();
}

class _HeelBannerState extends State<HeelBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  HeelAlert _paint = HeelAlert.none;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 300),
    );
    if (widget.alert != HeelAlert.none) {
      _paint = widget.alert;
      _fade.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant HeelBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.alert != HeelAlert.none) {
      _paint = widget.alert;
      _fade.forward();
    } else if (oldWidget.alert != HeelAlert.none) {
      _fade.reverse();
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _fade,
          builder: (context, _) {
            if (_fade.value == 0 || _paint == HeelAlert.none) {
              return const SizedBox(height: 0, width: double.infinity);
            }
            final top = HeelBanner.backgroundFor(_paint);
            return Semantics(
              liveRegion: true,
              label: HeelBanner.messageFor(_paint),
              child: Container(
                height: 56,
                width: double.infinity,
                alignment: Alignment.topCenter,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      top,
                      top.withValues(alpha: 0),
                    ],
                  ),
                ),
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  HeelBanner.messageFor(_paint),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: HeelBanner.foregroundFor(_paint),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    fontSize: 13,
                    height: 1.2,
                    shadows: const [
                      Shadow(color: Color(0xCC000000), blurRadius: 4),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Empile le bandeau au-dessus de [child] sans modifier la hauteur du contenu.
class HeelAlertOverlay extends StatelessWidget {
  const HeelAlertOverlay({
    super.key,
    required this.alert,
    required this.child,
  });

  final HeelAlert alert;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: HeelBanner(alert: alert),
          ),
        ),
      ],
    );
  }
}
