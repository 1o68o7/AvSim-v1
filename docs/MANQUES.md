# Ce qui manque pour construire la web app

*Consolidation au 24 juillet 2026 · complète le brief v2.0*

---

## 0. Ce qui est acquis

**Base de coques : close.** 182 moules, 6 constructeurs (Filippi, Empacher,
Hudson, WinTech, Swift, Vespoli), 8 classes. Le huit de pointe s'appuie sur
17 moules lourds de 6 constructeurs, médiane 17,42 m, étendue 82 cm. Cette
médiane n'a pas bougé de plus de 2 cm sur les trois derniers ajouts de
constructeur : la géométrie de référence est stable, inutile d'en chercher un
septième.

**Acquis également :** masses de coque (WinTech, = minima réglementaires
confirmés, plus une gamme club chiffrée), gréement (Filippi order form :
écartements, hauteurs, réglages de cale-pieds), avirons (Empacher : masses,
inboard, longueurs, surfaces de palette au cm²), anthropométrie (De Leva).

---

## 1. Bloquants physique — sans eux, rien ne tourne juste

| # | Manque | État | Effort |
|---|---|---|---|
| P1 | **Fermeture pilotée par la force** (brief §4.1) | code v1 a la mauvaise fermeture, diagnostiqué | 1-2 j |
| P2 | **Module d'enveloppe** (brief §3) | spécifié, pas écrit | 1 j |
| P3 | **Performance < 1 s** (mesuré 44 s) | leviers identifiés (brief §6) | 0,5 j |
| P4 | `dE_kinetic` calculé **indépendamment** | actuellement résidu → test trivial | 2 h |

Ces quatre-là se traitent en code, sans donnée extérieure. C'est le chemin critique.

## 2. Bloquants données — introuvables en catalogue

| # | Manque | Pourquoi c'est bloquant | Comment l'obtenir |
|---|---|---|---|
| D1 | **Longueur de flottaison** | entre dans Re, donc C_f | estimée à 0,986·LOA (catégorie N) — acceptable |
| D2 | **Surface mouillée** | facteur direct de la traînée | estimée par loi d'échelle — acceptable en relatif |
| D3 | **Coefficient de traînée réel** | échelle absolue du bilan énergétique | **essais de décélération libre** |
| D4 | **CdA aérodynamique** | 60 % d'incertitude sur 5-10 % du bilan | essais + anémomètre, ou accepter l'incertitude |
| D5 | **Coefficients de palette mesurés** | fichier actuel = approximation analytique | Caplan & Gardner (2007), à retrouver |
| D6 | **Table de triangulation** Atkinson / van Holst / Roosendaal | le test de crédibilité central du modèle | article de comparaison publié — **sorties** Atkinson/Kleshnev sur shelwork.htm ; **entrées** appariées listées sans valeurs sur comprslt.htm (2026-07-26) → skip quantitatif documenté |

**D3 est le vrai verrou.** Sans lui, le bilan énergétique reste un indice
relatif et ne passe jamais en watts absolus — donc le dashboard entraîneur
plafonne. Deux sorties suffisent, c'est gratuit, mais ça demande un équipage
(question Q10 du CSV).

## 3. Bloquants humains

| # | Manque | Question CSV |
|---|---|---|
| H1 | Profils de force à la poignée (paramétrique ou Concept2 réel) | Q04 |
| H2 | Masses et tailles réelles de l'équipage | Q05 |
| H3 | Accès équipage pour les essais de calibration | Q10 |

## 4. Bloquants environnement

| # | Manque | Question CSV |
|---|---|---|
| E1 | **Traces de vent réelles à la résolution du coup** | Q08 (station de rive) |
| E2 | Modèle de courant du bassin retenu | Q09 (Bordeaux ou Vichy) |

E1 est le seul moyen de trancher la question « anémomètre embarqué ou station
de rive ». Les modèles publics (AROME 1,3 km, pas 15 min) donnent le contexte,
jamais la structure des rafales.

## 5. Décisions produit en attente

| # | Décision | Question CSV |
|---|---|---|
| S1 | Ordre de validation des classes | Q01 |
| S2 | Périmètre de l'app (local / club / en ligne) | Q02 |
| S3 | Fidélité du schéma de bateau (statique / animé / 3D) | Q03 |
| S4 | Couple : un angle partagé ou deux indépendants | Q06 |

## 6. À écrire — couches non commencées

- `core/envelope.py`, `core/boat_class.py`
- `sensors/` — 12 modèles de bruit
- `estimation/ekf.py` — code partagé avec l'embarqué
- `analysis/` — Sobol, observabilité, détectabilité, Pareto
- `api/` — FastAPI, 8 points d'entrée
- `web/` — React + Vite + Plotly, composant schéma de bateau adaptatif

---

## 7. Réserves à porter dans le code

**Coques partagées.** Le double et le quatre de couple n'ont qu'une seule cote
propre chacun (Empacher). Tout le reste est une coque partagée pointe/couple.
L'accord inter-constructeurs sur ces deux classes est donc partiellement un
artefact.

**Huit de couple.** Aucun constructeur sauf Swift ne publie de ligne 8x. Swift
publie une page unique « Racing Shells 8+/x » avec moules partagés et mention
explicite des octuples — preuve directe de partage de coque. Drapeau
`hull_source = 'shared_mould_8plus'` à conserver.

**Qualité des sources.** Trois incohérences relevées chez les constructeurs
eux-mêmes : Hudson S4.21 annoncé 39'6" mais 12,3 m (39'6" = 12,04 m) ;
WinTech décrit la taille HW-S comme allongée de 0,6 m/poste alors que sa propre
table donne 41 cm sur un huit ; Vespoli affiche « 61 - 675kg » pour le VHP53
(lire 74,8 kg) et réutilise les noms VHP39/VHP41 avec des longueurs
différentes entre le 4-/x et le 4+. Les conversions ont été refaites depuis les
pieds-pouces et les livres, plus précis que les valeurs métriques arrondies.

---

## 8. Ordre recommandé

1. **P1 → P4** (code pur, aucune dépendance externe)
2. **D5, D6** (recherche documentaire, débloque la validation)
3. **Réponses au CSV** → S1-S4, H1-H2
4. **Station de rive installée** → E1 commence à s'accumuler pendant le dev
5. Couches capteurs → estimation → analyse
6. **Web app en dernier**
7. **D3, D4** par essais terrain — seul chemin vers les watts absolus
