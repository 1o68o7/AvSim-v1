import 'package:permission_handler/permission_handler.dart';

class PermissionOutcome {
  const PermissionOutcome({
    required this.locationOk,
    required this.message,
  });

  final bool locationOk;
  final String? message;
}

class AppPermissions {
  /// When-in-use d’abord (Android 10+). Background = [requestBackgroundAfterWhenInUse].
  static Future<PermissionOutcome> requestSession() async {
    try {
      await Permission.sensors.request();
    } catch (_) {}
    final loc = await Permission.locationWhenInUse.request();
    if (loc.isGranted) {
      return const PermissionOutcome(locationOk: true, message: null);
    }
    if (loc.isPermanentlyDenied) {
      return const PermissionOutcome(
        locationOk: false,
        message:
            'Localisation refusée. Ouvrir Réglages pour autoriser le GPS séance.',
      );
    }
    if (loc.isDenied) {
      return const PermissionOutcome(
        locationOk: false,
        message:
            'Localisation refusée. V sol et trace indisponibles (pas de crash).',
      );
    }
    return PermissionOutcome(
      locationOk: false,
      message: 'Localisation : ${loc.name}. GPS éteint jusqu’à acceptation.',
    );
  }

  /// Après grant when-in-use : notifs + localisation arrière-plan (FGS).
  static Future<void> requestBackgroundAfterWhenInUse() async {
    try {
      await Permission.notification.request();
    } catch (_) {}
    final when = await Permission.locationWhenInUse.status;
    if (!when.isGranted) return;
    try {
      await Permission.locationAlways.request();
    } catch (_) {}
  }
}
