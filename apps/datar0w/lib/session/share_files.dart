import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import 'store.dart';

/// imu.jsonl n’est joint que s’il pèse moins de 20 Mio.
const int kImuShareMaxBytes = 20 * 1024 * 1024;

/// Zip bulk : au-delà, snackbar, pas de crash.
const int kBulkZipMaxBytes = 100 * 1024 * 1024;

String sessionShareStem({String? code, required String sessionId}) {
  final c = (code ?? '')
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (c.isNotEmpty) return c;
  final id = sessionId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  return id.isEmpty ? 'seance' : id;
}

String sessionShareCaption(String stem) =>
    'DataR0w séance $stem — samples.jsonl';

String bulkZipFileName(DateTime now) {
  final l = now.toLocal();
  final y = l.year.toString().padLeft(4, '0');
  final m = l.month.toString().padLeft(2, '0');
  final d = l.day.toString().padLeft(2, '0');
  return 'datarow-seances-$y$m$d.zip';
}

/// Fichiers à partager : samples.jsonl + meta.json, imu.jsonl optionnel.
List<File> sessionShareFiles(
  Directory sessionDir, {
  int imuMaxBytes = kImuShareMaxBytes,
}) {
  final out = <File>[];
  final samples = File(p.join(sessionDir.path, 'samples.jsonl'));
  final meta = File(p.join(sessionDir.path, 'meta.json'));
  if (samples.existsSync()) out.add(samples);
  if (meta.existsSync()) out.add(meta);
  final imu = File(p.join(sessionDir.path, 'imu.jsonl'));
  if (imu.existsSync()) {
    final n = imu.lengthSync();
    if (n > 0 && n < imuMaxBytes) out.add(imu);
  }
  return out;
}

/// Noms lisibles (copie hors `sessions/`) : `GCZEKF-samples.jsonl`.
List<String> sessionShareDisplayNames(Directory sessionDir, String stem) =>
    [
      for (final f in sessionShareFiles(sessionDir))
        '$stem-${p.basename(f.path)}',
    ];

Future<List<XFile>> copySessionShareNamed(
  Directory sessionDir,
  String stem, {
  Directory? dest,
}) async {
  final tmp = dest ?? await Directory.systemTemp.createTemp('datar0w_share_');
  await tmp.create(recursive: true);
  final out = <XFile>[];
  for (final f in sessionShareFiles(sessionDir)) {
    final name = '$stem-${p.basename(f.path)}';
    final copy = await f.copy(p.join(tmp.path, name));
    out.add(XFile(copy.path, name: name));
  }
  return out;
}

class BulkZipPrep {
  const BulkZipPrep.zip(this.bytes) : tooHeavy = false;
  const BulkZipPrep.tooHeavy()
      : bytes = null,
        tooHeavy = true;

  final Uint8List? bytes;
  final bool tooHeavy;
}

/// Zip des jsonl + meta des séances cochées. `tooHeavy` si > 100 Mio.
BulkZipPrep zipSessionsShare(
  List<({Directory dir, String stem})> sessions,
) {
  final archive = Archive();
  var total = 0;
  for (final s in sessions) {
    for (final f in sessionShareFiles(s.dir)) {
      final data = f.readAsBytesSync();
      total += data.length;
      if (total > kBulkZipMaxBytes) {
        return const BulkZipPrep.tooHeavy();
      }
      final name = '${s.stem}-${p.basename(f.path)}';
      archive.addFile(
        ArchiveFile(name, data.length, data)..lastModTime = 0,
      );
    }
  }
  final encoded = ZipEncoder().encode(archive);
  if (encoded == null || encoded.length > kBulkZipMaxBytes) {
    return const BulkZipPrep.tooHeavy();
  }
  return BulkZipPrep.zip(Uint8List.fromList(encoded));
}

Future<void> shareLocalSession(String sessionId, {Directory? root}) async {
  final base = root ?? await SessionStore.sessionsRootIfPresent();
  if (base == null) return;
  final dir = Directory(p.join(base.path, sessionId));
  if (!dir.existsSync()) return;
  final meta = await SessionStore.loadMeta(sessionId, root: base);
  final stem = sessionShareStem(code: meta?.code, sessionId: sessionId);
  final files = await copySessionShareNamed(dir, stem);
  if (files.isEmpty) return;
  await SharePlus.instance.share(
    ShareParams(
      files: files,
      text: sessionShareCaption(stem),
    ),
  );
}

Future<BulkZipPrep> prepareBulkSessionZip(
  List<String> sessionIds, {
  Directory? root,
  DateTime? now,
}) async {
  final base = root ?? await SessionStore.sessionsRootIfPresent();
  if (base == null) return const BulkZipPrep.tooHeavy();
  final items = <({Directory dir, String stem})>[];
  for (final id in sessionIds) {
    final dir = Directory(p.join(base.path, id));
    if (!dir.existsSync()) continue;
    final meta = await SessionStore.loadMeta(id, root: base);
    items.add((
      dir: dir,
      stem: sessionShareStem(code: meta?.code, sessionId: id),
    ));
  }
  return zipSessionsShare(items);
}

Future<void> shareBulkSessionZip(
  List<String> sessionIds, {
  Directory? root,
  DateTime? now,
}) async {
  final prep = await prepareBulkSessionZip(sessionIds, root: root, now: now);
  if (prep.tooHeavy || prep.bytes == null) return;
  final name = bulkZipFileName(now ?? DateTime.now());
  final tmp = await Directory.systemTemp.createTemp('datar0w_bulk_');
  final zip = File(p.join(tmp.path, name));
  await zip.writeAsBytes(prep.bytes!);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(zip.path, name: name)],
      text: 'DataR0w séances — samples.jsonl',
    ),
  );
}
