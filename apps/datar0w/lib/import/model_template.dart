/// Modèle CSV cabane — en-têtes + 2 exemples.
const parkCsvFilename = 'datarow_parc_modele.csv';

const parkCsvHeaders = [
  'Nom',
  'Classe',
  'Type',
  'Pelles',
  'Marque',
  'Modele',
  'Annee',
  'Materiau',
  'Serie',
  'Loisir',
  'Notes',
];

String parkCsvTemplate() {
  final h = parkCsvHeaders.join(';');
  const a =
      'Empacher 8+;8+;pointe;P1/P2/P4;Empacher;E8;2021;carbone;;non;bateau compétition';
  const b =
      'Hudson skiff;1x;skiff;P1;Hudson;H1;2018;composite;;oui;loisir cabane';
  return '$h\n$a\n$b\n';
}
