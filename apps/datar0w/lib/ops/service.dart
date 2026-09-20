import '../identity/models.dart';
import '../identity/store.dart';
import 'boat_out.dart';
import 'impact_report.dart';
import 'oar_set.dart';
import 'store.dart';
import 'cloud_sync.dart';

enum CheckoutKind { checkedOut, queued, blocked }

class CheckoutResult {
  const CheckoutResult({
    required this.kind,
    required this.message,
    this.out,
    this.oarSet,
    this.queue,
  });

  final CheckoutKind kind;
  final String message;
  final BoatOut? out;
  final OarSet? oarSet;
  final QueueEntry? queue;

  bool get ok => kind == CheckoutKind.checkedOut;
}

String formatPlannedEnd(DateTime? t) {
  if (t == null) return '';
  final l = t.toLocal();
  final h = l.hour.toString();
  final m = l.minute.toString().padLeft(2, '0');
  return '${h}h$m';
}

/// Règles C1 : sortie explicite, file d’attente, pelles figées, impact → maintenance.
class OpsService {
  OpsService({required this.identity, required this.ops});

  final IdentityStore identity;
  final OpsStore ops;

  OpsCloudSync get _sync => OpsCloudSync(ops: ops, identity: identity);

  Future<void> _afterMutate() async {
    await _sync.snapshotOutbox();
    if (OpsSyncConfig.enabled) {
      try {
        await _sync.flush();
      } catch (_) {}
    }
  }

  Future<BoatOut?> activeOutForBoat(String boatId) async {
    final list = await ops.listOuts();
    for (final o in list.reversed) {
      if (o.boatId == boatId && o.isActive) return o;
    }
    return null;
  }

  Future<bool> canCompose(String boatId) async {
    final boat = await _boat(boatId);
    if (boat == null) return false;
    if (boat.status == BoatParkStatus.out ||
        boat.status == BoatParkStatus.reserved ||
        boat.status == BoatParkStatus.maintenance) {
      return false;
    }
    return await activeOutForBoat(boatId) == null;
  }

  Future<bool> canCheckout(String boatId) async {
    final boat = await _boat(boatId);
    if (boat == null) return false;
    if (boat.status == BoatParkStatus.maintenance) return false;
    if (await _hasOpenImpact(boatId)) return false;
    return boat.status == BoatParkStatus.ready;
  }

  Future<CheckoutResult> checkout({
    required String boatId,
    required String coachId,
    required String coachName,
    List<OarItem> items = const [],
    DateTime? plannedEnd,
    BoatOutStatus status = BoatOutStatus.reserved,
  }) async {
    final boat = await _boat(boatId);
    if (boat == null) {
      return const CheckoutResult(
        kind: CheckoutKind.blocked,
        message: 'Coque inconnue.',
      );
    }
    if (boat.status == BoatParkStatus.maintenance ||
        await _hasOpenImpact(boatId)) {
      return const CheckoutResult(
        kind: CheckoutKind.blocked,
        message: 'Coque en maintenance. Lever le signalement avant de sortir.',
      );
    }

    final active = await activeOutForBoat(boatId);
    if (active != null ||
        boat.status == BoatParkStatus.out ||
        boat.status == BoatParkStatus.reserved) {
      final until = formatPlannedEnd(active?.plannedEnd ?? plannedEnd);
      final who = active?.coachId == coachId ? coachName : 'un autre coach';
      final msg = until.isEmpty
          ? 'Réservée par $who.'
          : 'Réservée par $who jusqu’à $until.';
      final q = QueueEntry.create(
        boatId: boatId,
        coachId: coachId,
        message: msg,
      );
      await ops.upsertQueue(q);
      await _afterMutate();
      return CheckoutResult(
        kind: CheckoutKind.queued,
        message: msg,
        queue: q,
      );
    }

    final set = OarSet.create(boatId: boatId, items: items);
    if (!set.isSubsetOfRack(boat.oarRack)) {
      return const CheckoutResult(
        kind: CheckoutKind.blocked,
        message: 'Jeu de pelles hors rack du club.',
      );
    }
    await ops.upsertOarSet(set);
    final row = BoatOut.create(
      boatId: boatId,
      coachId: coachId,
      plannedEnd: plannedEnd,
      status: status,
      oarSetId: set.id,
    );
    await ops.upsertOut(row);
    final parkStatus = status == BoatOutStatus.out
        ? BoatParkStatus.out
        : BoatParkStatus.reserved;
    await identity.upsertBoat(boat.copyWith(status: parkStatus));
    await _notifyCrew(
      boatId,
      'Ta coque ${boat.name} est sortie.',
    );
    await _afterMutate();
    return CheckoutResult(
      kind: CheckoutKind.checkedOut,
      message: 'Sortie enregistrée.',
      out: row,
      oarSet: set,
    );
  }

  Future<BoatOut?> markDeparted(String outId) async {
    final row = await _outById(outId);
    if (row == null || !row.isActive) return row;
    final next = row.copyWith(status: BoatOutStatus.out);
    await ops.upsertOut(next);
    final boat = await _boat(row.boatId);
    if (boat != null) {
      await identity.upsertBoat(boat.copyWith(status: BoatParkStatus.out));
    }
    await _afterMutate();
    return next;
  }

  Future<BoatOut?> checkIn({
    required String outId,
    required bool oarsOk,
    String? missingNote,
  }) async {
    final row = await _outById(outId);
    if (row == null || !row.isActive) return row;
    final next = row.copyWith(
      status: BoatOutStatus.returned,
      endedAt: DateTime.now().toUtc(),
      oarsOk: oarsOk,
      oarsMissingNote: oarsOk ? null : (missingNote ?? 'pelles manquantes'),
    );
    await ops.upsertOut(next);
    await ops.removeQueueForBoat(row.boatId);
    final boat = await _boat(row.boatId);
    if (boat != null) {
      final maint = await _hasOpenImpact(row.boatId);
      await identity.upsertBoat(
        boat.copyWith(
          status: maint ? BoatParkStatus.maintenance : BoatParkStatus.ready,
        ),
      );
    }
    await _afterMutate();
    return next;
  }

  Future<BoatOut?> transfer({
    required String outId,
    required String toCoachId,
  }) async {
    final row = await _outById(outId);
    if (row == null || !row.isActive) return row;
    final next = row.copyWith(
      transferredFromCoachId: row.coachId,
      transferredAt: DateTime.now().toUtc(),
      coachId: toCoachId,
    );
    await ops.upsertOut(next);
    await _afterMutate();
    return next;
  }

  Future<ImpactReport> reportImpact({
    required String boatId,
    required String reportedBy,
    String note = '',
    String? photoPath,
  }) async {
    final report = ImpactReport.create(
      boatId: boatId,
      reportedBy: reportedBy,
      note: note,
      photoPath: photoPath,
    );
    await ops.upsertImpact(report);
    final boat = await _boat(boatId);
    if (boat != null) {
      await identity.upsertBoat(
        boat.copyWith(status: BoatParkStatus.maintenance),
      );
    }
    await _notifyCrew(boatId, 'Ta coque est en maintenance.');
    await _afterMutate();
    return report;
  }

  Future<void> clearImpact(String reportId) async {
    final list = await ops.listImpacts();
    ImpactReport? found;
    for (final r in list) {
      if (r.id == reportId) found = r;
    }
    if (found == null) return;
    await ops.upsertImpact(found.copyWith(status: ImpactStatus.cleared));
    final boatId = found.boatId;
    if (!await _hasOpenImpact(boatId)) {
      final active = await activeOutForBoat(boatId);
      final boat = await _boat(boatId);
      if (boat != null && active == null) {
        await identity.upsertBoat(
          boat.copyWith(status: BoatParkStatus.ready),
        );
      }
    }
    await _afterMutate();
  }

  Future<ParkBoat?> _boat(String id) async {
    final boats = await identity.listBoats();
    for (final b in boats) {
      if (b.id == id) return b;
    }
    return null;
  }

  Future<BoatOut?> _outById(String id) async {
    final list = await ops.listOuts();
    for (final o in list) {
      if (o.id == id) return o;
    }
    return null;
  }

  Future<bool> _hasOpenImpact(String boatId) async {
    final list = await ops.listImpacts();
    return list.any(
      (r) => r.boatId == boatId && r.status == ImpactStatus.open,
    );
  }

  Future<void> _notifyCrew(String boatId, String message) async {
    final asg = await identity.listAssignments();
    final seen = <String>{};
    for (final a in asg) {
      if (a.boatId != boatId) continue;
      if (!seen.add(a.rowerId)) continue;
      await ops.upsertNotice(
        OpsNotice.create(rowerId: a.rowerId, message: message),
      );
    }
  }
}
