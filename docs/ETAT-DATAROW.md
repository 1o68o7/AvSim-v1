# DataR0w — état des lieux

*Révisé le 16 septembre 2026 · aligné sur `STATE.md` (snapshot physique 25–26 juillet 2026) et le code de `main` (`fb8621ff`).*

**Source de vérité pour la physique et les tests :** `STATE.md`, puis `ROADMAP-PRODUCTION.md`.  
Ce fichier est un inventaire des trois chantiers. S'il diverge de `STATE.md`, `STATE.md` gagne.

La version du 24 juillet 2026 est **périmée**. Elle décrivait encore une fermeture cinématique cassée, `envelope` / `sensors` / `api` / `web` « à écrire », et une couche produit « rien codé ». Tout cela a été dépassé entre le 25 et le 28 juillet.

---

## 0. Trois chantiers, trois maturités

| Chantier | Contenu | Maturité |
|---|---|---|
| **A — Hardware télémétrie** | prototype embarqué, capteurs, câblage | spec hors noyau simu, **en pause volontaire** (Phase 8) |
| **B — Simulateur (avsim)** | vérité terrain + sélection de capteurs | Phase 0 **close** ; limites 1DOF **documentées et gelées** |
| **C — Couche produit** | Rameur / Team / Coach live + replay | Phase 7 **démarrée** — prototype contre rejeu simulé |

Décision produit figée : aucune sortie du simulateur n'est une mesure. Badge **Simulé** obligatoire. Classes hors `8+` / `1x` : badge **Bêta — non calibrée**.

---

## 1. Chantier A — Hardware de télémétrie embarquée

Mis en pause dès qu'on a décidé de simuler avant d'acheter. Les documents de spec (bus CAN, ESP32-S3, Pi 5, net-list, BOM) ne vivent **pas** dans ce dépôt.

**BOM historique** : ~2 550–3 000 € (huit complet) ou ~910 € (MVP, 2 postes en force).

La net-list avait 5 trous connus (passerelle pods, LoRa, WiFi externe, PPS, terminaison 120 Ω) plus l'actionneur haptique. **Ne pas retoucher le câblage** tant que le simulateur n'a pas tranché le jeu de capteurs : ce serait du travail à jeter. Phase 8 inchangée.

---

## 2. Chantier B — Simulateur

### 2.1 Données de référence — solides

| Donnée | État |
|---|---|
| Base de coques | 182 moules, 6 constructeurs (Filippi, Empacher, Hudson, WinTech, Swift, Vespoli), 8 classes |
| Anthropométrie | De Leva (1996), somme 100 % |
| Coefficients de palette | Caplan & Gardner (2007), domaine 0–180° — **approché** |
| Fichiers de classe | `params/classes/{1x,2-,2x,4+,4-,4x,8+,8x}.yaml` + `hull_ref` |
| Paramètres | gelés, chaque valeur sourcée (`src: L / E / N`) — ne pas retoucher pour « faire plus joli » |

### 2.2 Code — Phase 0 close (25 juillet)

**Fait (voir table `STATE.md`)**

- Chargeur multi-classes : `load_class` / `load_params(boat_class=)`, `n_rowers` dynamique, `m_cox_kg=0` si non barré
- Fermeture **pilotée par la force** : `I_oar·θ'' = M_poignée + M_palette` (brief §4.1 — **n'est plus le bug bloquant**)
- `F_h(u)` Kleshnev/BioRow : `F_u_peak=0,40`, `F_u_rise_70=0,17`, `F_high_width=0,35`
- `E_rower_J` indépendant (`P = -L_in·F·ω`) ; sauts de KE déduits ; identité aviron OK
- Fenêtres de retour réétagées ; pic inertiel faux éliminé
- Tabulation `com_x(θ)` à l'init de `Crew`
- `envelope.py`, `boat_class.py` écrits ; fixtures `8+` / `1x`

Compte tests cité par `STATE.md` (suite physique historique) : **30 passed, 1 skipped** sur `8+` et `1x`. La suite a depuis grandi (API, replay, coaching, observabilité) — relancer `pytest tests/` pour le chiffre courant.

**Limites 1DOF — réelles, comprises, gelées (26 juillet)**

Pas des bugs de seuil. Ne pas rouvrir un correctif physique sur ces leviers.

| Grandeur | Modèle | Cible §9.2 | Note |
|---|---|---|---|
| `v_mean` (8+) | ~4,91–5,13 m/s | 5,78–6,78 | trop bas |
| `η_blade` | ~0,62 | 0,75–0,85 | pas de contrôle d'incidence palette |
| `check_factor` | ~3,1–3,2 | 0,50–0,80 | empilement CdM × warp Hermite ; levier largeur épuisé |
| `power_instantaneous` | 2,1–2,8 kW | butée 1,5 kW | conséquence de `F_peak=1100 N` |
| `F_peak` | 1100 N | 500–700 N sur l'eau | aucun cycle viable dans la plage sourcée |

Gate Phase 5 : `is_admissible(..., ignore_known_1dof_limits=True)` exclut η + `P_inst`. Même là : **7/8 classes REJECT** ; seule **2x** passe.

Le modèle reste valide pour **comparer des configs capteurs**. Les watts et le cavalement absolus ne sont pas des lectures d'entraînement.

**Encore ouvert côté physique (pas un retour en arrière)**

- Bootstrap attaque : clamp `u_eff = max(u_geom, u_rise_70)` conservé
- `drive_fraction = 0,42` fixe (Cerne 2013 non branché)
- Catch slip angulaire ≈ 3° : paramètre présent, repère non confronté
- Phase 1 : `test_plausibility` / `test_class_scaling` en dette ; triangulation D6 en skip

### 2.3 Couches autrefois « à écrire » — état réel

| Module | État |
|---|---|
| `core/envelope.py`, `core/boat_class.py` | écrits |
| `sensors/` | 13 capteurs virtuels + bus — code là ; UI Analyste encore maquette |
| `estimation/ekf.py` | EKF minimal `[V, x_com]` — servi par Mode C 2x |
| `analysis/` | Observabilité (Mode C) 2x seulement ; Sobol / Mode D absents |
| `api/` + `web/` | FastAPI + React/Vite/Plotly, deux surfaces |
| `avsim replay --realtime` | CLI + `GET /api/replay/stream` (SSE) |

Mode C : `data/observability_2x_pilot.json`, vue `/analyst/observabilite`. **Non représentatif** des 7 autres classes.

---

## 3. Chantier C — Couche produit

Conception : `docs/avsim-personas-temps-reel.md` + `docs/brief-interface-utilisateur.md`.

**Codé (prototype contre rejeu simulé, principalement 2x)**

- Surface Analyste : Bateau / Coup / Bilan / Équipage ; Capteurs / Sensibilité / Détectabilité = maquettes honnêtes (graphe vide, pas de placeholder « réaliste »)
- Surface Produit : Rameur, Team (4 quadrants), Coach live (annotations → table `events`), Coach Replay (`StrokeGeometry`, nesting, compare avant/après)
- `EventStore` SQLite local (limite Render Free : pas de partage inter-instances)
- Comparaisons Coach : **écart brut seulement** — Mode D absent, aucun seuil inventé

Ce n'est pas un outil d'entraînement. C'est un banc d'UI alimenté par le simulateur, en attendant la Phase 8.

---

## 4. Décisions produit figées

- Multi-classes : 1x, 2x, 2−, 4x, 4−, 4+, 8+, 8x
- App web FastAPI + React (local et démo Render)
- Sélection constructeur + classe via `hull_ref`
- Team = cockpit temps réel ; Coach = live canot (canal B) + replay
- Coup+1 : haptique dès le départ, un seul motif v1
- Bassins envisagés : Bordeaux et Vichy — **non tranché**

## 5. Décisions en attente — le CSV n'est jamais revenu

`docs/questions-simulateur-aviron.csv` (10 questions) : toujours ouvert.

| # | Question | Statut |
|---|---|---|
| Q01 | ordre de validation des classes | ouvert (`8+`/`1x` validées pour le badge ; Mode C = 2x seulement) |
| Q02 | périmètre de l'app (local / club / ligne) | ouvert |
| Q03 | fidélité du schéma de bateau | ouvert (schéma 2D + pose Python existent) |
| Q04 | origine des profils de force | ouvert (`F_h(u)` paramétrique Kleshnev) |
| Q05 | rameurs identiques ou individualisés | ouvert |
| Q06 | couple : un angle ou deux | ouvert |
| Q07 | cotes réelles des bateaux du club | partiellement comblé par le catalogue constructeur |
| Q08 | station météo de rive | ouvert |
| Q09 | bassin de référence | ouvert |
| Q10 | accès équipage pour calibration | ouvert — **bloquant pour les watts absolus** |

---

## 6. Le prochain geste qui compte

La fermeture §4.1 n'est plus le chemin critique. Les diagnostics η / `check_factor` / `P_inst` sont clos.

Ordre utile maintenant :

1. Ne pas retoucher `F_peak`, η ou `check_factor` dans le 1DOF.
2. Soit accepter le 1DOF et pousser Phase 4 (brancher `sensors/` dans l'UI Analyste) **sur 2x**.
3. Soit un 2e DDL d'incidence palette si l'objectif redevient les watts absolus.
4. Répondre au CSV (surtout Q02 et Q10) avant tout hardware.
5. D3 (décélération libre) reste le seul chemin vers un bilan en watts réels — voir `docs/MANQUES.md`.
