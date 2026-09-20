# Point E — Calendrier FFA, plans d'eau, localisation club

> **Statut** : cadrage fonctionnel. Pas de code. Pas de Stitch. Pas de lancement.
> **Prérequis** : Points A–D (identité, parc, import cabane, parc opérationnel) gelés en doc.
> **Public cible** : rameurs compétiteurs + coachs. Les loisirs voient le calendrier en lecture, sans inscription.

---

## 0. Constat (vérifié 20 sept 2026)

### La FFA publie bien un calendrier annuel

- Page publique : https://www.ffaviron.fr/suivre-les-competitions/tous-les-evenements-ffa/
  - Liste statique d'événements : nom, dates, adresse complète, club organisateur, type (Compétitions / Randonnées), discipline (Rivière / Mer / Banc fixe), lien « En savoir plus ».
  - Pas d'API JSON, pas d'iCal, pas de flux structuré. Scraping HTML possible mais fragile.
- Calendrier national 2026 (Note d'info n°396, mai 2025) : 8 manifestations nationales rivière + mer + indoor, avec dates et organisateurs (Mâcon, Cazaubon, Mantes, Pont-à-Mousson, Bourges, Libourne, Vichy, La Seyne).
- Réglementation sportive 2026 (PDF, ~50 pages) : calendrier détaillé + inscriptions + ordre des départs, publié sur ffaviron.fr/reglementation-des-competitions/reglementation-sportive/.
- Pas de source machine-readable officielle. Donc : **catalogue curaté en local + sync optionnelle**, pas de dépendance live à la FFA.

### Ce que DataR0w a déjà

- `Club` : nom + code court. **Pas** d'adresse, pas de coordonnées, pas de blason (Point D3 prévu : blason + couleurs + slogan).
- `ParkBoat` : nom, classe, cox, pelles, statut. Pas de bassin d'entraînement rattaché.
- Pas d'écran calendrier, pas de carte, pas de plans d'eau.

---

## 1. Trois briques à ajouter

### 1.1 Localisation du club (géocode)

Sur la fiche club (Point D3) :
- Adresse postale (rue, CP, ville).
- Coordonnées GPS (lat/lon) — saisie manuelle OU géocodage via adresse (Nominatim / OpenStreetMap, gratuit, sans clé).
- Carte embarquée (flutter_map + tuiles OSM) : pin du club + bassin d'entraînement si différent.
- Rayon d'action : compétitions accessibles ≤ X km (filtre du calendrier).

### 1.2 Plans d'eau (bassins d'entraînement + sites de compétition)

Entité `WaterBody` :
- id, nom, type (bassin d'entraînement / site de compétition / rivière / mer),
- adresse + lat/lon,
- longueur de piste (m) si connue,
- club propriétaire (optionnel),
- notes (accès, stationnement, conditions).
- Rattaché au club (bassin d'entraînement) ou à un événement (site de compétition).

### 1.3 Calendrier compétitions (catalogue FFA + club)

Entité `Competition` :
- id, nom, dates (début/fin), lieu (WaterBody ou adresse libre),
- type : Championnat de France / Championnat national / Régionale / Coupe / Rando / Club,
- discipline : rivière / mer / indoor / banc fixe,
- catégories éligibles (texte libre ou tags),
- source : `ffa` (curaté) | `club` (saisi) | `custom`,
- url source (lien FFA),
- statut : à venir / en cours / terminé.

Deux flux :
- **Catalogue FFA** : JSON curaté maintenu dans le repo (`assets/ffa_calendar_2026.json`), mis à jour chaque saison. Pas de scraping live.
- **Événements club** : saisie manuelle par le coach (régates locales, interclubs).

---

## 2. Écrans (DA Deck, portrait 390×844)

### E1 — Carte club (fiche club enrichie)
- Pin club + bassin d'entraînement sur carte OSM.
- Adresse éditable, géocode auto.
- Compteur : « 3 compétitions à ≤ 150 km cette saison ».
- CTA : « Voir le calendrier ».

### E2 — Calendrier compétitions
- Liste chronologique, groupée par mois.
- Filtres : type (CF / national / régional / club), discipline, distance du club (≤ 50 / 150 / 300 km / tous).
- Chaque ligne : date, nom, lieu, distance km, type chip.
- Tap → E3.
- Toggle « Mes compétitions » (celles où le club est engagé — plus tard, Point B).

### E3 — Fiche compétition
- Nom, dates, lieu (adresse + mini-carte),
- type / discipline / catégories,
- distance depuis le club,
- lien « Ouvrir sur la carte » (navigation externe),
- source FFA (lien) ou « événement club ».
- CTA : « Ajouter à mon calendrier » (génère .ics local, pas de sync cloud).

### E4 — Plans d'eau (liste + fiche)
- Liste des bassins rattachés au club + sites de compétition visités.
- Fiche : nom, type, adresse, carte, longueur piste, notes d'accès.
- Coach : CRUD. Rameur : lecture.

---

## 3. Données FFA — stratégie

**Pas d'API live.** Trois options, par ordre de préférence :

1. **Catalogue curaté** (recommandé MVP) : `assets/ffa_calendar_2026.json` — ~30–50 événements nationaux + régionaux majeurs, maintenu à la main chaque saison (1 h de travail). Fiable, hors-ligne, légal.
2. **Scraping** de la page FFA : fragile (HTML change), à éviter.
3. **Saisie club** : le coach ajoute ses régates locales. Combiné avec (1) = couverture complète.

Règle : toute entrée `source: ffa` affiche « Source : FFA — calendrier indicatif, vérifier sur ffaviron.fr ». Pas de reproduction intégrale des PDF fédéraux.

---

## 4. Lots (ordre de build)

| Lot | Contenu | Écrans |
|-----|---------|--------|
| **E1** | Modèle `WaterBody` + `Competition` + store local + seed `ffa_calendar_2026.json` (10 événements) + tests | aucun |
| **E2** | Localisation club : adresse + géocode + pin carte sur fiche club (Point D3) | E1 |
| **E3** | Écran calendrier + fiche compétition + filtres distance | E2, E3 |
| **E4** | Plans d'eau : liste + fiche + rattachement club/événement | E4 |
| **E5** | Export .ics + « mes compétitions » (local) | — |

Chaque lot = 1 commit. `flutter analyze clean` entre chaque.

---

## 5. Prompt Cursor (à coller tel quel)

```
DataR0w — Point E : calendrier FFA + plans d'eau + localisation club.
Lis docs/CADRAGE-CALENDRIER-FFA-PLANS-D-EAU.md en entier avant de coder.
Lis aussi docs/CADRAGE-IDENTITE-CLUB-EQUIPAGE.md et docs/CADRAGE-IMPORT-CABANE.md (Point D3 blason/couleurs déjà prévus).

Ne pas toucher AvSim. Ne pas revert compileSdk 37 / ndkVersion 30.0.16248370.
Pas de sdkmanager. Pas de windows/. Pas d'Accueil sur /live /cox /coach.

## Règles
- Catalogue FFA = assets/ffa_calendar_2026.json curaté, PAS de scraping live.
- Chaque entrée source:ffa affiche « Source : FFA — indicatif, vérifier sur ffaviron.fr ».
- Géocodage via Nominatim/OSM (gratuit, sans clé). Cache local.
- Carte = flutter_map + tuiles OSM. Pas de Google Maps.
- Export .ics local uniquement (pas de sync cloud, Point B plus tard).
- Loisir : lecture seule du calendrier. Coach : CRUD événements club + plans d'eau.
- Ne pas casser Point D (import cabane, blason, spinoscope).

## E1 — modèle + seed, AUCUN écran
lib/calendar/models.dart : WaterBody, Competition
lib/calendar/ffa_seed.dart : parse assets/ffa_calendar_2026.json (10 événements minimum)
lib/calendar/store.dart : JSON local Documents/datar0w/calendar.json
Tests : parse seed, round-trip, filtre par distance, catégorie.
Commit : feat(datar0w): calendar model + FFA seed

## E2 — localisation club
Étendre Club (Point D3) : address, lat, lon, geocode via Nominatim.
Sur fiche club : pin carte (flutter_map) + bassin d'entraînement si différent.
Compteur « N compétitions à ≤ 150 km ».
Commit : feat(datar0w): club geolocation + map pin

## E3 — calendrier + fiche
Route /calendar : liste chronologique, groupée par mois.
Filtres : type (CF/national/régional/club), discipline, distance (≤50/150/300/tous).
Tap → /calendar/event : dates, lieu, mini-carte, type/discipline/catégories,
  distance depuis club, source, lien externe, CTA « Ajouter à mon calendrier » (.ics).
Commit : feat(datar0w): competition calendar screen + detail

## E4 — plans d'eau
Route /waterbodies : liste + fiche (nom, type, adresse, carte, piste m, notes).
Coach : CRUD. Rameur : lecture.
Rattachement : bassin → club ; site → compétition.
Commit : feat(datar0w): water bodies list + detail

## E5 — export ics + mes compétitions
Génération .ics locale depuis Competition.
Toggle « mes compétitions » (celles où le club est engagé) — stockage local.
Commit : feat(datar0w): ics export + my competitions

flutter analyze clean entre chaque lot.
Un commit par lot E1…E5.
```

---

## 6. Hors scope (volontaire)

- Sync cloud / multi-coach (Point B).
- Inscriptions en ligne aux compétitions FFA.
- Résultats / classements.
- Scraping automatique de ffaviron.fr.
- Notifications push « compétition dans 7 jours » (plus tard).
- Cartes hors-ligne tuiles (téléchargement) — plus tard.

---

## 7. Décisions figées

| # | Décision | Choix |
|---|----------|-------|
| E1 | Source calendrier FFA | Catalogue curaté JSON, pas de scraping |
| E2 | Géocodage | Nominatim/OSM gratuit |
| E3 | Cartes | flutter_map + tuiles OSM |
| E4 | Export calendrier | .ics local, pas de sync cloud |
| E5 | Accès loisir | Lecture seule du calendrier |
| E6 | Mise à jour catalogue | Manuelle chaque saison (1 h) |

---

*Point E — 20 sept 2026. Cadrage uniquement. Pas de code lancé.*
