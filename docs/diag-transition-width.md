# Largeur des transitions saturantes — élargir suffit-il ?

Suite de `docs/diag-cf-cycle-overview.md`. Question : pour les deux
transitions qui saturent le clamp `s''±25`, quelle est la largeur actuelle,
d’où vient-elle, et **élargir uniquement cette largeur** (forme C2 inchangée)
suffit-il à passer sous 25 m/s² sans le clip ?

Classe témoin : **8+**, régime établi.

## 1. Largeurs actuelles

### A — Fin de jambes (drive), τ ≈ 0,29–0,31

Fenêtre : `_window_cruise(u, 0, seq_legs_end=0,62)`, `blend_frac = 0,28`
(`min_abs = 0,10` non contraignant ici).

| Grandeur | Valeur |
|---|---|
| Largeur fenêtre | 0,62 (en u) |
| Largeur blend (chaque bord) | **b = 0,28 × 0,62 = 0,174** en u |
| Zone de décélération (sortie) | u ∈ [0,446 ; 0,620] |
| Ordre de grandeur temporel | ~0,12 s si u≈temps de drive |

`|a_com|` mesuré dans la zone : **~31 m/s²** (juste au-dessus du plafond 25).

### B — Tronc → coulisse (retour), τ_r ≈ 0,14–0,19

Fenêtres : `trunk=(0,12 ; 0,30)`, `slide≈(0,18 ; 1,0)`.

| Grandeur | Valeur |
|---|---|
| Blend tronc | frac effective **0,45** (plafonnée par `min_abs/width`) → b_abs ≈ **0,081** |
| Blend coulisse | frac **0,22** → b_abs ≈ **0,181** |
| Entrée coulisse | τ_r ∈ [0,18 ; 0,36] |
| Ordre de grandeur temporel | ~0,17 s sur T_retour |

`|a_com|` mesuré dans la zone : **~80–83 m/s²** (cinématique brute).

## 2. Provenance des constantes

| Constante | Origine |
|---|---|
| `blend = 0,16` (défaut `_window_cruise`) | Introduite en session (`bc1f6ac`, réétagement retour) — **choix d’ingénierie**, pas une source Cerne/Kleshnev/Nolte |
| `0,22` / `0,28` / `min_abs=0,10` | Itérations suivantes de la même session (adoucissements empiriques) — **non sourcés** |
| `seq_legs_end=0,62`, `rec_*` onsets | YAML `src: L` (Kleshnev/Nolte hands-body-slide) — sourcés, **pas** les largeurs de blend |
| Clamp `s''±25` | Garde-fou physiologique posé dans `dynamics` — pas une largeur de fenêtre |

**Verdict provenance :** les largeurs de transition (blends) sont des
constantes de session 1 / itérations récentes, **pas** des valeurs
calées sur Cerne et al. ni sur une mesure de durée de transition.

## 3. Sweep : élargir uniquement la largeur

Forme C2 (`_window_cruise`) inchangée ; on ne touche qu’aux `blend_frac` /
`min_abs`.

| Config | \|a\|_jambes | \|a\|_slide | cf | T_d/T_r | sous 25 ? |
|---|---|---|---|---|---|
| BASE (0,28 / 0,22 / min 0,10) | 30,8 | **83,0** | 3,20 | 0,80 | non |
| min_abs → 0,18 | 29,7 | 82,0 | 3,23 | 0,79 | non |
| min_abs → 0,28 | **23,6** | 72,5 | 3,56 | 0,68 | non (slide) |
| slide_frac → 0,45 | 34,8 | 76,4 | 3,53 | 0,72 | non |
| AGGRO 0,45/0,45/min 0,20 | 27,2 | 71,1 | **3,89** | 0,67 | non |
| MAX 0,49/0,49/min 0,25 | 26,1 | 71,2 | 3,88 | 0,66 | non |

Cible Cerne-like : `drive_fraction=0,42` ⇒ T_d/T_r ≈ **0,72**.
Les élargissements agressifs **dégradent** ce rapport (descente vers 0,66)
et **augmentent** souvent `cf`.

### Pourquoi le slide ne descend pas sous 25

Décomposition au pic retour (`τ=0,60`, `τ_r=0,16`, `a_com=−83`) :

```
a_com ≈ (d²c/dτ_r²)·(dτ_r/dt)²  +  (dc/dτ_r)·(d²τ_r/dt²)
         ≈ −81                    +  −1,4
```

- Le terme dominant est la **courbure spatiale du CdM** en `τ_r`, amplifiée
  par `(dτ_r/dt)² ≈ 2,9` (Hermite plus rapide qu’un `τ_r` linéaire).
- Siège seul, `τ_r` linéaire, blend 0,22 : `|a_seat|_max ≈ 11 m/s²` — sous 25.
- CdM complet (siège + tronc) même en temps linéaire : encore **~63 m/s²**.

Donc le problème n’est **pas** « blend trop étroit sur une seule fenêtre » :
c’est l’**empilement tronc+coulisse dans le CdM**, grossi par le warp
temporel Hermite. Élargir un blend ne défait pas cet empilement ; au-delà
d’un point ça empire `cf` et décale T_d/T_r.

Les jambes seules peuvent passer sous 25 (`min_abs≳0,28`) mais au prix d’un
`cf` qui **monte** (3,2 → 3,6) — on déplace / aggrave le bilan peak-to-peak.

## 4. Verdict (critère d’arrêt du fil)

**Élargir la largeur de transition ne suffit pas.**

- Slide : `|a|` plafonne ~70–80 m/s² même au blend max admissible (0,49).
- Jambes : possible sous 25, mais `cf` empire et T_d/T_r dérive.
- Aucune config du sweep n’approche la bande d’arrêt `cf ≲ 1,5–2,0`
  (toutes restent **≥ 3,1**, souvent pire).

→ **On n’insiste pas.** Pas de correctif « élargir le blend » appliqué.

Le résidu `cf ~ 3` après les fixes de forme (cruise, réétagement) n’est
plus un levier « largeur de transition C2 ». Les pistes suivantes
(hors ce fil, si un jour reprises) seraient d’une **autre nature** :
désempiler tronc/slide dans l’espace CdM, ou revoir le warp temporel
du retour / le rôle du clamp — pas une cinquième itération sur `blend_frac`.

## 5. Limite connue (même traitement que η)

Conformément au critère d’arrêt posé pour ce fil :

- `check_factor` reste **~3,1–3,2** (hors `[0,50 ; 0,80]`, au-dessus de 2,5–3).
- Une itération « élargir » a été tentée expérimentalement (sweep) et
  **échoue** à ramener sous ~2.
- On documente : **limite connue du levier « fenêtres / largeur de
  transition »** sur le cavalement peak-to-peak à 1 DOF — parallèle au
  traitement de `η` (écart réel compris, pas un bug de seuil).

Pas de modification de `body.py` / YAML dans ce livrable.
