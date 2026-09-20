import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../identity/models.dart';
import '../../ops/controller.dart';
import '../../router.dart';
import '../../session/boat_config.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/club_banner.dart';
import '../../widgets/deck_scaffold.dart';

class SpinoscopeScreen extends ConsumerStatefulWidget {
  const SpinoscopeScreen({super.key});

  @override
  ConsumerState<SpinoscopeScreen> createState() => _SpinoscopeScreenState();
}

class _SpinoscopeScreenState extends ConsumerState<SpinoscopeScreen> {
  final _name = TextEditingController();
  final _result = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _result.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(identityProvider);
    final ops = ref.watch(opsProvider);
    final role = ref.watch(boatConfigProvider).role;
    final club = snap.activeClub;
    final edit = canCheckoutOps(snap, role);
    final compet = snap.rowers.where((r) => r.level == RowerLevel.competiteur).length;
    final loisir = snap.rowers.where((r) => r.level == RowerLevel.loisir).length;
    final byClass = <String, int>{};
    for (final b in snap.boatsForClub(club?.id)) {
      byClass[b.classe] = (byClass[b.classe] ?? 0) + 1;
    }
    final outsToday = ops.activeOuts.length;
    final cups = snap.trophies.where((t) => club != null && t.clubId == club.id).toList();

    return DeckScaffold(
      title: 'SPINOSCOPE',
      subtitle: 'Vitrine du club',
      leading: TextButton(
        onPressed: () => context.go(
          role == CrewRole.coach ? AppRoutes.homeCoach : AppRoutes.homeRower,
        ),
        child: const Text('Retour'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (club != null) ClubBanner(club: club),
          const SizedBox(height: 16),
          const Text(
            'EFFECTIF',
            style: TextStyle(
              color: DeckColors.label,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          _Bar(label: 'Compétiteurs', n: compet, color: DeckColors.tribord),
          _Bar(label: 'Loisirs', n: loisir, color: DeckColors.amber),
          Text(
            'Licenciés : ${snap.rowers.length}',
            style: const TextStyle(color: DeckColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          const Text(
            'PARC',
            style: TextStyle(
              color: DeckColors.label,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          for (final e in byClass.entries)
            Text('${e.key}  ×${e.value}', style: const TextStyle(fontSize: 13)),
          if (byClass.isEmpty)
            const Text('Aucune coque', style: TextStyle(color: DeckColors.muted)),
          const SizedBox(height: 8),
          Text(
            'Sorties en cours : $outsToday',
            style: const TextStyle(color: DeckColors.amber),
          ),
          const SizedBox(height: 16),
          const Text(
            'COUPETTES',
            style: TextStyle(
              color: DeckColors.label,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          if (cups.isEmpty)
            const Text('Aucune coupettes.', style: TextStyle(color: DeckColors.muted)),
          for (final t in cups)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.name),
              subtitle: Text(
                '${t.date.toIso8601String().split('T').first}'
                '${t.result == null ? '' : ' · ${t.result}'}',
              ),
              trailing: edit
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          ref.read(identityProvider.notifier).deleteTrophy(t.id),
                    )
                  : null,
            ),
          if (edit && club != null) ...[
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Coupettes'),
            ),
            TextField(
              controller: _result,
              decoration: const InputDecoration(labelText: 'Résultat'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                if (_name.text.trim().isEmpty) return;
                await ref.read(identityProvider.notifier).saveTrophy(
                      Trophy.create(
                        clubId: club.id,
                        name: _name.text.trim(),
                        date: DateTime.now(),
                        result: _result.text.trim().isEmpty
                            ? null
                            : _result.text.trim(),
                      ),
                    );
                _name.clear();
                _result.clear();
              },
              child: const Text('AJOUTER'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.n, required this.color});
  final String label;
  final int n;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: LinearProgressIndicator(
              value: n == 0 ? 0 : (n / (n + 4)).clamp(0.05, 1),
              color: color,
              backgroundColor: DeckColors.hairline,
            ),
          ),
          const SizedBox(width: 8),
          Text('$n'),
        ],
      ),
    );
  }
}
