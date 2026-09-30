import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'session/session_sync.dart';
import 'sync/auth_session.dart';
import 'theme/deck_theme.dart';

class DataR0wApp extends StatelessWidget {
  const DataR0wApp({super.key, this.router});

  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    final cfg = router ?? appRouter;
    // AuthSessionBinder hors MaterialApp (écoute intents).
    // SessionSyncHost DANS builder MaterialApp : la bannière sync ne doit
    // JAMAIS remonter MaterialApp.router (sinon reset → /identity).
    return AuthSessionBinder(
      router: cfg,
      child: MaterialApp.router(
        title: 'DataR0w',
        debugShowCheckedModeBanner: false,
        theme: buildDeckTheme(),
        routerConfig: cfg,
        builder: (context, child) => SessionSyncHost(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
