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
  /// Localisation when-in-use. Background = plus tard (après grant).
  /// IMU iOS : Info.plist seulement. Tare offset = lot C.
  static Future<PermissionOutcome> requestSession() async {
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
}
