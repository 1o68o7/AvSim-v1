import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';

/// Hubs où le swipe horizontal ne doit pas voler les gestes métier.
bool navSwipeBlocked(String path) {
  return path == AppRoutes.live ||
      path == AppRoutes.cox ||
      path == AppRoutes.coachLive ||
      path == AppRoutes.tare;
}

/// Historique hubs pour swipe arrière / avant (complète `canPop`).
class HubNavHistory {
  final _past = <String>[];
  final _future = <String>[];
  String? current;
  bool _mutating = false;

  void onLocation(String path) {
    if (path.isEmpty || navSwipeBlocked(path)) return;
    if (_mutating) {
      current = path;
      return;
    }
    if (current == path) return;
    if (current != null) {
      if (_future.isNotEmpty && _future.last == path) {
        _future.removeLast();
      } else {
        _past.add(current!);
        _future.clear();
      }
    }
    current = path;
  }

  String? peekBack() {
    if (_past.isEmpty) return null;
    return _past.last;
  }

  String? peekForward() {
    if (_future.isEmpty) return null;
    return _future.last;
  }

  String? takeBack() {
    if (_past.isEmpty || current == null) return null;
    _mutating = true;
    _future.add(current!);
    final dest = _past.removeLast();
    current = dest;
    _mutating = false;
    return dest;
  }

  String? takeForward() {
    if (_future.isEmpty || current == null) return null;
    _mutating = true;
    _past.add(current!);
    final dest = _future.removeLast();
    current = dest;
    _mutating = false;
    return dest;
  }

  @visibleForTesting
  void debugReset() {
    _past.clear();
    _future.clear();
    current = null;
    _mutating = false;
  }
}

final hubNavHistory = HubNavHistory();

String _routerPath(GoRouter router) {
  final cfg = router.routerDelegate.currentConfiguration;
  if (cfg.isEmpty) return '';
  return cfg.uri.path;
}

/// Swipe droite → arrière · swipe gauche → avant (si historique).
/// Désactivé sur live / cox / coach / tare.
class NavSwipeHost extends StatefulWidget {
  const NavSwipeHost({
    super.key,
    required this.child,
    this.router,
    this.history,
  });

  final Widget child;
  final GoRouter? router;
  final HubNavHistory? history;

  @override
  State<NavSwipeHost> createState() => _NavSwipeHostState();
}

class _NavSwipeHostState extends State<NavSwipeHost> {
  static const _minDx = 72.0;
  static const _minVx = 280.0;

  GoRouter? _router;
  HubNavHistory get _hist => widget.history ?? hubNavHistory;
  double _dx = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = widget.router ?? GoRouter.maybeOf(context);
    if (r == null || identical(r, _router)) return;
    _router?.routerDelegate.removeListener(_onRoute);
    _router = r;
    _router!.routerDelegate.addListener(_onRoute);
    _onRoute();
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  void _onRoute() {
    final r = _router;
    if (r == null) return;
    _hist.onLocation(_routerPath(r));
  }

  void _goBack() {
    final r = _router;
    if (r == null) return;
    final path = _routerPath(r);
    if (navSwipeBlocked(path)) return;
    if (r.canPop()) {
      r.pop();
      return;
    }
    final dest = _hist.takeBack();
    if (dest != null) r.go(dest);
  }

  void _goForward() {
    final r = _router;
    if (r == null) return;
    final path = _routerPath(r);
    if (navSwipeBlocked(path)) return;
    final dest = _hist.takeForward();
    if (dest != null) r.go(dest);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _dx = 0,
      onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
      onHorizontalDragEnd: (d) {
        final vx = d.velocity.pixelsPerSecond.dx;
        final goBack = _dx > _minDx || vx > _minVx;
        final goFwd = _dx < -_minDx || vx < -_minVx;
        _dx = 0;
        if (goBack && !goFwd) {
          _goBack();
        } else if (goFwd && !goBack) {
          _goForward();
        }
      },
      child: widget.child,
    );
  }
}
