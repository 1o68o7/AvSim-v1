# Cadrage — Point C : parc opérationnel (sortie, alignement, pelles, multi-coach)

> Statut : **à construire**. Pas de débat — on code dans l'ordre ci-dessous.
> App : `apps/datar0w`. Ne pas toucher AvSim. Ne pas revert `compileSdk = 37` / `ndkVersion "30.0.16248370"`. Pas de `sdkmanager`. Pas de `windows/`.
> Prérequis : I1–I5 mergés (identité locale), Point B (Supabase) prévu en C6.
> Chaque lot = 1 commit, `flutter analyze` clean, tests, APK qui s'installe.

---

## 0. Pourquoi ce chantier

Aujourd'hui DataR0w gère l'**inventaire** du parc (coques, statut, pelles en rack) et la **composition** d'un équipage (sièges, côté, pelles du poste). Mais le club ne fait pas que « ranger des bateaux » : il **sort** des coques, les **aligne**, les **équipe**, les **fait partir**, puis les **rentre**.

Le trou réel :

- Pas de **sortie de parc** : qui sort quelle coque, à quelle heure, pour quelle séance.
- Pas de **check-out / check-in** : bateau « sorti » vs « au hangar ».
- Pas de **jeu de pelles dédié** : attribution fine P1/P2/P4 par poste, pas juste une liste rack.
- Pas de **verrou multi-coach** : deux coachs peuvent composer le même bateau en même temps.
- Pas de **filtre loisir / compétiteur** sur l'accès aux coques.
- Pas d'écran **« départ »** : embarquement, alignement, qui part avec quoi.
- Pas de **signalement d'impact** : photo + note → maintenance.

C'est le chantier **parc opérationnel**, pas juste « parc inventaire ». Sans lui, dès qu'il y a 2 coachs sur un même parc, ça se casse.

---

## 1. Ce qui existe déjà (I1–I5, sur `main`)

| Élément | État |
|---|---|
| `Boat` : nom, classe, cox, `oarRack` (inventaire), statut ready/maint/out | ✅ I3 |
| `Assignment` : siège, rameur, côté, pelles du poste, barreur avant/arrière | ✅ I4 |
| Écran `/crew` : composition coach, READY only, rameur déjà affecté grisé | ✅ I4 |
| Restriction loisir : pas de catalogue, un seul bateau attribué | ✅ I5 |
| Chip quai « siège n / côté / pelles » si Assignment | ✅ I5 |
| **Sortie de parc / check-out / check-in** | ❌ |
| **Jeu de pelles dédié (sortie)** | ❌ |
| **Verrou multi-coach** | ❌ |
| **Écran départ / alignement** | ❌ |
| **Filtre loisir/compétiteur sur coques** | ❌ |
| **Photo d'impact → maintenance** | ❌ |

---

## 2. Fonctionnalités (ordre de build)

### 2.1 Cycle de vie d'une coque

1. **Sortie de parc (check-out)** — le coach déclare « on sort l'Empacher pour la séance 14h ». La coque passe `ready → out`. Horodaté, par qui.
2. **Retour de parc (check-in)** — fin de séance ou manuellement. `out → ready` (ou `maintenance` si signalé). Horodaté.
3. **Statut enrichi** — `ready | out | maintenance | reserved` (reserved = sorti mais pas encore parti).
4. **Verrou d'édition** — une coque `out` ne peut pas être ré-composée par un autre coach tant qu'elle n'est pas revenue.
5. **File d'attente** — si 2 coachs veulent la même coque, le 2ᵉ voit « réservée par Coach X jusqu'à 15h30 ». Pas de refus sec.

### 2.2 Pelles

6. **Jeu de pelles de sortie** — à la sortie, on choisit *quelles* pelles sortent avec la coque (sous-ensemble du rack). Pas juste « le rack a P1/P2/P4 », mais « on emmène P1×2, P2×2, P4×1 ». **Critique en compétition** : le jeu est figé pour la course.
7. **Attribution poste → pelle** — déjà dans `Assignment.oars`, mais à **figer à la sortie** (pas modifiable après embarquement sans trace).
8. **Retour des pelles** — check-in vérifie que les pelles sont revenues (ou signale manquant). Simple booléen « pelles OK » au MVP.
9. **Usure / maintenance pelles** — plus tard. Hors MVP.
10. **Pelles personnelles** — un rameur amène ses propres pelles. Champ `oarSource: club | personal`. Utile loisir.

### 2.3 Départ & alignement

11. **Écran « départ »** — avant embarquement : liste coques sorties + équipages + pelles. Vue coach, lecture. Pas de télémétrie.
12. **Alignement** — ordre d'embarquement par classe (8+ d'abord, 1x en dernier) ou par quai. Simple file d'attente visuelle.
13. **Heure de départ planifiée** — champ optionnel sur la sortie. Utile pour enchaîner 2 sessions.
14. **Retour automatique** — à la fin de séance (STOP 2× → quai), proposer « rentrer la coque ? ». Opt-in.

### 2.4 Multi-coach & permissions

15. **Rôle `coach` vs `admin`** — admin gère le parc (CRUD coques), coach compose et sort. Déjà esquissé en Point B (`club_members.role`), à figer ici.
16. **Visibilité croisée** — coach A voit les sorties de coach B (même club), en lecture. Pas de silo.
17. **Transfert de sortie** — coach A sort, coach B reprend (ex. relève). Trace qui a transféré.
18. **Notification** — « ta coque est sortie » au rameur affecté. Via Realtime (Point B) ou locale.

### 2.5 Filtre loisir / compétiteur

19. **Tag coque `loisir_ok`** — une coque peut être réservée compétiteurs seulement, ou ouverte aux loisirs. Décision coach à la création.
20. **Règle d'attribution** — loisir ne peut recevoir qu'une coque `loisir_ok`. Compétiteur : toutes (sauf maintenance).
21. **Quota loisir** — plus tard. Hors MVP.

### 2.6 Signalement d'impact → maintenance

22. **Photo d'impact** — à la sortie ou au retour, le coach (ou le barreur) peut attacher **une photo** d'un choc / rayure / fissure sur la coque. La coque bascule automatiquement en `maintenance` jusqu'à validation.
23. **Signalement texte** — champ libre court « ce qui s'est passé » lié à la photo.
24. **File maintenance** — liste des coques signalées, avec photo + note, statut `maintenance` jusqu'à réparation. Le coach ne peut pas re-sortir une coque en maintenance sans lever le flag.
25. **Visibilité rameur** — le rameur voit « ta coque est en maintenance » s'il était affecté, sans détail photo si sensible.

> Note : pas de caméra live ni flux continu. **Une photo à la demande**, prise au moment du signalement. Hors scope : inspection IA, géoloc du hangar.

### 2.7 Hors scope assumé

- Planification multi-jours / calendrier de séances.
- Réservation à l'avance (J-1) — on reste « sortie du moment ».
- Suivi d'usure pelles / coques (compteurs de sorties).
- GPS de localisation du hangar.
- Facturation / abonnements loisir.
- Télémétrie par siège (Lot G).
- Inspection IA des dommages.

---

## 3. Règles figées (pas de débat)

| # | Règle |
|---|---|
| D1 | Sortie = action **explicite**. Composition ≠ sortie. On compose d'abord, on sort ensuite. |
| D2 | Verrou multi-coach = **file d'attente**, pas refus sec. |
| D3 | Check-in : **proposer** à la fin de séance (opt-in). |
| D4 | Pelles : **jeu de sortie** dédié (sous-ensemble du rack), figé à la sortie. |
| D5 | Filtre loisir/compétiteur : tag `loisir_ok` sur `Boat`. |
| D6 | Coach peut sortir ; admin gère le parc (CRUD). |
| D7 | Photo d'impact : **opt-in**, pas bloquante. |
| D8 | Photos : **local d'abord**, sync cloud au Point B. |
| D9 | Scope MVP = C1–C6. |

---

## 4. Lots (ordre de build)

**C1 — Modèle sortie + verrou + jeu de pelles + impact, AUCUN écran**
- `lib/ops/boat_out.dart` : `BoatOut` (boatId, coachId, startedAt, plannedEnd, status, oarSetId).
- `lib/ops/oar_set.dart` : `OarSet` (boatId, items[{spec, qty}], checkedOutAt) — sous-ensemble du rack.
- `lib/ops/impact_report.dart` : `ImpactReport` (boatId, photoPath, note, reportedBy, reportedAt, status).
- Store local + tests : sortie/retour, verrou, file d'attente, pelles manquantes, report impact → maintenance.
- Commit : `feat(datar0w): boat checkout model + oar sets + impact reports`

**C2 — Écran sortie / retour (coach)**
- `/ops/out` : liste coques `ready` → CTA « Sortir » (choisit jeu de pelles, heure prévue, option photo impact).
- `/ops/in` : coques `out` → CTA « Rentrer » (vérifie pelles, signale manquant).
- Verrou : coque `out` grisée à la composition.
- Commit : `feat(datar0w): boat checkout/in screens`

**C3 — Écran départ / alignement**
- `/ops/departure` : vue coach, coques sorties + équipages + pelles, ordre d'embarquement.
- Proposition auto « rentrer la coque ? » à la fin de séance.
- Commit : `feat(datar0w): departure board + auto check-in prompt`

**C4 — Filtre loisir / compétiteur + rôles**
- Tag `loisir_ok` sur `Boat`. Règle d'attribution à la composition.
- Rôles `coach` vs `admin` (réutilise Point B `club_members.role`).
- Commit : `feat(datar0w): boat access rules loisir/competiteur`

**C5 — Signalement d'impact (photo + maintenance)**
- Depuis `/ops/out` ou `/ops/in` : CTA « Signaler un impact » → photo (caméra) + note courte.
- Coque → `maintenance`, file visible coach/admin.
- Rameur affecté : notification « coque en maintenance ».
- Commit : `feat(datar0w): impact photo + maintenance queue`

**C6 — Sync Supabase (branche Point B)**
- Tables `boat_outs`, `oar_sets`, `impact_reports`. RLS par club. Realtime sur `boat_outs`.
- Photos : upload Storage au sync (local d'abord).
- Commit : `feat(datar0w): boat ops sync`

Hors scope C1–C6 : usure pelles (compteurs), calendrier multi-jours, réservation J-1, GPS hangar, inspection IA.

---

## 5. Prompt Cursor — Lots C1 → C6 (à coller tel quel)

```
DataR0w — Point C : parc opérationnel (sortie, alignement, pelles, multi-coach, impact).
Lis d'abord docs/CADRAGE-PARC-OPERATIONNEL.md et docs/CADRAGE-IDENTITE-CLUB-EQUIPAGE.md.

Ne pas toucher AvSim. Ne pas revert compileSdk 37 / ndkVersion "30.0.16248370".
Pas de sdkmanager. Pas de windows/. Pas d'Accueil sur /live /cox /coach (sortie = STOP 2×).
Ne pas porter le jargon Stitch (SYS_ID, STAGE PROTOCOL, SENSOR SYNC, entraxe, calage).

DA : #0B0E12 / blanc / #9AA0A6 / #2A2F36 / CTA #E8C547 / TRIBORD #46C275 / BÂBORD #E05353.

## Règles métier (figées)
- Sortie = action EXPLICITE (composition ≠ sortie).
- Verrou multi-coach = FILE D'ATTENTE, pas refus sec.
- Check-in : PROPOSER à la fin de séance (opt-in).
- Pelles : JEU DE SORTIE dédié (sous-ensemble du rack), figé à la sortie.
- Filtre loisir/compétiteur : tag loisir_ok sur Boat.
- Coach peut sortir ; admin gère le parc (CRUD).
- Photo d'impact : OPT-IN à la sortie/retour, pas bloquante.
- Photos : LOCAL d'abord, sync cloud au Point B.
- Scope MVP = C1–C6.

## C1 — modèle sortie + verrou + jeu de pelles + impact, AUCUN écran
lib/ops/boat_out.dart : BoatOut (boatId, coachId, startedAt, plannedEnd, status, oarSetId)
lib/ops/oar_set.dart : OarSet (boatId, items[{spec, qty}], checkedOutAt) — sous-ensemble du rack
lib/ops/impact_report.dart : ImpactReport (boatId, photoPath, note, reportedBy, reportedAt, status)
lib/ops/store.dart : CRUD local (JSON Documents/datar0w/ops/)
Règles : coque out → non ré-assignable ; file d'attente si 2 coachs veulent la même ;
         report impact → coque maintenance, non re-sortable sans lever le flag.
Tests : sortie/retour, verrou, file, pelles manquantes, report impact → maintenance.
Commit : feat(datar0w): boat checkout model + oar sets + impact reports

## C2 — écran sortie / retour (coach)
/ops/out  : liste coques ready → CTA « Sortir » (jeu de pelles, heure prévue, option photo impact).
/ops/in   : coques out → CTA « Rentrer » (vérifie pelles, signale manquant).
Verrou : coque out grisée à /crew.
Commit : feat(datar0w): boat checkout/in screens

## C3 — écran départ / alignement
/ops/departure : vue coach, coques sorties + équipages + pelles, ordre embarquement.
Proposition auto « rentrer la coque ? » à la fin de séance (opt-in).
Commit : feat(datar0w): departure board + auto check-in prompt

## C4 — filtre loisir/compétiteur + rôles
Tag loisir_ok sur Boat. Règle d'attribution à la composition.
Rôles coach vs admin (réutilise Point B club_members.role).
Commit : feat(datar0w): boat access rules loisir/competiteur

## C5 — signalement d'impact (photo + maintenance)
Depuis /ops/out ou /ops/in : CTA « Signaler un impact » → photo (caméra) + note courte.
Coque → maintenance, file visible coach/admin.
Rameur affecté : notification « coque en maintenance ».
Commit : feat(datar0w): impact photo + maintenance queue

## C6 — sync Supabase (branche Point B)
Tables boat_outs, oar_sets, impact_reports. RLS par club. Realtime sur boat_outs.
Photos : upload Storage au sync (local d'abord).
Commit : feat(datar0w): boat ops sync

## Hors scope
Usure pelles (compteurs), calendrier multi-jours, réservation J-1, GPS hangar,
inspection IA, télémétrie par siège.
Ne pas redessiner /live /cox /tare /coach carte /replay /crew /club.

flutter analyze clean. Tests ops verts.
Un commit par lot C1…C6, dans cet ordre.
```

---

## 6. Prochaine action

Lancer **C1** directement dans Cursor (modèle, pas d'écran), comme I1.

*Document vivant — ordre de build figé. À enrichir au fil des lots.*
