import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../identity/controller.dart';
import '../identity/models.dart';
import '../onboarding/routing.dart';
import '../router.dart';
import '../session/boat_config.dart';
import '../theme/deck_theme.dart';

/// Onglets shell Stitch redesign : Aujourd'hui · Séances · Plus.
enum DeckTab { today, sessions, plus }

/// Scaffold avec bottom nav 64 px (DA Technical Nautical Deck).
/// Pas de nav sur live / tare / cox (mode eau).
class DeckTabScaffold extends ConsumerWidget {
  const DeckTabScaffold({
    super.key,
    required this.tab,
    required this.body,
    this.floatingActionButton,
  });

  final DeckTab tab;
  final Widget body;
  final Widget? floatingActionButton;

  String _todayRoute(WidgetRef ref) {
    final snap = ref.read(identityProvider);
    final session = ref.read(boatConfigProvider).role;
    // Hub « Aujourd'hui » selon rôle club, sinon rôle séance.
    if (snap.prefs.clubRole == ClubMemberRole.coach ||
        session == CrewRole.coach) {
      return AppRoutes.homeCoach;
    }
    if (snap.prefs.clubRole == ClubMemberRole.admin ||
        snap.prefs.clubRole == ClubMemberRole.intendant ||
        snap.prefs.clubRole == ClubMemberRole.director ||
        snap.prefs.clubRole == ClubMemberRole.treasurer) {
      return homeRouteForClubMemberRole(snap.prefs.clubRole);
    }
    if (session == CrewRole.cox) return AppRoutes.homeCox;
    return AppRoutes.homeRower;
  }

  void _go(BuildContext context, WidgetRef ref, DeckTab t) {
    switch (t) {
      case DeckTab.today:
        context.go(_todayRoute(ref));
      case DeckTab.sessions:
        context.go(AppRoutes.sessions);
      case DeckTab.plus:
        context.go(AppRoutes.plus);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: DeckColors.bg,
      floatingActionButton: floatingActionButton,
      body: body,
      bottomNavigationBar: _DeckBottomNav(
        active: tab,
        onSelect: (t) => _go(context, ref, t),
      ),
    );
  }
}

class _DeckBottomNav extends StatelessWidget {
  const _DeckBottomNav({required this.active, required this.onSelect});

  final DeckTab active;
  final ValueChanged<DeckTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DeckColors.bgTactical,
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: DeckColors.hairline)),
          ),
          child: Row(
            children: [
              _Tab(
                label: "Aujourd'hui",
                icon: Icons.explore_outlined,
                selected: active == DeckTab.today,
                onTap: () => onSelect(DeckTab.today),
              ),
              _Tab(
                label: 'Séances',
                icon: Icons.timer_outlined,
                selected: active == DeckTab.sessions,
                onTap: () => onSelect(DeckTab.sessions),
              ),
              _Tab(
                label: 'Plus',
                icon: Icons.grid_view_rounded,
                selected: active == DeckTab.plus,
                onTap: () => onSelect(DeckTab.plus),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? DeckColors.volt : DeckColors.label;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (selected)
              const Positioned(
                top: 0,
                left: 24,
                right: 24,
                child: ColoredBox(
                  color: DeckColors.volt,
                  child: SizedBox(height: 2),
                ),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: DeckType.ui,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
