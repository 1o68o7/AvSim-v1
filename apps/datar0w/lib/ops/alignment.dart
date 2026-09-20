import '../identity/models.dart';
import '../session/boat_class.dart';
import 'boat_out.dart';

/// 8+ d’abord, 1x en dernier. File visuelle d’embarquement.
int boardingRank(String classe) {
  const order = ['8+', '4+', '4-', '4x', '2-', '2x', '1x'];
  final i = order.indexOf(BoatClassInfo.of(classe).code);
  return i < 0 ? order.length : i;
}

class DepartureRow {
  const DepartureRow({
    required this.out,
    required this.boat,
    required this.crew,
    this.oarLabel = '',
  });

  final BoatOut out;
  final ParkBoat boat;
  final List<Assignment> crew;
  final String oarLabel;
}

List<DepartureRow> sortDeparture(List<DepartureRow> rows) {
  final copy = [...rows];
  copy.sort((a, b) {
    final r = boardingRank(a.boat.classe).compareTo(boardingRank(b.boat.classe));
    if (r != 0) return r;
    return a.boat.name.compareTo(b.boat.name);
  });
  return copy;
}
