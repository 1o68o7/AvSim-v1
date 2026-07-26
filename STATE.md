# État de construction — Phase 0 close (25/07, PR #3 mergée sur main)

## Phase 0 : fermeture v1 — TERMINÉE

`pytest tests/` historique (`bfeb780`) : **16/16 verts** mais uniquement via
`load_params()` **sans** `boat_class` → `defaults.yaml` (`I_oar=1,30`), pas le
vrai 8+ (`I_oar=6,16`). Le « vérifié 8+ et 1x » de Phase 0 close était un
**override manuel** hors fixture (mesure `|v_n|` seule), pas la suite pytest.

Fixtures corrigées (`tests/conftest.py`, params `8+` / `1x`) : compte réel
ci-dessous — un échec apparaît dès que le vrai `I_oar=6,16` est confronté.

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

### Fixtures multi-classes (corrigé)

`tests/conftest.py` : `boat_class` ∈ {`8+`, `1x`} → `load_params(boat_class=)`.
Plus de `load_params()` nu dans les tests de physique.

**Compte réel** (`pytest tests/ -v`, après fix bilan aviron) : **30 passed,
1 skipped** (31 collected) sur **8+ et 1x**.

| Résultat | Test |
|---|---|
| SKIPPED | `test_phase_offset_actually_shifts_seat[1x]` — `n_rowers < 2` |
| PASSED | tout le reste, y compris `test_rower_work_equals_losses[8+]` et `[1x]` |

### Diagnostic résidu ~220 J (résolu)

Le terme `½ I ω²` n'était **pas** des deux côtés du bilan :
- **Propulsion** : `E_rower` via `-L_in F ω` inclut le travail qui accélère l'aviron
- **Dégagé** : clamp `w_at_finish ∈ [-0,6 ; 0,2]` détruit ~200 J (8+, I=6,16) hors intégrale
- **Retour** : Hermite avec `F_pull=0` → puissance contrainte `I α ω` absente de `E_rower`

Correction : puissance retour `I α ω` dans `handle_power` ; sauts de KE
(`E_oar_ke_jump_J`) déduits de `E_rower_J`. Identité aviron sur α dynamique
(plus `np.gradient`). Clamp Hermite **conservé** (sans lui le 1x diverge).

## Point ouvert — le vrai sujet de la suite

**Phase 2 §9.2 (plausibilité) reste hors cibles.** Hypothèse traînée testée
et **écartée** (voir sweep ci-dessous) : baisser `k_drag` dans sa bande ne
permet pas de ramener `F_peak` dans 500–700 N tout en touchant v/cf/η.
Prochaine piste : **pertes de palette** (surestimées), pas la traînée de coque.

**Pas encore vérifié** : le repère angulaire de Kleshnev (glissement ≈3° après
l'attaque) n'a pas été confronté directement — `blade_normal_speed` (0,94-1,04 m/s)
est encourageant mais mesure autre chose que ce repère précis.

### Sweep `k_drag` × `F_peak` (8+, I_oar=6,16, 2026-07-26)

Config réelle via `load_params(boat_class="8+")`. Grille :
- `k_drag` ∈ {11,70 ; 12,00 ; 12,35 ; 12,70 ; 13,00} — bande classe
  `params/classes/8+.yaml` **[11,70 ; 14,30]** (src N, loi d'échelle)
- `F_peak` ∈ {500 ; 550 ; 600 ; 650 ; 700 ; 1100} — plage eau Steinacker/Holt
  500–700 + référence erg actuelle

Pilotage traînée : modèle `simple` → `k_drag` (`forces.hull_drag`), pas `CdA`
(aéro minoritaire ~4 %).

**Aucune combinaison** avec `k_drag` **et** `F_peak` dans leurs bandes sourcées
n'atteint simultanément v_mean ∈ [5,78 ; 6,78], check_factor ∈ [0,50 ; 0,80],
η_blade ∈ [0,75 ; 0,85]. **Aucun YAML modifié.**

| Régime | k_drag | F_peak | viable ? | v_mean | cf | η | T_drive | Écarts vs §9.2 |
|---|---|---|---|---|---|---|---|---|
| Meilleure **deux bandes sourcées** | 13,00 | 550 | oui (limite) | 2,11 | 2,70 | 0,49 | 1,34 | v −3,67 ; cf +1,90 ; η −0,26 |
| Meilleure v globale (F hors eau) | 11,70 | 1100 | oui | 5,13 | 3,77 | 0,64 | 0,73 | v −0,65 ; cf +2,97 ; η −0,12 |
| Nominal actuel | 13,00 | 1100 | oui | 4,91 | 3,72 | 0,62 | 0,75 | v −0,87 ; cf +2,92 ; η −0,13 |

À F∈[500;700] : quasi tous les points ont drift > 0,5 % (cycle non établi) ;
les rares « viables » restent à v≈2,1–2,2 m/s. Baisser `k_drag` au min (11,70)
à F=1100 ne gagne que **+0,22 m/s** sur v_mean — loin du plancher 5,78.
`check_factor` et `η` bougent à peine. Signal : le problème n'est pas `k_drag`.

### Snapshot §9.2 (8+, F_peak=1100, k_drag=13, Catch Slip, leave=25)

| Grandeur | Valeur | Cible |
|---|---|---|
| v_mean | ~4,91–5,13 | 5,78–6,78 (`v_ref=6,28` ±8 %) |
| P_rower | ~608 W | 420–540 |
| η_blade | ~0,62–0,64 | 0,75–0,85 |
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
