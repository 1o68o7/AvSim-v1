import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../identity/controller.dart';
import '../identity/store.dart';
import 'boat_out.dart';
import 'impact_report.dart';
import 'oar_set.dart';
import 'service.dart';
import 'store.dart';

final opsStoreProvider = Provider<OpsStore>((ref) => OpsStore());

class OpsSnapshot {
  const OpsSnapshot({
    this.outs = const [],
    this.oarSets = const [],
    this.impacts = const [],
    this.queue = const [],
    this.notices = const [],
  });

  final List<BoatOut> outs;
  final List<OarSet> oarSets;
  final List<ImpactReport> impacts;
  final List<QueueEntry> queue;
  final List<OpsNotice> notices;

  BoatOut? activeForBoat(String boatId) {
    for (final o in outs.reversed) {
      if (o.boatId == boatId && o.isActive) return o;
    }
    return null;
  }

  OarSet? oarSetById(String? id) {
    if (id == null) return null;
    for (final s in oarSets) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<BoatOut> get activeOuts => outs.where((o) => o.isActive).toList();

  List<ImpactReport> get openImpacts =>
      impacts.where((r) => r.status == ImpactStatus.open).toList();

  List<OpsNotice> noticesFor(String rowerId) =>
      notices.where((n) => n.rowerId == rowerId).toList();
}

class OpsController extends Notifier<OpsSnapshot> {
  OpsStore get _store => ref.read(opsStoreProvider);
  IdentityStore get _identity => ref.read(identityStoreProvider);

  OpsService get service => OpsService(identity: _identity, ops: _store);

  @override
  OpsSnapshot build() {
    final seeded = _trySync();
    if (seeded != null) return seeded;
    Future<void>.microtask(_refresh);
    return const OpsSnapshot();
  }

  OpsSnapshot? _trySync() {
    final store = _store;
    final outs = store.tryListOutsSync();
    if (outs == null) return null;
    return OpsSnapshot(
      outs: outs,
      oarSets: store.tryListOarSetsSync() ?? const [],
      impacts: store.tryListImpactsSync() ?? const [],
      queue: store.tryListQueueSync() ?? const [],
      notices: store.tryListNoticesSync() ?? const [],
    );
  }

  Future<void> _refresh() async {
    state = OpsSnapshot(
      outs: await _store.listOuts(),
      oarSets: await _store.listOarSets(),
      impacts: await _store.listImpacts(),
      queue: await _store.listQueue(),
      notices: await _store.listNotices(),
    );
    await ref.read(identityProvider.notifier).reloadFromStore();
  }

  Future<CheckoutResult> checkout({
    required String boatId,
    required String coachId,
    required String coachName,
    List<OarItem> items = const [],
    DateTime? plannedEnd,
    BoatOutStatus status = BoatOutStatus.reserved,
  }) async {
    final r = await service.checkout(
      boatId: boatId,
      coachId: coachId,
      coachName: coachName,
      items: items,
      plannedEnd: plannedEnd,
      status: status,
    );
    await _refresh();
    return r;
  }

  Future<void> markDeparted(String outId) async {
    await service.markDeparted(outId);
    await _refresh();
  }

  Future<void> checkIn({
    required String outId,
    required bool oarsOk,
    String? missingNote,
  }) async {
    await service.checkIn(
      outId: outId,
      oarsOk: oarsOk,
      missingNote: missingNote,
    );
    await _refresh();
  }

  Future<void> transfer({
    required String outId,
    required String toCoachId,
  }) async {
    await service.transfer(outId: outId, toCoachId: toCoachId);
    await _refresh();
  }

  Future<void> reportImpact({
    required String boatId,
    required String reportedBy,
    String note = '',
    String? photoPath,
  }) async {
    await service.reportImpact(
      boatId: boatId,
      reportedBy: reportedBy,
      note: note,
      photoPath: photoPath,
    );
    await _refresh();
  }

  Future<void> clearImpact(String reportId) async {
    await service.clearImpact(reportId);
    await _refresh();
  }

  Future<void> markNoticeRead(String id) async {
    final list = await _store.listNotices();
    for (final n in list) {
      if (n.id == id) {
        await _store.upsertNotice(n.copyWith(read: true));
      }
    }
    await _refresh();
  }
}

final opsProvider = NotifierProvider<OpsController, OpsSnapshot>(
  OpsController.new,
);
