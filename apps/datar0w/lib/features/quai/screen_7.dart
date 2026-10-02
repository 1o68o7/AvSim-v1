import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../identity/controller.dart';
import '../../identity/format.dart';
import '../../identity/models.dart';
import '../../onboarding/routing.dart';
import '../../ops/controller.dart';
import '../../router.dart';
import '../../session/boat_config.dart';
import '../../session/live_hub.dart';
import '../../session/rower_orientation.dart';
import '../../session/store.dart';
import '../../session/summary.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import '../../widgets/deck_widgets.dart';
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

  @override
  void initState() {
    super.initState();
    unawaited(unlockRowerOrientations());
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final hub = ref.read(liveHubProvider);
      final id = hub.sessionId ?? await SessionStore.latestId();
      if (id != null) {
        final samples = await SessionStore.loadSamples(id);
        final meta = await SessionStore.loadMeta(id);
        final dir = hub.sessionDir ??
            '${(await SessionStore.sessionsRoot()).path}/$id';
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
      final ps = await ref.read(patchSyncStoreProvider).status();
      if (mounted) setState(() => _patchSync = ps);
    } catch (_) {
      if (!mounted) return;
      try {
        final ps = await ref.read(patchSyncStoreProvider).status();
        setState(() => _patchSync = ps);
      } catch (_) {}
    }
  }

  Future<void> _importPatch() async {
    setState(() => _patchSync = PatchSyncStatus.pending);
    await ref.read(patchSyncStoreProvider).importMock();
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
      ShareParams(files: files, text: 'DataR0w séance'),
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
    final distKm = s == null ? null : s.distM / 1000;

    return DeckScaffold(
      title: 'Quai',
      subtitle: 'Séance #$sessionTag',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (boat.sessionMode == SessionMode.competition) ...[
            const CompetitionBanner(),
            const SizedBox(height: 12),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DeckColors.surface,
              borderRadius: DeckRadii.cardAll,
              border: Border.all(color: DeckColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Résumé',
                  style: DeckType.uiLabel(
                    color: DeckColors.label,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatClockRange(_meta?.startedAt, _meta?.endedAt),
                  style: DeckType.labelMono(
                    color: DeckColors.muted,
                    size: 11,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Distance',
                            style: DeckType.uiLabel(size: 11),
                          ),
                          const SizedBox(height: 4),
                          Text.rich(
                            TextSpan(
                              style: DeckType.metric(
                                size: 32,
                                weight: FontWeight.w700,
                              ),
                              children: [
                                TextSpan(
                                  text: distKm == null
                                      ? '—'
                                      : distKm.toStringAsFixed(2),
                                ),
                                const TextSpan(
                                  text: ' km',
                                  style: TextStyle(
                                    fontFamily: DeckType.ui,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: DeckColors.label,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Durée',
                          style: DeckType.uiLabel(size: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s == null ? '—' : formatDuration(s.duration),
                          style: DeckType.metric(
                            size: 20,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InstrumentPod(
                  label: 'Cadence',
                  value: s?.cadenceMean == null
                      ? '—'
                      : s!.cadenceMean!.toStringAsFixed(0),
                  unit: 'spm',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InstrumentPod(
                  label: 'Gîte',
                  value: s == null ? '—' : s.giteRms.toStringAsFixed(1),
                  unit: '° rms',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 8,
            runSpacing: 8,
            children: [
              DeckStatusChip(
                label: _chip,
                alert: _chip.contains('attente'),
              ),
              if (isCox) const DeckStatusChip(label: 'barreur', ok: true),
              if (asg != null)
                DeckStatusChip(label: assignmentChip(asg), ok: true)
              else if (_meta?.seatIndex != null && _meta?.side != null)
                DeckStatusChip(
                  label: 'siège ${_meta!.seatIndex}',
                  ok: true,
                ),
              DeckStatusChip(
                label: switch (_patchSync) {
                  PatchSyncStatus.ok => 'sync OK',
                  PatchSyncStatus.pending => 'sync patch',
                  PatchSyncStatus.idle => 'sync patch',
                },
                ok: _patchSync == PatchSyncStatus.ok,
                alert: _patchSync != PatchSyncStatus.ok,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DeckColors.surface,
              borderRadius: DeckRadii.cardAll,
              border: Border.all(color: DeckColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Suite',
                  style: DeckType.uiLabel(
                    color: DeckColors.label,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _jsonlPath == null ? null : _share,
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: const Text('Partager'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final id = _meta?.id;
                      context.go(
                        id == null || id.isEmpty
                            ? AppRoutes.rowerReplay
                            : '${AppRoutes.rowerReplay}?id=${Uri.encodeQueryComponent(id)}',
                      );
                    },
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: const Text('Replay'),
                  ),
                ),
                if (code != null && code.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      final id = _meta?.id;
                      context.go(
                        id == null || id.isEmpty
                            ? AppRoutes.coachReplay
                            : '${AppRoutes.coachReplay}?id=${Uri.encodeQueryComponent(id)}',
                      );
                    },
                    child: const Text('Replay coach'),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _patchSync == PatchSyncStatus.pending
                      ? null
                      : _importPatch,
                  child: const Text('Importer patch'),
                ),
                if (showCheckIn) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final choice = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: DeckColors.surface,
                          title: const Text('Rentrer la coque ?'),
                          content: const Text(
                            'Les pelles sont-elles toutes rentrées ?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Annuler'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Pelles manquantes'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Pelles OK'),
                            ),
                          ],
                        ),
                      );
                      if (choice == null || !mounted) return;
                      await ref.read(opsProvider.notifier).checkIn(
                            outId: activeOut.id,
                            oarsOk: choice,
                          );
                    },
                    child: const Text('Rentrer la coque'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              // IA reshape : hub = rôle de séance (rameur/cox/coach), pas clubRole.
              final role = ref.read(boatConfigProvider).role;
              context.go(sessionRoleHome(role));
            },
            child: const Text('Retour accueil'),
          ),
        ],
      ),
    );
  }
}
