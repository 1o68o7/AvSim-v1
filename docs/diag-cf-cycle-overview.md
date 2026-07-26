# Vue d’ensemble — `check_factor` sur un cycle 8+ établi

Pas un diagnostic ponctuel : décomposition de `V(t)` et des contributions à
`a_V` sur **tout le cycle**, après les deux correctifs déjà en place
(retour Kleshnev / coulisse, drive jambes cruise).

Régime : `n_strokes=14`, `n_discard=8`. `cf = Vmax − Vmin ≈ 3,22`.

## Décomposition

```
(m_b + M) · a_V = F_prop − D − I
a_V = a_F + a_D + a_I
```

avec `I = Σ m_i s_i''`, `a_F = F_prop/M`, `a_D = −D/M`, `a_I = −I/M`.
Pendant le retour `F_prop = 0`.

Clamp dynamique existant (`dynamics._com_and_deriv`) :

```
s'' ← clip(s'', −25, +25) m/s²
```

⇒ `|I|` saturé à `M_crew × 25 = 8 × 88 × 25 = 17 600 N`
⇒ `|a_I|` saturé à `≈ 20,6 m/s²`.

## Où vivent Vmin et Vmax (rappel + ventilation)

| Point | τ | phase | V |
|---|---|---|---|
| Vmin | 0,241 | DRIVE | 3,35 |
| finish | 0,446 | fin DRIVE | 5,53 |
| Vmax | 0,623 | RETOUR | 6,56 |
| fin cycle | 1,000 | RETOUR | 4,36 |

**Ventilation de `cf = 3,22` :**

| Segment | ΔV | % cf |
|---|---|---|
| Vmin → finish (remontée drive) | +2,18 | **68 %** |
| finish → Vmax (remontée retour) | +1,04 | **32 %** |
| Vmax → fin (descente retour) | −2,20 | — |

Les deux pôles comptent ; le drive porte encore la majorité de l’amplitude
peak-to-peak, le retour le tiers restant **et** le pic absolu.

## Vmax retour : pic ponctuel ou plateau ?

| Critère | Mesure | Lecture |
|---|---|---|
| Largeur V ≥ Vmax − 5 %·cf | **Δτ = 0,012** (~20 ms) | pic serré |
| Largeur V ≥ Vmax − 10 %·cf | Δτ = 0,021 | idem |
| Largeur V ≥ Vmax − 20 %·cf | Δτ = 0,039 | pas un plateau |
| Frac. retour avec V dans le top 10 % de cf | **0,04** | pas diffus |
| `(Vmax − V_mean_retour) / cf` | 0,33 | crête au-dessus de la moyenne |

**Verdict : pic ponctuel**, pas un plateau large. Il reste un mécanisme
**localisé** à trouver — même logique que les précédents.

## Ce qui forme le pic : pulse inertiel saturé au début du retour

Autour de Vmax (`F_prop = 0`, seule l’inertie + traînée restent) :

```
τ     τ_r    V      a_V     a_I     a_com_kin   s''_eq
0.581 0.11  5.54    ~0      ~0         -0.5       -0.5
0.593 0.14  5.71  +20.6   +20.6      -50       -25 SAT ← entrée pulse
0.599 0.15  5.91  +20.0   +20.6      -78       -25 SAT
0.605 0.17  6.11  +20.0   +20.6      -81       -25 SAT
0.611 0.19  6.31  +19.9   +20.6      -55       -25 SAT
0.617 0.21  6.48  +12.3   +13.0      -18       -16
0.623 0.22  6.56   -4.6    -3.9       +7        +5   ← VMAX
0.630 0.24  6.38  -21.3   -20.6      +50       +25 SAT ← freinage
0.636 0.26  6.16  -21.2   -20.6      +60       +25 SAT
0.642 0.28  5.95  -21.2   -20.6      +42       +25 SAT
```

- Pulse accélérateur bateau : `s'' ≈ −25` saturé sur **τ ∈ [0,593 ; 0,611]**
  (`τ_r ∈ [0,14 ; 0,19]`), ΔV ≈ **+0,60 m/s** (~60 % de la remontée retour).
- Immédiatement suivi d’un pulse freineur `s'' ≈ +25` sur
  **τ ∈ [0,630 ; 0,642]** (`τ_r ∈ [0,24 ; 0,28]`).
- `a_com` **cinématique** sous-jacent : **−50 à −82 m/s²** puis **+40 à +60** —
  le clamp ±25 transforme un spike en créneau.

Fenêtres retour actuelles : `trunk=(0,12 ; 0,30)`, `slide≈(0,18 ; 1,0)`.
Le pulse saturé siège **pile sur la transition tronc → entrée coulisse**
(`τ_r ≈ 0,14–0,19` ≈ onset slide + début de blend).

## Autre saturation (drive, 68 % du cf)

Même clamp, fin de propulsion jambes :

- `s'' ≈ −25` saturé sur **τ ∈ [0,289 ; 0,307]** (sortie `seq_legs_end`,
  décélération siège) — accélère fortement le bateau après Vmin
  (`a_V` jusqu’à +23 m/s²).
- Contribue à la remontée Vmin→finish (pôle drive du cf).

## Réponse directe

> Maintenant que les deux pics déjà trouvés sont atténués, où se situe le
> reste de l’écart de check_factor (~3,1) ?

1. **Ce n’est pas un plateau diffus** d’amplitude inertielle retour.
2. **Vmax reste un pic localisé** (Δτ ≈ 0,01–0,02 au sommet), produit par un
   **créneau inertiel saturé** au début du retour.
3. Le sous-jacent est encore de la **famille fenêtres** : transition
   tronc/coulisse avec `|a_com|_kin ~ 50–80 m/s²`.
4. **Mais** le symptôme visible sur `V(t)` passe par un **seuil dur** :
   le clamp `s'' ∈ [−25 ; +25]`. Sans ce clamp, le spike serait plus pointu
   encore ; avec lui, on obtient un pulse rectangulaire qui intègre ~0,6 m/s
   de ΔV en 30 ms.

Donc : **pas le signal “on a atteint la limite des fenêtres”**. Il reste au
moins un (probablement deux) mécanismes localisés de la même famille —

| Pulse | τ | `τ_r` / u | Famille |
|---|---|---|---|
| Sat. accélératrice retour → Vmax | 0,59–0,61 | τ_r 0,14–0,19 | transition tronc→slide |
| Sat. freineuse retour (juste après) | 0,63–0,64 | τ_r 0,24–0,28 | suite entrée slide |
| Sat. accélératrice drive (post-Vmin) | 0,29–0,31 | u ≈ legs_end | sortie fenêtre jambes |

…plus le rôle du **clamp ±25** comme amplificateur d’amplitude intégrée
(créneau vs spike). Réétager / adoucir ces transitions (même traitement que
les précédents) est encore le bon levier ; regarder l’amplitude globale du
terme inertiel **sans** d’abord retirer ces saturations localisées serait
prématuré.

## Ce que ce rapport ne fait pas

Aucune correction ici — vue d’ensemble seule, comme demandé.
