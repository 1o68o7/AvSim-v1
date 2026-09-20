import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../identity/models.dart';
import '../../router.dart';
import '../../session/boat_config.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import 'screen_club.dart';

class BoatEditScreen extends ConsumerStatefulWidget {
  const BoatEditScreen({super.key, this.boatId});

  final String? boatId;

  @override
  ConsumerState<BoatEditScreen> createState() => _BoatEditScreenState();
}

class _BoatEditScreenState extends ConsumerState<BoatEditScreen> {
  final _name = TextEditingController();
  final _oars = TextEditingController();
  String _classe = '1x';
  BoatParkStatus _status = BoatParkStatus.ready;
  bool _loisirOk = true;
  bool _ready = false;
  String? _id;

  @override
  void dispose() {
    _name.dispose();
    _oars.dispose();
    super.dispose();
  }

  void _hydrate(IdentitySnapshot snap) {
    if (_ready) return;
    if (widget.boatId != null && snap.boats.isEmpty) return;
    ParkBoat? existing;
    if (widget.boatId != null) {
      existing = snap.boatById(widget.boatId);
    }
    if (existing != null) {
      _id = existing.id;
      _name.text = existing.name;
      _classe = existing.classe;
      _status = existing.status;
      _oars.text = existing.oarRack.join('/');
      _loisirOk = existing.loisirOk;
    }
    _ready = true;
  }

  Future<void> _save() async {
    if (!canEditPark(ref.read(identityProvider), ref.read(boatConfigProvider).role)) return;
    final name = _name.text.trim();
    final club = ref.read(identityProvider).activeClub;
    if (name.isEmpty || club == null) return;
    final rack = _oars.text
        .split(RegExp(r'[,/;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final boat = _id == null
        ? ParkBoat.create(
            clubId: club.id,
            name: name,
            classe: _classe,
            oarRack: rack,
            status: _status,
            loisirOk: _loisirOk,
          )
        : ParkBoat(
            id: _id!,
            clubId: club.id,
            name: name,
            classe: _classe,
            seats: BoatClassInfo.of(_classe).seats,
            cox: BoatClassInfo.of(_classe).coxed,
            oarRack: rack,
            status: _status,
            loisirOk: _loisirOk,
          );
    await ref.read(identityProvider.notifier).saveBoat(boat);
    if (mounted) context.go(AppRoutes.club);
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(identityProvider);
    final edit = canEditPark(
      snap,
      ref.watch(boatConfigProvider).role,
    );
    _hydrate(snap);
    final info = BoatClassInfo.of(_classe);
    if (!edit) {
      return DeckScaffold(
        title: 'COQUE',
        leading: TextButton(
          onPressed: () => context.go(AppRoutes.club),
          child: const Text('Retour'),
        ),
        body: const Center(
          child: Text(
            'Parc éditable par le coach seulement.',
            style: TextStyle(color: DeckColors.muted),
          ),
        ),
      );
    }
    return DeckScaffold(
      title: 'COQUE',
      subtitle: 'Parc du club',
      leading: TextButton(
        onPressed: () => context.go(AppRoutes.club),
        child: const Text('Retour'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
          const SizedBox(height: 12),
          const Text('Classe'),
          Wrap(
            spacing: 8,
            children: [
              for (final c in BoatClassInfo.all)
                ChoiceChip(
                  label: Text(c.code),
                  selected: _classe == c.code,
                  onSelected: (_) => setState(() => _classe = c.code),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Barreur : ${info.coxed ? 'oui' : 'non'} · ${info.seats} sièges',
            style: const TextStyle(color: DeckColors.label, fontSize: 12),
          ),
          TextField(
            controller: _oars,
            decoration: const InputDecoration(
              labelText: 'Pelles (ex. P1/P2/P4)',
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ouvert loisir'),
            value: _loisirOk,
            onChanged: (v) => setState(() => _loisirOk = v),
          ),
          const SizedBox(height: 8),
          const Text('Statut'),
          Wrap(
            spacing: 8,
            children: [
              for (final s in BoatParkStatus.values)
                ChoiceChip(
                  label: Text(boatStatusLabel(s)),
                  selected: _status == s,
                  onSelected: (_) => setState(() => _status = s),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: const Text('ENREGISTRER'),
          ),
        ],
      ),
    );
  }
}
