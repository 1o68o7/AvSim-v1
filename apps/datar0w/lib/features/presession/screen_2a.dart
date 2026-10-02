import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../session/boat_config.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import '../../widgets/deck_widgets.dart';
import '../../widgets/mode_banner.dart';

/// DR-50 — Préparer la séance (Stitch).
class PresessionScreen extends ConsumerStatefulWidget {
  const PresessionScreen({super.key});

  @override
  ConsumerState<PresessionScreen> createState() => _PresessionScreenState();
}

class _PresessionScreenState extends ConsumerState<PresessionScreen> {
  static const _recentBasins = [
    'Lac de Lacanau',
    'Canal de Mimizan',
    'Cazaux',
  ];

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

  String _seatStatus(BoatConfig cfg) {
    final info = cfg.info;
    if (info.code == '1x') return 'Skiff individuel (siège fixe)';
    if (cfg.isCox && info.coxed) {
      return 'Barreur · ${cfg.coxPosition.wire} · pas de siège rameur';
    }
    return 'Équipage · siège ${cfg.clampedSeat}/${info.seats} · 1 = nage';
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(boatConfigProvider);
    final info = cfg.info;
    final coxNeedsBoat = cfg.role == CrewRole.cox && !info.coxed;
    final training = cfg.sessionMode == SessionMode.training;
    final readyCount = training ? '3/3 opérationnels' : '2/3 + patch autonome';

    return DeckScaffold(
      title: 'Préparer la séance',
      subtitle: 'Réglages avant mise à l’eau',
      showRetour: false,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => performDeckRetour(context, ref),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Annuler'),
                      style: TextButton.styleFrom(
                        foregroundColor: DeckColors.label,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                    const Spacer(),
                    DeckStatusChip(label: 'Pont armé', ok: true),
                  ],
                ),
                const SizedBox(height: 12),
                const DeckSectionLabel('01. Régime de sortie'),
                const SizedBox(height: 8),
                _RegimeGrid(
                  mode: cfg.sessionMode,
                  onChanged: (m) =>
                      ref.read(boatConfigProvider.notifier).setSessionMode(m),
                ),
                const SizedBox(height: 8),
                if (!training) ...[
                  const CompetitionBanner(),
                  const SizedBox(height: 8),
                ],
                _InfoCallout(
                  icon: training ? Icons.info_outline : Icons.security,
                  iconColor: training ? DeckColors.volt : DeckColors.error,
                  title: training
                      ? 'Capteurs embarqués actifs'
                      : 'Règlement World Rowing / FFA',
                  body: training
                      ? 'Ton téléphone est calé directement dans le bateau '
                          '(sur cale-pied ou barreur). Il mesure ton cap GPS '
                          'et la gîte de coque en direct.'
                      : 'Le téléphone reste au quai. Le patch autonome logue '
                          'tes données en mer ou sur le bassin sans retour '
                          'télémétrique en direct.',
                ),
                const SizedBox(height: 20),
                DeckSectionLabel('02. Type d’embarcation'),
                const SizedBox(height: 4),
                Text(
                  _seatStatus(cfg),
                  style: DeckType.labelMono(size: 10),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in BoatClassInfo.all)
                      _BoatChip(
                        label: '${c.code} ${c.label}',
                        selected: cfg.classe == c.code,
                        showIcon: c.code == '1x',
                        onTap: () => ref
                            .read(boatConfigProvider.notifier)
                            .setClasse(c.code),
                      ),
                  ],
                ),
                if (info.coxed) ...[
                  const SizedBox(height: 16),
                  const DeckSectionLabel('Rôle dans ce bateau'),
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
                  const DeckSectionLabel('Position barreur'),
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
                      'Défaut : arrière (le plus courant). Pas de siège rameur. '
                      'Les rameurs restent en attente (local / poll API).',
                      style: TextStyle(
                        fontFamily: DeckType.ui,
                        color: DeckColors.label,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  DeckSectionLabel(
                    'Siège dans ${info.code} · ${cfg.clampedSeat} / ${info.seats} · 1 = nage',
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
                          ? 'Un smartphone = un hub / une place (${info.code}).'
                          : 'Ce tél. = siège ${cfg.clampedSeat}. '
                              'Autres places (${cfg.waitingSeats.join(', ')}) : '
                              'en attente (local) ou poll API (Lot G).',
                      style: const TextStyle(
                        fontFamily: DeckType.ui,
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
                      'Profil barreur : choisir 4+ ou 8+.',
                      style: TextStyle(
                        fontFamily: DeckType.ui,
                        color: DeckColors.volt,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const DeckSectionLabel('03. Plan d’eau'),
                const SizedBox(height: 8),
                TextField(
                  controller: _bassin,
                  onChanged: (v) =>
                      ref.read(boatConfigProvider.notifier).setBassin(v),
                  style: const TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nom du plan d’eau ou rivière',
                    hintStyle: const TextStyle(
                      color: DeckColors.label,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.water,
                      color: DeckColors.label,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: DeckColors.bgTactical,
                    border: OutlineInputBorder(
                      borderRadius: DeckRadii.cardAll,
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Récents :',
                      style: DeckType.labelMono(size: 10),
                    ),
                    for (final name in _recentBasins)
                      ActionChip(
                        label: Text(
                          name,
                          style: const TextStyle(
                            fontFamily: DeckType.ui,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () {
                          _bassin.text = name;
                          ref.read(boatConfigProvider.notifier).setBassin(name);
                        },
                        backgroundColor: DeckColors.surface,
                        side: const BorderSide(color: DeckColors.hairline),
                        shape: RoundedRectangleBorder(
                          borderRadius: DeckRadii.chipAll,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                DeckSectionLabel(
                  '04. État des flux matériel',
                  trailing: Text(
                    readyCount,
                    style: DeckType.labelMono(
                      color: DeckColors.tribord,
                      size: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: DeckColors.surface,
                    borderRadius: DeckRadii.cardAll,
                    border: Border.all(color: DeckColors.hairline),
                  ),
                  child: Column(
                    children: [
                      const _SensorTile(
                        icon: Icons.my_location,
                        title: 'GPS téléphone',
                        subtitle: 'Fréquence brute 10 Hz',
                        status: 'Prêt',
                        detail: 'Précision ~3 m',
                        ok: true,
                      ),
                      const SizedBox(height: 4),
                      const _SensorTile(
                        icon: Icons.screen_rotation_alt,
                        title: 'IMU gyroscope',
                        subtitle: 'Attitude transversale',
                        status: 'Prêt',
                        detail: 'Gîte lissée active',
                        ok: true,
                      ),
                      const SizedBox(height: 4),
                      _SensorTile(
                        icon: Icons.favorite,
                        title: 'Cardio BLE (0x180D)',
                        subtitle: 'Canal standard FC',
                        status: training ? 'Prêt' : 'Patch',
                        detail: training ? 'Sangle / patch' : 'Course : patch',
                        ok: true,
                      ),
                      const SizedBox(height: 4),
                      _SensorTile(
                        icon: Icons.sensors_off,
                        title: 'Patch dorsal',
                        subtitle: 'Accélérométrie haute fréquence',
                        status: training ? 'Option' : 'Autonome',
                        detail: training
                            ? 'Non requis en entraînement'
                            : 'Log flash autonome',
                        ok: !training,
                        demo: training,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: DeckColors.bgTactical,
                    borderRadius: DeckRadii.cardAll,
                    border: Border.all(color: DeckColors.hairline),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DeckIconBox(
                        icon: Icons.stay_current_portrait,
                        accent: true,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Repère de pont',
                              style: TextStyle(
                                fontFamily: DeckType.ui,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: DeckColors.text,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Oriente l’écran face à toi, bien aligné dans '
                              'l’axe longitudinal de la quille.',
                              style: TextStyle(
                                fontFamily: DeckType.ui,
                                color: DeckColors.label,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: coxNeedsBoat
                      ? null
                      : () => context.go(AppRoutes.tare),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.adjust, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Caler le téléphone',
                          style: TextStyle(
                            fontFamily: DeckType.ui,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        'Étape tare',
                        style: TextStyle(
                          fontFamily: DeckType.mono,
                          fontSize: 11,
                          letterSpacing: 0.6,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Prêt à embarquer · Mesure en autonomie locale',
                  textAlign: TextAlign.center,
                  style: DeckType.labelMono(size: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegimeGrid extends StatelessWidget {
  const _RegimeGrid({required this.mode, required this.onChanged});

  final SessionMode mode;
  final ValueChanged<SessionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DeckColors.bgTactical,
        borderRadius: DeckRadii.cardAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: _RegimeTile(
              selected: mode == SessionMode.training,
              icon: Icons.sailing,
              title: 'Entraînement',
              subtitle: 'Télémétrie live',
              onTap: () => onChanged(SessionMode.training),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _RegimeTile(
              selected: mode == SessionMode.competition,
              icon: Icons.timer,
              title: 'Compétition',
              subtitle: 'Règle FFA / WR',
              onTap: () => onChanged(SessionMode.competition),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegimeTile extends StatelessWidget {
  const _RegimeTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DeckRadii.buttonAll,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? DeckColors.surfaceHigh : Colors.transparent,
            borderRadius: DeckRadii.buttonAll,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? DeckColors.volt : DeckColors.label,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: DeckType.ui,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? DeckColors.text : DeckColors.label,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: DeckType.labelMono(
                  color: selected ? DeckColors.volt : DeckColors.label,
                  size: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoatChip extends StatelessWidget {
  const _BoatChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.showIcon = false,
  });

  final String label;
  final bool selected;
  final bool showIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DeckRadii.buttonAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? DeckColors.volt : DeckColors.surfaceHigh,
            borderRadius: DeckRadii.buttonAll,
            border: Border.all(
              color: selected ? DeckColors.volt : DeckColors.hairline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon) ...[
                Icon(
                  Icons.rowing,
                  size: 18,
                  color: selected ? DeckColors.onVolt : DeckColors.text,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: DeckType.ui,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? DeckColors.onVolt : DeckColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCallout extends StatelessWidget {
  const _InfoCallout({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: DeckRadii.cardAll,
        border: Border.all(color: DeckColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DeckColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 12,
                    height: 1.35,
                    color: DeckColors.label,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorTile extends StatelessWidget {
  const _SensorTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.detail,
    required this.ok,
    this.demo = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final String detail;
  final bool ok;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: DeckColors.surfaceHigh.withValues(alpha: demo ? 0.55 : 1),
        borderRadius: DeckRadii.buttonAll,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: ok && !demo ? DeckColors.tribord : DeckColors.label,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: DeckType.ui,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: demo ? DeckColors.label : DeckColors.text,
                        ),
                      ),
                    ),
                    if (demo) ...[
                      const SizedBox(width: 6),
                      const DeckHonestChip(kind: DeckHonestKind.mock),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DeckType.labelMono(size: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DeckType.labelMono(
                    color: ok && !demo ? DeckColors.tribord : DeckColors.label,
                    size: 11,
                    weight: FontWeight.w600,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: DeckType.labelMono(size: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
