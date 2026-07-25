# État de construction — session 3 (suite)

## Résolu depuis la session 1

| Chantier | Statut |
|---|---|
| Chargeur multi-classes | **fait**, PR #1 fusionnée |
| Fermeture pilotée par la force | **fait** |
| `F_h` en fraction d'arc `u` | **fait** |
| `F×immersion`, `lock_omega(V)`, `edge=0,72` | **retirés** |
| `E_rower_J` non circulaire | **fait** (résidu ~0,82 %) |
| `test_steady_state_reached` | **passe** |

## Bug retour / check_factor — chevauchement confirmé et corrigé

**Verdict** : ~50–64 m/s² au milieu du retour **n'est pas plausible**.

1. **OoM** : coulisse sinusoïdale sur `L_slide=0,72 m`, `T_rec≈0,97 s` →
   `|a|_max ≈ 3,8 m/s²` (demi-cosinus) ; avec Δs_CdM≈0,86 m → ≈4,6 m/s².
   Le modèle était **10–13×** au-dessus.
2. **Littérature** : une accel marquée *au milieu* du retour est la signature
   documentée de « rushing the slide » (défaut), pas d'un retour efficace
   (vitesse quasi uniforme au milieu, accel aux extrémités — Kleshnev / Nolte).

**Cause** (même famille que brief §12.2, déjà vue sur le drive) :

- Sous `ω(u)` Hermite, les fenêtres `rec_arms_away` / `rec_trunk_fwd` /
  `rec_slide_start` avec largeurs hardcodées `+0,45` / `+0,50` formaient un
  **triple chevauchement** sur τ∈[0,32 ; 0,55] — exactement sous `|ω|` max
  (τ≈0,55). Tronc et coulisse avaient tous deux une vitesse élevée vers
  u≈0,50–0,53.
- En plus, un `smootherstep` sur **toute** la course de coulisse plaçait un
  pic de courbure au milieu : le siège seul donnait déjà ~−43 m/s²
  (terme `(d²x/dτ²)(dτ/dt)²`). Le chevauchement n'ajoutait que ~4 m/s², mais
  le profil plein-fenêtre était la composante dominante du « rush ».

**Correction** (`body.py` + onsets YAML) :

- Fins de segment = onset du suivant (bras → tronc → coulisse, sans empilement).
- Coulisse (et tronc) en `_window_cruise` : accel C2 aux blends, **palier**
  `d²y/dτ²=0` au milieu.
- Onsets recalés (`rec_arms_away=0,05`, `rec_trunk_fwd=0,12`,
  `rec_slide_start=0,30`) pour que le palier couvre τ≈0,55.

**Effet diagnostique Hermite** : midband s'' −40 → **−1 m/s²** ; `n_segments`
actifs à ω max = 1.

**Phase 2 (8+, post-fix)** — encore hors cibles §9.2, mais la signature
change : `check_factor` 4,0 → 2,6 ; `v_max` retour 6,1 → 3,7. Le `v_mean`
qui « baissait » (3,4 → 2,0 à `F_peak=650`) était en partie un **artefact**
du faux pic inertiel (terme `−Σ m s''` qui propulsait la coque au retour).
Recaler `F_peak` / le drive une fois le retour stable — pas avant.

## Encore rouge

- Cibles §9.2 (v_mean, η, parts d'énergie, check_factor→0,5–0,8)
- `blade_near_stationary_in_water_at_catch` (Catch Slip ≈3°)
- `leave` 25° toujours injustifié
- Clip `s_ddot` ±25 encore engagé sur les blends d'extrémité du retour
- Perf 5–6 min/sim

## Ordre recommandé

1. ~~Diagnostiquer / corriger empilement retour~~ **fait**
2. Revoir les pics d'extrémité (blends) + clip ±25
3. Trancher `F_peak_N` dans 500–700 N avec retour sain
4. Catch Slip 3° ; revoir `leave`
5. Suite conventions + `test_plausibility` / scaling / triangulation
6. Performance
7. Capteurs / estimation / web
