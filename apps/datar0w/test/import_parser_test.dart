import 'dart:convert';

import 'package:datar0w/identity/models.dart';
import 'package:datar0w/import/apply.dart';
import 'package:datar0w/import/csv_parser.dart';
import 'package:datar0w/import/mapping.dart';
import 'package:datar0w/import/model_template.dart';
import 'package:datar0w/import/xlsx_parser.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CSV valide + modèle', () {
    final preview = parseCsv(parkCsvTemplate());
    expect(preview.fatal, isNull);
    expect(preview.validCount, 2);
    expect(preview.rows.first.name, 'Empacher 8+');
    expect(preview.rows.first.classe, '8+');
    expect(preview.rows.first.oars, ['P1', 'P2', 'P4']);
    expect(preview.rows.last.boatType, 'skiff');
  });

  test('en-têtes accents / casse / synonymes', () {
    const csv = 'COQUE;class;Palettes\nHudson;4x;P2\n';
    final p = parseCsv(csv);
    expect(p.fatal, isNull);
    expect(p.mapped.first, MappedCol.name);
    expect(p.rows.single.classe, '4x');
    expect(mapHeader('Modèle'), MappedCol.model);
    expect(mapHeader('Année'), MappedCol.year);
    expect(mapHeader('Matériau'), MappedCol.material);
  });

  test('colonne Nom manquante → message clair', () {
    final p = parseCsv('Classe;Pelles\n8+;P1\n');
    expect(p.fatal, 'Colonne Nom manquante.');
    expect(p.rows, isEmpty);
  });

  test('ligne vide ignorée, nom manquant en erreur', () {
    const csv = 'Nom;Classe\nEmpacher;8+\n\n;4x\n';
    final p = parseCsv(csv);
    expect(p.validCount, 1);
    expect(p.errorCount, 1);
    expect(p.rows.last.error, 'Nom manquant.');
  });

  test('doublon = mise à jour, nouvel importId sur créés', () {
    final club = Club.create(name: 'CN');
    final existing = [
      ParkBoat.create(clubId: club.id, name: 'Empacher 8+', classe: '8+'),
    ];
    final preview = parseCsv(parkCsvTemplate());
    final r = applyParkImport(
      clubId: club.id,
      existing: existing,
      rows: preview.rows,
    );
    expect(r.updated, 1);
    expect(r.created, 1);
    expect(r.ignored, 0);
    expect(r.boats.where((b) => b.importId == r.importId).length, 1);
    final undone = undoImport(boats: r.boats, importId: r.importId);
    expect(undone.length, 1);
    expect(undone.single.name, 'Empacher 8+');
  });

  test('encodage latin1 / UTF-8 malformé ne plante pas', () {
    final bytes = latin1.encode('Nom;Classe\nBâteau;1x\n');
    final p = parseCsvBytes(bytes);
    expect(p.fatal, isNull);
    expect(p.rows.single.name, contains('t'));
  });

  test('XLS ancien → message exporter XLSX', () {
    final p = parseSpreadsheetBytes(
      [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1],
      filename: 'parc.xls',
    );
    expect(p.fatal, xlsLegacyMessage);
  });

  test('XLSX via package excel', () {
    final book = Excel.createExcel();
    final sheet = book['Sheet1'];
    sheet.appendRow([
      TextCellValue('Nom'),
      TextCellValue('Classe'),
      TextCellValue('Pelles'),
    ]);
    sheet.appendRow([
      TextCellValue('Filippi'),
      TextCellValue('2x'),
      TextCellValue('P1/P1'),
    ]);
    final bytes = book.encode();
    expect(bytes, isNotNull);
    final p = parseXlsxBytes(bytes!);
    expect(p.fatal, isNull);
    expect(p.rows.single.name, 'Filippi');
    expect(p.rows.single.classe, '2x');
  });
}
