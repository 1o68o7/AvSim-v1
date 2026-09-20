import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class OutboxOp {
  const OutboxOp({
    required this.table,
    required this.op,
    required this.id,
    this.payload = const {},
    required this.queuedAt,
  });

  final String table;
  final String op;
  final String id;
  final Map<String, dynamic> payload;
  final DateTime queuedAt;

  Map<String, dynamic> toJson() => {
        'table': table,
        'op': op,
        'id': id,
        'payload': payload,
        'queuedAt': queuedAt.toUtc().toIso8601String(),
      };

  static OutboxOp fromJson(Map<String, dynamic> j) => OutboxOp(
        table: j['table'] as String,
        op: j['op'] as String? ?? 'upsert',
        id: j['id'] as String,
        payload: Map<String, dynamic>.from(j['payload'] as Map? ?? {}),
        queuedAt: DateTime.parse(j['queuedAt'] as String),
      );
}

/// File locale `outbox.json` (même racine que l’identité).
class SyncOutbox {
  SyncOutbox({required this.root});

  final Directory root;

  File get _file => File(p.join(root.path, 'outbox.json'));

  Future<List<OutboxOp>> peek() async {
    if (!_file.existsSync()) return [];
    final raw = jsonDecode(await _file.readAsString());
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => OutboxOp.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> enqueue(OutboxOp op) async {
    final list = await peek();
    list.add(op);
    await _write(list);
  }

  Future<void> replace(List<OutboxOp> next) => _write(next);

  Future<void> _write(List<OutboxOp> rows) async {
    await root.create(recursive: true);
    await _file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(rows.map((e) => e.toJson()).toList()),
    );
  }
}
