import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../identity/controller.dart';
import '../identity/ffa_categories.dart';
import '../identity/ffa_licence_lookup.dart';
import '../identity/models.dart';
import '../router.dart';
import '../theme/deck_theme.dart';
import '../widgets/deck_scaffold.dart';

/// 1er login rameur : profil puis ST-08 licence FFA optionnelle.
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
  /// 0 = profil, 1 = ST-08 licence.
  int _step = 0;
  FfaLicenceLookupResult? _lookup;

  @override
  void dispose() {
    _name.dispose();
    _licence.dispose();
    _code.dispose();
    super.dispose();
  }

  void _goLicenceStep() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _err = 'Le nom est obligatoire.');
      return;
    }
    setState(() {
      _err = null;
      _step = 1;
      _lookup = null;
    });
  }

  Future<void> _finish({required bool skipLicence}) async {
    final licence = skipLicence ? '' : _licence.text.trim();
    final result = (!skipLicence && licence.isNotEmpty)
        ? lookupFfaLicence(licence)
        : const FfaLicenceLeisure();
    if (!mounted) return;
    setState(() {
      _lookup = result;
      _err = null;
    });
    final dest = _coxToo ? AppRoutes.homeCox : AppRoutes.homeRower;
    try {
      await ref.read(identityProvider.notifier).completeRowerOnboarding(
            displayName: _name.text.trim(),
            birthDate: _birth,
            sex: _sex,
            ffaLicence: skipLicence || licence.isEmpty ? null : licence,
            clubCode: _solo ? null : _code.text,
            coxToo: _coxToo,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e');
      return;
    }
    if (!mounted) return;
    // Post-frame : évite conflit rebuild identity ↔ go_router.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(dest);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 1) return _buildLicenceStep(context);
    return _buildProfileStep(context);
  }

  Widget _buildProfileStep(BuildContext context) {
    final cat = ageCategory(_birth);
    return DeckScaffold(
      title: 'TON PROFIL RAMEUR',
      subtitle: '1er login',
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
            onPressed: _goLicenceStep,
            child: const Text('CONTINUER'),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenceStep(BuildContext context) {
    final lookup = _lookup;
    return DeckScaffold(
      title: 'TA LICENCE',
      subtitle: 'optionnel',
      leading: IconButton(
        tooltip: 'Retour',
        onPressed: () => setState(() {
          _step = 0;
          _lookup = null;
        }),
        icon: const Icon(Icons.arrow_back),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          TextField(
            controller: _licence,
            decoration: const InputDecoration(
              labelText: 'n° licence FFA (optionnel)',
              hintText: 'ex. 1234567A',
            ),
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) {
              if (_lookup != null) setState(() => _lookup = null);
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Loisir sans licence : tu peux passer.',
            style: TextStyle(color: DeckColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (lookup is FfaLicenceFound) ...[
            Text(
              '${lookup.hit.displayName} · ${lookup.hit.clubName}',
              style: const TextStyle(
                color: DeckColors.tribord,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
          ] else if (lookup is FfaLicenceLeisure) ...[
            const Text(
              'Profil loisir',
              style: TextStyle(
                color: DeckColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_err != null)
            Text(_err!, style: const TextStyle(color: DeckColors.amber)),
          FilledButton(
            onPressed: () => _finish(skipLicence: false),
            child: const Text('CONTINUER'),
          ),
          TextButton(
            onPressed: () => _finish(skipLicence: true),
            child: const Text('PASSER'),
          ),
        ],
      ),
    );
  }
}
