import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../session/double_press_stop.dart';
import '../../session/heel.dart';
import '../../session/live_hub.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/heel_banner.dart';
import '../../widgets/heel_gauge.dart';

class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  final _stop = DoublePressStop();
  bool _stopArmed = false;

  Future<void> _onStop() async {
    final done = _stop.press();
    if (!done) {
      setState(() => _stopArmed = true);
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _stopArmed = false);
      });
      return;
    }
    await ref.read(liveHubProvider.notifier).stop();
    if (!mounted) return;
    context.go(AppRoutes.quai);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(liveHubProvider);
    final gite = s.displayGiteDeg ?? s.giteDeg;
    final alert = heelAlertFor(s.giteDeg);

    return Scaffold(
      backgroundColor: DeckColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HeelBanner(alert: alert),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Text(
                    'LIVE 1X',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const Spacer(),
                  if (s.code != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        s.code!,
                        style: const TextStyle(
                          color: DeckColors.amber,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  _Chip(
                    ok: !s.gpsLost && s.locationOk,
                    label: s.gpsLost ? 'GPS perdu' : 'GPS',
                  ),
                  const SizedBox(width: 8),
                  _Chip(ok: s.rollDeg != null && s.tareOk, label: 'IMU'),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'sol — pas eau · cadence — · pas de SOG 10 Hz',
                style: TextStyle(color: DeckColors.label, fontSize: 11),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (s.permissionMessage != null &&
                      s.permissionMessage!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        s.permissionMessage!,
                        style: const TextStyle(color: DeckColors.amber),
                      ),
                    ),
                  _kv('CADENCE', '—'),
                  _kv(
                    'V SOL',
                    s.sog == null
                        ? '—'
                        : '${s.sog!.toStringAsFixed(2)} m/s',
                  ),
                  _kv(
                    'DISTANCE',
                    '${(s.distM / 1000).toStringAsFixed(3)} km',
                  ),
                  _kv(
                    'GÎTE',
                    gite == null
                        ? 'tare requise'
                        : '${gite.toStringAsFixed(1)}°',
                  ),
                  const SizedBox(height: 8),
                  const HeelLabels(),
                  HeelGauge(giteDeg: gite ?? 0),
                  const SizedBox(height: 8),
                  _kv(
                    'LAT / LON',
                    (s.lat == null || s.lon == null)
                        ? '—'
                        : '${s.lat!.toStringAsFixed(5)}  ${s.lon!.toStringAsFixed(5)}',
                  ),
                  _kv(
                    'ACC_H',
                    s.accH == null ? '—' : '${s.accH!.toStringAsFixed(1)} m',
                  ),
                  _kv('BATT / NET', '${s.batt ?? '—'} %   ${s.net}'),
                  _kv(
                    'FICHIER',
                    s.sessionDir == null
                        ? '…'
                        : '${s.sessionDir}/samples.jsonl  (${s.sampleCount})',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gauche = TRIBORD (vert) · droite = BÂBORD (rouge) · réf. rameur',
                    style: TextStyle(color: DeckColors.label, fontSize: 11),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _stopArmed ? DeckColors.alert : null,
                  side: BorderSide(
                    color: _stopArmed ? DeckColors.alert : DeckColors.hairline,
                  ),
                ),
                onPressed: _onStop,
                child: Text(
                  _stopArmed ? 'STOP — RETOUCHER (3 S)' : 'STOP  ·  TOUCHER 2×',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            k,
            style: const TextStyle(
              color: DeckColors.label,
              fontSize: 10,
              letterSpacing: 1.3,
            ),
          ),
          Text(
            v,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            color: ok ? DeckColors.tribord : DeckColors.hairline,
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
