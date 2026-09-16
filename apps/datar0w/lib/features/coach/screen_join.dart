import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../session/live_hub.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';

class CoachJoinScreen extends ConsumerStatefulWidget {
  const CoachJoinScreen({super.key});

  @override
  ConsumerState<CoachJoinScreen> createState() => _CoachJoinScreenState();
}

class _CoachJoinScreenState extends ConsumerState<CoachJoinScreen> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _join({bool last = false}) async {
    final id = await ref.read(liveHubProvider.notifier).joinAsCoach(
          last ? '' : _ctrl.text,
        );
    if (!mounted) return;
    if (id == null) {
      setState(() => _error = 'Code inconnu (mode local, même téléphone).');
      return;
    }
    context.go(AppRoutes.coachLive);
  }

  @override
  Widget build(BuildContext context) {
    return DeckScaffold(
      title: 'COACH',
      subtitle: 'code séance · mode local',
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
