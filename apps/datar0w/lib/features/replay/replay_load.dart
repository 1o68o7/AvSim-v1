import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../session/live_hub.dart';
import '../../session/model.dart';
import '../../session/share_files.dart';
import '../../session/store.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_widgets.dart';
import 'replay_body.dart';

class ReplayBundle {
  const ReplayBundle({
    required this.samples,
    required this.notes,
    this.meta,
    this.sourceLabel = 'dernière séance',
  });

  final List<SessionSample> samples;
  final List<SessionNote> notes;
  final SessionMeta? meta;
  final String sourceLabel;
}

class ReplayLoadScreen extends ConsumerStatefulWidget {
  const ReplayLoadScreen({
    super.key,
    required this.title,
    required this.onBack,
    this.sessionId,
    this.showEval = true,
    this.allowImport = true,
  });

  final String title;
  final VoidCallback onBack;
  /// Si fourni (query `?id=`), charge cette séance — pas `latestId`.
  final String? sessionId;
  final bool showEval;
  final bool allowImport;

  @override
  ConsumerState<ReplayLoadScreen> createState() => _ReplayLoadScreenState();
}

class _ReplayLoadScreenState extends ConsumerState<ReplayLoadScreen> {
  ReplayBundle? _bundle;
  bool _loading = true;
  String? _error;
  String? _loadedId;

  @override
  void initState() {
    super.initState();
    _loadLast();
  }

  Future<void> _loadLast() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final asked = widget.sessionId?.trim();
    final id = (asked != null && asked.isNotEmpty)
        ? asked
        : (ref.read(liveHubProvider).sessionId ?? await SessionStore.latestId());
    if (id == null) {
      if (mounted) {
        setState(() {
          _bundle = const ReplayBundle(samples: [], notes: []);
          _loading = false;
          _loadedId = null;
        });
      }
      return;
    }
    final samples = await SessionStore.loadSamples(id);
    final notes = await SessionStore.loadNotes(id);
    final meta = await SessionStore.loadMeta(id);
    if (mounted) {
      setState(() {
        _loadedId = id;
        _bundle = ReplayBundle(
          samples: samples,
          notes: notes,
          meta: meta,
          sourceLabel: asked != null && asked.isNotEmpty
              ? (meta?.code ?? id)
              : 'dernière séance',
        );
        _loading = false;
      });
    }
  }

  Future<void> _import() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jsonl', 'json', 'txt'],
    );
    if (f == null) return;
    final bytes = await f.readAsBytes();
    final text = utf8.decode(bytes);
    final samples = <SessionSample>[];
    for (final line in const LineSplitter().convert(text)) {
      final t = line.trim();
      if (t.isEmpty) continue;
      try {
        final j = jsonDecode(t);
        if (j is Map && j.containsKey('_meta')) continue;
        if (j is Map && j.containsKey('t')) {
          samples.add(SessionSample.fromJson(Map<String, dynamic>.from(j)));
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _bundle = ReplayBundle(
          samples: samples,
          notes: const [],
          sourceLabel: f.name,
        );
        _error = samples.isEmpty ? 'Aucune ligne sample dans le fichier' : null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DeckColors.bg,
      appBar: AppBar(
        toolbarHeight: 48,
        title: Row(
          children: [
            const DataR0wMark(compact: true),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        leading: TextButton(
          onPressed: widget.onBack,
          child: const Text('Retour'),
        ),
        actions: [
          if (_loadedId != null)
            TextButton(
              onPressed: () => shareLocalSession(_loadedId!),
              child: const Text('PARTAGER'),
            ),
          if (widget.allowImport)
            TextButton(
              onPressed: _import,
              child: const Text('IMPORTER'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: DeckColors.amber),
                    ),
                  ),
                Expanded(
                  child: ReplayBody(
                    samples: _bundle?.samples ?? const [],
                    notes: _bundle?.notes ?? const [],
                    meta: _bundle?.meta,
                    title: widget.title,
                    showEval: widget.showEval,
                    sourceLabel: _bundle?.sourceLabel,
                  ),
                ),
              ],
            ),
    );
  }
}
