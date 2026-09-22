import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../identity/controller.dart';
import '../../import/apply.dart';
import '../../import/mapping.dart';
import '../../import/model_template.dart';
import '../../import/rower_csv.dart';
import '../../import/rower_template.dart';
import '../../import/xlsx_parser.dart';
import '../../session/boat_config.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

enum _ImportKind { park, rowers }

class ClubImportScreen extends ConsumerStatefulWidget {
  const ClubImportScreen({super.key});

  @override
  ConsumerState<ClubImportScreen> createState() => _ClubImportScreenState();
}

class _ClubImportScreenState extends ConsumerState<ClubImportScreen> {
  _ImportKind _kind = _ImportKind.park;
  ImportPreview? _parkPreview;
  RowerImportPreview? _rowerPreview;
  ImportApplyResult? _parkReport;
  RowerImportApplyResult? _rowerReport;
  String? _flash;

  void _setKind(_ImportKind k) {
    setState(() {
      _kind = k;
      _flash = null;
    });
  }

  Future<void> _shareTemplate() async {
    final dir = await getTemporaryDirectory();
    if (_kind == _ImportKind.park) {
      final f = File('${dir.path}/$parkCsvFilename');
      await f.writeAsString(parkCsvTemplate());
      await SharePlus.instance.share(
        ShareParams(files: [XFile(f.path)], text: 'Modèle parc DataR0w'),
      );
      return;
    }
    final f = File('${dir.path}/$rowerCsvFilename');
    await f.writeAsString(rowerCsvTemplate());
    await SharePlus.instance.share(
      ShareParams(files: [XFile(f.path)], text: 'Modèle rameurs DataR0w'),
    );
  }

  Future<void> _pick() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx', 'xls', 'txt'],
    );
    if (files.isEmpty) return;
    final f = files.single;
    final bytes = await f.readAsBytes();
    setState(() {
      _flash = null;
      if (_kind == _ImportKind.park) {
        _parkPreview = parseSpreadsheetBytes(bytes, filename: f.name);
        _parkReport = null;
      } else {
        _rowerPreview = parseRowerSpreadsheetBytes(bytes, filename: f.name);
        _rowerReport = null;
      }
    });
  }

  Future<void> _confirmPark() async {
    final p = _parkPreview;
    if (p == null || p.fatal != null) return;
    final r = await ref.read(identityProvider.notifier).confirmImport(p.rows);
    if (!mounted) return;
    setState(() => _parkReport = r);
  }

  Future<void> _loadBordeaux() async {
    final text = await rootBundle.loadString('assets/seed/rameurs_bordeaux.csv');
    if (!mounted) return;
    setState(() {
      _flash = null;
      _rowerPreview = parseRowerCsv(text);
      _rowerReport = null;
    });
  }

  Future<void> _confirmRowers() async {
    final p = _rowerPreview;
    if (p == null || p.fatal != null) return;
    final r =
        await ref.read(identityProvider.notifier).confirmImportRowers(p.rows);
    if (!mounted) return;
    setState(() => _rowerReport = r);
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(identityProvider);
    final role = ref.watch(boatConfigProvider).role;
    if (!canCheckoutOps(snap, role)) {
      return const DeckScaffold(
        title: 'IMPORT',
        retourToProfile: true,
        body: Center(
          child: Text(
            'Réservé au coach.',
            style: TextStyle(color: DeckColors.muted),
          ),
        ),
      );
    }
    return DeckScaffold(
      title: 'IMPORT',
      subtitle: 'Parc ou rameurs · CSV / Excel',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('PARC'),
                selected: _kind == _ImportKind.park,
                onSelected: (_) => _setKind(_ImportKind.park),
              ),
              ChoiceChip(
                label: const Text('RAMEURS'),
                selected: _kind == _ImportKind.rowers,
                onSelected: (_) => _setKind(_ImportKind.rowers),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_flash != null)
            Text(_flash!, style: const TextStyle(color: DeckColors.amber)),
          FilledButton(
            onPressed: _shareTemplate,
            child: const Text('TÉLÉCHARGER LE MODÈLE CSV'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _pick,
            child: const Text('IMPORTER UN FICHIER'),
          ),
          if (_kind == _ImportKind.rowers) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loadBordeaux,
              child: const Text('CHARGER LA BASE BORDEAUX'),
            ),
          ],
          if (_kind == _ImportKind.park) ..._parkSection(snap) else ..._rowerSection(snap),
        ],
      ),
    );
  }

  List<Widget> _parkSection(IdentitySnapshot snap) {
    final p = _parkPreview;
    return [
      if (p != null) ...[
        const SizedBox(height: 16),
        if (p.fatal != null)
          Text(p.fatal!, style: const TextStyle(color: DeckColors.amber))
        else ...[
          Text(
            '${p.validCount} lignes OK · ${p.errorCount} erreurs',
            style: const TextStyle(color: DeckColors.label),
          ),
          if (p.unknownHeaders.isNotEmpty)
            Text(
              'Colonnes inconnues : ${p.unknownHeaders.join(', ')}',
              style: const TextStyle(color: DeckColors.amber, fontSize: 12),
            ),
          const SizedBox(height: 8),
          _boatTable(p),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _confirmPark,
            child: const Text('CONFIRMER L’IMPORT'),
          ),
        ],
      ],
      if (_parkReport != null) ...[
        const SizedBox(height: 16),
        Text(
          '${_parkReport!.created} créées · ${_parkReport!.updated} mises à jour · ${_parkReport!.ignored} ignorées',
          style: const TextStyle(color: DeckColors.amber),
        ),
      ],
      if (snap.prefs.lastImportId != null) ...[
        const SizedBox(height: 8),
        TextButton(
          onPressed: () async {
            await ref.read(identityProvider.notifier).undoLastImport();
            if (mounted) {
              setState(() {
                _parkReport = null;
                _flash = 'Import annulé (coques créées retirées).';
              });
            }
          },
          child: const Text('ANNULER CET IMPORT'),
        ),
      ],
    ];
  }

  List<Widget> _rowerSection(IdentitySnapshot snap) {
    final p = _rowerPreview;
    return [
      if (p != null) ...[
        const SizedBox(height: 16),
        if (p.fatal != null)
          Text(p.fatal!, style: const TextStyle(color: DeckColors.amber))
        else ...[
          Text(
            '${p.validCount} lignes OK · ${p.errorCount} erreurs',
            style: const TextStyle(color: DeckColors.label),
          ),
          const SizedBox(height: 8),
          _rowerTable(p),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _confirmRowers,
            child: const Text('CONFIRMER L’IMPORT'),
          ),
        ],
      ],
      if (_rowerReport != null) ...[
        const SizedBox(height: 16),
        Text(
          '${_rowerReport!.created} créés · ${_rowerReport!.updated} maj · ${_rowerReport!.ignored} ignorés',
          style: const TextStyle(color: DeckColors.amber),
        ),
      ],
      if (snap.prefs.lastRowerImportId != null) ...[
        const SizedBox(height: 8),
        TextButton(
          onPressed: () async {
            await ref.read(identityProvider.notifier).undoLastRowerImport();
            if (mounted) {
              setState(() {
                _rowerReport = null;
                _flash = 'Import annulé (rameurs créés retirés).';
              });
            }
          },
          child: const Text('ANNULER CET IMPORT'),
        ),
      ],
    ];
  }

  Widget _boatTable(ImportPreview p) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 40,
        columns: [
          for (var i = 0; i < p.headers.length; i++)
            DataColumn(
              label: Text(
                p.headers[i],
                style: TextStyle(
                  color: p.mapped[i] == MappedCol.unknown
                      ? DeckColors.amber
                      : DeckColors.tribord,
                  fontSize: 11,
                ),
              ),
            ),
        ],
        rows: [
          for (final row in p.rows)
            DataRow(
              color: WidgetStatePropertyAll(
                row.ok
                    ? Colors.transparent
                    : DeckColors.babord.withValues(alpha: 0.25),
              ),
              cells: [
                for (final h in p.headers)
                  DataCell(
                    Text(
                      row.cells[h] ?? row.error ?? '',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _rowerTable(RowerImportPreview p) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 40,
        columns: [
          for (var i = 0; i < p.headers.length; i++)
            DataColumn(
              label: Text(
                p.headers[i],
                style: TextStyle(
                  color: p.mapped[i] == MappedRowerCol.unknown
                      ? DeckColors.amber
                      : DeckColors.tribord,
                  fontSize: 11,
                ),
              ),
            ),
        ],
        rows: [
          for (final row in p.rows.take(80))
            DataRow(
              color: WidgetStatePropertyAll(
                row.ok
                    ? Colors.transparent
                    : DeckColors.babord.withValues(alpha: 0.25),
              ),
              cells: [
                for (final h in p.headers)
                  DataCell(
                    Text(
                      row.cells[h] ?? row.error ?? '',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
