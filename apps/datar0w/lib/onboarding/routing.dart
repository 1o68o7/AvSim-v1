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

/// Après login : staff → `/home/{rôle}` ; rameur/cox → branche A ; skip → `/`.
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
    return hasRowerProfile ? AppRoutes.homeRower : AppRoutes.identityEdit;
  }

  if (door == OnboardingDoor.club) return AppRoutes.clubJoin;
  return hasRowerProfile ? AppRoutes.homeRower : AppRoutes.identityEdit;
}

String homeRouteForClubRole(String role) {
  switch (role) {
    case 'cox':
      return AppRoutes.homeCox;
    case 'rower':
      return AppRoutes.homeRower;
    case 'coach':
    case 'admin':
    case 'intendant':
    case 'director':
    case 'treasurer':
      return AppRoutes.homeCoach;
    default:
      return AppRoutes.homeRower;
  }
}
