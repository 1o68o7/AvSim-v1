import 'package:flutter/foundation.dart';

import '../identity/models.dart';
import '../identity/store.dart';
import 'club_remote.dart';
import 'supabase_boot.dart';

/// auth.uid() courant — jamais l’id rameur local.
String? defaultOwnerUserId() {
  try {
    final id = supabaseOrNull()?.auth.currentUser?.id;
    return (id != null && id.isNotEmpty) ? id : null;
  } catch (_) {
    return null;
  }
}

/// Club actif (prefs) — uuid club pour session_meta / Storage.
/// Relit le disque si le root IdentityStore est résolu ; sinon la mémoire
/// posée par hydrate/saveState (pas un cache figé au cold start).
String? defaultActiveClubId() {
  try {
    final id = IdentityStore().tryLoadPrefsSync()?.activeClubId;
    if (id != null && id.isNotEmpty) return id;
  } catch (_) {}
  final mem = rememberedActiveClubId();
  if (mem != null && mem.isNotEmpty) return mem;
  return null;
}

/// Si `prefs.activeClubId` est null et que `auth.uid()` a au moins un
/// `club_members` → écrit activeClubId (+ rôle). Un seul membership → ce
/// club ; plusieurs → le premier. Ne crée pas de 2ᵉ club (pas d’UUID inventé).
Future<String?> ensureActiveClubForSync({
  IdentityStore? store,
  ClubRemote? remote,
  String? Function()? resolveOwnerUserId,
}) async {
  final s = store ?? IdentityStore();
  try {
    await s.root();
  } catch (e) {
    debugPrint('ensureActiveClubForSync root: $e');
  }

  IdentityPrefs prefs;
  try {
    prefs = await s.loadState();
  } catch (_) {
    prefs = const IdentityPrefs();
  }

  final existing = prefs.activeClubId;
  if (existing != null && existing.isNotEmpty) {
    notifyActiveClubId(existing);
    return existing;
  }

  final uid = resolveOwnerUserId?.call() ?? defaultOwnerUserId();
  if (uid == null || uid.isEmpty) {
    notifyActiveClubId(null);
    return null;
  }

  final r = remote ?? LiveClubRemote();
  RemoteMembership? m;
  try {
    m = await r.membershipFor(uid);
  } catch (e) {
    debugPrint('ensureActiveClubForSync membershipFor: $e');
    m = null;
  }
  if (m == null) {
    notifyActiveClubId(null);
    return null;
  }

  try {
    final clubs = await s.listClubs();
    final known = clubs.any((c) => c.id == m!.clubId);
    if (!known) {
      final rc = await r.clubById(m.clubId);
      if (rc != null) {
        await s.upsertClub(
          Club(
            id: rc.id,
            name: rc.name,
            shortCode: rc.shortCode,
            createdAt: DateTime.now().toUtc(),
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('ensureActiveClubForSync mirror club: $e');
  }

  await s.saveState(
    prefs.copyWith(
      activeClubId: m.clubId,
      clubRole: ClubMemberRoleX.parse(m.role),
      activeRowerId: m.rowerId ?? prefs.activeRowerId,
    ),
  );
  // saveState → notifyActiveClubId
  return m.clubId;
}
