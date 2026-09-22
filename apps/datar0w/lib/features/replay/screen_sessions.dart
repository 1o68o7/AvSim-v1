import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../session/share_files.dart';
import '../../session/store.dart';
import '../../session/summary.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

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
  });

  final SessionMeta meta;
  final Duration? duration;
  final double? distM;
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
      final samples = await SessionStore.loadSamples(m.id);
      Duration? duration;
      double? distM;
      if (samples.isNotEmpty) {
        final s = SessionSummary.fromSamples(samples);
        duration = s.duration;
        distM = s.distM;
      } else {
        final a = DateTime.tryParse(m.startedAt ?? '');
        final b = DateTime.tryParse(m.endedAt ?? '');
        if (a != null && b != null && !b.isBefore(a)) {
          duration = b.difference(a);
        }
      }
      rows.add(_SessionRow(meta: m, duration: duration, distM: distM));
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
    final m = ScaffoldMessenger.maybeOf(context);
    m?.showSnackBar(SnackBar(content: Text(msg)));
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

  @override
  Widget build(BuildContext context) {
    return DeckScaffold(
      title: 'MES SÉANCES',
      subtitle: widget.fromCoach
          ? 'toutes les séances locales'
          : 'historique local',
      retourFallback:
          widget.fromCoach ? AppRoutes.coachJoin : AppRoutes.homeRower,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(
                  child: Text(
                    'Aucune séance locale.\n'
                    'Les fichiers restent dans Documents/sessions/.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: DeckColors.muted, height: 1.4),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _rows.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final row = _rows[i];
                          final m = row.meta;
                          final code = (m.code ?? '').trim();
                          final km = row.distM;
                          final kmLabel = (km != null && km > 0)
                              ? '${(km / 1000).toStringAsFixed(2)} km'
                              : '— km';
                          final dur = row.duration == null
                              ? '—'
                              : formatDuration(row.duration!);
                          final checked = _selected.contains(m.id);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: checked,
                                  onChanged: (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selected.add(m.id);
                                      } else {
                                        _selected.remove(m.id);
                                      }
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        code.isEmpty
                                            ? m.id
                                            : code.toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${m.classe}  ·  $dur  ·  $kmLabel  ·  '
                                        '${formatSessionDay(m.startedAt ?? m.endedAt)}',
                                        style: const TextStyle(
                                          color: DeckColors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                context.go(_replayPath(m.id)),
                                            child: const Text('REPLAY'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                shareLocalSession(m.id),
                                            child: const Text('ENVOYER'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (_selected.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: FilledButton(
                          onPressed: _shareSelected,
                          child: const Text('ENVOYER LA SÉLECTION'),
                        ),
                      ),
                  ],
                ),
    );
  }
}
