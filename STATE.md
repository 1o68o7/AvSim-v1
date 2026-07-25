# État de construction — session 3 (remplace l'état de session 1)

## Résolu depuis la session 1

| Chantier | Statut |
|---|---|
| Chargeur multi-classes (`load_class`, `load_params(boat_class=)`, `hull_ref`, `n_rowers` dynamique, `m_cox_kg=0` si non barré) | **fait**, PR #1 fusionnée |
| Fermeture cinématique → fermeture pilotée par la force (`I_oar·θ''=M_poignée+M_palette`) | **fait**, structure validée |
| `F_h` reparamétré en fraction d'arc `u` plutôt qu'en temps absolu | **fait**, sourcé Kleshnev/BioRow (`F_u_peak=0,40`, `F_u_rise_70=0,17`, `F_high_width=0,35`) |
| `F×immersion`, `lock_omega(V)`, `edge=0,72` | **retirés** — trois réglages numériques sans justification physique, chacun ajouté pour faire passer un test précis plutôt que pour respecter la spec |
| Coefficients de palette | recalés sur les repères mesurés Caplan & Gardner (2007), domaine complet 0-180° |
| `E_rower_J` | **corrigé** — n'est plus calculé comme résidu de l'identité qu'il est censé vérifier (résidu 0,82 % désormais, contre 33 % avant) |
| `test_steady_state_reached` | **passe** |

## Bug actif — diagnostiqué, correction en attente

**`check_factor` trop élevé (v_max-v_min ≈ 3,7-4,7 m/s contre 0,5-0,8 m/s attendus).**

Localisé : pas un problème de propulsion. `v_min` en plein drive (365 ms),
`v_max` pendant le retour (465 ms après le dégagé).

Cause confirmée : `kin_harmonics`/`_build_tables` (bande-limitation spectrale
qui empêchait ce genre de pic sous l'ancienne fermeture cinématique) ne
s'appliquent plus au chemin actuel — absents du `Crew` réécrit, aucun
FFT/bandlimit dans le code. Le chemin de retour actuel (Hermite quintique →
`handle_position` → `com_x_from_handle` sur les fenêtres `seq_*`/`rec_*` →
dérivée seconde par différences finies → clip) ne repasse par aucun
lissage spectral.

Chiffré : au pic (t+1225 ms), `s''` brut atteint ≈-51 m/s² contre un plafond
de 25 — un dépassement d'un facteur **~2**, pas une divergence numérique
sauvage. Terme dominant : `(d²s/dθ²)·ω²` à `|ω|≈3,7 rad/s`.

**Diagnostic C2 des fenêtres (session 3)** : les fenêtres `seq_*`/`rec_*`
passent toutes par `_window` → `smootherstep` (C2, dérivées 1re et 2e nulles
aux bornes) — **aucune transition linéaire ou non-C2 introduite** à ce
niveau pendant la réécriture. Le pic ~50 m/s² persiste donc **malgré** des
fenêtres déjà C2. Question ouverte avant de toucher au clip : existe-t-il
une donnée biomécanique sur l'accélération du CdM pendant le retour qui
validerait ou invaliderait ~50 m/s² comme caractéristique réelle du couplage
`s(θ)×ω` au milieu de l'Hermite ? Note annexe : au pic, le clip d'extension
de bras `e` est actif (`e_raw > e_max`) — autre non-lissage possible, distinct
des fenêtres de séquençage.

## Point ouvert, non bloquant pour l'instant

**`F_peak_N`** : 1100 N vient de la plage ergomètre (800-1100 N, McGregor/Colloud) — pas comparable à notre modèle qui simule un bateau. La plage sourcée sur l'eau, à rythme de corps de course (`rate_spm=36`, pas un départ), est 500-700 N (Steinacker, confirmé par Holt et al. sur 47 courses réelles). Testé à 650 N : `check_factor` baisse un peu mais `v_mean` et `T_drive` s'éloignent des cibles — **la magnitude de F_peak seule n'explique pas le problème**, cohérent avec le fait que la vraie cause vit dans le retour, pas le drive. À trancher une fois le bug du retour résolu, pas avant. *(Valeur actuellement dans `defaults.yaml` : 650 N, commentaire sourcé Steinacker/Holt ; ancienne 1100 N documentée comme pics erg.)*

## Encore rouge, volontairement pas retouché

- `blade_near_stationary_in_water_at_catch` — cible sourcée disponible depuis peu : Kleshnev situe la pleine immersion à **≈3° après l'attaque** (le concept s'appelle *Catch Slip*), pas les 25-33° que produisaient les anciens réglages. Pas encore recalé sur cette cible précise — à faire une fois `check_factor` réglé.
- `leave` (fenêtre de sortie de palette, 25°) — toujours présent, jamais justifié ni retiré. Sa nécessité réelle ne pourra être jugée qu'une fois drive et retour tous les deux corrects.

## Pas retesté depuis la réécriture de la fermeture

`test_zero_wind_zero_current_ground_equals_water`, `test_identical_offsets_give_identical_seats`, `test_phase_offset_actually_shifts_seat`, `test_numerical_convergence` — aucun n'a été relancé depuis le changement de fermeture. À revérifier avant de déclarer v1 terminé, pas seulement les 3-4 tests qu'on suit activement.

## Pas encore écrit du tout

`tests/test_plausibility.py`, `tests/test_class_scaling.py`, `tests/test_triangulation.py` (brief §9.2-9.4). Ce dernier est **le test le plus important du projet** selon le brief lui-même — la comparaison contre Atkinson/van Holst/Roosendaal — et il n'existe pas encore en code.

## Performance

44 s/simulation en session 1 → **5-6 min actuellement**. Ça a empiré, probablement à cause de la complexité ajoutée par les événements de catch/dégagé et le suivi par coup. Cible du brief : < 1 s. Complètement intact, jamais attaqué — et ça devient plus urgent maintenant que ça ralentit directement la boucle de diagnostic elle-même.

## Points ouverts trouvés en construisant les vues sagittale/frontale (documentation, pas du code)

- `x_ankle_off_m=-0,17` produit un genou à l'attaque géométriquement très replié (derrière la cheville) — corrigé en session 2 pour satisfaire la contrainte de portée de jambe, jamais validé contre une vraie position de catch.
- Position et hauteur du pivot (dame) non paramétrées dans le modèle — reconstituées approximativement pour le dessin, incohérentes de 0,22 m entre attaque et dégagé (`geometry_mismatch`, déjà documenté dans `body.py`, jamais résolu).
- `drive_fraction=0,42` fixe — devrait varier avec la cadence (Černe et al. 2013 : ratio propulsion:retour de 1:2,04 à 20 c/min à 1:1,31 à 34 c/min), non implémenté.

## Ordre recommandé à partir d'ici

1. Fenêtres seq_*/rec_* déjà C2 — **ne pas retoucher le clip** tant qu'on n'a pas tranché si ~50 m/s² est physique (donnée biomécanique CdM au retour) ou un autre artefact (ex. saturation `e`)
2. Reconfirmer `check_factor` + les 5 autres grandeurs de plausibilité ensemble une fois (1) décidé
3. Trancher `F_peak_N` dans la plage 500-700 N une fois (2) stable
4. Recaler l'immersion sur la cible de 3° (Catch Slip), revoir si `leave` est encore nécessaire
5. Relancer la suite complète de `test_conventions.py` (pas seulement les tests suivis)
6. Écrire `test_plausibility`, `test_class_scaling`, `test_triangulation` — dans cet ordre
7. Performance (brief §6) — seulement une fois la physique juste, pas avant
8. Alors seulement : capteurs, estimation, analyse, API, web
