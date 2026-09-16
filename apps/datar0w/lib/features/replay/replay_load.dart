import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../session/live_hub.dart';
import '../../session/model.dart';
import '../../session/store.dart';
import '../../theme/deck_theme.dart';
import 'replay_body.dart';

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
  late final Future<List<SessionSample>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<SessionSample>> _load() async {
    final id =
        ref.read(liveHubProvider).sessionId ?? await SessionStore.latestId();
    if (id == null) return [];
    return SessionStore.loadSamples(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DeckColors.bg,
      appBar: AppBar(
        title: Text(widget.title),
        leading: BackButton(onPressed: widget.onBack),
      ),
      body: FutureBuilder<List<SessionSample>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return ReplayBody(samples: snap.data ?? const []);
        },
      ),
    );
  }
}
