import 'package:datar0w/features/cox/screen_cox.dart';
import 'package:datar0w/features/identity/screen_import.dart';
import 'package:datar0w/features/live/screen_3.dart';
import 'package:datar0w/router.dart';
import 'package:datar0w/widgets/deck_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('live : pas d’Accueil, pas de leading Retour', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LiveScreen())),
    );
    await tester.pump();
    expect(find.text('Accueil'), findsNothing);
    expect(find.text('Retour'), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byType(DeckRetour), findsNothing);
  });

  testWidgets('cox : pas d’Accueil, pas de leading Retour', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CoxLiveScreen())),
    );
    await tester.pump();
    expect(find.text('Accueil'), findsNothing);
    expect(find.text('Retour'), findsNothing);
    expect(find.byType(DeckRetour), findsNothing);
  });

  testWidgets('gate coach : Retour → /', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.clubImport,
      routes: [
        GoRoute(
          path: AppRoutes.profile,
          builder: (_, __) => const Text('HUB-PROFIL'),
        ),
        GoRoute(
          path: AppRoutes.clubImport,
          builder: (_, __) => const ClubImportScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    expect(find.text('Réservé au coach.'), findsOneWidget);
    expect(find.text('Retour'), findsOneWidget);
    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('HUB-PROFIL'), findsOneWidget);
  });
}
