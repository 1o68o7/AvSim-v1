# Ce qui manque

*Consolidation initiale : 24 juillet 2026.  
Révisé le 16 septembre 2026 pour coller à `STATE.md` (25–26 juillet) et au code de `main`.*

Complète le brief v2.0. Ne plus lire la §6 / §8 de juillet comme un backlog actif : P1–P4 et les couches `envelope` / `api` / `web` sont écrites.

---

## 0. Ce qui est acquis

**Base de coques : close.** 182 moules, 6 constructeurs (Filippi, Empacher,
Hudson, WinTech, Swift, Vespoli), 8 classes. Le huit de pointe s'appuie sur
17 moules lourds de 6 constructeurs, médiane 17,42 m, étendue 82 cm. Cette
médiane n'a pas bougé de plus de 2 cm sur les trois derniers ajouts de
constructeur : la géométrie de référence est stable, inutile d'en chercher un
septième.

**Acquis également :** masses de coque (WinTech, minima réglementaires
confirmés, gamme club), gréement (Filippi order form), avirons (Empacher),
anthropométrie (De Leva).

**Acquis depuis le 25 juillet (n'était pas vrai le 24) :**

- Fermeture pilotée par la force (brief §4.1)
- `envelope.py`, `boat_class.py`
- `E_rower_J` indépendant ; identité aviron
- Chargeur multi-classes, `n_rowers` dynamique
- API FastAPI + UI React (deux surfaces)
- Replay SSE + EventStore
- Mode C Observabilité **2x seulement**

---

## 1. Bloquants physique — statut 16 septembre 2026

| # | Item | État au 24/07 | État réel |
|---|---|---|---|
| P1 | Fermeture pilotée par la force (§4.1) | mauvaise fermeture | **clos** — `I_oar·θ'' = M_poignée + M_palette` |
| P2 | Module d'enveloppe (§3) | pas écrit | **clos** — `core/envelope.py` |
| P3 | Performance < 1 s (mesuré 44 s) | leviers identifiés | **partiel** — `max/min` + tabulation `com_x(θ)` ; chiffre 44 s à re-mesurer |
| P4 | `dE_kinetic` indépendant | résidu → test trivial | **clos** — `E_rower_J` hors circularité ; sauts de KE déduits |

Ces quatre-là ne sont plus le chemin critique.

**Limites 1DOF restantes (pas des P à « corriger » dans le même modèle) :**
voir `STATE.md` — `η_blade` ~0,62, `check_factor` ~3,1, `F_peak=1100 N` /
`P_inst` hors butée. Diagnostics clos le 26 juillet. Gate
`ignore_known_1dof_limits=True` : seule la **2x** passe l'enveloppe.

Encore ouvert, autre nature :

- bootstrap attaque (clamp `u_eff` conservé)
- `drive_fraction` fixe à 0,42
- catch slip angulaire 3° non confronté
- Phase 1 (`test_plausibility`, `test_class_scaling`, triangulation skip D6)

---

## 2. Bloquants données — introuvables en catalogue

Inchangés. Toujours vrais.

| # | Manque | Pourquoi c'est bloquant | Comment l'obtenir |
|---|---|---|---|
| D1 | Longueur de flottaison | entre dans Re, donc C_f | estimée à 0,986·LOA (catégorie N) — acceptable |
| D2 | Surface mouillée | facteur direct de la traînée | estimée par loi d'échelle — acceptable en relatif |
| D3 | Coefficient de traînée réel | échelle absolue du bilan | **essais de décélération libre** |
| D4 | CdA aérodynamique | 60 % d'incertitude sur 5–10 % du bilan | essais + anémomètre, ou accepter l'incertitude |
| D5 | Coefficients de palette mesurés | fichier actuel = approximation | Caplan & Gardner (2007), courbes à numériser |
| D6 | Table de triangulation Atkinson / van Holst / Roosendaal | test de crédibilité central | article publié — **ne pas inventer** ; skip documenté |

**D3 est le vrai verrou pour les watts absolus.** Sans lui le dashboard
entraîneur plafonne à un indice relatif. Deux sorties suffisent, ça demande
un équipage (Q10).

Le sweep `k_drag` × `F_peak` du 26 juillet écarte l'hypothèse « baisser
`k_drag` dans la bande sourcée règle v_mean / η / cf ». D3 reste néanmoins
le seul ancrage terrain de l'échelle de traînée.

---

## 3. Bloquants humains

| # | Manque | Question CSV |
|---|---|---|
| H1 | Profils de force à la poignée (paramétrique ou Concept2 réel) | Q04 — aujourd'hui : `F_h(u)` Kleshnev |
| H2 | Masses et tailles réelles de l'équipage | Q05 |
| H3 | Accès équipage pour les essais de calibration | Q10 |

---

## 4. Bloquants environnement

| # | Manque | Question CSV |
|---|---|---|
| E1 | Traces de vent réelles à la résolution du coup | Q08 (station de rive) |
| E2 | Modèle de courant du bassin retenu | Q09 (Bordeaux ou Vichy) |

E1 tranche « anémomètre embarqué ou station de rive ». AROME 1,3 km / 15 min
ne donne pas la structure des rafales.

---

## 5. Décisions produit en attente

| # | Décision | Question CSV |
|---|---|---|
| S1 | Ordre de validation des classes | Q01 |
| S2 | Périmètre de l'app (local / club / en ligne) | Q02 |
| S3 | Fidélité du schéma de bateau | Q03 |
| S4 | Couple : un angle partagé ou deux | Q06 |

---

## 6. Couches — ce qui reste vraiment à faire

Plus « à écrire from scratch ». État :

| Couche | État |
|---|---|
| `core/envelope.py`, `core/boat_class.py` | faits |
| `sensors/` | modules écrits ; **pas branchés** dans l'UI Analyste (maquette Phase 4) |
| `estimation/ekf.py` | fait, minimal ; partagable avec l'embarqué plus tard |
| `analysis/` Observabilité | pilote 2x seulement |
| `analysis/` Sobol / Détectabilité / Pareto | **absents** — UI 501 / graphe vide |
| `api/` + `web/` | faits (prototype) |
| Hardware / bus réel | Phase 8, hors noyau |

---

## 7. Réserves à porter dans le code

Inchangées.

**Coques partagées.** Le double et le quatre de couple n'ont qu'une seule cote
propre chacun (Empacher). Tout le reste est une coque partagée pointe/couple.
L'accord inter-constructeurs sur ces deux classes est donc partiellement un
artefact.

**Huit de couple.** Aucun constructeur sauf Swift ne publie de ligne 8x. Swift
publie une page unique « Racing Shells 8+/x » avec moules partagés. Drapeau
`hull_source = 'shared_mould_8plus'` à conserver.

**Qualité des sources.** Hudson S4.21 39'6" vs 12,3 m (39'6" = 12,04 m) ;
WinTech HW-S « +0,6 m/poste » vs table 41 cm sur un huit ; Vespoli
« 61 - 675kg » pour le VHP53 (→ 74,8 kg) et noms VHP39/VHP41 réutilisés.
Conversions refaites depuis pieds-pouces et livres.

---

## 8. Ordre recommandé (révisé)

L'ordre de juillet (P1→P4 puis web en dernier) est exécuté à l'envers sur
la partie UI, de façon assumée (`STATE.md` : priorité Surface Produit).

1. **Ne pas** rouvrir η / `check_factor` / `F_peak` dans le 1DOF.
2. Brancher `sensors/` dans l'UI Analyste **sur 2x** (Phase 4 réelle).
3. D5, D6 — recherche documentaire ; D6 = skip tant que la table n'est pas sourcée.
4. Réponses au CSV → S1–S4, H1–H2.
5. Station de rive → E1 s'accumule pendant le dev.
6. Mode D / Sobol seulement après un jeu de capteurs branché.
7. **D3, D4** par essais terrain — seul chemin vers les watts absolus.
8. Phase 8 hardware **après** le Pareto capteurs, pas avant.
