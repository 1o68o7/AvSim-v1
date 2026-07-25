# DataR0w — état des lieux

*24 juillet 2026 · inventaire vérifié, pas récité de mémoire*

---

## 0. Trois chantiers, trois maturités très différentes

| Chantier | Contenu | Maturité |
|---|---|---|
| **A — Hardware télémétrie** | prototype embarqué, capteurs, câblage | spec complète, **en pause volontaire** |
| **B — Simulateur (avsim)** | sélection de capteurs par simulation | code démarré, **un bug bloquant non corrigé** |
| **C — Couche produit** | dashboards rameur/team/coach | conçu, **rien codé** |

---

## 1. Chantier A — Hardware de télémétrie embarquée

Le tout premier travail de ce projet, mis en pause dès qu'on a décidé de
simuler avant d'acheter.

| Document | Contenu |
|---|---|
| `prototype-telemetrie-aviron-huit.md` | spec v0.2 complète : architecture bus CAN, 8 nœuds ESP32-S3 + concentrateur Pi 5, pods dorsaux, pipeline EKF |
| `V1-implantation-huit-vue-dessus.svg` | implantation capteurs sur le huit |
| `V5-chaine-donnees-telemetrie.svg` | flux de données, 3 canaux télémétrie |
| `branchement-noeud-de-poste.svg` / `branchement-systeme-central.svg` | schémas de câblage niveau broche |
| `netlist-fritzing-telemetrie.md` | 83 connexions numérotées |
| `panorama-concurrents-aviron.md` | 11 concurrents, brevets expirés, terrain FR vierge |
| `inventaire-datasets-aviron.md` (v1.1) | Concept2, Strava, Rowsandall, RACEMAP, études académiques ; Quiske analysé comme adjacent, pas concurrent frontal |

**BOM chiffrée** : ~2 550-3 000 € (huit complet) ou ~910 € (MVP, pods maison,
2 postes en force).

**Périmé, volontairement** : la net-list a été auditée et présente 5 trous
connus (passerelle ESP32 manquante pour les pods, canal LoRa absent, WiFi
externe absent, PPS non distribué aux nœuds, terminaison 120 Ω à déplacer si
la station de rive remplace l'anémomètre de proue T0) — plus l'actionneur
haptique du chantier C, qui s'ajoute maintenant à la nomenclature. Refonte
reportée jusqu'à ce que le simulateur tranche le jeu de capteurs définitif :
retoucher le câblage maintenant serait du travail à jeter.

---

## 2. Chantier B — Simulateur de sélection de capteurs (avsim)

### 2.1 Données de référence — solides

| Donnée | État |
|---|---|
| Base de coques | **182 moules, 6 constructeurs** (Filippi, Empacher, Hudson, WinTech, Swift, Vespoli), 8 classes |
| Anthropométrie | table De Leva (1996), somme vérifiée à 100,0000 % |
| Coefficients de palette | recalés sur les repères mesurés de Caplan & Gardner (2007), domaine complet 0-180° — **approché**, les valeurs exactes ne sont publiées qu'en courbes non numérisées |
| Fichiers de classe | 8 fichiers YAML, mécanisme `hull_ref` (composite médian ou moule nommé) |
| Paramètres physiques | gelés dans `defaults.yaml`, chaque valeur sourcée |

### 2.2 Code — 1 010 lignes, statut retesté à l'instant

**Fonctionne** : conventions géométriques (5 tests sur 7), chargement des
paramètres, chaîne anthropométrique, hydrodynamique de palette et de coque,
intégration ODE, décomposition énergétique.

**Cassé — confirmé par un nouveau passage des tests il y a quelques minutes** :
la fermeture cinématique reste fausse. 2 tests échouent encore exactement
comme lors de la dernière session — le glissement de palette a le mauvais
signe et la mauvaise amplitude à mi-propulsion (`vx = +0,46` au lieu de
négatif). La cause est diagnostiquée et la solution spécifiée depuis le brief
v2 (§4.1 — fermeture pilotée par la force plutôt que par la cinématique), mais
**pas encore implémentée**. La correction de l'angle d'incidence à 0-180°
faite avec Caplan & Gardner n'a rien cassé, mais n'a pas non plus réglé ce
problème — ce n'était pas censé le faire, ce sont deux bugs indépendants.

**Autres dettes connues** :
- performance à 44 s par simulation, cible du brief < 1 s, leviers identifiés mais pas codés
- `n_rowers` codé en dur à 8 dans `defaults.yaml` — pas encore générique, pourtant requis pour simuler autre chose que le huit
- `dE_kinetic` calculé comme résidu de l'identité qu'il est censé vérifier, donc son test est trivialement vrai

### 2.3 Spécifié, rien codé

`envelope.py`, `boat_class.py`, `sensors/` (12 modèles de bruit),
`estimation/ekf.py`, `analysis/` (Sobol, observabilité, détectabilité,
Pareto), `api/` + `web/`, et le mode `avsim replay --realtime` proposé en fin
de dernière session.

---

## 3. Chantier C — Couche produit (personas)

`avsim-personas-temps-reel.md` — conception complète, rien codé :

- 3 fiches persona finalisées (Rameur, Team, Coach live + Coach replay)
- architecture haptique à deux niveaux (auto local vs équipage centralisé), avec budget de latence chiffré par cadence
- modèle de données pour les ordres vocaux annotés du coach
- extension proposée du mode Détectabilité pour évaluer la faisabilité temps réel par architecture

---

## 4. Décisions produit figées

- Multi-classes de bout en bout : 1x, 2x, 2−, 4x, 4−, 4+, 8+, 8x
- Rendu final en application web (FastAPI + React), locale
- Sélection constructeur + classe + gréement + gamme, via le mécanisme `hull_ref`
- Team = cockpit temps réel embarqué ; Coach = live en canot moteur (canal B) + replay post-séance
- Coup+1 : haptique dès le départ (couvre aussi les bateaux non barrés), vocabulaire à un seul motif pour la v1
- Bassins de référence envisagés : Bordeaux et Vichy (choix entre les deux non tranché)

## 5. Décisions en attente — le CSV n'est jamais revenu

`questions-simulateur-aviron.csv` (10 questions) a été transmis mais **jamais
retourné rempli**. Deux décisions produit ont été prises entre-temps par
échange direct (localisation du coach, modalité coup+1) mais elles ne
recouvrent pas les 10 questions du fichier. Statut réel :

| # | Question | Statut |
|---|---|---|
| Q01 | ordre de validation des classes | ouvert (mais les données coques couvrent déjà les 8 classes) |
| Q02 | périmètre de l'app (local / club / ligne) | ouvert |
| Q03 | fidélité du schéma de bateau (statique / animé / 3D) | ouvert |
| Q04 | origine des profils de force | ouvert |
| Q05 | rameurs identiques ou individualisés | ouvert |
| Q06 | couple : un angle ou deux | ouvert |
| Q07 | cotes réelles des bateaux du club | ouvert (partiellement comblé par les données constructeur) |
| Q08 | état de la station météo de rive | ouvert |
| Q09 | bassin de référence principal | ouvert (les deux envisagés, pas tranché) |
| Q10 | accès à un équipage pour la calibration | ouvert — **bloquant pour le bilan énergétique en watts absolus** |

---

## 6. Le prochain geste qui compte le plus

Tout le reste — capteurs virtuels, observabilité, application web, dashboards
persona — dépend d'un moteur physique juste. Or c'est précisément la pièce qui
reste cassée depuis deux sessions, pendant qu'on a avancé sur les données
constructeur et la conception produit.

**Avant toute nouvelle extension** : implémenter la fermeture pilotée par la
force (brief v2 §4.1). C'est un chantier de code pur, aucune dépendance
externe, spécifié en détail, et tant qu'il n'est pas fait, aucune sortie du
simulateur — même sur la donnée constructeur la plus solide — n'est fiable.
