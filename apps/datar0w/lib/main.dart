import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'session/session_fgs.dart';
import 'session/session_sync.dart';
import 'sync/supabase_boot.dart';
import 'sync/telemetry_upload.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SessionSync.resolveGateway = liveTelemetryGateway;
  unawaited(initSessionForegroundTask());
  unawaited(bootSupabase());
  runApp(const ProviderScope(child: DataR0wApp()));
}
