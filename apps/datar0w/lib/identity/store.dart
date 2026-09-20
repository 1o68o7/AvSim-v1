import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../sync/cloud_map.dart';
import '../sync/outbox.dart';
import 'models.dart';

/// CRUD JSON sous `Documents/datar0w/`.
class IdentityStore {
  IdentityStore({Directory? root}) : _rootOverride = root;

  final Directory? _rootOverride;
  SyncOutbox? _outbox;

  Future<SyncOutbox> outbox() async {
    _outbox ??= SyncOutbox(root: await root());
    return _outbox!;
  }

  Future<void> _enqueue({
    required String table,
    required String op,
    required String id,
    Map<String, dynamic> payload = const {},
  }) async {
    final box = await outbox();
    await box.enqueue(
      OutboxOp(
        table: table,
        op: op,
        id: id,
        payload: payload,
        queuedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<Directory> root() async {
    if (_rootOverride != null) {
      await _rootOverride.create(recursive: true);
      return _rootOverride;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'datar0w'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<List<Rower>> listRowers() async {
    final raw = await _readList('rowers.json');
    return raw.map(Rower.fromJson).toList();
  }

  Future<void> upsertRower(Rower rower, {bool enqueue = true}) async {
    final row = enqueue
        ? rower.copyWith(updatedAt: DateTime.now().toUtc())
        : rower;
    final list = await listRowers();
    final i = list.indexWhere((e) => e.id == row.id);
    if (i >= 0) {
      list[i] = row;
    } else {
      list.add(row);
    }
    await _writeList('rowers.json', list.map((e) => e.toJson()).toList());
    if (enqueue && row.clubId != null) {
      await _enqueue(
        table: 'rowers',
        op: 'upsert',
        id: row.id,
        payload: rowerToCloud(row),
      );
    }
  }

  Future<void> deleteRower(String id) async {
    final list = await listRowers();
    list.removeWhere((e) => e.id == id);
    await _writeList('rowers.json', list.map((e) => e.toJson()).toList());
    final st = await loadState();
    if (st.activeRowerId == id) {
      await saveState(st.copyWith(clearRower: true));
    }
    await _enqueue(table: 'rowers', op: 'delete', id: id);
  }

  Future<List<Club>> listClubs() async {
    final raw = await _readList('clubs.json');
    return raw.map(Club.fromJson).toList();
  }

  Future<void> upsertClub(Club club, {bool enqueue = true}) async {
    final row = enqueue
        ? club.copyWith(updatedAt: DateTime.now().toUtc())
        : club;
    final list = await listClubs();
    final i = list.indexWhere((e) => e.id == row.id);
    if (i >= 0) {
      list[i] = row;
    } else {
      list.add(row);
    }
    await _writeList('clubs.json', list.map((e) => e.toJson()).toList());
    if (enqueue) {
      await _enqueue(
        table: 'clubs',
        op: 'upsert',
        id: row.id,
        payload: clubToCloud(row),
      );
    }
  }

  Future<void> deleteClub(String id) async {
    final list = await listClubs();
    list.removeWhere((e) => e.id == id);
    await _writeList('clubs.json', list.map((e) => e.toJson()).toList());
    final boats = await listBoats();
    boats.removeWhere((b) => b.clubId == id);
    await _writeList('boats.json', boats.map((e) => e.toJson()).toList());
    final st = await loadState();
    if (st.activeClubId == id) {
      await saveState(st.copyWith(clearClub: true));
    }
    await _enqueue(table: 'clubs', op: 'delete', id: id);
  }

  Future<List<ParkBoat>> listBoats() async {
    final raw = await _readList('boats.json');
    return raw.map(ParkBoat.fromJson).toList();
  }

  Future<void> upsertBoat(ParkBoat boat, {bool enqueue = true}) async {
    final row = enqueue
        ? boat.copyWith(updatedAt: DateTime.now().toUtc())
        : boat;
    final list = await listBoats();
    final i = list.indexWhere((e) => e.id == row.id);
    if (i >= 0) {
      list[i] = row;
    } else {
      list.add(row);
    }
    await _writeList('boats.json', list.map((e) => e.toJson()).toList());
    if (enqueue) {
      await _enqueue(
        table: 'boats',
        op: 'upsert',
        id: row.id,
        payload: boatToCloud(row),
      );
    }
  }

  Future<void> deleteBoat(String id) async {
    final list = await listBoats();
    list.removeWhere((e) => e.id == id);
    await _writeList('boats.json', list.map((e) => e.toJson()).toList());
    final asg = await listAssignments();
    asg.removeWhere((a) => a.boatId == id);
    await _writeList('assignments.json', asg.map((e) => e.toJson()).toList());
    await _enqueue(table: 'boats', op: 'delete', id: id);
  }

  Future<List<Assignment>> listAssignments() async {
    final raw = await _readList('assignments.json');
    return raw.map(Assignment.fromJson).toList();
  }

  Future<void> upsertAssignment(Assignment a, {bool enqueue = true}) async {
    final row = enqueue
        ? Assignment(
            id: a.id,
            boatId: a.boatId,
            seatIndex: a.seatIndex,
            rowerId: a.rowerId,
            side: a.side,
            oars: a.oars,
            role: a.role,
            coxPosition: a.coxPosition,
            createdAt: a.createdAt,
            updatedAt: DateTime.now().toUtc(),
          )
        : a;
    final list = await listAssignments();
    final i = list.indexWhere((e) => e.id == row.id);
    if (i >= 0) {
      list[i] = row;
    } else {
      list.add(row);
    }
    await _writeList('assignments.json', list.map((e) => e.toJson()).toList());
    if (enqueue) {
      final boats = await listBoats();
      String? clubId;
      for (final b in boats) {
        if (b.id == row.boatId) clubId = b.clubId;
      }
      if (clubId != null) {
        await _enqueue(
          table: 'assignments',
          op: 'upsert',
          id: row.id,
          payload: assignmentToCloud(row, clubId: clubId),
        );
      }
    }
  }

  Future<void> replaceAssignmentsForBoat(
    String boatId,
    List<Assignment> next,
  ) async {
    final list = await listAssignments();
    final removed = list.where((a) => a.boatId == boatId).toList();
    list.removeWhere((a) => a.boatId == boatId);
    await _writeList('assignments.json', list.map((e) => e.toJson()).toList());
    for (final a in removed) {
      await _enqueue(table: 'assignments', op: 'delete', id: a.id);
    }
    for (final a in next) {
      await upsertAssignment(a);
    }
  }

  Future<void> deleteAssignment(String id) async {
    final list = await listAssignments();
    list.removeWhere((e) => e.id == id);
    await _writeList('assignments.json', list.map((e) => e.toJson()).toList());
    await _enqueue(table: 'assignments', op: 'delete', id: id);
  }

  Future<IdentityPrefs> loadState() async {
    final dir = await root();
    final f = File(p.join(dir.path, 'state.json'));
    if (!f.existsSync()) return const IdentityPrefs();
    final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    return IdentityPrefs.fromJson(j);
  }

  Future<void> saveState(IdentityPrefs prefs) async {
    final dir = await root();
    await File(p.join(dir.path, 'state.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(prefs.toJson()),
    );
  }

  Future<List<Map<String, dynamic>>> _readList(String name) async {
    final dir = await root();
    final f = File(p.join(dir.path, name));
    if (!f.existsSync()) return [];
    final raw = jsonDecode(await f.readAsString());
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _writeList(String name, List<Map<String, dynamic>> rows) async {
    final dir = await root();
    await File(p.join(dir.path, name)).writeAsString(
      const JsonEncoder.withIndent('  ').convert(rows),
    );
  }

  /// Lecture synchrone si le store a un répertoire imposé (tests).
  IdentityPrefs? tryLoadPrefsSync() {
    final dir = _rootOverride;
    if (dir == null) return null;
    dir.createSync(recursive: true);
    final f = File(p.join(dir.path, 'state.json'));
    if (!f.existsSync()) return const IdentityPrefs();
    final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    return IdentityPrefs.fromJson(j);
  }

  List<Rower>? tryListRowersSync() {
    final raw = _tryReadListSync('rowers.json');
    return raw?.map(Rower.fromJson).toList();
  }

  List<Club>? tryListClubsSync() {
    final raw = _tryReadListSync('clubs.json');
    return raw?.map(Club.fromJson).toList();
  }

  List<ParkBoat>? tryListBoatsSync() {
    final raw = _tryReadListSync('boats.json');
    return raw?.map(ParkBoat.fromJson).toList();
  }

  List<Assignment>? tryListAssignmentsSync() {
    final raw = _tryReadListSync('assignments.json');
    return raw?.map(Assignment.fromJson).toList();
  }

  List<Map<String, dynamic>>? _tryReadListSync(String name) {
    final dir = _rootOverride;
    if (dir == null) return null;
    dir.createSync(recursive: true);
    final f = File(p.join(dir.path, name));
    if (!f.existsSync()) return [];
    final raw = jsonDecode(f.readAsStringSync());
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

class IdentityPrefs {
  const IdentityPrefs({this.activeRowerId, this.activeClubId});

  final String? activeRowerId;
  final String? activeClubId;

  IdentityPrefs copyWith({
    String? activeRowerId,
    String? activeClubId,
    bool clearRower = false,
    bool clearClub = false,
  }) {
    return IdentityPrefs(
      activeRowerId: clearRower ? null : (activeRowerId ?? this.activeRowerId),
      activeClubId: clearClub ? null : (activeClubId ?? this.activeClubId),
    );
  }

  Map<String, dynamic> toJson() => {
        'activeRowerId': activeRowerId,
        'activeClubId': activeClubId,
      };

  static IdentityPrefs fromJson(Map<String, dynamic> j) => IdentityPrefs(
        activeRowerId: j['activeRowerId'] as String?,
        activeClubId: j['activeClubId'] as String?,
      );
}
