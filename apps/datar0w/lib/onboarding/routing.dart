import '../identity/models.dart';
import '../router.dart';

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

/// Après login : staff → `/home/{rôle}` ; sinon rameur home / onboard.
/// Porte club anonyme n’envoie plus vers `/club/join`.
String resolvePostLogin({
  required OnboardingDoor door,
  String? clubMemberRole,
  bool skipAccount = false,
  bool hasRowerProfile = false,
}) {
  if (skipAccount) return AppRoutes.profile;

  if (isClubStaffRole(clubMemberRole)) {
    return homeRouteForClubRole(clubMemberRole!);
  }
  if (clubMemberRole == 'cox') return AppRoutes.homeCox;
  if (clubMemberRole == 'rower') {
    return hasRowerProfile ? AppRoutes.homeRower : AppRoutes.rowerOnboard;
  }

  return hasRowerProfile ? AppRoutes.homeRower : AppRoutes.rowerOnboard;
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
