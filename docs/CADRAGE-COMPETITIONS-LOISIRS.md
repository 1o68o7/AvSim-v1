# Point L — Compétitions loisirs & randonnées (cadrage)

> **Statut** : cadrage figé (validé). Aucun code. Prêt à coder L1→L5.
> **Prérequis** : Point E (calendrier FFA) + Point F (scraper serveur) + Point G (licenciés agrégés) + Point D (spinoscope).
> **But** : couvrir le monde « loisir qui compétitionne » — régates ouvertes, randonnées, coupes club — sans toucher au Code des régates compétition pure.

---

## 0. Décisions figées (validées)

| # | Décision | Choix figé |
|---|----------|------------|
| **L1** | Périmètre | Régates *ouvertes* (flag `open_to_loisir`) + Randon'Aviron + championnats **master** (pont loisir/compétition). |
| **L2** | Définition « loisir » | Afficher la définition de l'orga (texte) + proposer un tag standard. Jamais forcer. |
| **L3** | Inscription | Deep-link MyFFA / site orga. Pas de paiement ni gestion de licence in-app. |
| **L4** | Randon'Aviron | Même écran calendrier, type `randonnee`, filtre type. |
| **L5** | Résultats | Saisie opt-in du classement loisir de l'équipage → spinoscope club. 1 résultat / événement. |
| **L6** | Sync | Extension du catalogue FFA (E) + agrégats licenciés (G). Pas de silo. |
| **L7** | Un rameur = un parcours | Un rameur (loisir ou compétiteur) peut faire **régate + rando + master**. L'app ne l'empêche pas. Le tag de classement reste distinct. |
| **L8** | Signalement | Le rameur / coach peut **signaler** sa participation (régate, rando, master) pour alimenter classements & temps. Opt-in, vérifiable. |

---

## 1. Ce que j'ai vérifié en live (FFA, sept 2026)

### 1.1 Licences : AL vs AC (fait)
- **Licence Aviron annuelle Loisir (AL)** : activités du club, **pas** les compétitions de la Règlementation sportive.
- **Licence Aviron annuelle Compétition (AC)** : activités + compétitions (régates, championnats, critériums).
- Source : [ffaviron.fr/accompagnement-des-structures/licences](https://www.ffaviron.fr/accompagnement-des-structures/licences/).

**Conséquence produit** : un rameur « loisir » dans DataR0w **ne peut pas** s'engager dans une régate AC. L'app doit le dire clairement (bandeau « licence AL — compétition réservée AC »), pas le laisser croire le contraire.

### 1.2 Il existe des compétitions *ouvertes aux loisirs* (fait)
Des clubs organisent des régates avec **classement Loisir** explicite, distinct de l'Open :
- **Régate du Pays de Fontainebleau** (ANFA, ~100 ans) : 6 classements — Open H/F/mixte + **Loisirs H/F/mixte**. Définition loisir = rameur J14+ *n'ayant pas* été inscrit aux championnats de France / critérium national FFA lors des 2 dernières saisons. Formule de handicap (type bateau + âge + sexe) → « coupe du Pays de Fontainebleau ». Inscription 15 €, 30 bateaux max.
- Même logique ailleurs : Coupe des dames (Angers), régates régionales « open + loisir ».
- **Classement loisir = temps de course réels** (ex. PDF « CLASSEMENT LOISIRS - (temps de course réels) » : place, club, barreur, catégorie, heure départ, heure arrivée, temps mi-course, temps de course).

**Conséquence** : le calendrier (Point E) doit porter un flag `open_to_loisir: bool` + la **définition loisir du club** (texte libre, car chaque organisateur la fixe). Les **temps** sont une donnée de premier ordre pour le classement loisir.

### 1.3 Randon'Aviron (fait, c'est le gros du loisir « compétition »)
- **Circuit national Randon'Aviron** : ~50 randonnées/an, labellisées FFA. Critères : ≥25 km (rivière 1j) / ≥40 km (2j) / ≥20 km (mer), **pas de compétition**, ≥50 participants hors club orga, parcours touristique.
- **Trophée Randon'Aviron** : classement clubs par points (ex. 2025 : Base Nautique de Sciez 1er, 415,2 pts). Basé sur km parcourus + nombre de randonnées.
- Emblématique : **Traversée de Paris** (41e éd. 2026, 26–28 km, 1300+ rameurs, 260+ bateaux, 10+ nations) — *« n'est pas une compétition, c'est une fête »* mais labellisée Randon'Aviron + Fête du Sport.
- Sources : [ffaviron.fr/.../aviron-de-randonnee](https://www.ffaviron.fr/pratiquer-laviron/les-programmes-federaux/aviron-de-randonnee/), [cahier des charges Randon'Aviron 2025](https://www.ffaviron.fr/wp-content/uploads/2024/08/ffaviron-randonnee-cahier-charges-randon-aviron-2025.pdf), [Trophée 2025](https://www.ffaviron.fr/wp-content/uploads/2026/02/ffaviron-trophee-randon_aviron-2025.pdf).

**Conséquence** : randonnée ≠ régate. Deux types d'événements dans le calendrier, deux fiches, deux flux d'inscription. Le Trophée club = spinoscope, pas un classement rameur.

### 1.4 Licence événementielle (EC) (fait)
- Souscrite **individuellement sur MyFFA**, sans adhésion club, valable début→fin d'une compétition (≤3 j).
- Permet toutes les compétitions FFA **sauf** les manifestations de la Règlementation sportive (championnats/critériums). Indoor inclus.
- Utile pour un loisir qui veut *tester* une régate ouverte sans prendre AC.

### 1.5 Championnats « master » = le pont loisir/compétition (fait)
- Championnats de France **master** (ex. Brive 2025 : **1047 équipages, 3500+ rameurs**, record) : 7 catégories d'âge (A→G), toutes embarcations, esprit convivial + performance. C'est *le* rendez-vous où le loisir compétitionne vraiment.
- Sources : actu FFA Brive 2025.

### 1.6 Ce que la FFA *ne* publie pas (fait)
- Pas de calendrier « compétitions loisir » dédié. Les régates ouvertes sont noyées dans « Tous les événements FFA » (cartes HTML, pas d'API — Point E).
- Pas de définition fédérale unique de « loisir » : chaque organisateur la rédige (Fontainebleau = non-inscrit 2 saisons ; d'autres = licence AL, etc.).
- Pas de flux iCal / API pour Randon'Aviron non plus.
- Pas de base unifiée « qui a fait quoi » (régate + rando + master) au niveau rameur.

---

## 2. Le principe « un rameur, un parcours » (figé, L7)

Un rameur — loisir **ou** compétiteur — peut enchaîner :
- une **régate ouverte** (classement loisir, temps réels),
- une **randonnée** Randon'Aviron (km, pas de chrono officiel),
- un **championnat master** (classement officiel, temps).

L'app **ne l'empêche pas**. Elle **signale** chaque participation pour :
1. alimenter le **classement loisir** de l'équipage / du club,
2. afficher les **temps** (là où ils existent : régate loisir, master),
3. nourrir le **spinoscope** club (Point D) et le profil rameur.

Règle : le **tag de classement** reste distinct (`loisir` / `master` / `rando`). Un rameur AC qui fait une régate loisir garde son tag « loisir » pour cet événement — il ne « triche » pas, il participe.

---

## 3. Signalement de participation (figé, L8)

Deux modes, opt-in :

**A. Signalement manuel (rameur / coach)**
- Depuis la fiche événement ou le profil : « J'ai participé » / « Mon équipage a participé ».
- Champs : événement, date, équipage (siège + côté), **temps** (si course chronométrée), classement loisir (si publié), distance (si rando).
- Vérifiable : le club orga ou un autre participant peut confirmer (optionnel, plus tard).

**B. Import résultat (orga / coach)**
- Upload d'un PDF / CSV de résultats (ex. « CLASSEMENT LOISIRS - temps de course réels ») → parsing → affectation aux équipages signalés.
- Même pattern que l'import cabane (Point D) : prévisualisation, mapping colonnes.

**Ce que ça produit**
- Classement loisir de l'équipage (place + temps) sur la fiche événement.
- Historique rameur : « 3 régates loisir, 1 rando, 1 master — meilleur temps 1:05:59 ».
- Spinoscope club : effectif engagé, km rando, podiums loisir.

---

## 4. Modèle de données (proposition)

```text
EventLoisir {
  id, source: 'ffa' | 'club' | 'manual',
  type: 'regate_ouverte' | 'randonnee' | 'master' | 'indoor_loisir',
  nom, dates: {debut, fin},
  plan_eau_id (→ Point E),
  club_organisateur_id (→ Point F),
  distance_km?, format: 'ligne' | 'tete_de_riviere' | 'randonnee' | 'indoor',
  open_to_loisir: bool,
  definition_loisir: text,          // texte de l'orga
  licence_requise: 'AL' | 'AC' | 'EC' | 'aucune',
  inscription: { url, tarif_eur?, limite_bateaux? },
  handicap: bool,                   // formule de points (ex. Fontainebleau)
  resultats: [{ equipage_id, classement_loisir, temps?, classement_general? }],
  labellise: 'RandonAviron' | 'FeteDuSport' | null,
}

ParticipationLoisir {                 // signalement (L8)
  id, event_id, rower_id, equipage_id?,
  type: 'regate_ouverte' | 'randonnee' | 'master',
  date, temps_course?, distance_km?, classement_loisir?,
  source: 'manuel' | 'import_resultat' | 'ffa_sync',
  verified: bool,
}
```

Règle : un `EventLoisir` ne remplace **pas** un `Event` compétition (Point E) — il le complète. Un master = les deux tags possibles.

---

## 5. Parcours utilisateur (coach / rameur)

**Coach**
1. Calendrier → filtre « Loisir / Rando / Master ».
2. Fiche événement : définition loisir, licence requise, plan d'eau, inscription (lien).
3. Composition : proposer l'équipage *en respectant* la définition (ex. pas de rameur master-inscrit 2 saisons dans une case « loisir »).
4. Après : **signaler la participation** (équipage + temps + classement) → alimente spinoscope club + profils rameurs.
5. Option : importer le PDF/CSV de résultats loisir → mapping auto.

**Rameur loisir (AL)**
1. Voit uniquement les événements `open_to_loisir` + randonnées + master.
2. Bandeau clair : « ta licence AL t'autorise cet événement ; pour les championnats AC, passe en compétition ».
3. Peut s'inscrire via le lien (MyFFA / site orga) — l'app ne paie pas.
4. Après : **signale sa participation** (temps, place) → visible dans son profil / spinoscope.

**Rameur compétiteur (AC)**
1. Voit tout (loisir + compétition + master).
2. Peut s'engager en loisir (certains le font pour la convivialité) — l'app ne l'en empêche pas, mais le tag « loisir » du classement reste distinct.
3. Peut aussi signaler une rando ou un master.

---

## 6. Lots (ordre de build)

| Lot | Contenu | Dépend de |
|-----|---------|-----------|
| **L1** | Modèle `EventLoisir` + `ParticipationLoisir` + store local + tests | E, F, G |
| **L2** | Extension calendrier : filtre type + fiche événement loisir/rando/master | L1, E |
| **L3** | Garde-fous licence : bandeau AL/AC/EC selon l'événement | L1, G |
| **L4** | Signalement participation (manuel + import résultat) + spinoscope | L1, D |
| **L5** | Sync serveur : ingestion régates ouvertes + Randon'Aviron + master | F, L1 |

**Hors scope (volontaire)** : paiements, gestion des inscriptions FFA, arbitrage, chronométrage officiel, Code des régates (déjà géré par la FFA).

---

## 7. Prompt Cursor (à coller tel quel)

```
DataR0w — Point L : compétitions loisirs & randonnées.
Lis docs/CADRAGE-COMPETITIONS-LOISIRS.md + docs/CADRAGE-CALENDRIER-FFA-PLANS-D-EAU.md
+ docs/CADRAGE-FFA-SERVEUR-SCRAPER.md + docs/CADRAGE-FFA-LICENCIES-AGREGES.md
+ docs/CADRAGE-IMPORT-CABANE.md (pattern import résultat).

Ne pas toucher AvSim. Ne pas revert compileSdk 37 / NDK 30. Pas de sdkmanager.
Pas d'Accueil sur /live /cox /coach. Ne pas porter le jargon Stitch.

## Règles figées
- Licence AL = pas de compétition Règlementation sportive. L'app le dit (bandeau).
- Régates « ouvertes loisir » : flag open_to_loisir + définition_loisir (texte orga).
  Classement loisir = temps de course réels (donnée de 1er ordre).
- Randon'Aviron = type 'randonnee', pas une régate. Même calendrier, filtre type.
- Master = inclus (pont loisir/compétition), tag 'master'.
- Un rameur (loisir ou compétiteur) peut faire régate + rando + master (L7).
  L'app ne l'empêche pas ; le tag de classement reste distinct.
- Signalement de participation (L8) : manuel (rameur/coach) + import PDF/CSV
  de résultats loisir. Opt-in, alimente spinoscope + profil rameur.
- Inscription = deep-link (MyFFA / site orga). Pas de paiement in-app.
- Sync = extension du scraper F (pas de silo).

## L1 — modèle + tests, AUCUN écran
lib/events/event_loisir.dart : EventLoisir + ParticipationLoisir (voir §4).
lib/events/loisir_store.dart (JSON local, même pattern que identity/store).
Tests : flags, définition, licence_requise, labellise, signalement, JSON round-trip.
Commit : feat(datar0w): event loisir + participation model + store

## L2 — calendrier étendu
Écran calendrier (existant Point E) : ajouter filtre type
  (régate_ouverte / randonnee / master / indoor_loisir) + fiche événement
  loisir (définition, licence, plan d'eau, inscription lien, temps si résultat).
Commit : feat(datar0w): calendar loisir filter + event sheet

## L3 — garde-fous licence
Bandeau selon niveau rameur (AL/AC/EC) + type événement.
Un rameur AL ne voit pas les événements AC-only ; il voit loisir/rando/master.
Commit : feat(datar0w): licence guard loisir/competition

## L4 — signalement + spinoscope
Saisie opt-in participation (équipage, temps, classement loisir) → spinoscope club (Point D)
+ profil rameur. Import PDF/CSV résultats loisir (pattern Point D).
Commit : feat(datar0w): loisir participation signal + result import

## L5 — sync serveur
Extension scraper F : ingérer régates ouvertes + Randon'Aviron labelisées + master.
Commit : feat(datar0w): sync loisir events from FFA scraper

flutter analyze clean. Un commit par lot L1…L5.
```

---

## 8. Limites assumées

- Pas de chronométrage officiel in-app (la FFA / l'orga gèrent via Time-Team etc.).
- Pas de paiement ni gestion de licence FFA.
- Le scraper Randon'Aviron (pages en cartes) à valider en prototype avant de promettre L5.
- Périmètre France / FFA d'abord ; World Rowing Tour / Vogalonga plus tard si demandé.

---

*Point L — compétitions loisirs. Figé, prêt à coder.*
