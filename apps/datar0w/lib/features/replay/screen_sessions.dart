import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../session/cadence_backfill.dart';
import '../../session/share_files.dart';
import '../../session/store.dart';
import '../../session/summary.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_shell.dart';
import '../../widgets/deck_widgets.dart';

/// DR-60 — Historique des séances (onglet Séances).
class SessionHistoryScreen extends ConsumerStatefulWidget {
  const SessionHistoryScreen({
    super.key,
    this.fromCoach = false,
    this.roleFilter,
    this.codeFilter,
  });

  final bool fromCoach;
  final String? roleFilter;
  final String? codeFilter;

  @override
  ConsumerState<SessionHistoryScreen> createState() =>
      _SessionHistoryScreenState();
}

class _SessionRow {
  const _SessionRow({
    required this.meta,
    this.duration,
    this.distM,
    this.cadenceMean,
  });

  final SessionMeta meta;
  final Duration? duration;
  final double? distM;
  final double? cadenceMean;
}

class _SessionHistoryScreenState extends ConsumerState<SessionHistoryScreen> {
  List<_SessionRow> _rows = const [];
  bool _loading = true;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final metas = await SessionStore.listSessions();
    final role = widget.roleFilter?.trim().toLowerCase();
    final code = widget.codeFilter?.trim().toUpperCase();
    final filtered = metas.where((m) {
      if (role != null && role.isNotEmpty && m.role.toLowerCase() != role) {
        return false;
      }
      if (code != null &&
          code.isNotEmpty &&
          (m.code ?? '').toUpperCase() != code) {
        return false;
      }
      return true;
    });
    final rows = <_SessionRow>[];
    for (final m in filtered) {
      await CadenceBackfill.maybeBackfill(m.id);
      final samples = await SessionStore.loadSamples(m.id);
      Duration? duration;
      double? distM;
      double? cad;
      if (samples.isNotEmpty) {
        final s = SessionSummary.fromSamples(samples);
        duration = s.duration;
        distM = s.distM;
        cad = s.cadenceMedianHigh ?? s.cadenceMean;
      } else {
        final a = DateTime.tryParse(m.startedAt ?? '');
        final b = DateTime.tryParse(m.endedAt ?? '');
        if (a != null && b != null && !b.isBefore(a)) {
          duration = b.difference(a);
        }
      }
      rows.add(
        _SessionRow(
          meta: m,
          duration: duration,
          distM: distM,
          cadenceMean: cad,
        ),
      );
    }
    if (mounted) {
      setState(() {
        _rows = rows;
        _loading = false;
      });
    }
  }

  String _replayPath(String id) {
    final base =
        widget.fromCoach ? AppRoutes.coachReplay : AppRoutes.rowerReplay;
    return '$base?id=${Uri.encodeQueryComponent(id)}';
  }

  void _snack(String msg) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _shareSelected() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    final prep = await prepareBulkSessionZip(ids);
    if (!mounted) return;
    if (prep.tooHeavy || prep.bytes == null) {
      _snack('trop lourd, envoie séance par séance');
      return;
    }
    await shareBulkSessionZip(ids);
  }

  String _pace(_SessionRow row) {
    final d = row.duration;
    final dist = row.distM;
    if (d == null || dist == null || dist <= 0 || d.inMilliseconds <= 0) {
      return '—';
    }
    final sec = d.inMilliseconds / 1000.0 * 500.0 / dist;
    final m = sec ~/ 60;
    final s = (sec % 60).round().clamp(0, 59);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _dayHeader(String? iso) {
    if (iso == null || iso.isEmpty) return 'Sans date';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return formatSessionDay(iso);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return 'Hier';
    return formatSessionDay(iso);
  }

  String _timeLabel(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '—';
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return DeckTabScaffold(
      tab: DeckTab.sessions,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  if (widget.fromCoach)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: DeckColors.text),
                      onPressed: () => context.go(AppRoutes.homeCoach),
                    ),
                  Expanded(
                    child: Text(
                      widget.fromCoach
                          ? 'Séances club'
                          : 'Historique des séances',
                      style: const TextStyle(
                        fontFamily: DeckType.ui,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: DeckColors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Plus',
                    onPressed: () => context.go(AppRoutes.plus),
                    icon: const Icon(
                      Icons.person_outline,
                      color: DeckColors.text,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucune séance sur ce téléphone.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: DeckType.ui,
              color: DeckColors.muted,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (_selected.isNotEmpty) ...[
          FilledButton(
            onPressed: _shareSelected,
            child: Text('Envoyer la sélection (${_selected.length})'),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          '${_rows.length} séances',
          style: DeckType.uiLabel(weight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _rows.length; i++) ...[
          if (i == 0 ||
              _dayHeader(_rows[i].meta.startedAt) !=
                  _dayHeader(_rows[i - 1].meta.startedAt))
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 12, bottom: 8),
              child: Text(
                _dayHeader(_rows[i].meta.startedAt),
                style: const TextStyle(
                  fontFamily: DeckType.ui,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: DeckColors.text,
                ),
              ),
            ),
          _SessionCard(
            row: _rows[i],
            selected: _selected.contains(_rows[i].meta.id),
            time: _timeLabel(_rows[i].meta.startedAt),
            pace: _pace(_rows[i]),
            onToggle: (v) {
              setState(() {
                if (v) {
                  _selected.add(_rows[i].meta.id);
                } else {
                  _selected.remove(_rows[i].meta.id);
                }
              });
            },
            onReplay: () => context.go(_replayPath(_rows[i].meta.id)),
            onShare: () => shareLocalSession(_rows[i].meta.id),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.row,
    required this.selected,
    required this.time,
    required this.pace,
    required this.onToggle,
    required this.onReplay,
    required this.onShare,
  });

  final _SessionRow row;
  final bool selected;
  final String time;
  final String pace;
  final ValueChanged<bool> onToggle;
  final VoidCallback onReplay;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final m = row.meta;
    final code = (m.code ?? '').trim();
    final dist = row.distM;
    final distLabel =
        (dist != null && dist > 0) ? '${dist.round()} m' : '—';
    final dur = row.duration == null ? '—' : formatDuration(row.duration!);
    final cad = row.cadenceMean?.round().toString() ?? '—';

    return Material(
      color: DeckColors.surface,
      borderRadius: DeckRadii.cardAll,
      child: InkWell(
        borderRadius: DeckRadii.cardAll,
        onTap: onReplay,
        onLongPress: () => onToggle(!selected),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: DeckRadii.cardAll,
            border: Border.all(
              color: selected ? DeckColors.volt : DeckColors.hairline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    time,
                    style: DeckType.labelMono(color: DeckColors.label, size: 11),
                  ),
                  const Spacer(),
                  const DeckHonestChip(kind: DeckHonestKind.local),
                  Checkbox(
                    value: selected,
                    onChanged: (v) => onToggle(v ?? false),
                  ),
                ],
              ),
              Text(
                m.bassin?.isNotEmpty == true
                    ? m.bassin!
                    : (code.isEmpty ? m.id : code.toUpperCase()),
                style: const TextStyle(
                  fontFamily: DeckType.ui,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: DeckColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.kayaking, size: 18, color: DeckColors.label),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${m.classe.toUpperCase()}'
                      '${m.seatIndex == null ? '' : ' · poste ${m.seatIndex}'}',
                      style: const TextStyle(
                        fontFamily: DeckType.ui,
                        fontSize: 13,
                        color: DeckColors.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Mini('Distance', distLabel)),
                  Expanded(child: _Mini('Durée', dur)),
                  Expanded(child: _Mini('Allure /500m', pace)),
                  Expanded(child: _Mini('Cadence', '$cad spm')),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(onPressed: onReplay, child: const Text('Revoir')),
                  TextButton(onPressed: onShare, child: const Text('Exporter')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DeckType.uiLabel(size: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: DeckType.metric(size: 14, weight: FontWeight.w600),
        ),
      ],
    );
  }
}
