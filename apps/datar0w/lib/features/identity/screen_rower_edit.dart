import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../identity/models.dart';
import '../../router.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

class RowerEditScreen extends ConsumerStatefulWidget {
  const RowerEditScreen({super.key, this.rowerId});

  final String? rowerId;

  @override
  ConsumerState<RowerEditScreen> createState() => _RowerEditScreenState();
}

class _RowerEditScreenState extends ConsumerState<RowerEditScreen> {
  final _name = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _oars = TextEditingController();
  DateTime _birth = DateTime(2000, 1, 1);
  RowerSex _sex = RowerSex.m;
  SidePref _side = SidePref.none;
  RowerLevel _level = RowerLevel.inconnu;
  bool _ready = false;
  String? _id;
  DateTime? _createdAt;

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    _height.dispose();
    _oars.dispose();
    super.dispose();
  }

  void _hydrate(IdentitySnapshot snap) {
    if (_ready) return;
    if (widget.rowerId != null && snap.rowers.isEmpty) return;
    Rower? existing;
    if (widget.rowerId != null) {
      for (final r in snap.rowers) {
        if (r.id == widget.rowerId) existing = r;
      }
    }
    if (existing != null) {
      _id = existing.id;
      _createdAt = existing.createdAt;
      _name.text = existing.displayName;
      _birth = existing.birthDate;
      _sex = existing.sex;
      _side = existing.sidePref;
      _level = existing.level;
      if (existing.weightKg != null) {
        _weight.text = existing.weightKg!.toString();
      }
      if (existing.heightCm != null) {
        _height.text = existing.heightCm!.toString();
      }
      _oars.text = existing.oarSpec ?? '';
    }
    _ready = true;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _birth,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _birth = d);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final now = DateTime.now().toUtc();
    final clubId = ref.read(identityProvider).activeClub?.id;
    final rower = Rower(
      id: _id ?? Rower.create(displayName: name, birthDate: _birth).id,
      displayName: name,
      birthDate: _birth,
      sex: _sex,
      weightKg: double.tryParse(_weight.text.replaceAll(',', '.')),
      heightCm: double.tryParse(_height.text.replaceAll(',', '.')),
      sidePref: _side,
      oarSpec: _oars.text.trim().isEmpty ? null : _oars.text.trim(),
      level: _level,
      clubId: clubId,
      createdAt: _createdAt ?? now,
      updatedAt: now,
    );
    await ref.read(identityProvider.notifier).saveRower(rower);
    if (mounted) context.go(AppRoutes.identity);
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(identityProvider);
    _hydrate(snap);
    final preview = Rower(
      id: 'tmp',
      displayName: _name.text,
      birthDate: _birth,
      sex: _sex,
      weightKg: double.tryParse(_weight.text.replaceAll(',', '.')),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return DeckScaffold(
      title: 'PROFIL RAMEUR',
      subtitle: 'Catégorie calculée · jamais saisie',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Prénom + nom'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date de naissance'),
            subtitle: Text(
              '${_birth.year.toString().padLeft(4, '0')}-'
              '${_birth.month.toString().padLeft(2, '0')}-'
              '${_birth.day.toString().padLeft(2, '0')}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          Text(
            'Catégorie : ${preview.category()} (lecture seule)',
            style: const TextStyle(color: DeckColors.amber, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final s in RowerSex.values)
                ChoiceChip(
                  label: Text(s.wire),
                  selected: _sex == s,
                  onSelected: (_) => setState(() => _sex = s),
                ),
            ],
          ),
          if (preview.lightweight)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Poids léger (ligne FFA)',
                style: TextStyle(color: DeckColors.tribord, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Poids (kg)'),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _height,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Taille (cm)'),
          ),
          const SizedBox(height: 8),
          const Text('Côté préféré (pas une contrainte)'),
          Wrap(
            spacing: 8,
            children: [
              for (final s in SidePref.values)
                ChoiceChip(
                  label: Text(s.wire),
                  selected: _side == s,
                  onSelected: (_) => setState(() => _side = s),
                ),
            ],
          ),
          TextField(
            controller: _oars,
            decoration: const InputDecoration(
              labelText: 'Pelles (ex. P1/P2/P4)',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final l in RowerLevel.values)
                ChoiceChip(
                  label: Text(l.wire),
                  selected: _level == l,
                  onSelected: (_) => setState(() => _level = l),
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
