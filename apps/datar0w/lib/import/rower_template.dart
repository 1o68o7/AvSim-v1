/// Modèle CSV rameurs — en-têtes + 2 exemples. Pas de PII (email, licence, adresse).
const rowerCsvFilename = 'datarow_rameurs_modele.csv';

const rowerCsvHeaders = [
  'Nom',
  'Sexe',
  'Naissance',
  'Poids',
  'Taille',
  'Cote',
  'Niveau',
  'Club',
];

String rowerCsvTemplate() {
  final h = rowerCsvHeaders.join(';');
  const a = 'Camille Dupont;F;1998-05-10;62;172;babord;competiteur;';
  const b = 'Jean Martin;M;1975-03-22;78;181;tribord;loisir;';
  return '$h\n$a\n$b\n';
}
