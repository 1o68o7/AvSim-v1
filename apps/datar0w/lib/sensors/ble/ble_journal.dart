import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Niveau d'un événement du journal technique BLE (DR-63).
enum BleLogLevel { info, warn, error }

extension BleLogLevelX on BleLogLevel {
  String get label => switch (this) {
        BleLogLevel.info => 'INFO',
        BleLogLevel.warn => 'ALERTE',
        BleLogLevel.error => 'ERREUR',
      };
}

class BleJournalEntry {
  const BleJournalEntry({
    required this.at,
    required this.level,
    required this.tag,
    required this.message,
  });

  final DateTime at;
  final BleLogLevel level;
  final String tag;
  final String message;

  String format() {
    final t = at.toLocal();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return '[$hh:$mm:$ss] [${level.label}] [$tag] $message';
  }
}

class BleJournal extends Notifier<List<BleJournalEntry>> {
  static const int kMaxEntries = 200;

  @override
  List<BleJournalEntry> build() => const [];

  void log(BleLogLevel level, String tag, String message, {DateTime? at}) {
    final entry = BleJournalEntry(
      at: at ?? DateTime.now(),
      level: level,
      tag: tag,
      message: message,
    );
    final next = [...state, entry];
    state = next.length > kMaxEntries
        ? next.sublist(next.length - kMaxEntries)
        : next;
  }

  void info(String tag, String message) => log(BleLogLevel.info, tag, message);
  void warn(String tag, String message) => log(BleLogLevel.warn, tag, message);
  void error(String tag, String message) =>
      log(BleLogLevel.error, tag, message);

  void clear() => state = const [];
}

final bleJournalProvider =
    NotifierProvider<BleJournal, List<BleJournalEntry>>(BleJournal.new);
