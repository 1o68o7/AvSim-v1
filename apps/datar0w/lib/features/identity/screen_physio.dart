import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../calendar/loisir_store.dart';
import '../../health/consent_store.dart';
import '../../identity/controller.dart';
import '../../router.dart';
import '../../session/store.dart';
import '../../session/summary.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import '../../widgets/deck_widgets.dart';

enum _PhysioWindow { d7, d28, d90 }

class PhysioScreen extends ConsumerStatefulWidget {
  const PhysioScreen({super.key});

  @override
  ConsumerState<PhysioScreen> createState() => _PhysioScreenState();
}

class _PhysioScreenState extends ConsumerState<PhysioScreen> {
  _PhysioWindow _window = _PhysioWindow.d28;
  List<_SessionRow> _rows = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Duration get _span => switch (_window) {
        _PhysioWindow.d7 => const Duration(days: 7),
        _PhysioWindow.d28 => const Duration(days: 28),
        _PhysioWindow.d90 => const Duration(days: 90),
      };

  Future<void> _load() async {
    setState(() => _loading = true);
    final rowerId = ref.read(identityProvider).activeRower?.id;
    final metas = await SessionStore.listSessions();
    final cutoff = DateTime.now().toUtc().subtract(_span);
    final filtered = metas.where((m) {
      if (rowerId != null && m.rowerId != null && m.rowerId != rowerId) {
        return false;
      }
      final start = m.startedAt == null ? null : DateTime.tryParse(m.startedAt!);
      if (start == null) return true;
      return !start.isBefore(cutoff);
    }).toList();
    final rows = <_SessionRow>[];
    for (final m in filtered.take(12)) {
      final samples = await SessionStore.loadSamples(m.id);
      final s = SessionSummary.fromSamples(samples);
      rows.add(_SessionRow(meta: m, summary: s));
    }
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rower = ref.watch(identityProvider).activeRower;
    final latest = _rows.isEmpty ? null : _rows.first;
    return DeckScaffold(
      title: 'MES CONSTANTES',
      subtitle: 'informatif · pas médical',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const DeckSectionLabel('Readiness'),
          const SizedBox(height: 8),
          const Text(
            '—',
            style: TextStyle(fontSize: 48, fontWeight: FontWeight.w700),
          ),
          const Text(
            'Pas assez de séances avec FC pour un score.',
            style: TextStyle(color: DeckColors.muted),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: [
              for (final w in _PhysioWindow.values)
                ChoiceChip(
                  label: Text(switch (w) {
                    _PhysioWindow.d7 => '7 JOURS',
                    _PhysioWindow.d28 => '28 JOURS',
                    _PhysioWindow.d90 => '90 JOURS',
                  }),
                  selected: _window == w,
                  onSelected: (_) {
                    setState(() => _window = w);
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),
          const DeckSectionLabel('Dernière séance'),
          const SizedBox(height: 8),
          if (_loading)
            const Text('…', style: TextStyle(color: DeckColors.muted))
          else if (latest == null)
            const Text(
              'Aucune séance dans la fenêtre. Courbe FC + cadence + V sol : '
              'voir replay après STOP.',
              style: TextStyle(color: DeckColors.muted, height: 1.4),
            )
          else
            _LatestCard(row: latest),
          if (latest != null) ...[
            const SizedBox(height: 16),
            const DeckSectionLabel('Métriques clés'),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.55,
              children: [
                InstrumentPod(
                  label: 'Distance',
                  value: (latest.summary.distM / 1000).toStringAsFixed(2),
                  unit: 'KM',
                ),
                InstrumentPod(
                  label: 'Durée',
                  value: formatDuration(latest.summary.duration),
                  unit: 'MIN',
                ),
                InstrumentPod(
                  label: 'Cadence moy.',
                  value: latest.summary.cadenceMean == null
                      ? '—'
                      : latest.summary.cadenceMean!.toStringAsFixed(0),
                  unit: 'SPM',
                ),
                InstrumentPod(
                  label: 'Gîte RMS',
                  value: latest.summary.giteRms.toStringAsFixed(1),
                  unit: '°',
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'FC moy / max — non dispo ici (voir replay). '
              'Pas de courbe inventée.',
              style: TextStyle(color: DeckColors.label, fontSize: 11),
            ),
          ],
          const SizedBox(height: 20),
          DeckSectionLabel(
            'Historique séances',
            trailing: Text(
              '${_rows.length}',
              style: const TextStyle(color: DeckColors.label, fontSize: 11),
            ),
          ),
          const SizedBox(height: 8),
          for (final row in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: DeckColors.surfaceHigh,
                child: InkWell(
                  onTap: () => context.go(
                    '${AppRoutes.rowerReplay}?id=${Uri.encodeQueryComponent(row.meta.id)}',
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: DeckColors.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatClockRange(
                            row.meta.startedAt,
                            row.meta.endedAt,
                          ),
                          style: const TextStyle(
                            color: DeckColors.label,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '${row.meta.classe.toUpperCase()}'
                          '${row.meta.bassin == null ? '' : ' · ${row.meta.bassin}'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Dist ${(row.summary.distM / 1000).toStringAsFixed(2)} km · '
                          'SPM ${row.summary.cadenceMean?.toStringAsFixed(0) ?? '—'} · '
                          '${formatDuration(row.summary.duration)}',
                          style: const TextStyle(
                            color: DeckColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const DeckSectionLabel('Parcours loisirs'),
          const SizedBox(height: 8),
          FutureBuilder(
            future: LoisirStore().list(),
            builder: (context, snap) {
              final mine = (snap.data ?? const [])
                  .where((p) => rower == null || p.rowerId == rower.id)
                  .toList();
              if (mine.isEmpty) {
                return const Text(
                  'Aucune régate / rando / master signalé.',
                  style: TextStyle(color: DeckColors.muted),
                );
              }
              return Column(
                children: [
                  for (final p in mine)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.type),
                      subtitle: Text(p.tempsCourse ?? p.eventId),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.consent),
            child: const Text('GÉRER LE PARTAGE COACH'),
          ),
          FutureBuilder(
            future: ConsentStore().load(),
            builder: (context, snap) {
              final c = snap.data;
              final shared = c?.shareWithCoach == true;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  shared
                      ? 'Partage coach : activé (opt-in).'
                      : 'Partage coach : privé par défaut.',
                  style: const TextStyle(color: DeckColors.muted, fontSize: 11),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SessionRow {
  const _SessionRow({required this.meta, required this.summary});
  final SessionMeta meta;
  final SessionSummary summary;
}

class _LatestCard extends StatelessWidget {
  const _LatestCard({required this.row});
  final _SessionRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DeckColors.surfaceHigh,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatClockRange(row.meta.startedAt, row.meta.endedAt),
            style: const TextStyle(color: DeckColors.label, fontSize: 11),
          ),
          Text(
            row.meta.classe.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              letterSpacing: 1.0,
            ),
          ),
          if (row.meta.bassin != null)
            Text(
              row.meta.bassin!,
              style: const TextStyle(color: DeckColors.muted, fontSize: 12),
            ),
          const SizedBox(height: 8),
          const Text(
            'Overlay multi-courbes : ouvrir le replay (pas de FC inventée ici).',
            style: TextStyle(color: DeckColors.muted, fontSize: 11, height: 1.35),
          ),
        ],
      ),
    );
  }
}
