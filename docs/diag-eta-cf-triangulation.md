# Diagnostic — η couple/pointe, check_factor, triangulation

*26 juillet 2026 · branche `cursor/diag-eta-cf-triang-36e5` · pas de
correction physique dans ce tour (aucune cause précise + sourcée à corriger).*

---

## 1) Scission couple / pointe sur η

### Géométrie effectivement chargée

| | Couple (1x, 2x, 4x, 8x) | Pointe (2-, 4-, 4+, 8+) |
|---|---|---|
| Source YAML | Empacher **scull** (spec sheet Sep 23) | Empacher **riemen** + Filippi spans |
| L_in | 0,880 m | 1,150 m |
| L_out | 1,792 m | 2,343 m |
| A_blade | 0,0814 m² (Big Blade 44×22) | 0,1124 m² (Smoothie med.) |
| I_oar | 1,82 (N, repartition estimée) | 6,16 |
| Arc catch/finish | +66 / −46 | +58 / −34 |
| n_oars_per_rower | 2 | 1 |

**Pas de valeur composite unique** appliquée aux deux familles. Concept2
n’est cité que pour confirmer le **pitch** 0–7° (hors plan sagittal, sans
effet sur le modèle 2D actuel) — pas comme source d’aire couple.

`blade_force` utilise `A_blade` / `L_out` de la classe ; `n_oars` multiplie
fx/fy/p_loss. `F_peak_N=1100` est **le même** pour couple et pointe
(une seule poignée virtuelle par rameur).

### α(u) à régime comparable (n_strokes=8, n_discard=4)

| | 1x | 2- | Δ |
|---|---|---|---|
| η | 0,436 | 0,566 | −0,13 |
| α mid (u∈0,22–0,52) | 64,9° | 62,1° | +2,8° |
| CD/\|CL\| mid | 2,19 | 1,88 | |

Bins α(u) : écart ~2–5° sur 0–0,52 ; **+12°** seulement sur u∈[0,52 ; 0,70).
Δα mid **seul** n’explique pas 0,13–0,20 pt de η.

### Sensibilités (diagnostic, overrides temporaires)

| Essai sur 1x / 2- | η |
|---|---|
| 1x baseline | 0,447 |
| 1x `I_oar *= n_oars` | 0,445 (neutre) |
| 1x `n_oars=1` | 0,399 (pire) |
| 1x `A_blade`→sweep | 0,450 (neutre) |
| 2- baseline | 0,577 |
| **2- avec package rig couple** | **0,465** |

Le package géométrie+arc+I+n_oars couple, greffé sur un 2-, **reproduit
presque tout l’écart** (0,577→0,465). Ce n’est pas un calcul « oublié »
qui divergerait en silence : c’est la famille scull (plus lent, plus de
perte relative palette, α un peu moins favorable en fin de drive) vs
pointe.

### Verdict piste 1

- Cause d’un **bug de source unique / composite** : **écartée**.
- Cause d’un Δα mid isolé : **insuffisante**.
- Écart η couple/pointe : **effet de famille de gréement Empacher**, amplifié
  par V plus bas en couple (même F_peak). Pas de correction YAML/code sans
  nouvelle source (ex. F_peak par main en couple, ou I effectif 2 sculls
  documenté) — à trancher plus tard, pas à inventer ici.

---

## 2) check_factor universel

### Mesure (n_strokes=6, n_discard=3)

| Classe | check_factor | peak \|a\| drive | peak \|a\| retour | spikes \|a\|>40 |
|---|---|---|---|---|
| 8+ | 3,73 | 19 | 142 | 14 |
| 1x | 3,49 | 13 | 206 | 15 |
| 2- | 3,71 | 15 | 155 | 14 |

Pics situés à **τ≈0,62–0,75** (milieu/fin de retour, immersion=0), proches
de V_max — **même signature** sur les trois classes.

### Lien avec le réétagement

`STATE.md` : le réétagement bras→tronc→coulisse a éliminé le pic **faux**
d’empilement (~−40 m/s²). Cela a été motivé sur le chantier 8+ ; le même
code `_window_cruise` s’applique à toutes les classes (pas de branche
par `boat_class`).

Ce qui reste (~100–200 m/s² au retour, cf≈3,5–3,7) est un **phénomène
commun**, pas une réapparition différente du bug d’empilement selon la
classe. Le check_factor cible 0,50–0,80 n’a jamais été restauré par ce
fix — cohérent avec le snapshot §9.2 (cf~3,7).

### Verdict piste 2

Pas de cause nouvelle sourcée à corriger aujourd’hui. Piste ouverte :
cinématique Hermite du retour / bande passante corporelle (`kin_harmonics`)
— triage explicite, pas un patch opportuniste.

---

## 3) Triangulation — shelwork.htm (Atkinson **vs Kleshnev**)

Page relue : `https://atkinsopht.com/row/shelwork.htm` (2026-07-26).

### Ce qui est publié (sorties)

| | Atkinson | Kleshnev |
|---|---|---|
| P_tot | 552 W | 544 W |
| P_métab | 2208 W | 2386 W |
| Dissipation corps | 25 % | 23 % |
| η palette | 75 % | 79 % |

Règle qualitative : ~¾ du travail poignée atteint la dame.

### Ce qui **n’est pas** sur la page

Aucun tableau d’**entrées** appariées (angle catch/release, aire palette,
facteur de résistance, profil de force). van Holst / Roosendaal sont
mentionnés ailleurs (`comprslt.htm` / `validate.htm`) mais **pas** comme
source chiffrée d’entrées ici.

### Conséquence

Label honnête du test : **Atkinson vs Kleshnev (sorties shelwork.htm)**,
comparaison **qualitative** — pas van Holst/Roosendaal, pas d’override
d’entrées inventées. Voir `tests/test_triangulation.py`.
