# Diagnostic — `v_min` en plein drive (pas au retour)

Fil rouvert après le fix retour (R Kleshnev / coulisse τ∈[0,65;0,75]).
Classes : **8+**, **1x**, **2-**. Régime `n_strokes=12`, `n_discard=6`.

## Où est `v_min` ?

| Classe | τ_stroke | u (arc) | θ | phase | coincidences |
|---|---|---|---|---|---|
| 8+ | 0,204 | **0,377** | +23° | DRIVE | juste avant `F_u_peak=0,40` |
| 1x | 0,264 | **0,362** | +26° | DRIVE | idem |
| 2- | 0,216 | **0,362** | +25° | DRIVE | idem |

`Vmax` est **au retour** (τ≈0,61–0,68), pas en propulsion.
`check_factor = Vmax_retour − Vmin_drive`.

## Piste A — creux / transition de `F_h(u)` : **innocente**

Au `v_min` :

- `F_h ≈ 1090–1100 N` (pic du profil, `F_peak_N=1100`)
- `u ∈ [0,36 ; 0,38]` — **avant** `F_u_peak=0,40`, **après** `F_u_rise_70=0,17`
- clamp `u_eff=max(u, F_u_rise_70)` **inactif** (`u > 0,17`)
- `u_fall_70 = 0,52` est ~0,15 plus tard — hors zone

Pas de creux de force, pas de transition `rise_70` / `high_width` au minimum.

## Piste B — pic de traînée palette (α≈90°, Cd max) : **innocente**

| Classe | α @ v_min | Cd @ v_min | Cd_max drive | τ(Cd_max) | Δτ |
|---|---|---|---|---|---|
| 8+ | 56° | 1,39 | 2,00 @ α≈90° | 0,306 (u=0,63) | **+0,10** |
| 1x | 61° | 1,54 | 2,00 | 0,381 (u=0,59) | **+0,12** |
| 2- | 60° | 1,52 | 2,00 | 0,336 (u=0,63) | **+0,12** |

Le Cd maximal (incidence ~90°) arrive **après** `v_min`, en pleine remontée de V.
`F_prop ≫ D_hull+D_aero` au minimum (écart +3800 N sur 8+) — la traînée coque/palette
ne gagne pas sur la force nette.

## Cause retenue — surcharge inertielle CdM (jambes)

Équation (brief §4.3) :

```
(m_b + M) · V' = F_prop − D_h − D_a − Σ m_i s_i''
```

Le long du drive (8+) :

| u | V | a_V | F_prop | inertiel I | I/F_prop | a_com |
|---|---|---|---|---|---|---|
| 0,17 | 4,25 | −6,6 | 2174 | 7553 | **3,5** | +11 |
| 0,25 | 3,70 | −7,7 | 3147 | 9503 | **3,0** | +14 (pic) |
| 0,35 | 3,31 | −1,5 | 3882 | 4996 | **1,3** | +7 |
| **0,38** | **3,30** | **≈0** | 3981 | 3665 | **≈0,92** | +5 |
| 0,40 | 3,31 | +1,7 | 4031 | 2383 | 0,6 | +3 |

**`v_min` = instant où `I / F_prop` repasse sous ~1** : la propulsion nette
recommence à accélérer le bateau. Universel sur les 3 classes (Δτ pic `a_com` →
`v_min` ≈ 0,07).

Mécanisme : la course de siège drive utilise `_window` = **smootherstep** sur
`[0 ; seq_legs_end=0,62]`. La courbure du smootherstep concentre l'accélération
du CdM vers u≈0,23–0,25 (avant le pic de F_h à 0,40). Tant que le rameur
accélère vers la proue plus fort que la palette ne pousse, le bateau **ralentit**
— même avec F_h au plateau.

C'est le « catch dip » inertiel de la littérature, **amplifié** ici par la
forme smootherstep (pic de courbure), pas un artefact de force ou de Cd.

## Famille de bug (semaine en cours)

| Fix récent | Mécanisme |
|---|---|
| Retour : `_window_cruise` siège/tronc | smootherstep / empilement → pic \|a\| |
| Retour : onset coulisse avancé | blend d'entrée sous ω Hermite |
| **Drive : `_window` jambes** | **même smootherstep → pulse `s''` avant F_peak** |

**Même famille** : fenêtre à courbure centrale (pas un seuil dur non lissé, pas
une transition F_h). Correctif naturel = `_window_cruise` sur le drive
jambes (± tronc), comme au retour.

## Ce que ça ne ferme pas tout seul

`Vmax` reste au **retour** (τ≈0,61). Adoucir les jambes drive remonte un peu
`Vmin` et réduit `cf` de ~3,6 → ~3,2 (essai blend 0,28) — loin de la cible
§9.2 / enveloppe `[0,50 ; 0,80]` (8+). Le sujet `check_factor` a donc
**deux pôles** :

1. `Vmin` drive — inertie jambes smootherstep ← ce diagnostic
2. `Vmax` retour — déjà partiellement traité (R Kleshnev) ; le résidu
   de cavalement haut reste ouvert

## Post-fix (cruise jambes/tronc drive, blend≈0,28)

Appliqué dans `body.seat_phi_from_u` (drive) — même famille que le retour.

| Classe | cf avant | cf après | Vmin @u | rejet enveloppe |
|---|---|---|---|---|
| 8+ | 3,58 | **3,21** | 0,45 (était 0,38) | REJECT |
| 1x | 3,21 | **2,94** | 0,24 | REJECT |
| 2- | 3,54 | **3,24** | 0,44 | REJECT |

Taux de rejet enveloppe sur 8 classes : **8/8** (inchangé). `cf` moyen ≈ 3,1.
Le pôle `Vmax` retour domine encore le peak-to-peak.

## Sources

- Kleshnev / BioRow — rythme inertiel catch–drive (boat speed drop early drive)
- Brief §4.3 — terme `Σ m_i s_i''` dans le bilan cavalement
- Brief §12.2 — fenêtres empilées / courbure → accélérations non physiologiques
