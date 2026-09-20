import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../identity/controller.dart';
import 'layout_model.dart';
import 'layout_store.dart';

final layoutStoreProvider = Provider<LayoutStore>((ref) => LayoutStore());

class LayoutController extends Notifier<RowerLayout> {
  @override
  RowerLayout build() {
    Future<void>.microtask(_reload);
    return RowerLayout.security(_id);
  }

  String get _id =>
      ref.read(identityProvider).activeRower?.id ?? 'anon';

  Future<void> _reload() async {
    state = await ref.read(layoutStoreProvider).load(_id);
  }

  Future<void> cycle() async {
    const order = [
      LivePreset.securite,
      LivePreset.performance,
      LivePreset.cardio,
      LivePreset.navigation,
      LivePreset.complet,
    ];
    final i = order.indexOf(state.preset);
    final next = order[(i + 1) % order.length];
    await setPreset(next);
  }

  Future<void> setPreset(LivePreset p) async {
    final layout = state.withPreset(p);
    await ref.read(layoutStoreProvider).save(layout);
    state = layout;
  }

  Future<void> setMapEnabled(bool v) async {
    final layout = RowerLayout(
      rowerId: state.rowerId,
      preset: state.preset,
      blocks: state.blocks,
      mapEnabled: v,
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(layoutStoreProvider).save(layout);
    state = layout;
  }
}

final liveLayoutProvider =
    NotifierProvider<LayoutController, RowerLayout>(LayoutController.new);
