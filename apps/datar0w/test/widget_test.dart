import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:datar0w/app.dart';

void main() {
  testWidgets('écran 1 profils Deck', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: DataR0wApp()),
    );
    expect(find.textContaining('DATA'), findsWidgets);
    expect(find.text('RAMEUR'), findsOneWidget);
    expect(find.text('COACH'), findsOneWidget);
    expect(find.text('BARREUR'), findsOneWidget);
  });
}
