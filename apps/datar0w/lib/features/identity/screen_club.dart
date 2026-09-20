import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../../identity/controller.dart';
import '../../identity/models.dart';
import '../../router.dart';
import '../../session/boat_config.dart';
import '../../theme/deck_theme.dart';
import '../../maps/deck_tiles.dart';
import '../../widgets/club_banner.dart';
import '../../widgets/deck_scaffold.dart';

String boatStatusLabel(BoatParkStatus s) => switch (s) {
      BoatParkStatus.ready => 'prêt',
      BoatParkStatus.reserved => 'réservée',
      BoatParkStatus.maintenance => 'maintenance',
      BoatParkStatus.out => 'hors d’eau',
    };

class ClubScreen extends ConsumerStatefulWidget {
  const ClubScreen({super.key});

  @override
  ConsumerState<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends ConsumerState<ClubScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _full = TextEditingController();
  final _slogan = TextEditingController();
  final _year = TextEditingController();
  final _primary = TextEditingController();
  final _secondary = TextEditingController();
  final _city = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  final _licences = TextEditingController();
  bool _hydrated = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _full.dispose();
    _slogan.dispose();
    _year.dispose();
    _primary.dispose();
    _secondary.dispose();
    _city.dispose();
    _lat.dispose();
    _lon.dispose();
    _licences.dispose();
    super.dispose();
  }

  void _hydrate(IdentitySnapshot snap) {
    if (_hydrated) return;
    final c = snap.activeClub;
    if (c != null) {
      _name.text = c.name;
      _code.text = c.shortCode ?? '';
      _full.text = c.fullName ?? '';
      _slogan.text = c.slogan ?? '';
      _year.text = c.foundedYear?.toString() ?? '';
      _primary.text = hexColor(c.primaryColor);
      _secondary.text = hexColor(c.secondaryColor);
      _city.text = c.city ?? '';
      _lat.text = c.lat?.toString() ?? '';
      _lon.text = c.lon?.toString() ?? '';
      _licences.text = c.licenceCountApprox?.toString() ?? '';
    }
    _hydrated = true;
  }

  Future<void> _saveClub() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final existing = ref.read(identityProvider).activeClub;
    final club = (existing == null
            ? Club.create(
                name: name,
                shortCode: _code.text.trim().isEmpty ? null : _code.text.trim(),
              )
            : existing.copyWith(
                name: name,
                shortCode: _code.text.trim(),
                clearCode: _code.text.trim().isEmpty,
              ))
        .copyWith(
      fullName: _full.text.trim(),
      clearFullName: _full.text.trim().isEmpty,
      slogan: _slogan.text.trim(),
      clearSlogan: _slogan.text.trim().isEmpty,
      foundedYear: int.tryParse(_year.text.trim()),
      clearFounded: _year.text.trim().isEmpty,
      primaryColor: parseHexColor(_primary.text),
      secondaryColor: parseHexColor(_secondary.text),
      city: _city.text.trim().isEmpty ? null : _city.text.trim(),
      lat: double.tryParse(_lat.text.trim().replaceAll(',', '.')),
      lon: double.tryParse(_lon.text.trim().replaceAll(',', '.')),
      licenceCountApprox: int.tryParse(_licences.text.trim()),
      clearLicenceCount: _licences.text.trim().isEmpty,
    );
    await ref.read(identityProvider.notifier).saveClub(club);
  }

  Future<void> _pickCrest() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final existing = ref.read(identityProvider).activeClub;
    if (existing == null) return;
    final docs = await getApplicationDocumentsDirectory();
    final dest = File('${docs.path}/datar0w/crest/${existing.id}.jpg');
    await dest.parent.create(recursive: true);
    await File(x.path).copy(dest.path);
    await ref.read(identityProvider.notifier).saveClub(
          existing.copyWith(crestPath: dest.path),
        );
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(identityProvider);
    final role = ref.watch(boatConfigProvider).role;
    final edit = canEditPark(snap, role);
    _hydrate(snap);
    final boats = snap.boatsForClub(snap.activeClub?.id);

    return DeckScaffold(
      title: 'CLUB',
      subtitle: 'Un téléphone · un club',
      leading: TextButton(
        onPressed: () => context.go(AppRoutes.profile),
        child: const Text('Retour'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (snap.activeClub != null) ...[
            ClubBanner(club: snap.activeClub!),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _name,
            enabled: edit,
            decoration: const InputDecoration(labelText: 'Nom du club'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _code,
            enabled: edit,
            decoration: const InputDecoration(labelText: 'Code court (3–4 car.)'),
          ),
          if (edit) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _full,
              decoration: const InputDecoration(labelText: 'Nom complet'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _slogan,
              decoration: const InputDecoration(labelText: 'Slogan'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _year,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Année de fondation'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _primary,
              decoration: const InputDecoration(labelText: 'Couleur 1 (#RRGGBB)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _secondary,
              decoration: const InputDecoration(labelText: 'Couleur 2 (#RRGGBB)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'Ville'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _lat,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Latitude'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _lon,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Longitude'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _licences,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Licenciés (approx.)',
                helperText: 'Estimation club, pas FFA. Pas de PII rameurs.',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _pickCrest,
              child: const Text('BLASON (PHOTO)'),
            ),
          ],
          if (role == CrewRole.coach) ...[
            const SizedBox(height: 12),
            const Text(
              'RÔLE CLUB',
              style: TextStyle(
                color: DeckColors.label,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final r in [ClubMemberRole.coach, ClubMemberRole.admin])
                  ChoiceChip(
                    label: Text(r.wire),
                    selected: snap.prefs.clubRole == r,
                    onSelected: (_) =>
                        ref.read(identityProvider.notifier).setClubRole(r),
                  ),
              ],
            ),
          ],
          if (edit) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saveClub,
              child: const Text('ENREGISTRER LE CLUB'),
            ),
          ],
          if (snap.activeClub?.lat != null && snap.activeClub?.lon != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(
                    snap.activeClub!.lat!,
                    snap.activeClub!.lon!,
                  ),
                  initialZoom: 12,
                ),
                children: [
                  DeckMapTiles.layer(),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(
                          snap.activeClub!.lat!,
                          snap.activeClub!.lon!,
                        ),
                        width: 28,
                        height: 28,
                        child: const Icon(Icons.place, color: DeckColors.amber),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Text(
              DeckMapTiles.attribution,
              style: TextStyle(color: DeckColors.muted, fontSize: 10),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.calendar),
            child: const Text('CALENDRIER'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.waters),
            child: const Text('PLANS D’EAU'),
          ),
          const SizedBox(height: 24),
          Text(
            'PARC À BATEAUX',
            style: const TextStyle(
              color: DeckColors.label,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          if (boats.isEmpty)
            const Text(
              'Aucune coque. Le coach ajoute le parc.',
              style: TextStyle(color: DeckColors.muted),
            ),
          for (final b in boats)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(b.name),
              subtitle: Text(
                '${b.classe} · ${b.seats} sièges'
                '${b.cox ? ' · barreur' : ''} · ${boatStatusLabel(b.status)}',
              ),
              onTap: edit
                  ? () => context.go('${AppRoutes.clubBoat}?id=${b.id}')
                  : null,
              trailing: edit
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
                          .read(identityProvider.notifier)
                          .deleteBoat(b.id),
                    )
                  : null,
            ),
          if (edit && snap.activeClub != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.clubBoat),
              child: const Text('+ Ajouter'),
            ),
          ],
          if (canCheckoutOps(snap, role) && snap.activeClub != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.clubImport),
              child: const Text('IMPORTER UN FICHIER'),
            ),
          ],
        ],
      ),
    );
  }
}
