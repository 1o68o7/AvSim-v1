import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../session/api_client.dart';
import '../../session/live_hub.dart';
import '../../session/store.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import '../../widgets/deck_widgets.dart';

class CoachJoinScreen extends ConsumerStatefulWidget {
  const CoachJoinScreen({super.key});

  @override
  ConsumerState<CoachJoinScreen> createState() => _CoachJoinScreenState();
}

class _CoachJoinScreenState extends ConsumerState<CoachJoinScreen> {
  final _ctrl = TextEditingController();
  String? _error;
  SessionMeta? _last;

  @override
  void initState() {
    super.initState();
    _loadLast();
  }

  Future<void> _loadLast() async {
    final id = await SessionStore.latestId();
    if (id == null) return;
    final m = await SessionStore.loadMeta(id);
    if (mounted) setState(() => _last = m);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _go(String? id) async {
    if (!mounted) return;
    if (id == null) {
      setState(() => _error = SessionApi.enabled
          ? 'Code inconnu (local + API).'
          : 'Code inconnu (mode local, même téléphone).');
      return;
    }
    context.go(AppRoutes.coachLive);
  }

  Future<void> _join({bool last = false, bool apiLive = false}) async {
    setState(() => _error = null);
    final hub = ref.read(liveHubProvider.notifier);
    if (last) {
      await _go(await hub.joinAsCoach(''));
      return;
    }
    if (apiLive) {
      await _go(await hub.joinRemoteLive(_ctrl.text));
      return;
    }
    await _go(await hub.joinAsCoach(_ctrl.text));
  }

  @override
  Widget build(BuildContext context) {
    final api = SessionApi.enabled;
    return DeckScaffold(
      title: 'COACH',
      subtitle: api ? 'code · local ou API' : 'code séance · mode local',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'CODE SÉANCE (6 CAR.)',
              style: TextStyle(color: DeckColors.label, fontSize: 11),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(letterSpacing: 4, fontSize: 22),
              decoration: const InputDecoration(
                hintText: 'K7P2QM',
                counterText: '',
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: DeckColors.amber)),
            if (_last != null) ...[
              const SizedBox(height: 16),
              Text(
                'DERNIÈRE SÉANCE LOCALE  ·  ${_last!.classe.toUpperCase()}'
                '${_last!.code == null ? '' : '  ${_last!.code}'}',
                style: const TextStyle(color: DeckColors.label, fontSize: 11),
              ),
              const SizedBox(height: 4),
              DeckStatusChip(label: _last!.id, ok: true),
            ],
            const Spacer(),
            FilledButton(
              onPressed: _join,
              child: const Text('REJOINDRE'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _join(last: true),
              child: const Text('DERNIÈRE SÉANCE (MÊME TÉL.)'),
            ),
            if (api) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _join(apiLive: true),
                child: const Text('SÉANCE LIVE (API)'),
              ),
            ],
            TextButton(
              onPressed: () => context.go(AppRoutes.profile),
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }
}
