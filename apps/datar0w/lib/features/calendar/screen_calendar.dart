import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../calendar/catalog.dart';
import '../../identity/controller.dart';
import '../../identity/models.dart';
import '../../theme/deck_theme.dart';
import '../../widgets/deck_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// DR-43 — Calendrier & régates (Stitch).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  String? _type;

  @override
  Widget build(BuildContext context) {
    final rower = ref.watch(identityProvider).activeRower;
    return DeckScaffold(
      title: 'Calendrier',
      subtitle: 'Catalogue curaté · pas un scrape FFA',
      body: FutureBuilder<CalendarCatalog>(
        future: CalendarCatalog.load(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var list = snap.data!.events;
          if (_type != null) {
            list = list.where((e) => e.type == _type).toList();
          }
          if (rower?.level == RowerLevel.loisir) {
            list = list
                .where(
                  (e) =>
                      e.openToLoisir ||
                      e.type == 'randonnee' ||
                      e.type == 'master',
                )
                .toList();
          }
          return Column(
            children: [
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _chip('Tous', null),
                    _chip('Ouvertes', 'regate_ouverte'),
                    _chip('Rando', 'randonnee'),
                    _chip('Master', 'master'),
                    _chip('Championnat', 'championnat'),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final e = list[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: DeckColors.surface,
                        borderRadius: DeckRadii.cardAll,
                        child: InkWell(
                          borderRadius: DeckRadii.cardAll,
                          onTap: () => context.go('/calendar/${e.id}'),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: DeckRadii.cardAll,
                              border: Border.all(color: DeckColors.hairline),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.typeLabel,
                                  style: DeckType.labelMono(
                                    color: DeckColors.volt,
                                    size: 10,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  e.name,
                                  style: const TextStyle(
                                    fontFamily: DeckType.ui,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${e.start.toIso8601String().split('T').first}'
                                  ' · ${e.city ?? '—'} · ${e.licenceRequise}',
                                  style: const TextStyle(
                                    fontFamily: DeckType.ui,
                                    color: DeckColors.label,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, String? type) {
    final on = _type == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: on,
        onSelected: (_) => setState(() => _type = type),
      ),
    );
  }
}
