/// Miroir des politiques SQL 0001 + 0004 (tests d’isolation hors Postgres).
bool rlsCanWriteBoats(String role) =>
    role == 'admin' || role == 'coach' || role == 'intendant';

bool rlsCanWriteRowers(String role) => role == 'admin' || role == 'coach';

bool rlsCanApproveJoin(String role) => role == 'admin' || role == 'director';

bool rlsSameClubOnly({required String memberClub, required String rowClub}) =>
    memberClub == rowClub;
