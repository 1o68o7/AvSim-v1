import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/controller.dart';
import '../../identity/models.dart';
import '../../router.dart';
import '../../session/boat_config.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

String boatStatusLabel(BoatParkStatus s) => switch (s) {
      BoatParkStatus.ready => 'prêt',
      BoatParkStatus.maintenance => 'maintenance',
      BoatParkStatus.out => 'hors d’eau',
    };

class ClubScreen extends ConsumerStatefulWidget {
  const ClubScreen({super.key});

  @override
  ConsumerState<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends ConsumerState<ClubScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _hydrated = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  void _hydrate(IdentitySnapshot snap) {
    if (_hydrated) return;
    final c = snap.activeClub;
    if (c != null) {
      _name.text = c.name;
      _code.text = c.shortCode ?? '';
    }
    _hydrated = true;
  }

  Future<void> _saveClub() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final existing = ref.read(identityProvider).activeClub;
    final club = existing == null
        ? Club.create(name: name, shortCode: _code.text.trim().isEmpty ? null : _code.text.trim())
        : existing.copyWith(
            name: name,
            shortCode: _code.text.trim(),
            clearCode: _code.text.trim().isEmpty,
          );
    await ref.read(identityProvider.notifier).saveClub(club);
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(identityProvider);
    final role = ref.watch(boatConfigProvider).role;
    final edit = canEditPark(role);
    _hydrate(snap);
    final boats = snap.boatsForClub(snap.activeClub?.id);

    return DeckScaffold(
      title: 'CLUB',
      subtitle: 'Un téléphone · un club',
      leading: TextButton(
        onPressed: () => context.go(AppRoutes.profile),
        child: const Text('Retour'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          TextField(
            controller: _name,
            enabled: edit,
            decoration: const InputDecoration(labelText: 'Nom du club'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _code,
            enabled: edit,
            decoration: const InputDecoration(labelText: 'Code court (3–4 car.)'),
          ),
          if (edit) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saveClub,
              child: const Text('ENREGISTRER LE CLUB'),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'PARC À BATEAUX',
            style: const TextStyle(
              color: DeckColors.label,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          if (boats.isEmpty)
            const Text(
              'Aucune coque. Le coach ajoute le parc.',
              style: TextStyle(color: DeckColors.muted),
            ),
          for (final b in boats)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(b.name),
              subtitle: Text(
                '${b.classe} · ${b.seats} sièges'
                '${b.cox ? ' · barreur' : ''} · ${boatStatusLabel(b.status)}',
              ),
              onTap: edit
                  ? () => context.go('${AppRoutes.clubBoat}?id=${b.id}')
                  : null,
              trailing: edit
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
                          .read(identityProvider.notifier)
                          .deleteBoat(b.id),
                    )
                  : null,
            ),
          if (edit && snap.activeClub != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.clubBoat),
              child: const Text('+ Ajouter'),
            ),
          ],
        ],
      ),
    );
  }
}
