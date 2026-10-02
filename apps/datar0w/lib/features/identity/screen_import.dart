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

/// ST-07 — Import cabane (bateaux + rameurs).
class ClubImportScreen extends ConsumerStatefulWidget {
  const ClubImportScreen({super.key});

  @override
  ConsumerState<ClubImportScreen> createState() => _ClubImportScreenState();
}

class _ClubImportScreenState extends ConsumerState<ClubImportScreen> {
  ImportPreview? _parkPreview;
  RowerImportPreview? _rowerPreview;
  ImportApplyResult? _parkReport;
  RowerImportApplyResult? _rowerReport;
  String? _flash;

  String _errorLinesLabel(Iterable<int> lines) {
    final sorted = lines.toList()..sort();
    if (sorted.isEmpty) return '';
    return sorted.join(', ');
  }

  String _parkReportText(ImportPreview p) {
    final errs = p.rows.where((r) => !r.ok).map((r) => r.line);
    final n = p.errorCount;
    if (n == 0) return '${p.validCount} bateaux OK · 0 erreur';
    return '${p.validCount} bateaux OK · $n erreurs ligne ${_errorLinesLabel(errs)}';
  }

  String _rowerReportText(RowerImportPreview p) {
    final errs = p.rows.where((r) => !r.ok).map((r) => r.line);
    final n = p.errorCount;
    if (n == 0) return '${p.validCount} rameurs OK · 0 erreur';
    return '${p.validCount} rameurs OK · $n erreurs ligne ${_errorLinesLabel(errs)}';
  }

  Future<void> _shareTemplate({required bool park}) async {
    final dir = await getTemporaryDirectory();
    if (park) {
      final f = File('${dir.path}/Bateaux.csv');
      await f.writeAsString(parkCsvTemplate());
      await SharePlus.instance.share(
        ShareParams(files: [XFile(f.path)], text: 'Bateaux.csv — modèle DataR0w'),
      );
      return;
    }
    final f = File('${dir.path}/Rameurs.csv');
    await f.writeAsString(rowerCsvTemplate());
    await SharePlus.instance.share(
      ShareParams(files: [XFile(f.path)], text: 'Rameurs.csv — modèle DataR0w'),
    );
  }

  Future<void> _pick({required bool park}) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx', 'xls', 'txt'],
    );
    if (files.isEmpty) return;
    final f = files.single;
    final bytes = await f.readAsBytes();
    setState(() {
      _flash = null;
      if (park) {
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
        title: 'IMPORT CABANE',
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
      title: 'IMPORT CABANE',
      subtitle: 'CSV yearly · cloud',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Text(
            'Données yearly · stockées cloud, pas sur le téléphone.',
            style: TextStyle(color: DeckColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (_flash != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _flash!,
                style: const TextStyle(color: DeckColors.volt),
              ),
            ),
          _DropZone(
            filename: 'Bateaux.csv',
            subtitle: 'Parc / coques',
            onPick: () => _pick(park: true),
            onTemplate: () => _shareTemplate(park: true),
          ),
          const SizedBox(height: 12),
          _DropZone(
            filename: 'Rameurs.csv',
            subtitle: 'Effectif club',
            onPick: () => _pick(park: false),
            onTemplate: () => _shareTemplate(park: false),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadBordeaux,
            child: const Text('Charger la base Bordeaux (démo)'),
          ),
          ..._parkSection(snap),
          ..._rowerSection(snap),
        ],
      ),
    );
  }

  List<Widget> _parkSection(IdentitySnapshot snap) {
    final p = _parkPreview;
    return [
      if (p != null) ...[
        const SizedBox(height: 20),
        const Text(
          'BATEAUX',
          style: TextStyle(
            color: DeckColors.label,
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (p.fatal != null)
          Text(p.fatal!, style: const TextStyle(color: DeckColors.volt))
        else ...[
          Text(
            _parkReportText(p),
            style: const TextStyle(color: DeckColors.label),
          ),
          if (p.unknownHeaders.isNotEmpty)
            Text(
              'Colonnes inconnues : ${p.unknownHeaders.join(', ')}',
              style: const TextStyle(color: DeckColors.volt, fontSize: 12),
            ),
          const SizedBox(height: 8),
          _boatTable(p),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _confirmPark,
            child: const Text('ENVOYER VERS LE CLUB'),
          ),
        ],
      ],
      if (_parkReport != null) ...[
        const SizedBox(height: 12),
        Text(
          '${_parkReport!.created} créées · ${_parkReport!.updated} mises à jour · ${_parkReport!.ignored} ignorées',
          style: const TextStyle(color: DeckColors.volt),
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
        const SizedBox(height: 20),
        const Text(
          'RAMEURS',
          style: TextStyle(
            color: DeckColors.label,
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (p.fatal != null)
          Text(p.fatal!, style: const TextStyle(color: DeckColors.volt))
        else ...[
          Text(
            _rowerReportText(p),
            style: const TextStyle(color: DeckColors.label),
          ),
          const SizedBox(height: 8),
          _rowerTable(p),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _confirmRowers,
            child: const Text('ENVOYER VERS LE CLUB'),
          ),
        ],
      ],
      if (_rowerReport != null) ...[
        const SizedBox(height: 12),
        Text(
          '${_rowerReport!.created} créés · ${_rowerReport!.updated} maj · ${_rowerReport!.ignored} ignorés',
          style: const TextStyle(color: DeckColors.volt),
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
                      ? DeckColors.volt
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
                      ? DeckColors.volt
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

class _DropZone extends StatelessWidget {
  const _DropZone({
    required this.filename,
    required this.subtitle,
    required this.onPick,
    required this.onTemplate,
  });

  final String filename;
  final String subtitle;
  final VoidCallback onPick;
  final VoidCallback onTemplate;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DeckColors.surface,
      child: InkWell(
        onTap: onPick,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            border: Border.all(color: DeckColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                filename,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: DeckColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Choisir un fichier',
                    style: TextStyle(
                      color: DeckColors.volt,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onTemplate,
                    child: const Text('Modèle'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
