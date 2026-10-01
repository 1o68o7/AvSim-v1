import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../identity/controller.dart';
import '../identity/models.dart';
import '../router.dart';
import '../theme/deck_theme.dart';
import '../widgets/deck_scaffold.dart';
import 'routing.dart';

class ClubJoinScreen extends ConsumerStatefulWidget {
  const ClubJoinScreen({super.key});

  @override
  ConsumerState<ClubJoinScreen> createState() => _ClubJoinScreenState();
}

class _ClubJoinScreenState extends ConsumerState<ClubJoinScreen> {
  final _name = TextEditingController();
  final _createCode = TextEditingController();
  final _joinCode = TextEditingController();
  ClubMemberRole _want = ClubMemberRole.rower;
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
    if (name.isEmpty) {
      setState(() => _msg = 'Indique un nom de club.');
      return;
    }
    await ref.read(identityProvider.notifier).createClubAsAdmin(
          name: name,
          shortCode: _createCode.text,
        );
    if (!mounted) return;
    final snap = ref.read(identityProvider);
    context.go(homeRouteForClubMemberRole(snap.prefs.clubRole));
  }

  Future<void> _join() async {
    final r = await ref.read(identityProvider.notifier).requestClubRole(
          code: _joinCode.text,
          role: _want,
        );
    setState(() {
      _msg = r == null
          ? 'Code club introuvable. Vérifie le code ou crée le club.'
          : 'Demande « ${_want.labelFr} » envoyée — en attente de validation.';
    });
  }

  String _requesterLabel(IdentitySnapshot snap, ClubJoinRequest r) {
    for (final rower in snap.rowers) {
      if (rower.userId == r.userId && rower.displayName.trim().isNotEmpty) {
        return rower.displayName.trim();
      }
    }
    final short = r.userId.length <= 8 ? r.userId : '${r.userId.substring(0, 8)}…';
    return 'Compte $short';
  }

  Future<void> _decide(ClubJoinRequest r, {required bool accept}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DeckColors.surface,
        title: Text(accept ? 'Accepter la demande ?' : 'Refuser la demande ?'),
        content: Text(
          '${_requesterLabel(ref.read(identityProvider), r)} — ${r.requestedRole.labelFr}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(accept ? 'Accepter' : 'Refuser'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(identityProvider.notifier).decideJoinRequest(r, accept: accept);
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
      retourFallback: homeRouteForClubMemberRole(snap.prefs.clubRole),
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
                ClubMemberRole.rower,
                ClubMemberRole.cox,
                ClubMemberRole.coach,
                ClubMemberRole.intendant,
                ClubMemberRole.director,
                ClubMemberRole.treasurer,
              ])
                ChoiceChip(
                  label: Text(r.labelFr),
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
            Text(_msg!, style: const TextStyle(color: DeckColors.volt)),
          if (canDecide) ...[
            const SizedBox(height: 24),
            const Text(
              'DEMANDES À VALIDER',
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
                title: Text(_requesterLabel(snap, r)),
                subtitle: Text('Rôle demandé : ${r.requestedRole.labelFr}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _decide(r, accept: true),
                      child: const Text('Accepter'),
                    ),
                    TextButton(
                      onPressed: () => _decide(r, accept: false),
                      child: const Text('Refuser'),
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
