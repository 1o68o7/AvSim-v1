import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../identity/models.dart';
import '../../router.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

String _sexLabel(RowerSex s) => switch (s) {
      RowerSex.m => 'Homme',
      RowerSex.f => 'Femme',
      RowerSex.x => 'Autre',
    };

String _sexIcon(RowerSex s) => switch (s) {
      RowerSex.m => '♂',
      RowerSex.f => '♀',
      RowerSex.x => '·',
    };

String _initials(String first, String last) {
  final a = first.trim().isEmpty ? '' : first.trim()[0];
  final b = last.trim().isEmpty ? '' : last.trim()[0];
  final s = '$a$b'.toUpperCase();
  return s.isEmpty ? '?' : s;
}

int _ageYears(DateTime birth) {
  final now = DateTime.now();
  var age = now.year - birth.year;
  if (now.month < birth.month ||
      (now.month == birth.month && now.day < birth.day)) {
    age--;
  }
  return age < 0 ? 0 : age;
}

/// DR-02 — Fiche rameur (Stitch).
class RowerEditScreen extends ConsumerStatefulWidget {
  const RowerEditScreen({super.key, this.rowerId});

  final String? rowerId;

  @override
  ConsumerState<RowerEditScreen> createState() => _RowerEditScreenState();
}

class _RowerEditScreenState extends ConsumerState<RowerEditScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
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
    _first.dispose();
    _last.dispose();
    _weight.dispose();
    _height.dispose();
    _oars.dispose();
    super.dispose();
  }

  void _splitName(String full) {
    final parts =
        full.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) {
      _first.text = '';
      _last.text = '';
      return;
    }
    if (parts.length == 1) {
      _first.text = parts.first;
      _last.text = '';
      return;
    }
    _first.text = parts.first;
    _last.text = parts.sublist(1).join(' ');
  }

  String get _displayName {
    final f = _first.text.trim();
    final l = _last.text.trim();
    if (f.isEmpty) return l;
    if (l.isEmpty) return f;
    return '$f $l';
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
      _splitName(existing.displayName);
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
    final name = _displayName;
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

  String get _birthLabel =>
      '${_birth.day.toString().padLeft(2, '0')} / '
      '${_birth.month.toString().padLeft(2, '0')} / '
      '${_birth.year.toString().padLeft(4, '0')}';

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(identityProvider);
    _hydrate(snap);
    final preview = Rower(
      id: 'tmp',
      displayName: _displayName,
      birthDate: _birth,
      sex: _sex,
      weightKg: double.tryParse(_weight.text.replaceAll(',', '.')),
      heightCm: double.tryParse(_height.text.replaceAll(',', '.')),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final cat = preview.category();
    final club = snap.activeClub;
    final age = _ageYears(_birth);

    return DeckScaffold(
      title: 'Fiche rameur',
      subtitle: club?.name ?? 'Biométrie & calage',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DeckColors.volt,
                  borderRadius: DeckRadii.chipAll,
                ),
                child: Text(
                  'ONBOARDING 2/3',
                  style: DeckType.labelMono(
                    color: DeckColors.onVolt,
                    size: 10,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Setup Athlète',
                style: DeckType.uiLabel(size: 12),
              ),
              const Spacer(),
              Text(
                'FFA v25.1',
                style: DeckType.labelMono(color: DeckColors.volt, size: 10),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Fiche rameur',
            style: TextStyle(
              fontFamily: DeckType.ui,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.24,
              color: DeckColors.text,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Biométrie appliquée, allonge & calcul de coque',
            style: TextStyle(
              fontFamily: DeckType.ui,
              fontSize: 12,
              color: DeckColors.label,
            ),
          ),
          const SizedBox(height: 16),
          _DeckCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: DeckColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _initials(_first.text, _last.text),
                        style: const TextStyle(
                          fontFamily: DeckType.ui,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: DeckColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName.isEmpty ? 'Nouveau profil' : _displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: DeckType.ui,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: DeckColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            club?.name ?? 'Profil local',
                            style: const TextStyle(
                              fontFamily: DeckType.ui,
                              fontSize: 12,
                              color: DeckColors.label,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _first,
                        decoration: const InputDecoration(
                          labelText: 'PRÉNOM',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _last,
                        decoration: const InputDecoration(
                          labelText: 'NOM',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'CATÉGORIE SEXE (FÉDÉRALE)',
                  style: DeckType.labelMono(color: DeckColors.label, size: 10),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: DeckColors.surfaceHigh,
                    borderRadius: DeckRadii.buttonAll,
                  ),
                  child: Row(
                    children: [
                      for (final s in RowerSex.values)
                        Expanded(
                          child: _SexChip(
                            label: _sexLabel(s),
                            prefix: _sexIcon(s),
                            selected: _sex == s,
                            onTap: () => setState(() => _sex = s),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'DATE DE NAISSANCE',
                      style: DeckType.labelMono(
                        color: DeckColors.label,
                        size: 10,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$age ANS',
                      style: DeckType.labelMono(
                        color: DeckColors.tribord,
                        size: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: DeckRadii.buttonAll,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: DeckColors.surfaceHigh,
                      borderRadius: DeckRadii.buttonAll,
                      border: Border.all(color: DeckColors.hairline),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: DeckColors.label,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _birthLabel,
                          style: DeckType.metric(size: 14, height: 18 / 14),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.edit_calendar,
                          size: 18,
                          color: DeckColors.label,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DeckColors.surfaceHigh,
                    borderRadius: DeckRadii.buttonAll,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: DeckColors.tribord,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'CATÉGORIE FFA : ${cat.code} '
                              '${cat.label.toUpperCase()} '
                              '(${_sexShort(_sex)})',
                              style: DeckType.labelMono(
                                color: DeckColors.tribord,
                                size: 10,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Index officiel ajusté d’après les tables fédérales '
                        'FFA. Calculé — jamais saisi.',
                        style: TextStyle(
                          fontFamily: DeckType.ui,
                          fontSize: 12,
                          color: DeckColors.label,
                        ),
                      ),
                      if (preview.lightweight)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Poids léger (ligne FFA)',
                            style: TextStyle(
                              fontFamily: DeckType.ui,
                              color: DeckColors.tribord,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DeckCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Morphologie & Calage',
                        style: TextStyle(
                          fontFamily: DeckType.ui,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: DeckColors.text,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: DeckColors.surfaceHigh,
                        borderRadius: DeckRadii.chipAll,
                      ),
                      child: Text(
                        'RIGGING HUD',
                        style: DeckType.labelMono(
                          color: DeckColors.label,
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Indispensable pour l’assiette latérale et l’amplitude '
                  'de coulisse.',
                  style: TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 12,
                    color: DeckColors.label,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _height,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'TAILLE (cm)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _weight,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'POIDS (kg)',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'POSTE DE NAGE PRÉFÉRENTIEL',
                  style: DeckType.labelMono(color: DeckColors.label, size: 10),
                ),
                const SizedBox(height: 8),
                _SideTile(
                  title: 'Pointe Bâbord',
                  subtitle: 'Port Side (Rouge)',
                  accent: DeckColors.babord,
                  selected: _side == SidePref.babord,
                  onTap: () => setState(() => _side = SidePref.babord),
                ),
                const SizedBox(height: 6),
                _SideTile(
                  title: 'Pointe Tribord',
                  subtitle: 'Stbd (Vert)',
                  accent: DeckColors.tribord,
                  selected: _side == SidePref.tribord,
                  onTap: () => setState(() => _side = SidePref.tribord),
                ),
                const SizedBox(height: 6),
                _SideTile(
                  title: 'Couple (2 pelles)',
                  subtitle: 'Bâbord & Tribord',
                  accent: DeckColors.label,
                  selected: _side == SidePref.none,
                  onTap: () => setState(() => _side = SidePref.none),
                  dualDot: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _oars,
                  decoration: const InputDecoration(
                    labelText: 'Pelles (ex. P1/P2/P4)',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'NIVEAU',
                  style: DeckType.labelMono(color: DeckColors.label, size: 10),
                ),
                const SizedBox(height: 6),
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
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _save,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Enregistrer'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 22),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.identity),
            child: const Text('Remplir plus tard (Mode invité bord de bassin)'),
          ),
        ],
      ),
    );
  }
}

String _sexShort(RowerSex s) => switch (s) {
      RowerSex.m => 'SH',
      RowerSex.f => 'SF',
      RowerSex.x => 'SX',
    };

class _DeckCard extends StatelessWidget {
  const _DeckCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: DeckRadii.cardAll,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: child,
    );
  }
}

class _SexChip extends StatelessWidget {
  const _SexChip({
    required this.label,
    required this.prefix,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String prefix;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? DeckColors.surfaceHighest : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 36,
          child: Center(
            child: Text(
              '$prefix $label',
              style: TextStyle(
                fontFamily: DeckType.ui,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? DeckColors.text : DeckColors.label,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SideTile extends StatelessWidget {
  const _SideTile({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.selected,
    required this.onTap,
    this.dualDot = false,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;
  final bool dualDot;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? DeckColors.surfaceHigh : DeckColors.surfaceHigh.withValues(alpha: 0.5),
      borderRadius: DeckRadii.buttonAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: DeckRadii.buttonAll,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: DeckRadii.buttonAll,
            border: Border.all(
              color: selected ? DeckColors.volt : DeckColors.hairline,
            ),
          ),
          child: Row(
            children: [
              if (dualDot)
                SizedBox(
                  width: 14,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: DeckColors.babord,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: DeckColors.tribord,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: DeckType.ui,
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: DeckColors.text,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: DeckType.labelMono(color: accent, size: 10),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: DeckColors.volt, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
