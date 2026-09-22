import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../identity/controller.dart';
import '../identity/ffa_categories.dart';
import '../identity/models.dart';
import '../router.dart';
import '../theme/deck_theme.dart';
import '../widgets/deck_scaffold.dart';

/// 1er login rameur : nom, naissance, sexe, licence FFA optionnelle.
class RowerOnboardingScreen extends ConsumerStatefulWidget {
  const RowerOnboardingScreen({super.key});

  @override
  ConsumerState<RowerOnboardingScreen> createState() =>
      _RowerOnboardingScreenState();
}

class _RowerOnboardingScreenState extends ConsumerState<RowerOnboardingScreen> {
  final _name = TextEditingController();
  final _licence = TextEditingController();
  final _code = TextEditingController();
  DateTime _birth = DateTime(2000, 1, 1);
  RowerSex _sex = RowerSex.m;
  bool _coxToo = false;
  bool _solo = true;
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _licence.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _err = 'Le nom est obligatoire.');
      return;
    }
    setState(() => _err = null);
    await ref.read(identityProvider.notifier).completeRowerOnboarding(
          displayName: name,
          birthDate: _birth,
          sex: _sex,
          ffaLicence: _licence.text,
          clubCode: _solo ? null : _code.text,
          coxToo: _coxToo,
        );
    if (!mounted) return;
    context.go(
      _coxToo ? AppRoutes.homeCox : AppRoutes.homeRower,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = ageCategory(_birth);
    return DeckScaffold(
      title: 'TON PROFIL RAMEUR',
      subtitle: 'Licence FFA optionnelle',
      retourFallback: AppRoutes.auth,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Naissance'),
            subtitle: Text(
              _birth.toIso8601String().split('T').first,
            ),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _birth,
                firstDate: DateTime(1940),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _birth = d);
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'SEXE',
            style: TextStyle(
              color: DeckColors.label,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
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
          const SizedBox(height: 12),
          TextField(
            controller: _licence,
            decoration: const InputDecoration(
              labelText: 'Licence FFA (optionnel)',
              hintText: 'je n’en ai pas',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Catégorie FFA : ${cat.code} ${cat.label} (calculée)',
            style: const TextStyle(color: DeckColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Je rame seul (loisir)'),
            value: _solo,
            onChanged: (v) => setState(() => _solo = v),
          ),
          if (!_solo)
            TextField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Code club'),
              textCapitalization: TextCapitalization.characters,
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Je barre aussi'),
            value: _coxToo,
            onChanged: (v) => setState(() => _coxToo = v),
          ),
          if (_err != null)
            Text(_err!, style: const TextStyle(color: DeckColors.amber)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: const Text('CONTINUER'),
          ),
        ],
      ),
    );
  }
}
