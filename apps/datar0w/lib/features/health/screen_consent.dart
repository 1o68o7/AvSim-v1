import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../health/consent_store.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

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
      title: 'DONNÉES SANTÉ',
      subtitle: 'informatif, pas médical',
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const Text(
                  'La fréquence cardiaque et la saturation sont des '
                  'indications d’entraînement, pas un diagnostic.',
                  style: TextStyle(color: DeckColors.muted, height: 1.4),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enregistrer FC / SpO2'),
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
                  title: const Text('Partager avec le coach'),
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
