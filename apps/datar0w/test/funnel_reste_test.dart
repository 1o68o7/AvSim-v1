import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:datar0w/funnel/boat_fiche.dart';
import 'package:datar0w/funnel/lot5_models.dart';
import 'package:datar0w/identity/controller.dart';
import 'package:datar0w/identity/id.dart';
import 'package:datar0w/identity/license.dart';
import 'package:datar0w/identity/license_pdf.dart';
import 'package:datar0w/identity/license_store.dart';
import 'package:datar0w/identity/models.dart';
import 'package:datar0w/identity/store.dart';
import 'package:datar0w/sync/club_remote.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Texte type carte FFA AL (couche TCPDF).
const kSampleAlText = '''
Fédération Française d'Aviron
Licence Annuelle loisir (AL)
N° 1234567
Valable jusqu'au 31/08/2027
DUPONT Jean
Homme
Né le 15/03/1992
Français
Émulation nautique de Bordeaux (C033003)
Catégorie Sénior A
Surclassement Non
Classification handi
''';

Uint8List _minimalPdfWithText(String plain) {
  // PDF minimal avec un stream FlateDecode contenant (text) Tj
  final content = 'BT /F1 12 Tf 100 700 Td (${plain.replaceAll('(', '\\(').replaceAll(')', '\\)')}) Tj ET';
  final compressed = const ZLibEncoder().encode(utf8.encode(content));
  final buf = BytesBuilder();
  void w(String s) => buf.add(utf8.encode(s));
  w('%PDF-1.4\n');
  w('1 0 obj<< /Type /Catalog /Pages 2 0 R >>endobj\n');
  w('2 0 obj<< /Type /Pages /Kids [3 0 R] /Count 1 >>endobj\n');
  w('3 0 obj<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
      '/Contents 4 0 R >>endobj\n');
  w('4 0 obj<< /Length ${compressed.length} /Filter /FlateDecode >>stream\n');
  buf.add(Uint8List.fromList(compressed));
  w('\nendstream\nendobj\n');
  w('xref\n0 5\ntrailer<< /Size 5 /Root 1 0 R >>\nstartxref\n0\n%%EOF\n');
  return buf.toBytes();
}

void main() {
  test('parse AL text → draft lisible', () {
    final draft = parseLicenseText(kSampleAlText);
    expect(draft.isReadable, isTrue);
    expect(draft.licenseType, 'AL');
    expect(draft.licenseNumber, '1234567');
    expect(draft.ffaCode, 'C033003');
    expect(draft.clubName, contains('Bordeaux'));
    expect(draft.category, contains('Sénior'));
    expect(draft.sex, 'M');
    expect(draft.validUntil?.year, 2027);
    expect(draft.birthDate?.year, 1992);
    expect(draft.displayName.toLowerCase(), contains('jean'));
  });

  test('refus sans numéro ni code club', () {
    expect(
      () => LicensePdfParser.parseLicenseText('Bon de commande magasin'),
      returnsNormally,
    );
    final draft = parseLicenseText('Facture n° ABC');
    expect(draft.isReadable, isFalse);
  });

  test('PDF FlateDecode → extract + parse', () async {
    final bytes = _minimalPdfWithText(
      'Annuelle loisir (AL) N° 9988776 '
      'Valable jusqu\'au 31/08/2027 '
      'Club Test (C033003) Catégorie Senior',
    );
    final draft = await const LicensePdfParser().parseBytes(bytes);
    expect(draft.licenseNumber, '9988776');
    expect(draft.ffaCode, 'C033003');
    expect(draft.source, LicenseSource.pdf);
  });

  test('fiche token roundtrip + share headline sans PII', () {
    final payload = BoatFichePayload(
      tokenId: 't1',
      clubId: 'c1',
      clubName: 'Club Test',
      boatId: 'b1',
      boatName: 'Vitesse',
      boatClass: '4x',
      seats: 4,
      cox: false,
      plannedAt: DateTime(2026, 10, 3, 18),
      expiresAt: DateTime(2026, 10, 3, 20).toUtc(),
      confirmedSeats: const {1: 'Ada', 2: 'Bob'},
      freeSeatIndexes: const [3, 4],
    );
    final token = encodeFicheToken(payload);
    final back = decodeFicheToken(token)!;
    expect(back.boatClass, '4x');
    expect(back.freeCount, 2);
    final text = ficheShareText(back, token);
    expect(text, contains('4x · 18:00 · 2 sièges libres'));
    expect(text, contains('/fiche/'));
    expect(text, isNot(contains('licence')));
    expect(text.toLowerCase(), isNot(contains('naissance')));
    expect(text, isNot(contains('kg')));
  });

  test('buildFicheFromPlan retire sièges confirmés', () {
    final club = Club.create(name: 'C', ffaCode: 'C033003');
    final boat = ParkBoat(
      id: 'b1',
      clubId: club.id,
      name: 'X',
      classe: '4x',
      seats: 4,
      cox: false,
    );
    final plan = WaterOutingPlan(
      id: 'p1',
      boatId: boat.id,
      boatClass: '4x',
      plannedAt: DateTime(2026, 10, 3, 18),
      distM: 2000,
      waterId: 'w1',
      waterLabel: 'Bassin',
      seatsRequired: 4,
      coxRequired: false,
      seatStates: {
        'r1': SeatConfirmState.confirmed,
        'r2': SeatConfirmState.confirmed,
      },
    );
    final asgs = [
      Assignment.create(
        boatId: boat.id,
        rowerId: 'r1',
        side: SidePref.none,
        seatIndex: 1,
      ),
      Assignment.create(
        boatId: boat.id,
        rowerId: 'r2',
        side: SidePref.none,
        seatIndex: 2,
      ),
    ];
    final fiche = buildFicheFromPlan(
      tokenId: 'tok',
      club: club,
      boat: boat,
      plan: plan,
      assignments: asgs,
      displayNameOf: (id) => id == 'r1' ? 'Ada Lovelace' : 'Bob',
    );
    expect(fiche.freeSeatIndexes, [3, 4]);
    expect(fiche.confirmedSeats[1], 'Ada');
    expect(fiche.shareHeadline(), contains('2 sièges libres'));
  });

  test('applyLicenseDraft écrit licenses + rower, pas de second profil', () async {
    final dir = await Directory.systemTemp.createTemp('reste-lic');
    addTearDown(() => dir.delete(recursive: true));
    final idStore = IdentityStore(root: dir);
    final licStore = LicenseStore(root: dir);
    final remote = MemoryClubRemote();

    final container = ProviderContainer(
      overrides: [
        identityStoreProvider.overrideWithValue(idStore),
        licenseStoreProvider.overrideWithValue(licStore),
        clubRemoteProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);

    final draft = parseLicenseText(kSampleAlText);
    final ctrl = container.read(identityProvider.notifier);
    await ctrl.reloadFromStore();
    final first = await ctrl.applyLicenseDraft(
      draft,
      createClubIfMissing: true,
    );
    expect(first.license.licenseNumber, '1234567');
    expect(first.license.myffaVerified, isFalse);
    expect(first.license.source, LicenseSource.pdf);
    expect(first.rower.displayName.toLowerCase(), contains('jean'));
    expect(remote.licenses, isNotEmpty);
    expect(remote.licenses.first['myffa_verified'], isFalse);

    // Second import même n° → même rower.
    final second = await ctrl.applyLicenseDraft(
      draft,
      createClubIfMissing: false,
    );
    expect(second.rower.id, first.rower.id);
    final rowers = await idStore.listRowers();
    expect(rowers.length, 1);
  });

  test('FfaLicense AL helpers', () {
    final al = FfaLicense(
      id: newIdentityId(),
      rowerId: 'r',
      licenseType: 'AL',
      validUntil: DateTime(2020, 1, 1),
    );
    expect(al.isAl, isTrue);
    expect(al.isExpired, isTrue);
  });

  test('aucune table profiles/outings/erg_logs dans migrations reste', () {
    final mig = File('supabase/migrations/0009_waters_and_closures.sql');
    // Chemin depuis apps/datar0w/test → remonter
    final rootMig = File('../../supabase/migrations/0009_waters_and_closures.sql');
    final f = mig.existsSync()
        ? mig
        : rootMig.existsSync()
            ? rootMig
            : File('/workspace/supabase/migrations/0009_waters_and_closures.sql');
    final sql = f.readAsStringSync();
    expect(sql.toLowerCase(), isNot(contains('create table profiles')));
    expect(sql.toLowerCase(), isNot(contains('create table outings')));
    expect(sql.toLowerCase(), isNot(contains('create table erg_logs')));
    expect(sql, contains('water_closures'));
    expect(sql, contains('club_waters'));
  });
}
