# MVP club — brief Stitch

*16 septembre 2026 · pack d'écrans à produire.  
Complète `STATE.md` (physique) et `docs/ETAT-DATAROW.md` (chantiers).  
Ceci n'est **pas** l'UI Analyste ni l'aide à l'achat capteurs.*

Coller ce fichier dans Stitch tel quel. Une app, trois profils, sept écrans.

---

## 0. Produit en une phrase

Application native (iOS + Android) : le smartphone du bateau est le **concentrateur**. Il affiche les instruments au rameur, agrège GPS / IMU / BLE, et pousse un flux 4G/5G vers le coach. Personne ne voit tout.

Nom de travail à l'écran : **DataR0w** (pas « AvSim », pas « Analyste »).

---

## 1. Décisions figées

| Sujet | Décision |
|---|---|
| Premier bateau | **1x (skiff)** |
| Autres classes | Mêmes écrans ; schéma 2 / 4 / 8 cases + profil Barreur si bateau barré |
| Fixation | Support au **cale-pied**, ou au **portant** s'il passe au-dessus. Téléphone **paysage**, axe long // axe bateau |
| Niveau | Support réglé mécaniquement à l'horizontale. L'app fait une **tare gîte à quai**, pas un offset inventé à chaque coup |
| Coach live | **4G/5G** bateau → cloud → téléphone coach. Trou réseau = log local, sync à quai |
| Stack UI | Native iOS + Android (Flutter par défaut si non tranché). Stitch dessine, pas le framework |
| Aide à l'achat capteurs | Outil **maison**, hors ce pack |

---

## 2. Deux surfaces mentales

| Surface | Public | Dans Stitch ? |
|---|---|---|
| **Club** | Rameur, Barreur, Coach | **Oui** — ce document |
| **Maison** | Analyste, Pareto capteurs, YAML | **Non** |

---

## 3. Profils — qui voit quoi

Session unique. Trois fenêtres.

### 3.1 Rameur (1x, paysage, 80 cm, soleil)

**Afficher**

- Gros : cadence (coups/min), vitesse GPS, distance **ou** temps (un seul des deux en gros)
- Moyen : **gîte** (horizon artificiel / bille, axe bateau)
- Petit : état capteurs (OK / perdu), batterie téléphone, pastille réseau (4G / hors ligne)

**Ne jamais afficher au rameur**

- Watts, η palette, check_factor, slip, Mode C, YAML
- Force / angle des autres postes
- Liste d'annotations coach
- Plus d'une alerte à la fois

**Feedback** : un seul motif — gîte hors bande **ou** rupture de cadence. Pas les deux.

Légende obligatoire sous la vitesse : `sol — pas eau` (GPS ≠ vitesse surface).

### 3.2 Barreur (4+ / 8+ seulement — écran prêt, profil grise sur 1x)

**Afficher** : même socle + schéma postes (qui décroche) + cap / dérive + dernière consigne coach (une ligne).

**Ne pas afficher** : courbe de force du barreur.

### 3.3 Coach (canot / rive, portrait acceptable, paysage préféré)

**Live** : carte + cadence équipage + 3 alertes max + bouton **Annoter** (1 tap = timestamp).

**Replay quai** : timeline + **2 courbes max** + liste annotations. Écarts bruts seulement. Pas de seuil inventé (« bon / mauvais »).

**Ne pas afficher** : réglage physique, Observabilité, badges labo.

Consigne **vers** le rameur pendant le live : **hors MVP** (annotation locale coach seulement). À débloquer plus tard.

---

## 4. Les 7 écrans à dessiner

Orientation **paysage** pour 3, 4, 5. Portrait OK pour 1, 2, 6, 7.

Cible : iPhone 15 / Pixel classe 6,1" paysage ≈ 844×390 pt. Contraste WCAG AAA sur les 3 gros chiffres. Fond sombre (soleil sur l'eau). Pas de glassmorphism. Pas de sidebar desktop.

### Écran 1 — Entrée / profil

- Logo DataR0w
- Trois cartes : **Rameur** | **Coach** | **Barreur**
- Barreur **grisé** + mention `besoin d'un bateau barré` tant que la classe = 1x
- Pas de sélecteur Analyste

### Écran 2 — Pré-session (portrait ou paysage)

- Classe : `1x` sélectionné ; autres classes visibles mais secondaires
- Bassin (texte libre v1)
- Liste capteurs : `GPS` `IMU` + emplacements BLE vides (`— aucun`)
- Bouton plein largeur : **Tare gîte (30 s)** — bateau à quai, coque calée
- État tare : `non faite` / `OK ±0,2°`
- CTA : **Démarrer la session**

### Écran 3 — Rameur live (paysage) — écran roi

Trois colonnes stables, pas de scroll.

```
┌───────────────┬────────────┬───────────┐
│  28 /min           │   GÎTE         │  ● GPS  │
│  4.2 m/s  sol      │   [horizon]    │  ● IMU  │
│  1.24 km           │   +1.4° trib.  │  4G  62%│
└───────────────┴────────────┴───────────┘
```

- Chiffres nav : très gros, mono, blanc sur noir
- Gîte : horizon type avion léger, **l'eau est la référence visuelle**, pas un graphe Plotly
- Bande de tolérance gîte ±X° (X = 3° v1, réglable plus tard, pas un knob sur cet écran)
- Zone statut : pastilles, pas de texte long
- Bouton discret `Stop` coin bas (confirmation 1 tap de plus)

### Écran 4 — Rameur alerte (variante de 3)

Même layout. Une barre haute pleine largeur, une cause, une couleur.

- `Gîte — trop tribords` **ou**
- `Cadence — rupture`

Pas de stack d'alertes. Disparaît dès que la condition retombe 2 s.

### Écran 5 — Coach live

- Gauche (60 %) : carte (trace GPS du bateau), nord en haut
- Droite : cadence, V sol, gîte instantanée, pastille lien (`live` / `retard 8 s` / `hors ligne`)
- Bas : **Annoter** gros — 1 tap écrit un événement `t=now` (texte optionnel après, pas obligatoire au tap)
- Max 3 chips d'alerte (mêmes règles que le rameur)
- Aucun bouton « envoyer au bateau »

### Écran 6 — Coach replay

- Timeline horizontale de la séance (play / pause / ±10 s)
- 2 courbes max au choix : cadence | V sol | gîte  (pas 13 traces)
- Marqueurs d'annotation sur la timeline
- Liste annotations à droite
- Comparer deux extraits : **écart brut** (`Δ cadence = +2`) sans verdict

### Écran 7 — Quai / fin de séance

Quatre chiffres seulement : durée, distance GPS, cadence moyenne, gîte RMS.

- État sync : `envoyé` / `en attente réseau`
- Partager au coach du club (lien session)
- Retour accueil

Pas de PDF labo, pas de bilan énergétique.

---

## 5. Extension autres bateaux (même pack)

Ne pas dessiner 7 écrans × 8 classes.

Règles :

- Écran 1 : Barreur actif si classe ∈ {`4+`, `8+`}
- Écran 3 / 5 : un **schéma bateau** 1 / 2 / 4 / 8 cases à la place du vide statut si `n_rowers > 1`
- Couleur d'une case = OK / décroche (cadence poste vs bateau) — seulement quand un capteur poste existe
- 1x : pas de schéma, on garde les pastilles

Stitch : fournir le schéma 1x (rien), 2x (2 cases), 8+ (8 cases + triangle barreur). Assez pour interpoler.

---

## 6. Capteurs — ce que l'UI a le droit de montrer

| Source | MVP 1x | Badge |
|---|---|---|
| GPS téléphone | oui | Mesuré |
| IMU téléphone (gîte, cadence approx.) | oui | Mesuré |
| BLE force / angle | slot vide | — |
| Modèle physique AvSim | **interdit** sur Club | (Maison seulement) |

Si un jour un chiffre vient du simulateur (démo sans bateau) : badge **Simulé** obligatoire, même typo que le web actuel.

Cadence IMU ≠ catch slip Kleshnev. **Ne pas** étiqueter « slip ».

---

## 7. Ton visuel

- Nautique instrument, pas dashboard SaaS
- Noir / gris charbon / un accent (jaune alertes, bleu live)
- Typo chiffres : tabulaire, largeur fixe
- Zones tactiles ≥ 48 dp (doigts mouillés)
- Aucune pub, aucun onboarding de 8 slides
- Langue : français. Mots courts.

Référence d'ambiance : afficheur de bateau / horizon cockpit, pas Strava.

---

## 8. Hors scope Stitch (ne pas inventer d'écran)

- Analyste / Observabilité / Sensibilité / Pareto
- Réglage `F_peak`, YAML, constructeur de coque
- Haptique Coup+1 (plus tard)
- LoRa, station de rive, anémomètre
- Compte club complexe, paiement
- 3D bateau

---

## 9. Prompt Stitch (bloc à coller)

```
App native aviron, nom DataR0w. Smartphone fixé au cale-pied en PAYSAGE.
3 profils : Rameur, Coach, Barreur (grisé sur skiff).
7 écrans : (1) choix profil (2) pré-session + tare gîte 30s (3) rameur live
3 colonnes cadence/V/distance + horizon gîte + pastilles capteurs
(4) même écran + 1 bandeau alerte (5) coach live carte + annoter
(6) coach replay 2 courbes + annotations (7) résumé quai 4 chiffres.
Fond noir, gros chiffres blancs, contraste soleil, pas de sidebar,
pas de watts, pas de settings labo. Français. iPhone 15 paysage.
Prévoir variante schéma 2 cases et 8 cases pour plus tard.
```

---

## 10. Lien repo

| Fichier | Rôle |
|---|---|
| `STATE.md` | Vérité physique simulateur — ne pas la copier dans l'app club |
| `docs/ETAT-DATAROW.md` | Trois chantiers |
| `docs/MANQUES.md` | Trous données / hardware |
| `docs/avsim-personas-temps-reel.md` | Conception longue — ce brief **réduit** au MVP |
| `web/` | Prototype desktop — **ne pas** cloner pixel à pixel |
