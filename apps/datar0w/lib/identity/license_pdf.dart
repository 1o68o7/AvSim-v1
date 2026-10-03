import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'license.dart';

// latin1 / ascii / utf8 / base64 via dart:convert.

/// Message refus import (spec funnel v3.3).
const kLicenseUnreadableMsg = 'Ce n’est pas une licence FFA lisible.';

class LicenseParseException implements Exception {
  LicenseParseException([this.message = kLicenseUnreadableMsg]);
  final String message;
  @override
  String toString() => message;
}

/// Extraktion couche texte PDF (TCPDF / FlateDecode) + parse champs FFA.
/// OCR de repli : [ocrFallback] si la couche est vide. PDF jamais persisté.
class LicensePdfParser {
  const LicensePdfParser({this.ocrFallback});

  /// OCR optionnel (scan). Retourne texte ou null.
  final Future<String?> Function(Uint8List bytes)? ocrFallback;

  Future<LicenseDraft> parseBytes(Uint8List bytes) async {
    var text = extractPdfText(bytes);
    var source = LicenseSource.pdf;
    if (text.trim().isEmpty) {
      final ocr = ocrFallback == null ? null : await ocrFallback!(bytes);
      text = ocr?.trim() ?? '';
      source = LicenseSource.ocr;
    }
    if (text.isEmpty) {
      throw LicenseParseException();
    }
    final draft = parseLicenseText(text, source: source);
    if (!draft.isReadable) {
      throw LicenseParseException();
    }
    return draft;
  }

  /// Parse synchrone depuis texte déjà extrait (tests).
  static LicenseDraft parseLicenseText(
    String text, {
    LicenseSource source = LicenseSource.pdf,
  }) {
    final normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u00a0', ' ');
    final doubtful = <String>{};

    final licenseNumber = _firstMatch(normalized, [
      RegExp(r'(?:N[°ºo]|N°|Num[ée]ro)\s*[:\s]*([0-9]{5,12})', caseSensitive: false),
      RegExp(r'\b([0-9]{7,10})\b'),
    ]);

    final ffaCode = _firstMatch(normalized, [
      RegExp(r'\(([CDE][0-9]{5,7})\)'),
      RegExp(r'\b([CDE][0-9]{5,7})\b'),
    ])?.toUpperCase();

    final licenseType = _parseType(normalized);
    final validUntil = _parseDate(normalized, [
      RegExp(
        r"Valable\s+jusqu['’]?au\s*[:\s]*(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})",
        caseSensitive: false,
      ),
      RegExp(
        r'Validit[ée]\s*[:\s]*(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})',
        caseSensitive: false,
      ),
    ]);

    final birthDate = _parseDate(normalized, [
      RegExp(
        r'N[ée][·e]?e?\s+le\s*[:\s]*(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})',
        caseSensitive: false,
      ),
      RegExp(
        r'Date\s+de\s+naissance\s*[:\s]*(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})',
        caseSensitive: false,
      ),
    ]);

    final sex = _parseSex(normalized);
    final category = _firstMatch(normalized, [
      RegExp(
        r'Cat[ée]gorie\s*[:\s]*([A-Za-zÉéÈèÀàÙùÂâÊêÎîÔôÛûÇç0-9 \-]+)',
        caseSensitive: false,
      ),
    ])?.trim();

    final surclassement = _parseOuiNon(
      normalized,
      RegExp(r'Surclassement\s*[:\s]*(Oui|Non)', caseSensitive: false),
    );

    final handi = _firstMatch(normalized, [
      RegExp(
        r'Classification\s*(?:handi)?\s*[:\s]*([A-Za-z0-9+\- ]+)',
        caseSensitive: false,
      ),
    ])?.trim();
    final handiClean = (handi == null ||
            handi.toLowerCase() == 'vide' ||
            handi.toLowerCase() == '-' ||
            handi.isEmpty)
        ? null
        : handi;

    final clubName = _parseClubName(normalized, ffaCode);
    final names = _parseNames(normalized);

    if (licenseNumber == null) doubtful.add('licenseNumber');
    if (ffaCode == null) doubtful.add('ffaCode');
    if (validUntil == null) doubtful.add('validUntil');
    if (licenseType == null) doubtful.add('licenseType');
    if (names.$1 == null && names.$2 == null) doubtful.add('displayName');
    if (source == LicenseSource.ocr) {
      doubtful.addAll([
        'licenseNumber',
        'ffaCode',
        'validUntil',
        'licenseType',
        'category',
        'displayName',
      ]);
    }

    return LicenseDraft(
      firstName: names.$1,
      lastName: names.$2,
      birthDate: birthDate,
      sex: sex,
      licenseNumber: licenseNumber,
      licenseType: licenseType,
      validUntil: validUntil,
      ffaCode: ffaCode,
      clubName: clubName,
      category: category,
      surclassement: surclassement ?? false,
      handiClassification: handiClean,
      source: source,
      doubtfulFields: doubtful,
    );
  }
}

/// Extrait le texte des flux PDF (FlateDecode + opérateurs Tj/TJ/'/").
String extractPdfText(Uint8List bytes) {
  final raw = utf8.decode(bytes, allowMalformed: true);
  final latin = latin1.decode(bytes, allowInvalid: true);
  final combined = '$raw\n$latin';
  final buf = StringBuffer();

  // Streams FlateDecode
  final streamRe = RegExp(
    r'stream\r?\n([\s\S]*?)\r?\nendstream',
    multiLine: true,
  );
  for (final m in streamRe.allMatches(combined)) {
    final payload = m.group(1);
    if (payload == null || payload.isEmpty) continue;
    // Heuristique : chercher le bloc binaire juste après "stream\n"
    final start = m.start;
    final headerSlice = combined.substring(
      (start - 200).clamp(0, combined.length),
      start,
    );
    final isFlate = headerSlice.contains('FlateDecode') ||
        headerSlice.contains('/Fl');
    if (!isFlate) {
      buf.write(_extractOperators(payload));
      continue;
    }
    try {
      final binStart = _findStreamBytesStart(bytes, m.start);
      final binEnd = _findStreamBytesEnd(bytes, binStart);
      if (binStart >= 0 && binEnd > binStart) {
        final chunk = bytes.sublist(binStart, binEnd);
        final inflated = const ZLibDecoder().decodeBytes(chunk, verify: false);
        final text = utf8.decode(inflated, allowMalformed: true);
        buf.write(_extractOperators(text));
        buf.write('\n');
        // Aussi les chaînes littérales visibles
        buf.write(_looseStrings(text));
      }
    } catch (_) {
      buf.write(_extractOperators(payload));
    }
  }

  // Fallback : chaînes (… )Tj dans le fichier brut
  if (buf.isEmpty) {
    buf.write(_extractOperators(combined));
    buf.write(_looseStrings(combined));
  }
  return buf.toString();
}

int _findStreamBytesStart(Uint8List bytes, int approxTextOffset) {
  // Cherche "stream\n" ou "stream\r\n" près de l'offset approximatif.
  final needle = ascii.encode('stream');
  for (var i = approxTextOffset.clamp(0, bytes.length - 1);
      i < bytes.length - 8;
      i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (bytes[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (!ok) continue;
    var p = i + needle.length;
    if (p < bytes.length && bytes[p] == 0x0d) p++;
    if (p < bytes.length && bytes[p] == 0x0a) p++;
    return p;
  }
  return -1;
}

int _findStreamBytesEnd(Uint8List bytes, int start) {
  final needle = ascii.encode('endstream');
  for (var i = start; i < bytes.length - needle.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (bytes[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) {
      var end = i;
      if (end > start && bytes[end - 1] == 0x0a) end--;
      if (end > start && bytes[end - 1] == 0x0d) end--;
      return end;
    }
  }
  return bytes.length;
}

String _extractOperators(String content) {
  final out = StringBuffer();
  // (string) Tj  ou  (string) ' / "
  final tj = RegExp(r"\((?:\\.|[^\\)])*\)\s*(?:Tj|'|" + r'")');
  for (final m in tj.allMatches(content)) {
    final raw = m.group(0)!;
    final open = raw.indexOf('(');
    final close = raw.lastIndexOf(')');
    if (open < 0 || close <= open) continue;
    out.write(_unescapePdfString(raw.substring(open + 1, close)));
    out.write(' ');
  }
  // [ (a) (b) ] TJ
  final tjArr = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);
  for (final m in tjArr.allMatches(content)) {
    final inner = m.group(1) ?? '';
    for (final sm in RegExp(r'\((?:\\.|[^\\)])*\)').allMatches(inner)) {
      final s = sm.group(0)!;
      out.write(_unescapePdfString(s.substring(1, s.length - 1)));
      out.write(' ');
    }
  }
  return out.toString();
}

String _looseStrings(String content) {
  final out = StringBuffer();
  for (final m in RegExp(r'\((?:\\.|[^\\)]){3,}\)').allMatches(content)) {
    final s = m.group(0)!;
    out.write(_unescapePdfString(s.substring(1, s.length - 1)));
    out.write('\n');
  }
  return out.toString();
}

String _unescapePdfString(String s) => s
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\r', '\r')
    .replaceAll(r'\t', '\t')
    .replaceAll(r'\(', '(')
    .replaceAll(r'\)', ')')
    .replaceAll(r'\\', r'\');

String? _firstMatch(String text, List<RegExp> patterns) {
  for (final re in patterns) {
    final m = re.firstMatch(text);
    if (m != null && m.groupCount >= 1) {
      final g = m.group(1)?.trim();
      if (g != null && g.isNotEmpty) return g;
    }
  }
  return null;
}

String? _parseType(String text) {
  final paren = RegExp(r'\((A[LC]|II|E|AC|JP)\)').firstMatch(text);
  if (paren != null) {
    final code = paren.group(1)!;
    if (code == 'AL') return 'AL';
    if (code == 'AC') return 'AC';
    return code;
  }
  if (RegExp(r'Annuelle\s+loisir', caseSensitive: false).hasMatch(text)) {
    return 'AL';
  }
  if (RegExp(r'Annuelle\s+comp[ée]tition', caseSensitive: false)
      .hasMatch(text)) {
    return 'AC';
  }
  if (RegExp(r'\bAL\b').hasMatch(text)) return 'AL';
  if (RegExp(r'\bAC\b').hasMatch(text)) return 'AC';
  return null;
}

DateTime? _parseDate(String text, List<RegExp> patterns) {
  final raw = _firstMatch(text, patterns);
  if (raw == null) return null;
  final parts = raw.split(RegExp(r'[/\-.]'));
  if (parts.length != 3) return null;
  final d = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  var y = int.tryParse(parts[2]);
  if (d == null || m == null || y == null) return null;
  if (y < 100) y += 2000;
  try {
    return DateTime(y, m, d);
  } catch (_) {
    return null;
  }
}

String? _parseSex(String text) {
  if (RegExp(r'\bFemme\b', caseSensitive: false).hasMatch(text) ||
      RegExp(r'\bF[ée]minin\b', caseSensitive: false).hasMatch(text)) {
    return 'F';
  }
  if (RegExp(r'\bHomme\b', caseSensitive: false).hasMatch(text) ||
      RegExp(r'\bMasculin\b', caseSensitive: false).hasMatch(text)) {
    return 'M';
  }
  final g = RegExp(r'Genre\s*[:\s]*(H|F|M)', caseSensitive: false)
      .firstMatch(text)
      ?.group(1)
      ?.toUpperCase();
  if (g == 'H' || g == 'M') return 'M';
  if (g == 'F') return 'F';
  return null;
}

bool? _parseOuiNon(String text, RegExp re) {
  final m = re.firstMatch(text);
  if (m == null) return null;
  return m.group(1)!.toLowerCase().startsWith('o');
}

String? _parseClubName(String text, String? ffaCode) {
  final withCode = RegExp(
    r"([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ0-9 '\-]{2,80})\s*\(([CDE][0-9]{5,7})\)",
    unicode: true,
  ).firstMatch(text);
  if (withCode != null) return withCode.group(1)?.trim();
  if (ffaCode != null) {
    final before = RegExp(
      r"([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ0-9 '\-]{2,80})\s*\(" +
          RegExp.escape(ffaCode) +
          r"\)",
      unicode: true,
    ).firstMatch(text);
    if (before != null) return before.group(1)?.trim();
  }
  final clubLine = RegExp(
    r"Club\s*[:\s]*([A-Za-zÀ-ÿ0-9 '\-]{3,80})",
    caseSensitive: false,
    unicode: true,
  ).firstMatch(text);
  return clubLine?.group(1)?.trim();
}

/// Retourne (prénom, nom).
(String?, String?) _parseNames(String text) {
  final labeled = RegExp(
    r'(?:Nom|Name)\s*[:\s]*([A-ZÉÈÀÙÂÊÎÔÛÇ][A-ZÉÈÀÙÂÊÎÔÛÇ\- ]+)\s*(?:Pr[ée]nom|First)\s*[:\s]*([A-Za-zÉéÈèÀàÙùÂâÊêÎîÔôÛûÇç\-]+)',
    caseSensitive: false,
  ).firstMatch(text);
  if (labeled != null) {
    return (labeled.group(2)?.trim(), labeled.group(1)?.trim());
  }
  final prenomFirst = RegExp(
    r'Pr[ée]nom\s*[:\s]*([A-Za-zÉéÈèÀàÙùÂâÊêÎîÔôÛûÇç\-]+).*?Nom\s*[:\s]*([A-ZÉÈÀÙÂÊÎÔÛÇ][A-ZÉÈÀÙÂÊÎÔÛÇ\- ]+)',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(text);
  if (prenomFirst != null) {
    return (prenomFirst.group(1)?.trim(), prenomFirst.group(2)?.trim());
  }
  // Ligne type "DUPONT Jean" après type licence
  final line = RegExp(
    r'\b([A-ZÉÈÀÙÂÊÎÔÛÇ]{2,}(?:[\- ][A-ZÉÈÀÙÂÊÎÔÛÇ]{2,})*)\s+([A-ZÉÈÀÙÂÊÎÔÛÇ][a-zéèàùâêîôûç\-]+)\b',
  ).firstMatch(text);
  if (line != null) {
    return (line.group(2)?.trim(), line.group(1)?.trim());
  }
  return (null, null);
}

// Re-export pour appels statiques depuis tests.
LicenseDraft parseLicenseText(
  String text, {
  LicenseSource source = LicenseSource.pdf,
}) =>
    LicensePdfParser.parseLicenseText(text, source: source);
