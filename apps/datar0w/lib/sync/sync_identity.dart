import '../identity/store.dart';
import 'supabase_boot.dart';

/// auth.uid() courant — jamais l’id rameur local.
String? defaultOwnerUserId() {
  try {
    final id = supabaseOrNull()?.auth.currentUser?.id;
    return id is String && id.isNotEmpty ? id : null;
  } catch (_) {
    return null;
  }
}

/// Club actif (prefs) — uuid club pour session_meta / Storage.
String? defaultActiveClubId() {
  try {
    final id = IdentityStore().tryLoadPrefsSync()?.activeClubId;
    return id != null && id.isNotEmpty ? id : null;
  } catch (_) {
    return null;
  }
}
