import 'package:battery_plus/battery_plus.dart';

class BatteryService {
  final Battery _battery = Battery();

  Future<int?> levelPercent() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      return null;
    }
  }
}
