import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/loisir_store.dart';
import '../../health/consent_store.dart';
import '../../health/physio_store.dart';
import '../../identity/controller.dart';
import '../../sync/physio_sync.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

final physioStoreProvider = Provider<PhysioStore>((ref) => PhysioStore());

class PhysioScreen extends ConsumerStatefulWidget {
  const PhysioScreen({super.key});

  @override
  ConsumerState<PhysioScreen> createState() => _PhysioScreenState();
}

class _PhysioScreenState extends ConsumerState<PhysioScreen> {
  PhysioRecord _r = const PhysioRecord();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final r = await ref.read(physioStoreProvider).load();
    if (mounted) {
      setState(() {
        _r = r;
        _loaded = true;
      });
    }
  }

  Future<void> _save(PhysioRecord r) async {
    final ident = ref.read(identityProvider);
    final rower = ident.activeRower;
    final n = r.copyWith(
      rowerId: rower?.id,
      clubId: rower?.clubId ?? ident.activeClub?.id,
      userId: rower?.userId,
      consentAt: r.consent ? (r.consentAt ?? DateTime.now().toUtc()) : r.consentAt,
    );
    await ref.read(physioStoreProvider).save(n);
    await ConsentStore().save(
      HealthConsent(
        accepted: n.consent,
        shareWithCoach: n.shareWithCoach,
        at: n.consentAt,
      ),
    );
    await syncRowerPhysio(n);
    if (mounted) setState(() => _r = n);
  }

  @override
  Widget build(BuildContext context) {
    final rower = ref.watch(identityProvider).activeRower;
    return DeckScaffold(
      title: 'MES CONSTANTES',
      subtitle: 'informatif · pas médical',
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _r.consent,
                  onChanged: (v) => _save(
                    _r.copyWith(
                      consent: v == true,
                      shareWithCoach: v == true ? _r.shareWithCoach : false,
                    ),
                  ),
                  title: const Text('Consentement santé (FC / constantes)'),
                  subtitle: const Text(
                    'Données de santé, usage informatif, pas médical. '
                    'Aucun diagnostic. Opt-in R6.',
                    style: TextStyle(color: DeckColors.muted, fontSize: 12),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Partager avec le coach'),
                  value: _r.shareWithCoach,
                  onChanged: !_r.consent
                      ? null
                      : (v) => _save(_r.copyWith(shareWithCoach: v)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'READINESS',
                  style: TextStyle(
                    color: DeckColors.label,
                    fontSize: 11,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '—',
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.w700),
                ),
                const Text(
                  'Pas assez de séances avec FC pour un score.',
                  style: TextStyle(color: DeckColors.muted),
                ),
                const SizedBox(height: 24),
                const Text(
                  'DERNIÈRE SÉANCE',
                  style: TextStyle(
                    color: DeckColors.label,
                    fontSize: 11,
                    letterSpacing: 1.1,
                  ),
                ),
                const Text(
                  'Courbe FC + cadence + V sol : voir replay après STOP.',
                  style: TextStyle(color: DeckColors.muted, height: 1.4),
                ),
                const SizedBox(height: 24),
                const Text(
                  'PARCOURS',
                  style: TextStyle(
                    color: DeckColors.label,
                    fontSize: 11,
                    letterSpacing: 1.1,
                  ),
                ),
                FutureBuilder(
                  future: LoisirStore().list(),
                  builder: (context, snap) {
                    final mine = (snap.data ?? const [])
                        .where((p) => rower == null || p.rowerId == rower.id)
                        .toList();
                    if (mine.isEmpty) {
                      return const Text(
                        'Aucune régate / rando / master signalé.',
                        style: TextStyle(color: DeckColors.muted),
                      );
                    }
                    return Column(
                      children: [
                        for (final p in mine)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(p.type),
                            subtitle: Text(p.tempsCourse ?? p.eventId),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }
}
