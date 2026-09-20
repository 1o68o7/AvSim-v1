abstract class IdentityCloud {
  bool get enabled;

  Future<void> upsert(String table, Map<String, dynamic> row);
  Future<void> delete(String table, String id);
  Future<List<Map<String, dynamic>>> pull(String table, DateTime since);
}

class NoopCloud implements IdentityCloud {
  const NoopCloud();

  @override
  bool get enabled => false;

  @override
  Future<void> upsert(String table, Map<String, dynamic> row) async {}

  @override
  Future<void> delete(String table, String id) async {}

  @override
  Future<List<Map<String, dynamic>>> pull(String table, DateTime since) async =>
      [];
}

class MemoryCloud implements IdentityCloud {
  final Map<String, Map<String, Map<String, dynamic>>> tables = {
    'clubs': {},
    'rowers': {},
    'boats': {},
    'assignments': {},
  };

  @override
  bool get enabled => true;

  @override
  Future<void> upsert(String table, Map<String, dynamic> row) async {
    final id = row['id'] as String;
    tables.putIfAbsent(table, () => {});
    tables[table]![id] = Map<String, dynamic>.from(row);
  }

  @override
  Future<void> delete(String table, String id) async {
    tables[table]?.remove(id);
  }

  @override
  Future<List<Map<String, dynamic>>> pull(String table, DateTime since) async {
    final rows = tables[table]?.values ?? const Iterable.empty();
    return [
      for (final r in rows)
        if (_updated(r).isAfter(since)) Map<String, dynamic>.from(r),
    ];
  }

  DateTime _updated(Map<String, dynamic> r) {
    final raw = r['updated_at'] ?? r['updatedAt'];
    if (raw is String) return DateTime.parse(raw);
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
