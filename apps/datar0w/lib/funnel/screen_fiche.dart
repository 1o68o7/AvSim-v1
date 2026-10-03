import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../identity/controller.dart';
import '../identity/models.dart';
import '../router.dart';
import '../sync/club_sql.dart';
import '../sync/club_remote.dart';
import '../theme/deck_theme.dart';
import 'account_gate.dart';
import 'boat_fiche.dart';
import 'fiche_revoke_store.dart';

/// Page minimale / deep link `datarow://fiche/{token}`.
class FunnelFicheScreen extends ConsumerStatefulWidget {
  const FunnelFicheScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<FunnelFicheScreen> createState() => _FunnelFicheScreenState();
}

class _FunnelFicheScreenState extends ConsumerState<FunnelFicheScreen> {
  BoatFichePayload? _payload;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = decodeFicheToken(widget.token);
    if (p == null) {
      setState(() => _error = 'Fiche introuvable.');
      return;
    }
    final revoked = await FicheRevokeStore().isRevoked(p.tokenId);
    if (revoked || p.revoked) {
      setState(() {
        _payload = p.copyWith(revoked: true);
        _error = 'Fiche révoquée. Les sièges déjà confirmés restent.';
      });
      return;
    }
    if (p.isExpired) {
      setState(() {
        _payload = p;
        _error = 'Créneau terminé — fiche expirée.';
      });
      return;
    }
    setState(() => _payload = p);
  }

  Future<void> _claim(int seatIndex) async {
    final payload = _payload;
    if (payload == null || !payload.isValid) return;

    final signed = await AccountGate.ensureSignedIn(
      context,
      ref,
      reason: 'Compte requis pour prendre un siège',
    );
    if (!signed || !mounted) return;
    await AccountGate.attachActiveRower(ref);

    final snap = ref.read(identityProvider);
    final rower = snap.activeRower;
    if (rower == null) {
      setState(() => _error = 'Profil rameur manquant.');
      return;
    }

    final lic = await ref.read(licenseStoreProvider).byRowerId(rower.id);
    if (lic == null && (rower.ffaLicence == null || rower.ffaLicence!.isEmpty)) {
      setState(() =>
          _error = 'Sans licence : la fiche est visible, le siège est refusé.');
      return;
    }
    if (lic != null && lic.isExpired) {
      setState(() => _error = 'Licence périmée — siège non confirmé.');
      return;
    }

    final sameClub = rower.clubId == payload.clubId;
    if (!sameClub) {
      final home = snap.activeClub?.name ?? 'ton club';
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: DeckColors.surface,
          title: const Text(
            'Autre club',
            style: TextStyle(color: DeckColors.text),
          ),
          content: Text(
            'Tu es à ${payload.clubName}. Ta licence est à $home. '
            'Tu peux prendre le siège pour ce créneau — club de licence inchangé.',
            style: const TextStyle(color: DeckColors.label),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Je prends le siège $seatIndex'),
            ),
          ],
        ),
      );
      if (go != true) return;
    }

    setState(() => _busy = true);
    try {
      final asg = Assignment.create(
        boatId: payload.boatId,
        rowerId: rower.id,
        side: SidePref.none,
        seatIndex: seatIndex,
      );
      final existing = snap.assignmentsForBoat(payload.boatId);
      final next = [
        ...existing.where((a) => a.seatIndex != seatIndex),
        asg,
      ];
      await ref.read(identityProvider.notifier).saveCrew(payload.boatId, next);
      await ref.read(clubRemoteProvider).upsertAssignment(
            assignmentToSql(asg, payload.clubId),
          );

      final free = payload.freeSeatIndexes.where((i) => i != seatIndex).toList();
      final confirmed = Map<int, String>.from(payload.confirmedSeats);
      confirmed[seatIndex] = rower.displayName.split(' ').first;
      setState(() {
        _payload = payload.copyWith(
          freeSeatIndexes: free,
          confirmedSeats: confirmed,
        );
        _busy = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Siège $seatIndex pris')),
        );
      }
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Impossible d’écrire le siège.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _payload;
    return Scaffold(
      backgroundColor: DeckColors.bg,
      appBar: AppBar(
        backgroundColor: DeckColors.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: DeckColors.text),
          onPressed: () => context.go(AppRoutes.homeRower),
        ),
        title: const Text(
          'Fiche bateau',
          style: TextStyle(
            fontFamily: DeckType.ui,
            fontWeight: FontWeight.w600,
            color: DeckColors.text,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: p == null
              ? Center(
                  child: Text(
                    _error ?? 'Chargement…',
                    style: DeckType.uiLabel(),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      p.clubName,
                      style: DeckType.uiLabel(color: DeckColors.label),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${p.boatName} · ${p.boatClass}',
                      key: const Key('fiche-boat-title'),
                      style: const TextStyle(
                        fontFamily: DeckType.ui,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: DeckColors.text,
                      ),
                    ),
                    Text(
                      p.shareHeadline(),
                      style: DeckType.labelMono(size: 13),
                    ),
                    if (p.cox)
                      Text('Barreur requis', style: DeckType.uiLabel()),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: DeckType.uiLabel(color: DeckColors.amber),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text('Confirmés', style: DeckType.uiLabel()),
                    const SizedBox(height: 6),
                    if (p.confirmedSeats.isEmpty)
                      Text('Aucun', style: DeckType.labelMono())
                    else
                      ...p.confirmedSeats.entries.map(
                        (e) => Text(
                          'Siège ${e.key} · ${e.value}',
                          style: DeckType.labelMono(),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text('Libres', style: DeckType.uiLabel()),
                    const SizedBox(height: 8),
                    if (!p.isValid || p.freeSeatIndexes.isEmpty)
                      Text(
                        p.freeSeatIndexes.isEmpty
                            ? 'Plus de siège libre'
                            : 'Fiche inactive',
                        style: DeckType.labelMono(),
                      )
                    else
                      ...p.freeSeatIndexes.map(
                        (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SizedBox(
                            height: 48,
                            child: FilledButton(
                              key: Key('fiche-claim-$i'),
                              onPressed: _busy ? null : () => _claim(i),
                              child: Text('Je prends le siège $i'),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
