import 'dart:io';

import 'package:datar0w/import/rower_csv.dart';
import 'package:datar0w/import/rower_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('modèle CSV : en-têtes + 2 exemples parseables', () {
    final p = parseRowerCsv(rowerCsvTemplate());
    expect(p.fatal, isNull);
    expect(p.validCount, 2);
    expect(p.rows.first.displayName, 'Camille Dupont');
    expect(p.rows.last.level.toString(), contains('loisir'));
  });

  test('seed Bordeaux : 552 lignes, 47 compétiteurs, 505 loisirs, pas de PII', () {
    final f = File('assets/seed/rameurs_bordeaux.csv');
    expect(f.existsSync(), isTrue);
    final text = f.readAsStringSync();
    expect(text.toLowerCase().contains('email'), isFalse);
    expect(text.toLowerCase().contains('licence'), isFalse);
    expect(text.toLowerCase().contains('@'), isFalse);
    final p = parseRowerCsv(text);
    expect(p.fatal, isNull);
    expect(p.validCount, 552);
    expect(p.errorCount, 0);
    expect(p.rows.where((r) => r.level.name == 'competiteur').length, 47);
    expect(p.rows.where((r) => r.level.name == 'loisir').length, 505);
    final leis = p.rows.where((r) => r.level.name == 'loisir').toList();
    final nM = leis.where((r) => r.sex.name == 'm').length;
    final nF = leis.where((r) => r.sex.name == 'f').length;
    expect((nM - nF).abs(), lessThanOrEqualTo(1));
    for (final r in leis) {
      final birth = r.birthDate!;
      final asOf = DateTime.utc(2026, 9, 22);
      var age = asOf.year - birth.year;
      final anniversary = DateTime.utc(asOf.year, birth.month, birth.day);
      if (anniversary.isAfter(asOf)) age--;
      expect(age, inInclusiveRange(35, 75));
      expect(r.weightKg, isNotNull);
      expect(r.heightCm, isNotNull);
    }
  });

  test('template asset aligné sur rowerCsvTemplate()', () {
    final f = File('assets/seed/rameurs_bordeaux_template.csv');
    expect(f.readAsStringSync(), rowerCsvTemplate());
  });
}
