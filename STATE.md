# État de construction — branche `cursor/fermeture-force-36e5`

## Fait sur cette branche

| Chantier | Statut |
|---|---|
| Fermeture pilotée par la force (`I_oar·θ''=M_h+M_bl`) | fait |
| `F_h(u)` fraction d'arc | fait |
| Retrait `F×immersion`, `lock_omega(V)`, `edge=0,72` | fait |
| `E_rower` non circulaire | fait |
| Réétagement retour (bras→tronc→coulisse) + `_window_cruise` | fait |
| Perf : clip scalaires hot-path (`np.clip` → `max/min`) | fait (~2×) |
| `F_peak_N=1100` documenté (au-dessus Steinacker/Holt) | fait |
| Catch Slip angulaire ≈3° (Kleshnev) | fait |
| `leave_deg=25` conservé (retrait dégrade η/hydro) | fait |

## Non fait / ouvert

- Bootstrap `u_eff` : tentative `F(0)=0,13·F_peak` sans clamp → drive > période ; clamp conservé
- À 650 N : bistabilité T_drive (cycle limite) ; à 1100 N : convergence OK
- Phase 2 §9.2 encore hors cibles (`v_mean≈4,87`, `check_factor≈3,7`, η≈0,63…)
- Écart F_peak erg vs eau : piste I_oar / traînée / pertes palette
- Tabulation `com_x(θ)` (perf étape 2) : **après merge**, branche séparée
- Ne pas merger sans feu vert explicite

## Phase 2 snapshot (8+, F_peak=1100, clamp, Catch Slip, leave=25)

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
