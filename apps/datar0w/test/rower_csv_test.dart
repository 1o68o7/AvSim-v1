import 'package:datar0w/identity/models.dart';
import 'package:datar0w/import/apply.dart';
import 'package:datar0w/import/rower_csv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CSV rameurs valide', () {
    const csv = 'Nom;Sexe;Naissance;Poids;Taille;Cote;Niveau;Club\n'
        'Camille Test;F;1998-05-10;58;172;babord;loisir;club-1\n';
    final p = parseRowerCsv(csv);
    expect(p.fatal, isNull);
    expect(p.validCount, 1);
    final r = p.rows.single;
    expect(r.displayName, 'Camille Test');
    expect(r.sex, RowerSex.f);
    expect(r.birthDate, DateTime.utc(1998, 5, 10));
    expect(r.weightKg, 58);
    expect(r.heightCm, 172);
    expect(r.sidePref, SidePref.babord);
    expect(r.level, RowerLevel.loisir);
    expect(r.clubId, 'club-1');
    expect(categoryFromImportBirth(r.birthDate!, seasonYear: 2025).code, 'SE');
  });

  test('en-têtes accents / casse / synonymes', () {
    const csv = 'RAMEUR;SEX;DATE DE NAISSANCE;Côté;LEVEL\n'
        'Ada;F;1998-05-10;tribord;competiteur\n';
    final p = parseRowerCsv(csv);
    expect(p.fatal, isNull);
    expect(p.mapped.first, MappedRowerCol.name);
    expect(mapRowerHeader('Naissance'), MappedRowerCol.birth);
    expect(mapRowerHeader('POIDS'), MappedRowerCol.weight);
    expect(p.rows.single.sidePref, SidePref.tribord);
    expect(p.rows.single.level, RowerLevel.competiteur);
  });

  test('colonne Nom manquante → message clair, pas de crash', () {
    final p = parseRowerCsv('Sexe;Naissance\nF;1998-05-10\n');
    expect(p.fatal, 'Colonne Nom manquante.');
    expect(p.rows, isEmpty);
  });

  test('ligne vide ignorée, nom manquant en erreur', () {
    const csv = 'Nom;Naissance\nCamille;1998-05-10\n\n;1999-01-01\n';
    final p = parseRowerCsv(csv);
    expect(p.validCount, 1);
    expect(p.errorCount, 1);
    expect(p.rows.last.error, 'Nom manquant.');
  });

  test('sexe invalide → M par défaut ; poids/taille absents OK', () {
    const csv = 'Nom;Sexe;Naissance;Poids;Taille\nAlex;??;1998-05-10;;\n';
    final p = parseRowerCsv(csv);
    expect(p.validCount, 1);
    expect(p.rows.single.sex, RowerSex.m);
    expect(p.rows.single.weightKg, isNull);
    expect(p.rows.single.heightCm, isNull);
  });

  test('doublon = mise à jour, importId sur créés', () {
    final existing = [
      Rower.create(
        displayName: 'Camille Test',
        birthDate: DateTime.utc(1998, 5, 10),
        sex: RowerSex.f,
      ),
    ];
    const csv = 'Nom;Sexe;Naissance;Poids;Niveau\n'
        'camille test;F;1998-05-10;59;competiteur\n'
        'Nouveau;M;2000-01-02;;loisir\n';
    final preview = parseRowerCsv(csv);
    final r = applyRowerImport(existing: existing, rows: preview.rows);
    expect(r.updated, 1);
    expect(r.created, 1);
    expect(r.ignored, 0);
    expect(r.rowers.where((x) => x.importId == r.importId).length, 1);
    final camille = r.rowers.firstWhere(
      (x) => x.displayName.toLowerCase() == 'camille test',
    );
    expect(camille.weightKg, 59);
    expect(camille.level, RowerLevel.competiteur);
    expect(camille.importId, isNull);
    final undone = undoRowerImport(rowers: r.rowers, importId: r.importId);
    expect(undone.length, 1);
    expect(undone.single.displayName, 'Camille Test');
  });

  test('fromJson tolère l’absence d’importId', () {
    final r = Rower.create(
      displayName: 'Ada',
      birthDate: DateTime.utc(1998, 5, 10),
    );
    final j = r.toJson();
    expect(j.containsKey('importId'), isFalse);
    final back = Rower.fromJson(j);
    expect(back.importId, isNull);
    final withId = r.copyWith(importId: 'imp-1');
    expect(withId.toJson()['importId'], 'imp-1');
    expect(withId.copyWith(clearImport: true).importId, isNull);
  });

  test('pas d’email / licence dans le mapping', () {
    expect(mapRowerHeader('email'), MappedRowerCol.unknown);
    expect(mapRowerHeader('adresse'), MappedRowerCol.unknown);
    expect(mapRowerHeader('licence'), MappedRowerCol.unknown);
  });
}
