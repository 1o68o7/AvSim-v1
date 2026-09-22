import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../import/apply.dart';
import '../import/cloud_sync.dart';
import '../import/mapping.dart';
import '../session/boat_class.dart';
import '../sync/supabase_boot.dart';
import 'models.dart';
import 'store.dart';

final identityStoreProvider = Provider<IdentityStore>((ref) => IdentityStore());

class IdentitySnapshot {
  const IdentitySnapshot({
    this.rowers = const [],
    this.clubs = const [],
    this.boats = const [],
    this.assignments = const [],
    this.trophies = const [],
    this.joinRequests = const [],
    this.prefs = const IdentityPrefs(),
  });

  final List<Rower> rowers;
  final List<Club> clubs;
  final List<ParkBoat> boats;
  final List<Assignment> assignments;
  final List<Trophy> trophies;
  final List<ClubJoinRequest> joinRequests;
  final IdentityPrefs prefs;

  Rower? get activeRower {
    final id = prefs.activeRowerId;
    if (id == null) return null;
    for (final r in rowers) {
      if (r.id == id) return r;
    }
    return null;
  }

  Club? get activeClub {
    final id = prefs.activeClubId;
    if (id == null) {
      return clubs.isEmpty ? null : clubs.first;
    }
    for (final c in clubs) {
      if (c.id == id) return c;
    }
    return clubs.isEmpty ? null : clubs.first;
  }

  List<ParkBoat> boatsForClub(String? clubId) {
    if (clubId == null) return boats;
    return boats.where((b) => b.clubId == clubId).toList();
  }

  List<ParkBoat> get readyBoats => boats
      .where((b) => b.status == BoatParkStatus.ready)
      .toList();

  List<Assignment> assignmentsForBoat(String boatId) =>
      assignments.where((a) => a.boatId == boatId).toList();

  Assignment? assignmentForRower(String rowerId) {
    for (final a in assignments.reversed) {
      if (a.rowerId == rowerId && a.role != 'cox') return a;
    }
    return null;
  }

  Assignment? coxAssignmentFor(String rowerId) {
    for (final a in assignments.reversed) {
      if (a.rowerId == rowerId && a.role == 'cox') return a;
    }
    return null;
  }

  ParkBoat? boatById(String? id) {
    if (id == null) return null;
    for (final b in boats) {
      if (b.id == id) return b;
    }
    return null;
  }

  Rower? rowerById(String? id) {
    if (id == null) return null;
    for (final r in rowers) {
      if (r.id == id) return r;
    }
    return null;
  }

  List<ParkBoat> readyBoatsForClub(String? clubId) => boats
      .where((b) =>
          b.status == BoatParkStatus.ready &&
          (clubId == null || b.clubId == clubId))
      .toList();

  bool rowerAssignedTodayElsewhere(
    String rowerId, {
    String? exceptBoatId,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    for (final a in assignments) {
      if (a.rowerId != rowerId) continue;
      if (exceptBoatId != null && a.boatId == exceptBoatId) continue;
      if (sameLocalDay(a.createdAt, n)) return true;
    }
    return false;
  }
}

/// Notifier : racine test = lecture sync ; sinon premier frame vide + reload.
class IdentityController extends Notifier<IdentitySnapshot> {
  IdentityStore get _store => ref.read(identityStoreProvider);

  @override
  IdentitySnapshot build() {
    final seeded = _trySyncSnapshot();
    if (seeded != null) return seeded;
    Future<void>.microtask(_refresh);
    return const IdentitySnapshot();
  }

  IdentitySnapshot? _trySyncSnapshot() {
    final store = _store;
    final rowers = store.tryListRowersSync();
    if (rowers == null) return null;
    return IdentitySnapshot(
      rowers: rowers,
      clubs: store.tryListClubsSync() ?? const [],
      boats: store.tryListBoatsSync() ?? const [],
      assignments: store.tryListAssignmentsSync() ?? const [],
      trophies: store.tryListTrophiesSync() ?? const [],
      joinRequests: store.tryListJoinRequestsSync() ?? const [],
      prefs: store.tryLoadPrefsSync() ?? const IdentityPrefs(),
    );
  }

  Future<IdentitySnapshot> _reload() async {
    return IdentitySnapshot(
      rowers: await _store.listRowers(),
      clubs: await _store.listClubs(),
      boats: await _store.listBoats(),
      assignments: await _store.listAssignments(),
      trophies: await _store.listTrophies(),
      joinRequests: await _store.listJoinRequests(),
      prefs: await _store.loadState(),
    );
  }

  Future<void> _refresh() async {
    state = await _reload();
  }

  Future<void> saveRower(Rower rower) async {
    await _store.upsertRower(rower);
    final prefs = await _store.loadState();
    await _store.saveState(prefs.copyWith(activeRowerId: rower.id));
    await _refresh();
  }

  Future<void> selectRower(String? id) async {
    final prefs = await _store.loadState();
    await _store.saveState(
      id == null
          ? prefs.copyWith(clearRower: true)
          : prefs.copyWith(activeRowerId: id),
    );
    await _refresh();
  }

  Future<void> deleteRower(String id) async {
    await _store.deleteRower(id);
    await _refresh();
  }

  Future<void> saveClub(Club club) async {
    await _store.upsertClub(club);
    final prefs = await _store.loadState();
    await _store.saveState(prefs.copyWith(activeClubId: club.id));
    await ClubImportSync(identity: _store).snapshotOutbox();
    await _refresh();
  }

  Future<void> selectClub(String id) async {
    final prefs = await _store.loadState();
    await _store.saveState(prefs.copyWith(activeClubId: id));
    await _refresh();
  }

  Future<void> saveBoat(ParkBoat boat) async {
    await _store.upsertBoat(boat);
    await _refresh();
  }

  Future<void> deleteBoat(String id) async {
    await _store.deleteBoat(id);
    await _refresh();
  }

  Future<void> saveCrew(String boatId, List<Assignment> crew) async {
    await _store.replaceAssignmentsForBoat(boatId, crew);
    await _refresh();
  }

  Future<void> setClubRole(ClubMemberRole role) async {
    final prefs = await _store.loadState();
    await _store.saveState(prefs.copyWith(clubRole: role));
    await _refresh();
  }

  Future<void> becomeCox() async {
    await setClubRole(ClubMemberRole.cox);
  }

  /// Code club local ou RPC `join_club`. Vide = rameur solo.
  Future<bool> joinClubByCode(String? code) async {
    final raw = (code ?? '').trim();
    if (raw.isEmpty) return true;
    final client = supabaseOrNull();
    if (client != null) {
      try {
        await client.rpc('join_club', params: {'p_code': raw});
      } catch (_) {}
    }
    final needle = raw.toUpperCase();
    for (final c in state.clubs) {
      if ((c.shortCode ?? '').toUpperCase() == needle) {
        await selectClub(c.id);
        return true;
      }
    }
    return false;
  }

  Future<Rower> completeRowerOnboarding({
    required String displayName,
    required DateTime birthDate,
    RowerSex sex = RowerSex.m,
    String? ffaLicence,
    String? clubCode,
    bool coxToo = false,
  }) async {
    var rower = Rower.create(
      displayName: displayName.trim(),
      birthDate: birthDate,
      sex: sex,
    );
    final lic = ffaLicence?.trim();
    if (lic != null && lic.isNotEmpty) {
      rower = rower.copyWith(ffaLicence: lic);
    }
    await saveRower(rower);
    if (clubCode != null && clubCode.trim().isNotEmpty) {
      final ok = await joinClubByCode(clubCode);
      if (ok) {
        final club = state.activeClub;
        if (club != null) {
          await saveRower(rower.copyWith(clubId: club.id));
        }
      }
    }
    if (coxToo) {
      await becomeCox();
    } else {
      await setClubRole(ClubMemberRole.rower);
    }
    return rower;
  }

  Future<void> createClubAsAdmin({
    required String name,
    String? shortCode,
  }) async {
    final club = Club.create(name: name.trim(), shortCode: shortCode?.trim());
    await saveClub(club);
    await setClubRole(ClubMemberRole.admin);
  }

  Future<ClubJoinRequest?> requestClubRole({
    required String code,
    required ClubMemberRole role,
    String userId = 'local',
  }) async {
    final needle = code.trim().toUpperCase();
    Club? club;
    for (final c in state.clubs) {
      if ((c.shortCode ?? '').toUpperCase() == needle) club = c;
    }
    if (club == null) return null;
    final client = supabaseOrNull();
    if (client != null) {
      try {
        await client.rpc(
          'request_club_role',
          params: {'p_code': code.trim(), 'p_role': role.wire},
        );
      } catch (_) {}
    }
    final req = ClubJoinRequest.create(
      clubId: club.id,
      userId: userId,
      requestedRole: role,
    );
    await _store.upsertJoinRequest(req);
    await _refresh();
    return req;
  }

  Future<void> decideJoinRequest(ClubJoinRequest req, {required bool accept}) async {
    final actor = state.prefs.clubRole;
    if (actor != ClubMemberRole.admin && actor != ClubMemberRole.director) {
      return;
    }
    final next = req.copyWith(status: accept ? 'approved' : 'rejected');
    await _store.upsertJoinRequest(next);
    await _refresh();
  }

  Future<ImportApplyResult?> confirmImport(List<ParsedBoatRow> rows) async {
    final club = state.activeClub;
    if (club == null) return null;
    final r = applyParkImport(
      clubId: club.id,
      existing: state.boats,
      rows: rows,
    );
    await _store.replaceAllBoats(r.boats);
    final prefs = await _store.loadState();
    await _store.saveState(prefs.copyWith(lastImportId: r.importId));
    await ClubImportSync(identity: _store).snapshotOutbox();
    await _refresh();
    return r;
  }

  Future<void> undoLastImport() async {
    final id = state.prefs.lastImportId;
    if (id == null) return;
    await _store.deleteBoatsByImportId(id);
    final prefs = await _store.loadState();
    await _store.saveState(prefs.copyWith(clearImport: true));
    await _refresh();
  }

  Future<void> saveTrophy(Trophy t) async {
    await _store.upsertTrophy(t);
    await _refresh();
  }

  Future<void> deleteTrophy(String id) async {
    await _store.deleteTrophy(id);
    await _refresh();
  }

  Future<void> reloadFromStore() async {
    await _refresh();
  }
}

final identityProvider =
    NotifierProvider<IdentityController, IdentitySnapshot>(
  IdentityController.new,
);

bool canEditPark(IdentitySnapshot snap, CrewRole session) =>
    session == CrewRole.coach && snap.prefs.clubRole == ClubMemberRole.admin;

bool canCheckoutOps(IdentitySnapshot snap, CrewRole session) =>
    session == CrewRole.coach &&
    (snap.prefs.clubRole == ClubMemberRole.coach ||
        snap.prefs.clubRole == ClubMemberRole.admin ||
        snap.prefs.clubRole == ClubMemberRole.intendant);

bool boatAllowsRower(ParkBoat boat, Rower rower) {
  if (rower.level == RowerLevel.loisir) return boat.loisirOk;
  return true;
}
