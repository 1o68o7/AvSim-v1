import 'dart:io';

import 'package:share_plus/share_plus.dart';

import 'store.dart';

/// imu.jsonl n’est joint que s’il pèse moins de 20 Mio.
const int kImuShareMaxBytes = 20 * 1024 * 1024;

/// Fichiers à partager : samples.jsonl + meta.json, imu.jsonl optionnel.
List<File> sessionShareFiles(
  Directory sessionDir, {
  int imuMaxBytes = kImuShareMaxBytes,
}) {
  final out = <File>[];
  final samples = File('${sessionDir.path}/samples.jsonl');
  final meta = File('${sessionDir.path}/meta.json');
  if (samples.existsSync()) out.add(samples);
  if (meta.existsSync()) out.add(meta);
  final imu = File('${sessionDir.path}/imu.jsonl');
  if (imu.existsSync()) {
    final n = imu.lengthSync();
    if (n > 0 && n < imuMaxBytes) out.add(imu);
  }
  return out;
}

Future<void> shareLocalSession(String sessionId, {Directory? root}) async {
  final base = root ?? await SessionStore.sessionsRootIfPresent();
  if (base == null) return;
  final dir = Directory('${base.path}/$sessionId');
  if (!dir.existsSync()) return;
  final files = sessionShareFiles(dir);
  if (files.isEmpty) return;
  await SharePlus.instance.share(
    ShareParams(
      files: files.map((f) => XFile(f.path)).toList(),
      text: 'DataR0w séance (samples.jsonl + meta.json)',
    ),
  );
}
