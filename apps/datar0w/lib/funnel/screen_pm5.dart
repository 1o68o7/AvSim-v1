import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/deck_theme.dart';
import 'controller.dart';
import 'pm5_client.dart';

/// DR-FR-P — Connexion PM5, drag factor live (Lot 3).
class FunnelPm5Screen extends ConsumerStatefulWidget {
  const FunnelPm5Screen({super.key});

  @override
  ConsumerState<FunnelPm5Screen> createState() => _FunnelPm5ScreenState();
}

class _FunnelPm5ScreenState extends ConsumerState<FunnelPm5Screen> {
  List<Pm5Hit> _hits = const [];
  StreamSubscription<List<Pm5Hit>>? _hitsSub;
  StreamSubscription<Pm5LiveTick>? _tickSub;
  Pm5LiveTick? _live;
  bool _scanning = false;
  String? _connectingId;

  @override
  void initState() {
    super.initState();
    final client = ref.read(pm5ClientProvider);
    _hitsSub = client.hits.listen((h) {
      if (mounted) setState(() => _hits = h);
    });
    _tickSub = client.ticks.listen((t) {
      if (mounted) setState(() => _live = t);
    });
    _scan();
  }

  @override
  void dispose() {
    _hitsSub?.cancel();
    _tickSub?.cancel();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final client = ref.read(pm5ClientProvider);
    await client.startScan();
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _connect(Pm5Hit hit) async {
    setState(() => _connectingId = hit.id);
    final ok = await ref.read(pm5ClientProvider).connect(hit.id);
    if (!mounted) return;
    setState(() => _connectingId = null);
    if (ok) {
      final df = ref.read(pm5ClientProvider).lastDragFactor;
      if (df != null) {
        final f = ref.read(funnelProvider);
        final piece = f.resolvedPiece;
        ref.read(funnelProvider.notifier).setActivePiece(
              piece: piece,
              dragFactor: df,
            );
      }
    }
  }

  void _continue() {
    context.go(AppRoutes.funnelPlayer);
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(pm5ClientProvider);
    final connected = client.connectedId;

    return Scaffold(
      backgroundColor: DeckColors.bg,
      appBar: AppBar(
        backgroundColor: DeckColors.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DeckColors.text),
          onPressed: () => context.go(AppRoutes.funnelPreview),
        ),
        title: const Text(
          'PM5',
          style: TextStyle(
            fontFamily: DeckType.ui,
            fontWeight: FontWeight.w600,
            color: DeckColors.text,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _scanning ? null : _scan,
            child: Text(
              _scanning ? 'Scan…' : 'Rescan',
              style: const TextStyle(color: DeckColors.muted),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Drag factor live depuis le moniteur',
                style: const TextStyle(
                  fontFamily: DeckType.ui,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: DeckColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sans PM5 : saisie manuelle au Stop.',
                style: DeckType.uiLabel(color: DeckColors.label),
              ),
              const SizedBox(height: 16),
              if (connected != null && _live != null)
                Container(
                  key: const Key('funnel-pm5-connected'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: DeckColors.surface,
                    borderRadius: DeckRadii.cardAll,
                    border: Border.all(color: DeckColors.volt),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Relié · DF ${_live!.dragFactor}',
                        style: const TextStyle(
                          fontFamily: DeckType.ui,
                          fontWeight: FontWeight.w700,
                          color: DeckColors.volt,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Split ${_live!.split500S > 0 ? formatLiveSplit(_live!.split500S) : '—'}  ·  '
                        '${_live!.cadence > 0 ? '${_live!.cadence.round()} spm' : '—'}  ·  '
                        '${_live!.watts > 0 ? '${_live!.watts.round()} W' : '—'}',
                        style: DeckType.metric(size: 14),
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _hits.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final hit = _hits[i];
                      final busy = _connectingId == hit.id;
                      return Material(
                        color: DeckColors.surface,
                        borderRadius: DeckRadii.cardAll,
                        child: InkWell(
                          borderRadius: DeckRadii.cardAll,
                          onTap: busy ? null : () => _connect(hit),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: DeckRadii.cardAll,
                              border: Border.all(color: DeckColors.hairline),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hit.name,
                                        style: const TextStyle(
                                          fontFamily: DeckType.ui,
                                          fontWeight: FontWeight.w600,
                                          color: DeckColors.text,
                                        ),
                                      ),
                                      Text(
                                        '${hit.rssi} dBm',
                                        style: DeckType.labelMono(size: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  busy ? '…' : 'Relier',
                                  style: const TextStyle(
                                    fontFamily: DeckType.ui,
                                    color: DeckColors.volt,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (connected != null) const Spacer(),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _continue,
                  child: Text(
                    connected != null
                        ? 'Continuer vers le player'
                        : 'Continuer sans PM5',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String formatLiveSplit(double seconds) {
  final m = seconds.floor() ~/ 60;
  final s = seconds - m * 60;
  return '$m:${s.toStringAsFixed(1).padLeft(4, '0')}';
}
