import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/deck_theme.dart';
import 'controller.dart';
import 'models.dart';

/// DR-FR-3 — Preview du morceau (Lot 1 + Lot 2).
class FunnelPreviewScreen extends ConsumerStatefulWidget {
  const FunnelPreviewScreen({super.key, this.distM, this.pieceId});

  final int? distM;
  final String? pieceId;

  @override
  ConsumerState<FunnelPreviewScreen> createState() =>
      _FunnelPreviewScreenState();
}

class _FunnelPreviewScreenState extends ConsumerState<FunnelPreviewScreen> {
  late ErgPiece _piece;
  late final TextEditingController _dfCtrl;

  @override
  void initState() {
    super.initState();
    final funnel = ref.read(funnelProvider);
    _piece = ErgPiece.byId(widget.pieceId) ??
        funnel.activePiece ??
        (widget.distM != null
            ? ErgPiece.fromDistanceMeters(widget.distM!)
            : funnel.profile?.todayPiece) ??
        ErgPiece.distance500;
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
          piece: _piece,
          dragFactor: df,
        );
    final needs =
        await ref.read(funnelProvider.notifier).needsBrief(_piece);
    if (!mounted) return;
    // Lot 3 : brief (1re fois) puis PM5, sinon PM5 direct.
    if (needs) {
      context.go(AppRoutes.funnelBrief);
    } else {
      context.go(AppRoutes.funnelPm5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = ref.watch(funnelProvider).profile?.targetSplit500s;
    final formatLine = switch (_piece.kind) {
      ErgPieceKind.duration =>
        '${(_piece.durationS ?? 0) ~/ 60} min · cadence ${_piece.targetCadence ?? '—'}',
      ErgPieceKind.intervals =>
        '${_piece.blockCount} × ${(_piece.durationS ?? 60)} s · ${_piece.blockCadences.join(' / ')}',
      ErgPieceKind.relay =>
        '${_piece.blockCount} × ${_piece.blockDistM ?? 500} m',
      ErgPieceKind.distance =>
        ErgDistance.fromMeters(_piece.distM)?.label ?? '${_piece.distM} m',
    };

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
          _piece.label,
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
              _Row(label: 'Format', value: formatLine),
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
              if (target != null &&
                  _piece.kind == ErgPieceKind.distance &&
                  _piece.announcedMinM == null) ...[
                const SizedBox(height: 10),
                _Row(
                  label: 'Split cible',
                  value: formatSplit500(target),
                ),
              ],
              if (_piece.announcedMinM != null) ...[
                const SizedBox(height: 10),
                _Row(
                  label: 'Bande distance',
                  value:
                      '${_piece.announcedMinM}–${_piece.announcedMaxM} m',
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Cues',
                style: DeckType.uiLabel(weight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final c in _piece.cues) ...[
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
