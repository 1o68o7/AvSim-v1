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

/// DR-32 — Rejoindre par code (Stitch Deck Volt).
class CoachJoinScreen extends ConsumerStatefulWidget {
  const CoachJoinScreen({super.key});

  @override
  ConsumerState<CoachJoinScreen> createState() => _CoachJoinScreenState();
}

class _CoachJoinScreenState extends ConsumerState<CoachJoinScreen> {
  final _ctrl = TextEditingController();
  String? _error;
  SessionMeta? _last;
  bool _joining = false;

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

  String get _codeRaw => _ctrl.text.trim().toUpperCase();

  bool get _codeReady => _codeRaw.length >= 4;

  Future<void> _go(String? id) async {
    if (!mounted) return;
    if (id == null) {
      setState(() {
        _joining = false;
        _error = SessionApi.enabled
            ? 'Code inconnu (local + API).'
            : 'Code inconnu (mode local, même téléphone).';
      });
      return;
    }
    context.go(AppRoutes.coachLive);
  }

  Future<void> _join({bool last = false, bool apiLive = false}) async {
    setState(() {
      _error = null;
      _joining = true;
    });
    final hub = ref.read(liveHubProvider.notifier);
    try {
      if (last) {
        await _go(await hub.joinAsCoach(''));
        return;
      }
      if (apiLive) {
        await _go(await hub.joinRemoteLive(_ctrl.text));
        return;
      }
      await _go(await hub.joinAsCoach(_ctrl.text));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = SessionApi.enabled;
    final code = _codeRaw;
    final cta = !_codeReady
        ? 'Saisir un code valide'
        : 'Rejoindre le direct${code.isEmpty ? '' : ' ($code)'}';

    return DeckScaffold(
      title: 'Rejoindre par code',
      subtitle: api ? 'Local ou cloud' : 'Mode local · même téléphone',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: DeckColors.surfaceHigh,
              borderRadius: DeckRadii.buttonAll,
              border: Border.all(color: DeckColors.hairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: DeckColors.tribord,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Poste coach',
                        style: TextStyle(
                          fontFamily: DeckType.ui,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        api
                            ? 'Local direct ou cloud actif'
                            : 'Local direct · P2P même appareil',
                        style: DeckType.labelMono(
                          color: DeckColors.tribord,
                          size: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: DeckColors.bg,
                    borderRadius: DeckRadii.chipAll,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sensors,
                          size: 14, color: DeckColors.tribord),
                      const SizedBox(width: 4),
                      Text(
                        api ? 'API' : 'Local',
                        style: DeckType.labelMono(size: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: DeckColors.surface,
              borderRadius: DeckRadii.cardAll,
              border: Border.all(color: DeckColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tag, color: DeckColors.volt, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Code de séance en direct',
                        style: TextStyle(
                          fontFamily: DeckType.ui,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: DeckColors.bg,
                        borderRadius: DeckRadii.chipAll,
                      ),
                      child: Text('Deck-sync',
                          style: DeckType.labelMono(size: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: DeckColors.bg,
                    borderRadius: DeckRadii.buttonAll,
                    border: Border.all(color: DeckColors.hairline),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 8,
                          onChanged: (_) => setState(() {}),
                          style: DeckType.metric(
                            size: 28,
                            color: DeckColors.volt,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'K7P2QM',
                            counterText: '',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Effacer',
                        onPressed: () {
                          _ctrl.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.backspace_outlined),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Saisis le code affiché sur le téléphone embarqué ou généré '
                  'par l’équipage.',
                  style: TextStyle(
                    fontFamily: DeckType.ui,
                    color: DeckColors.label,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style:
                        const TextStyle(color: DeckColors.volt, fontSize: 13),
                  ),
                ],
                if (_last != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DeckColors.surfaceHigh,
                      borderRadius: DeckRadii.buttonAll,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: DeckColors.tribord,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Dernière séance locale',
                                style: TextStyle(
                                  fontFamily: DeckType.ui,
                                  color: DeckColors.tribord,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${_last!.classe}'
                                '${_last!.code == null ? '' : ' · ${_last!.code}'}',
                                style: DeckType.labelMono(size: 10),
                              ),
                            ],
                          ),
                        ),
                        DeckStatusChip(label: _last!.id, ok: true),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: (!_codeReady || _joining) ? null : () => _join(),
                    icon: _joining
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.stream),
                    label: Text(cta),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const DeckSectionLabel('Actions rapides'),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.history,
            title: 'Dernière séance (même tél.)',
            subtitle: 'Reprendre le flux local le plus récent',
            onTap: () => _join(last: true),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.folder_open,
            title: 'Toutes les séances locales',
            subtitle: 'Bibliothèque appareil',
            onTap: () => context.go('${AppRoutes.sessions}?from=coach'),
          ),
          if (api) ...[
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.cloud_sync,
              title: 'Séance live (API)',
              subtitle: 'Relais cloud club',
              accent: true,
              onTap: () => _join(apiLive: true),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: DeckColors.bg,
              borderRadius: DeckRadii.cardAll,
              border: Border.all(color: DeckColors.hairline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: DeckColors.surfaceHigh,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.anchor,
                    color: DeckColors.volt,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mode canot / bord de bassin',
                        style: TextStyle(
                          fontFamily: DeckType.ui,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Connexion P2P locale ou relais club cloud. '
                        'Aucune perte de notes ni d’intervalles en zone blanche.',
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
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DeckColors.surface,
      borderRadius: DeckRadii.cardAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: DeckRadii.cardAll,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: DeckRadii.cardAll,
            border: Border.all(
              color: accent
                  ? DeckColors.volt.withValues(alpha: 0.4)
                  : DeckColors.hairline,
            ),
          ),
          child: Row(
            children: [
              DeckIconBox(icon: icon, accent: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: DeckType.ui,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: DeckType.ui,
                        color: DeckColors.label,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: DeckColors.label),
            ],
          ),
        ),
      ),
    );
  }
}
