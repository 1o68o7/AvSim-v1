import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../identity/controller.dart';
import '../identity/models.dart';
import '../router.dart';
import '../theme/deck_theme.dart';
import '../widgets/deck_scaffold.dart';

class ClubJoinScreen extends ConsumerStatefulWidget {
  const ClubJoinScreen({super.key});

  @override
  ConsumerState<ClubJoinScreen> createState() => _ClubJoinScreenState();
}

class _ClubJoinScreenState extends ConsumerState<ClubJoinScreen> {
  final _name = TextEditingController();
  final _createCode = TextEditingController();
  final _joinCode = TextEditingController();
  ClubMemberRole _want = ClubMemberRole.coach;
  String? _msg;

  @override
  void dispose() {
    _name.dispose();
    _createCode.dispose();
    _joinCode.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await ref.read(identityProvider.notifier).createClubAsAdmin(
          name: name,
          shortCode: _createCode.text,
        );
    if (mounted) context.go(AppRoutes.homeCoach);
  }

  Future<void> _join() async {
    final r = await ref.read(identityProvider.notifier).requestClubRole(
          code: _joinCode.text,
          role: _want,
        );
    setState(() {
      _msg = r == null
          ? 'Code inconnu (en local, crée le club d’abord).'
          : 'Demande ${_want.wire} envoyée — validation admin.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(identityProvider);
    final canDecide = snap.prefs.clubRole == ClubMemberRole.admin ||
        snap.prefs.clubRole == ClubMemberRole.director;
    final pending =
        snap.joinRequests.where((r) => r.status == 'pending').toList();
    return DeckScaffold(
      title: 'CLUB',
      subtitle: 'Rejoindre ou créer',
      retourFallback: AppRoutes.clubLogin,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const Text(
            'CRÉER MON CLUB',
            style: TextStyle(
              color: DeckColors.label,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nom du club'),
          ),
          TextField(
            controller: _createCode,
            decoration: const InputDecoration(labelText: 'Code court'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _create,
            child: const Text('CRÉER LE CLUB'),
          ),
          const SizedBox(height: 24),
          const Text(
            'REJOINDRE',
            style: TextStyle(
              color: DeckColors.label,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          TextField(
            controller: _joinCode,
            decoration: const InputDecoration(labelText: 'Code club'),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final r in const [
                ClubMemberRole.coach,
                ClubMemberRole.intendant,
                ClubMemberRole.director,
                ClubMemberRole.treasurer,
              ])
                ChoiceChip(
                  label: Text(r.wire),
                  selected: _want == r,
                  onSelected: (_) => setState(() => _want = r),
                ),
            ],
          ),
          OutlinedButton(
            onPressed: _join,
            child: const Text('DEMANDER À REJOINDRE'),
          ),
          if (_msg != null)
            Text(_msg!, style: const TextStyle(color: DeckColors.amber)),
          if (canDecide) ...[
            const SizedBox(height: 24),
            const Text(
              'VALIDATION ADMIN',
              style: TextStyle(
                color: DeckColors.label,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
            ),
            if (pending.isEmpty)
              const Text(
                'Aucune demande.',
                style: TextStyle(color: DeckColors.muted),
              ),
            for (final r in pending)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r.requestedRole.wire),
                subtitle: Text(r.userId),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => ref
                          .read(identityProvider.notifier)
                          .decideJoinRequest(r, accept: true),
                      child: const Text('OK'),
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(identityProvider.notifier)
                          .decideJoinRequest(r, accept: false),
                      child: const Text('NON'),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
