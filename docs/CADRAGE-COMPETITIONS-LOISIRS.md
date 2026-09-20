# Point L — Compétitions loisirs & randonnées (cadrage)

> **Statut** : cadrage exploratoire. Aucun code. À discuter avant de figer.
> **Prérequis** : Point E (calendrier FFA) + Point F (scraper serveur) + Point G (licenciés agrégés).
> **But** : couvrir le monde « loisir qui compétitionne » — régates ouvertes, randonnées, coupes club — sans toucher au Code des régates compétition pure.

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

**Conséquence** : le calendrier (Point E) doit porter un flag `open_to_loisir: bool` + la **définition loisir du club** (texte libre, car chaque organisateur la fixe).

### 1.3 Randon'Aviron (fait, c'est le gros du loisir « compétition »)
- **Circuit national Randon'Aviron** : ~50 randonnées/an, labellisées FFA. Critères : ≥25 km (rivière 1j) / ≥40 km (2j) / ≥20 km (mer), **pas de compétition**, ≥50 participants hors club orga, parcours touristique.
- **Points Randon'Aviron** : clubs labellisés, navigation libre hors calendrier.
- Emblématique : **Traversée de Paris** (41e éd. 2026, 26–28 km, 1300+ rameurs, 260+ bateaux, 10+ nations) — *« n'est pas une compétition, c'est une fête »* mais labellisée Randon'Aviron + Fête du Sport.
- Sources : [ffaviron.fr/.../aviron-de-randonnee](https://www.ffaviron.fr/pratiquer-laviron/les-programmes-federaux/aviron-de-randonnee/), [cahier des charges Randon'Aviron 2025](https://www.ffaviron.fr/wp-content/uploads/2024/08/ffaviron-randonnee-cahier-charges-randon-aviron-2025.pdf).

**Conséquence** : randonnée ≠ régate. Deux types d'événements dans le calendrier, deux fiches, deux flux d'inscription.

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

---

## 2. Décisions à trancher (à discuter)

| # | Décision | Options | Recommandation |
|---|----------|---------|----------------|
| **L1** | Périmètre « compétition loisir » | (a) uniquement régates *ouvertes* (flag open_to_loisir) + Randon'Aviron ; (b) + championnats master ; (c) tout ce qui n'est pas Règlementation sportive | **(a)+(b)** : master = le vrai pont, à inclure |
| **L2** | Définition « loisir » | (a) reprendre celle de l'orga (texte) ; (b) forcer « licence AL ou non-inscrit 2 saisons » ; (c) les deux, l'orga choisit | **(c)** : afficher la définition de l'orga, proposer un tag standard |
| **L3** | Inscription depuis l'app | (a) deep-link MyFFA / site orga ; (b) formulaire in-app (besoin EC/AC) ; (c) juste info + contact | **(a)** au MVP : on ne gère pas les paiements/licences |
| **L4** | Randon'Aviron : même écran que régate ? | (a) oui, type `randonnee` ; (b) écran dédié | **(a)** : un seul calendrier, filtre type |
| **L5** | Trophée / résultat loisir | (a) stocker le classement loisir de l'équipage ; (b) hors scope | **(a)** léger : 1 résultat par événement, opt-in |
| **L6** | Sync avec Point E/F/G | calendrier loisir = extension du catalogue FFA (E) + agrégat licenciés (G) pour « qui peut y aller » | Oui, pas de silo |

---

## 3. Modèle de données (proposition)

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
  resultats: [{ equipage_id, classement_loisir, classement_general? }],
  labellise: 'RandonAviron' | 'FeteDuSport' | null,
}
```

Règle : un `EventLoisir` ne remplace **pas** un `Event` compétition (Point E) — il le complète. Un master = les deux tags possibles.

---

## 4. Parcours utilisateur (coach / rameur)

**Coach**
1. Calendrier → filtre « Loisir / Rando / Master ».
2. Fiche événement : définition loisir, licence requise, plan d'eau, inscription (lien).
3. Composition : proposer l'équipage *en respectant* la définition (ex. pas de rameur master-inscrit 2 saisons dans une case « loisir »).
4. Après : saisir le classement loisir (opt-in) → alimente le spinoscope club.

**Rameur loisir (AL)**
1. Voit uniquement les événements `open_to_loisir` + randonnées + master.
2. Bandeau clair : « ta licence AL t'autorise cet événement ; pour les championnats AC, passe en compétition ».
3. Peut s'inscrire via le lien (MyFFA / site orga) — l'app ne paie pas.
4. Après : voit son résultat loisir dans son profil / spinoscope.

**Rameur compétiteur (AC)**
1. Voit tout (loisir + compétition + master).
2. Peut s'engager en loisir (certains le font pour la convivialité) — l'app ne l'en empêche pas, mais le tag « loisir » du classement reste distinct.

---

## 5. Lots (ordre de build)

| Lot | Contenu | Dépend de |
|-----|---------|-----------|
| **L1** | Modèle `EventLoisir` + store local + tests (définition, licence, flags) | E (calendrier), F (clubs) |
| **L2** | Extension calendrier : filtre type + fiche événement loisir/rando | L1, E |
| **L3** | Garde-fous licence : bandeau AL/AC/EC selon l'événement | L1, G (niveau rameur) |
| **L4** | Résultats loisir + spinoscope club (classement loisir) | L1, D (spinoscope) |
| **L5** | Sync serveur : ingestion régates ouvertes + Randon'Aviron (extension scraper F) | F, L1 |

**Hors scope (volontaire)** : paiements, gestion des inscriptions FFA, arbitrage, chronométrage, Code des régates (déjà géré par la FFA).

---

## 6. Prompt Cursor (à coller tel quel)

```
DataR0w — Point L : compétitions loisirs & randonnées.
Lis docs/CADRAGE-COMPETITIONS-LOISIRS.md + docs/CADRAGE-CALENDRIER-FFA-PLANS-D-EAU.md
+ docs/CADRAGE-FFA-SERVEUR-SCRAPER.md + docs/CADRAGE-FFA-LICENCIES-AGREGES.md.

Ne pas toucher AvSim. Ne pas revert compileSdk 37 / NDK 30. Pas de sdkmanager.
Pas d'Accueil sur /live /cox /coach. Ne pas porter le jargon Stitch.

## Règles figées
- Licence AL = pas de compétition Règlementation sportive. L'app le dit (bandeau),
  ne le laisse pas croire.
- Régates « ouvertes loisir » existent (ex. Fontainebleau) : flag open_to_loisir +
  définition_loisir (texte orga) sur EventLoisir.
- Randon'Aviron = type 'randonnee', pas une régate. Même calendrier, filtre type.
- Master = inclus (pont loisir/compétition), tag 'master'.
- Inscription = deep-link (MyFFA / site orga). Pas de paiement in-app.
- Résultat loisir = opt-in, 1 par événement, alimente spinoscope club.
- Sync = extension du scraper F (pas de silo).

## L1 — modèle + tests, AUCUN écran
lib/events/event_loisir.dart : EventLoisir (voir §3 du cadrage).
lib/events/loisir_store.dart (JSON local, même pattern que identity/store).
Tests : flags, définition, licence_requise, labellise, JSON round-trip.
Commit : feat(datar0w): event loisir model + store

## L2 — calendrier étendu
Écran calendrier (existant Point E) : ajouter filtre type
  (régate_ouverte / randonnee / master / indoor_loisir) + fiche événement
  loisir (définition, licence, plan d'eau, inscription lien).
Commit : feat(datar0w): calendar loisir filter + event sheet

## L3 — garde-fous licence
Bandeau selon niveau rameur (AL/AC/EC) + type événement.
Un rameur AL ne voit pas les événements AC-only ; il voit loisir/rando/master.
Commit : feat(datar0w): licence guard loisir/competition

## L4 — résultats + spinoscope
Saisie opt-in du classement loisir → spinoscope club (Point D).
Commit : feat(datar0w): loisir results + club spinoscope

## L5 — sync serveur
Extension scraper F : ingérer régates ouvertes + Randon'Aviron labelisées.
Commit : feat(datar0w): sync loisir events from FFA scraper

flutter analyze clean. Un commit par lot L1…L5.
```

---

## 7. À discuter avant de figer

1. **L1** : on inclut les master dans « loisir » ou on les garde « compétition » avec un sous-tag ? (Reco : les deux tags.)
2. **L3** : on bloque vraiment l'engagement AL sur AC, ou on affiche juste un warning ? (Reco : bloquer l'action « S'engager », laisser la lecture.)
3. **L5** : le scraper Randon'Aviron est-il faisable (pages FFA en cartes) ? À valider en prototype avant de promettre.
4. **Périmètre** : on reste France / FFA, ou on ouvre World Rowing Tour / Vogalonga (déjà cité par des clubs) ? (Reco : France d'abord.)

---

*Point L — compétitions loisirs. À valider avant tout code.*
