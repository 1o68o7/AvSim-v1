# État de construction — `main` / `cursor/blade-vn-catch-36e5`

## Fait

| Chantier | Statut |
|---|---|
| Chargeur multi-classes (`defaults` + `classes/*.yaml`) | fait |
| Fermeture pilotée par la force (`I_oar·θ''=M_h+M_bl`) | fait |
| `F_h(u)` fraction d'arc | fait |
| Retrait `F×immersion`, `lock_omega(V)`, `edge=0,72` | fait |
| `E_rower` non circulaire | fait |
| Réétagement retour (bras→tronc→coulisse) + `_window_cruise` | fait |
| Perf : clip scalaires hot-path + tabulation `com_x(θ)` | fait (~10×) |
| `F_peak_N=1100` documenté (au-dessus Steinacker/Holt) | fait |
| Catch Slip angulaire ≈3° (Kleshnev) | fait |
| `leave_deg=25` conservé (retrait dégrade η/hydro) | fait |
| Métrique attaque = `|v_n|` (glissement), pas `|v_tip|` | fait |

## Diagnostic `|v_tip|` à l'attaque (2026-07-26)

Le test historique mesurait `hypot(vx,vy)`. Or la cinématique impose
`|v_tip| ≥ V |sin θ|`.

À `θ_catch=58°`, `V≈4,5 m/s`, le plancher vaut **≈3,8 m/s** même palette
parfaitement plantée (`v·n = 0`, seul un écoulement de chant). La simu
atteint déjà ce plancher (`ω ≈ -V cosθ / L`). Le seuil `< 1,5` sur `|v_tip|`
était donc **impossible** à vitesse réaliste — ce n'était pas un bug de signe.

Correction : `blade_normal_speed` + test sur `|v_n| < 1,5` (brief §9.1 :
« vitesse par rapport à l'eau » = glissement à travers l'eau).

## Non fait / ouvert

- Bootstrap `u_eff` : clamp `u_rise_70` conservé (sans clamp → drive > période)
- À 650 N : bistabilité T_drive ; à 1100 N : convergence OK
- Phase 2 §9.2 encore hors cibles (voir snapshot)
- Écart F_peak erg vs eau : piste I_oar / traînée / pertes palette
- Ne pas avancer `sensors/` / `web/` tant que Phase 2 n'est pas dans l'enveloppe

## Phase 2 snapshot (8+, F_peak=1100, Catch Slip, leave=25)

| Grandeur | Valeur | Cible |
|---|---|---|
| v_mean | ~4,87–4,95 | 5,78–6,78 |
| P_rower | ~623 W | 420–540 |
| η_blade | ~0,63 | 0,75–0,85 |
| part hydro | ~47 % | 70–80 |
| part blade | ~48 % | 15–25 |
| part aero | ~4,5 % | 5–10 |
| check_factor | ~3,7 | 0,50–0,80 |
| slip | ~2,3 | 0,4–1,4 |
| steady drift | ~0,02 % | <0,5 % |
