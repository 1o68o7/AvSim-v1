# Cadrage — Point I : layout live rameur personnalisable

> Complète `docs/CARTE-LIVE-REPLAY.md` (carte réservée au coach) et `docs/CADRAGE-TELEMETRIE-TEL.md`.
> Objectif : le rameur choisit **quels blocs** afficher sur son écran live en mode paysage, y compris une mini-carte du plan d'eau.
> Date : 2026-09-20. Mis à jour : 2026-09-20 (point I.6 — provider tuiles gratuit + cache offline).

---

## 1. Constat

Aujourd'hui `/live` (rameur) affiche un layout fixe : gîte, V sol, distance, SPM, alertes. La carte OSM n'existe que sur `/coach` (lisible à 80 cm). Le rameur au cale-pied n'a pas de vue spatiale de sa trace.

Demande : permettre au rameur de **sélectionner les blocs** visibles, et d'ajouter une **mini-carte** (trace + position) quand le smartphone a du réseau (5G / Wi-Fi).

---

## 2. Décisions figées

1. **Layout = blocs empilables**, pas de grille libre. Le rameur choisit un *preset* ou compose 2–3 blocs max (lisibilité en mouvement).
2. **Sélecteur gros, en bord d'écran**, accessible au pouce sans lâcher la poignée. Pas de drag-and-drop pendant la séance.
3. **Mémoire par profil** : le choix est persisté (local d'abord, sync cloud au point B). Pas redemandé à chaque séance.
4. **Mini-carte optionnelle** : activable seulement si fix GPS OK *et* réseau disponible (tile cache). Sinon, le preset « carte » bascule automatiquement sur gîte + V sol.
5. **Performance** : la mini-carte utilise le **même provider de tiles que le coach** (voir §2.1 — OpenFreeMap Dark, 100% gratuit, sans clé). Tuiles mises en cache localement pour usage offline partiel.
6. **Pas de RTK, pas de 10 Hz** sur la mini-carte rameur — 1 Hz suffit pour la trace.
7. **Accessibilité** : le sélecteur a un mode « une main » (swipe vertical entre presets) + bouton tactile 48×48 min.
8. **Ne pas casser** le live coach, le `/cox`, la tare, ni le jsonl (les blocs masqués continuent de logger).

### 2.1 Provider de tuiles (décision I.6, figée 2026-09-20)

**Choix : OpenFreeMap (style Dark), 100% gratuit, sans clé API.**

| Critère | OpenFreeMap | Stadia Maps (Alidade Dark) | Carto Dark Matter (actuel) |
|---|---|---|---|
| Gratuit dès le départ | ✅ oui, illimité | ❌ free = non-commercial + dev seulement | ⚠️ clé gratuite requise, raster en retrait |
| Clé API | ❌ aucune | ✅ requise | ✅ requise |
| Usage commercial | ✅ autorisé | ❌ interdit sur free | ⚠️ à vérifier |
| Bulk download / cache offline | ✅ MBTiles hebdo + Btrfs | ❌ interdit (ToS) | ⚠️ partiel |
| Style dark | ✅ `dark` (fork dark-matter) | ✅ alidade_smooth_dark | ✅ dark_all |
| Licence | MIT | propriétaire | propriétaire |

**Pourquoi OpenFreeMap gagne :**
- Aucune clé, aucun compte, aucun cookie — zéro friction pour le coach non technique.
- Commercial use explicitement autorisé, pas de surprise à la monétisation.
- Bulk download autorisé : MBTiles planète hebdo (`https://btrfs.openfreemap.com/areas/planet/{version}/tiles.mbtiles`) + images Btrfs pour self-host.
- Style Dark disponible : `https://tiles.openfreemap.org/styles/dark` (fork du dark-matter-gl-style, non encore poli mais fonctionnel).
- Survit à 100k req/s (test Wplace.live, août 2025) — robuste.
- Pas de rate limit sur l'instance publique.

**Pourquoi pas Stadia :** free tier = non-commercial + dev/démo uniquement. Bulk download / proxying **interdit** par ToS → impossible de pré-télécharger le bassin. Commercial = payant dès 20 $/mois. Éliminé pour un produit club.

**Pourquoi pas Carto (actuel) :** raster en cours de retrait, clé API obligatoire, politique d'usage floue pour un produit commercial. Remplacement obligatoire avant prod.

**Attribution obligatoire** (affichée discrètement, coin bas-gauche, 10 px, #9AA0A6) :
`OpenFreeMap © OpenMapTiles · Data © OpenStreetMap`

**Fallback si OpenFreeMap down :** preset « Navigation » bascule sur gîte + V sol (déjà prévu §4). Pas de tuile de secours embarquée au MVP.

---

## 2.2 Cache offline (décision I.6, figée)

**Choix : `flutter_map_cache` (MIT) — pas FMTC (GPL).**

| | `flutter_map_tile_caching` (FMTC) | `flutter_map_cache` |
|---|---|---|
| Licence | **GPL-3.0** → force open-source de toute l'app | **MIT** ✅ |
| Bulk download région (cercle/polygone/corridor) | ✅ excellent | ⚠️ via MBTiles pré-généré |
| Browse cache auto | ✅ | ✅ |
| Maturité | 16k dl/sem, 130/160 | 21k dl/sem, 150/160 |
| Coût licence | payante si propriétaire | 0 € |

**Décision :** on part sur **`flutter_map_cache` (MIT)**. Raison : DataR0w n'est pas open-source (produit club, spinoscope, sync Supabase). GPL forcerait à ouvrir tout le code → inacceptable. FMTC vend des licences propriétaires mais on évite la dépendance juridique.

**Stratégie de cache concrète :**
1. **Pré-téléchargement bassin** : avant la séance (ou à la config du club), le coach/rameur télécharge les tuiles du plan d'eau en **MBTiles** via OpenFreeMap (fourni hebdo). Stocké dans `Documents/datar0w/tiles/{bassin}.mbtiles`.
2. **Runtime** : `flutter_map_cache` sert d'abord le MBTiles local, puis réseau si absent, avec TTL 7 jours (conforme politique OSM).
3. **Skip mer** : les tuiles océan ne sont pas téléchargées (MBTiles filtré ou skip à l'import).
4. **Plafond** : 200 Mo max par bassin. Au-delà, purge du zoom le plus fin d'abord.
5. **Chip sync** (point I, §buffer) : si le cache bassin est vieux de >7 jours, chip ambre « cartes à jour » → rappel de re-télécharger.

Alternative retenue si MBTiles trop lourd : bulk download runtime via `flutter_map_cache` + `dio_cache_interceptor` sur un cercle de 5 km autour du quai, rate-limité 50 tuiles/s pour ne pas spammer OpenFreeMap.

---

## 3. Blocs disponibles (catalogue)

| Bloc | Source | Poids écran | Remarque |
|---|---|---|---|
| `gite` | téléphone (roll lissé) | léger | défaut, toujours visible en preset « sécurité » |
| `vsol` | GNSS SOG | léger | |
| `distance` | intégrale trace | léger | |
| `spm` | capteurs / estimation | léger | « — » si instable |
| `hr` | capteur BLE (point cardio) | léger | masqué si pas de capteur pairé |
| `spo2` | capteur BLE | léger | labellisé approximatif |
| `map` | GNSS + tiles OpenFreeMap | **lourd** | tuiles cachées (MBTiles), fallback auto si offline |
| `alert` | heel_banner | overlay | ne se masque pas, prioritaire |

Un preset = combinaison ordonnée de 2–3 blocs + position (haut / centre / bas).

---

## 4. Presets proposés (MVP)

- **Sécurité** : `gite` + `alert` (défaut à la première séance).
- **Performance** : `vsol` + `distance` + `spm`.
- **Cardio** : `hr` + `spo2` + `gite` (apparaît si capteur pairé).
- **Navigation** : `map` + `vsol` + `distance` (bascule auto si pas de réseau).
- **Complet** : `gite` + `vsol` + `hr` (3 blocs, compact).

Le rameur peut aussi composer librement depuis le catalogue (max 3 blocs).

---

## 5. UX du sélecteur

- **Pendant la séance** : swipe vertical sur le bord droit (zone 60 px) → cycle les presets. Feedback haptique léger à chaque changement.
- **Hors séance / pause** : panneau « Personnaliser » (liste de presets + toggle blocs) accessible depuis le menu STOP ou le quai.
- **Indicateur** : petit point coloré en haut à droite = preset actif. Tape = ouvre le panneau.
- **Mini-carte** : pinch-to-zoom désactivé en live (sécurité). Zoom figé à l'échelle bassin. Nord en haut, aligné au coach.

---

## 6. Données & persistance

- `RowerLayout` (local JSON, sync cloud point B) :
  - `rowerId`, `preset` (enum), `blocks[]` (ordre + position),
  - `mapEnabled` (bool, défaut true si réseau),
  - `updatedAt`.
- Le layout ne change **pas** le jsonl : tous les blocs loggent, masqués ou non.
- Migration : les séances sans layout → preset « Sécurité ».
- `TileCache` (local) : `Documents/datar0w/tiles/{bassinId}.mbtiles` + metadata (version, downloadedAt, sizeBytes).

---

## 7. Lots (ordre de build)

- **I1** — Modèle `RowerLayout` + store local + preset « Sécurité » par défaut. Aucun changement visuel. Tests round-trip JSON.
- **I2** — Refactor `/live` : blocs rendus depuis une config (pas de layout hardcodé). Toggle runtime d'un bloc (preuve que le swap marche). Toujours 1 preset forcé pour valider.
- **I3** — Sélecteur swipe + panneau « Personnaliser » + persistance. 5 presets + composition libre (max 3). Mémoire par profil.
- **I4** — Mini-carte : intégration **OpenFreeMap Dark** (`https://tiles.openfreemap.org/styles/dark`) dans un bloc `map`, cache local via `flutter_map_cache` + MBTiles bassin, fallback auto si offline, alignement nord = coach. Attribution discrète.
- **I5** — Mode « une main » (swipe bord droit) + accessibilité (Semantics, zones 48×48) + tests widget layout.
- **I6** — (nouveau) Pré-téléchargement MBTiles bassin + UI « Mettre à jour les cartes » + chip sync si cache >7j. Peut être fusionné avec I4 si simple.

Chaque lot = 1 commit. `flutter analyze` clean. Ne pas toucher AvSim, compileSdk 37, NDK 30, ni le live coach.

---

## 8. Prompt Cursor (I1 → I6)

```
DataR0w — point I : layout live rameur personnalisable (lots I1→I6).
Lis d'abord docs/CADRAGE-LIVE-RAMEUR-LAYOUT.md et docs/CARTE-LIVE-REPLAY.md.
Ne pas toucher AvSim. Ne pas revert compileSdk 37 / ndkVersion "30.0.16248370".
Pas de sdkmanager. Pas de windows/. Pas d'Accueil sur /live /cox /coach.
Ne pas casser le live coach, /cox, la tare, ni le jsonl (blocs masqués continuent de logger).

## Règles (figées §2 + §2.1 + §2.2)
- Layout = blocs empilables, 2–3 max. Pas de grille libre.
- Sélecteur gros, bord d'écran, accessible au pouce.
- Mémoire par profil (local → sync point B).
- Mini-carte = OpenFreeMap Dark (PAS Carto, PAS Stadia) :
    urlTemplate / style : https://tiles.openfreemap.org/styles/dark
    AUCUNE clé API. Attribution discrète obligatoire.
- Cache offline : flutter_map_cache (MIT) + MBTiles bassin pré-téléchargé.
    PAS flutter_map_tile_caching (GPL — incompatible produit propriétaire).
- Fallback auto si offline : preset « Navigation » → gite + vsol.
- Chip « cartes à jour » si cache >7 jours.
- Ne pas porter le jargon Stitch.

## I1 — Modèle + store (aucun changement visuel)
lib/live/layout_model.dart : RowerLayout (rowerId, preset, blocks[], mapEnabled, updatedAt).
lib/live/layout_store.dart : CRUD local JSON (Documents/datar0w/layouts/).
Preset « Sécurité » par défaut si absent.
Tests : round-trip JSON, migration séance sans layout.
Commit : feat(datar0w): rower layout model + local store

## I2 — Refactor /live blocs depuis config
features/live/screen_3.dart : les blocs (gite, vsol, distance, spm) sont rendus
  depuis RowerLayout, plus de layout hardcodé.
Toggle runtime d'un bloc (preuve du swap) — 1 preset forcé pour valider.
Tous les blocs loggent dans le jsonl, masqués ou non.
Commit : feat(datar0w): live blocks driven by layout config

## I3 — Sélecteur + panneau Personnaliser
Swipe vertical bord droit (60 px) → cycle presets (feedback haptique).
Panneau « Personnaliser » : 5 presets + composition libre (max 3 blocs).
Persistance par profil. Indicateur preset actif (point coloré).
Commit : feat(datar0w): live layout selector + customize panel

## I4 — Mini-carte OpenFreeMap + cache
Bloc `map` : style OpenFreeMap Dark
  (https://tiles.openfreemap.org/styles/dark — vectoriel, pas de clé).
Cache : flutter_map_cache (MIT) + MBTiles bassin (Documents/datar0w/tiles/{bassin}.mbtiles).
  1 Hz, nord en haut, aligné au coach. Attribution discrète bas-gauche.
Fallback auto si offline : masquer map, afficher gite + vsol.
Pinch-to-zoom désactivé en live. Plafond 200 Mo/bassin.
Commit : feat(datar0w): live mini-map OpenFreeMap + offline cache

## I5 — Mode une main + accessibilité
Swipe bord droit = sélecteur principal (une main).
Zones tactiles 48×48 min, Semantics sur chaque bloc et preset.
Tests widget : layout swap, fallback offline, preset mémoire.
Commit : feat(datar0w): live layout one-hand mode + a11y

## I6 — Pré-téléchargement MBTiles + chip sync
UI « Mettre à jour les cartes du bassin » (depuis /club ou /quai).
Télécharge MBTiles OpenFreeMap (hebdo) → Documents/datar0w/tiles/.
Chip ambre « cartes à jour » si cache >7j (branche le point buffer sync).
Commit : feat(datar0w): basin tile predownload + stale cache chip

## Hors scope
Live coach, /cox, tare, RTK, 10 Hz, multi-carte, drag-and-drop libre,
modification du solver AvSim, FMTC (GPL), Stadia, Carto.

flutter analyze clean.
Un commit par lot I1…I6, dans cet ordre.
```

---

## 9. Hors scope (volontaire)

- Drag-and-drop libre de blocs (trop risqué en mouvement).
- Mini-carte en mode portrait (le live rameur est paysage).
- Couche GeoJSON bassin sur la mini-carte rameur (réservé coach).
- Modification des tiles / moteur de carte.
- Self-host OpenFreeMap (réservé si trafic > 100k req/j — pas au MVP).

---

## 10. Sources vérifiées (2026-09-20)

- OpenFreeMap : https://openfreemap.org/ — gratuit, no key, commercial OK, MBTiles hebdo, style Dark.
- OpenFreeMap styles : https://github.com/hyperknot/openfreemap-styles — `dark` = fork dark-matter-gl-style.
- MBTiles download : https://btrfs.openfreemap.com/areas/planet/{version}/tiles.mbtiles
- flutter_map_cache (MIT) : https://pub.dev/packages/flutter_map_cache
- flutter_map_tile_caching (GPL, écarté) : https://pub.dev/packages/flutter_map_tile_caching
- Stadia ToS (bulk download interdit) : https://stadiamaps.com/terms-of-service/
- Carto retrait raster : https://carto.com/blog/ (vérifier statut actuel avant prod)

---

*Document vivant — point I. À enrichir au fil des tests sur l'eau.*
