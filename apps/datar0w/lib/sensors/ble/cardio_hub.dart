import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hr_parser.dart';

class CardioHub extends Notifier<HrReading?> {
  @override
  HrReading? build() => null;

  void ingest(List<int> payload) {
    try {
      state = parseHeartRateMeasurement(payload);
    } catch (_) {
      state = null;
    }
  }

  void clear() => state = null;
}

final cardioHubProvider =
    NotifierProvider<CardioHub, HrReading?>(CardioHub.new);
