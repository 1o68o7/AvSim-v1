import 'dart:io';

import 'package:datar0w/health/physio_store.dart';
import 'package:datar0w/sync/rls_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rower ne write pas boats / rowers', () {
    expect(rlsCanWriteBoats('rower'), isFalse);
    expect(rlsCanWriteRowers('rower'), isFalse);
    expect(rlsCanWriteBoats('cox'), isFalse);
    expect(rlsCanWriteRowers('cox'), isFalse);
    expect(rlsCanWriteBoats('coach'), isTrue);
    expect(rlsCanWriteRowers('coach'), isTrue);
    expect(rlsCanWriteBoats('intendant'), isTrue);
    expect(rlsCanWriteRowers('intendant'), isFalse);
    expect(rlsCanApproveJoin('rower'), isFalse);
    expect(rlsCanApproveJoin('director'), isTrue);
  });

  test('isolation inter-clubs', () {
    expect(
      rlsSameClubOnly(memberClub: 'club-a', rowClub: 'club-b'),
      isFalse,
    );
    expect(
      rlsSameClubOnly(memberClub: 'club-a', rowClub: 'club-a'),
      isTrue,
    );
  });

  test('SQL 0001+0004 : politiques alignées', () {
    final core = File('../../supabase/migrations/0001_identity_core.sql')
        .readAsStringSync();
    final roles = File('../../supabase/migrations/0004_club_roles.sql')
        .readAsStringSync();
    expect(core.contains("in ('admin','coach')"), isTrue);
    expect(core.contains('rowers_write'), isTrue);
    expect(core.contains('boats_write'), isTrue);
    expect(roles.contains("'intendant'"), isTrue);
    expect(roles.contains('treasurer'), isTrue);
    expect(roles.contains('director'), isTrue);
    expect(
      roles.contains("in ('admin', 'coach', 'intendant')"),
      isTrue,
    );
    final recipe = File('../../supabase/tests/isolation_rls.sql').readAsStringSync();
    expect(recipe.contains('INSERT boats'), isTrue);
    expect(recipe.contains('club B'), isTrue);
    expect(recipe.contains('session_meta'), isTrue);
    expect(recipe.contains('rower_physio'), isTrue);
  });

  test('physio RLS : coach lit, n’écrit pas ; rower écrit le sien', () {
    expect(
      rlsCanWritePhysio(authUid: 'rower-a', rowUserId: 'rower-a'),
      isTrue,
    );
    expect(
      rlsCanWritePhysio(authUid: 'coach', rowUserId: 'rower-a'),
      isFalse,
    );
    expect(
      rlsCanReadPhysio(
        authUid: 'coach',
        rowUserId: 'rower-a',
        shareWithCoach: true,
        role: 'coach',
        sameClub: true,
      ),
      isTrue,
    );
    expect(
      rlsCanReadPhysio(
        authUid: 'coach',
        rowUserId: 'rower-a',
        shareWithCoach: false,
        role: 'coach',
        sameClub: true,
      ),
      isFalse,
    );
    expect(
      rlsCanWriteSessionMeta(
        authUid: 'rower-a',
        ownerUserId: 'rower-b',
        sameClub: true,
      ),
      isFalse,
    );
    final sql = File('../../supabase/migrations/0006_rower_physio.sql')
        .readAsStringSync();
    expect(sql.contains('user_id = auth.uid()'), isTrue);
    expect(sql.contains("club_role(club_id) in ('admin', 'coach')"), isTrue);
    expect(sql.contains('for delete'), isTrue);
  });
}
