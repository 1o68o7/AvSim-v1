import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'identity/controller.dart';
import 'router.dart';
import 'sync/config.dart';
import 'sync/providers.dart';
import 'sync/sync_engine.dart';
import 'theme/deck_theme.dart';

class DataR0wApp extends ConsumerStatefulWidget {
  const DataR0wApp({super.key});

  @override
  ConsumerState<DataR0wApp> createState() => _DataR0wAppState();
}

class _DataR0wAppState extends ConsumerState<DataR0wApp> {
  StreamSubscription<List<ConnectivityResult>>? _net;

  @override
  void initState() {
    super.initState();
    _net = Connectivity().onConnectivityChanged.listen((results) {
      unawaited(_onNet(results));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final now = await Connectivity().checkConnectivity();
      await _onNet(now);
    });
  }

  Future<void> _onNet(List<ConnectivityResult> results) async {
    final online = results.any((e) => e != ConnectivityResult.none);
    if (!SyncConfig.enabled) {
      ref.read(syncHudProvider.notifier).setStatus(
            SyncStatus(online: online),
          );
      return;
    }
    final store = ref.read(identityStoreProvider);
    final engine = SyncEngine(
      store: store,
      outbox: await store.outbox(),
      cloud: ref.read(identityCloudProvider),
    );
    if (online) {
      try {
        await engine.tick();
      } catch (_) {}
    }
    if (!mounted) return;
    ref.read(syncHudProvider.notifier).setStatus(
          await engine.status(online: online),
        );
  }

  @override
  void dispose() {
    _net?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DataR0w',
      debugShowCheckedModeBanner: false,
      theme: buildDeckTheme(),
      routerConfig: appRouter,
    );
  }
}
