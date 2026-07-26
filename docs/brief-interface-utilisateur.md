# Brief interface utilisateur — DataR0w

*25 juillet 2026 · à destination de Cursor · Phase 7 de ROADMAP-PRODUCTION.md*
*Mis à jour après revue de PR #7 (première itération livrée)*

---

## État au 25/07 — ce qui existe déjà, vérifié dans le code

PR #7 mergée sur `main` (`447d5cc`). Vérifié directement dans le dépôt,
pas seulement rapporté :

- **API** (`src/avsim/api/`, pas un dossier `api/` à la racine — écart
  mineur sans conséquence par rapport à la structure du brief §10 initial) :
  `/classes`, `/hull_moulds`, `/params/{code}`, `/validate`, `/simulate`,
  `/jobs/sweep` (stub 501, Phase 5). Rôles via en-tête `X-DataR0w-Role`,
  `analyst_only()` réellement appliqué sur `/params`, `/validate`,
  `/jobs/sweep` — vérifié dans le code, pas juste déclaré.
- **Web** (`web/`, React+Vite) : sélection de rôle, surface Analyste avec
  Bateau/Coup/Bilan/Équipage (Coup et Bilan encore à finir de brancher),
  badges Simulé + Validée/Bêta déjà en place. Surface Produit en stubs.
- **`BoatSchematic.tsx`** : vue de dessus 1-8 postes, pointe/couple,
  fonctionne. Voir §4.1 ci-dessous pour la distinction avec le composant
  qui reste à faire.

**Limite connue et acceptée pour l'instant** : le contrôle de rôle par
en-tête HTTP empêche un clic accidentel dans la mauvaise surface, mais
n'importe quel client peut se déclarer `product` et lire des routes
Analyste — ce n'est pas une vraie séparation d'accès, seulement une
convention d'interface. Sans conséquence tant que l'outil reste à usage
interne ; à revoir avant toute exposition au-delà de ce cercle.

---

## 0. Principes directeurs — à lire avant d'écrire une ligne

**Deux surfaces, un seul backend, séparation stricte.** Analyste (moi/toi,
qui décide des capteurs à acheter) et Produit (rameur/team/coach, qui

utilise le système sur l'eau) ne partagent aucune vue, mais consomment la
même API FastAPI. Ne jamais mélanger les deux dans un même composant.

**Rien de fictif à l'écran.** Aucune vue ne doit jamais afficher une donnée
de capteur simulée comme si elle venait d'un vrai capteur, ni une sortie de
simulation présentée comme une mesure. Toute vue alimentée par le
simulateur porte un badge visuel constant : **« Simulé »**. Toute vue
alimentée par un vrai flux (Phase 8, matériel) porte **« Mesuré »**. Ce
n'est pas un détail cosmétique, c'est la règle qui a gouverné tout le
chantier physique cette semaine — elle continue côté interface.

**Statut de validation par classe, visible partout où une classe se
choisit.** Vérifié au 25/07 :

| Classe | Statut | Base |
|---|---|---|
| `8+` | **Validée** | Suite complète (30 tests), Phase 2 examinée en détail |
| `1x` | **Validée** | Suite complète, fixtures dédiées |
| `2x`, `2-`, `4x`, `4-`, `4+`, `8x` | **Test de fumée seulement** | Tourne sans exception, ordres de grandeur raisonnables — pas de calibration `test_class_scaling.py` (pas encore écrit) |

Tant que `test_class_scaling.py` n'existe pas, les 6 classes en test de
fumée s'affichent avec un badge **« Bêta — non calibrée »**, visible sur
le sélecteur de bateau ET dans l'en-tête de chaque vue qui en dépend. Ne
jamais les présenter à égalité avec `8+`/`1x`.

**Ce qui est constructible maintenant vs plus tard.** Ce brief couvre
l'intégralité de l'interface cible, mais une partie dépend de backends qui
n'existent pas encore (Phases 4, 5, 6 de la roadmap). Chaque section
ci-dessous indique son statut :

- 🟢 **Constructible maintenant** — données déjà disponibles (moteur physique)
- 🟡 **Bloqué** — attend un backend d'une phase antérieure, indiqué explicitement
- Construire les 🟢 d'abord, poser les 🟡 en maquette avec état "à venir" explicite plutôt que de les omettre — pour que la navigation finale soit stable dès le premier déploiement.

**Stack** (brief §10, confirmé) : FastAPI (backend), React + Vite + Plotly
(frontend). Composant central : schéma de bateau adaptatif, testé sur les
8 classes (couple ET pointe), qui réapparaît dans presque toutes les vues.

---

## 1. Architecture d'ensemble

```
┌─────────────────────────────────────────────────────┐
│  Écran de connexion / sélection de rôle              │
│  → Analyste          → Produit (Rameur/Team/Coach)   │
└─────────────────────────────────────────────────────┘
         │                          │
   ┌─────▼─────┐              ┌─────▼──────┐
   │ SURFACE   │              │ SURFACE    │
   │ ANALYSTE  │              │ PRODUIT    │
   │ (§2)      │              │ (§3)       │
   └─────┬─────┘              └─────┬──────┘
         │                          │
         └──────────┬───────────────┘
                     ▼
         ┌───────────────────────┐
         │   API FastAPI          │
         │  /classes /params      │
         │  /validate /simulate   │
         │  /jobs/sweep /export   │
         └───────────┬───────────┘
                     ▼
         ┌───────────────────────┐
         │  avsim.core (le moteur)│
         └───────────────────────┘
```

Aucune route ne doit permettre à un composant Produit d'appeler
directement `/jobs/sweep` ou d'afficher `/params` brut — ces routes sont
réservées à la surface Analyste. La séparation se fait au niveau de
l'API (permissions par rôle), pas seulement dans le routing frontend.

---

## 2. Surface Analyste

### 2.1 Vue « Bateau » 🟢

**But** : choisir une configuration à simuler.

**Composants** :
- Sélecteur de classe (8 options), chaque option affichant son badge de
  statut (§0) — les 6 classes bêta ne sont pas masquées, juste marquées.
- Sélecteur constructeur/moule (`hull_ref`) : liste déroulante alimentée
  par `data/hull_moulds.csv`, avec option « composite (médiane) » par
  défaut — c'est l'option `geometry_source: composite` déjà existante
  dans le chargeur, à exposer telle quelle, pas à réinventer.
- Panneau de paramètres, groupé par section YAML (`crew.*`, `rig.*`,
  `technique.*`, `hull.*`...), chaque champ affichant sa source si le
  YAML la documente en commentaire (`src: L/E/N` + référence). Un champ
  sans source visible affiche **« non sourcé »** en orange — jamais
  silencieux.
- Rendu de `BoatSchematic` (composant partagé, §4.1a), mis à
  jour en direct quand la classe change.

**Actions** :
- « Lancer une simulation » → appelle `/simulate`, redirige vers Vue Coup.
- « Réinitialiser aux valeurs de la classe » (annule les surcharges locales).

**États** :
- Chargement des classes (skeleton sur le sélecteur).
- Erreur réseau (bandeau, pas de blocage de l'UI).

### 2.2 Vue « Coup » 🟢

**But** : visualiser un coup individuel — c'est la version interactive du
diagramme de référence biomécanique construit cette semaine
(`reperes-biomecaniques-coup.svg`), pas un nouveau design à inventer.

**Composants** :
- Graphique Plotly double piste (calqué sur le diagramme SVG déjà
  produit) : courbe de force en haut, angle de pelle en bas, axe commun
  `u` (fraction de course). Curseur synchronisé entre les deux pistes.
- `StrokeGeometry` (§4.1b) avec l'aviron et le corps du rameur animés à
  la position du curseur — c'est précisément le composant que ce brief
  spécifie en détail au §4.1b.
- Sélecteur de coup (dernier coup du régime établi par défaut, mais
  navigable coup par coup si l'utilisateur veut inspecter la convergence).
- Bandeau de repères sourcés superposables en overlay (Catch Slip ≈3°,
  plateau F>70%Fmax, pic à u=0,40...) — activable/désactivable, jamais
  affiché par défaut sans que l'utilisateur l'ait demandé (pour ne pas
  laisser croire que ce sont des mesures du coup affiché).

### 2.3 Vue « Bilan » 🟢

**But** : les 6 grandeurs de plausibilité (§9.2) qu'on a suivies toute la
semaine, enfin visibles sans lire une réponse de Cursor.

**Composants** :
- Cartes métriques : `v_mean`, `v_min`, `v_max`, `check_factor`,
  `T_drive`, `η_blade` — chaque carte affiche la valeur, la cible §9.2
  sourcée, et un indicateur vert/orange/rouge selon l'écart.
- Décomposition énergétique (E_prop, E_blade_loss, E_oar_ke_jump — les
  termes du bilan qu'on a débogués cette semaine), en graphique à barres
  empilées.
- Note de contexte fixe et non masquable si `η_blade` est hors cible :
  rappel bref que l'écart est connu et documenté (lien vers
  `ROADMAP-PRODUCTION.md` §« Piste différée »), pas une alerte d'erreur.

### 2.4 Vue « Équipage » 🟢

**But** : le détail par poste — utile pour repérer un déséquilibre
d'équipage une fois les capteurs réels branchés (Phase 8), mais déjà
exploitable sur les grandeurs simulées.

**Composants** :
- Tableau par poste (1 à 8 lignes selon la classe) : phase offset,
  contribution de puissance individuelle.
- Alerte visuelle si `n_rowers` de la classe est incohérent avec le
  nombre de lignes affichées (garde-fou contre une régression du
  chargeur, silencieuse sinon).

### 2.5 Vue « Capteurs » 🟡 — bloquée sur Phase 4

Maquette uniquement : liste des 13 capteurs (déjà documentés dans le
dossier hardware), avec mention explicite **« modèles de bruit non
implémentés — Phase 4 de la roadmap »**. Ne pas construire de vraie
logique tant que `sensors/` n'existe pas.

### 2.6 Vue « Observabilité » 🟡 — bloquée sur Phase 5

**C'est le livrable central du projet** (brief §14) — la vue qui répond
aux questions d'achat de capteurs. Maquette avec front de Pareto
coût/erreur en placeholder, légendé **« nécessite le mode Observabilité,
pas encore implémenté »**. Ne pas simuler de fausses données pour
« montrer à quoi ça ressemblera » — un graphique vide légendé vaut mieux
qu'un graphique qui a l'air réel et ne l'est pas.

### 2.7 Vue « Sensibilité » 🟡 — bloquée sur Phase 5 (Sobol)

Même traitement que 2.6.

### 2.8 Vue « Détectabilité » 🟡 — bloquée sur Phase 5

Même traitement que 2.6.

---

## 3. Surface Produit

Toutes les vues de cette section sont 🟡 tant que le matériel réel
n'existe pas (Phase 8) — mais elles doivent être **construites et
testables dès maintenant** contre le simulateur en mode rejeu, via
`avsim replay --realtime` (déjà spécifié dans `avsim-personas-temps-reel.md`,
pas encore codé). C'est la raison d'être de ce mode : prototyper l'UX sur
des données simulées rejouées à la cadence réelle, sur le même
composant qui basculera sur le flux matériel sans modification quand il
existera. Construire cette surface contre le simulateur n'est donc pas
prématuré — c'est le chemin prévu.

### 3.1 Rameur

**But** : ce que le rameur voit à son poste (probablement téléphone fixé
au pied de nage, ou montre).

**Composants** :
- Feedback coup+1 haptique — pas d'écran nécessaire pour cette fonction
  elle-même, mais une vue de calibration/configuration existe : intensité,
  activer/désactiver, niveau (auto-local vs équipage, cf. document
  personas).
- Écran minimal optionnel : cadence actuelle, distance parcourue,
  timing relatif à l'équipage (retard/avance en ms).

### 3.2 Team (cockpit temps réel embarqué)

**But** : dashboard embarqué, canal A, visible par toute l'équipe pendant
l'effort (probablement un écran fixé au bateau, pas un téléphone individuel).

**Composants** :
- Vue unique, gros caractères, lisible en mouvement : cadence, vitesse,
  cap, distance/temps restant si un parcours est défini.
- Indicateur de synchronisation d'équipage (le même conçu pour le
  feedback coup+1) sous forme visuelle en plus de l'haptique.

### 3.3 Coach live (canot moteur, canal B)

**But** : suivi temps réel depuis l'embarcation du coach, décidé comme
canal séparé du bateau. Même socle de données que Team, densité plus
riche — un état par rameur (force, timing, signaux haptiques déclenchés),
pas seulement 3 chiffres agrégés, actualisé à 0,3-1 s (canal B, moins
strict que la synchro inter-rameurs).

**Composants** :
- Vue multi-métriques par poste : force, timing, alerte de synchro,
  `check_factor` en direct (signal du simulateur en mode rejeu, badge
  Simulé permanent).
- Bouton d'annotation vocale timecodée — enregistre un événement dans la
  table `events` (schéma exact ci-dessous), consultable en Coach Replay.
- Contrainte d'affichage : soleil, mouvement — mêmes limites de lisibilité
  qu'en bateau, ne pas supposer un grand écran stable.

### 3.4 Coach Replay (post-séance)

**But** : diagnostiquer les pertes, suivre la progression, **relier les
ordres donnés à leur effet** — l'écran le plus exigeant des trois, où une
valeur non signalée comme incertaine coûte le plus cher (un coach ne doit
jamais changer une composition d'équipage sur un chiffre présenté comme
sûr alors qu'il ne l'est pas).

**Point d'entrée** : vue d'équipage (carte de chaleur des écarts par
poste) → clic sur un poste → vue Rameur de ce rameur.

**Composants** :
- Vue Coup (réutilise `StrokeGeometry`, §4.1b — même composant, pas une
  réimplémentation) avec les annotations vocales du coach superposées sur
  la timeline.
- Timeline annotée : ordres vocaux horodatés, table `events` :

```
events
  event_id       identifiant
  t_utc          horodatage absolu (horloge du téléphone du coach, GPS/NTP)
  source         'coach_voice' | (extensible)
  audio_ref      référence au clip audio, optionnel
  transcript     texte, optionnel (transcription locale, module séparé, non bloquant)
  tag            catégorie manuelle ou déduite ('longueur', 'cadence', 'relax'...)
  session_id     clé de jointure vers la séance
```

  Précision de synchronisation requise : à la seconde, pas la milliseconde
  (contrairement à la synchro inter-rameurs) — l'horloge du téléphone du
  coach suffit, aucun matériel dédié nécessaire.

- Clic sur un ordre → comparaison avant/après sur la métrique choisie
  (longueur d'arc, cadence, décalage de phase) sur une fenêtre de N coups.

**Dépendance non résolue, à traiter honnêtement plutôt qu'à ignorer** :
la spec d'origine (document personas §5.2) prévoit que le seuil jugeant
si un écart avant/après est réel ou du bruit soit **celui calibré par le
mode Détectabilité du simulateur** (Phase 5, Mode D) — qui n'existe pas
encore (Phase 5 bloquée à 87,5 % de rejet d'enveloppe, cf. `STATE.md`).
**Ne pas inventer un seuil de substitution.** Afficher l'écart brut
avant/après sans validation statistique, avec une mention explicite
« signification non calibrée — Mode D non disponible » plutôt qu'un
seuil silencieusement approximatif. Basculer vers le vrai seuil le jour
où Mode D existe, sans changer l'interface.

---

## 4. Composants partagés

### 4.1 Deux composants distincts — pas un seul « schéma de bateau »

La version précédente de ce brief désignait un composant unique sous ce
nom pour des besoins en réalité différents. Corrigé après la première
itération (PR #7) : deux composants séparés.

**4.1a — `BoatSchematic` (déjà fait, garder tel quel)**

Vue de dessus, 1 à 8 postes, pointe/couple avec alternance de côté
correcte. Sert d'aperçu de configuration — Vue Bateau, Vue Équipage,
Team. Ne représente pas la biomécanique du coup, ce n'est pas son rôle.
Aucune modification nécessaire.

**4.1b — `StrokeGeometry` (à construire, pour Vue Coup et Coach Replay uniquement)**

Vue latérale animée du rameur + aviron + coque, pilotée par `u` (fraction
de course, 0 à 1). Doit reprendre **exactement** la géométrie déjà
calculée pour `vue-sagittale-rameur-aviron.svg` (position attaque/dégagé,
`theta_catch`/`theta_finish`, cinématique inverse cheville→genou→hanche→
épaule→main) — même source de vérité, pas un second calcul divergent.

Concrètement : exposer cette géométrie via un endpoint serveur
(`/api/pose?boat_class=X&u=0.3`) qui renvoie les coordonnées déjà
calculées côté Python, plutôt que de réimplémenter les formules d'IK en
TypeScript. Un seul calcul de géométrie, pas deux susceptibles de
diverger — la même discipline qui a gouverné tout le chantier physique
cette semaine (ne jamais laisser deux chemins de calcul indépendants
produire silencieusement des résultats différents, cf. le
`geometry_mismatch` déjà documenté dans `body.py`).

**Les deux composants, testés explicitement sur les 8 classes avant
d'être considérés finis** — y compris les 6 en statut bêta, pour vérifier
que le rendu ne casse pas même si la physique sous-jacente n'est pas
calibrée.

### 4.2 Badge de statut (validé / bêta / simulé / mesuré)

Composant unique, réutilisé partout où une donnée ou une classe a besoin
d'un statut de confiance visible (§0). Ne pas laisser chaque vue
réinventer sa propre pastille de couleur.

### 4.3 Indicateur de calcul en cours

Le temps de simulation n'est pas encore sous la seconde (Phase 2 de la
roadmap partiellement faite — tabulation `com_x(θ)` confirmée, cible
finale pas encore mesurée). Tant que ce n'est pas confirmé sous la
seconde, toute action qui déclenche `/simulate` doit afficher un
indicateur de progression honnête, pas un spinner générique qui laisse
croire à une réponse instantanée.

---

## 5. États et erreurs, systématiques sur toute vue 🟢

- **Chargement** : squelette, jamais un écran blanc.
- **Erreur réseau** : bandeau non bloquant, action de retry.
- **Classe bêta sélectionnée** : bandeau permanent, pas une alerte
  ponctuelle qu'on peut fermer et oublier.
- **Simulation en cours > 5 s** : indicateur de progression avec estimation
  si possible, pas un simple spinner.
- **Résultat hors cibles §9.2** : jamais une erreur — une information
  neutre, cohérente avec la Vue Bilan (§2.3).

---

## 6. Ordre de construction recommandé

1. ~~Composants partagés (§4)~~ — `BoatSchematic` fait ; `StrokeGeometry`
   (§4.1b) reste à construire, priorité immédiate
2. ~~Vue Bateau (§2.1)~~ — faite
3. Finir de brancher Vue Coup (§2.2) sur `StrokeGeometry` une fois
   construit, et Vue Bilan (§2.3) — les deux sont amorcées mais pas
   terminées d'après la revue de PR #7
4. Vue Équipage (§2.4)
5. Surface Produit (§3) en mode rejeu (`avsim replay --realtime`) —
   encore en stubs
6. Vues Capteurs/Observabilité/Sensibilité/Détectabilité (§2.5-2.8) —
   passent de maquette à réel au fur et à mesure que les Phases 4 et 5
   avancent, pas toutes d'un coup

---

## 7. Ce qui bloque explicitement le passage en réel

| Vue | Bloquée par | Statut au 25/07 |
|---|---|---|
| Capteurs | `sensors/` (Phase 4) | pas commencé |
| Observabilité, Sensibilité, Détectabilité | `analysis/` (Phase 5) | pas commencé |
| Team/Coach avec vrai flux matériel | Hardware (Phase 8) | en pause, bloqué sur Q10 (accès équipage) |
| Toute vue avec simulation < 1 s perçue comme instantanée | Performance (Phase 2) | tabulation faite, cible finale pas mesurée |
| Sélecteur 8 classes à égalité | `test_class_scaling.py` (Phase 1) | pas écrit |

Rien de tout ça n'empêche de commencer à construire — c'est précisément
pour ça que chaque section ci-dessus est marquée 🟢/🟡 plutôt que
listée sans distinction.
