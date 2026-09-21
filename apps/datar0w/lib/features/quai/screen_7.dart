import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../identity/controller.dart';
import '../../identity/format.dart';
import '../../identity/models.dart';
import '../../ops/controller.dart';
import '../../router.dart';
import '../../session/boat_config.dart';
import '../../session/live_hub.dart';
import '../../session/rower_orientation.dart';
import '../../session/store.dart';
import '../../session/summary.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import '../../identity/patch_sync.dart';
import '../../widgets/mode_banner.dart';

class QuaiScreen extends ConsumerStatefulWidget {
  const QuaiScreen({super.key});

  @override
  ConsumerState<QuaiScreen> createState() => _QuaiScreenState();
}

class _QuaiScreenState extends ConsumerState<QuaiScreen> {
  SessionSummary? _summary;
  SessionMeta? _meta;
  String? _jsonlPath;
  String? _metaPath;
  String _chip = 'en attente réseau';
  PatchSyncStatus _patchSync = PatchSyncStatus.idle;
  final _patchStore = PatchSyncStore();

  @override
  void initState() {
    super.initState();
    unawaited(unlockRowerOrientations());
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final hub = ref.read(liveHubProvider);
    final id = hub.sessionId ?? await SessionStore.latestId();
    if (id != null) {
      final samples = await SessionStore.loadSamples(id);
      final meta = await SessionStore.loadMeta(id);
      final dir = hub.sessionDir ?? '${(await SessionStore.sessionsRoot()).path}/$id';
      if (mounted) {
        setState(() {
          _summary = SessionSummary.fromSamples(samples);
          _meta = meta;
          _jsonlPath = '$dir/samples.jsonl';
          _metaPath = '$dir/meta.json';
          _chip = hub.net == 'hors ligne' ? 'en attente réseau' : hub.net;
        });
      }
    }
    final ps = await _patchStore.status();
    if (mounted) setState(() => _patchSync = ps);
  }

  Future<void> _importPatch() async {
    setState(() => _patchSync = PatchSyncStatus.pending);
    await _patchStore.importMock();
    if (!mounted) return;
    setState(() => _patchSync = PatchSyncStatus.ok);
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
    final sessionTag = _meta?.code ?? _meta?.id ?? '—';
    final boat = ref.watch(boatConfigProvider);
    final ident = ref.watch(identityProvider);
    Assignment? asg;
    final aid = _meta?.assignmentId;
    if (aid != null) {
      for (final a in ident.assignments) {
        if (a.id == aid) asg = a;
      }
    }
    final isCox = _meta?.role == 'cox' || boat.role == CrewRole.cox;
    final code = _meta?.code?.trim();
    final ops = ref.watch(opsProvider);
    final hullId = _meta?.boatId ?? asg?.boatId;
    final activeOut = hullId == null ? null : ops.activeForBoat(hullId);
    final showCheckIn = boat.role == CrewRole.coach && activeOut != null;
    return DeckScaffold(
      title: 'QUAI',
      subtitle: 'SESSION #$sessionTag',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (boat.sessionMode == SessionMode.competition) ...[
              const CompetitionBanner(),
              const SizedBox(height: 12),
            ],
            const Text(
              'RÉSUMÉ D\'ACTIVITÉ',
              style: TextStyle(
                color: DeckColors.amber,
                letterSpacing: 1.4,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              formatClockRange(_meta?.startedAt, _meta?.endedAt),
              style: const TextStyle(color: DeckColors.muted, fontSize: 10),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  InstrumentPod(
                    label: 'DURÉE',
                    value: s == null ? '—' : formatDuration(s.duration),
                    unit: 'MIN',
                  ),
                  InstrumentPod(
                    label: 'DISTANCE GPS',
                    value: s == null ? '—' : (s.distM / 1000).toStringAsFixed(2),
                    unit: 'KM',
                  ),
                  InstrumentPod(
                    label: 'CADENCE MOYENNE',
                    value: s?.cadenceMean == null
                        ? '—'
                        : s!.cadenceMean!.toStringAsFixed(0),
                    unit: 'SPM',
                  ),
                  InstrumentPod(
                    label: 'GÎTE RMS',
                    value: s == null ? '—' : s.giteRms.toStringAsFixed(1),
                    unit: 'DEGRÉS (°)',
                  ),
                ],
              ),
            ),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  DeckStatusChip(
                    label: _chip,
                    alert: _chip.contains('attente'),
                  ),
                  if (isCox)
                    const DeckStatusChip(label: 'séance barreur', ok: true),
                  if (asg != null)
                    DeckStatusChip(label: assignmentChip(asg), ok: true)
                  else if (_meta?.seatIndex != null && _meta?.side != null)
                    DeckStatusChip(
                      label: 'siège ${_meta!.seatIndex} / ${_meta!.side}',
                      ok: true,
                    ),
                  DeckStatusChip(
                    label: switch (_patchSync) {
                      PatchSyncStatus.ok => 'sync OK',
                      PatchSyncStatus.pending => 'en attente sync patch',
                      PatchSyncStatus.idle => 'en attente sync patch',
                    },
                    ok: _patchSync == PatchSyncStatus.ok,
                    alert: _patchSync != PatchSyncStatus.ok,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go(AppRoutes.rowerReplay),
              child: const Text('REPLAY'),
            ),
            if (code != null && code.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go(AppRoutes.coachReplay),
                child: const Text('Replay coach'),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _share,
              child: const Text('PARTAGER AU COACH'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _patchSync == PatchSyncStatus.pending
                  ? null
                  : _importPatch,
              child: const Text('IMPORTER PATCH'),
            ),
            if (showCheckIn) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  await ref.read(opsProvider.notifier).checkIn(
                        outId: activeOut.id,
                        oarsOk: true,
                      );
                },
                child: const Text('RENTRER LA COQUE ?'),
              ),
            ],
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
}
