import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../onboarding/routing.dart';
import '../../router.dart';
import '../../session/boat_config.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import '../../widgets/deck_widgets.dart';
import '../../widgets/mode_banner.dart';

class PresessionScreen extends ConsumerStatefulWidget {
  const PresessionScreen({super.key});

  @override
  ConsumerState<PresessionScreen> createState() => _PresessionScreenState();
}

class _PresessionScreenState extends ConsumerState<PresessionScreen> {
  late final TextEditingController _bassin;

  @override
  void initState() {
    super.initState();
    _bassin = TextEditingController(text: ref.read(boatConfigProvider).bassin);
  }

  @override
  void dispose() {
    _bassin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(boatConfigProvider);
    final info = cfg.info;
    final coxNeedsBoat = cfg.role == CrewRole.cox && !info.coxed;
    return DeckScaffold(
      title: 'Pré-session',
      subtitle: 'Classe · siège · mode',
      retourFallback: sessionRoleHome(cfg.role),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                if (cfg.sessionMode == SessionMode.competition) ...[
                  const CompetitionBanner(),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Mode',
                  style: TextStyle(
                    color: DeckColors.label,
                    fontSize: 10,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Entraînement'),
                      selected: cfg.sessionMode == SessionMode.training,
                      onSelected: (_) => ref
                          .read(boatConfigProvider.notifier)
                          .setSessionMode(SessionMode.training),
                    ),
                    ChoiceChip(
                      label: const Text('Compétition'),
                      selected: cfg.sessionMode == SessionMode.competition,
                      onSelected: (_) => ref
                          .read(boatConfigProvider.notifier)
                          .setSessionMode(SessionMode.competition),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  cfg.sessionMode == SessionMode.competition
                      ? 'Tél. au quai (FFA). Patch autonome.'
                      : 'Tél. = hub GPS + IMU. Live Deck.',
                  style: const TextStyle(color: DeckColors.muted, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 16),
                const Text(
                  '1 · Classe',
                  style: TextStyle(
                    color: DeckColors.label,
                    fontSize: 10,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${info.code.toUpperCase()}  ·  ${info.seats} siège(s)'
                  '${info.coxed ? '  ·  barré' : ''}',
                  style: const TextStyle(
                    color: DeckColors.volt,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in BoatClassInfo.all)
                      SizedBox(
                        width: 72,
                        child: _ClassChip(
                          code: c.code.toUpperCase(),
                          name: c.label,
                          on: cfg.classe == c.code,
                          onTap: () => ref
                              .read(boatConfigProvider.notifier)
                              .setClasse(c.code),
                        ),
                      ),
                  ],
                ),
                if (info.coxed) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '2 · Rôle',
                    style: TextStyle(
                      color: DeckColors.label,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Rameur'),
                        selected: cfg.role == CrewRole.rower,
                        onSelected: (_) => ref
                            .read(boatConfigProvider.notifier)
                            .setRole(CrewRole.rower),
                      ),
                      ChoiceChip(
                        label: const Text('Barreur'),
                        selected: cfg.role == CrewRole.cox,
                        onSelected: (_) => ref
                            .read(boatConfigProvider.notifier)
                            .setRole(CrewRole.cox),
                      ),
                    ],
                  ),
                ],
                if (cfg.isCox && info.coxed) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '3 · Position barreur',
                    style: TextStyle(
                      color: DeckColors.label,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Arrière'),
                        selected: cfg.coxPosition == CoxPosition.rear,
                        onSelected: (_) => ref
                            .read(boatConfigProvider.notifier)
                            .setCoxPosition(CoxPosition.rear),
                      ),
                      ChoiceChip(
                        label: const Text('Avant'),
                        selected: cfg.coxPosition == CoxPosition.front,
                        onSelected: (_) => ref
                            .read(boatConfigProvider.notifier)
                            .setCoxPosition(CoxPosition.front),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Défaut : arrière. Pas de siège rameur.',
                      style: TextStyle(color: DeckColors.label, fontSize: 11),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Text(
                    '${info.coxed ? '3' : '2'} · Siège ${info.code.toUpperCase()}  ·  ${cfg.clampedSeat} / ${info.seats}  ·  1 = nage',
                    style: const TextStyle(
                      color: DeckColors.label,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 1; i <= info.seats; i++)
                        ChoiceChip(
                          label: Text(i == 1 ? '$i nage' : '$i'),
                          selected: cfg.clampedSeat == i,
                          onSelected: (_) =>
                              ref.read(boatConfigProvider.notifier).setSeat(i),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      cfg.waitingSeats.isEmpty
                          ? 'Un tél. = une place (${info.code}).'
                          : 'Siège ${cfg.clampedSeat}. '
                              'Autres (${cfg.waitingSeats.join(', ')}) : en attente.',
                      style: const TextStyle(
                        color: DeckColors.label,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
                if (coxNeedsBoat)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Barreur : choisir 4+ ou 8+.',
                      style: TextStyle(color: DeckColors.volt, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'Bassin',
                  style: TextStyle(
                    color: DeckColors.label,
                    fontSize: 10,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bassin,
                  onChanged: (v) =>
                      ref.read(boatConfigProvider.notifier).setBassin(v),
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Nom du plan d’eau',
                    hintStyle: TextStyle(
                      color: DeckColors.label,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Capteurs',
                  style: TextStyle(
                    color: DeckColors.label,
                    fontSize: 10,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                const _SensorRow(name: 'GPS', state: 'actif', ok: true),
                const _SensorRow(name: 'IMU', state: 'actif', ok: true),
                _SensorRow(
                  name: 'BLE',
                  state: cfg.sessionMode == SessionMode.competition
                      ? 'patch'
                      : 'sangle / patch',
                  ok: true,
                ),
                _SensorRow(
                  name: 'Patch',
                  state: cfg.sessionMode == SessionMode.competition
                      ? 'autonome'
                      : 'option',
                  ok: cfg.sessionMode == SessionMode.competition,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton(
                  onPressed: () => performDeckRetour(context, ref),
                  child: const Text('Retour'),
                ),
                const SizedBox(height: 4),
                FilledButton(
                  onPressed: coxNeedsBoat
                      ? null
                      : () => context.go(AppRoutes.tare),
                  child: const Text('Tare'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassChip extends StatelessWidget {
  const _ClassChip({
    required this.code,
    required this.name,
    required this.onTap,
    this.on = false,
  });

  final String code;
  final String name;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DeckColors.bg,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: on ? DeckColors.volt : DeckColors.hairline),
          ),
          child: Column(
            children: [
              Text(
                code,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: on ? DeckColors.volt : DeckColors.label,
                ),
              ),
              Text(
                name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 8,
                  color: DeckColors.label,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
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
                    : name == 'PATCH'
                        ? Icons.sensors
                        : Icons.bluetooth,
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
