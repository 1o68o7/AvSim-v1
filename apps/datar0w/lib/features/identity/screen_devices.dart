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

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final all = await ref.read(deviceStoreProvider).list();
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
    await ref.read(deviceStoreProvider).upsert(device);
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

  @override
  Widget build(BuildContext context) {
    final rower = ref.watch(identityProvider).activeRower;
    final hr = ref.watch(cardioHubProvider);
    final heart = (!_linkOk || _denied || hr == null) ? '♥ —' : '♥ ${hr.bpm}';
    return DeckScaffold(
      title: 'MES OBJETS',
      subtitle: 'sangle / brassard · GATT 0x180D · pas de montre',
      leading: TextButton(
        onPressed: () => context.go(AppRoutes.homeRower),
        child: const Text('Retour'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: DeckStatusChip(
              label: heart,
              ok: _linkOk && hr != null,
              alert: _denied || !_linkOk,
            ),
          ),
          if (_denied)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Bluetooth refusé. Le GPS continue. FC indisponible.',
                style: TextStyle(color: DeckColors.amber, height: 1.4),
              ),
            ),
          const SizedBox(height: 16),
          if (_list.isEmpty)
            const Text(
              'Scanner une sangle pectorale (Heart Rate 0x180D).',
              style: TextStyle(color: DeckColors.muted, height: 1.4),
            ),
          for (final d in _list)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(d.name),
              subtitle: Text(
                [
                  if (d.isPrimary) 'primaire',
                  d.type.name,
                  if (d.bleId != null) d.bleId!,
                ].join(' · '),
              ),
              trailing: d.lastBattery == null ? null : Text('${d.lastBattery} %'),
              onTap: rower == null || d.bleId == null
                  ? null
                  : () async {
                      await ref.read(deviceStoreProvider).upsert(
                            ConnectedDevice(
                              id: d.id,
                              rowerId: d.rowerId,
                              type: d.type,
                              name: d.name,
                              bleId: d.bleId,
                              isPrimary: true,
                              pairedAt: d.pairedAt,
                              lastSeenAt: DateTime.now().toUtc(),
                              lastBattery: d.lastBattery,
                            ),
                          );
                      await _reload();
                      await _connect(d.bleId!);
                    },
            ),
          if (_hits.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'TROUVÉS',
              style: TextStyle(
                color: DeckColors.label,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
            ),
            for (final h in _hits)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(h.name),
                subtitle: Text('RSSI ${h.rssi} dBm'),
                trailing: const Text('APPAIRER'),
                onTap: rower == null ? null : () => _pair(h),
              ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: rower == null || _scanning ? null : _scan,
            child: Text(_scanning ? 'SCAN…' : 'SCANNER'),
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
