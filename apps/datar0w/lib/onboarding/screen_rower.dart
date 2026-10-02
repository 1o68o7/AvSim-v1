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
import '../widgets/deck_widgets.dart';

/// DR-03 — Licence & club (Stitch).
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
  bool _shareTraining = true;
  bool _roleComp = true;
  bool _roleLeisure = false;
  String? _err;
  /// 0 = profil, 1 = DR-03 licence.
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

  void _verifyLicence() {
    final licence = _licence.text.trim();
    setState(() {
      _lookup = lookupFfaLicence(licence);
      _err = null;
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
      title: 'Fiche rameur',
      subtitle: '1er login · étape 1/2',
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
          Text(
            'SEXE',
            style: DeckType.labelMono(color: DeckColors.label, size: 10),
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
            style: const TextStyle(
              fontFamily: DeckType.ui,
              color: DeckColors.label,
              fontSize: 12,
            ),
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
            Text(_err!, style: const TextStyle(color: DeckColors.volt)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _goLicenceStep,
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenceStep(BuildContext context) {
    final lookup = _lookup;
    final club = ref.watch(identityProvider).activeClub;
    final season = seasonStartYear(DateTime.now());

    return DeckScaffold(
      title: 'Licence & club',
      subtitle: 'Affiliation FFA & habilitations',
      leading: IconButton(
        tooltip: 'Retour',
        onPressed: () => setState(() {
          _step = 0;
          _lookup = null;
        }),
        icon: const Icon(Icons.arrow_back),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Row(
            children: [
              Text(
                'DR-03',
                style: DeckType.labelMono(color: DeckColors.volt, size: 11),
              ),
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: DeckColors.volt,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Licence & Filiation',
                style: DeckType.labelMono(color: DeckColors.label, size: 11),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: DeckColors.surfaceHigh,
                  borderRadius: DeckRadii.chipAll,
                ),
                child: Text(
                  '3 / 3',
                  style: DeckType.labelMono(color: DeckColors.volt, size: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Affiliation FFA & habilitations navigantes',
            style: TextStyle(
              fontFamily: DeckType.ui,
              fontSize: 12,
              color: DeckColors.label,
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 64,
                  decoration: BoxDecoration(
                    color: DeckColors.tribord,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                const DeckIconBox(icon: Icons.sailing, accent: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Non bloquant pour ramer',
                              style: TextStyle(
                                fontFamily: DeckType.ui,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
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
                              'LOCAL PRÊT',
                              style: DeckType.labelMono(
                                color: DeckColors.tribord,
                                size: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'La saisie de votre licence est facultative pour '
                        'enregistrer vos premières sorties locales. Vous '
                        'pourrez naviguer et tester les capteurs immédiatement.',
                        style: TextStyle(
                          fontFamily: DeckType.ui,
                          fontSize: 12,
                          height: 1.4,
                          color: DeckColors.label,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.apartment,
                      size: 18,
                      color: DeckColors.volt,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'CLUB D\'APPARTENANCE',
                      style: DeckType.uiLabel(
                        color: DeckColors.text,
                        size: 13,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (club?.shortCode != null)
                      Text(
                        'CODE FFA #${club!.shortCode}',
                        style: DeckType.labelMono(
                          color: DeckColors.label,
                          size: 10,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: DeckColors.surfaceHigh,
                    borderRadius: DeckRadii.buttonAll,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: DeckColors.surfaceHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          (club?.shortCode ?? 'LOC').toUpperCase(),
                          style: DeckType.labelMono(
                            color: DeckColors.volt,
                            size: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              club?.name ??
                                  (_solo
                                      ? 'Profil loisir (sans club)'
                                      : 'Club via code'),
                              style: const TextStyle(
                                fontFamily: DeckType.ui,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: DeckColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _solo
                                  ? 'Je rame seul (loisir)'
                                  : 'Code club saisi à l’étape précédente',
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
                ),
                if (!_solo) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _code,
                    decoration: const InputDecoration(
                      labelText: 'Rechercher un autre club FFA…',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.badge, size: 18, color: DeckColors.volt),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'IDENTIFIANT FÉDÉRAL & LICENCE',
                        style: DeckType.uiLabel(
                          color: DeckColors.text,
                          size: 13,
                          weight: FontWeight.w500,
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
                        'SAISON ${season.toString().substring(2)}/'
                        '${(season + 1).toString().substring(2)}',
                        style: DeckType.labelMono(
                          color: DeckColors.text,
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _licence,
                        decoration: const InputDecoration(
                          labelText: 'n° licence FFA (optionnel)',
                          hintText: 'ex. 1234567A',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (_) {
                          if (_lookup != null) {
                            setState(() => _lookup = null);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _verifyLicence,
                        icon: const Icon(Icons.verified, size: 16),
                        label: const Text('Vérifier'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (lookup is FfaLicenceFound)
                  _LookupBanner(
                    title: 'LICENCE COMPÉTITION VALIDÉE',
                    body:
                        '${lookup.hit.displayName} · ${lookup.hit.clubName}',
                    ok: true,
                  )
                else if (lookup is FfaLicenceLeisure)
                  const _LookupBanner(
                    title: 'Profil loisir',
                    body: 'Loisir sans licence : tu peux passer.',
                    ok: false,
                  )
                else
                  const Text(
                    'Loisir sans licence : tu peux passer.',
                    style: TextStyle(
                      fontFamily: DeckType.ui,
                      color: DeckColors.label,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sports, size: 18, color: DeckColors.volt),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'CASQUETTES & RÔLES AU CLUB',
                        style: DeckType.uiLabel(
                          color: DeckColors.text,
                          size: 13,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      'CHOIX MULTIPLE',
                      style: DeckType.labelMono(
                        color: DeckColors.label,
                        size: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _RoleRow(
                  label: 'Rameur Compétition',
                  badge: 'J18/SENIOR',
                  selected: _roleComp,
                  onTap: () => setState(() => _roleComp = !_roleComp),
                ),
                const SizedBox(height: 6),
                _RoleRow(
                  label: 'Rameur Loisir / Randonnée',
                  badge: 'LOISIR',
                  selected: _roleLeisure,
                  onTap: () => setState(() => _roleLeisure = !_roleLeisure),
                ),
                const SizedBox(height: 6),
                _RoleRow(
                  label: 'Barreur certifié',
                  badge: 'BREVET B',
                  selected: _coxToo,
                  onTap: () => setState(() => _coxToo = !_coxToo),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Row(
              children: [
                const DeckIconBox(icon: Icons.ios_share, accent: true),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Partage bilans d’entraînement',
                        style: TextStyle(
                          fontFamily: DeckType.ui,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: DeckColors.text,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Transmission automatique des splits et watts aux '
                        'entraîneurs du club.',
                        style: TextStyle(
                          fontFamily: DeckType.ui,
                          fontSize: 12,
                          color: DeckColors.label,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _shareTraining,
                  onChanged: (v) => setState(() => _shareTraining = v),
                ),
              ],
            ),
          ),
          if (_err != null) ...[
            const SizedBox(height: 8),
            Text(_err!, style: const TextStyle(color: DeckColors.volt)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: () => _finish(skipLicence: false),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Finaliser mon profil & Aller à Aujourd’hui',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => _finish(skipLicence: true),
            child: const Text(
              'Passer cette étape (je renseignerai ma licence plus tard)',
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

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

class _LookupBanner extends StatelessWidget {
  const _LookupBanner({
    required this.title,
    required this.body,
    required this.ok,
  });

  final String title;
  final String body;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                decoration: BoxDecoration(
                  color: ok ? DeckColors.tribord : DeckColors.label,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ok ? DeckColors.tribord : DeckColors.label,
                  ),
                ),
              ),
              if (ok)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: DeckColors.tribordWash,
                    borderRadius: DeckRadii.chipAll,
                  ),
                  child: Text(
                    'ACTIF',
                    style: DeckType.labelMono(
                      color: DeckColors.tribord,
                      size: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontFamily: DeckType.ui,
              fontSize: 12,
              color: DeckColors.label,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.label,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? DeckColors.surfaceHigh : DeckColors.bg,
      borderRadius: DeckRadii.buttonAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: DeckRadii.buttonAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? DeckColors.volt : DeckColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: selected
                    ? const Icon(
                        Icons.check,
                        size: 14,
                        color: DeckColors.onVolt,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 14,
                    color: selected ? DeckColors.text : DeckColors.label,
                  ),
                ),
              ),
              Text(
                badge,
                style: DeckType.labelMono(
                  color: selected ? DeckColors.volt : DeckColors.label,
                  size: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
