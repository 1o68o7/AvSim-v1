import 'models.dart';

/// Chip quai / accueil : siège, côté et pelles viennent de [Assignment].
String assignmentChip(Assignment a) {
  if (a.role == 'cox') {
    final pos = a.coxPosition == 'front' ? 'avant' : 'arrière';
    return 'barreur $pos';
  }
  final seat = a.seatIndex?.toString() ?? '—';
  final side = a.side == SidePref.none ? '—' : a.side.wire;
  final oars = a.oars.isEmpty ? '—' : a.oars.join('/');
  return 'siège $seat / $side / $oars';
}
