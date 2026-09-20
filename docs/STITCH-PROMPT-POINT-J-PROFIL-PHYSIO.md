# Brief Stitch — Point J : Profil rameur physiologique

> **Usage** : coller ce brief dans Stitch (même projet que les planches I2–I5 / D / E). Ne pas refaire les écrans 1–9 déjà gelés (identité, club, parc, composition, accueil rôle). Ne pas redessiner `/live`, `/cox`, `/tare`, `/coach` carte, `/replay`.
>
> **Références UI pompées** : Garmin Connect (In Focus cards, Training Readiness 0–100, Body Battery), WHOOP (Recovery score), Oura (Trends 7/28/90j), CrewNerd (layout paysage configurable, champs data), ErgData (data screens small/medium/large, graph overlay).

---

## DA FIGÉE (Marine Avionics Deck, déjà en prod)

- Fond `#0B0E12`. Texte blanc. Labels `#9AA0A6`. Filets `#2A2F36`.
- CTA `#E8C547` texte noir. Accents : TRIBORD `#46C275`, BÂBORD `#E05353`.
- Police type JetBrains Mono / chiffres cockpit. PAS de cyan High-Vis, PAS de RTK, 10 Hz, watts, SYS READY, 2000 m FISA.
- Chiffres = toujours mono. Scores (Readiness, Recovery) = gros chiffre + anneau de progression.

## CONTEXTE PRODUIT (1 phrase)

Après le setup identité (qui, taille, poids, côté, pelles), le rameur connecte ses objets connectés (patch dorsal PPG, sangle, brassard) et retrouve toutes ses constantes physiques par session : FC, SpO2, température, tendance de récupération. Le coach voit ces constantes **uniquement si le rameur a opt-in** (partage consentement, pas de défaut partagé).

## NAVIGATION À RESPECTER

```
/identity (liste) → /identity/edit (fiche) → /home/rower (accueil)
                         ↓
              /profile/physio   ← NOUVELLE BRANCHE (depuis fiche ou accueil)
                   ↓
         /profile/devices  (objets connectés)
                   ↓
         /profile/constants (tableau de bord constantes)
```

Pendant `/live` : le patch dorsal alimente FC + orientation torse en temps réel (point I layout). Ici on conçoit l'**après-séance** et le **profil**, pas le live.

Pendant live/cox/coach : PAS de bouton Accueil.

---

## ÉCRANS À PRODUIRE (4) — portrait 390×844 sauf J3 paysage

### ÉCRAN J1 — Mes objets connectés (portrait)

**But** : le rameur voit et gère ses capteurs (patch dorsal, sangle pectorale, brassard). Aucun jargon technique.

- Header : « MES OBJETS » + chip batterie du patch dorsal si connecté (ex. « 78 % » vert, <20 % ambre).
- Liste des objets appairés :
  - Ligne : icône type (patch / sangle / brassard) + nom + statut (connecté vert / hors ligne gris / batterie faible ambre) + dernier sync (ex. « il y a 2 min »).
  - Swipe gauche : « Oublier » (désappairage, confirme).
- CTA principal : « + AJOUTER UN OBJET » (jaune) → scan BLE (animation radar, liste des appareils à portée, tap pour appairer).
- État vide : illustration patch + « Aucun objet connecté. Appuie pour scanner. »
- Note bas de page (petit, gris) : « Le patch dorsal mesure FC, SpO2, température et orientation. La sangle améliore la précision FC. »
- **Pas** de champ de saisie manuelle de constantes ici — tout vient du capteur.

### ÉCRAN J2 — Readiness / Récupération (portrait) — pattern Garmin In Focus + WHOOP Recovery

**But** : score de forme du jour, lisible en 2 secondes, dérivé des constantes de la veille + tendance.

- Score géant au centre : « 74 » + anneau de progression coloré (vert >70, ambre 40–70, rouge <40) + libellé « READY » / « MODERATE » / « REST ».
- 4 contributeurs en cartes (style Garmin In Focus, swipe horizontal) :
  1. **FC repos** — valeur + tendance 7j (flèche haut/bas).
  2. **SpO2 nuit** — valeur + tendance.
  3. **Température peau** — écart vs baseline.
  4. **Charge séance** — SPM moyen + temps total + distance (de la dernère session).
- Courbe tendance 28 jours (ligne, axe temps) : score Readiness jour par jour. Tap pour zoomer 7 / 28 / 90 j.
- Bandeau bas (ambre si score <50) : « Récupération incomplète — allège la charge aujourd'hui. » (opt-in coach : mention « ton coach voit ce score » si partage activé).
- CTA : « VOIR MES CONSTANTES » → J3.

### ÉCRAN J3 — Mes constantes (portrait + variante paysage) — pattern ErgData graph + Oura Trends

**But** : le rameur retrouve **toutes** ses constantes physiques, séance par séance, avec overlay multi-métriques.

**Portrait (390×844)** :
- Header : « MES CONSTANTES » + filtre période (7j / 28j / 90j) en chips.
- Liste des séances récentes (cards) : date, coque, séance (ex. « 8x500m »), SPM moy, FC moy, FC max, distance. Tap → détail séance.
- Détail séance : graphique temporel (X = temps) avec **jusqu'à 3 courbes empilées/overlay** (style ErgData) :
  - FC (battements, rouge/ambre)
  - SPM (cadence, vert)
  - Vitesse sol ou pace (bleu)
  - Option : SpO2 (pointillé), température (gris)
  - Toggle chips en bas pour activer/désactiver chaque courbe.
- Résumé bas : FC moy / max, SPM moy / max, distance, temps, charge estimée.
- Chip « partagé avec coach » (vert) ou « privé » (gris) — tap pour basculer le consentement de CETTE séance.

**Variante paysage (844×390)** — pour consultation au calme (pas en coup) :
- Gauche 60 % : graphique plein écran, mêmes 3 courbes, axe temps large, zoom pincement.
- Droite 40 % : panneau résumé (FC moy/max, SPM, distance, pace) + tendance 28j miniature + toggle courbes.
- Même DA, même police mono pour les chiffres.

### ÉCRAN J4 — Consentement partage coach (portrait, modal ou écran léger)

**But** : le rameur contrôle ce que son coach voit. Opt-in, jamais de défaut partagé.

- Titre : « PARTAGE AVEC TON COACH ».
- 3 toggles indépendants :
  1. **Readiness / score de récupération** (J2) — oui/non.
  2. **Constantes de séance** (FC, SPM, SpO2, température) — oui/non.
  3. **Tendance 28 jours** — oui/non.
- Note : « Ton coach voit uniquement ce que tu autorises. Tu peux retirer à tout moment. »
- CTA : « ENREGISTRER » (jaune).
- Lien : « Pourquoi ces données ? » → mini-explication (données de santé, consentement RGPD, révocable).

---

## INTERDIT

- Recréer Qui rame / fiche / club / bateau / composition / accueil rôle (1–9).
- Recréer `/live`, `/cox`, `/tare`, carte coach, replay.
- Login Google, licence FFA en ligne, IMC comme champ saisi, 8 IMU, High-Vis cyan.
- Partage **par défaut** des constantes avec le coach (toujours opt-in).
- Social, fil d'actu, abonnement payant, gamification lourde.
- SpO2 affiché comme mesure clinique en mouvement (labelliser « approximatif » si besoin).

## LIVRABLE

4 écrans (J1, J2, J3 portrait + J3 paysage, J4) + HTML. Même DA que la planche actuelle (`#0B0E12` / `#E8C547`).

Après livraison : on gèle J1–J4 à côté des 9 existants, puis Cursor code les lots J1–J5 du cadrage `CADRAGE-PROFIL-RAMEUR-PHYSIO.md`.
