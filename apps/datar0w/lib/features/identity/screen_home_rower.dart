import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../funnel/controller.dart';
import '../../funnel/models.dart';
import '../../funnel/water_today_card.dart';
import '../../identity/controller.dart';
import '../../identity/format.dart';
import '../../identity/models.dart';
import '../../ops/controller.dart';
import '../../ops/impact_report.dart';
import '../../router.dart';
import '../../session/boat_config.dart';
import '../../session/cadence_backfill.dart';
import '../../session/store.dart';
import '../../session/summary.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_shell.dart';
import '../../widgets/deck_widgets.dart';
import '../identity/screen_home_roles.dart';

/// DR-20 — Aujourd'hui rameur (shell 3 onglets).
class HomeRowerScreen extends ConsumerStatefulWidget {
  const HomeRowerScreen({super.key});

  @override
  ConsumerState<HomeRowerScreen> createState() => _HomeRowerScreenState();
}

class _LastOuting {
  const _LastOuting({
    required this.meta,
    this.duration,
    this.distM,
    this.cadenceLabel = '—',
  });

  final SessionMeta meta;
  final Duration? duration;
  final double? distM;
  /// Médiane high / ~moyenne / — (jamais 0 inventé).
  final String cadenceLabel;
}

class _HomeRowerScreenState extends ConsumerState<HomeRowerScreen> {
  _LastOuting? _last;
  int _sessionCount = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadLast();
  }

  Future<void> _loadLast() async {
    final metas = await SessionStore.listSessions();
    _LastOuting? last;
    if (metas.isNotEmpty) {
      final m = metas.first;
      await CadenceBackfill.maybeBackfill(m.id);
      final samples = await SessionStore.loadSamples(m.id);
      Duration? duration;
      double? distM;
      var cadLabel = '—';
      if (samples.isNotEmpty) {
        final s = SessionSummary.fromSamples(samples);
        duration = s.duration;
        distM = s.distM;
        cadLabel = s.cadenceLabel;
      } else {
        final a = DateTime.tryParse(m.startedAt ?? '');
        final b = DateTime.tryParse(m.endedAt ?? '');
        if (a != null && b != null && !b.isBefore(a)) {
          duration = b.difference(a);
        }
      }
      last = _LastOuting(
        meta: m,
        duration: duration,
        distM: distM,
        cadenceLabel: cadLabel,
      );
    }
    if (!mounted) return;
    setState(() {
      _last = last;
      _sessionCount = metas.length;
      _loaded = true;
    });
  }

  void _continue(BuildContext context) {
    final snap = ref.read(identityProvider);
    final rower = snap.activeRower;
    final asg = rower == null ? null : snap.assignmentForRower(rower.id);
    continueFromAssignment(
      ref,
      role: CrewRole.rower,
      assignment: asg,
      boat: snap.boatById(asg?.boatId),
    );
    context.go(AppRoutes.presession);
  }

  String _paceLabel(_LastOuting o) {
    final d = o.duration;
    final dist = o.distM;
    if (d == null || dist == null || dist <= 0 || d.inMilliseconds <= 0) {
      return '—';
    }
    final sec = d.inMilliseconds / 1000.0 * 500.0 / dist;
    final m = sec ~/ 60;
    final s = (sec % 60).round().clamp(0, 59);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _whenLabel(SessionMeta m) {
    final iso = m.startedAt ?? m.endedAt;
    if (iso == null || iso.isEmpty) return 'Dernière sortie';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return formatSessionDay(iso);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    if (diff == 0) return 'Aujourd\'hui · $hh:$mm';
    if (diff == 1) return 'Hier soir · $hh:$mm';
    return '${formatSessionDay(iso)} · $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final ident = ref.watch(identityProvider);
    final rower = ident.activeRower;
    final asg = rower == null ? null : ident.assignmentForRower(rower.id);
    final boat = ident.boatById(asg?.boatId);
    final club = ident.activeClub;
    final notices = rower == null
        ? const <OpsNotice>[]
        : ref.watch(opsProvider).noticesFor(rower.id);
    final maint = notices.where((n) => n.message.contains('maintenance'));
    final mode = ref.watch(boatConfigProvider).sessionMode;
    final firstName = (rower?.displayName ?? 'rameur').split(' ').first;

    return DeckTabScaffold(
      tab: DeckTab.today,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: DeckColors.bg.withValues(alpha: 0.92),
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 56,
            titleSpacing: 16,
            title: const Text(
              "Aujourd'hui",
              style: TextStyle(
                fontFamily: DeckType.ui,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: DeckColors.text,
                letterSpacing: -0.2,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Profil',
                onPressed: () => context.go(
                  rower == null
                      ? AppRoutes.identity
                      : '${AppRoutes.identityEdit}?id=${Uri.encodeQueryComponent(rower.id)}',
                ),
                icon: const Icon(Icons.person_outline, color: DeckColors.text),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              Text(
                                'Bonjour $firstName',
                                style: const TextStyle(
                                  fontFamily: DeckType.ui,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.24,
                                  color: DeckColors.text,
                                ),
                              ),
                              if (club != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: DeckColors.surfaceHighest,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    club.name,
                                    style: DeckType.labelMono(
                                      color: DeckColors.label,
                                      size: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ref.watch(boatConfigProvider).bassin,
                            style: const TextStyle(
                              fontFamily: DeckType.ui,
                              fontSize: 12,
                              color: DeckColors.label,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: DeckColors.surfaceHighest,
                      child: Text(
                        firstName.isEmpty
                            ? '?'
                            : firstName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontFamily: DeckType.ui,
                          fontWeight: FontWeight.w700,
                          color: DeckColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    DeckSessionModeSwitch(
                      mode: mode,
                      onChanged: (m) => ref
                          .read(boatConfigProvider.notifier)
                          .setSessionMode(m),
                    ),
                    const Spacer(),
                    const DeckSyncPill(highlight: DeckHonestKind.local),
                  ],
                ),
                const SizedBox(height: 16),
                const WaterTodayCard(),
                const SizedBox(height: 12),
                _FunnelTodayCard(
                  funnel: ref.watch(funnelProvider),
                  hasRower: rower != null,
                  onStart: () {
                    final f = ref.read(funnelProvider);
                    final piece = f.profile?.todayPiece;
                    if (piece != null) {
                      ref.read(funnelProvider.notifier).setActivePiece(
                            piece: piece,
                            dragFactor: f.profile?.dragFactor,
                          );
                      context.go(
                        '${AppRoutes.funnelPreview}?piece=${piece.id}',
                      );
                    } else {
                      final dist = f.profile?.playDistanceM ?? 500;
                      ref.read(funnelProvider.notifier).setActivePiece(
                            distM: dist,
                            dragFactor: f.profile?.dragFactor,
                          );
                      context.go(
                        '${AppRoutes.funnelPreview}?dist=$dist',
                      );
                    }
                  },
                  onSetupPractice: () => context.go(AppRoutes.funnelOnboard),
                  onAteliers: () => context.go(AppRoutes.funnelAteliers),
                  onDistances: () => context.go(AppRoutes.funnelDistances),
                ),
                const SizedBox(height: 12),
                _HeroLastOuting(
                  loaded: _loaded,
                  last: _last,
                  whenLabel: _last == null ? null : _whenLabel(_last!.meta),
                  pace: _last == null ? '—' : _paceLabel(_last!),
                  onQuickStart: () => _continue(context),
                  onChangeBoat: () => context.go(AppRoutes.presession),
                ),
                const SizedBox(height: 12),
                _AssignmentCard(
                  hasAssignment: asg != null && boat != null,
                  boat: boat,
                  assignment: asg,
                  maint: maint.isNotEmpty,
                ),
                const SizedBox(height: 16),
                Text(
                  'Mes sorties',
                  style: DeckType.uiLabel(
                    color: DeckColors.label,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Material(
                  color: DeckColors.surface,
                  borderRadius: DeckRadii.cardAll,
                  child: InkWell(
                    borderRadius: DeckRadii.cardAll,
                    onTap: () => context.go(AppRoutes.sessions),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: DeckRadii.cardAll,
                        border: Border.all(color: DeckColors.hairline),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: DeckColors.surfaceHighest,
                              borderRadius: DeckRadii.buttonAll,
                            ),
                            child: const Icon(
                              Icons.smartphone,
                              color: DeckColors.text,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _sessionCount == 0
                                      ? 'Aucune sortie sur ce téléphone'
                                      : '$_sessionCount sorties sur ce téléphone',
                                  style: const TextStyle(
                                    fontFamily: DeckType.ui,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                    color: DeckColors.text,
                                  ),
                                ),
                                if (_last != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_whenLabel(_last!.meta)} · '
                                    '${_last!.distM == null ? '—' : '${_last!.distM!.round()} m'}',
                                    style: DeckType.labelMono(
                                      color: DeckColors.label,
                                      size: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward,
                            color: DeckColors.label,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte funnel « Aujourd’hui · {distance} » ou CTA pratique.
class _FunnelTodayCard extends StatelessWidget {
  const _FunnelTodayCard({
    required this.funnel,
    required this.hasRower,
    required this.onStart,
    required this.onSetupPractice,
    required this.onAteliers,
    required this.onDistances,
  });

  final FunnelState funnel;
  final bool hasRower;
  final VoidCallback onStart;
  final VoidCallback onSetupPractice;
  final VoidCallback onAteliers;
  final VoidCallback onDistances;

  ErgSessionLog? get _lastCompleteErg {
    ErgSessionLog? last;
    for (final log in funnel.logs) {
      if (!log.complete) continue;
      if (last == null || log.at.isAfter(last.at)) last = log;
    }
    return last;
  }

  @override
  Widget build(BuildContext context) {
    final profile = funnel.profile;
    final ready = profile != null && profile.onboardDone;

    if (!ready) {
      return Container(
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
              hasRower
                  ? 'Pose ton cadre de pratique'
                  : 'Un morceau sur l’erg',
              style: const TextStyle(
                fontFamily: DeckType.ui,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: DeckColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasRower
                  ? 'Une fois, pour la carte du jour.'
                  : '500 m ou 2 000 m — local, sans compte.',
              style: const TextStyle(
                fontFamily: DeckType.ui,
                fontSize: 13,
                color: DeckColors.label,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: onSetupPractice,
                child: Text(hasRower ? 'Choisir mon cadre' : 'Commencer'),
              ),
            ),
          ],
        ),
      );
    }

    final label = profile.todayCardLabel;
    final pb = profile.pb2000s;
    final df = profile.dragFactor;
    final lastErg = _lastCompleteErg;

    return Container(
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
          Row(
            children: [
              const Icon(Icons.fitness_center, size: 18, color: DeckColors.volt),
              const SizedBox(width: 6),
              Text(
                'Erg',
                style: DeckType.uiLabel(
                  color: DeckColors.volt,
                  weight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (pb != null)
                Text(
                  'PB 2 000 m · ${formatErgTime(pb)}',
                  style: DeckType.labelMono(size: 10),
                )
              else
                Text(
                  'Pas de 2 000 m logué',
                  style: DeckType.labelMono(size: 10),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Aujourd'hui · $label",
            style: const TextStyle(
              fontFamily: DeckType.ui,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: DeckColors.text,
            ),
          ),
          if (lastErg != null && lastErg.split500S > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Split moyen · ${formatErgTime(lastErg.split500S)} /500 m',
              style: DeckType.labelMono(size: 12, color: DeckColors.label),
            ),
            if (lastErg.cadence != null) ...[
              const SizedBox(height: 2),
              Text(
                'Cadence moy. · ${lastErg.cadence!.round()}',
                style: DeckType.labelMono(size: 12, color: DeckColors.label),
              ),
            ],
          ],
          if (df != null) ...[
            const SizedBox(height: 4),
            Text(
              'DF $df',
              style: DeckType.labelMono(size: 11),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow, size: 24),
              label: const Text('Start'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onAteliers,
            child: const Text(
              'Ateliers brevet',
              style: TextStyle(color: DeckColors.muted),
            ),
          ),
          TextButton(
            onPressed: onDistances,
            child: const Text(
              'Distances FFA',
              style: TextStyle(color: DeckColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroLastOuting extends StatelessWidget {
  const _HeroLastOuting({
    required this.loaded,
    required this.last,
    required this.pace,
    required this.onQuickStart,
    required this.onChangeBoat,
    this.whenLabel,
  });

  final bool loaded;
  final _LastOuting? last;
  final String pace;
  final String? whenLabel;
  final VoidCallback onQuickStart;
  final VoidCallback onChangeBoat;

  @override
  Widget build(BuildContext context) {
    final m = last?.meta;
    final dist = last?.distM;
    final cad = last?.cadenceLabel ?? '—';
    final dur = last?.duration;

    return Container(
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
          Stack(
            children: [
              Positioned(
                top: -16,
                left: -16,
                right: -16,
                child: Container(height: 2, color: DeckColors.volt),
              ),
              Row(
                children: [
                  const Icon(Icons.history, size: 18, color: DeckColors.volt),
                  const SizedBox(width: 6),
                  Text(
                    'Dernière sortie',
                    style: DeckType.uiLabel(
                      color: DeckColors.volt,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            loaded && m != null
                ? '${whenLabel ?? 'Dernière sortie'} · ${m.classe}'
                    '${m.bassin == null || m.bassin!.isEmpty ? '' : ' · ${m.bassin}'}'
                : 'Pas encore de sortie sur ce téléphone',
            style: const TextStyle(
              fontFamily: DeckType.ui,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: DeckColors.text,
            ),
          ),
          if (dur != null) ...[
            const SizedBox(height: 4),
            Text(
              'Durée effective ${formatDuration(dur)}',
              style: DeckType.labelMono(color: DeckColors.label, size: 10),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: DeckColors.bg,
              borderRadius: DeckRadii.buttonAll,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MetricCol(
                    label: 'Distance',
                    value: dist == null || dist <= 0
                        ? '—'
                        : dist.round().toString().replaceAllMapped(
                              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                              (m) => '${m[1]} ',
                            ),
                    unit: 'm',
                  ),
                ),
                Expanded(
                  child: _MetricCol(
                    label: 'Allure moy',
                    value: pace,
                    unit: '/500m',
                    unitBelow: true,
                  ),
                ),
                Expanded(
                  child: _MetricCol(
                    label: 'Cadence moy',
                    value: cad,
                    unit: cad == '—' ? null : 'spm',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: onQuickStart,
              icon: const Icon(Icons.play_arrow, size: 24),
              label: Text(
                last == null ? 'Aller ramer' : 'Reprendre',
              ),
            ),
          ),
          TextButton(
            onPressed: onChangeBoat,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Autre bateau'),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCol extends StatelessWidget {
  const _MetricCol({
    required this.label,
    required this.value,
    this.unit,
    this.unitBelow = false,
  });

  final String label;
  final String value;
  final String? unit;
  final bool unitBelow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DeckType.uiLabel(size: 12)),
        const SizedBox(height: 4),
        if (unitBelow) ...[
          Text(value, style: DeckType.metric(size: 20, weight: FontWeight.w600)),
          if (unit != null)
            Text(
              unit!,
              style: DeckType.labelMono(color: DeckColors.label, size: 10),
            ),
        ] else
          Text.rich(
            TextSpan(
              text: value,
              style: DeckType.metric(size: 20, weight: FontWeight.w600),
              children: [
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: DeckType.labelMono(
                      color: DeckColors.label,
                      size: 10,
                      weight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.hasAssignment,
    required this.maint,
    this.boat,
    this.assignment,
  });

  final bool hasAssignment;
  final ParkBoat? boat;
  final Assignment? assignment;
  final bool maint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DeckColors.bgTactical,
        borderRadius: DeckRadii.cardAll,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment, size: 20, color: DeckColors.tribord),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Affectation du jour',
                  style: TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: DeckColors.text,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DeckColors.surfaceHighest,
                  borderRadius: DeckRadii.chipAll,
                ),
                child: Text(
                  'Planning',
                  style: DeckType.labelMono(color: DeckColors.label, size: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: DeckColors.surfaceHighest,
                  borderRadius: DeckRadii.buttonAll,
                ),
                child: const Icon(
                  Icons.kayaking,
                  size: 20,
                  color: DeckColors.label,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: hasAssignment && boat != null && assignment != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${boat!.name} · ${boat!.classe}',
                            style: const TextStyle(
                              fontFamily: DeckType.ui,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: DeckColors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            assignment!.seatIndex == null
                                ? assignmentChip(assignment!)
                                : 'Siège ${assignment!.seatIndex}'
                                    '${assignment!.side == SidePref.none ? '' : ' · ${assignment!.side.wire}'}',
                            style: const TextStyle(
                              fontFamily: DeckType.ui,
                              fontSize: 12,
                              color: DeckColors.label,
                            ),
                          ),
                          if (maint)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                'Ta coque est en maintenance.',
                                style: TextStyle(color: DeckColors.volt),
                              ),
                            ),
                        ],
                      )
                    : const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pas d’affectation aujourd’hui.',
                            style: TextStyle(
                              fontFamily: DeckType.ui,
                              fontSize: 14,
                              color: DeckColors.text,
                              height: 1.35,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Choisis ta coque librement.',
                            style: TextStyle(
                              fontFamily: DeckType.ui,
                              fontSize: 12,
                              color: DeckColors.label,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
