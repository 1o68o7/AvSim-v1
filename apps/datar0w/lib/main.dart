import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'session/session_fgs.dart';
import 'sync/supabase_boot.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(() async {
    await bootSupabase();
    await initSessionForegroundTask();
  }());
  runApp(const ProviderScope(child: DataR0wApp()));
}
