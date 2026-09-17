import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../session/live_hub.dart';
import '../../session/model.dart';
import '../../session/store.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_widgets.dart';
import 'replay_body.dart';

class ReplayBundle {
  const ReplayBundle({
    required this.samples,
    required this.notes,
    this.meta,
  });

  final List<SessionSample> samples;
  final List<SessionNote> notes;
  final SessionMeta? meta;
}

class ReplayLoadScreen extends ConsumerStatefulWidget {
  const ReplayLoadScreen({
    super.key,
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  ConsumerState<ReplayLoadScreen> createState() => _ReplayLoadScreenState();
}

class _ReplayLoadScreenState extends ConsumerState<ReplayLoadScreen> {
  late final Future<ReplayBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ReplayBundle> _load() async {
    final id =
        ref.read(liveHubProvider).sessionId ?? await SessionStore.latestId();
    if (id == null) {
      return const ReplayBundle(samples: [], notes: []);
    }
    final samples = await SessionStore.loadSamples(id);
    final notes = await SessionStore.loadNotes(id);
    final meta = await SessionStore.loadMeta(id);
    return ReplayBundle(samples: samples, notes: notes, meta: meta);
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
        leading: BackButton(onPressed: widget.onBack),
      ),
      body: FutureBuilder<ReplayBundle>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final b = snap.data ??
              const ReplayBundle(samples: [], notes: []);
          return ReplayBody(
            samples: b.samples,
            notes: b.notes,
            meta: b.meta,
            title: widget.title,
          );
        },
      ),
    );
  }
}
