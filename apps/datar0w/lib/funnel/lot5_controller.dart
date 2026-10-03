import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../identity/controller.dart';
import '../identity/id.dart';
import '../identity/models.dart';
import 'controller.dart';
import 'lot5_gates.dart';
import 'lot5_models.dart';
import 'lot5_store.dart';
import 'models.dart';

class Lot5State {
  const Lot5State({
    this.loaded = false,
    this.plan,
    this.closures = const [],
    this.dispos = const [],
    this.rowerChoseErg = false,
    this.gate,
  });

  final bool loaded;
  final WaterOutingPlan? plan;
  final List<WaterClosure> closures;
  final List<RowerDispo> dispos;
  final bool rowerChoseErg;
  final WaterGateResult? gate;

  Lot5State copyWith({
    bool? loaded,
    WaterOutingPlan? plan,
    List<WaterClosure>? closures,
    List<RowerDispo>? dispos,
    bool? rowerChoseErg,
    WaterGateResult? gate,
    bool clearPlan = false,
    bool clearGate = false,
  }) =>
      Lot5State(
        loaded: loaded ?? this.loaded,
        plan: clearPlan ? null : (plan ?? this.plan),
        closures: closures ?? this.closures,
        dispos: dispos ?? this.dispos,
        rowerChoseErg: rowerChoseErg ?? this.rowerChoseErg,
        gate: clearGate ? null : (gate ?? this.gate),
      );
}

class Lot5Controller extends Notifier<Lot5State> {
  Lot5Store get _store => ref.read(lot5StoreProvider);

  @override
  Lot5State build() {
    Future<void>.microtask(reload);
    return const Lot5State();
  }

  Future<void> reload() async {
    final dispos = await _store.loadDispos();
    final closures = await _store.loadClosures();
    var plan = await _store.loadPlan();
    final chose = await _store.loadRowerChoseErg();

    final id = ref.read(identityProvider);
    final asg = id.activeRower == null
        ? null
        : id.assignmentForRower(id.activeRower!.id);
    final boat = asg == null ? null : id.boatById(asg.boatId);

    // Seed plan du jour depuis l’affectation si aucun plan persisté.
    if (plan == null && boat != null && asg != null) {
      final now = DateTime.now();
      final planned = DateTime(now.year, now.month, now.day, 18);
      final seats = <String, SeatConfirmState>{};
      for (final a in id.assignmentsForBoat(boat.id)) {
        seats[a.rowerId] = SeatConfirmState.confirmed;
      }
      plan = WaterOutingPlan(
        id: 'plan-${boat.id}',
        boatId: boat.id,
        boatClass: boat.classe,
        plannedAt: planned,
        distM: 2000,
        waterId: 'club-water',
        waterLabel: 'Plan d’eau club',
        seatsRequired: boat.seats,
        coxRequired: boat.cox,
        seatStates: seats,
      );
      await _store.savePlan(plan);
    }

    WaterGateResult? gate;
    if (plan != null && boat != null) {
      gate = resolveWaterGates(
        boat: boat,
        assignments: id.assignmentsForBoat(boat.id),
        plan: plan,
        closures: closures,
        rowerChoseErg: chose,
      );
    }

    state = Lot5State(
      loaded: true,
      plan: plan,
      closures: closures,
      dispos: dispos,
      rowerChoseErg: chose,
      gate: gate,
    );
  }

  Future<void> setDispo({
    required String rowerId,
    required DispoSlot slot,
    required DispoMode mode,
  }) async {
    final day = localDayKey();
    final next = [
      ...state.dispos.where((d) => !(d.rowerId == rowerId && d.day == day && d.slot == slot)),
      RowerDispo(rowerId: rowerId, day: day, slot: slot, mode: mode),
    ];
    await _store.saveDispos(next);
    state = state.copyWith(dispos: next);
  }

  List<RowerDispo> disposTodayFor(String rowerId) {
    final day = localDayKey();
    return state.dispos
        .where((d) => d.rowerId == rowerId && d.day == day)
        .toList();
  }

  Future<void> closeWater({
    required String waterId,
    required WaterVetoReason reason,
    String? note,
    Duration duration = const Duration(hours: 6),
  }) async {
    final now = DateTime.now().toUtc();
    final closure = WaterClosure(
      id: newIdentityId(),
      waterId: waterId,
      from: now,
      to: now.add(duration),
      reason: reason,
      note: note,
    );
    final next = [...state.closures, closure];
    await _store.saveClosures(next);
    state = state.copyWith(closures: next);
    await reload();
  }

  Future<void> liftVeto(String closureId) async {
    final next = state.closures.where((c) => c.id != closureId).toList();
    await _store.saveClosures(next);
    state = state.copyWith(closures: next);
    await reload();
  }

  Future<void> markRowerChoseErg() async {
    await _store.saveRowerChoseErg(true);
    state = state.copyWith(rowerChoseErg: true);
    await reload();
  }

  Future<void> clearRowerChoseErg() async {
    await _store.saveRowerChoseErg(false);
    state = state.copyWith(rowerChoseErg: false);
    await reload();
  }

  /// Bascule indoor : pose la pièce + origin remplacement, retourne piece id.
  Future<ErgPiece> switchToErg() async {
    final plan = state.plan;
    final frame =
        ref.read(funnelProvider).profile?.frame ?? PracticeFrame.competition;
    final piece = ergReplacementForWater(
      waterDistM: plan?.distM ?? 2000,
      frame: frame,
    );
    final reason = state.gate?.kind ?? WaterGateKind.rowerChoseErg;
    if (reason == WaterGateKind.rowerChoseErg ||
        state.gate?.kind == WaterGateKind.open) {
      await markRowerChoseErg();
    }
    ref.read(funnelProvider.notifier).setActivePiece(
          piece: piece,
          dragFactor: ref.read(funnelProvider).profile?.dragFactor,
        );
    ref.read(funnelProvider.notifier).setPendingOrigin('remplacement');
    return piece;
  }

  Future<void> setPlan(WaterOutingPlan plan) async {
    await _store.savePlan(plan);
    state = state.copyWith(plan: plan);
    await reload();
  }

  Future<void> setSeatState(String rowerId, SeatConfirmState st) async {
    final plan = state.plan;
    if (plan == null) return;
    final seats = Map<String, SeatConfirmState>.from(plan.seatStates);
    seats[rowerId] = st;
    await setPlan(plan.copyWith(seatStates: seats));
  }
}

final lot5Provider =
    NotifierProvider<Lot5Controller, Lot5State>(Lot5Controller.new);
