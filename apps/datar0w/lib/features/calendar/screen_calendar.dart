import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../calendar/catalog.dart';
import '../../identity/controller.dart';
import '../../identity/models.dart';
import '../../widgets/deck_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      title: 'CALENDRIER',
      subtitle: 'catalogue curaté · pas un scrape FFA',
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
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.name),
                      subtitle: Text(
                        '${e.start.toIso8601String().split('T').first}'
                        ' · ${e.city ?? '—'} · ${e.typeLabel}'
                        ' · ${e.licenceRequise}',
                      ),
                      onTap: () => context.go('/calendar/${e.id}'),
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
