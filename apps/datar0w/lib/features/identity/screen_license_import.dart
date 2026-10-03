import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../funnel/controller.dart';
import '../../funnel/models.dart';
import '../../identity/controller.dart';
import '../../identity/license.dart';
import '../../identity/license_pdf.dart';
import '../../router.dart';
import '../../theme/deck_theme.dart';

/// Import PDF licence FFA — confirmation avant toute écriture.
class LicenseImportScreen extends ConsumerStatefulWidget {
  const LicenseImportScreen({super.key, this.initialDraft});

  final LicenseDraft? initialDraft;

  @override
  ConsumerState<LicenseImportScreen> createState() =>
      _LicenseImportScreenState();
}

class _LicenseImportScreenState extends ConsumerState<LicenseImportScreen> {
  LicenseDraft? _draft;
  String? _error;
  bool _busy = false;
  bool _createClub = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft;
  }

  Future<void> _pickPdf() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (files.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      final file = files.single;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        setState(() {
          _error = kLicenseUnreadableMsg;
          _busy = false;
        });
        return;
      }
      // Parse en mémoire — bytes jetés après (pas de File persisté).
      final draft = await const LicensePdfParser().parseBytes(
        Uint8List.fromList(bytes),
      );
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _busy = false;
      });
    } on LicenseParseException catch (e) {
      setState(() {
        _error = e.message;
        _draft = null;
        _busy = false;
      });
    } catch (_) {
      setState(() {
        _error = kLicenseUnreadableMsg;
        _draft = null;
        _busy = false;
      });
    }
  }

  Future<void> _confirm() async {
    final draft = _draft;
    if (draft == null || !draft.isReadable) return;
    setState(() => _busy = true);
    try {
      // Club inconnu → confirmation avant création.
      var createClub = _createClub;
      final code = draft.ffaCode?.trim();
      if (code != null && code.isNotEmpty && !createClub) {
        final snap = ref.read(identityProvider);
        final knownLocal = snap.clubs.any(
          (c) => (c.ffaCode ?? '').toUpperCase() == code.toUpperCase(),
        );
        if (!knownLocal) {
          final go = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: DeckColors.surface,
              title: const Text(
                'Club inconnu',
                style: TextStyle(color: DeckColors.text),
              ),
              content: Text(
                'Le code ${draft.ffaCode} (${draft.clubName ?? 'club'}) '
                'n’est pas encore dans DataR0w. Créer le rattachement ?',
                style: const TextStyle(color: DeckColors.label),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Sans club'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Confirmer le club'),
                ),
              ],
            ),
          );
          createClub = go == true;
        }
      }

      final result = await ref.read(identityProvider.notifier).applyLicenseDraft(
            draft,
            createClubIfMissing: createClub,
          );

      // AL → carte du jour 15/30 min, pas le diagnostic 2 000 m.
      if (result.license.isAl) {
        await ref.read(funnelProvider.notifier).completeOnboard(
              FunnelProfile(
                frame: PracticeFrame.loisir,
                todayDurationMin: 15,
                todayDistanceM: 0,
                onboardDone: true,
              ),
            );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.license.isExpired
                ? 'Licence enregistrée — périmée, siège non confirmé.'
                : 'Licence enregistrée · ${result.license.licenseType ?? ''}',
          ),
        ),
      );
      context.go(AppRoutes.homeRower);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return Scaffold(
      backgroundColor: DeckColors.bg,
      appBar: AppBar(
        backgroundColor: DeckColors.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: DeckColors.text),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Licence FFA',
          style: TextStyle(
            fontFamily: DeckType.ui,
            fontWeight: FontWeight.w600,
            color: DeckColors.text,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: draft == null ? _pickBody() : _confirmBody(draft),
        ),
      ),
    );
  }

  Widget _pickBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Importer ma licence',
          style: TextStyle(
            fontFamily: DeckType.ui,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: DeckColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'PDF officiel MyFFA, une page. Le fichier est lu puis jeté — '
          'il n’est jamais stocké.',
          style: DeckType.uiLabel(color: DeckColors.label),
        ),
        const Spacer(),
        if (_error != null) ...[
          Text(
            _error!,
            key: const Key('license-import-error'),
            style: DeckType.uiLabel(color: DeckColors.babord),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          height: 52,
          child: FilledButton(
            key: const Key('license-import-pick'),
            onPressed: _busy ? null : _pickPdf,
            child: Text(_busy ? 'Lecture…' : 'Choisir le PDF'),
          ),
        ),
      ],
    );
  }

  Widget _confirmBody(LicenseDraft draft) {
    String fmtDate(DateTime? d) {
      if (d == null) return '—';
      final dd = d.day.toString().padLeft(2, '0');
      final mm = d.month.toString().padLeft(2, '0');
      return '$dd/$mm/${d.year}';
    }

    Widget row(String label, String value, String field) {
      final doubt = draft.isDoubtful(field);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(label, style: DeckType.uiLabel()),
            ),
            Flexible(
              child: Container(
                padding: doubt
                    ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                    : EdgeInsets.zero,
                decoration: doubt
                    ? BoxDecoration(
                        color: DeckColors.amber.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      )
                    : null,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: DeckType.ui,
                    fontWeight: FontWeight.w600,
                    color: DeckColors.text,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Confirmer la licence',
          style: TextStyle(
            fontFamily: DeckType.ui,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: DeckColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Rien n’est écrit tant que tu ne valides pas.',
          style: DeckType.uiLabel(color: DeckColors.label),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            children: [
              row(
                'Club',
                '${draft.clubName ?? '—'} · ${draft.ffaCode ?? '—'}',
                'ffaCode',
              ),
              row('Type', draft.licenseType ?? '—', 'licenseType'),
              row('Catégorie', draft.category ?? '—', 'category'),
              row('Validité', fmtDate(draft.validUntil), 'validUntil'),
              row('Nom', draft.displayName.isEmpty ? '—' : draft.displayName,
                  'displayName'),
              row('N°', draft.licenseNumber ?? '—', 'licenseNumber'),
              row('Né·e le', fmtDate(draft.birthDate), 'birthDate'),
              row('Genre', draft.sex ?? '—', 'sex'),
              if (draft.surclassement)
                row('Surclassement', 'Oui', 'surclassement'),
              if (draft.handiClassification != null)
                row(
                  'Handi',
                  draft.handiClassification!,
                  'handiClassification',
                ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _createClub,
                onChanged: (v) => setState(() => _createClub = v ?? false),
                title: Text(
                  'Créer le club si le code est inconnu',
                  style: DeckType.uiLabel(color: DeckColors.text),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 52,
          child: FilledButton(
            key: const Key('license-import-confirm'),
            onPressed: _busy ? null : _confirm,
            child: const Text('Valider'),
          ),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _draft = null;
                    _error = null;
                  }),
          child: const Text(
            'Choisir un autre PDF',
            style: TextStyle(color: DeckColors.muted),
          ),
        ),
      ],
    );
  }
}
