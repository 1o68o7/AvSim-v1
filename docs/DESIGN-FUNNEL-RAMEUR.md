# Design utilisateur — Funnel rameur

**Version** : 3.3  
**Date** : 3 octobre 2026  
**Statut** : proposition de parcours et d’écrans  
**Parcours** : inspiré des apps d’entraînement les plus utilisées (ROXFIT, Runna, FORMD, RoxHype)  
**Distances et KPI** : Fédération Française d’Aviron et standards aviron indoor. Aucune distance Hyrox, aucun KPI de station course.

Sources FFA : page « L’aviron indoor en compétition » (distance de référence 2 000 m, sprint 500 m, 5 000 / 6 000 / 10 000 m, relais 4 × 500 m et 8 × 250 m), championnats indoor (500 / 1 000 / 2 000 m), évaluation fédérale (2 000 m Concept2, facteur de résistance), brevets indoor (ateliers cadence + 10 km / 21 km / 42 km), courses en ligne (500 à 2 000 m selon catégorie).

---

## 1. Intention

Le parcours se comporte comme une app d’entraînement : une séance du jour, un preview, un play, une preuve. Les grandeurs affichées restent celles du rameur fédéral.

Promesse :

> « Ton 2 000 m. Tu connais le temps au 500 à tenir, tu lances, tu logues. »

Critère de succès : **un 2 000 m terminé et logué**, avec temps, split /500 m, cadence et watts. Pas une fiche vidéo.

Le 2 000 m est la distance de référence FFA en indoor et le test de l’évaluation fédérale. Le 500 m est le format sprint. Le funnel n’invente pas d’autre distance hero.

---

## 2. Ce qu’on prend aux apps d’entraînement

Uniquement le parcours. Pas leurs métriques.

| Pattern | Source | Traduction rameur |
|---|---|---|
| Séance du jour, un tap | FORMD, RoxHype, ROXFIT | Carte `Aujourd’hui · 2 000 m` + Start |
| Preview puis go | ROXFIT | Format, drag factor, split cible, 3 cues |
| Diagnostic avant le play | FORMD | Temps projeté sur 2 000 m, pas un chrono de course |
| Allure cible sur la séance | Runna | Split /500 m cible |
| Player + prochain bloc | RoxHype | 500 m par 500 m, buzz au passage |
| Vert / rouge versus cible | ROXFIT | Écart au temps et au split, pas un classement de station |
| Plan qui se décale | Runna | Si le 2 000 m est sauté, il revient en tête |
| Streak + PB | ROXFIT | PB sur les distances FFA seulement |

---

## 3. Distances conservées

Affichées telles quelles. Pas de conversion en « station ».

### Indoor — FFA

| Format | Statut | Usage dans le funnel |
|---|---|---|
| 2 000 m | Distance de référence, évaluation fédérale, championnats | Séance hero, PB principal |
| 500 m | Sprint, championnats, relais 4 × 500 m | Séance courte, atelier brevet |
| 1 000 m | Championnats indoor, atelier brevet (temps annoncé, 990–1 010 m) | Format intermédiaire, pas le hero |
| 4 × 500 m | Relais championnats de France FFA | Séance équipage, lot 2 |
| 8 × 250 m | Relais championnats de France FFA | Séance équipage, lot 2 |
| 5 000 m | Paysage indoor FFA | Endurance, hors premier funnel |
| 6 000 m | Paysage indoor FFA, ordre de grandeur des têtes de rivière junior / senior | Endurance, hors premier funnel |
| 10 000 m | Paysage indoor + brevet 10 km | Brevet endurance |
| 21 km | Brevet semi-marathon | Brevet, pas le funnel d’entrée |
| 42 km | Brevet marathon | Brevet, pas le funnel d’entrée |

### Eau — pour étiqueter le profil, pas pour remplacer l’erg

Distances maximales des courses en ligne FFA : J11–J12 500 m, J13–J14 1 000 m, J15–J16 1 500 m, J17–J18 2 000 m, vétéran 1 000 m, para-aviron 2 000 m. Têtes de rivière : souvent 3 000–4 000 m jeune, 6 000 m junior et senior.

Si la catégorie est connue, la home rappelle la distance d’eau. Le player reste sur ergomètre.

### Ateliers brevet indoor niveau 1 — à ne pas remplacer par un format libre

- 500 m programmés avec pace boat, cadence 24
- Temps annoncé sur 1 000 m, réalisé entre 990 et 1 010 m
- 5 min continu, cadence 18
- 3 × 1 min à cadence 18 / 22 / 26, en longueur
- Réglage cale-pieds, écrans du moniteur

Ces ateliers sont des séances nommées, pas des exercices de bibliothèque.

---

## 4. KPI conservés

Ce qui se lit sur le PM, ce qui se logue, ce qui sert de preuve. Rien d’autre en hero.

| KPI | Unité | Rôle |
|---|---|---|
| Temps | mm:ss, ou h:mm:ss au-delà de 60 min | Résultat de la distance |
| Distance | m | Résultat d’un format temps (5 min, relais) |
| Temps au 500 m | m:ss /500 m | Split instantané et split moyen |
| Cadence | coups/min | Cible brevet ou consigne de morceau |
| Puissance | watts | Affichée avec le split, pas à la place |
| Facteur de résistance | drag factor | Réglage logué. Évaluation J16 : max 110 filles, 120 garçons. J18, senior, para : libre |

Interdits en hero et en KPI de funnel : calories, classement de station, temps de course global, « +48 s vs le milieu », distance autre que la liste FFA.

Vert / rouge = écart au temps cible ou au split cible du morceau, sur une distance FFA.

---

## 5. Onboarding — première visite

L’onboarding n’est pas le funnel séance. Il sert à savoir **qui rame** et **dans quel cadre**, puis à poser le premier morceau. Il s’affiche une fois, au premier lancement, ou au premier QR erg si aucun profil local n’existe.

Quatre questions maximum. Le compte vient après la première preuve. Une branche ne voit pas les questions des autres.

### Règles

- Pas de tab bar. Retour conservé. Une décision par écran.
- Le compte n’est pas demandé. Le profil tient en local jusqu’au premier log complet.
- Aucune branche n’est un fourre-tout « autre ». Loisir, Aviron Santé, compétition, para et para adapté ont chacun un premier morceau.
- Skip : `Plus tard` seulement après le choix de pratique. Il ouvre un 15 min loisir, sans split cible.
- Déjà un compte : lien texte sur l’écran 0, pas un mur.
- Deuxième ouverture : onboarding non rejoué.
- QR erg : même parcours, le brief « je suis devant » est déjà coché.
- On ne demande pas de diagnostic médical. Para, adapté et Handi-Santé sont des cadres de pratique, pas des formulaires de santé.

### Parcours

```
[0] Promesse
      │
      ▼
[1] Pratique            loisir · santé · compétition · para
      │
      ├── Loisir ──────────────► temps dispo → home 15 / 30 min
      ├── Aviron Santé ────────► créneau 15–60 min → home
      ├── Compétition ─────────► catégorie FFA → temps déjà fait → diagnostic
      └── Para / adapté ───────► cadre → format temps, pas un 2 000 m imposé
```

### Écran 0 — Promesse

- Titre : `Un morceau déjà écrit. Tu sais quoi lire sur le moniteur.`
- Trois lignes : temps au 500 · cadence · watts. Le drag factor si tu es en compétition.
- CTA : `Commencer`
- Lien : `J’ai déjà un compte`

La promesse ne dit pas « ton 2 000 m » : ce n’est pas le morceau de tout le monde.

### Écran 1 — Pratique

Question : `Tu rames dans quel cadre ?`

| Carte | Qui | Premier morceau |
|---|---|---|
| Loisir | Salle, club loisir, sans licence course | 15 ou 30 min, cadence libre, split affiché |
| Aviron Santé | Créneau santé FFA, retour progressif | 15, 30, 45 ou 60 min, les 4 programmes indoor santé |
| Compétition | Licence course, indoor ou eau | Branche catégories |
| Para-aviron | Classification fonctionnelle, ou en cours | Format temps ou distance de sa classe, jamais imposé |
| Para-aviron adapté | Handicap mental, psychique ou TSA | 15 min guidé, cues courtes, pas de chrono hero |
| Handi-Santé | ALD ou MDPH, hors classification | Même formats que Aviron Santé |

Une seule carte. Suite auto.

### Branche loisir

Pas de catégorie d’âge obligatoire. Tranche demandée seulement si l’utilisateur a moins de 15 ans, pour plafonner la durée.

- Temps réel : 15 min (préselectionné) ou 30 min
- Déjà ramé : oui / non. Non = brief geste obligatoire
- Home : `Aujourd’hui · 20 min` n’existe pas. Seulement 15 ou 30, alignés sur les durées santé pour ne pas inventer un format
- KPI lus : temps, distance, split /500 m, cadence, watts. Drag factor affiché, pas exigé
- Le 2 000 m est dans l’onglet Distances, pas sur la carte du jour
- Passage compétition : lien `J’ai une licence course` dans Moi, ouvre la branche compétition sans refaire l’écran 0

### Branche Aviron Santé

Programmes indoor FFA : 15, 30, 45, 60 min. Accessibles aux débutants. Les programmes bateau (5 à 25 km) ne sont pas proposés ici.

- Créneau : 15 min au premier lancement. 30 / 45 / 60 débloqués après un 15 min logué
- Intensité : cadence basse, pas de cible de split au premier morceau
- KPI : temps tenu, distance, cadence moyenne. Split en secondaire
- Pas de vert / rouge sur un temps. La preuve dit `Créneau tenu` ou `Partiel gardé`

### Branche compétition

Écran catégorie, libellés du code indoor FFA (âges atteints dans l’année de licence).

| Groupe | Sous-catégories | Effet |
|---|---|---|
| Jeune | U10 (≤ 9), U12 (10–11), U15 (12–14, classements J12 J13 J14) | Pas de 2 000 m. U10 : animation, pas une course. U12 : 500 m max. U15 : 1 000 m max |
| Junior | 15–18 ans, J15 à J18 | J15–J16 : 1 500 m max en ligne, test erg 2 000 m possible à l’évaluation, DF max 110 filles / 120 garçons. J17–J18 : 2 000 m |
| Senior | 19 ans et plus | 2 000 m référence. Poids léger indoor : 75 kg homme, 61,5 kg femme |
| Master | 27 ans et plus | 1 000 m rappelé pour l’eau vétéran. Indoor : 500 et 2 000 m restent disponibles |

Puce optionnelle : poids léger, seulement senior et master. Eau : 72,5 / 59 kg skiff, moyenne équipage 70 / 57 kg. Indoor : 75 / 61,5 kg. L’app affiche le plafond du cadre choisi, elle ne pèse personne.

Puis : `Déjà un temps ?` — 2 000 m, 1 000 m, 500 m, ou aucun. Un jeune ne voit pas la saisie d’une distance au-dessus de son plafond.

Diagnostic : temps projeté seulement sur une distance autorisée pour la catégorie. U12 sans temps → 500 m. Senior sans temps → 500 m puis 2 000 m. Senior avec un 2 000 m → ce 2 000 m est la carte du jour.

### Branche para-aviron

- Classe connue : PR1, PR2, PR3, ou `Pas encore classé`
- Pas encore classé : format 15 min, comme le loisir, mention `La classe se pose avec le club, pas dans l’app`
- Classe connue : distance de course de la classe si elle est renseignée par le club, sinon 1 000 m temps, pas un test maximal au premier lancement
- Aucun plafond de drag factor inventé. Réglage libre, logué

### Branche para-aviron adapté

- Pas de classe AB / BC / CD demandée au premier écran. Lien `Ma classe` vers Moi, rempli plus tard
- Premier morceau : 15 min, une cue à la fois, boutons larges
- Preuve sans écart rouge. `Temps tenu` et distance

### Branche Handi-Santé

Même mécanique qu’Aviron Santé. Pas de pièce compétition proposée tant que l’utilisateur ne change pas de cadre.

### Après l’onboarding

| État | Prochaine home |
|---|---|
| Loisir ou santé, aucun log | Carte 15 ou 30 min |
| Compétition sans temps | Carte au plafond de la catégorie (500, 1 000 ou 2 000 m) |
| Compétition avec temps | Carte de cette distance |
| Para non classé | Carte 15 min |
| Skip | Carte 15 min loisir, bandeau `Précise ton cadre` |

Le compte est proposé à la preuve du premier log : `Garder ce temps`. Notifications et Bluetooth au moment où ils servent.

Quitte avant la pratique : reprise à l’écran quitté, 7 jours. Après le choix de pratique, la carte est posée, prochaine ouverture = home.

---

## 6. Funnel

```
[H] Home
      carte « Aujourd’hui · 2 000 m »
        │
        ▼
[1] Catégorie        âge FFA + poids si léger, pas une division course
        │
        ▼
[2] Diagnostic       temps 2 000 m projeté, split /500 m
        │
        ▼
[3] Preview          distance officielle, drag factor, cadence, cues
        │
        ▼
[4] Brief            cale-pieds, damper → drag factor, écran /500 m
        │
        ▼
[5] Player           temps, split, cadence, watts, mètres restants
        │
        ▼
[6] Preuve           temps, split moyen, cadence moy., watts moy., drag factor
        │
        ▼
[7] Suite            même distance à J+3, ou 500 m si le 2 000 m est trop long
```

Le morceau du jour vient de l’onboarding. Loisir et Aviron Santé ouvrent sur 15 ou 30 min. Compétition ouvre sur la distance plafond de la catégorie. L’écran Catégorie du funnel est sauté s’il a déjà été rempli.

---

## 7. Écrans

### H — Home

Trois lignes, modèle app d’entraînement, grandeurs aviron.

- `PB 2 000 m · 7:42` ou `Pas de 2 000 m logué`
- `Split moyen · 1:55 /500 m`
- `Cadence moy. · 26`
- Carte : `Aujourd’hui · 2 000 m` + `Start`
- Sous la carte : facteur de résistance rappelé (`DF 115`)

Onglets : Home · Plan · Distances · Moi.  
L’onglet Distances liste les formats FFA, pas huit stations.

### 1 — Catégorie

- Âge : J11–J12, J13–J14, J15–J16, J17–J18, senior, master. Sert à plafonner la distance d’eau rappelée et le drag factor J16.
- Poids, optionnel : léger homme 70 kg (72,5 kg skiff), léger femme 57 kg (59 kg skiff). N’ouvre pas un autre format.
- Déjà un 2 000 m ? Oui (mm:ss) / Non.

Pas de date de course hybride. Si une date de régate ou de championnat indoor existe, elle alimente le countdown. Sinon pas de countdown.

### 2 — Diagnostic

- Hero : `2 000 m · 7:48`
- Sous-texte : `1:57 /500 m`
- Ligne : `500 m de découverte d’abord` si aucun log
- CTA : `Lancer` (ouvre le 500 m ou le 2 000 m selon le cas)
- Les autres distances FFA en liste grise, avec leur PB ou `—`

### 3 — Preview

Fiche du morceau officiel.

**2 000 m**

- Drag factor libre, rappel J16 si concerné (110 / 120 max)
- Affichage moniteur : /500 m, cadence, watts
- Découpe : 0–500 installation, 500–1 500 tenu, 1 500–2 000 cadence +2
- CTA : `Je suis sur l’erg`

**500 m** (première fois ou sprint)

- Pace boat si l’atelier brevet est choisi, cadence 24
- Sinon 500 m libre, split affiché quand même

Swap machine : aucun substitut. Si l’erg est pris, la séance est reportée. Un autre ergomètre ne se logue pas à la place.

### 4 — Brief

- Cale-pieds
- Damper jusqu’au drag factor cible (le damper seul ne suffit pas : deux erg au même cran n’ont pas le même DF)
- Écran /500 m
- CTA : `C’est parti`
- Skip dès la deuxième séance sur la même distance

### 5 — Player

- Hero : split instantané vs split cible
- Secondaires : mètres restants, cadence, watts
- Passage des 500 m : buzz, split du morceau qui se fige 3 s
- Stop → `Garder le partiel` préselectionné. Le partiel n’est un PB que s’il couvre la distance entière.

Sans capteur : temps final saisi au stop, distance choisie au preview. Pas de saisie coup par coup.

### 6 — Preuve

- Hero : temps sur la distance (`7:44` sur 2 000 m)
- Split moyen /500 m
- Cadence moyenne
- Watts moyens
- Drag factor de la séance
- Pastille verte si temps ≤ cible, rouge si au-dessus, écart en secondes
- `PB 2 000 m` seulement si la distance est complète
- CTA : `Poser la suivante`

### 7 — Suite

- `Même distance dans 3 jours`
- `500 m` si le morceau du jour était un 2 000 m
- Pas de format hors liste

---

## 8. Plan

Une fois le 2 000 m logué, la semaine tourne sur les distances FFA.

| Jour | Morceau | KPI lus |
|---|---|---|
| 1 | 5 min continu, cadence 18 | cadence, split |
| 2 | 3 × 1 min à 18 / 22 / 26 | cadence par bloc |
| 3 | 500 m, pace boat cadence 24 | temps, split |
| 4 | 2 000 m | temps, split moyen, watts |
| 5 | off ou 1 000 m annoncé (990–1 010 m) | distance réalisée vs temps annoncé |

Le 10 km n’entre qu’après un 2 000 m logué. Le 21 km rappelle le brevet 10 km. Le 42 km rappelle le semi.

---

## 9. Mesure produit

Les événements suivent les formats FFA. Pas d’événement « station ».

| Événement | Cible |
|---|---|
| `erg_start` | — |
| `erg_500_logged` | première distance, ≥ 50 % des starts sans PB |
| `erg_2000_logged` | référence, ≥ 40 % des profils ayant fini un 500 m |
| `erg_split_saved` | 100 % des logs complets |
| `erg_df_saved` | 100 % des logs capteur, saisie sinon |
| `erg_next_booked` | ≥ 50 % des 2 000 m complets |

Un log incomplet n’entre pas dans le PB ni dans le taux de référence.

---

## 10. Lots

1. 500 m et 2 000 m, KPI temps / split / cadence / watts / drag factor, preuve, replanif.
2. Ateliers brevet (5 min @ 18, 3 × 1 min, 1 000 m annoncé) et relais 4 × 500 m.
3. PM5, drag factor live, export logbook.
4. 5 000 / 6 000 / 10 000 m et brevets 10 / 21 / 42 km.
5. Dispos, composition d’équipage, veto plan d’eau, bascule indoor.

---

## 11. Eau impossible — équipage ou météo

Une sortie bateau n’est confirmée que si les deux portes sont ouvertes : l’équipage est complet, et le plan d’eau est autorisé. Sinon l’app ne laisse pas un créneau vide. Elle propose l’indoor, ou le rameur le choisit lui-même.

L’app ne décide pas à la place du club. La météo est un signal. L’interdiction de sortir vient du club ou du coach, pour le plan d’eau identifié.

### Lieu — club et plan d’eau

Deux objets distincts. Le club est la structure. Le plan d’eau est le bassin. Un club peut avoir plusieurs plans d’eau. Plusieurs clubs peuvent partager le même.

L’identification se fait à l’ouverture de l’app et au lancement d’une sortie, pas en continu. La permission est demandée à ce moment-là. Refus : choix manuel dans la liste, mémorisé.

| Signal | Résultat |
|---|---|
| Point dans le polygone du plan d’eau | Bassin nommé. Météo et veto de ce bassin |
| Point dans le géofence du club house ou du hangar | Club nommé. Équipage cherché dans ce club |
| Les deux | Club et plan d’eau affichés ensemble |
| Plusieurs clubs sur le même bassin | Liste courte, un tap, mémorisé pour ce lieu |
| GPS trop large, ou hors zone | `Choisir le club` / `Choisir le plan d’eau`. Pas de club deviné |

Référentiel : structures FFA (club, ligue, comité) et plans d’eau rattachés. Un club indoor seul n’a pas de plan d’eau : la géoloc ne propose que l’erg.

La licence est la source du profil, pas seulement du club. La carte FFA 2026-2027 (licence annuelle loisir) porte les champs que l’app lit, et qu’elle ne redemande pas.

| Champ carte | Exemple lu | Usage |
|---|---|---|
| Type | Annuelle loisir (AL) | Branche loisir. Une AC ouvrirait la compétition. II et E restent sans club |
| N° / identifiant | numéro de licence | Clé du compte. C’est l’identifiant MyFFA |
| Valable jusqu’au | 31/08/2027 | Saison 2026-2027. Périmée : bandeau, pas de composition |
| Nom, prénom | — | Affichage équipage. Pas une saisie |
| Genre | Homme | Plafond drag factor J16, catégorie de poids |
| Né·e le | date de naissance | Contrôle de la catégorie. Ne remplace pas le libellé carte |
| Nationalité | Français | Affiché, sans effet sur le morceau |
| Club | nom + code structure, ex. C033003 | Club d’appartenance. Clé de l’équipage et du plan d’eau rattaché |
| Catégorie | Sénior A | Plafond de distance. Senior : 2 000 m indoor disponible, pas imposé en AL |
| Surclassement | Non | Si Oui, la distance suit la catégorie de surclassement, pas l’âge seul |
| Classification handi | vide sur cette carte | Vide = pas de branche para. Renseignée = branche para, sans questionnaire |

AL ne déclenche pas le diagnostic 2 000 m. Le club est connu, le premier morceau reste 15 ou 30 min. Le 2 000 m est dans Distances. Une licence compétition, même carte, même champs, ouvre la branche compétition et le plafond de la catégorie.

L’onboarding avec licence liée saute l’écran Pratique et l’écran Catégorie. Il confirme : `Émulation nautique de Bordeaux · AL · Sénior A · jusqu’au 31/08/2027`, puis le temps dispo. Sans licence, le parcours à quatre questions reste.

### Import du PDF officiel

Oui. Le téléchargement MyFFA est un PDF TCPDF, une page A4, non chiffré, avec une couche texte. Les valeurs se lisent sans OCR : type `(AL)`, numéro, date de validité, nom, prénom, genre, date de naissance, nationalité, club et code `(C033003)`, catégorie, surclassement, numéro répété. La classification handi est lue seulement si la ligne n’est pas vide.

Entrée : `Importer ma licence`, fichier PDF, depuis l’écran 0 ou depuis Moi. L’app extrait, puis affiche la confirmation déjà prévue. Rien n’est écrit tant que le rameur n’a pas validé.

Si la couche texte est absente (scan, photo), OCR de repli, même écran de confirmation, champs douteux surlignés. Un PDF modifié par l’utilisateur remplit le profil, il ne prouve pas la licence. Le numéro reste une clé locale tant qu’il n’est pas recoupé avec MyFFA. L’import ne remplace pas cette vérification le jour où elle existe.

Fichier refusé : autre document, plusieurs pages illisibles, aucun code club et aucun numéro. Message : `Ce n’est pas une licence FFA lisible.` Pas de profil à moitié rempli.

Écriture après confirmation, et seulement là :

| Champ PDF | Table | Colonne |
|---|---|---|
| Nom + prénom | `rowers` | `display_name` |
| Né·e le | `rowers` | `birth_date` |
| Genre | `rowers` | `sex` |
| Type, n°, validité, catégorie, surclassement, classification | `licenses` | colonnes dédiées |
| Code structure `C033003` | `licenses` | `ffa_code` |
| Club nommé | `clubs` | rapprochement par `ffa_code`, pas par `short_code` |

Le PDF est parsé en mémoire puis jeté. Il n’entre pas dans `session_meta.storage_path`. Un second import met à jour `licenses` de la saison, il ne crée pas un second rameur si le numéro est le même.

### Compte Google

Le compte n’est pas demandé à l’écran 0. Il l’est à la première action qui doit survivre au téléphone : `Garder ce temps`, ou `Partager la fiche`.

Bouton unique : `Continuer avec Google`. Supabase Auth, provider Google. Pas de mot de passe à côté. Magic link reste le repli si Google est refusé.

À la réussite : `auth.users.id` est écrit dans `rowers.user_id` et `club_members.user_id`. Le profil déjà rempli par le PDF n’est pas ressaisi. Si un compte Google existe déjà avec ce `user_id`, on rattache le rameur, on ne duplique pas la ligne.

Sans compte, le morceau tient en local. Le partage d’équipage et la composition club exigent le compte : un lien WhatsApp doit ouvrir un rameur identifiable.

### Fiche bateau — partager pour constituer l’équipage

Depuis une sortie ou un bateau incomplet : `Partager la fiche`. Une fiche, pas un export de licence.

La fiche montre : club, bateau (`boats.name`, `class`, `seats`, `cox`), heure, sièges confirmés, sièges libres, côté si connu. Elle ne montre pas le numéro de licence, la date de naissance, ni le poids.

Partage : feuille système, donc WhatsApp, SMS, mail. Le message prérempli est `4x · 18:00 · 2 sièges libres` plus un lien `https://…/fiche/{token}`. Pas d’API WhatsApp. Pas d’envoi au nom du rameur.

Le lien ouvre l’app, ou une page minimale si l’app n’est pas installée. Le destinataire se connecte avec Google, puis :

- même `club_id` : bouton `Je prends le siège 3`, écriture dans `assignments` (`boat_id`, `rower_id`, `seat_index`, `side`, `role`)
- autre club : `Tu es à Y. Ta licence est à X.` Il peut prendre le siège pour ce créneau, club de licence inchangé
- sans licence : il voit la fiche, il ne prend pas de siège

Un siège pris disparaît de la fiche. Le token expire à la fin du créneau. Révoquer la fiche invalide le token, les sièges déjà confirmés restent.

---

La géoloc ne sert pas à deviner ce club. Elle sert à trois choses.

- Retrouver le plan d’eau du club, ou le bon bassin s’il en a plusieurs.
- Confirmer que le rameur est sur place. S’il est ailleurs, la sortie reste celle de son club, le veto affiché est celui du bassin de la séance, pas celui du lieu où il se trouve.
- Reconnaître une visite. Point dans le géofence d’un autre club : `Tu es à Y. Ta licence est à X.` Il peut composer ici pour le créneau, sans changer de club de licence.

Licence II ou E, ou pas de licence : pas de club imposé. La géoloc propose le club et le plan d’eau du lieu, à confirmer. Le loisir salle sans licence reste sur l’erg du lieu détecté.

Carte du jour, ligne de lieu : `Émulation nautique de Bordeaux · C033003 · plan d’eau détecté`. Le club et le code viennent de la licence. Le plan d’eau vient de la géoloc, ou du bassin rattaché au code club si le GPS est refusé. Changer de lieu est un lien, pas un réglage caché. Le veto météo suit le plan d’eau de la séance. L’équipage se cherche d’abord parmi les licences du même code club.

---

### Portes

```
Séance eau prévue
        │
        ├─ Porte équipage    tous les sièges + barreur si besoin, dispos croisées
        ├─ Porte plan d’eau  créneau club ouvert, pas de veto météo
        │
        ├─ les deux ouvertes ──► sortie bateau
        │                         lien « Je passe sur l’erg »
        │
        └─ une porte fermée ───► carte indoor déjà écrite
                                  raison affichée
```

### Disponibilités

Chaque rameur pose ses créneaux : matin, midi, soir, ou des heures. Une dispo est `eau`, `erg` ou `les deux`. Elle expire à la fin du jour.

Une sortie se monte dans un groupe de club, pas dans toute la base.

| Bateau | Sièges à pourvoir |
|---|---|
| 1x skiff | 1 |
| 2x / 2- | 2 |
| 2+ | 2 + barreur |
| 4x / 4- | 4 |
| 4+ | 4 + barreur |
| 8+ | 8 + barreur |

Le barreur a sa propre dispo. Son siège ne se remplit pas avec un rameur.

Composition, dans l’ordre :

1. Le groupe de la séance (le quatre habituel, pas le club entier).
2. Même catégorie d’âge. Un U15 ne complète pas un senior.
3. Côté si connu : babord / tribord. Couple : pas de côté exigé.
4. Poids léger seulement si la séance est étiquetée légère.
5. Les autres rameurs du club libres sur le créneau, en suggestion, jamais ajoutés sans oui.

États d’un siège : confirmé, en attente, absent, remplacé. La sortie passe à `complet` quand chaque siège a un oui. Un `en attente` à H-3 devient absent et relance la recherche.

Skiff : pas d’équipage à composer. Seule la porte plan d’eau compte. S’il est seul et que l’eau est ouverte, la sortie tient.

### Météo

Trois sources, une seule décision.

| Source | Effet |
|---|---|
| Veto club ou coach | Porte fermée. Raison : vent, orage, crue, glace, brouillard, navigation |
| Créneau club fermé | Porte fermée, même si le ciel est clair |
| Météo affichée | Vent, précipitations, température. N’interdit pas seul |

Le veto est un bouton coach : `Plan d’eau fermé` + motif. Il s’applique à un bassin et à une plage horaire, pas à un rameur. Lever le veto rouvre la porte pour ceux dont l’équipage est déjà complet.

L’app affiche le vent et la pluie pour que le rameur choisisse. Elle ne convertit pas un seuil de vent en interdiction.

### Bascule indoor

Déclencheurs :

- Équipage incomplet à H-3, ou au moment où le rameur ouvre l’app
- Plan d’eau fermé
- Choix du rameur, même si les deux portes sont ouvertes

La carte eau est remplacée, pas supprimée. Mention : `Eau annulée · équipage` ou `Eau annulée · plan d’eau` ou `Tu as choisi l’erg`.

Le morceau indoor reprend la distance de la séance eau, dans les plafonds déjà posés.

| Séance eau prévue | Erg proposé |
|---|---|
| 500 m | 500 m |
| 1 000 m | 1 000 m |
| 1 500 m | 1 500 m si la catégorie l’autorise, sinon 1 000 m |
| 2 000 m | 2 000 m |
| Tête de rivière 6 000 m | 6 000 m, ou 30 min si le rameur est loisir / santé |
| Loisir ou santé | 15 ou 30 min, jamais un 2 000 m imposé |

Le log est marqué `indoor · remplacement`. Il n’entre pas dans un classement bateau. Il entre dans le PB ergomètre de la même distance.

Équipage incomplet mais au moins deux oui : proposer un bateau plus court (4+ → 2x, 2x → 1x) avant l’erg. L’erg n’est le défaut que si personne d’autre n’est libre, ou si le rameur refuse le bateau court.

### Écrans

**Carte du jour, eau tenue**

- `18:00 · 4x · 2 000 m`
- `4/4 confirmés`
- `Plan d’eau ouvert`
- CTA : `Je sors`
- Secondaire : `Passer sur l’erg`

**Carte du jour, équipage cassé**

- `Il manque 1 siège`
- Noms en attente, bouton `Relancer`
- CTA : `Faire le 2 000 m sur l’erg`
- Secondaire : `Descendre en 2x` si deux oui existent

**Carte du jour, plan d’eau fermé**

- Motif du club en une ligne : `Vent · veto coach`
- Pas de bouton `Je sors`
- CTA : `Faire le 2 000 m sur l’erg`

**Choix rameur**

Depuis une carte eau ouverte : `Passer sur l’erg` demande une confirmation, prévient l’équipage `X passe à l’erg`, libère le siège, relance la composition. Pas de départ silencieux.

### Loisir et santé

Pas de composition de bateau. La météo ne ferme que si le club a mis un veto et que le créneau était une sortie d’initiation. Sinon le loisir est déjà indoor, ou le rameur choisit.

---

## 12. Hors scope

- Distances et classements Hyrox.
- Calories, zones de fréquence en hero.
- Substitut SkiErg logué comme un temps rameur.
- Interdiction météo automatique sans veto du club.
- Écriture directe dans Supabase depuis ce document. Le schéma ci-dessous est à migrer par Cursor.

---

## 13. Schéma Supabase — colonnes réelles

Inventaire du 3 octobre 2026. RLS déjà actif. Ne pas recréer ces tables. Ne pas relancer l’ancien `create table`.

`clubs` : `id`, `name`, `short_code`, `created_at`, `updated_at`. Pas de code FFA. `short_code` n’est pas `C033003` tant que ce n’est pas vérifié. Le code structure de la licence va dans une colonne ajoutée `ffa_code`, pas dans `short_code` par défaut.

`club_identity` : nom long, slogan, année, couleurs, blason. Pas un plan d’eau.

`club_members` : `club_id`, `user_id`, `role`, `rower_id`. Le rôle coach est ici. L’équipage se filtre par `club_id`.

`rowers` : `display_name`, `birth_date`, `sex`, `weight_kg`, `height_cm`, `side_pref`, `oar_spec`, `level`, `club_id`, `user_id`. C’est le profil. L’import PDF remplit ces champs. Il ne crée pas `profiles`. Manquent sur cette table : type de licence, numéro, validité, catégorie FFA, surclassement, classification handi. Ces champs vont dans `licenses`, liée par `rower_id`.

`rower_physio` : FC repos, HRV, consentement. Hors licence, hors séance erg.

`boats` : `class`, `seats`, `cox`, `status`. La composition lit `class` et `seats`, elle n’invente pas un type `4x` à part.

`boat_outs` : sortie eau. `club_id`, `boat_id`, `coach_id`, `started_at`, `planned_end`, `ended_at`, `status`, `crew_frozen`. Pas de distance, pas de plan d’eau, pas de motif météo. Le statut existant porte l’annulation. Ne pas créer `outings`.

`assignments` : siège. `boat_id`, `rower_id`, `seat_index`, `side`, `role`, `cox_position`. Lié au bateau, pas à `boat_outs`. La dispo d’équipage se lit ici plus `boat_outs.status`. Ne pas créer `outing_seats`.

`session_meta` : séance. `dist_m`, `duration_s`, `started_at`, `ended_at`, `rower_id`, `storage_path`. Pas de split, cadence, watts, drag factor. On ajoute ces quatre colonnes ici. Pas de table `erg_logs`. `storage_path` garde le payload, pas le PDF de licence.

`checkout_queue` : file de sortie bateau. Déjà le créneau coach. Ne pas la doublonner.

Ajouts, et seulement ceux-là :

- `licenses` (`rower_id`, `license_number`, `license_type`, `valid_until`, `ffa_code`, `category`, `surclassement`, `handi_classification`, `source`, `myffa_verified`). PDF non stocké.
- `waters` + `club_waters`, aucun plan d’eau n’existe.
- `water_closures` (`water_id`, plage, `reason`, `created_by`). Le veto ne rentre pas dans `boat_outs.status` seul : il ferme le bassin, pas une sortie.
- Quatre colonnes sur `session_meta` : `split_500_s`, `cadence`, `watts`, `drag_factor`, plus `origin` (`indoor` ou `remplacement`).

Règles : une AL ne crée pas un 2 000 m du jour. Log incomplet : pas un PB. `origin = remplacement` ne ferme pas un `boat_outs`. Licence périmée : pas d’`assignments` confirmé.

---

## 14. Instructions Cursor

Tu développes le parcours de ce fichier sur le schéma existant. Tu ne crées pas `profiles`, `outings`, `outing_seats`, `erg_logs` ni un second `clubs`. Tu ne relances pas le SQL de l’ancienne section 13.

### Parcours

1. Onboarding section 5. Sans licence : quatre questions. Avec PDF : confirmation, écriture dans `rowers` (`display_name`, `birth_date`, `sex`, `weight_kg`) et `licenses`. Jamais dans une table `profiles`.
2. Compte Google au premier `Garder ce temps` ou `Partager la fiche`. Supabase Auth. Rattacher `rowers.user_id`. Pas de second profil.
3. Carte du jour. AL, santé, para non classé : 15 ou 30 min. Compétition : distance plafond. Jamais de 2 000 m imposé à une AL.
4. Preview, brief, player, preuve. KPI écrits dans `session_meta` : `dist_m`, `duration_s`, plus `split_500_s`, `cadence`, `watts`, `drag_factor`.
5. Import PDF. Couche texte TCPDF, OCR si vide. Pas de stockage du fichier. `session_meta.storage_path` n’est pas pour la licence.
6. Lieu. Club = `rowers.club_id`. Code FFA = `licenses.ffa_code`, pas `clubs.short_code`. Plan d’eau = `waters`. Visite signalée, club de licence inchangé.
7. Portes eau sur `boat_outs` et `assignments`. Fiche partageable, lien à token, siège pris dans `assignments`. Pas d’API WhatsApp.

### Setup à produire

- Ne pas livrer `001_init.sql` tel que l’ancienne section 13. Livrer `supabase/migrations/00N_license_and_water.sql` uniquement pour les tables absentes, après avoir lu `information_schema.columns`.
- `002_rls.sql` sur les tables existantes. RLS est déjà on. Ajouter les policies, ne pas réactiver en boucle.
- Pas de seed avec la licence d’exemple.
- `.env.example` : `SUPABASE_URL`, `SUPABASE_ANON_KEY`. Pas de service role dans l’app.
- README : le schéma métier est déjà en place. Ce spec ne logge rien tant que l’import n’est pas branché sur `rowers`.
