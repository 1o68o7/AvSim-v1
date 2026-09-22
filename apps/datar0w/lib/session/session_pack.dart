import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Noms packés (ordre lexicographique = hash stable).
const kSessionPackNames = [
  'cardio.jsonl',
  'imu.jsonl',
  'meta.json',
  'notes.json',
  'samples.jsonl',
];

class SessionPack {
  const SessionPack({
    required this.bytes,
    required this.sha256hex,
  });

  final Uint8List bytes;
  final String sha256hex;
}

/// Zip déterministe des fichiers séance. Absent = omis (pas d’entrée vide).
SessionPack packSessionDir(Directory dir) {
  final archive = Archive();
  for (final name in kSessionPackNames) {
    final f = File(p.join(dir.path, name));
    if (!f.existsSync()) continue;
    final data = f.readAsBytesSync();
    final entry = ArchiveFile(name, data.length, data)
      ..lastModTime = 0
      ..crc32 = getCrc32(data);
    archive.addFile(entry);
  }
  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw StateError('zip vide');
  }
  final bytes = Uint8List.fromList(encoded);
  return SessionPack(
    bytes: bytes,
    sha256hex: sha256.convert(bytes).toString(),
  );
}

void unpackSessionBytes(Uint8List bytes, Directory dest) {
  dest.createSync(recursive: true);
  final archive = ZipDecoder().decodeBytes(bytes);
  for (final entry in archive) {
    if (!entry.isFile) continue;
    if (!kSessionPackNames.contains(entry.name)) continue;
    final out = File(p.join(dest.path, entry.name));
    out.writeAsBytesSync(entry.content as List<int>);
  }
}
