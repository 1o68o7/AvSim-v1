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
import '../sync/sync_identity.dart' show ensureActiveClubForSync;
import 'id.dart';
import 'license.dart';
import 'license_store.dart';
import 'models.dart';
import 'store.dart';

final identityStoreProvider = Provider<IdentityStore>((ref) => IdentityStore());

final licenseStoreProvider = Provider<LicenseStore>((ref) => LicenseStore());

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
  LicenseStore get _licenses => ref.read(licenseStoreProvider);

  String? get _sessionUserId {
    final fromAuth = ref.read(authGoogleProvider).sessionUserId;
    if (fromAuth != null && fromAuth.isNotEmpty) return fromAuth;
    return supabaseOrNull()?.auth.currentUser?.id;
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
    notifyActiveClubId(state.prefs.activeClubId);
  }

  /// Login / boot sync : si prefs.activeClubId null + membership cloud → pose.
  Future<String?> ensureActiveClubFromMembership() async {
    return ensureActiveClubForSync(
      store: _store,
      remote: _remote,
      resolveOwnerUserId: () => _sessionUserId,
    );
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
  /// Si prefs.activeClubId déjà posé : conserve, met à jour rôle / parc.
  /// Sinon : 1 membership → ce club ; plusieurs → premier (limit remote).
  Future<void> hydrateFromCloud(String userId) async {
    final m = await _remote.membershipFor(userId);
    if (m == null) {
      // Prefs peuvent déjà avoir un club local — publier pour sync.
      final prefs = await _store.loadState();
      notifyActiveClubId(prefs.activeClubId);
      return;
    }
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
            ffaCode: rc.ffaCode,
            createdAt: DateTime.now().toUtc(),
          ),
        );
      }
    }
    final prefs = await _store.loadState();
    // Ne pas inventer un 2e club : membership existant uniquement.
    final clubId = (prefs.activeClubId != null &&
            prefs.activeClubId!.isNotEmpty)
        ? prefs.activeClubId!
        : m.clubId;
    await _store.saveState(
      prefs.copyWith(
        activeClubId: clubId,
        clubRole: clubId == m.clubId
            ? ClubMemberRoleX.parse(m.role)
            : prefs.clubRole,
        activeRowerId: m.rowerId ?? prefs.activeRowerId,
      ),
    );
    await _mergeRemotePark(clubId);
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
    for (final rower in r.rowers) {
      if (rower.clubId == null) continue;
      await _remote.upsertRower(rowerToSql(rower));
    }
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

  /// Rattache `auth.users.id` → `rowers.user_id` + cloud. Pas de second profil.
  Future<void> linkRowerUserIdCloud({
    required String rowerId,
    required String userId,
  }) async {
    final rower = state.rowerById(rowerId);
    if (rower == null) return;
    final linked = rower.copyWith(
      userId: userId,
      updatedAt: DateTime.now().toUtc(),
    );
    await _store.upsertRower(linked);
    await _remote.upsertRower(rowerToSql(linked));
    await _refresh();
  }

  Future<FfaLicense?> licenseForActiveRower() async {
    final r = state.activeRower;
    if (r == null) return null;
    return _licenses.byRowerId(r.id);
  }

  /// Écriture après confirmation PDF. PDF déjà jeté (bytes hors scope).
  /// [createClubIfConfirmed] : si le ffa_code n’existe pas et l’utilisateur confirme.
  Future<({Rower rower, FfaLicense license, Club? club})> applyLicenseDraft(
    LicenseDraft draft, {
    bool createClubIfMissing = false,
  }) async {
    // Même numéro = update saison, pas un second rower.
    Rower? rower;
    final existingLic = draft.licenseNumber == null
        ? null
        : await _licenses.byLicenseNumber(draft.licenseNumber!);
    if (existingLic != null) {
      rower = state.rowerById(existingLic.rowerId);
    }
    rower ??= state.activeRower;

    final display = draft.displayName.trim().isNotEmpty
        ? draft.displayName.trim()
        : (rower?.displayName ?? 'Rameur');
    final birth = draft.birthDate ??
        rower?.birthDate ??
        DateTime(DateTime.now().year - 30);
    final sex = switch ((draft.sex ?? '').toUpperCase()) {
      'F' => RowerSex.f,
      'X' => RowerSex.x,
      _ => rower?.sex ?? RowerSex.m,
    };

    Club? club;
    final code = draft.ffaCode?.trim().toUpperCase();
    if (code != null && code.isNotEmpty) {
      for (final c in state.clubs) {
        if ((c.ffaCode ?? '').toUpperCase() == code) {
          club = c;
          break;
        }
      }
      if (club == null) {
        final remote = await _remote.clubByFfaCode(code);
        if (remote != null) {
          club = Club(
            id: remote.id,
            name: remote.name,
            shortCode: remote.shortCode,
            ffaCode: remote.ffaCode ?? code,
            createdAt: DateTime.now().toUtc(),
          );
          await _store.upsertClub(club);
        } else if (createClubIfMissing &&
            draft.clubName != null &&
            draft.clubName!.trim().isNotEmpty) {
          // Confirmation explicite uniquement — jamais silencieux.
          club = Club.create(
            name: draft.clubName!.trim(),
            ffaCode: code,
          );
          await saveClub(club);
          await _remote.insertClub(
            id: club.id,
            name: club.name,
            ffaCode: code,
          );
        }
      }
    }

    final uid = _sessionUserId;
    if (rower == null) {
      rower = Rower.create(
        displayName: display,
        birthDate: birth,
        sex: sex,
      );
    }
    rower = rower.copyWith(
      displayName: display,
      birthDate: birth,
      sex: sex,
      clubId: club?.id ?? rower.clubId,
      userId: uid ?? rower.userId,
      ffaLicence: draft.licenseNumber ?? rower.ffaLicence,
      level: draft.isAlLike ? RowerLevel.loisir : rower.level,
      updatedAt: DateTime.now().toUtc(),
    );
    // Poids seulement si la carte le porte (draft n’a pas weight — skip).
    await saveRower(rower);
    if (club != null) {
      await selectClub(club.id);
    }
    await _remote.upsertRower(rowerToSql(rower));

    final lic = FfaLicense(
      id: existingLic?.id ?? newIdentityId(),
      rowerId: rower.id,
      licenseNumber: draft.licenseNumber,
      licenseType: draft.licenseType,
      validUntil: draft.validUntil,
      ffaCode: code,
      category: draft.category,
      surclassement: draft.surclassement,
      handiClassification: draft.handiClassification,
      source: draft.source,
      myffaVerified: false,
    );
    await _licenses.upsert(lic);
    await _remote.upsertLicense(lic.toSql());
    await _refresh();
    return (rower: rower, license: lic, club: club);
  }
}

extension on LicenseDraft {
  bool get isAlLike {
    final t = (licenseType ?? '').toUpperCase();
    return t.contains('AL') || t.contains('LOISIR');
  }
}

final identityProvider =
    NotifierProvider<IdentityController, IdentitySnapshot>(
  IdentityController.new,
);

/// Édition parc : admin club — [session] ignoré (compat call sites).
bool canEditPark(IdentitySnapshot snap, CrewRole session) =>
    snap.prefs.clubRole == ClubMemberRole.admin;

/// Composition équipage : coach / admin / intendant club.
bool canComposeCrew(IdentitySnapshot snap) =>
    snap.prefs.clubRole == ClubMemberRole.coach ||
    snap.prefs.clubRole == ClubMemberRole.admin ||
    snap.prefs.clubRole == ClubMemberRole.intendant;

/// Ops check-out / check-in : même périmètre club que [canComposeCrew].
/// [session] conservé pour compat ; le rôle bateau n’est plus exigé.
bool canCheckoutOps(IdentitySnapshot snap, CrewRole session) =>
    canComposeCrew(snap);

bool boatAllowsRower(ParkBoat boat, Rower rower) {
  if (rower.level == RowerLevel.loisir) return boat.loisirOk;
  return true;
}
