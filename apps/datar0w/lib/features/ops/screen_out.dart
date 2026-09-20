import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../identity/models.dart';
import '../../ops/controller.dart';
import '../../ops/oar_set.dart';
import '../../router.dart';
import '../../session/boat_config.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

class OpsOutScreen extends ConsumerStatefulWidget {
  const OpsOutScreen({super.key});

  @override
  ConsumerState<OpsOutScreen> createState() => _OpsOutScreenState();
}

class _OpsOutScreenState extends ConsumerState<OpsOutScreen> {
  String? _boatId;
  TimeOfDay? _end;
  final Map<String, int> _qty = {};
  final Map<String, bool> _pick = {};
  bool _personal = false;
  final _personalSpec = TextEditingController();
  final _impact = TextEditingController();
  String? _flash;

  @override
  void dispose() {
    _personalSpec.dispose();
    _impact.dispose();
    super.dispose();
  }

  String get _coachId {
    final r = ref.read(identityProvider).activeRower;
    return r?.id ?? 'coach-local';
  }

  String get _coachName =>
      ref.read(identityProvider).activeRower?.displayName ?? 'Coach';

  Future<void> _sortir(ParkBoat boat) async {
    final items = <OarItem>[];
    for (final spec in boat.oarRack) {
      if (_pick[spec] == true) {
        items.add(OarItem(spec: spec, qty: _qty[spec] ?? 1));
      }
    }
    if (_personal && _personalSpec.text.trim().isNotEmpty) {
      items.add(
        OarItem(
          spec: _personalSpec.text.trim(),
          qty: 1,
          source: OarSource.personal,
        ),
      );
    }
    DateTime? planned;
    if (_end != null) {
      final n = DateTime.now();
      planned = DateTime(n.year, n.month, n.day, _end!.hour, _end!.minute);
    }
    final r = await ref.read(opsProvider.notifier).checkout(
          boatId: boat.id,
          coachId: _coachId,
          coachName: _coachName,
          items: items,
          plannedEnd: planned,
        );
    if (!mounted) return;
    if (r.ok && _impact.text.trim().isNotEmpty) {
      await ref.read(opsProvider.notifier).reportImpact(
            boatId: boat.id,
            reportedBy: _coachId,
            note: _impact.text.trim(),
          );
    }
    setState(() => _flash = r.message);
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(boatConfigProvider).role;
    final snap = ref.watch(identityProvider);
    if (role != CrewRole.coach) {
      return const DeckScaffold(
        title: 'SORTIE',
        body: Center(
          child: Text(
            'Réservé au coach.',
            style: TextStyle(color: DeckColors.muted),
          ),
        ),
      );
    }
    final ready = snap.readyBoatsForClub(snap.activeClub?.id);
    if (_boatId != null && ready.every((b) => b.id != _boatId)) {
      _boatId = null;
    }
    _boatId ??= ready.isEmpty ? null : ready.first.id;
    final boat = snap.boatById(_boatId);

    return DeckScaffold(
      title: 'SORTIE DE PARC',
      subtitle: 'Check-out explicite',
      leading: TextButton(
        onPressed: () => context.go(AppRoutes.homeCoach),
        child: const Text('Retour'),
      ),
      body: ready.isEmpty
          ? const Center(
              child: Text(
                'Aucune coque prête.',
                style: TextStyle(color: DeckColors.muted),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (_flash != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _flash!,
                      style: const TextStyle(color: DeckColors.amber),
                    ),
                  ),
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
                      onChanged: (id) => setState(() {
                        _boatId = id;
                        _pick.clear();
                        _qty.clear();
                      }),
                    ),
                  ),
                ),
                if (boat != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'JEU DE PELLES',
                    style: TextStyle(
                      color: DeckColors.label,
                      fontSize: 11,
                      letterSpacing: 1.1,
                    ),
                  ),
                  for (final spec in boat.oarRack)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(spec),
                      value: _pick[spec] ?? false,
                      onChanged: (v) => setState(() {
                        _pick[spec] = v ?? false;
                        _qty[spec] = _qty[spec] ?? 1;
                      }),
                      secondary: SizedBox(
                        width: 72,
                        child: TextField(
                          decoration: const InputDecoration(labelText: 'qty'),
                          keyboardType: TextInputType.number,
                          onChanged: (t) =>
                              _qty[spec] = int.tryParse(t) ?? 1,
                        ),
                      ),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pelles personnelles'),
                    value: _personal,
                    onChanged: (v) => setState(() => _personal = v),
                  ),
                  if (_personal)
                    TextField(
                      controller: _personalSpec,
                      decoration: const InputDecoration(
                        labelText: 'Spec perso',
                      ),
                    ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _end == null
                          ? 'Heure prévue (optionnel)'
                          : 'Prévu ${_end!.format(context)}',
                    ),
                    trailing: const Icon(Icons.schedule, color: DeckColors.label),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (t != null) setState(() => _end = t);
                    },
                  ),
                  TextField(
                    controller: _impact,
                    decoration: const InputDecoration(
                      labelText: 'Impact (opt-in, photo au lot C5)',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => _sortir(boat),
                    child: const Text('SORTIR'),
                  ),
                ],
              ],
            ),
    );
  }
}
