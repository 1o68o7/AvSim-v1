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

## Limites connues du modèle 1DOF (η et check_factor)

Deux écarts **réels et compris** face aux cibles §9.2 / enveloppe — pas des
bugs de seuil. Même traitement : documentés ici, `xfail` sur 8+/1x dans
`tests/test_plausibility.py`, pistes différées dans `ROADMAP-PRODUCTION.md`.
Le modèle reste valide pour comparer des configurations de capteurs
(l'objectif du projet) ; les lectures absolues (watts, cavalement) sont
sous-estimées / sur-estimées selon le poste.

### η_blade ≈ 0,62 — chantier §9.2 / η clos (diagnostic)

Les 4 suspects (`I_oar`, `k_drag`, pertes de palette comme knob, arc
catch/finish) ont été examinés avec diagnostic réel : **3 innocents**, **1
(arc) confirmé conforme à Kleshnev à ~1° près**. `η≈0,62` est un écart
**réel et compris**, pas un bug : le modèle 1DOF n'a pas de contrôle actif
de l'incidence de palette pendant le drive (le « aircraft principle »
documenté au tout début du projet) ; à la différence d'un vrai rameur,
notre aviron ne corrige pas `α` en temps réel, donc il traverse la zone
`C_D/C_L` défavorable (`u∈[0,22 ; 0,52]`) sans compensation.

### check_factor ≈ 3,1–3,2 — levier « largeur » épuisé

Après les correctifs de forme (retour R Kleshnev + transition coulisse,
cruise jambes/tronc drive), `cf = Vmax_retour − Vmin_drive` reste
**~3,1–3,2** (cible §9.2 8+ : `[0,50 ; 0,80]`). Mécanisme établi :

- saturations `s''=±25` aux transitions tronc→slide et fin jambes ;
- **empilement CdM** (tronc + coulisse) grossi par le warp temporel
  Hermite au carré `(dτ_r/dt)²` — pas une seule fenêtre trop étroite.

Sweep « élargir les blends » (`docs/diag-transition-width.md`) : aucune
config n'approche `cf ≲ 1,5–2` ; slide reste `|a|~70–80 m/s²` même au
blend max. **Levier largeur épuisé** — pas de correctif blend appliqué.
Pistes restantes (autre nature) : désempiler tronc/slide dans l'espace
CdM, ou revoir le warp Hermite / le rôle du clamp. Voir aussi
`docs/diag-vmin-drive.md`, `docs/diag-cf-cycle-overview.md`.

### Notes de clôture (2026-07-26)

- Cible §9.2 `0,75–0,85` : pas de citation inline ; provenance = Kleshnev
  2006 Table 3 (AIS) ~78–87 % (8+ ≈ 81,4 %). Définition code
  `E_prop/(E_prop+E_blade_loss)` alignée sur Kleshnev `P_prop/P_handle`
  (±1 pt).
- `k_drag` × `F_peak` balayé : hypothèse traînée écartée (détail ci-dessous).
- Arc `+58/−34` (92°) ≈ men sweep Kleshnev `56,8/34,3` (91,2°).
- Pas de facteur d'efficacité palette libre (Caplan + géométrie sourcée).

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

**Pas encore vérifié** : le repère angulaire Catch Slip Kleshnev (≈3° après
l'attaque) — `blade_normal_speed` encourageant mais autre grandeur.

### Snapshot §9.2 (8+, F_peak=1100, k_drag=13, Catch Slip, leave=25)

| Grandeur | Valeur | Cible |
|---|---|---|
| v_mean | ~4,91–5,13 | 5,78–6,78 (`v_ref=6,28` ±8 %) |
| P_rower | ~608 W | 420–540 |
| η_blade | **~0,62** (écart réel, déf. OK) | 0,75–0,85 |
| part hydro | ~47 % | 70–80 |
| part blade | ~48 % | 15–25 |
| part aero | ~4,5 % | 5–10 |
| check_factor | **~3,1–3,2** (après fixes forme ; ~3,7 avant) | 0,50–0,80 |
| slip \|v_n\| moyen | ~2,3 | 0,4–1,4 |
| steady drift | ~0,02 % | <0,5 % |

## Suite

Chantiers diagnostic §9.2 / η **et** check_factor (largeur) **clos** —
deux limites 1DOF documentées, pas de nouvelle correction physique sur
ces leviers.

**Phase 7 démarrée** (brief `docs/brief-interface-utilisateur.md`) : API
FastAPI + UI React (surfaces Analyste 🟢 / Produit maquette). Badges
Simulé + Validée/Bêta par classe. Phase 1 (`test_plausibility` /
`test_class_scaling`) reste en dette — les 6 classes bêta ne sont pas
présentées à égalité avec 8+/1x.

```
pip install -e '.[api]' --break-system-packages
python -m avsim.api          # :8000
cd web && npm install && npm run dev   # :5173
```
