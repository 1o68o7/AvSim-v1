# État de construction — Phase 0 close (25/07, PR #3 mergée sur main)

## Phase 0 : fermeture v1 — TERMINÉE

`pytest tests/` : **16/16 verts** sur `main` (`bfeb780`), vérifié sur 8+ ET 1x.
Première fois que la validation porte sur deux classes, pas seulement 8+.

Tout ce qui suit a été résolu au fil de la session, chacun avec une source :

| Chantier | Résolution |
|---|---|
| Chargeur multi-classes | `load_class`/`load_params(boat_class=)`, `hull_ref`, `n_rowers` dynamique, `m_cox_kg=0` si non barré |
| Fermeture cinématique → pilotée par la force | `I_oar·θ''=M_poignée+M_palette` |
| `F_h(u)` | fraction d'arc, sourcé Kleshnev/BioRow (`F_u_peak=0,40`, `F_u_rise_70=0,17`, `F_high_width=0,35`) |
| Amorçage à l'attaque | **tenté** : F(u=0)=13 % Fmax (Kleshnev) raccordé C2 sans clamp → drive > période à 1100 N ; **clamp** `u_eff=max(u_geom, u_rise_70)` **conservé** en attendant une refonte du bootstrap |
| Fenêtres de retour | réétagées bras→tronc→coulisse, `_window_cruise` — pic inertiel faux (`-40 m/s²`) éliminé |
| `F×immersion`, `lock_omega`, `edge=0,72` | retirés — sans justification physique |
| `E_rower_J` | recalculé indépendamment (`P=-L_in·F_handle·ω`), plus de circularité |
| `blade_near_stationary` | recentré sur `blade_normal_speed` (composante normale) — `|v_tip|` a un plancher géométrique `V·sinθ_catch` incompressible |
| `F_peak_N=1100` | retenu, **au-dessus** de la plage sourcée sur l'eau (500-700 N, Steinacker/Holt) — 650 N ne produit aucun cycle viable même avec amorçage. Écart non expliqué, voir point ouvert |
| Performance étape 1 | `np.clip` scalaire → `max/min`, ×2,1 |
| Performance étape 2 | tabulation `com_x(θ)` (drive/retour, 3001 pts) à l'init de `Crew` — **faite** (`334da14`) |

### Note chargeur vs fixture tests

Les fixtures `pytest` appellent encore `load_params()` **sans** `boat_class` →
`defaults.yaml` seul (`I_oar=1,30`). `load_params(boat_class="8+")` fusionne
la classe (`I_oar=6,16` Empacher/estim.). Les deux convergent aujourd'hui
(diag court) ; la suite Phase 1 doit simuler via `boat_class=` explicitement.

## Point ouvert — le vrai sujet de la suite

**Phase 2 §9.2 (plausibilité) reste hors cibles** : `v_mean`, rendement de palette,
`check_factor` pas encore dans les fourchettes du brief. `F_peak` retenu au-dessus
de la plage sourcée en est le symptôme le plus probable — piste à creuser :
`I_oar`, coefficient de traînée, ou pertes de palette surestimés quelque part
dans le bilan. Pas encore diagnostiqué.

**Pas encore vérifié** : le repère angulaire de Kleshnev (glissement ≈3° après
l'attaque) n'a pas été confronté directement — `blade_normal_speed` (0,94-1,04 m/s)
est encourageant mais mesure autre chose que ce repère précis.

### Snapshot §9.2 (8+, F_peak=1100, Catch Slip, leave=25)

| Grandeur | Valeur | Cible |
|---|---|---|
| v_mean | ~4,87–5,05 | 5,78–6,78 (`v_ref=6,28` ±8 %) |
| P_rower | ~620 W | 420–540 |
| η_blade | ~0,63 | 0,75–0,85 |
| part hydro | ~47 % | 70–80 |
| part blade | ~48 % | 15–25 |
| part aero | ~4,5 % | 5–10 |
| check_factor | ~3,7 | 0,50–0,80 |
| slip \|v_n\| moyen | ~2,3 | 0,4–1,4 |
| steady drift | ~0,02 % | <0,5 % |

## Suite

Voir `ROADMAP-PRODUCTION.md`. Prochaine étape : Phase 1 — écrire
`test_plausibility.py`, `test_class_scaling.py`, `test_triangulation.py`
(ce dernier = test le plus important du projet, jamais écrit ; bloqué data :
MANQUES D6).
