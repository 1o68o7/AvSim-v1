import 'package:datar0w/app.dart';
import 'package:datar0w/features/identity/screen_who.dart';
import 'package:datar0w/identity/controller.dart';
import 'package:datar0w/identity/models.dart';
import 'package:datar0w/identity/store.dart';
import 'package:datar0w/router.dart';
import 'package:datar0w/sync/auth_google.dart';
import 'package:datar0w/sync/auth_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'identity_test_helpers.dart';

/// Liens auth inertes — pas de deep link pendant le test nav.
class _NoLinks implements AuthLinkSource {
  @override
  Future<Uri?> initialLink() async => null;

  @override
  Stream<Uri> get links => const Stream.empty();
}

class _SeededIdentity extends IdentityController {
  _SeededIdentity(this.rower);
  final Rower rower;

  @override
  IdentitySnapshot build() => IdentitySnapshot(
        rowers: [rower],
        prefs: IdentityPrefs(activeRowerId: rower.id),
      );

  @override
  Future<void> selectRower(String? id) async {
    state = IdentitySnapshot(
      rowers: state.rowers,
      prefs: state.prefs.copyWith(activeRowerId: id),
    );
  }
}

void main() {
  tearDown(() {
    debugHidePasserSansProfil = false;
    // Remet le singleton pour les tests suivants.
    appRouter.go(AppRoutes.identity);
  });

  testWidgets(
    'Connexion → /auth via vrai appRouter (DataR0wApp)',
    (tester) async {
      appRouter.go(AppRoutes.identity);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityStoreOverride(),
            authGoogleProvider.overrideWithValue(AuthGoogle()),
            authLinkSourceProvider.overrideWithValue(_NoLinks()),
          ],
          child: DataR0wApp(router: appRouter),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(appRouter.state.uri.path, AppRoutes.identity);
      expect(find.text('Profils'), findsOneWidget);

      await tester.tap(find.text('Connexion'));
      // go 300 ms (+ éventuel push 300 ms)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(appRouter.state.uri.path, AppRoutes.auth);
      expect(find.text('CONNEXION'), findsOneWidget);
      expect(find.textContaining('Navigation bloquée'), findsNothing);
    },
  );

  testWidgets(
    'tap profil jouable → /home/rower via appRouter',
    (tester) async {
      final rower = Rower.create(
        displayName: 'Camille Test',
        birthDate: DateTime(1998, 5, 10),
      );
      appRouter.go(AppRoutes.identity);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityStoreOverride(),
            identityProvider.overrideWith(() => _SeededIdentity(rower)),
            authGoogleProvider.overrideWithValue(AuthGoogle()),
            authLinkSourceProvider.overrideWithValue(_NoLinks()),
          ],
          child: DataR0wApp(router: appRouter),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Camille Test'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(appRouter.state.uri.path, AppRoutes.homeRower);
      expect(find.text("Aujourd'hui"), findsWidgets);
      expect(find.textContaining('Navigation bloquée'), findsNothing);
    },
  );
}
