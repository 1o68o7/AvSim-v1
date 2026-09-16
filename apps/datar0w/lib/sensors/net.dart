import 'package:connectivity_plus/connectivity_plus.dart';

class NetService {
  Stream<String> stream() {
    return Connectivity().onConnectivityChanged.map(_label);
  }

  Future<String> current() async {
    final list = await Connectivity().checkConnectivity();
    return _label(list);
  }

  String _label(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none) || results.isEmpty) {
      return 'hors ligne';
    }
    if (results.contains(ConnectivityResult.wifi)) return 'wifi';
    if (results.contains(ConnectivityResult.mobile)) return '4g';
    if (results.contains(ConnectivityResult.ethernet)) return 'eth';
    return results.first.name;
  }
}
