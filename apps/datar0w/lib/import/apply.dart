import '../identity/id.dart';
import '../identity/models.dart';
import 'mapping.dart';

class ImportApplyResult {
  const ImportApplyResult({
    required this.importId,
    required this.boats,
    required this.created,
    required this.updated,
    required this.ignored,
  });

  final String importId;
  final List<ParkBoat> boats;
  final int created;
  final int updated;
  final int ignored;
}

/// Écrit seulement après confirmation. Doublon nom+classe (ou id) → mise à jour.
ImportApplyResult applyParkImport({
  required String clubId,
  required List<ParkBoat> existing,
  required List<ParsedBoatRow> rows,
  String? importId,
}) {
  final id = importId ?? newIdentityId();
  final boats = [...existing];
  var created = 0;
  var updated = 0;
  var ignored = 0;

  int indexOf(ParsedBoatRow r) {
    if (r.id != null && r.id!.isNotEmpty) {
      final i = boats.indexWhere((b) => b.id == r.id);
      if (i >= 0) return i;
    }
    final name = r.name ?? '';
    final classe = resolveBoatClass(r.classe);
    return boats.indexWhere(
      (b) =>
          b.clubId == clubId &&
          b.name.toLowerCase() == name.toLowerCase() &&
          b.classe == classe,
    );
  }

  for (final r in rows) {
    if (!r.ok) {
      ignored++;
      continue;
    }
    final classe = resolveBoatClass(r.classe);
    final i = indexOf(r);
    if (i >= 0) {
      final prev = boats[i];
      boats[i] = prev.copyWith(
        name: r.name,
        classe: classe,
        oarRack: r.oars.isEmpty ? prev.oarRack : r.oars,
        boatType: r.boatType == null
            ? prev.boatType
            : BoatTypeX.parse(r.boatType),
        brand: r.brand ?? prev.brand,
        model: r.model ?? prev.model,
        year: r.year ?? prev.year,
        material: r.material == null
            ? prev.material
            : BoatMaterialX.parse(r.material),
        serial: r.serial ?? prev.serial,
        notes: r.notes ?? prev.notes,
        loisirOk: r.loisirOk ?? prev.loisirOk,
        status: r.status == null
            ? prev.status
            : BoatParkStatusX.parse(r.status),
      );
      updated++;
    } else {
      boats.add(
        ParkBoat.create(
          clubId: clubId,
          name: r.name!,
          classe: classe,
          oarRack: r.oars,
          boatType: BoatTypeX.parse(r.boatType),
          brand: r.brand,
          model: r.model,
          year: r.year,
          material: BoatMaterialX.parse(r.material),
          serial: r.serial,
          notes: r.notes,
          loisirOk: r.loisirOk ?? true,
          status: BoatParkStatusX.parse(r.status),
          importId: id,
        ),
      );
      created++;
    }
  }
  return ImportApplyResult(
    importId: id,
    boats: boats,
    created: created,
    updated: updated,
    ignored: ignored,
  );
}

List<ParkBoat> undoImport({
  required List<ParkBoat> boats,
  required String importId,
}) {
  return boats.where((b) => b.importId != importId).toList();
}

String resolveBoatClass(String? raw) {
  final c = (raw ?? '').trim();
  if (c.isEmpty) return '1x';
  const codes = ['1x', '2x', '2-', '4x', '4-', '4+', '8+'];
  for (final x in codes) {
    if (x.toLowerCase() == c.toLowerCase()) return x;
  }
  return '1x';
}
