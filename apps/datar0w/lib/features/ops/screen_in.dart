import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../identity/controller.dart';
import '../../ops/controller.dart';
import '../../ops/service.dart';
import '../../session/boat_config.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import 'screen_impact.dart';

class OpsInScreen extends ConsumerStatefulWidget {
  const OpsInScreen({super.key});

  @override
  ConsumerState<OpsInScreen> createState() => _OpsInScreenState();
}

class _OpsInScreenState extends ConsumerState<OpsInScreen> {
  bool _oarsOk = true;
  final _missing = TextEditingController();
  String? _flash;

  @override
  void dispose() {
    _missing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(boatConfigProvider).role;
    final ident = ref.watch(identityProvider);
    final ops = ref.watch(opsProvider);
    if (role != CrewRole.coach || !canCheckoutOps(ident, role)) {
      return const DeckScaffold(
        title: 'RETOUR',
        retourToProfile: true,
        body: Center(
          child: Text(
            'Réservé au coach.',
            style: TextStyle(color: DeckColors.muted),
          ),
        ),
      );
    }
    final active = ops.activeOuts;

    return DeckScaffold(
      title: 'RETOUR DE PARC',
      subtitle: 'Check-in',
      body: active.isEmpty
          ? const Center(
              child: Text(
                'Aucune coque sortie.',
                style: TextStyle(color: DeckColors.muted),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (_flash != null)
                  Text(_flash!, style: const TextStyle(color: DeckColors.amber)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pelles OK'),
                  value: _oarsOk,
                  onChanged: (v) => setState(() => _oarsOk = v),
                ),
                if (!_oarsOk)
                  TextField(
                    controller: _missing,
                    decoration: const InputDecoration(
                      labelText: 'Manquant',
                    ),
                  ),
                const SizedBox(height: 8),
                for (final o in active)
                  _OutTile(
                    name: ident.boatById(o.boatId)?.name ?? o.boatId,
                    classe: ident.boatById(o.boatId)?.classe ?? '',
                    boatId: o.boatId,
                    oars: ops.oarSetById(o.oarSetId)?.label ?? '—',
                    until: formatPlannedEnd(o.plannedEnd),
                    onIn: () async {
                      await ref.read(opsProvider.notifier).checkIn(
                            outId: o.id,
                            oarsOk: _oarsOk,
                            missingNote: _oarsOk ? null : _missing.text.trim(),
                          );
                      if (mounted) {
                        setState(() => _flash = 'Coque rentrée.');
                      }
                    },
                  ),
              ],
            ),
    );
  }
}

class _OutTile extends StatelessWidget {
  const _OutTile({
    required this.name,
    required this.classe,
    required this.boatId,
    required this.oars,
    required this.until,
    required this.onIn,
  });

  final String name;
  final String classe;
  final String boatId;
  final String oars;
  final String until;
  final VoidCallback onIn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: DeckColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              '$classe${until.isEmpty ? '' : ' · jusqu’à $until'}',
              style: const TextStyle(color: DeckColors.label, fontSize: 12),
            ),
            Text(
              'Pelles : $oars',
              style: const TextStyle(color: DeckColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onIn,
              child: const Text('RENTRER'),
            ),
            const SizedBox(height: 8),
            SignalImpactButton(boatId: boatId),
          ],
        ),
      ),
    );
  }
}
