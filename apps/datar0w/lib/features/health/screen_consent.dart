import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../health/consent_store.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import '../../widgets/deck_widgets.dart';

final consentStoreProvider = Provider<ConsentStore>((ref) => ConsentStore());

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  HealthConsent _c = const HealthConsent();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final c = await ref.read(consentStoreProvider).load();
    if (mounted) {
      setState(() {
        _c = c;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DeckScaffold(
      title: 'Santé & consentement',
      subtitle: 'RGPD Art. 9 · informatif, pas médical',
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const Wrap(
                  spacing: 8,
                  children: [
                    DeckHonestChip(kind: DeckHonestKind.local),
                    DeckStatusChip(label: 'Chiffré local', ok: true),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'La fréquence cardiaque et la saturation sont des '
                  'indications d’entraînement, pas un diagnostic. '
                  'Stockage local-first.',
                  style: TextStyle(color: DeckColors.muted, height: 1.4),
                ),
                const SizedBox(height: 8),
                const DeckSectionLabel('Consentement actif'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Collecte biométrique en séance'),
                  value: _c.accepted,
                  onChanged: (v) async {
                    final n = HealthConsent(
                      accepted: v,
                      shareWithCoach: v ? _c.shareWithCoach : false,
                      at: DateTime.now().toUtc(),
                    );
                    await ref.read(consentStoreProvider).save(n);
                    setState(() => _c = n);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cockpit coach live & débrief'),
                  subtitle: const Text('Désactivé par défaut'),
                  value: _c.shareWithCoach,
                  onChanged: !_c.accepted
                      ? null
                      : (v) async {
                          final n = HealthConsent(
                            accepted: true,
                            shareWithCoach: v,
                            at: DateTime.now().toUtc(),
                          );
                          await ref.read(consentStoreProvider).save(n);
                          setState(() => _c = n);
                        },
                ),
              ],
            ),
    );
  }
}
