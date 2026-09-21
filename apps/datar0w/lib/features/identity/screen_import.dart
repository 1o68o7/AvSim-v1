import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../identity/controller.dart';
import '../../import/apply.dart';
import '../../import/mapping.dart';
import '../../import/model_template.dart';
import '../../import/xlsx_parser.dart';
import '../../session/boat_config.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

class ClubImportScreen extends ConsumerStatefulWidget {
  const ClubImportScreen({super.key});

  @override
  ConsumerState<ClubImportScreen> createState() => _ClubImportScreenState();
}

class _ClubImportScreenState extends ConsumerState<ClubImportScreen> {
  ImportPreview? _preview;
  ImportApplyResult? _report;
  String? _flash;

  Future<void> _shareTemplate() async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$parkCsvFilename');
    await f.writeAsString(parkCsvTemplate());
    await SharePlus.instance.share(
      ShareParams(files: [XFile(f.path)], text: 'Modèle parc DataR0w'),
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
      _preview = parseSpreadsheetBytes(bytes, filename: f.name);
      _report = null;
      _flash = null;
    });
  }

  Future<void> _confirm() async {
    final p = _preview;
    if (p == null || p.fatal != null) return;
    final r = await ref.read(identityProvider.notifier).confirmImport(p.rows);
    if (!mounted) return;
    setState(() => _report = r);
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
    final p = _preview;
    return DeckScaffold(
      title: 'IMPORT PARC',
      subtitle: 'CSV ou Excel',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
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
              SingleChildScrollView(
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
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _confirm,
                child: const Text('CONFIRMER L’IMPORT'),
              ),
            ],
          ],
          if (_report != null) ...[
            const SizedBox(height: 16),
            Text(
              '${_report!.created} créées · ${_report!.updated} mises à jour · ${_report!.ignored} ignorées',
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
                    _report = null;
                    _flash = 'Import annulé (coques créées retirées).';
                  });
                }
              },
              child: const Text('ANNULER CET IMPORT'),
            ),
          ],
        ],
      ),
    );
  }
}
