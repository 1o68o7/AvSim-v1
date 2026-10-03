import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/deck_theme.dart';
import 'controller.dart';
import 'models.dart';

/// DR-FR-00 — Promesse + choix de pratique (Lot 1).
class FunnelOnboardScreen extends ConsumerStatefulWidget {
  const FunnelOnboardScreen({super.key});

  @override
  ConsumerState<FunnelOnboardScreen> createState() =>
      _FunnelOnboardScreenState();
}

class _FunnelOnboardScreenState extends ConsumerState<FunnelOnboardScreen> {
  int _step = 0; // 0 promise · 1 practice · 2 loisir durée · 3 compétition temps
  PracticeFrame? _frame;

  Future<void> _finish(FunnelProfile profile) async {
    await ref.read(funnelProvider.notifier).completeOnboard(profile);
    if (!mounted) return;
    context.go(AppRoutes.homeRower);
  }

  Future<void> _skip() async {
    await _finish(
      const FunnelProfile(
        frame: PracticeFrame.loisir,
        todayDurationMin: 15,
        todayDistanceM: 0,
        onboardDone: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DeckColors.bg,
      appBar: AppBar(
        backgroundColor: DeckColors.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DeckColors.text),
          onPressed: () {
            if (_step == 0) {
              context.go(AppRoutes.discover);
            } else {
              setState(() => _step = _step == 2 || _step == 3 ? 1 : 0);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: switch (_step) {
            0 => _PromiseStep(
                onStart: () => setState(() => _step = 1),
                onAccount: () => context.go(AppRoutes.auth),
              ),
            1 => _PracticeStep(
                onPick: (f) {
                  setState(() {
                    _frame = f;
                    if (f == PracticeFrame.loisir ||
                        f == PracticeFrame.sante ||
                        f == PracticeFrame.handiSante) {
                      _step = 2;
                    } else if (f == PracticeFrame.competition) {
                      _step = 3;
                    } else {
                      // Para / adapté : 15 min, pas de 2000 imposé.
                      _finish(
                        FunnelProfile(
                          frame: f,
                          todayDurationMin: 15,
                          todayDistanceM: 0,
                        ),
                      );
                    }
                  });
                },
                onSkip: _skip,
              ),
            2 => _DurationStep(
                frame: _frame ?? PracticeFrame.loisir,
                onPick: (min) => _finish(
                  FunnelProfile(
                    frame: _frame ?? PracticeFrame.loisir,
                    todayDurationMin: min,
                    todayDistanceM: 0,
                  ),
                ),
              ),
            _ => _CompetitionStep(
                onHasTime: (has) => _finish(
                  FunnelProfile(
                    frame: PracticeFrame.competition,
                    todayDistanceM: has
                        ? ErgDistance.m2000.meters
                        : ErgDistance.m500.meters,
                    targetSplit500s: has ? 120 : null,
                  ),
                ),
              ),
          },
        ),
      ),
    );
  }
}

class _PromiseStep extends StatelessWidget {
  const _PromiseStep({required this.onStart, required this.onAccount});

  final VoidCallback onStart;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Un morceau déjà écrit. Tu sais quoi lire sur le moniteur.',
          style: TextStyle(
            fontFamily: DeckType.ui,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: DeckColors.text,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Temps au 500 · cadence · watts.\n'
          'Le drag factor si tu es en compétition.',
          style: TextStyle(
            fontFamily: DeckType.ui,
            fontSize: 15,
            height: 1.45,
            color: DeckColors.label,
          ),
        ),
        const Spacer(),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: onStart,
            child: const Text('Commencer'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onAccount,
          child: const Text(
            'J’ai déjà un compte',
            style: TextStyle(color: DeckColors.muted),
          ),
        ),
      ],
    );
  }
}

class _PracticeStep extends StatelessWidget {
  const _PracticeStep({required this.onPick, required this.onSkip});

  final ValueChanged<PracticeFrame> onPick;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final frames = [
      PracticeFrame.loisir,
      PracticeFrame.sante,
      PracticeFrame.competition,
      PracticeFrame.para,
      PracticeFrame.paraAdapte,
      PracticeFrame.handiSante,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Tu rames dans quel cadre ?',
          style: TextStyle(
            fontFamily: DeckType.ui,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: DeckColors.text,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: frames.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final f = frames[i];
              return Material(
                color: DeckColors.surface,
                borderRadius: DeckRadii.cardAll,
                child: InkWell(
                  borderRadius: DeckRadii.cardAll,
                  onTap: () => onPick(f),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: DeckRadii.cardAll,
                      border: Border.all(color: DeckColors.hairline),
                    ),
                    child: Text(
                      f.label,
                      style: const TextStyle(
                        fontFamily: DeckType.ui,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: DeckColors.text,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        TextButton(
          onPressed: onSkip,
          child: const Text(
            'Plus tard',
            style: TextStyle(color: DeckColors.muted),
          ),
        ),
      ],
    );
  }
}

class _DurationStep extends StatelessWidget {
  const _DurationStep({required this.frame, required this.onPick});

  final PracticeFrame frame;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final options = frame == PracticeFrame.sante ||
            frame == PracticeFrame.handiSante
        ? const [15, 30, 45, 60]
        : const [15, 30];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Combien de temps aujourd’hui ?',
          style: TextStyle(
            fontFamily: DeckType.ui,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: DeckColors.text,
          ),
        ),
        const SizedBox(height: 16),
        for (final m in options) ...[
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () => onPick(m),
              child: Text('$m min'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CompetitionStep extends StatelessWidget {
  const _CompetitionStep({required this.onHasTime});

  final ValueChanged<bool> onHasTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Déjà un temps ?',
          style: TextStyle(
            fontFamily: DeckType.ui,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: DeckColors.text,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sur 2 000 m. Sinon on commence par 500 m.',
          style: TextStyle(
            fontFamily: DeckType.ui,
            fontSize: 14,
            color: DeckColors.label,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: () => onHasTime(true),
            child: const Text('Oui — carte 2 000 m'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: () => onHasTime(false),
            child: const Text('Non — 500 m d’abord'),
          ),
        ),
      ],
    );
  }
}
