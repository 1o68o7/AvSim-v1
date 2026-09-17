import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import '../../widgets/deck_widgets.dart';

class PresessionScreen extends StatefulWidget {
  const PresessionScreen({super.key});

  @override
  State<PresessionScreen> createState() => _PresessionScreenState();
}

class _PresessionScreenState extends State<PresessionScreen> {
  final _bassin = TextEditingController(text: 'Bassin de Mantes-la-Jolie');

  @override
  void dispose() {
    _bassin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DeckScaffold(
      title: 'DATAR0W / 2A  ·  PRÉ-SESSION',
      subtitle: 'Configuration séance',
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                const Text(
                  'PARAMÉTRAGE MATÉRIEL ET TÉLÉMÉTRIE AVANT MISE À L’EAU',
                  style: TextStyle(
                    color: DeckColors.label,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'CLASSE D’EMBARCATION',
                  style: TextStyle(
                    color: DeckColors.label,
                    fontSize: 10,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'SÉLECTIONNÉ : 1X',
                  style: TextStyle(
                    color: DeckColors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    Expanded(child: _ClassChip(code: '1X', name: 'Skiff', on: true)),
                    SizedBox(width: 8),
                    Expanded(child: _ClassChip(code: '2X', name: 'Double')),
                    SizedBox(width: 8),
                    Expanded(child: _ClassChip(code: '4-', name: 'Pointe')),
                    SizedBox(width: 8),
                    Expanded(child: _ClassChip(code: '8+', name: 'Huit')),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'BASSIN / PLAN D’EAU',
                  style: TextStyle(
                    color: DeckColors.label,
                    fontSize: 10,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bassin,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    suffixText: '2 000 m',
                    suffixStyle: TextStyle(
                      color: DeckColors.label,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'CAPTEURS TÉLÉMÉTRIQUES',
                  style: TextStyle(
                    color: DeckColors.label,
                    fontSize: 10,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                const _SensorRow(name: 'GPS', state: 'ACTIF', ok: true),
                const _SensorRow(name: 'IMU', state: 'ACTIF', ok: true),
                const _SensorRow(name: 'BLE', state: '— aucun', ok: false),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.go(AppRoutes.tare),
                child: const Text('CONTINUER — TARE GÎTE'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassChip extends StatelessWidget {
  const _ClassChip({required this.code, required this.name, this.on = false});

  final String code;
  final String name;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: DeckColors.bg,
        border: Border.all(color: on ? DeckColors.amber : DeckColors.hairline),
      ),
      child: Column(
        children: [
          Text(
            code,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: on ? DeckColors.amber : DeckColors.label,
            ),
          ),
          Text(
            name.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              color: DeckColors.label,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorRow extends StatelessWidget {
  const _SensorRow({
    required this.name,
    required this.state,
    required this.ok,
  });

  final String name;
  final String state;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DeckColors.hairline)),
      ),
      child: Row(
        children: [
          DeckIconBox(
            icon: name == 'GPS'
                ? Icons.gps_fixed
                : name == 'IMU'
                    ? Icons.screen_rotation
                    : Icons.bluetooth_disabled,
            accent: ok,
            muted: !ok,
          ),
          const SizedBox(width: 12),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          DeckStatusChip(label: state, ok: ok),
        ],
      ),
    );
  }
}
