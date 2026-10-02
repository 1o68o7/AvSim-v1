import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../identity/controller.dart';
import '../../identity/format.dart';
import '../../identity/models.dart';
import '../../identity/patch_sync.dart';
import '../../onboarding/routing.dart';
import '../../ops/controller.dart';
import '../../router.dart';
import '../../session/boat_config.dart';
import '../../session/live_hub.dart';
import '../../session/model.dart';
import '../../session/rower_orientation.dart';
import '../../session/store.dart';
import '../../session/summary.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import '../../widgets/deck_widgets.dart';
import '../../widgets/mode_banner.dart';

/// DR-54 — Au quai (Stitch).
class QuaiScreen extends ConsumerStatefulWidget {
  const QuaiScreen({super.key});

  @override
  ConsumerState<QuaiScreen> createState() => _QuaiScreenState();
}

class _QuaiScreenState extends ConsumerState<QuaiScreen> {
  SessionSummary? _summary;
  SessionMeta? _meta;
  List<SessionSample> _samples = const [];
  String? _jsonlPath;
  String? _metaPath;
  String _chip = 'en attente réseau';
  PatchSyncStatus _patchSync = PatchSyncStatus.idle;
  bool _showAllSplits = false;

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
            _samples = samples;
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
      ShareParams(
        files: files,
        text: 'DataR0w séance (samples.jsonl + meta.json)',
      ),
    );
  }

  static String _split500FromSog(double? sog) {
    if (sog == null || sog <= 0.05) return '—';
    final sec = 500 / sog;
    final m = sec ~/ 60;
    final s = sec - m * 60;
    return '$m:${s.toStringAsFixed(1).padLeft(4, '0')}';
  }

  static String _fmtDurationFr(Duration d) {
    if (d.inHours > 0) {
      final m = d.inMinutes.remainder(60);
      final s = d.inSeconds.remainder(60);
      return '${d.inHours} h ${m.toString().padLeft(2, '0')} min ${s.toString().padLeft(2, '0')} s';
    }
    return '${d.inMinutes} min ${d.inSeconds.remainder(60).toString().padLeft(2, '0')} s';
  }

  static String _dayLabel(String? iso) {
    if (iso == null || iso.isEmpty) return 'Séance';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return 'Séance';
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    if (sameDay) return 'Aujourd’hui, $hh:$mm';
    return '${formatSessionDay(iso)}, $hh:$mm';
  }

  List<_SplitRow> _computeSplits() {
    if (_samples.isEmpty) return const [];
    final out = <_SplitRow>[];
    var next = 500.0;
    SessionSample? start = _samples.first;
    var tour = 1;
    for (final s in _samples) {
      if (s.distM < next) continue;
      final dtMs = s.t - (start?.t ?? s.t);
      final dd = s.distM - (start?.distM ?? 0);
      final sog = dtMs > 0 ? dd / (dtMs / 1000.0) : null;
      final cads = _samples
          .where((x) => x.t >= (start?.t ?? 0) && x.t <= s.t && x.cadenceSpm != null)
          .map((x) => x.cadenceSpm!)
          .toList();
      final hrs = _samples
          .where((x) => x.t >= (start?.t ?? 0) && x.t <= s.t && x.hrBpm != null)
          .map((x) => x.hrBpm!)
          .toList();
      out.add(_SplitRow(
        index: tour,
        fromM: (next - 500).round(),
        toM: next.round(),
        pace: _split500FromSog(sog),
        cadence: cads.isEmpty ? null : cads.reduce((a, b) => a + b) / cads.length,
        hr: hrs.isEmpty ? null : (hrs.reduce((a, b) => a + b) / hrs.length).round(),
      ));
      tour++;
      next += 500;
      start = s;
      if (out.length >= 40) break;
    }
    return out;
  }

  double? _meanSog() {
    final sogs = _samples.map((s) => s.sog).whereType<double>().where((v) => v > 0.05);
    if (sogs.isEmpty) return null;
    return sogs.reduce((a, b) => a + b) / sogs.length;
  }

  double? _peakGite() {
    final g = _samples.map((s) => s.giteDeg).whereType<double>();
    if (g.isEmpty) return null;
    return g.reduce((a, b) => a.abs() >= b.abs() ? a : b);
  }

  int? _meanHr() {
    final hrs = _samples.map((s) => s.hrBpm).whereType<int>();
    if (hrs.isEmpty) return null;
    return (hrs.reduce((a, b) => a + b) / hrs.length).round();
  }

  int? _maxHr() {
    final hrs = _samples.map((s) => s.hrBpm).whereType<int>();
    if (hrs.isEmpty) return null;
    return hrs.reduce(math.max);
  }

  double? _peakCadence() {
    final c = _samples.map((s) => s.cadenceSpm).whereType<double>();
    if (c.isEmpty) return null;
    return c.reduce(math.max);
  }

  int _sensorCount() {
    var n = 0;
    if (_samples.any((s) => s.lat != null)) n++;
    if (_samples.any((s) => s.giteDeg != null)) n++;
    if (_samples.any((s) => s.cadenceSpm != null)) n++;
    if (_samples.any((s) => s.hrBpm != null)) n++;
    return n;
  }

  static double? _paceSeconds(String pace) {
    if (pace == '—' || !pace.contains(':')) return null;
    final parts = pace.split(':');
    if (parts.length != 2) return null;
    final m = int.tryParse(parts[0]);
    final s = double.tryParse(parts[1]);
    if (m == null || s == null) return null;
    return m * 60 + s;
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
    final splits = _computeSplits();
    final meanSog = _meanSog();
    final peakGite = _peakGite();
    final meanHr = _meanHr();
    final maxHr = _maxHr();
    final peakCad = _peakCadence();
    final boatLabel = _meta?.classe ?? boat.classe;
    final visibleSplits = _showAllSplits ? splits : splits.take(5).toList();
    final fastest = splits.isEmpty
        ? null
        : splits.reduce((a, b) {
            final ap = _paceSeconds(a.pace);
            final bp = _paceSeconds(b.pace);
            if (ap == null) return b;
            if (bp == null) return a;
            return ap <= bp ? a : b;
          });
    final waiting = _chip.contains('attente');

    return DeckScaffold(
      title: 'Au quai',
      subtitle: 'Télémétrie deck · #$sessionTag',
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                if (boat.sessionMode == SessionMode.competition)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: CompetitionBanner(),
                  ),
                _StatusBanner(
                  chip: _chip,
                  waiting: waiting,
                  dayLabel: _dayLabel(_meta?.startedAt),
                  location: _meta?.bassin ?? boat.bassin,
                  boatLabel: boatLabel,
                  isCox: isCox,
                  assignment: asg,
                  meta: _meta,
                  patchSync: _patchSync,
                ),
                _HeroDistance(distM: s?.distM, duration: s?.duration, formatDuration: _fmtDurationFr),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _LakeMomento(distM: s?.distM),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _TelemetryGrid(
                    meanPace: _split500FromSog(meanSog),
                    fastest: fastest,
                    cadenceMean: s?.cadenceMean,
                    peakCadence: peakCad,
                    meanHr: meanHr,
                    maxHr: maxHr,
                    peakGite: peakGite,
                    giteRms: s?.giteRms,
                    sensorCount: _sensorCount(),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SplitsTable(
                    splits: visibleSplits,
                    fastestIndex: fastest?.index,
                    total: splits.length,
                    expanded: _showAllSplits,
                    onToggle: splits.length > 5
                        ? () => setState(() => _showAllSplits = !_showAllSplits)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _PatchCard(
                    status: _patchSync,
                    onImport: _patchSync == PatchSyncStatus.pending ? null : _importPatch,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _DockedBanner(boatLabel: boatLabel, sessionTag: sessionTag),
                ),
                if (showCheckIn) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton(
                      onPressed: () async {
                        final choice = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: DeckColors.surface,
                            title: const Text('Rentrer la coque ?'),
                            content: const Text('Les pelles sont-elles toutes rentrées ?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Pelles manquantes')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pelles OK')),
                            ],
                          ),
                        );
                        if (choice == null || !mounted) return;
                        await ref.read(opsProvider.notifier).checkIn(outId: activeOut.id, oarsOk: choice);
                      },
                      child: const Text('Rentrer la coque'),
                    ),
                  ),
                ],
                if (code != null && code.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextButton(
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
                  ),
                ],
                const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          _QuaiFooter(
            onHome: () {
              final role = ref.read(identityProvider).prefs.clubRole;
              context.go(homeRouteForClubMemberRole(role));
            },
            onReplay: () {
              final id = _meta?.id;
              context.go(
                id == null || id.isEmpty
                    ? AppRoutes.rowerReplay
                    : '${AppRoutes.rowerReplay}?id=${Uri.encodeQueryComponent(id)}',
              );
            },
            onShare: _jsonlPath == null ? null : _share,
          ),
        ],
      ),
    );
  }
}

class _SplitRow {
  const _SplitRow({
    required this.index,
    required this.fromM,
    required this.toM,
    required this.pace,
    required this.cadence,
    required this.hr,
  });
  final int index;
  final int fromM;
  final int toM;
  final String pace;
  final double? cadence;
  final int? hr;
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.chip,
    required this.waiting,
    required this.dayLabel,
    required this.location,
    required this.boatLabel,
    required this.isCox,
    required this.assignment,
    required this.meta,
    required this.patchSync,
  });
  final String chip;
  final bool waiting;
  final String dayLabel;
  final String location;
  final String boatLabel;
  final bool isCox;
  final Assignment? assignment;
  final SessionMeta? meta;
  final PatchSyncStatus patchSync;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1C1B1B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF93000A),
                        borderRadius: DeckRadii.chipAll,
                      ),
                      child: Text(
                        'Enregistrement terminé',
                        style: DeckType.labelMono(color: const Color(0xFFFFDAD6), size: 10),
                      ),
                    ),
                    DeckHonestChip(
                      kind: waiting ? DeckHonestKind.enFile : DeckHonestKind.local,
                      label: waiting ? 'Local · en file cloud' : 'Local',
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sensors, size: 14, color: DeckColors.label.withValues(alpha: 0.9)),
                  const SizedBox(width: 4),
                  Text(chip, style: DeckType.labelMono(size: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayLabel,
                      style: const TextStyle(
                        fontFamily: DeckType.ui,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: DeckColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: DeckColors.label),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$location · $boatLabel',
                            style: const TextStyle(
                              fontFamily: DeckType.ui,
                              fontSize: 12,
                              color: DeckColors.label,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (isCox) const DeckStatusChip(label: 'séance barreur', ok: true),
                  if (assignment != null)
                    DeckStatusChip(label: assignmentChip(assignment!), ok: true)
                  else if (meta?.seatIndex != null && meta?.side != null)
                    DeckStatusChip(
                      label: 'siège ${meta!.seatIndex} / ${meta!.side}',
                      ok: true,
                    ),
                  DeckStatusChip(
                    label: switch (patchSync) {
                      PatchSyncStatus.ok => 'sync OK',
                      PatchSyncStatus.pending => 'en attente sync patch',
                      PatchSyncStatus.idle => 'en attente sync patch',
                    },
                    ok: patchSync == PatchSyncStatus.ok,
                    alert: patchSync != PatchSyncStatus.ok,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroDistance extends StatelessWidget {
  const _HeroDistance({
    required this.distM,
    required this.duration,
    required this.formatDuration,
  });
  final double? distM;
  final Duration? duration;
  final String Function(Duration) formatDuration;

  @override
  Widget build(BuildContext context) {
    final meters = distM;
    final value = meters == null
        ? '—'
        : meters.toStringAsFixed(0).replaceAllMapped(
              RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
              (m) => '${m[1]} ',
            );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        children: [
          Text('Distance totale naviguée', style: DeckType.uiLabel(size: 13)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: DeckType.metric(size: 48, weight: FontWeight.w700)),
              const SizedBox(width: 4),
              Text('m', style: DeckType.metric(size: 20, color: DeckColors.volt)),
            ],
          ),
          if (duration != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: DeckColors.surfaceHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, size: 16, color: DeckColors.tribord),
                  const SizedBox(width: 6),
                  Text('Durée d’effort', style: DeckType.labelMono(size: 10)),
                  const SizedBox(width: 8),
                  Text(formatDuration(duration!), style: DeckType.metric(size: 14)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LakeMomento extends StatelessWidget {
  const _LakeMomento({required this.distM});
  final double? distM;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: DeckRadii.cardAll,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A2228), Color(0xFF0E0E0E)],
        ),
        border: Border.all(color: DeckColors.hairline),
      ),
      padding: const EdgeInsets.all(12),
      alignment: Alignment.bottomLeft,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: DeckColors.bg.withValues(alpha: 0.8),
              borderRadius: DeckRadii.chipAll,
            ),
            child: Text(
              distM == null || distM! <= 0 ? 'Aucune trace GPS' : 'Trace validée',
              style: DeckType.labelMono(color: DeckColors.text, size: 10),
            ),
          ),
          const Spacer(),
          const Icon(Icons.water, size: 14, color: DeckColors.tribord),
          const SizedBox(width: 4),
          Text('Assiette session', style: DeckType.metric(size: 12, color: DeckColors.tribord)),
        ],
      ),
    );
  }
}

class _TelemetryGrid extends StatelessWidget {
  const _TelemetryGrid({
    required this.meanPace,
    required this.fastest,
    required this.cadenceMean,
    required this.peakCadence,
    required this.meanHr,
    required this.maxHr,
    required this.peakGite,
    required this.giteRms,
    required this.sensorCount,
  });
  final String meanPace;
  final _SplitRow? fastest;
  final double? cadenceMean;
  final double? peakCadence;
  final int? meanHr;
  final int? maxHr;
  final double? peakGite;
  final double? giteRms;
  final int sensorCount;

  @override
  Widget build(BuildContext context) {
    final peakLabel = peakGite == null
        ? '—'
        : '${peakGite! >= 0 ? '+' : ''}${peakGite!.toStringAsFixed(1)}° ${peakGite! >= 0 ? 'tribord' : 'bâbord'}';
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Télémétrie de bord',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DeckType.uiLabel(size: 13),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$sensorCount capteurs synchronisés',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: DeckType.labelMono(size: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Allure moy.',
                unit: '/500m',
                value: meanPace,
                footnote: fastest == null ? null : 'Meilleur T${fastest!.index} ${fastest!.pace}',
                footnoteGreen: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                label: '500m max',
                unit: fastest == null ? null : 'T${fastest!.index}',
                unitVolt: true,
                value: fastest?.pace ?? '—',
                valueVolt: true,
                footnote: fastest == null ? 'Pas encore 500 m' : '${fastest!.fromM}–${fastest!.toM} m',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Cadence moy.',
                unit: 'spm',
                value: cadenceMean?.toStringAsFixed(0) ?? '—',
                footnote: peakCadence == null
                    ? 'Cadence non mesurée'
                    : 'Pic : ${peakCadence!.toStringAsFixed(0)} spm',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                label: 'FC moyenne',
                icon: Icons.favorite,
                iconColor: DeckColors.babord,
                value: meanHr?.toString() ?? '—',
                unit: 'bpm',
                footnote: maxHr == null ? 'Pas de cardio' : 'Max $maxHr',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DeckColors.surface,
            borderRadius: DeckRadii.cardAll,
            border: Border.all(color: DeckColors.hairline),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Gîte maximale observée',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DeckType.uiLabel(color: DeckColors.label),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      peakLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: DeckType.labelMono(color: DeckColors.tribord, size: 11, weight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _HeelStrip(peak: peakGite),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('Gîte RMS : ${giteRms?.toStringAsFixed(1) ?? '—'}°', style: DeckType.labelMono(size: 10)),
                  const Spacer(),
                  Text('Assiette : samples IMU', style: DeckType.labelMono(size: 10)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.unit,
    this.unitVolt = false,
    this.valueVolt = false,
    this.footnote,
    this.footnoteGreen = false,
    this.icon,
    this.iconColor,
  });
  final String label;
  final String value;
  final String? unit;
  final bool unitVolt;
  final bool valueVolt;
  final String? footnote;
  final bool footnoteGreen;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
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
              Expanded(child: Text(label, style: DeckType.uiLabel(color: DeckColors.label))),
              if (icon != null)
                Icon(icon, size: 14, color: iconColor ?? DeckColors.label)
              else if (unit != null)
                Text(
                  unit!,
                  style: DeckType.labelMono(
                    color: unitVolt ? DeckColors.volt : DeckColors.label,
                    size: 10,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: DeckType.metric(size: 28, color: valueVolt ? DeckColors.volt : DeckColors.text),
          ),
          if (unit != null && icon != null) Text(unit!, style: DeckType.labelMono(size: 11)),
          if (footnote != null) ...[
            const SizedBox(height: 4),
            Text(
              footnote!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DeckType.labelMono(
                color: footnoteGreen ? DeckColors.tribord : DeckColors.label,
                size: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeelStrip extends StatelessWidget {
  const _HeelStrip({required this.peak});
  final double? peak;

  @override
  Widget build(BuildContext context) {
    final v = (peak ?? 0).clamp(-15.0, 15.0);
    final frac = 0.5 + (v / 30.0);
    return SizedBox(
      height: 12,
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 4),
                  color: DeckColors.babord.withValues(alpha: 0.2),
                  child: Text('BÂBORD', style: DeckType.labelMono(color: DeckColors.babord, size: 8)),
                ),
              ),
              Expanded(
                child: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 4),
                  color: DeckColors.tribord.withValues(alpha: 0.2),
                  child: Text('TRIBORD', style: DeckType.labelMono(color: DeckColors.tribord, size: 8)),
                ),
              ),
            ],
          ),
          Align(alignment: Alignment.center, child: Container(width: 2, color: DeckColors.text)),
          if (peak != null)
            Align(
              alignment: Alignment((frac * 2) - 1, 0),
              child: Container(
                width: 10,
                height: 12,
                decoration: BoxDecoration(
                  color: v >= 0 ? DeckColors.tribord : DeckColors.babord,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SplitsTable extends StatelessWidget {
  const _SplitsTable({
    required this.splits,
    required this.fastestIndex,
    required this.total,
    required this.expanded,
    required this.onToggle,
  });
  final List<_SplitRow> splits;
  final int? fastestIndex;
  final int total;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text('Tableau des tours (500 m)', style: DeckType.uiLabel(size: 13)),
            const Spacer(),
            Text(total == 0 ? 'Aucun intervalle' : '$total intervalles', style: DeckType.labelMono(size: 10)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: DeckColors.surface,
            borderRadius: DeckRadii.cardAll,
            border: Border.all(color: DeckColors.hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                color: DeckColors.surfaceHighest,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(width: 64, child: Text('Intervalle', style: DeckType.labelMono(size: 10))),
                    Expanded(child: Text('Allure', textAlign: TextAlign.center, style: DeckType.labelMono(size: 10))),
                    Expanded(child: Text('Cadence', textAlign: TextAlign.center, style: DeckType.labelMono(size: 10))),
                    SizedBox(width: 64, child: Text('FC moy', textAlign: TextAlign.right, style: DeckType.labelMono(size: 10))),
                  ],
                ),
              ),
              if (splits.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Pas encore 500 m de trace GPS.', style: DeckType.labelMono(size: 11)),
                )
              else
                for (var i = 0; i < splits.length; i++)
                  _SplitTile(row: splits[i], highlight: splits[i].index == fastestIndex, alt: i.isOdd),
            ],
          ),
        ),
        if (onToggle != null) ...[
          const SizedBox(height: 8),
          Material(
            color: const Color(0xFF1C1B1B),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      expanded
                          ? 'Réduire les splits'
                          : 'Afficher les ${total - splits.length} autres splits',
                      style: DeckType.labelMono(size: 11),
                    ),
                    Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 16, color: DeckColors.label),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SplitTile extends StatelessWidget {
  const _SplitTile({required this.row, required this.highlight, required this.alt});
  final _SplitRow row;
  final bool highlight;
  final bool alt;

  @override
  Widget build(BuildContext context) {
    final fg = highlight ? DeckColors.volt : DeckColors.text;
    return Container(
      color: highlight
          ? DeckColors.surfaceHighest
          : (alt ? const Color(0xFF1C1B1B) : DeckColors.surface),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'T${row.index}',
                      style: DeckType.metric(
                        size: 14,
                        color: fg,
                        weight: highlight ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    if (highlight) ...[
                      const SizedBox(width: 2),
                      const Icon(Icons.bolt, size: 13, color: DeckColors.volt),
                    ],
                  ],
                ),
                Text(
                  '${row.fromM}–${row.toM} m',
                  style: DeckType.labelMono(
                    color: highlight ? DeckColors.volt : DeckColors.label,
                    size: 9,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              row.pace,
              textAlign: TextAlign.center,
              style: DeckType.metric(size: 14, color: fg, weight: highlight ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              row.cadence == null ? '—' : '${row.cadence!.toStringAsFixed(0)} spm',
              textAlign: TextAlign.center,
              style: DeckType.metric(size: 14, color: fg),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              row.hr == null ? '—' : '${row.hr} bpm',
              textAlign: TextAlign.right,
              style: DeckType.metric(size: 14, color: highlight ? DeckColors.volt : DeckColors.label),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatchCard extends StatelessWidget {
  const _PatchCard({required this.status, required this.onImport});
  final PatchSyncStatus status;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: DeckRadii.cardAll,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.developer_board, size: 18, color: DeckColors.label),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Patch dorsal cinématique',
                  style: TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: DeckColors.text,
                  ),
                ),
              ),
              const DeckHonestChip(kind: DeckHonestKind.mock, label: 'Mock / démo'),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Patch dorsal — démo (firmware non branché). Les mesures d’angles '
            'vertébraux et de chaîne cinématique sont simulées pour '
            'démonstration d’interface quai.',
            style: TextStyle(
              fontFamily: DeckType.ui,
              fontSize: 12,
              height: 1.35,
              color: DeckColors.label,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                switch (status) {
                  PatchSyncStatus.ok => 'Canal : mock importé',
                  PatchSyncStatus.pending => 'Canal : import…',
                  PatchSyncStatus.idle => 'Canal série : offline',
                },
                style: DeckType.labelMono(size: 10),
              ),
              const Spacer(),
              TextButton(
                onPressed: onImport,
                child: Text(
                  status == PatchSyncStatus.ok ? 'Réimporter patch' : 'Importer patch',
                  style: DeckType.labelMono(color: DeckColors.tribord, size: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DockedBanner extends StatelessWidget {
  const _DockedBanner({required this.boatLabel, required this.sessionTag});
  final String boatLabel;
  final String sessionTag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: DeckRadii.cardAll,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Matériel débâté', style: DeckType.labelMono(color: DeckColors.volt, size: 10)),
                Text(
                  '$boatLabel au ponton',
                  style: const TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: DeckColors.text,
                  ),
                ),
                Text(
                  'Fermeture session #$sessionTag',
                  style: const TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 12,
                    color: DeckColors.label,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: DeckColors.surfaceHighest,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.anchor, size: 20, color: DeckColors.tribord),
          ),
        ],
      ),
    );
  }
}

class _QuaiFooter extends StatelessWidget {
  const _QuaiFooter({
    required this.onHome,
    required this.onReplay,
    required this.onShare,
  });
  final VoidCallback onHome;
  final VoidCallback onReplay;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1B1B),
        border: Border(top: BorderSide(color: DeckColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: DeckColors.volt,
                foregroundColor: DeckColors.onVolt,
                shape: RoundedRectangleBorder(borderRadius: DeckRadii.cardAll),
              ),
              onPressed: onHome,
              icon: const Icon(Icons.check_circle, size: 22),
              label: const Text(
                'Retour à Aujourd’hui',
                style: TextStyle(
                  fontFamily: DeckType.ui,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: DeckColors.surfaceHighest,
                foregroundColor: DeckColors.text,
                shape: RoundedRectangleBorder(borderRadius: DeckRadii.cardAll),
              ),
              onPressed: onReplay,
              icon: const Icon(Icons.play_circle, size: 20),
              label: Text(
                'Revoir la séance (replay GPS)',
                style: DeckType.uiLabel(color: DeckColors.text, weight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.file_download, size: 16),
            label: const Text('Partager l’export local (JSONL)'),
            style: TextButton.styleFrom(foregroundColor: DeckColors.label),
          ),
        ],
      ),
    );
  }
}
