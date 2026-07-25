# Etat de construction — session 1

## Ce qui est en place et fonctionne

| Element | Etat |
|---|---|
| Arborescence, `pyproject.toml`, separation en 3 couches | OK |
| `params/defaults.yaml` gele, chaque valeur sourcee (`src: L/E/N`) | OK |
| `data/segment_masses.csv` (De Leva) — somme verifiee a 100,0000 % | OK |
| `data/blade_coefficients.csv` — **approximation analytique, pas Caplan & Gardner** | a remplacer |
| `core/geometry.py` — conventions de signe centralisees | OK |
| `core/body.py` — chaine sagittale, CI de jambe, bassin non tournant | OK |
| `core/forces.py` — palette portance/trainee, coque simple + ITTC, aero, fluides | OK |
| `core/dynamics.py` — tabulation de phase + derivation spectrale | OK |
| `core/solver.py` — `solve_ivp`, decoupage en coups, bilan energetique | OK |
| `tests/test_conventions.py` — 5 tests de geometrie et cinematique | **verts** |
| `tests/test_conservation.py` | non concluant (voir plus bas) |

Temps de calcul : **44 s** pour 20 coups. Cible du brief : < 1 s. Non tenu.

## Bugs reels trouves et corriges

1. **Sur-extension de jambe.** Le defaut `x_ankle_off_m = -0.42` plus une course
   de coulisse de 0,72 m placait la hanche hors de portee de la jambe en fin de
   propulsion. La cinematique inverse saturait en silence et injectait un pic
   d'acceleration de **3 858 m/s²** dans le terme inertiel, donc dans tout le
   bilan energetique. Corrige a -0,17 m, avec un controle explicite
   (`BodyModel._check_leg_reach`) qui leve une erreur parlante.
2. **Empilement du sequencage.** Jambes, tronc et bras acceleraient simultanement.
   Ajout de `seq_legs_end` et `seq_trunk_end` pour etager les fenetres.
3. **Bassin tournant.** Les 43,46 % du tronc pivotaient autour de la hanche,
   bassin compris. Le bassin suit le siege sans tourner : table scindee en
   `pelvis` (11,17 %) et `upper_trunk` (32,29 %).

## Le probleme de fond — DECISION REQUISE

Le modele **sur-determine le coup**. On impose a la fois :

- l'arc d'aviron (58° a -34°, soit 92°)
- la duree de propulsion (`drive_fraction` x periode = 0,70 s)

Ces deux contraintes fixent la vitesse de balayage **independamment de la
vitesse du bateau**. La palette est donc forcee dans l'eau a une vitesse
imposee de l'exterieur.

Mesure sur la propulsion, dernier coup :

```
glissement palette vx : min -1,41  max +6,35  moyen +1,35 m/s
|v_rel| moyen         : 3,30 m/s        (aviron correct : 0,5 - 1,0)
bout de palette pic   : 8,64 m/s        vs coque a 6,69 m/s
```

La palette dissipe donc enormement. Consequences en cascade :

| Grandeur | Obtenu | Cible brief 8.2 |
|---|---|---|
| Rendement de palette | **0,224** | 0,75 - 0,85 |
| Puissance par rameur | **2 730 W** | ~420 W |
| Vitesse moyenne | 6,69 m/s | 5,8 - 6,1 |
| Fluctuation intra-coup | **±1,84 m/s** | ±0,25 - 0,40 |
| Temps 2 000 m | 299 s | 320 - 340 s |

Aucune de ces valeurs ne se corrige en ajustant un parametre — et le brief
interdit de le tenter. C'est la fermeture du modele qui est fausse.

### Fermeture correcte

Le brief 3.7a proposait le profil de force a la poignee comme entree primaire.
Il faut y revenir :

- **entree** : profil de force a la poignee `F(tau)` (parametrique ou issu de
  Concept2 / OpenRowingMonitor)
- **etat supplementaire** : angle d'aviron `theta`, gouverne par
  `I_oar * theta'' = M_poignee + M_palette`
- **consequence** : le glissement de palette s'auto-regule. Si le rameur pousse
  plus fort, la palette accroche et le bateau accelere ; il ne peut pas balayer
  plus vite que l'eau ne le permet.
- **cinematique corporelle** : reste prescrite, mais ne pilote plus l'aviron.
  Elle alimente uniquement le terme inertiel `sum(m_i * s_i'')`.

Le systeme passe de 1 a 3 etats (`V`, `theta`, `theta'`). Risque a surveiller :
sans couplage main-corps, un profil de force trop fort peut emballer la rotation
de l'aviron. Prevoir une butee de fin de course et un test de stabilite.

## A faire ensuite, dans cet ordre

0. **Chargeur multi-classes — manquant, confirme.** `params.py` ne lit que
   `defaults.yaml`. Les 8 fichiers `params/classes/*.yaml` (avec leur
   mecanisme `hull_ref` vers `data/hull_moulds.csv`) existent mais ne sont
   consommes par aucun code. Le brief §11 prevoyait cette piece (`boat_class.py`
   + chargeur fusionnant defaults + classe) **avant** de retoucher le solveur —
   sautee en session 1. A ecrire : une fonction qui fusionne `defaults.yaml`
   avec `classes/<code>.yaml`, et qui resout `hull_ref` en remplacant les
   cotes composites par celles du moule nomme quand il est renseigne.
   `n_rowers` doit en sortir dynamique — `defaults.yaml` fixe aujourd'hui
   `crew.phase_offset_ms` et `crew.mass_kg` a des listes de longueur 8 en
   dur, ce qui casse toute classe autre que 8+/8x.
1. Basculer sur la fermeture pilotee par la force (ci-dessus).
2. Refaire tourner `test_plausibility` — c'est le seul juge.
3. Rendre `dE_kinetic` **independant** : il est actuellement calcule comme le
   residu de l'identite qu'il est cense verifier, donc `test_energy_balance_closes`
   est trivialement vrai. Le calculer par `integrale( somme(m_i s_i'') * V ) dt`.
4. Performance : viser < 1 s. Pistes — relacher `max_step`, vectoriser les 8
   postes en une seule passe, ne calculer `internal_forces` qu'a la demande.
5. `test_triangulation` contre Atkinson / van Holst / Roosendaal.
6. Seulement ensuite : capteurs virtuels, estimation, analyse, interface.
