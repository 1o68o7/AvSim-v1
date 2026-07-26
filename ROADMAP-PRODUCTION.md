# ROADMAP production — avsim / DataR0w

Ordre calé sur `brief-simulateur-v2.md` §11. Ne pas sauter d'étape :
une belle UI sur une physique fausse est le pire résultat possible.

## Phase 0 — Fermeture v1 — TERMINÉE (main `bfeb780`)

Voir `STATE.md`. `pytest tests/` 16/16, 8+ et 1x.

## Phase 1 — Tests de crédibilité (écrire d'abord, faire échouer)

| Fichier | Brief | Contenu |
|---|---|---|
| `tests/test_plausibility.py` | §9.2 | v_mean ±8 % `v_ref`, P/rameur, η, parts bilan, check_factor, slip — **par classe** via `boat_class=` |
| `tests/test_class_scaling.py` | §2.4 / §9.3 | `k_drag` skiff ∈ [3,0 ; 3,6] ; P/rameur ∈ [420 ; 560] W sur les 8 classes |
| `tests/test_triangulation.py` | §9.4 | decomposition puissance dans la dispersion Atkinson / van Holst / Roosendaal |

**Bloquant triangulation** : table de référence absente (`docs/MANQUES.md` D6).
Écrire le test + le schéma `data/` attendu ; marquer skip explicite tant que
la table n'est pas sourcée — ne pas inventer les chiffres.

Critère de sortie Phase 1 : les trois fichiers existent ; plausibility et
class_scaling **échouent pour de vraies raisons physiques** (pas des imports
cassés) ; triangulation en skip documenté ou vert si data arrivée.

Ne pas avancer Phase 3+ tant que plausibility / scaling sont rouges
(sauf skip triangulation pour manque data).

## Phase 2 — Performance & diagnostic §9.2

| Item | Statut |
|---|---|
| Tabulation `com_x(θ)` (étape 2) | **fait** (`334da14`) |
| Bootstrap `u_eff` C2 sans clamp dur | ouvert (tentative F(0)=0,13 Fpeak échouée) |
| Diagnostiquer écart F_peak erg vs eau | ouvert — pistes `I_oar`, `k_drag`, pertes palette |
| Confrontor Catch Slip angulaire 3° (Kleshnev) | ouvert |

## Phase 3 — Enveloppe & classe (spec brief §3 / §2)

- `core/envelope.py` — contrôles a priori / a posteriori
- `core/boat_class.py` — si encore utile hors `params.load_class`

Spécifiés dans le brief, **pas écrits**.

## Phase 4 — Capteurs (`sensors/`)

Un capteur à la fois, chacun avec son test de bruit. Seulement après
plausibility / scaling verts (ou triage explicite du point ouvert §9.2).

## Phase 5 — Estimation (`estimation/ekf.py`)

Code partageable avec l'embarqué.

## Phase 6 — Analyse (`analysis/`)

Sobol → observability → detectability → Pareto.

## Phase 7 — Produit local (`io/`, `cli.py`, `api/`, `web/`)

Brief UI : `docs/brief-interface-utilisateur.md`.

| Item | Statut |
|---|---|
| API FastAPI (`/classes`, `/params`, `/validate`, `/simulate`, rôles) | **démarré** |
| UI Analyste 🟢 Bateau / Coup / Bilan / Équipage | **démarré** |
| UI Analyste 🟡 Capteurs / Observabilité / … | maquettes |
| Surface Produit (rejeu) | maquettes (replay CLI pas encore codé) |
| CLI `avsim` | pas commencé |

Note : Phase 1 (plausibility / scaling) reste ouverte ; l'UI marque les 6
classes smoke-only en **Bêta — non calibrée**.

## Phase 8 — Hardware / bus réel

Hors noyau simu ; inchangé.
