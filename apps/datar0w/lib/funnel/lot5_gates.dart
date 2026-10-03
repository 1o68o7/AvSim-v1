import '../identity/models.dart';
import 'lot5_models.dart';

/// Porte équipage : sièges rameurs (+ barreur si besoin).
/// Skiff (1 siège, pas de barreur) : équipage toujours OK s’il y a ≥1 assignment.
({int confirmed, int needed, bool complete, bool canDownsize}) evaluateCrewGate({
  required ParkBoat boat,
  required List<Assignment> assignments,
  Map<String, SeatConfirmState> seatStates = const {},
}) {
  final needed = boat.seats;
  final coxNeeded = boat.cox;
  final rowers = assignments.where((a) => a.role != 'cox').toList();
  final coxes = assignments.where((a) => a.role == 'cox').toList();

  int confirmed;
  if (seatStates.isEmpty) {
    // Pas d’états locaux : toute affectation compte comme confirmée.
    confirmed = rowers.length;
  } else {
    confirmed = rowers.where((a) {
      final st = seatStates[a.rowerId] ?? SeatConfirmState.pending;
      return st == SeatConfirmState.confirmed || st == SeatConfirmState.replaced;
    }).length;
  }

  final coxOk = !coxNeeded || coxes.isNotEmpty;
  final complete = confirmed >= needed && coxOk;

  // Au moins 2 oui → proposer bateau plus court avant erg.
  final canDownsize = !complete && confirmed >= 2 && needed > 2;

  // Skiff : seule la porte plan d’eau compte.
  if (needed <= 1 && !coxNeeded) {
    return (
      confirmed: confirmed.clamp(0, 1),
      needed: 1,
      complete: true,
      canDownsize: false,
    );
  }

  return (
    confirmed: confirmed,
    needed: needed,
    complete: complete,
    canDownsize: canDownsize,
  );
}

/// Porte plan d’eau : ouvert sauf veto actif sur ce bassin.
({bool open, WaterClosure? closure}) evaluateWaterGate({
  required String waterId,
  required List<WaterClosure> closures,
  DateTime? at,
}) {
  final t = at ?? DateTime.now().toUtc();
  for (final c in closures) {
    if (c.waterId == waterId && c.activeAt(t)) {
      return (open: false, closure: c);
    }
  }
  return (open: true, closure: null);
}

WaterGateResult resolveWaterGates({
  required ParkBoat boat,
  required List<Assignment> assignments,
  required WaterOutingPlan plan,
  required List<WaterClosure> closures,
  bool rowerChoseErg = false,
  DateTime? at,
}) {
  if (rowerChoseErg) {
    return const WaterGateResult(kind: WaterGateKind.rowerChoseErg);
  }

  final water = evaluateWaterGate(
    waterId: plan.waterId,
    closures: closures,
    at: at,
  );
  if (!water.open) {
    return WaterGateResult(
      kind: WaterGateKind.waterClosed,
      waterReason: water.closure?.reasonLine ?? 'Plan d’eau fermé',
      crewConfirmed: 0,
      crewNeeded: boat.seats,
    );
  }

  final crew = evaluateCrewGate(
    boat: boat,
    assignments: assignments,
    seatStates: plan.seatStates,
  );
  if (!crew.complete) {
    return WaterGateResult(
      kind: WaterGateKind.crewBroken,
      crewConfirmed: crew.confirmed,
      crewNeeded: crew.needed,
      canDownsize: crew.canDownsize,
    );
  }

  return WaterGateResult(
    kind: WaterGateKind.open,
    crewConfirmed: crew.confirmed,
    crewNeeded: crew.needed,
  );
}

String indoorCancelLabel(WaterGateKind kind) => switch (kind) {
      WaterGateKind.crewBroken => 'Eau annulée · équipage',
      WaterGateKind.waterClosed => 'Eau annulée · plan d’eau',
      WaterGateKind.rowerChoseErg => 'Tu as choisi l’erg',
      WaterGateKind.open => '',
    };
