import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../identity/device_store.dart';
import '../../identity/devices.dart';
import '../../identity/id.dart';
import '../../router.dart';
import '../../sensors/ble/ble_client.dart';
import '../../sensors/ble/cardio_hub.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import '../../widgets/deck_widgets.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  List<ConnectedDevice> _list = [];
  List<BleScanHit> _hits = [];
  bool _scanning = false;
  bool _denied = false;
  bool _linkOk = false;
  bool _patchDenied = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  DeviceStore get _store => ref.read(deviceStoreProvider);

  Future<void> _reload() async {
    final all = await _store.list();
    final id = ref.read(identityProvider).activeRower?.id;
    setState(() {
      _list = id == null ? all : all.where((d) => d.rowerId == id).toList();
    });
  }

  Future<void> _scan() async {
    final client = ref.read(bleHrClientProvider);
    setState(() {
      _scanning = true;
      _denied = false;
      _hits = [];
    });
    final ok = await client.ensurePermission();
    if (!ok) {
      ref.read(cardioHubProvider.notifier).clear();
      setState(() {
        _scanning = false;
        _denied = true;
        _linkOk = false;
      });
      return;
    }
    final sub = client.hits.listen((list) {
      if (mounted) setState(() => _hits = list);
    });
    try {
      await client.startScan();
    } catch (_) {
      ref.read(cardioHubProvider.notifier).clear();
      setState(() => _linkOk = false);
    } finally {
      sub.cancel();
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _pair(BleScanHit hit) async {
    final rower = ref.read(identityProvider).activeRower;
    if (rower == null) return;
    final device = ConnectedDevice(
      id: newIdentityId(),
      rowerId: rower.id,
      type: DeviceType.chestStrap,
      name: hit.name,
      bleId: hit.id,
      isPrimary: true,
      pairedAt: DateTime.now().toUtc(),
      lastSeenAt: DateTime.now().toUtc(),
    );
    await _store.upsert(device);
    await _reload();
    await _connect(hit.id);
  }

  Future<void> _connect(String bleId) async {
    final client = ref.read(bleHrClientProvider);
    final hub = ref.read(cardioHubProvider.notifier);
    final ok = await client.connect(
      bleId,
      onPayload: hub.ingest,
    );
    if (!ok) hub.clear();
    if (mounted) setState(() => _linkOk = ok);
  }

  Future<void> _forget(ConnectedDevice d) async {
    await _store.remove(d.id);
    await _reload();
  }

  Future<void> _mockPatch() async {
    final rower = ref.read(identityProvider).activeRower;
    if (rower == null) return;
    final client = ref.read(bleHrClientProvider);
    final ok = await client.ensurePermission();
    if (!ok) {
      setState(() => _patchDenied = true);
      return;
    }
    setState(() => _patchDenied = false);
    await _store.upsert(
      ConnectedDevice(
        id: newIdentityId(),
        rowerId: rower.id,
        type: DeviceType.patchDorsal,
        name: 'Patch dorsal',
        bleId: 'mock-patch',
        isPrimary: false,
        pairedAt: DateTime.now().toUtc(),
        lastSeenAt: DateTime.now().toUtc(),
        lastBattery: 82,
        patchLink: PatchLinkState.paired,
      ),
    );
    await _reload();
  }

  Future<void> _savePatch(ConnectedDevice d) async {
    await _store.upsert(d);
    await _reload();
  }

  IconData _iconFor(ConnectedDevice d) {
    if (d.isPatch) return Icons.sensors;
    switch (d.type) {
      case DeviceType.chestStrap:
        return Icons.monitor_heart;
      case DeviceType.armBand:
        return Icons.watch;
      case DeviceType.watch:
        return Icons.watch;
      default:
        return Icons.bluetooth;
    }
  }

  String _lastSync(ConnectedDevice d) {
    final t = d.lastSeenAt ?? d.pairedAt;
    final diff = DateTime.now().toUtc().difference(t);
    if (diff.inMinutes < 2) return 'il y a un instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return 'il y a ${diff.inDays} j';
  }

  @override
  Widget build(BuildContext context) {
    final rower = ref.watch(identityProvider).activeRower;
    final hr = ref.watch(cardioHubProvider);
    final heart = (!_linkOk || _denied || hr == null) ? '♥ —' : '♥ ${hr.bpm}';
    final patches = _list.where((d) => d.isPatch).toList();
    final patchBat = patches.isEmpty ? null : patches.first.lastBattery;
    final patchChip = _patchDenied || patches.isEmpty
        ? 'patch —'
        : (patchBat == null
            ? 'patch ${patches.first.patchLink?.label ?? 'pairé'}'
            : 'patch $patchBat %');
    return DeckScaffold(
      title: 'MES OBJETS',
      subtitle: 'sangle GATT 0x180D · patch dorsal · pas de montre',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DeckStatusChip(
                label: heart,
                ok: _linkOk && hr != null,
                alert: _denied || !_linkOk,
              ),
              DeckStatusChip(
                label: patchChip,
                ok: patches.isNotEmpty && !_patchDenied,
                alert: _patchDenied || patches.isEmpty,
              ),
            ],
          ),
          if (_denied || _patchDenied)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Bluetooth refusé. En entraînement le GPS téléphone continue. '
                'FC / patch indisponibles.',
                style: TextStyle(color: DeckColors.amber, height: 1.4),
              ),
            ),
          const SizedBox(height: 16),
          DeckSectionLabel(
            'Objets appairés',
            trailing: Text(
              '${_list.length}',
              style: const TextStyle(
                color: DeckColors.label,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_list.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: DeckColors.hairline),
              ),
              child: const Text(
                'Aucun objet connecté.\n'
                'Scanner une sangle (0x180D) ou apparier un patch dorsal (mock).',
                style: TextStyle(color: DeckColors.muted, height: 1.4),
              ),
            ),
          for (final d in _list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: DeckColors.surfaceHigh,
                child: InkWell(
                  onTap: rower == null
                      ? null
                      : () async {
                          if (d.isPatch) {
                            await _savePatch(
                              d.copyWith(
                                patchLink: PatchLinkState.logLocal,
                                lastSeenAt: DateTime.now().toUtc(),
                              ),
                            );
                            return;
                          }
                          if (d.bleId == null) return;
                          await _store.upsert(
                            d.copyWith(
                              isPrimary: true,
                              lastSeenAt: DateTime.now().toUtc(),
                            ),
                          );
                          await _reload();
                          await _connect(d.bleId!);
                        },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: DeckColors.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            DeckIconBox(
                              icon: _iconFor(d),
                              accent: d.isPatch || d.isPrimary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    [
                                      if (d.isPrimary) 'primaire',
                                      d.isPatch
                                          ? 'patch dorsal'
                                          : 'sangle FC',
                                      if (d.isPatch && d.patchLink != null)
                                        d.patchLink!.label,
                                    ].join(' · '),
                                    style: const TextStyle(
                                      color: DeckColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (d.lastBattery != null)
                              Text(
                                '${d.lastBattery} %',
                                style: TextStyle(
                                  color: (d.lastBattery ?? 100) < 20
                                      ? DeckColors.amber
                                      : DeckColors.tribord,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dernier sync : ${_lastSync(d)}',
                          style: const TextStyle(
                            color: DeckColors.label,
                            fontSize: 11,
                          ),
                        ),
                        if (d.lastBattery != null) ...[
                          const SizedBox(height: 8),
                          ClipRect(
                            child: LinearProgressIndicator(
                              value: (d.lastBattery! / 100).clamp(0.0, 1.0),
                              minHeight: 4,
                              backgroundColor: DeckColors.hairline,
                              color: (d.lastBattery ?? 100) < 20
                                  ? DeckColors.amber
                                  : DeckColors.tribord,
                            ),
                          ),
                        ],
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _forget(d),
                            child: Text(d.isPatch ? 'OUBLIER' : 'DÉCONNECTER'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_hits.isNotEmpty) ...[
            const SizedBox(height: 8),
            const DeckSectionLabel('Trouvés à proximité'),
            for (final h in _hits)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(h.name),
                subtitle: Text('RSSI ${h.rssi} dBm · tap pour appairer'),
                trailing: const Icon(Icons.add_link, color: DeckColors.amber),
                onTap: rower == null ? null : () => _pair(h),
              ),
          ],
          if (patches.isNotEmpty) ...[
            const SizedBox(height: 16),
            const DeckSectionLabel('Feedback patch'),
            const Text(
              'Personnel onboard (vibration / petit OLED). '
              'Pas de liaison coach pendant une course. Pas de firmware ici.',
              style: TextStyle(color: DeckColors.muted, fontSize: 12, height: 1.35),
            ),
            for (final p in patches) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cadence'),
                value: p.feedbackCadence,
                onChanged: (v) => _savePatch(p.copyWith(feedbackCadence: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Gîte (bande)'),
                value: p.feedbackGite,
                onChanged: (v) => _savePatch(p.copyWith(feedbackGite: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Zone HR'),
                value: p.feedbackHr,
                onChanged: (v) => _savePatch(p.copyWith(feedbackHr: v)),
              ),
            ],
            const Text(
              'F estimée — non dispo',
              style: TextStyle(color: DeckColors.label, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: rower == null || _scanning ? null : _scan,
            child: Text(
              _scanning ? 'SCAN…' : '+ AJOUTER UN OBJET (SCAN BLE)',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: rower == null ? null : _mockPatch,
            child: const Text('APPARIER PATCH (MOCK)'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Le patch dorsal mesure FC, SpO2 (au repos), température de peau '
            'et orientation du torse. La sangle améliore la fidélité FC. '
            'États patch = mock jusqu’au firmware.',
            style: TextStyle(color: DeckColors.muted, fontSize: 11, height: 1.4),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.consent),
            child: const Text('Consentement santé'),
          ),
        ],
      ),
    );
  }
}
