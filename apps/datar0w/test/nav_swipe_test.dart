import 'package:datar0w/router.dart';
import 'package:datar0w/widgets/nav_swipe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('navSwipeBlocked protège live/cox/coach/tare', () {
    expect(navSwipeBlocked(AppRoutes.live), isTrue);
    expect(navSwipeBlocked(AppRoutes.cox), isTrue);
    expect(navSwipeBlocked(AppRoutes.coachLive), isTrue);
    expect(navSwipeBlocked(AppRoutes.tare), isTrue);
    expect(navSwipeBlocked(AppRoutes.auth), isFalse);
    expect(navSwipeBlocked(AppRoutes.settings), isFalse);
  });

  test('HubNavHistory back puis forward', () {
    final h = HubNavHistory();
    h.onLocation(AppRoutes.identity);
    h.onLocation(AppRoutes.auth);
    h.onLocation(AppRoutes.settings);
    expect(h.peekBack(), AppRoutes.auth);
    expect(h.takeBack(), AppRoutes.auth);
    expect(h.current, AppRoutes.auth);
    expect(h.peekForward(), AppRoutes.settings);
    expect(h.takeForward(), AppRoutes.settings);
    expect(h.current, AppRoutes.settings);
  });

  test('HubNavHistory ignore live', () {
    final h = HubNavHistory();
    h.onLocation(AppRoutes.auth);
    h.onLocation(AppRoutes.live);
    expect(h.current, AppRoutes.auth);
    expect(h.peekBack(), isNull);
  });
}
