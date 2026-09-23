import 'package:datar0w/widgets/deck_scaffold.dart';
import 'package:datar0w/widgets/deck_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DeckAppBar : marque + slash + titre (Stitch Deck)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: DeckAppBar(title: 'QUAI'),
          body: SizedBox.shrink(),
        ),
      ),
    );
    expect(find.byType(DataR0wMark), findsOneWidget);
    expect(find.text('/'), findsOneWidget);
    expect(find.text('QUAI'), findsOneWidget);
    expect(find.textContaining('DATAR0W /'), findsNothing);
    expect(find.textContaining('STAGE'), findsNothing);
  });

  testWidgets('DeckSessionHeader : sans Retour', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DeckSessionHeader(title: 'LIVE'),
        ),
      ),
    );
    expect(find.byType(DataR0wMark), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('Retour'), findsNothing);
  });
}
