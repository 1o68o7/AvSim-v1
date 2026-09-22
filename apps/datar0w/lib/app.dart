import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'sync/auth_session.dart';
import 'theme/deck_theme.dart';

class DataR0wApp extends StatelessWidget {
  const DataR0wApp({super.key, this.router});

  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    final cfg = router ?? appRouter;
    return AuthSessionBinder(
      router: cfg,
      child: MaterialApp.router(
        title: 'DataR0w',
        debugShowCheckedModeBanner: false,
        theme: buildDeckTheme(),
        routerConfig: cfg,
      ),
    );
  }
}
