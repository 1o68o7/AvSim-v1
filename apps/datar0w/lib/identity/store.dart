import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// CRUD JSON sous `Documents/datar0w/`.
class IdentityStore {
  IdentityStore({Directory? root}) : _rootOverride = root;

  final Directory? _rootOverride;

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

  Future<void> upsertRower(Rower rower) async {
    final list = await listRowers();
    final i = list.indexWhere((e) => e.id == rower.id);
    if (i >= 0) {
      list[i] = rower;
    } else {
      list.add(rower);
    }
    await _writeList('rowers.json', list.map((e) => e.toJson()).toList());
  }

  Future<void> deleteRower(String id) async {
    final list = await listRowers();
    list.removeWhere((e) => e.id == id);
    await _writeList('rowers.json', list.map((e) => e.toJson()).toList());
    final st = await loadState();
    if (st.activeRowerId == id) {
      await saveState(st.copyWith(clearRower: true));
    }
  }

  Future<List<Club>> listClubs() async {
    final raw = await _readList('clubs.json');
    return raw.map(Club.fromJson).toList();
  }

  Future<void> upsertClub(Club club) async {
    final list = await listClubs();
    final i = list.indexWhere((e) => e.id == club.id);
    if (i >= 0) {
      list[i] = club;
    } else {
      list.add(club);
    }
    await _writeList('clubs.json', list.map((e) => e.toJson()).toList());
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
  }

  Future<List<ParkBoat>> listBoats() async {
    final raw = await _readList('boats.json');
    return raw.map(ParkBoat.fromJson).toList();
  }

  Future<void> upsertBoat(ParkBoat boat) async {
    final list = await listBoats();
    final i = list.indexWhere((e) => e.id == boat.id);
    if (i >= 0) {
      list[i] = boat;
    } else {
      list.add(boat);
    }
    await _writeList('boats.json', list.map((e) => e.toJson()).toList());
  }

  Future<void> replaceAllBoats(List<ParkBoat> boats) async {
    await _writeList('boats.json', boats.map((e) => e.toJson()).toList());
  }

  Future<void> deleteBoatsByImportId(String importId) async {
    final list = await listBoats();
    list.removeWhere((e) => e.importId == importId);
    await _writeList('boats.json', list.map((e) => e.toJson()).toList());
  }

  Future<void> deleteBoat(String id) async {
    final list = await listBoats();
    list.removeWhere((e) => e.id == id);
    await _writeList('boats.json', list.map((e) => e.toJson()).toList());
    final asg = await listAssignments();
    asg.removeWhere((a) => a.boatId == id);
    await _writeList('assignments.json', asg.map((e) => e.toJson()).toList());
  }

  Future<List<Trophy>> listTrophies() async {
    final raw = await _readList('trophies.json');
    return raw.map(Trophy.fromJson).toList();
  }

  Future<void> upsertTrophy(Trophy t) async {
    final list = await listTrophies();
    final i = list.indexWhere((e) => e.id == t.id);
    if (i >= 0) {
      list[i] = t;
    } else {
      list.add(t);
    }
    await _writeList('trophies.json', list.map((e) => e.toJson()).toList());
  }

  Future<void> deleteTrophy(String id) async {
    final list = await listTrophies();
    list.removeWhere((e) => e.id == id);
    await _writeList('trophies.json', list.map((e) => e.toJson()).toList());
  }

  Future<List<Assignment>> listAssignments() async {
    final raw = await _readList('assignments.json');
    return raw.map(Assignment.fromJson).toList();
  }

  Future<void> upsertAssignment(Assignment a) async {
    final list = await listAssignments();
    final i = list.indexWhere((e) => e.id == a.id);
    if (i >= 0) {
      list[i] = a;
    } else {
      list.add(a);
    }
    await _writeList('assignments.json', list.map((e) => e.toJson()).toList());
  }

  Future<void> replaceAssignmentsForBoat(
    String boatId,
    List<Assignment> next,
  ) async {
    final list = await listAssignments();
    list.removeWhere((a) => a.boatId == boatId);
    list.addAll(next);
    await _writeList('assignments.json', list.map((e) => e.toJson()).toList());
  }

  Future<void> deleteAssignment(String id) async {
    final list = await listAssignments();
    list.removeWhere((e) => e.id == id);
    await _writeList('assignments.json', list.map((e) => e.toJson()).toList());
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

  List<Trophy>? tryListTrophiesSync() {
    final raw = _tryReadListSync('trophies.json');
    return raw?.map(Trophy.fromJson).toList();
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
  const IdentityPrefs({
    this.activeRowerId,
    this.activeClubId,
    this.clubRole = ClubMemberRole.admin,
    this.lastImportId,
  });

  final String? activeRowerId;
  final String? activeClubId;
  /// Rôle club (Point B `club_members.role`). Défaut admin = téléphone qui tient le parc.
  final ClubMemberRole clubRole;
  final String? lastImportId;

  IdentityPrefs copyWith({
    String? activeRowerId,
    String? activeClubId,
    ClubMemberRole? clubRole,
    String? lastImportId,
    bool clearRower = false,
    bool clearClub = false,
    bool clearImport = false,
  }) {
    return IdentityPrefs(
      activeRowerId: clearRower ? null : (activeRowerId ?? this.activeRowerId),
      activeClubId: clearClub ? null : (activeClubId ?? this.activeClubId),
      clubRole: clubRole ?? this.clubRole,
      lastImportId: clearImport ? null : (lastImportId ?? this.lastImportId),
    );
  }

  Map<String, dynamic> toJson() => {
        'activeRowerId': activeRowerId,
        'activeClubId': activeClubId,
        'clubRole': clubRole.wire,
        'lastImportId': lastImportId,
      };

  static IdentityPrefs fromJson(Map<String, dynamic> j) => IdentityPrefs(
        activeRowerId: j['activeRowerId'] as String?,
        activeClubId: j['activeClubId'] as String?,
        clubRole: ClubMemberRoleX.parse(j['clubRole'] as String?),
        lastImportId: j['lastImportId'] as String?,
      );
}
