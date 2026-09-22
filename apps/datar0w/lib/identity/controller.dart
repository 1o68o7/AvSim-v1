import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../import/apply.dart';
import '../import/cloud_sync.dart';
import '../import/mapping.dart';
import '../import/rower_csv.dart';
import '../session/boat_class.dart';
import '../sync/auth_google.dart';
import '../sync/club_remote.dart';
import '../sync/club_sql.dart';
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
  ClubRemote get _remote => ref.read(clubRemoteProvider);

  String? get _sessionUserId {
    final fromAuth = ref.read(authGoogleProvider).sessionUserId;
    if (fromAuth != null && fromAuth.isNotEmpty) return fromAuth;
    final id = supabaseOrNull()?.auth.currentUser?.id;
    return id is String ? id : null;
  }

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
    await _flushImportQuiet();
    await _refresh();
  }

  Future<void> selectClub(String id) async {
    final prefs = await _store.loadState();
    await _store.saveState(prefs.copyWith(activeClubId: id));
    await _refresh();
  }

  Future<void> saveBoat(ParkBoat boat) async {
    await _store.upsertBoat(boat);
    await _remote.upsertBoat(boatToSql(boat));
    await _refresh();
  }

  Future<void> deleteBoat(String id) async {
    await _store.deleteBoat(id);
    await _refresh();
  }

  Future<void> saveCrew(String boatId, List<Assignment> crew) async {
    await _store.replaceAssignmentsForBoat(boatId, crew);
    final clubId =
        state.boatById(boatId)?.clubId ?? state.prefs.activeClubId;
    if (clubId != null) {
      for (final a in crew) {
        await _remote.upsertAssignment(assignmentToSql(a, clubId));
      }
    }
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
    final uid = _sessionUserId;
    if (uid != null) {
      rower = rower.copyWith(userId: uid);
    }
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
          rower = rower.copyWith(clubId: club.id);
          await saveRower(rower);
          await _remote.upsertRower(rowerToSql(rower));
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

  /// Applique `club_members` cloud sur le store local. No-op hors session.
  Future<void> hydrateFromCloud(String userId) async {
    final m = await _remote.membershipFor(userId);
    if (m == null) return;
    var known = false;
    for (final c in state.clubs) {
      if (c.id == m.clubId) known = true;
    }
    if (!known) {
      final rc = await _remote.clubById(m.clubId);
      if (rc != null) {
        await _store.upsertClub(
          Club(
            id: rc.id,
            name: rc.name,
            shortCode: rc.shortCode,
            createdAt: DateTime.now().toUtc(),
          ),
        );
      }
    }
    final prefs = await _store.loadState();
    await _store.saveState(
      prefs.copyWith(
        activeClubId: m.clubId,
        clubRole: ClubMemberRoleX.parse(m.role),
        activeRowerId: m.rowerId ?? prefs.activeRowerId,
      ),
    );
    await _mergeRemotePark(m.clubId);
    await _refresh();
  }

  Future<void> _mergeRemotePark(String clubId) async {
    final park = await _remote.parkForClub(clubId);
    final haveBoat = {for (final b in state.boats) b.id};
    for (final b in park.boats) {
      if (!haveBoat.contains(b.id)) await _store.upsertBoat(b);
    }
    final haveRower = {for (final r in state.rowers) r.id};
    for (final r in park.rowers) {
      if (!haveRower.contains(r.id)) await _store.upsertRower(r);
    }
    final byBoat = <String, List<Assignment>>{};
    for (final a in park.assignments) {
      byBoat.putIfAbsent(a.boatId, () => []).add(a);
    }
    for (final e in byBoat.entries) {
      if (state.assignmentsForBoat(e.key).isEmpty) {
        await _store.replaceAssignmentsForBoat(e.key, e.value);
      }
    }
  }

  Future<void> _flushImportQuiet() async {
    final sync = ClubImportSync(identity: _store);
    await sync.snapshotOutbox();
    try {
      await sync.flush();
    } catch (_) {}
  }

  Future<void> createClubAsAdmin({
    required String name,
    String? shortCode,
  }) async {
    final club = Club.create(name: name.trim(), shortCode: shortCode?.trim());
    await saveClub(club);
    await setClubRole(ClubMemberRole.admin);
    await _remote.insertClub(
      id: club.id,
      name: club.name,
      shortCode: club.shortCode,
    );
  }

  Future<ClubJoinRequest?> requestClubRole({
    required String code,
    required ClubMemberRole role,
    String? userId,
  }) async {
    userId ??= _sessionUserId ?? 'local';
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
    await _remote.approveJoin(req.id, accept: accept);
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
    for (final b in r.boats) {
      await _remote.upsertBoat(boatToSql(b));
    }
    await _flushImportQuiet();
    await _refresh();
    return r;
  }

  Future<RowerImportApplyResult> confirmImportRowers(
    List<ParsedRowerRow> rows,
  ) async {
    final r = applyRowerImport(
      existing: state.rowers,
      rows: rows,
      clubId: state.activeClub?.id,
    );
    await _store.replaceAllRowers(r.rowers);
    final prefs = await _store.loadState();
    await _store.saveState(prefs.copyWith(lastRowerImportId: r.importId));
    await _refresh();
    return r;
  }

  Future<void> undoLastRowerImport() async {
    final id = state.prefs.lastRowerImportId;
    if (id == null) return;
    await _store.deleteRowersByImportId(id);
    final prefs = await _store.loadState();
    await _store.saveState(prefs.copyWith(clearRowerImport: true));
    await _refresh();
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
