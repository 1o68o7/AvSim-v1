import 'package:datar0w/app.dart';
import 'package:datar0w/router.dart';
import 'package:datar0w/session/session_sync.dart';
import 'package:datar0w/sync/auth_google.dart';
import 'package:datar0w/sync/auth_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'identity_test_helpers.dart';

class _NoLinks implements AuthLinkSource {
  @override
  Future<Uri?> initialLink() async => null;

  @override
  Stream<Uri> get links => const Stream.empty();
}

void main() {
  tearDown(() {
    appRouter.go(AppRoutes.identity);
  });

  testWidgets('SessionSyncHost : arbre toujours Stack (pas child↔Stack)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SessionSyncHost(
          child: Scaffold(body: Text('body')),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (w) => w is Stack && w.fit == StackFit.expand,
      ),
      findsOneWidget,
    );
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets(
    'DataR0wApp : Connexion → /auth (SessionSyncHost dans builder)',
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
      await tester.pump(const Duration(milliseconds: 80));

      await tester.tap(find.text('Connexion'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(appRouter.state.uri.path, AppRoutes.auth);
      expect(find.text('CONNEXION'), findsOneWidget);
      expect(find.textContaining('Navigation bloquée'), findsNothing);
    },
  );
}
