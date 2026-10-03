import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/deck_theme.dart';
import 'controller.dart';
import 'models.dart';

/// DR-FR-3 — Preview du morceau.
class FunnelPreviewScreen extends ConsumerStatefulWidget {
  const FunnelPreviewScreen({super.key, this.distM});

  final int? distM;

  @override
  ConsumerState<FunnelPreviewScreen> createState() =>
      _FunnelPreviewScreenState();
}

class _FunnelPreviewScreenState extends ConsumerState<FunnelPreviewScreen> {
  late int _distM;
  late final TextEditingController _dfCtrl;

  @override
  void initState() {
    super.initState();
    final funnel = ref.read(funnelProvider);
    _distM = widget.distM ??
        funnel.activeDistM ??
        funnel.profile?.playDistanceM ??
        ErgDistance.m500.meters;
    final df = funnel.profile?.dragFactor ?? 115;
    _dfCtrl = TextEditingController(text: df.toString());
  }

  @override
  void dispose() {
    _dfCtrl.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final df = int.tryParse(_dfCtrl.text.trim());
    ref.read(funnelProvider.notifier).setActivePiece(
          distM: _distM,
          dragFactor: df,
        );
    final needs =
        await ref.read(funnelProvider.notifier).needsBrief(_distM);
    if (!mounted) return;
    if (needs) {
      context.go(AppRoutes.funnelBrief);
    } else {
      context.go(AppRoutes.funnelPlayer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dist = ErgDistance.fromMeters(_distM);
    final target = ref.watch(funnelProvider).profile?.targetSplit500s;
    final cues = _distM == ErgDistance.m2000.meters
        ? const [
            '0–500 m · installation',
            '500–1 500 m · tenu',
            '1 500–2 000 m · cadence +2',
          ]
        : const [
            'Départ propre',
            'Cadence stable',
            'Split affiché',
          ];

    return Scaffold(
      backgroundColor: DeckColors.bg,
      appBar: AppBar(
        backgroundColor: DeckColors.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DeckColors.text),
          onPressed: () => context.go(AppRoutes.homeRower),
        ),
        title: Text(
          dist?.label ?? '$_distM m',
          style: const TextStyle(
            fontFamily: DeckType.ui,
            fontWeight: FontWeight.w600,
            color: DeckColors.text,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Fiche du morceau',
                style: DeckType.uiLabel(color: DeckColors.label),
              ),
              const SizedBox(height: 12),
              _Row(
                label: 'Distance',
                value: dist?.label ?? '$_distM m',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Drag factor',
                      style: DeckType.uiLabel(),
                    ),
                  ),
                  SizedBox(
                    width: 88,
                    child: TextField(
                      controller: _dfCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.end,
                      style: DeckType.metric(size: 20),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '115',
                      ),
                    ),
                  ),
                ],
              ),
              if (target != null) ...[
                const SizedBox(height: 10),
                _Row(
                  label: 'Split cible',
                  value: formatSplit500(target),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Cues',
                style: DeckType.uiLabel(weight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final c in cues) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    c,
                    style: const TextStyle(
                      fontFamily: DeckType.ui,
                      fontSize: 15,
                      color: DeckColors.text,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _go,
                  child: const Text('Je suis sur l’erg'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: DeckType.uiLabel())),
        Text(
          value,
          style: DeckType.metric(size: 18, weight: FontWeight.w600),
        ),
      ],
    );
  }
}
