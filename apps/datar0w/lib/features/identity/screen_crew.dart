import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../identity/models.dart';
import '../../ops/controller.dart';
import '../../router.dart';
import '../../session/boat_config.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

class _SeatDraft {
  _SeatDraft({this.rowerId, this.side = SidePref.tribord, this.oars = ''});
  String? rowerId;
  SidePref side;
  String oars;
}

/// Composition d'équipage — coach seulement. Coques READY.
class CrewScreen extends ConsumerStatefulWidget {
  const CrewScreen({super.key});

  @override
  ConsumerState<CrewScreen> createState() => _CrewScreenState();
}

class _CrewScreenState extends ConsumerState<CrewScreen> {
  String? _boatId;
  final Map<int, _SeatDraft> _seats = {};
  String? _coxRowerId;
  String _coxPos = 'rear';
  bool _loaded = false;

  void _ensureBoat(IdentitySnapshot snap) {
    final ready = snap.readyBoatsForClub(snap.activeClub?.id);
    if (ready.isEmpty) {
      _boatId = null;
      return;
    }
    if (_boatId == null || ready.every((b) => b.id != _boatId)) {
      _boatId = ready.first.id;
      _loaded = false;
    }
    if (!_loaded) {
      _loadDraft(snap);
      _loaded = true;
    }
  }

  void _loadDraft(IdentitySnapshot snap) {
    final boat = snap.boatById(_boatId);
    _seats.clear();
    _coxRowerId = null;
    _coxPos = 'rear';
    if (boat == null) return;
    for (var i = 1; i <= boat.seats; i++) {
      _seats[i] = _SeatDraft(
        side: i.isOdd ? SidePref.tribord : SidePref.babord,
      );
    }
    for (final a in snap.assignmentsForBoat(boat.id)) {
      if (a.role == 'cox') {
        _coxRowerId = a.rowerId;
        _coxPos = a.coxPosition ?? 'rear';
        continue;
      }
      final i = a.seatIndex;
      if (i == null) continue;
      _seats[i] = _SeatDraft(
        rowerId: a.rowerId,
        side: a.side == SidePref.none ? SidePref.tribord : a.side,
        oars: a.oars.join('/'),
      );
    }
  }

  List<String> _oarsOf(String raw) => raw
      .split(RegExp(r'[,/;]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Set<String> _pickedIds({int? exceptSeat, bool exceptCox = false}) {
    final ids = <String>{};
    for (final e in _seats.entries) {
      if (exceptSeat != null && e.key == exceptSeat) continue;
      final id = e.value.rowerId;
      if (id != null) ids.add(id);
    }
    if (!exceptCox && _coxRowerId != null) ids.add(_coxRowerId!);
    return ids;
  }

  bool _busy(
    IdentitySnapshot snap,
    String rowerId, {
    int? exceptSeat,
    bool exceptCox = false,
  }) {
    if (_pickedIds(exceptSeat: exceptSeat, exceptCox: exceptCox)
        .contains(rowerId)) {
      return true;
    }
    final boat = snap.boatById(_boatId);
    final rower = snap.rowerById(rowerId);
    if (boat != null && rower != null && !boatAllowsRower(boat, rower)) {
      return true;
    }
    return snap.rowerAssignedTodayElsewhere(
      rowerId,
      exceptBoatId: _boatId,
    );
  }

  Future<void> _save(IdentitySnapshot snap) async {
    final boat = snap.boatById(_boatId);
    if (boat == null) return;
    if (ref.read(opsProvider).activeForBoat(boat.id) != null) return;
    final now = DateTime.now().toUtc();
    final crew = <Assignment>[];
    for (var i = 1; i <= boat.seats; i++) {
      final d = _seats[i];
      if (d == null || d.rowerId == null) continue;
      final rower = snap.rowerById(d.rowerId);
      if (rower != null && !boatAllowsRower(boat, rower)) continue;
      crew.add(
        Assignment.create(
          boatId: boat.id,
          rowerId: d.rowerId!,
          side: d.side,
          seatIndex: i,
          oars: _oarsOf(d.oars),
          createdAt: now,
        ),
      );
    }
    if (boat.cox && _coxRowerId != null) {
      crew.add(
        Assignment.create(
          boatId: boat.id,
          rowerId: _coxRowerId!,
          side: SidePref.none,
          role: 'cox',
          coxPosition: _coxPos,
          createdAt: now,
        ),
      );
    }
    await ref.read(identityProvider.notifier).saveCrew(boat.id, crew);
    if (mounted) context.go(AppRoutes.homeCoach);
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(boatConfigProvider).role;
    final snap = ref.watch(identityProvider);
    if (role != CrewRole.coach) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (GoRouter.maybeOf(context) == null) return;
        final dest = snap.activeRower != null
            ? AppRoutes.homeRower
            : AppRoutes.profile;
        context.go(dest);
      });
      return const DeckScaffold(
        title: 'COMPOSITION',
        retourToProfile: true,
        body: Center(
          child: Text(
            'Réservé au coach.',
            style: TextStyle(color: DeckColors.muted),
          ),
        ),
      );
    }

    _ensureBoat(snap);
    final ready = snap.readyBoatsForClub(snap.activeClub?.id);
    final boat = snap.boatById(_boatId);
    final ops = ref.watch(opsProvider);
    final locked = snap
        .boatsForClub(snap.activeClub?.id)
        .where((b) => ops.activeForBoat(b.id) != null ||
            b.status == BoatParkStatus.out ||
            b.status == BoatParkStatus.reserved)
        .toList();

    return DeckScaffold(
      title: 'COMPOSITION',
      subtitle: 'Coques prêtes · 1 tél. = 1 place',
      landscapeHint: true,
      body: ready.isEmpty && locked.isEmpty
          ? const Center(
              child: Text(
                'Aucune coque prête. Statut hors d’eau / maintenance : non assignable.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DeckColors.muted),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (locked.isNotEmpty) ...[
                  for (final b in locked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${b.name} — sortie, composition verrouillée',
                        style: const TextStyle(color: DeckColors.muted),
                      ),
                    ),
                ],
                if (ready.isEmpty)
                  const Text(
                    'Aucune coque prête à composer.',
                    style: TextStyle(color: DeckColors.muted),
                  )
                else
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Coque'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _boatId,
                      items: [
                        for (final b in ready)
                          DropdownMenuItem(
                            value: b.id,
                            child: Text('${b.name}  ${b.classe}'),
                          ),
                      ],
                      onChanged: (id) {
                        setState(() {
                          _boatId = id;
                          _loaded = false;
                          _ensureBoat(snap);
                        });
                      },
                    ),
                  ),
                ),
                if (boat != null && ready.any((b) => b.id == boat.id)) ...[
                  const SizedBox(height: 12),
                  for (var i = 1; i <= boat.seats; i++)
                    _seatRow(snap, boat, i),
                  if (boat.cox) _coxRow(snap),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => _save(snap),
                    child: const Text('ENREGISTRER L’ÉQUIPAGE'),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _seatRow(IdentitySnapshot snap, ParkBoat boat, int seat) {
    final d = _seats[seat] ?? _SeatDraft();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: DeckColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SIÈGE $seat',
              style: const TextStyle(
                color: DeckColors.label,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
            ),
            DropdownButton<String?>(
              isExpanded: true,
              value: d.rowerId,
              hint: const Text('Rameur'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('—'),
                ),
                for (final r in snap.rowers)
                  DropdownMenuItem<String?>(
                    value: r.id,
                    enabled: r.id == d.rowerId ||
                        !_busy(snap, r.id, exceptSeat: seat),
                    child: Text(
                      r.displayName,
                      style: TextStyle(
                        color: (r.id == d.rowerId ||
                                !_busy(snap, r.id, exceptSeat: seat))
                            ? DeckColors.text
                            : DeckColors.muted,
                      ),
                    ),
                  ),
              ],
              onChanged: (id) => setState(() {
                _seats[seat] = _SeatDraft(
                  rowerId: id,
                  side: d.side,
                  oars: d.oars,
                );
              }),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final s in [SidePref.tribord, SidePref.babord])
                  ChoiceChip(
                    label: Text(s.wire),
                    selected: d.side == s,
                    onSelected: (_) => setState(() {
                      _seats[seat] = _SeatDraft(
                        rowerId: d.rowerId,
                        side: s,
                        oars: d.oars,
                      );
                    }),
                  ),
              ],
            ),
            TextFormField(
              initialValue: d.oars,
              decoration: InputDecoration(
                labelText: boat.oarRack.isEmpty
                    ? 'Pelles'
                    : 'Pelles (${boat.oarRack.join('/')})',
              ),
              onChanged: (v) => d.oars = v,
            ),
          ],
        ),
      ),
    );
  }

  Widget _coxRow(IdentitySnapshot snap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: DeckColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BARREUR',
              style: TextStyle(
                color: DeckColors.label,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
            ),
            DropdownButton<String?>(
              isExpanded: true,
              value: _coxRowerId,
              hint: const Text('Barreur'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('—'),
                ),
                for (final r in snap.rowers)
                  DropdownMenuItem<String?>(
                    value: r.id,
                    enabled: r.id == _coxRowerId ||
                        !_busy(snap, r.id, exceptCox: true),
                    child: Text(r.displayName),
                  ),
              ],
              onChanged: (id) => setState(() => _coxRowerId = id),
            ),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('arrière'),
                  selected: _coxPos == 'rear',
                  onSelected: (_) => setState(() => _coxPos = 'rear'),
                ),
                ChoiceChip(
                  label: const Text('avant'),
                  selected: _coxPos == 'front',
                  onSelected: (_) => setState(() => _coxPos = 'front'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
