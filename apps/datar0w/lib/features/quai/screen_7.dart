import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../router.dart';
import '../../session/live_hub.dart';
import '../../session/rower_orientation.dart';
import '../../session/store.dart';
import '../../session/summary.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

class QuaiScreen extends ConsumerStatefulWidget {
  const QuaiScreen({super.key});

  @override
  ConsumerState<QuaiScreen> createState() => _QuaiScreenState();
}

class _QuaiScreenState extends ConsumerState<QuaiScreen> {
  SessionSummary? _summary;
  String? _jsonlPath;
  String? _metaPath;
  String _chip = 'en attente réseau';

  @override
  void initState() {
    super.initState();
    unawaited(unlockRowerOrientations());
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final hub = ref.read(liveHubProvider);
    final id = hub.sessionId ?? await SessionStore.latestId();
    if (id == null) return;
    final samples = await SessionStore.loadSamples(id);
    final dir = hub.sessionDir ?? '${(await SessionStore.sessionsRoot()).path}/$id';
    if (!mounted) return;
    setState(() {
      _summary = SessionSummary.fromSamples(samples);
      _jsonlPath = '$dir/samples.jsonl';
      _metaPath = '$dir/meta.json';
      _chip = hub.net == 'hors ligne' ? 'en attente réseau' : hub.net;
    });
  }

  Future<void> _share() async {
    final jsonl = _jsonlPath;
    final meta = _metaPath;
    if (jsonl == null) return;
    final files = [XFile(jsonl)];
    if (meta != null) files.add(XFile(meta));
    await SharePlus.instance.share(
      ShareParams(files: files, text: 'DataR0w séance (samples.jsonl + meta.json)'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return DeckScaffold(
      title: 'QUAI',
      subtitle: 'fin de séance',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'RÉSUMÉ D\'ACTIVITÉ',
              style: TextStyle(
                color: DeckColors.amber,
                letterSpacing: 1.4,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _tile(
                    'DURÉE',
                    s == null ? '—' : formatDuration(s.duration),
                    'MIN',
                  ),
                  _tile(
                    'DISTANCE GPS',
                    s == null ? '—' : (s.distM / 1000).toStringAsFixed(2),
                    'KM',
                  ),
                  _tile(
                    'CADENCE MOYENNE',
                    s?.cadenceMean == null
                        ? '—'
                        : s!.cadenceMean!.toStringAsFixed(0),
                    'SPM',
                  ),
                  _tile(
                    'GÎTE RMS',
                    s == null ? '—' : s.giteRms.toStringAsFixed(1),
                    'DEGRÉS (°)',
                  ),
                ],
              ),
            ),
            Center(
              child: Text(
                _chip.toUpperCase(),
                style: const TextStyle(color: DeckColors.label, fontSize: 11),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go(AppRoutes.rowerReplay),
              child: const Text('REPLAY'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _share,
              child: const Text('PARTAGER AU COACH'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go(AppRoutes.profile),
              child: const Text('RETOUR ACCUEIL'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: DeckColors.label,
              fontSize: 10,
              letterSpacing: 1.1,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          Text(
            unit,
            style: const TextStyle(color: DeckColors.label, fontSize: 9),
          ),
        ],
      ),
    );
  }
}
