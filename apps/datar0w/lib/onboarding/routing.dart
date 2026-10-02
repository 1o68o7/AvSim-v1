import '../identity/controller.dart';
import '../identity/models.dart';
import '../router.dart';
import '../session/boat_config.dart';

enum OnboardingDoor { rower, club }

const clubStaffRoles = {
  'admin',
  'coach',
  'treasurer',
  'intendant',
  'director',
};

bool isClubStaffRole(String? role) =>
    role != null && clubStaffRoles.contains(role);

/// Profil local jouable (nom non vide). Sinon → onboarding.
bool isRowerProfilePlayable(Rower r) => r.displayName.trim().isNotEmpty;

/// Après login / redirect `/` : jamais `/` ni `ProfileScreen`.
/// Porte club anonyme n’envoie plus vers `/club/join`.
String resolvePostLogin({
  required OnboardingDoor door,
  String? clubMemberRole,
  bool skipAccount = false,
  bool hasRowerProfile = false,
}) {
  // Sans compte / passer → vitrine club (pas stack eau).
  if (skipAccount) return AppRoutes.discover;

  if (isClubStaffRole(clubMemberRole)) {
    return homeRouteForClubRole(clubMemberRole!);
  }
  if (clubMemberRole == 'cox') {
    return hasRowerProfile ? AppRoutes.homeCox : AppRoutes.rowerOnboard;
  }
  if (clubMemberRole == 'rower') {
    return hasRowerProfile ? AppRoutes.homeRower : AppRoutes.rowerOnboard;
  }

  return hasRowerProfile ? AppRoutes.homeRower : AppRoutes.rowerOnboard;
}

/// Redirect de `path: '/'` selon l’identité locale (pas de builder ProfileScreen).
String resolveRootRedirect(IdentitySnapshot snap) {
  final role = snap.prefs.activeClubId != null
      ? snap.prefs.clubRole.name
      : null;
  final rower = snap.activeRower;
  final hasPlayable =
      rower != null && isRowerProfilePlayable(rower);
  final hasAnyProfile = snap.rowers.isNotEmpty;

  if (isClubStaffRole(role)) {
    return homeRouteForClubRole(role!);
  }
  if (role == 'cox' && hasPlayable) return AppRoutes.homeCox;
  if (hasPlayable) return AppRoutes.homeRower;
  if (hasAnyProfile && rower != null && !isRowerProfilePlayable(rower)) {
    return AppRoutes.rowerOnboard;
  }
  // Cold start sans profil → porte club, pas `/identity`.
  if (!hasAnyProfile) return AppRoutes.discover;
  return AppRoutes.rowerOnboard;
}

/// Licence FFA requise pour le tunnel eau si un profil rameur est actif.
bool needsLicence(IdentitySnapshot snap) {
  final rower = snap.activeRower;
  if (rower == null) return false;
  final lic = rower.ffaLicence?.trim();
  return lic == null || lic.isEmpty;
}

/// Routes tunnel eau : pré-session → tare → live / cox.
bool isWaterSessionPath(String path) =>
    path == AppRoutes.presession ||
    path == AppRoutes.tare ||
    path == AppRoutes.live ||
    path == AppRoutes.cox;

/// `null` = accès OK ; sinon → onboarding licence.
String? waterLicenceRedirect(IdentitySnapshot snap) {
  if (!needsLicence(snap)) return null;
  return AppRoutes.rowerOnboard;
}

/// Accueil selon le rôle **séance** (quai, retours Deck).
String sessionRoleHome(CrewRole role) => switch (role) {
      CrewRole.rower => AppRoutes.homeRower,
      CrewRole.cox => AppRoutes.homeCox,
      CrewRole.coach => AppRoutes.homeCoach,
    };

/// Routes écriture club : import, sessions cloud, crew, ops.
bool isClubStaffToolsPath(String path) {
  if (path == AppRoutes.clubImport ||
      path == AppRoutes.clubSessions ||
      path == AppRoutes.crew ||
      path == AppRoutes.opsOut ||
      path == AppRoutes.opsIn ||
      path == AppRoutes.opsDeparture ||
      path == AppRoutes.opsMaintenance) {
    return true;
  }
  if (path.startsWith('${AppRoutes.clubSessions}/')) return true;
  if (path.startsWith('/ops/')) return true;
  return false;
}

/// `null` = accès OK ; sinon destination de redirect (rameur/cox).
String? clubStaffToolsRedirect(IdentitySnapshot snap) {
  final role = snap.prefs.clubRole.name;
  if (isClubStaffRole(role)) return null;
  return AppRoutes.homeRower;
}

String homeRouteForClubRole(String role) {
  switch (role) {
    case 'cox':
      return AppRoutes.homeCox;
    case 'rower':
      return AppRoutes.homeRower;
    case 'coach':
      return AppRoutes.homeCoach;
    case 'admin':
      return AppRoutes.homeAdmin;
    case 'intendant':
      return AppRoutes.homeIntendant;
    case 'director':
      return AppRoutes.homeDirector;
    case 'treasurer':
      return AppRoutes.homeTreasurer;
    default:
      return AppRoutes.homeRower;
  }
}

String homeRouteForClubMemberRole(ClubMemberRole role) =>
    homeRouteForClubRole(role.wire);
