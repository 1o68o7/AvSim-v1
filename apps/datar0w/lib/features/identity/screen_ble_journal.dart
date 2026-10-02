import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../identity/controller.dart';
import '../../identity/device_store.dart';
import '../../identity/devices.dart';
import '../../sensors/ble/ble_journal.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import '../../widgets/deck_widgets.dart';

/// DR-63 — Journal technique & diagnostics BLE.
class BleJournalScreen extends ConsumerStatefulWidget {
  const BleJournalScreen({super.key});

  @override
  ConsumerState<BleJournalScreen> createState() => _BleJournalScreenState();
}

class _BleJournalScreenState extends ConsumerState<BleJournalScreen> {
  List<ConnectedDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final id = ref.read(identityProvider).activeRower?.id;
    final all = await ref.read(deviceStoreProvider).list();
    if (!mounted) return;
    setState(() {
      _devices = id == null ? all : all.where((d) => d.rowerId == id).toList();
    });
  }

  Future<void> _copyJournal(List<BleJournalEntry> entries) async {
    final text = entries.isEmpty
        ? 'Journal BLE vide.'
        : entries.map((e) => e.format()).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Journal copié dans le presse-papiers.')),
    );
  }

  String _deviceState(ConnectedDevice d) {
    final seen = d.lastSeenAt;
    if (seen == null) return 'jamais vu';
    final diff = DateTime.now().toUtc().difference(seen);
    if (diff.inMinutes < 5) return 'actif';
    if (diff.inHours < 24) return 'hors portée (récent)';
    return 'hors portée';
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(bleJournalProvider);
    final reversed = entries.reversed.toList();

    return DeckScaffold(
      title: 'Journal BLE',
      subtitle: 'Diagnostics techniques locaux',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const DeckHonestChip(kind: DeckHonestKind.local),
              DeckStatusChip(
                label: '${_devices.length} objet(s) appairé(s)',
                ok: _devices.isNotEmpty,
              ),
              DeckStatusChip(
                label: '${entries.length} événement(s)',
                ok: entries.isNotEmpty,
              ),
            ],
          ),
          const SizedBox(height: 16),
          DeckSectionLabel(
            'État des objets appairés',
            trailing: Text('${_devices.length}', style: DeckType.labelMono(size: 11)),
          ),
          const SizedBox(height: 8),
          if (_devices.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DeckColors.surface,
                borderRadius: DeckRadii.cardAll,
                border: Border.all(color: DeckColors.hairline),
              ),
              child: const Text(
                'Aucun objet appairé. Rien à diagnostiquer pour le moment.',
                style: TextStyle(color: DeckColors.muted, height: 1.4),
              ),
            )
          else
            for (final d in _devices)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DeckColors.surface,
                    borderRadius: DeckRadii.cardAll,
                    border: Border.all(color: DeckColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              d.name,
                              style: const TextStyle(
                                fontFamily: DeckType.ui,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DeckStatusChip(
                            label: _deviceState(d),
                            ok: _deviceState(d) == 'actif',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Identifiant BLE : ${d.bleId ?? '—'}',
                        style: DeckType.labelMono(size: 11),
                      ),
                      if (d.lastBattery != null)
                        Text(
                          'Dernière batterie rapportée : ${d.lastBattery} %',
                          style: DeckType.labelMono(size: 11),
                        ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 16),
          DeckSectionLabel(
            'Journal des événements',
            trailing: Text('${entries.length}', style: DeckType.labelMono(size: 11)),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DeckColors.surfaceHigh,
              borderRadius: DeckRadii.cardAll,
              border: Border.all(color: DeckColors.hairline),
            ),
            child: reversed.isEmpty
                ? const Text(
                    'Journal vide — lance un scan ou une connexion depuis '
                    '« Mes objets » pour générer des entrées.',
                    style: TextStyle(color: DeckColors.muted, height: 1.4),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in reversed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            e.format(),
                            style: TextStyle(
                              fontFamily: DeckType.mono,
                              fontSize: 11,
                              color: switch (e.level) {
                                BleLogLevel.error => DeckColors.babord,
                                BleLogLevel.warn => DeckColors.amber,
                                BleLogLevel.info => DeckColors.label,
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _copyJournal(entries),
                  child: const Text('Copier le journal'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: entries.isEmpty
                      ? null
                      : () => ref.read(bleJournalProvider.notifier).clear(),
                  child: const Text('Vider'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Journal technique local uniquement — aucun envoi cloud. '
            'Diagnostic du lien BLE, pas une mesure physiologique ou '
            'biomécanique certifiée.',
            style: TextStyle(color: DeckColors.muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}
