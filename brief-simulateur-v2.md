# Brief de construction — Simulateur multi-classes d'aviron

*Version 2.0 · juillet 2026 · remplace la v1.0*
*Destine a Claude Code ou Cursor. Document autoportant.*

---

## 0. Ce qui change depuis la v1.0

| Sujet | v1.0 | v2.0 |
|---|---|---|
| Classes de bateau | huit de pointe uniquement | **8 classes**, couple et pointe, avec ou sans barreur |
| Fermeture du modele | cinematique (fausse, cf. §4.1) | **pilotee par la force** |
| Domaine de validite | absent | **module de premiere classe** (§3) |
| Rendu | Streamlit local | **application web** FastAPI + React |
| Retours de la session 1 | — | integres en §12 |

La v1.0 a ete partiellement implementee. Trois bugs reels en sont sortis et
sont documentes en §12 : les relire **avant** d'ecrire du code evite de les
reproduire.

---

## 1. Objectif

Construire un simulateur physique local, multi-classes, qui :

1. calcule la dynamique du systeme coque + rameurs + barreur + avirons ;
2. produit le **bilan energetique decompose** (propulsion, trainee hydro,
   trainee aero, pertes de palette, echange cinetique) ;
3. **emule chaque capteur candidat** avec son bruit, sa quantification, sa latence ;
4. repond a la question qui commande le budget materiel : **quels capteurs
   changent reellement la reponse ?**
5. le tout accessible par une **application web** qui affiche les grandeurs
   **poste par poste**, quelle que soit la classe de bateau.

**Critere de succes unique** : pouvoir dire « le capteur X, a Y euros et Z
grammes, fait passer l'erreur sur la metrique M de A a B », pour chaque
capteur de la nomenclature. Tout le reste est instrumental.

### Ce que le simulateur n'est pas

Ce n'est **pas une source de donnees**. Rien de ce qu'il produit n'est une
mesure. Aucune sortie ne doit etre presentee comme un resultat, ni servir de
reference normative.

### Le piege de circularite

Un simulateur ne se valide pas lui-meme. Si l'on ajuste les parametres jusqu'a
obtenir des courbes qui « ont l'air justes », on aura concu une instrumentation
pour un phenomene imaginaire.

**Regle non negociable** : tous les parametres physiques par defaut sont fixes
depuis la litterature referencee, ecrits dans `params/`, et **geles avant le
premier regard sur les sorties**. Toute modification ulterieure d'un defaut
exige une source citee dans le commit, jamais l'allure d'un resultat.

---

## 2. Classes de bateau

### 2.1 Abstraction

Une classe se decrit par quatre attributs orthogonaux. Tout le reste en decoule.

```python
@dataclass(frozen=True)
class BoatClass:
    code: str            # "1x", "2-", "2x", "4-", "4x", "4+", "8+", "8x"
    n_rowers: int        # 1, 2, 4, 8
    sculling: bool       # True = couple (2 avirons/rameur), False = pointe (1)
    coxed: bool          # presence d'un barreur
    rig_pattern: tuple   # pointe seulement : +1 tribord / -1 babord, par poste
```

**Ne jamais coder en dur le nombre 8.** Toute boucle, tout tableau, toute vue
de l'interface doit se dimensionner sur `n_rowers`. C'est la premiere source
de regression sur ce type de projet.

### 2.2 Couple contre pointe — ce qui change reellement

| Aspect | Couple (sculling) | Pointe (sweep) |
|---|---|---|
| Avirons par rameur | 2, symetriques | 1, d'un seul cote |
| Levier interieur | ~0,88 m par aviron | ~1,14 m |
| Levier exterieur (au centre de poussee) | ~1,75 m | ~2,26 m |
| Surface de palette | ~0,088 m² x2 = 0,176 m² | ~0,115 m² |
| Arc total | 108 - 118 deg | 88 - 96 deg |
| Moment de lacet | **nul par symetrie** | **non nul, a corriger a la barre** |
| Effort par main | reparti sur deux mains | une seule poignee |

Consequence de modelisation : en couple, les deux avirons partagent le meme
angle et les efforts s'additionnent sans composante laterale nette. En pointe,
chaque aviron cree un moment de lacet ; le desequilibre babord/tribord impose
une correction de barre, donc une **trainee additionnelle** que le modele doit
comptabiliser (v3, cf. §4.7).

### 2.3 Table de reference — chiffres verifies

Masses de coque = minima de la reglementation. Vitesses = meilleures
performances mondiales hommes, a utiliser comme **borne haute** et non comme
cible d'entrainement.

| Classe | Coque kg | Rameurs | Barreur | L_wl m | v_ref m/s | 2000 m |
|---|---|---|---|---|---|---|
| 1x  | 14 | 1 | non | 8,2  | 5,12 | 6:31 |
| 2-  | 27 | 2 | non | 10,4 | 5,47 | 6:05 |
| 2x  | 27 | 2 | non | 10,4 | 5,56 | 6:00 |
| 4-  | 50 | 4 | non | 13,4 | 5,92 | 5:38 |
| 4x  | 52 | 4 | non | 13,4 | 6,02 | 5:32 |
| 4+  | 51 | 4 | oui | 13,7 | 5,57 | 5:59 |
| 8+  | 96 | 8 | oui | 17,0 | 6,28 | 5:19 |
| 8x  | 96 | 8 | oui | 17,0 | 6,35 | 5:15 |

Barreur : masse minimale reglementaire 55 kg (hommes) / 50 kg (femmes).

### 2.4 Lois d'echelle — a implementer, pas a tabuler

Ne pas saisir huit jeux de coefficients independants : les deriver d'une seule
reference calee sur le 8+, ce qui garantit la coherence entre classes.

```
M_tot   = m_coque + n_rameurs * m_rameur + n_barreur * m_barreur
k_drag  = 13,0  * (M_tot / 855)^(2/3)
S_wet   = 11,5  * (M_tot / 855)^(2/3)
CdA     = 2,00  * (M_tot / 855)^(2/3)     [approximation, cf. avertissement]
```

**Verification effectuee** — la loi ci-dessus, calee uniquement sur le huit,
donne :

| Classe | M_tot kg | k_drag | S_wet m² | Trainee N | P/rameur W | Froude |
|---|---|---|---|---|---|---|
| 1x | 102 | 3,15 | 2,79 | 83 | 528 | 0,571 |
| 2- | 203 | 4,98 | 4,41 | 149 | 511 | 0,542 |
| 2x | 203 | 4,98 | 4,41 | 154 | 535 | 0,550 |
| 4- | 402 | 7,86 | 6,95 | 275 | 509 | 0,516 |
| 4x | 404 | 7,89 | 6,98 | 286 | 538 | 0,525 |
| 4+ | 458 | 8,57 | 7,59 | 266 | 464 | 0,481 |
| 8+ | 855 | 13,00 | 11,50 | 512 | 502 | 0,486 |
| 8x | 855 | 13,00 | 11,50 | 524 | 520 | 0,492 |

Deux controles independants passent :
- `k_drag` du skiff sort a **3,15**, la litterature attend 3,0 - 3,6 ;
- la puissance par rameur reste dans **464 - 538 W** sur les huit classes,
  cohérent avec les valeurs elites sur 2 000 m.

Ces deux accords ne sont pas construits : ils tombent d'une loi calee sur une
seule classe. C'est le meilleur argument disponible que l'echelle est juste.
Ils constituent le test `test_class_scaling`.

⚠️ La ligne `CdA` est la plus fragile : la trainee aerodynamique ne suit pas
la meme loi que la trainee hydrodynamique (nombre de corps, effet d'aspiration
en file). A traiter comme parametre a forte incertitude (§5, categorie N).

---

## 3. Domaine de validite — module de premiere classe

**C'est la section la plus importante de la v2.0.**

Un simulateur qui accepte n'importe quel jeu de parametres explorera des
configurations qu'aucun equipage ne peut produire dans aucun bateau. Les
conclusions sur les capteurs seraient alors tirees d'une physique qui n'arrive
jamais sur l'eau — ce qui invaliderait tout le projet, puisque son but est
precisement de choisir des capteurs pour un bateau reel.

### 3.1 Le probleme des contraintes couplees

Un simple echantillonnage dans des bornes independantes produit majoritairement
des points impossibles. On ne peut pas tenir simultanement :

- une cadence de 20 coups/min,
- une force pic de 900 N,
- une puissance de 500 W.

Ces trois grandeurs sont liees par la mecanique du coup. Echantillonner chacune
dans sa boite fabrique des rameurs qui n'existent pas.

**Consequence methodologique majeure** : les indices de Sobol calcules sur un
echantillonnage en boite seraient biaises, parce qu'une grande part de la
variance viendrait de regions physiquement inaccessibles. Le module de
sensibilite (§8) doit donc **rejeter ou reponderer** les points hors domaine,
et le rapport doit indiquer le taux de rejet. Un taux superieur a 60 % signale
que les bornes elles-memes sont mal posees.

### 3.2 Contraintes physiologiques (par rameur, elite masculin)

| Grandeur | Plage admissible | Butee dure |
|---|---|---|
| Force pic a la poignee, pointe | 600 - 1 100 N | 1 400 N |
| Force pic par main, couple | 300 - 550 N | 700 N |
| Force moyenne sur la propulsion | 45 - 65 % du pic | — |
| Puissance moyenne sur 2 000 m | 250 - 520 W | 600 W |
| Puissance instantanee | — | 1 500 W |
| Vitesse moyenne de poignee | 2,2 - 3,2 m/s | 4,0 m/s |
| Vitesse pic de poignee | 2,8 - 4,2 m/s | 5,0 m/s |
| Vitesse pic de coulisse | 1,2 - 2,0 m/s | 2,5 m/s |
| Amplitude de bascule du tronc | 40 - 70 deg | 85 deg |
| Cadence | 12 - 46 coups/min | 50 |
| Fraction de propulsion | 0,33 - 0,52 | — |

Note : les butees dures sont des impossibilites ; les plages sont des domaines
d'exploitation normaux. Sortir d'une plage produit un avertissement, franchir
une butee produit un rejet.

### 3.3 Contraintes geometriques et mecaniques

| Controle | Regle |
|---|---|
| Portee de jambe | `abs(x_cheville) + L_coulisse < 0,985 * (L_jambe + L_cuisse)` |
| Extension de bras | l'extension calculee doit rester dans `[0,10 ; 1,00] * L_bras` |
| Immersion de palette | profondeur entre 0,10 et 0,30 m ; sinon ventilation ou enfoncement |
| Butee d'aviron | `theta` doit rester entre les angles d'attaque et de degage +/- 5 deg |
| Nombre de Froude | `0,40 < Fr < 0,62` ; au-dela la trainee de vague devient dominante |
| Fluctuation de vitesse | `+/- 0,15` a `+/- 0,50 m/s` selon la classe |
| Rendement de palette | `0,68 < eta < 0,92` ; en dehors, le modele de palette est faux |
| Glissement de palette | `abs(v_rel)` moyen sur la propulsion entre 0,4 et 1,4 m/s |

Le controle de portee de jambe et celui d'extension de bras ne sont pas
theoriques : ils ont chacun attrape un bug reel en session 1 (§12).

### 3.4 Contraintes environnementales

L'aviron ne se pratique pas dans toutes les conditions. Simuler un huit par
15 m/s de vent de travers produit des chiffres, pas de la connaissance.

| Grandeur | Entrainement | Competition |
|---|---|---|
| Vent | jusqu'a 10 m/s | annulation courante au-dela de 6 - 8 m/s de travers |
| Clapot | < 0,25 m | < 0,15 m |
| Temperature d'eau | 2 - 30 C | — |
| Courant | jusqu'a 1,5 m/s | bassin en principe sans courant |

### 3.5 Enveloppe experimentale — la contrainte d'Antoine

Au-dela de la physique, une contrainte propre a ce projet : **le simulateur ne
doit pas explorer des configurations impossibles a valider sur l'eau**. Le
resultat attendu est une decision d'achat de capteurs, qui sera ensuite
confrontee a des sorties reelles.

Chaque scenario porte donc un attribut `validable_sur_eau` :

- l'equipage disponible peut-il produire cette cadence et cette puissance ?
- la classe de bateau est-elle accessible au club ?
- les conditions environnementales se rencontrent-elles sur le plan d'eau ?
- la duree de la sequence est-elle compatible avec une seance ?

Un capteur dont la valeur n'apparait que hors de cette enveloppe est un
capteur qu'il ne faut pas acheter, meme si l'analyse le classe bien.

### 3.6 Interface du module

```python
# src/avsim/core/envelope.py

class Severity(Enum):
    OK = 0
    WARNING = 1      # hors plage normale, simulation autorisee
    REJECT = 2       # impossible, simulation refusee

@dataclass
class Violation:
    rule: str            # identifiant stable, ex. "physio.handle_peak_force"
    severity: Severity
    value: float
    bound: float
    message: str         # redige pour l'utilisateur, pas pour le journal

def check_inputs(P: dict, cls: BoatClass) -> list[Violation]:
    """Controles a priori, avant integration. Rapides."""

def check_outputs(result, P: dict, cls: BoatClass) -> list[Violation]:
    """Controles a posteriori : rendement, glissement, fluctuation, Froude."""

def is_admissible(violations) -> bool:
    return not any(v.severity is Severity.REJECT for v in violations)
```

**Regles d'usage, non negociables :**

1. `check_inputs` s'execute avant toute integration.
2. `check_outputs` s'execute apres chaque simulation, et son resultat est
   attache a l'objet resultat.
3. Les modes d'analyse (§8) **n'agregent que des points admissibles** et
   rapportent le taux de rejet.
4. L'application web affiche l'etat d'enveloppe en permanence, et le detail
   des violations au clic.
5. Aucun export de donnees ne part sans son statut d'enveloppe.

---

## 4. Modele physique

### 4.1 La fermeture — corriger l'erreur de la v1.0

La v1.0 prescrivait a la fois l'arc d'aviron et la duree de propulsion. Ces deux
contraintes fixent la vitesse de balayage **independamment de la vitesse du
bateau**. La palette est alors forcee dans l'eau a une vitesse imposee de
l'exterieur, elle dissipe enormement, et tout le bilan s'effondre : rendement
mesure a 0,22 au lieu de 0,80, puissance de 2 730 W par rameur au lieu de 500.

**Fermeture correcte : la force est l'entree, l'angle est un etat.**

- **Entree** : profil de force a la poignee `F_h(tau)`, parametrique ou importe
  de Concept2 / OpenRowingMonitor.
- **Etat supplementaire par rameur** : `theta`, `theta_point`, gouvernes par
  l'equilibre en rotation de l'aviron.
- **Consequence** : le glissement de palette s'auto-regule. Un rameur qui pousse
  plus fort fait accrocher la palette ; il ne peut pas balayer plus vite que
  l'eau ne l'autorise.

### 4.2 La poignee est la coordonnee maitresse

Corollaire de 4.1, et il resout un defaut de la v1.0 : la chaine corporelle
produisait une course de mains de 1,84 m la ou la geometrie n'en admettait que
1,60 m, ecart absorbe par un facteur de renormalisation arbitraire.

Nouvelle construction, sans facteur de fudge :

1. `theta(t)` vient de l'integration ⇒ position de poignee `x_poignee(t)`.
2. Le **sequencage repartit** cette course entre les segments, en fonction de
   la position dans le coup `u` (et non du temps absolu) — c'est d'ailleurs
   ainsi que les entraineurs le decrivent :
   ```
   x_siege(u) = L_coulisse * part_jambes(u)
   phi(u)     = phi_attaque + (phi_degage - phi_attaque) * part_tronc(u)
   ```
3. L'extension de bras est **deduite** par fermeture geometrique exacte :
   ```
   e(u) = x_siege(u) + L_tronc * sin(phi(u)) - x_poignee(u)
   ```
4. `e(u)` doit rester dans `[0,10 ; 1,00] * L_bras`. **Sinon, ce n'est pas une
   erreur numerique : c'est une combinaison de sequencage impossible.** Le
   controle remonte comme violation d'enveloppe, plus comme correctif silencieux.

### 4.3 Equation du mouvement — cavalement

Bilan de quantite de mouvement sur le systeme entier, ce qui elimine toutes
les forces internes :

```
(m_coque + M) * dV/dt = F_prop - D_coque - D_aero - somme(m_i * d2s_i/dt2)
```

`M` = masse totale des rameurs, `s_i` = position du CdM du rameur i relative a
la coque. **Le terme `somme(m_i * s_i'')` est le sujet du projet** : c'est lui
qui cree la fluctuation intra-coup, lui que mesurent coulisses et pods dorsaux,
et lui sur lequel les modeles publies divergent. Il se calcule explicitement,
jamais par une masse ponctuelle.

### 4.4 Equation de l'aviron

Par rameur (en couple, les deux avirons partagent `theta`, les efforts doublent) :

```
I_aviron * d2(theta)/dt2 = M_poignee + M_palette
M_poignee = L_in * F_h(t)          (force normale au manche)
M_palette = r_palette x F_palette   (composante z)
```

**Phase de propulsion** : `theta` est un etat, integre.
**Evenement de degage** : declenche quand `theta <= theta_degage`.
**Phase de retour** : palette hors de l'eau, donc plus de force hydrodynamique.
`theta` suit une trajectoire d'Hermite quintique de `(theta_degage,
theta_point_au_degage)` vers `(theta_attaque, 0)` sur la duree restante.

La cadence reste une **entree** ; la duree de propulsion devient une **sortie**.
Si la duree de propulsion issue de la force depasse la periode imposee par la
cadence, la combinaison force/cadence est infaisable ⇒ violation d'enveloppe.
C'est physiquement juste : on ne peut pas ramer a 40 avec une force de traction
qui demande une seconde de propulsion.

### 4.5 Efforts hydrodynamiques

**Palette** — modele portance/trainee. La palette est un profil, pas un point
d'appui : elle glisse, et ce glissement est la premiere source de perte.

```
v_palette/eau = ( V + L_out*cos(theta)*theta_point , -L_out*sin(theta)*theta_point )
alpha         = angle entre v_relative et le plan de la palette
F_L = 0,5 * rho_eau * A_palette * C_L(alpha) * |v_rel|^2
F_D = 0,5 * rho_eau * A_palette * C_D(alpha) * |v_rel|^2
```

Coefficients `C_L`, `C_D` : tabuler dans `data/blade_coefficients.csv`.
⚠️ Le fichier livre en session 1 contient une **approximation analytique de
plaque portante**, pas les valeurs mesurees. Il porte un drapeau
`blade_coeff_source='analytic'` qui doit remonter jusqu'aux exports. A remplacer
par des donnees mesurees des que disponibles ; l'ecart pres de l'attaque est
significatif.

**Coque** — deux niveaux, les deux implementes :
```
simple :  D = k_drag * |V|^n * signe(V)                      n ~ 2,0
ITTC   :  Re = V*L_wl/nu(T_eau)
          C_f = 0,075 / (log10(Re) - 2)^2
          D_f = 0,5*rho*S_mouillee*C_f*(1+k_forme)*V^2   + trainee de vague f(Fr)
```
Entre 5 et 25 C, `nu` varie d'environ 35 %, ce qui deplace `C_f` de plusieurs
pour-cent. C'est exactement le genre d'effet que le simulateur doit chiffrer
pour decider si la sonde de temperature merite sa place.

**Air** :
```
V_apparent = V_fond + vent_axial
D_aero = 0,5 * rho_air(T,P,H) * CdA * V_apparent^2 * signe(V_apparent)
```

### 4.6 Anthropometrie

Fractions de masse segmentaire selon De Leva (1996), table 4, dans
`data/segment_masses.csv`. Somme verifiee a 100,0000 % — c'est un test unitaire.

⚠️ Le tronc doit etre **scinde** : le bassin (11,17 %) suit la coulisse **sans
tourner** autour de la hanche, seul le tronc superieur (32,29 %) pivote. Faire
tourner les 43,46 % en bloc surestime la course du CdM.

⚠️ Les pieds sont **fixes** sur le cale-pieds. Seuls jambe et cuisse tournent.
Le genou se resout par cinematique inverse a deux barres, ancree a la cheville.

### 4.7 Specificites de la pointe (v3, apres que la v1 fonctionne)

Chaque rameur tire d'un seul cote. A modeliser :
- force laterale par aviron ⇒ moment de lacet instantane
- motif de gréement (alterne, italien, allemand) ⇒ moment residuel different
- desequilibre babord/tribord ⇒ lacet ⇒ **correction de barre ⇒ trainee ajoutee**
- hauteurs de mains inegales ⇒ roulis

Peu de litterature accessible traite correctement ce point : c'est une piste de
differenciation, mais elle vient **apres** que les tests de plausibilite passent
en cavalement seul.

---

## 5. Parametres

Organisation en trois fichiers :

```
params/defaults.yaml        parametres communs, independants de la classe
params/classes/<code>.yaml  specifique a la classe (masse, longueur, greement)
params/scenarios/*.yaml     scenarios nommes (regate, entrainement, vent de face)
```

Chaque parametre porte : valeur, borne min, borne max, source.
Code source : `L` litterature ou reglement, `E` estimation d'ingenierie,
`N` mal connu, a traiter en incertitude.

Parametres a forte incertitude, a surveiller dans l'analyse de sensibilite :
`CdA`, `S_mouillee`, `facteur_forme`, `I_aviron`, coefficients de palette.

---

## 6. Resolution numerique

- Etat : `[x, V, theta_1..theta_n, theta_point_1..theta_point_n]`, soit `2 + 2n`.
- Integrateur : `solve_ivp`, methode **LSODA** ou **Radau** (raide a l'attaque).
- `rtol=1e-8`, `atol=1e-10`. Test de convergence : resserrer d'un ordre, la
  vitesse moyenne ne doit pas bouger de plus de 0,1 %.
- Sortie reechantillonnee a **200 Hz**, meme frequence que le bus reel.
- Evenements : degage detecte par `solve_ivp(events=...)`, pas par balayage.
- Regime etabli : simuler 20 coups, jeter les 10 premiers, analyser les 10 derniers.
  Verifier une derive inferieure a 0,5 % entre les deux derniers coups.

### Performance — exigence dure

**Une simulation de 20 coups doit tenir sous 1 seconde sur un coeur.** Les modes
B, C et D lancent des dizaines de milliers d'evaluations ; au-dela d'une seconde
ils deviennent inexploitables. La session 1 a mesure 44 s : inacceptable.

Leviers, dans cet ordre :
1. **Tabuler la cinematique corporelle** sur une grille de phase a la
   construction, puis interpoler. Elle ne depend que de la phase, jamais de la
   vitesse. Deriver par differences finies dans le membre de droite coute trois
   evaluations completes de la chaine corporelle par appel du solveur.
2. **Vectoriser les n postes** en une seule passe, jamais de boucle Python.
3. Ne calculer les efforts internes qu'a la demande, pas dans le membre de droite.
4. Relacher `max_step`, verifier ensuite la convergence.
5. En dernier recours seulement : `numba` sur les boucles chaudes.

### Note sur la derivation

Les trajectoires assemblees par fenetres presentent des pics d'acceleration que
le corps humain ne produit pas — le systeme neuro-musculaire a une bande
passante finie. Tronquer la serie de Fourier a une dizaine d'harmoniques de la
frequence de coup est **justifie physiquement**, pas cosmetiquement, et rend le
signal exactement derivable par voie spectrale (ni bruit de differences finies,
ni sonnerie de Gibbs sur la derivee seconde). Exposer `kin_harmonics` comme
parametre : l'analyse de sensibilite dira s'il compte.

---

## 7. Capteurs virtuels

Chaque capteur candidat est une classe qui prend la verite terrain et retourne
ce que le vrai capteur aurait produit. **Le realisme du bruit prime sur le
realisme de la physique** : la question n'est pas « ce capteur mesure-t-il la
bonne grandeur » — oui, par construction — mais « avec son bruit, sa
quantification et sa latence reels, permet-il de resoudre ce qui m'interesse ».

Chaque modele inclut : bruit blanc, biais, derive lente, quantification, bande
passante, sensibilite thermique, frequence d'echantillonnage.

| Capteur | Reference | Fe | Erreurs a modeliser | Cout | Masse |
|---|---|---|---|---|---|
| Force dame | jauges + ADS131M04 | 200 Hz | 20-21 bits effectifs ; non-linearite 0,05 % PE ; hysteresis ; derive 0,002 %PE/C ; **sensibilite parasite a l'effort axial** | 95 EUR | 60 g |
| Angle dame | AS5600 | 200 Hz | 12 bits = 0,088 deg ; INL 0,3 deg ; excentration d'aimant | 4 EUR | 10 g |
| Coulisse | VL53L1X | 100 Hz | sigma 1-3 mm ; **degradation forte en plein soleil** | 12 EUR | 8 g |
| Force pieds x2 | shear-beam 100 kg | 200 Hz | 0,03 %PE ; hysteresis ; derive | 60 EUR | 400 g |
| Pod dorsal | ICM-42688-P | 100 Hz | accel 70 ug/rtHz ; gyro 2,8 mdps/rtHz ; **derive de biais** ; artefacts de fixation sur tissu mou | 28 EUR | 30 g |
| IMU coque | ICM-42688-P | 200 Hz | idem + vibration structurelle | 28 EUR | 25 g |
| GNSS standard | NEO-M9N | 10 Hz | 1,5 m CEP ; vitesse 0,05 m/s ; multitrajet berge | 45 EUR | 30 g |
| GNSS RTK | ZED-F9P | 10 Hz | 1-2 cm ; vitesse 0,02 m/s ; **perte de fix sous les arbres** | 270 EUR | 60 g |
| Impeller | NK | ~1 Hz | 1-2 % apres etalonnage ; non lineaire sous 2 m/s ; salissure | 80 EUR | 50 g |
| Anemo rive | Ecowitt WS80 | **0,06 Hz** | 0,3 m/s ; **periode 16 s, rafales invisibles** | 100 EUR | 0 |
| Anemo embarque | Calypso / FT205 | 1-4 Hz | 0,5 m/s ; perturbation d'ecoulement autour du bateau | 350-600 EUR | 200 g |
| Temperature eau | DS18B20 | 0,2 Hz | 0,5 C ; constante de temps ~10 s | 6 EUR | 15 g |

### 7.1 Synchronisation et bus — a ne pas negliger

La metrique centrale du tableau de bord entraineur est un ecart de timing entre
rameurs de **20 a 50 ms**. Tout ce qui degrade l'horodatage attaque directement
le produit.

A modeliser explicitement :
- gigue d'horodatage CAN : arbitrage, latence de file, derive d'horloge par
  noeud (20 ppm typique sans discipline PPS) ;
- charge de bus : `n` noeuds x 2 trames de 8 octets a 200 Hz. Pour 8 postes cela
  fait 3 200 trames/s, soit environ **70 % d'occupation a 500 kbit/s**. Au-dela
  de 60 %, la latence d'arbitrage devient erratique ;
- discipline PPS du GNSS, avec et sans ;
- liaison sans fil des pods : gigue et pertes de paquets (0,1 a 2 %).

**Question a laquelle le simulateur doit repondre explicitement** : quelle
precision de synchronisation faut-il pour detecter un decalage de 30 ms entre
deux rameurs avec 95 % de confiance ? Si la reponse est la milliseconde,
l'architecture actuelle tient. Si c'est 100 microsecondes, il faut repenser le bus.

⚠️ Le controleur CAN integre a l'ESP32-S3 ne fait que du CAN classique, pas du
CAN-FD. Si la conclusion est qu'il faut du FD, chaque noeud demande un
controleur externe : ce n'est pas un ajustement, c'est un redesign. Le
simulateur doit trancher **avant** l'achat.

---

## 8. Modes d'analyse

Tous les modes n'agregent que des points **admissibles au sens du §3**, et
rapportent leur taux de rejet.

### Mode A — Exploration interactive
Curseurs sur tous les parametres, mise a jour des courbes et du bilan.
Construit l'intuition et sert de demonstration.

### Mode B — Sensibilite globale (Sobol)
Echantillonnage de Saltelli, indices du premier ordre et totaux pour chaque
metrique de sortie : vitesse moyenne, temps sur 2 000 m, amplitude de
fluctuation, rendement de palette, chaque poste du bilan.

Un parametre dont l'indice total reste sous 0,02 sur toutes les metriques est
un parametre qu'on peut fixer grossierement — donc un capteur a ne pas acheter.

Budget : 10 000 a 50 000 evaluations. D'ou l'exigence de la seconde.

### Mode C — Observabilite et valeur du capteur ← **le livrable**

Pour chaque sous-ensemble de capteurs `S` :
1. tirer une verite terrain avec des parametres connus, dans l'enveloppe ;
2. generer les sorties bruitees des seuls capteurs de `S` ;
3. faire tourner **l'estimateur reel** — le meme filtre que le calculateur
   embarque — en n'utilisant que `S` ;
4. comparer a la verite terrain sur chaque metrique de tableau de bord ;
5. repeter sur au moins 200 tirages.

Parcours : selection avant gloutonne, selection arriere, puis enumeration
exhaustive sur les sous-ensembles de 4 a 7 capteurs autour des optima.

Sorties : table « capteur → gain par metrique », **front de Pareto** erreur/cout
et erreur/masse, borne de Cramer-Rao, test de rang d'observabilite.

Question type a trancher : *peut-on estimer le CdM equipage a +/- 2 cm avec les
coulisses seules, ou les pods dorsaux sont-ils indispensables ?* Decision a
225 EUR et 280 g portes, prise avant achat.

### Mode D — Detectabilite des defauts

| Defaut injecte | Amplitude | Question |
|---|---|---|
| Rameur k en retard | 30 / 50 / 80 ms | detectable en combien de coups ? |
| Rameur k precipite la coulisse | +30 % de vitesse de retour | seuil ? |
| Asymetrie d'appui aux pieds | 15 % | faut-il deux capteurs par cale-pied ? |
| Palette trop profonde | +3 cm | signature dans l'acceleration de coque ? |
| Attaque tardive | -5 deg | resoluble avec un encodeur 12 bits ? |

Sortie : **taille d'effet minimale detectable** a p<0,05 par jeu de capteurs, et
nombre de coups necessaires. C'est ce qui calibre les seuils d'alerte du
tableau de bord barreur — pas des seuils inventes.

---

## 9. Validation

A ecrire **en premier**, a faire echouer, puis a satisfaire.

### 9.1 Unitaires
- somme des fractions de masse segmentaire = 100,00 % +/- 0,01
- a l'attaque, vitesse de la palette par rapport a l'eau proche de zero
- a mi-propulsion, le glissement se fait **vers la poupe** (c'est ce qui propulse)
- conservation : residu du bilan sur un coup etabli < 0,5 %
- vent et courant nuls ⇒ vitesse fond = vitesse eau
- decalages tous nuls ⇒ les `n` postes strictement identiques
- un decalage de 50 ms produit une trace differente
- convergence numerique < 0,1 %

⚠️ Le terme d'echange cinetique doit etre calcule **independamment**, par
`integrale( somme(m_i * s_i'') * V ) dt`. En session 1 il etait obtenu comme
residu de l'identite qu'il etait cense verifier : le test etait trivialement vrai.

### 9.2 Plausibilite, par classe

| Grandeur | Cible |
|---|---|
| Vitesse moyenne | dans +/- 8 % de `v_ref` de la table §2.3 |
| Puissance par rameur | 420 - 540 W au rythme de reference |
| Rendement de palette | 0,75 - 0,85 |
| Part trainee hydro | 70 - 80 % |
| Part pertes de palette | 15 - 25 % |
| Part aero, air calme | 5 - 10 % |
| Fluctuation intra-coup | +/- 0,25 a 0,40 m/s (8+) ; jusqu'a +/- 0,50 (1x) |
| Glissement moyen | 0,4 - 1,4 m/s |

### 9.3 Coherence inter-classes — `test_class_scaling`

Verifier que la loi d'echelle du §2.4, **calee sur le seul 8+**, reproduit :
- `k_drag` du skiff entre 3,0 et 3,6 ;
- une puissance par rameur dans 420 - 560 W sur les huit classes.

Ces deux accords ne sont pas construits ; ils tombent de la loi. C'est le
meilleur controle disponible que l'echelle est juste.

### 9.4 Triangulation — le test le plus important

Reproduire la comparaison publiee entre les modeles d'Atkinson, van Holst et
Roosendaal avec les memes entrees, et verifier que notre decomposition de
puissance tombe **dans la dispersion des trois**.

Ecarts connus entre eux : environ 1 % sur la dissipation de palette, environ
5 % sur les puissances a la dame, a la poignee et en trainee de coque,
**divergence nettement plus forte sur la dissipation dans le corps du rameur et
l'echange cinetique coque/rameur**.

Consequence strategique directe : si le modele tombe dans la fourchette sur les
postes consensuels, il est credible. Et **la zone ou les trois modeles divergent
est exactement la cible d'instrumentation** — c'est la que la mesure apporte ce
que le calcul ne donne pas. Produire un graphique explicite de cette divergence :
c'est l'argument central du projet.

---

## 10. Application web

### 10.1 Architecture

```
Navigateur  ──HTTP/WS──►  FastAPI (uvicorn, local)  ──►  noyau avsim
                                   │
                                   └──►  file de taches (modes B/C/D)
                                              └──►  Parquet sur disque
```

Tout tourne en local, sans compte, sans reseau sortant. Un seul processus a
lancer.

| Couche | Choix |
|---|---|
| Backend | FastAPI + uvicorn |
| Frontend | React + TypeScript + Vite |
| Graphiques | Plotly.js |
| Schema d'echange | Pydantic cote serveur, types generes cote client |
| Taches longues | `BackgroundTasks` en local ; WebSocket pour l'avancement |
| Etat client | Zustand ou contexte React, pas de Redux |

Le frontend est **compile et servi par FastAPI** en production locale : une
seule commande, un seul port.

### 10.2 Points d'entree

```
GET  /api/classes                  liste des classes et leurs defauts
GET  /api/params/{code}            parametres par defaut d'une classe
POST /api/validate                 controles d'enveloppe seuls, sans integration
POST /api/simulate                 une simulation, retourne courbes + bilan + enveloppe
POST /api/jobs/sweep               lance un mode B/C/D, retourne un identifiant
GET  /api/jobs/{id}                etat et resultats
WS   /ws/jobs/{id}                 avancement en direct
GET  /api/export/{id}?fmt=parquet  export
```

`/api/validate` est appele a chaque modification de curseur, avec anti-rebond.
Il est peu couteux et donne un retour immediat sur l'admissibilite **avant**
de lancer un calcul.

### 10.3 Le composant central — schema de bateau adaptatif

C'est la reponse a la demande de visualisation poste par poste, quelle que soit
la classe.

Un composant SVG unique, pilote par `BoatClass` :

- dessine `n_rowers` postes, espaces selon `d_seat`, plus le barreur si present ;
- **couple** : deux avirons symetriques par poste ;
  **pointe** : un aviron, du cote donne par `rig_pattern` ;
- chaque poste est **cliquable** ⇒ ouvre son detail ;
- chaque poste est **colore par une metrique au choix** dans un selecteur :
  decalage de phase, force pic, longueur d'arc, vitesse de coulisse, puissance,
  rendement — echelle divergente centree sur la mediane de l'equipage ;
- superposition optionnelle de l'angle d'aviron instantane, anime sur le coup ;
- le barreur affiche les trois chiffres temps reel.

Ce composant doit fonctionner sans modification de 1 a 8 postes. **Le tester
explicitement sur les huit classes** — c'est la regression la plus probable.

### 10.4 Vues

| Vue | Contenu |
|---|---|
| **Bateau** | schema adaptatif ci-dessus, selecteur de metrique, detail au clic |
| **Coup** | force poignee, force dame, angle, vitesse et acceleration de coque, coulisse, bascule du tronc — sur un coup normalise, avec bandes min/max sur les 10 coups analyses |
| **Bilan** | diagramme de Sankey : puissance rameurs → propulsive / pertes palette / trainee hydro / trainee aero / cinetique. Plus un histogramme comparant la decomposition a celles d'Atkinson, van Holst et Roosendaal |
| **Equipage** | une ligne par poste : decalage, force pic, timing d'attaque. Carte de chaleur des ecarts. Vue « qui traine » |
| **Capteurs** | signaux bruts tels qu'ils sortiraient de chaque capteur, superposes a la verite terrain, curseur d'amplification du bruit |
| **Observabilite** | selecteur de sous-ensemble, table d'erreur, front de Pareto cout/erreur et masse/erreur |
| **Sensibilite** | indices de Sobol en barres triees, taux de rejet d'enveloppe affiche |
| **Detectabilite** | injecteur de defaut, resultat : detectable ou non, en combien de coups, avec quels capteurs |

**Barre d'etat permanente** : classe · vitesse moyenne · temps 2 000 m ·
cadence · rendement de palette · **pastille d'enveloppe**. La pastille passe a
l'ambre sur avertissement, au rouge sur rejet, et son clic liste les violations.

### 10.5 Regles de redaction de l'interface

- Nommer par ce que l'utilisateur controle, pas par l'implementation :
  « decalage du rameur 4 », jamais `phase_offset_idx3`.
- Chaque valeur affichee porte son unite.
- Aucune valeur sans son incertitude quand elle en a une.
- Un etat vide ou une erreur explique quoi faire, jamais un message generique.
- Les donnees simulees sont **identifiables partout** ou elles apparaissent.

---

## 11. Depot et ordre de construction

```
avsim/
├── pyproject.toml · CLAUDE.md · README.md
├── params/  defaults.yaml · classes/*.yaml · scenarios/*.yaml
├── data/    blade_coefficients.csv · segment_masses.csv · force_curves/ · wind_traces/
├── src/avsim/
│   ├── core/       boat_class · params · geometry · body · forces · dynamics ·
│   │               solver · energy · envelope
│   ├── sensors/    base · loadcell · angle · tof · imu · gnss · impeller ·
│   │               anemometer · bus
│   ├── estimation/ ekf (code partage avec l'embarque) · metrics
│   ├── analysis/   sobol · observability · detectability · pareto
│   ├── io/         export · validation
│   ├── api/        app · routes · schemas · jobs
│   └── cli.py
├── web/            src/components · src/views · src/api · vite.config.ts
└── tests/          test_conventions · test_conservation · test_envelope ·
                    test_class_scaling · test_plausibility · test_triangulation
```

### Ordre imperatif

1. `tests/test_conventions.py` et `test_conservation.py` — **avant tout code de physique**
2. `core/boat_class.py` + `core/envelope.py` — **avant le solveur**, pour que rien
   ne tourne hors domaine des le premier jour
3. `core/` : params → geometry → body → forces → dynamics → solver → energy
4. `test_plausibility`, `test_class_scaling`, `test_triangulation` —
   **ne pas avancer tant qu'ils echouent**
5. `io/export.py` et schema de donnees
6. `cli.py` mode `run`
7. `sensors/` — un capteur a la fois, chacun avec son test de bruit
8. `estimation/ekf.py`
9. `analysis/` : sobol → observability → detectability
10. `api/` puis `web/` — **l'interface en dernier**

Ne pas construire l'interface avant que la triangulation passe. Une belle
application sur une physique fausse est le pire resultat possible du projet.

---

## 12. Retours de la session 1 — a lire avant de coder

Trois bugs reels, tous silencieux, tous attrapes par les tests ou par un
controle explicite.

**1. Sur-extension de jambe.** Un decalage de cheville de -0,42 m combine a une
course de coulisse de 0,72 m placait la hanche hors de portee de la jambe en fin
de propulsion. La cinematique inverse saturait sans rien signaler et injectait un
pic d'acceleration de **3 858 m/s²** dans le terme inertiel, donc dans tout le
bilan energetique. Aucune exception, aucun avertissement.
⇒ Le controle de portee de jambe (§3.3) est **obligatoire** et doit lever une
erreur parlante, pas saturer.

**2. Empilement du sequencage.** Jambes, tronc et bras accelerant simultanement
produisent des accelerations non physiologiques. Il faut des fenetres etagees,
et la fermeture geometrique du §4.2 les contraint desormais explicitement.

**3. Bassin tournant.** Faire pivoter les 43,46 % du tronc autour de la hanche
surestime la course du CdM : le bassin **est** la hanche. Table scindee.

Et l'erreur de conception principale, corrigee au §4.1 : **prescrire a la fois
l'arc et la duree de propulsion sur-determine le coup**. Symptomes a surveiller
comme signature de rechute — rendement de palette autour de 0,2, puissance par
rameur au-dela de 1 500 W, glissement moyen superieur a 2 m/s.

---

## 13. Contenu de CLAUDE.md

```markdown
# Simulateur aviron — regles de travail

## Principe directeur
Ce simulateur sert a decider quels capteurs acheter. Toute decision de
conception se tranche par : est-ce que ca change la reponse a cette question ?

## Interdits
- Ne JAMAIS ajuster un parametre par defaut pour ameliorer l'allure d'un
  resultat. Les defauts sont geles et sources ; toute modification exige une
  reference dans le commit.
- Ne jamais coder en dur le nombre de postes. Tout se dimensionne sur n_rowers.
- Ne jamais importer FastAPI, React ou Plotly dans src/avsim/core/.
- Ne jamais agreger un point hors enveloppe dans une analyse.
- Ne jamais presenter une sortie du simulateur comme une mesure.
- Ne pas passer a l'etape suivante avec des tests rouges.

## Obligations
- Tout parametre physique porte son unite dans son nom ou son type.
- Toute constante a un commentaire avec sa source.
- Toute fonction de core/ est pure et testable sans entrees-sorties.
- L'EKF de estimation/ est destine a tourner tel quel sur le calculateur
  embarque : pas de dependance lourde.
- Toute simulation retourne son statut d'enveloppe, et tout export le porte.

## En cas de doute sur la physique
Demander plutot que deviner. Une convention de signe fausse se propage
silencieusement dans tout le bilan energetique.
```

---

## 14. Criteres de recette

1. Les six suites de tests passent, dont la triangulation et la coherence
   inter-classes.
2. Une simulation de 20 coups tourne **sous 1 seconde** sur un coeur.
3. Les huit classes simulent, et le schema de bateau s'affiche correctement de
   1 a 8 postes, en couple comme en pointe.
4. `avsim observe` produit le front de Pareto cout/erreur pour toute la
   nomenclature.
5. On repond, chiffres a l'appui, aux cinq questions suivantes :
   - les pods dorsaux sont-ils necessaires, ou les coulisses suffisent-elles ?
   - anemometre embarque, ou station de rive suffisante compte tenu des rafales ?
   - RTK ou GNSS standard ?
   - combien de postes instrumenter en force pour reconstruire les autres ?
   - CAN 500 kbit/s suffit-il pour une synchronisation a 30 ms ?
6. Le format d'export est identique au schema cible, et un tableau de bord
   developpe sur donnees simulees tourne sans modification sur un fichier reel.

---

## 15. Ce que ce simulateur ne pourra jamais faire

A ecrire dans le README, pour eviter la derive d'usage.

- Il ne remplace pas la calibration terrain. Les coefficients de trainee reels
  de la coque avec l'equipage reel s'obtiennent par essais de deceleration
  libre, pas par simulation.
- Il ne fournit aucune norme. Il ne dira jamais si un score de glisse de 0,78
  est bon.
- Il ne valide pas ses propres hypotheses. La divergence entre modeles publies
  sur l'energie du corps du rameur reste ouverte — c'est precisement ce que le
  materiel devra trancher.
- Il ne prouve rien sur la performance du produit. Il oriente une decision
  d'achat, ce qui est deja beaucoup.
