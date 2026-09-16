import 'package:flutter/material.dart';

import 'router.dart';
import 'theme/deck_theme.dart';

class DataR0wApp extends StatelessWidget {
  const DataR0wApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DataR0w',
      debugShowCheckedModeBanner: false,
      theme: buildDeckTheme(),
      routerConfig: appRouter,
    );
  }
}
