import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../onboarding/routing.dart';
import '../../router.dart';
import '../../sync/club_sessions.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import '../../widgets/deck_widgets.dart';

String _fmtDate(DateTime d) {
  final l = d.toLocal();
  final dd = l.day.toString().padLeft(2, '0');
  final mm = l.month.toString().padLeft(2, '0');
  final yy = (l.year % 100).toString().padLeft(2, '0');
  final hh = l.hour.toString().padLeft(2, '0');
  final mi = l.minute.toString().padLeft(2, '0');
  return '$dd/$mm/$yy ${hh}h$mi';
}

String _friendlyLoadError(Object e) {
  final raw = '$e';
  if (raw.contains('pas de club') || raw == 'pas de club') {
    return 'Aucun club sélectionné.';
  }
  if (raw.contains('42501')) return 'Accès refusé au cloud.';
  if (raw.contains('23505')) return 'Cette séance est déjà synchronisée.';
  if (raw.contains('PGRST') || raw.contains('Postgrest')) {
    return 'Erreur serveur cloud. Réessaie.';
  }
  if (raw.length > 120) return '${raw.substring(0, 120)}…';
  return raw;
}

/// ST-05 — liste `session_meta` du club (staff only).
class ClubSessionsScreen extends ConsumerStatefulWidget {
  const ClubSessionsScreen({super.key});

  @override
  ConsumerState<ClubSessionsScreen> createState() => _ClubSessionsScreenState();
}

class _ClubSessionsScreenState extends ConsumerState<ClubSessionsScreen> {
  List<ClubSessionMeta>? _rows;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final snap = ref.read(identityProvider);
    if (!isClubStaffRole(snap.prefs.clubRole.name)) {
      if (mounted) context.go(AppRoutes.homeRower);
      return;
    }
    final clubId = snap.prefs.activeClubId;
    if (clubId == null || clubId.isEmpty) {
      setState(() {
        _loading = false;
        _rows = const [];
        _error = 'Aucun club sélectionné.';
      });
      return;
    }
    try {
      final rows =
          await ref.read(clubSessionRemoteProvider).listForClub(clubId);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyLoadError(e);
        _rows = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final snap = ref.watch(identityProvider);
    return DeckScaffold(
      title: 'Séances du club',
      subtitle: 'Séances cloud',
      retourFallback: homeRouteForClubMemberRole(snap.prefs.clubRole),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: DeckColors.volt),
                      ),
                    ),
                  if (_error == null && (rows == null || rows.isEmpty))
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Text(
                        'Aucune séance cloud.',
                        style: TextStyle(
                          color: DeckColors.muted,
                          height: 1.4,
                        ),
                      ),
                    )
                  else if (rows != null)
                    for (final r in rows) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          r.code.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (r.displayDate != null) _fmtDate(r.displayDate!),
                            r.sizeLabel,
                          ].join(' · '),
                          style: const TextStyle(color: DeckColors.label),
                        ),
                        trailing: const DeckStatusChip(label: 'Cloud', ok: true),
                        onTap: () => context.go(
                          '${AppRoutes.clubSessions}/${Uri.encodeComponent(r.code)}',
                        ),
                      ),
                      const Divider(height: 1, color: DeckColors.hairline),
                    ],
                ],
              ),
            ),
    );
  }
}

/// ST-06 — fiche séance cloud (méta + résumé si présent).
class ClubSessionDetailScreen extends ConsumerStatefulWidget {
  const ClubSessionDetailScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<ClubSessionDetailScreen> createState() =>
      _ClubSessionDetailScreenState();
}

class _ClubSessionDetailScreenState
    extends ConsumerState<ClubSessionDetailScreen> {
  ClubSessionMeta? _row;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final snap = ref.read(identityProvider);
    if (!isClubStaffRole(snap.prefs.clubRole.name)) {
      if (mounted) context.go(AppRoutes.homeRower);
      return;
    }
    final clubId = snap.prefs.activeClubId;
    if (clubId == null) {
      setState(() {
        _loading = false;
        _error = 'Aucun club sélectionné.';
      });
      return;
    }
    try {
      final row = await ref
          .read(clubSessionRemoteProvider)
          .byCode(clubId, widget.code);
      if (!mounted) return;
      setState(() {
        _row = row;
        _loading = false;
        _error = row == null ? 'Séance introuvable pour ce code.' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyLoadError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _row;
    return DeckScaffold(
      title: widget.code.toUpperCase(),
      subtitle: 'Séance cloud',
      retourFallback: AppRoutes.clubSessions,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: DeckColors.volt),
                  ),
                )
              : r == null
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Séance introuvable.',
                        style: TextStyle(color: DeckColors.muted),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        const DeckSectionLabel('Méta'),
                        const SizedBox(height: 8),
                        _kv('Code', r.code.toUpperCase()),
                        _kv('Classe', (r.boatClass ?? '—').toUpperCase()),
                        _kv(
                          'Début',
                          r.startedAt != null ? _fmtDate(r.startedAt!) : '—',
                        ),
                        _kv(
                          'Fin',
                          r.endedAt != null ? _fmtDate(r.endedAt!) : '—',
                        ),
                        _kv('Taille', r.sizeLabel),
                        _kv('Propriétaire', r.ownerUserId ?? '—'),
                        const SizedBox(height: 20),
                        const DeckSectionLabel('Résumé'),
                        const SizedBox(height: 8),
                        _kv(
                          'Distance',
                          r.distM != null ? '${r.distM!.round()} m' : 'non mesurée',
                        ),
                        _kv(
                          'Durée',
                          r.durationS != null
                              ? '${(r.durationS! / 60).toStringAsFixed(1)} min'
                              : 'non mesurée',
                        ),
                        _kv(
                          'Vitesse',
                          _speedLabel(r),
                        ),
                        _kv(
                          'Cadence',
                          r.cadenceSpm != null
                              ? '${r.cadenceSpm!.toStringAsFixed(0)} spm'
                              : 'cadence non mesurée',
                        ),
                        _kv(
                          'Gîte (RMS)',
                          r.giteRmsDeg != null
                              ? '${r.giteRmsDeg!.toStringAsFixed(1)}°'
                              : 'non mesurée',
                        ),
                        const SizedBox(height: 16),
                        const DeckStatusChip(label: 'Cloud', ok: true),
                      ],
                    ),
    );
  }

  String _speedLabel(ClubSessionMeta r) {
    if (r.distM == null || r.durationS == null || r.durationS! <= 0) {
      return 'non mesurée';
    }
    final ms = r.distM! / r.durationS!;
    final kmh = ms * 3.6;
    final split500 = ms > 0 ? 500 / ms : null;
    final split = split500 == null
        ? ''
        : ' · ${(split500 / 60).floor()}:'
            '${(split500 % 60).floor().toString().padLeft(2, '0')}/500';
    return '${kmh.toStringAsFixed(1)} km/h$split';
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              k,
              style: const TextStyle(color: DeckColors.label, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
