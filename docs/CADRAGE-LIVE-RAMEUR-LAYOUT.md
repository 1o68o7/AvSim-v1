# Cadrage — Point I : layout live rameur personnalisable

> Complète `docs/CARTE-LIVE-REPLAY.md` (carte réservée au coach) et `docs/CADRAGE-TELEMETRIE-TEL.md`.
> Objectif : le rameur choisit **quels blocs** afficher sur son écran live en mode paysage, y compris une mini-carte du plan d'eau.
> Date : 2026-09-20.

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
5. **Performance** : la mini-carte utilise le même provider de tiles que le coach (Carto Dark Matter, sans clé). Pas de second moteur de carte. Tuiles mises en cache localement pour usage offline partiel.
6. **Pas de RTK, pas de 10 Hz** sur la mini-carte rameur — 1 Hz suffit pour la trace.
7. **Accessibilité** : le sélecteur a un mode « une main » (swipe vertical entre presets) + bouton tactile 48×48 min.
8. **Ne pas casser** le live coach, le `/cox`, la tare, ni le jsonl (les blocs masqués continuent de logger).

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
| `map` | GNSS + tiles Carto | **lourd** | tuiles cachées, fallback auto si offline |
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

---

## 7. Lots (ordre de build)

- **I1** — Modèle `RowerLayout` + store local + preset « Sécurité » par défaut. Aucun changement visuel. Tests round-trip JSON.
- **I2** — Refactor `/live` : blocs rendus depuis une config (pas de layout hardcodé). Toggle runtime d'un bloc (preuve que le swap marche). Toujours 1 preset forcé pour valider.
- **I3** — Sélecteur swipe + panneau « Personnaliser » + persistance. 5 presets + composition libre (max 3). Mémoire par profil.
- **I4** — Mini-carte : intégration tiles Carto dans un bloc `map`, cache local, fallback auto si offline, alignement nord = coach.
- **I5** — Mode « une main » (swipe bord droit) + accessibilité (Semantics, zones 48×48) + tests widget layout.

Chaque lot = 1 commit. `flutter analyze` clean. Ne pas toucher AvSim, compileSdk 37, NDK 30, ni le live coach.

---

## 8. Prompt Cursor (I1 → I5)

```
DataR0w — point I : layout live rameur personnalisable (lots I1→I5).
Lis d'abord docs/CADRAGE-LIVE-RAMEUR-LAYOUT.md et docs/CARTE-LIVE-REPLAY.md.
Ne pas toucher AvSim. Ne pas revert compileSdk 37 / ndkVersion "30.0.16248370".
Pas de sdkmanager. Pas de windows/. Pas d'Accueil sur /live /cox /coach.
Ne pas casser le live coach, /cox, la tare, ni le jsonl (blocs masqués continuent de logger).

## Règles (figées §2)
- Layout = blocs empilables, 2–3 max. Pas de grille libre.
- Sélecteur gros, bord d'écran, accessible au pouce.
- Mémoire par profil (local → sync point B).
- Mini-carte optionnelle, 1 Hz, tiles Carto (même provider que coach), cache local.
- Fallback auto si pas de réseau : preset « Navigation » → gite + vsol.
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

## I4 — Mini-carte
Bloc `map` : tiles Carto Dark Matter (même urlTemplate que /coach),
  cache local, 1 Hz, nord en haut, aligné au coach.
Fallback auto si offline : masquer map, afficher gite + vsol.
Pinch-to-zoom désactivé en live.
Commit : feat(datar0w): live mini-map block with tile cache

## I5 — Mode une main + accessibilité
Swipe bord droit = sélecteur principal (une main).
Zones tactiles 48×48 min, Semantics sur chaque bloc et preset.
Tests widget : layout swap, fallback offline, preset mémoire.
Commit : feat(datar0w): live layout one-hand mode + a11y

## Hors scope
Live coach, /cox, tare, RTK, 10 Hz, multi-carte, drag-and-drop libre,
modification du solver AvSim.

flutter analyze clean.
Un commit par lot I1…I5, dans cet ordre.
```

---

## 9. Hors scope (volontaire)

- Drag-and-drop libre de blocs (trop risqué en mouvement).
- Mini-carte en mode portrait (le live rameur est paysage).
- Couche GeoJSON bassin sur la mini-carte rameur (réservé coach).
- Modification des tiles / moteur de carte.

---

*Document vivant — point I. À enrichir au fil des tests sur l'eau.*
