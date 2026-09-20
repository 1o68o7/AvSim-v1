import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../identity/device_store.dart';
import '../../identity/devices.dart';
import '../../identity/id.dart';
import '../../router.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  List<ConnectedDevice> _list = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final all = await DeviceStore().list();
    final id = ref.read(identityProvider).activeRower?.id;
    setState(() {
      _list = id == null ? all : all.where((d) => d.rowerId == id).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rower = ref.watch(identityProvider).activeRower;
    return DeckScaffold(
      title: 'MES OBJETS',
      subtitle: 'sangle / brassard · pas de montre',
      leading: TextButton(
        onPressed: () => context.go(AppRoutes.homeRower),
        child: const Text('Retour'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (_list.isEmpty)
            const Text(
              'Connecte une sangle pectorale pour débloquer la FC.',
              style: TextStyle(color: DeckColors.muted, height: 1.4),
            ),
          for (final d in _list)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(d.name),
              subtitle: Text(
                d.isPrimary ? 'primaire' : d.type.name,
              ),
              trailing: d.lastBattery == null ? null : Text('${d.lastBattery} %'),
              onTap: rower == null
                  ? null
                  : () async {
                      await DeviceStore().upsert(
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
                    },
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: rower == null
                ? null
                : () async {
                    await DeviceStore().upsert(
                      ConnectedDevice(
                        id: newIdentityId(),
                        rowerId: rower.id,
                        type: DeviceType.chestStrap,
                        name: 'Sangle ${_list.length + 1}',
                        isPrimary: _list.isEmpty,
                        pairedAt: DateTime.now().toUtc(),
                      ),
                    );
                    await _reload();
                  },
            child: const Text('+ CONNECTER UN APPAREIL'),
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
