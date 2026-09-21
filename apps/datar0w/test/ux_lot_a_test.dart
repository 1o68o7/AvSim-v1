import 'package:datar0w/features/identity/screen_who.dart';
import 'package:datar0w/features/presession/screen_2a.dart';
import 'package:datar0w/features/tare/screen_2b.dart';
import 'package:datar0w/identity/controller.dart';
import 'package:datar0w/identity/models.dart';
import 'package:datar0w/theme/deck_theme.dart';
import 'package:datar0w/widgets/deck_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _DeleteProbe extends IdentityController {
  _DeleteProbe(this.seed);
  final Rower seed;
  int deleteCalls = 0;

  @override
  IdentitySnapshot build() => IdentitySnapshot(rowers: [seed]);

  @override
  Future<void> deleteRower(String id) async {
    deleteCalls++;
    state = IdentitySnapshot(
      rowers: state.rowers.where((r) => r.id != id).toList(),
    );
  }
}

void main() {
  test('ColorScheme.error distinct de l’ambre CTA', () {
    final t = buildDeckTheme();
    expect(t.colorScheme.error, DeckColors.error);
    expect(t.colorScheme.error, isNot(DeckColors.amber));
    expect(t.colorScheme.primary, DeckColors.amber);
  });

  testWidgets('AppBar titre 14–16 px', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DeckScaffold(title: 'QUI RAME ?', body: SizedBox.shrink()),
      ),
    );
    final text = tester.widget<Text>(find.text('QUI RAME ?'));
    final size = text.style?.fontSize ?? 0;
    expect(size, inInclusiveRange(14, 16));
  });

  testWidgets('pré-session : titre humain, pas de 2A', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PresessionScreen())),
    );
    expect(find.text('PRÉ-SESSION'), findsOneWidget);
    expect(find.textContaining('2A'), findsNothing);
    expect(find.textContaining('DATAR0W /'), findsNothing);
  });

  testWidgets('tare portrait : titre humain, pas de 2B', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TareScreen())),
    );
    await tester.pump();
    expect(find.text('ÉTALONNAGE / TARE'), findsOneWidget);
    expect(find.textContaining('2B'), findsNothing);
    expect(find.textContaining('DATAROW /'), findsNothing);
  });

  Future<void> pumpWho(WidgetTester tester, _DeleteProbe probe) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityProvider.overrideWith(() => probe)],
        child: const MaterialApp(home: IdentityListScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('delete : tap icône n’efface pas sans confirmer', (tester) async {
    final probe = _DeleteProbe(
      Rower.create(displayName: 'Camille Test', birthDate: DateTime(1998, 5, 10)),
    );
    await pumpWho(tester, probe);
    expect(find.text('Camille Test'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    expect(find.text('Supprimer ce profil ?'), findsOneWidget);
    expect(find.text('Camille Test'), findsWidgets);
    expect(probe.deleteCalls, 0);
  });

  testWidgets('delete : ANNULER conserve le profil', (tester) async {
    final probe = _DeleteProbe(
      Rower.create(displayName: 'Camille Test', birthDate: DateTime(1998, 5, 10)),
    );
    await pumpWho(tester, probe);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.tap(find.text('ANNULER'));
    await tester.pump();
    expect(find.text('Camille Test'), findsOneWidget);
    expect(probe.deleteCalls, 0);
  });

  testWidgets('delete : SUPPRIMER retire le profil', (tester) async {
    final probe = _DeleteProbe(
      Rower.create(displayName: 'Camille Test', birthDate: DateTime(1998, 5, 10)),
    );
    await pumpWho(tester, probe);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.tap(find.text('SUPPRIMER'));
    await tester.pump();
    expect(find.text('Camille Test'), findsNothing);
    expect(probe.deleteCalls, 1);
  });
}
