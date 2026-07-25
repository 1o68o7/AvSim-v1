# Fiches persona et couche temps réel

*Complète le brief-simulateur-v2.md — ne le remplace pas · v1.0 · juillet 2026*

---

## 0. Statut de ce document

Le brief v2.0 spécifie l'**outil de sélection de capteurs** : noyau physique, enveloppe
de validité, capteurs virtuels, modes d'analyse A-D, application web analyste
(§10). Ce document ajoute une **couche produit** par-dessus : trois personas
utilisateurs (rameur, team, coach), un retour temps réel intra-coup, et un
module de replay annoté.

**Principe d'articulation, non négociable** : les deux couches partagent le
même schéma de données (table de faits, grain coup × poste, brief §10) et la
même API. Elles n'ont **pas la même interface**. Un rameur ou un coach ne doit
jamais voir un indice de Sobol ; un ingénieur choisissant des capteurs n'a pas
besoin du cockpit temps réel. Deux surfaces, un seul backend.

**Ordre de construction** : cette couche produit vient après que la couche
analyste passe ses tests de plausibilité et de triangulation (brief §14).
Mais elle peut être **prototypée avant que le matériel existe** — voir §9.

---

## 1. Les trois canaux — rappel et attribution par persona

Architecture déjà posée en amont du simulateur, reprise ici avec l'attribution
exacte à chaque vue :

| Canal | Latence | Portée | Alimente |
|---|---|---|---|
| A — WiFi direct (Pi = point d'accès) | < 100 ms | ~100 m | **Team** (cockpit embarqué), retour haptique tier 1 |
| B — 4G / MQTT / TLS | 0,3 - 1 s | illimitée | **Coach live** (canot moteur) |
| C — LoRa 868 / ESP-NOW | secours | 1-2 km | dégradation si A ou B indisponibles |

Le retour haptique **tier 1** (voir §2) ne transite même pas par le canal A :
il boucle localement sur le nœud du rameur, sans aller-retour réseau. C'est ce
qui le rend insensible à la charge du bus.

---

## 2. Budget de latence « coup+1 » et architecture à deux niveaux

### 2.1 Le calcul qui contraint tout le reste

Retour utile = capture à la sortie d'eau du coup N, jusqu'à affichage/signal
**avant** l'attaque du coup N+1. Fenêtre disponible = durée de retour moins une
marge de réaction humaine (0,3 s retenue).

| Cadence | Période | Propulsion | Retour disponible | Budget net |
|---|---|---|---|---|
| 20 c/min | 3,00 s | 1,26 s | 1,74 s | **1,44 s** |
| 24 c/min | 2,50 s | 1,05 s | 1,45 s | **1,15 s** |
| 28 c/min | 2,14 s | 0,90 s | 1,24 s | **0,94 s** |
| 32 c/min | 1,88 s | 0,79 s | 1,09 s | **0,79 s** |
| 36 c/min | 1,67 s | 0,70 s | 0,97 s | **0,67 s** |
| 40 c/min | 1,50 s | 0,63 s | 0,87 s | **0,57 s** |
| 44 c/min | 1,36 s | 0,57 s | 0,79 s | **0,49 s** ⚠ |

Confortable en travail technique à cadence basse — exactement là où le retour
est le plus utile pédagogiquement. Tendu en course.

### 2.2 Deux niveaux de signal, deux budgets réels

| Niveau | Grandeurs | Chemin de calcul | Latence réelle | Limité par la cadence ? |
|---|---|---|---|---|
| **1 — Auto** | timing d'attaque propre, vitesse de glisse propre, position du pic de force propre | calcul local sur le nœud ESP32 du rameur, sur ses propres capteurs, aucun aller-retour | quelques ms | **non** — tient à toutes les allures |
| **2 — Équipage** | décalage de phase vs rameur de nage, synchro relative | nœud → bus CAN → Pi (fusion) → retour | dépend de la charge de bus (~70 % à 500 kbit/s, brief §7.1) | **oui** — se dégrade au-delà de ~40 c/min |

**Décision retenue** : demarrer par le niveau 1 uniquement. Il couvre une part
significative de la valeur pédagogique, fonctionne y compris en course, et ne
dépend d'aucune fusion centralisée. Le niveau 2 vient ensuite, avec un seuil
de cadence explicite au-delà duquel il se désactive proprement (silence, pas
d'info en retard non signalée comme telle).

### 2.3 Modalité et vocabulaire — décision retenue : haptique dès le départ

Écran par poste écarté (illisible en plein soleil, cf. la même limite déjà
identifiée sur le capteur ToF de coulisse). Retenu : **vibreur au niveau du
cale-pied**, réutilisant le nœud déjà présent à cet endroit pour la mesure de
force aux pieds (même ESP32, même alimentation, même câblage — voir §7).

**Vocabulaire v1 : un seul motif.** Pas de taxonomie de motifs différenciés au
lancement — on ne sait pas encore si un rameur sous charge distingue de
manière fiable plusieurs motifs de vibration pendant l'effort. Un seul signal
« quelque chose sur le dernier coup mérite ton attention » suffit à valider le
concept. Enrichir le vocabulaire (2-3 motifs distincts) est une v2, conditionnée
à la validation terrain de la discrimination des motifs.

Le haptique ne remplace pas le relais du barreur, il le complète : sur un
bateau barré, le rameur sent le signal au moment utile, le barreur voit sur
Team **quel poste** a été signalé et peut détailler à la voix. Sur un bateau
non barré, le haptique est le seul canal — d'où l'investissement dès le départ
plutôt qu'un relais qui n'aurait couvert que les bateaux barrés.

---

## 3. Fiche RAMEUR

**Contexte** — seul, après la séance ou entre deux blocs ; **plus, pendant
l'effort**, un canal haptique passif.

**Objectif** — comprendre sa propre technique et sa progression, indépendamment
des conditions du jour.

**Point d'entrée** — clic sur son poste depuis le schéma de bateau adaptatif.

**Pendant la séance** — signal haptique tier 1 (§2.3) sur le coup qui vient de
se terminer, avant l'attaque suivante.

**Après la séance, 3 chiffres qui priment**
- Courbe de force du coup (pic, position, forme) superposée aux 10 derniers coups
- Décalage de phase vs rameur de nage (ms)
- Indice de progression à conditions comparables (tendance, pas un absolu)

**Vue additionnelle** — journal des coups signalés en haptique pendant la
séance, superposé à la courbe de force : voir *quel* coup a déclenché *quel*
signal, pour relier le ressenti pendant l'effort à la donnée après coup.

**Décision que ça permet** — ajuster sa technique, vérifier si le travail
spécifique porte ses fruits, comprendre a posteriori ce que le vibreur a
signalé pendant l'effort.

**Niveau de confiance** — la courbe de force et le séquençage sont des mesures
directes, fiables dès aujourd'hui. Toute grandeur en watts reste un indice tant
que la calibration de traînée (D3, voir MANQUES.md) n'est pas faite — badge
visuel obligatoire.

**À ne pas mettre** — comparaison à d'autres rameurs, jargon d'ingénierie.

---

## 4. Fiche TEAM (cockpit temps réel embarqué)

**Contexte** — dans le bateau, canal A, pendant l'effort. Lecture en une
seconde, en mouvement.

**Objectif** — savoir si l'équipage est synchrone maintenant, être alerté si
ça dérape.

**3 chiffres qui priment**
- Vitesse bateau (moyenne intra-cycle + tendance sur 10 coups)
- Check factor (calculable via l'IMU de coque seule — disponible tôt)
- Alerte de synchro (poste en cause, seuil dépassé)

**Ajout de cette session** — aperçu agrégé des signaux haptiques tier 1
déclenchés au dernier coup, par poste : le barreur voit *qui* a été signalé et
peut relayer à la voix avec plus de détail que le vibreur seul ne le permet.
Le niveau 2 (synchro relative, §2.2) s'affiche ici quand la cadence le permet,
et se met en grisé au-delà du seuil plutôt que d'afficher une donnée en retard.

**Décision que ça permet** — correction vocale immédiate du barreur.

**Niveau de confiance** — la latence prime sur la précision absolue ; un
chiffre approximatif et instantané vaut mieux qu'un chiffre juste en retard.

**À ne pas mettre** — historique, courbes, tout ce qui demande plus de deux
secondes de lecture.

---

## 5. Fiche COACH — deux modes

### 5.1 Coach live (canot moteur, canal B)

**Contexte** — le coach suit en canot moteur à côté du bateau, ne barre pas,
peut suivre plusieurs grandeurs à la fois pendant un exercice ciblé.

**Différence avec Team** — même socle de données, densité plus riche : pas
seulement 3 chiffres, mais un état par rameur (force, timing, signaux
haptiques déclenchés) actualisé au rythme du canal B (0,3-1 s).

**Décision que ça permet** — intervenir pendant l'exercice, pas seulement au
débrief.

**Contrainte d'affichage** — mêmes limites de lisibilité qu'en bateau : soleil,
mouvement. Ne pas supposer un grand écran stable.

### 5.2 Coach replay (post-séance et longitudinal)

**Contexte** — au bureau ou au bord après la sortie, seul ou en débrief équipe.

**Objectif** — diagnostiquer les pertes, suivre la progression à conditions
égales, et **relier les ordres donnés à leur effet**.

**Point d'entrée** — vue d'équipage (carte de chaleur des écarts par poste) →
clic sur un poste → vue Rameur de ce rameur.

**3 chiffres qui priment**
- Bilan de pertes par coup (propulsion / traînée / palette / cinétique)
- Synchro d'équipage agrégée sur la séance (distribution, pas un instantané)
- Tendance normalisée inter-séances

**Nouveau : timeline annotée**
- Ordres vocaux enregistrés côté coach (le téléphone déjà en main dans le
  canot, voir §6), horodatés, posés sur la même frise que les métriques du
  bateau
- Clic sur un ordre → comparaison avant/après sur la métrique choisie (longueur
  d'arc, cadence, décalage de phase...) sur une fenêtre de N coups
- Le seuil de détectabilité utilisé pour juger si l'écart est réel ou du bruit
  est **le même** que celui calibré par le mode Détectabilité du simulateur
  (brief §8, Mode D) — pas un seuil inventé pour l'occasion

**Décision que ça permet** — savoir si une correction a été suivie d'effet, et
en combien de coups ; cibler le travail du prochain cycle ; comparer des
compositions d'équipage.

**Niveau de confiance** — le plus exigeant des trois écrans. Aucune valeur
énergétique sans son statut de calibration (indice vs mesuré). C'est l'écran
où une erreur non signalée coûte le plus cher — un coach ne doit jamais
changer une composition d'équipage sur un chiffre présenté comme sûr alors
qu'il ne l'est pas.

---

## 6. Modèle de données additionnel — événements

Nouvelle table, jointe à la table de faits existante (grain coup × poste) par
proximité temporelle :

```
events
  event_id       identifiant
  t_utc          horodatage absolu (horloge du téléphone du coach, GPS/NTP)
  source         'coach_voice' | (extensible : marqueur de départ/arrêt d'exercice, etc.)
  audio_ref      référence au clip audio, optionnel
  transcript     texte, optionnel (voir STT ci-dessous)
  tag            catégorie manuelle ou déduite ('longueur', 'cadence', 'relax'...)
  session_id     clé de jointure vers la séance
```

**Sur la précision de synchronisation requise** : contrairement à la synchro
inter-rameurs (20-50 ms, cf. brief §7.1), corréler « le coach a dit X » à
« le coup N s'est produit » tolère une précision à la seconde. L'horloge d'un
téléphone (NTP ou GPS) suffit largement — **pas de matériel dédié nécessaire**
sur la plateforme du coach.

**Transcription automatique (optionnelle, module séparé)** — un modèle local
type Whisper, cohérent avec l'approche tout-local du projet, rendrait les
ordres cherchables (« montre-moi toutes les fois où j'ai dit "relâche" »). Non
bloquant pour le reste.

---

## 7. Matériel additionnel

| Élément | Où | Ajout | Coût estimé | Masse |
|---|---|---|---|---|
| Actionneur haptique (LRA ou ERM) + driver | greffé sur le nœud pieds existant | quelques composants, pas de nouvelle ligne matérielle indépendante | 5-8 € / poste | quelques grammes |
| Capture vocale coach | téléphone du coach, déjà présent | aucun | 0 € | 0 |

Aucun nouveau capteur au sens du brief §7 — uniquement un actionneur, absent de
la nomenclature initiale (qui ne listait que des capteurs). À ajouter comme
catégorie propre dans le tableau matériel.

---

## 8. Extension du mode Détectabilité (brief Mode D)

Deux ajouts à l'analyse déjà spécifiée :

1. **Budget de latence par architecture.** Le mode D calcule aujourd'hui la
   taille d'effet minimale détectable et le nombre de coups nécessaires. Y
   ajouter le **temps de calcul réel de l'estimateur**, confronté à la table du
   §2.1, pour statuer si le niveau 2 (équipage) est tenable à une cadence
   donnée sur l'architecture choisie — avant l'achat, comme le reste du mode D.

2. **Application post-hoc aux événements réels.** La même méthodologie
   avant/après, jusqu'ici réservée à l'injection de défauts synthétiques,
   s'applique telle quelle aux événements vocaux réels du §6. Aucune nouvelle
   théorie : c'est un second cas d'usage du même calcul.

---

## 9. Prochaine étape concrète — prototyper sans matériel

Le simulateur produit déjà des séries à 200 Hz, grain coup × poste, au format
qui doit être identique aux données réelles (brief §10). Il suffit de **rejouer
une simulation à la cadence réelle** — pas plus vite que le temps réel — pour
émuler un flux live et prototyper entièrement l'UX de Team, Coach live et le
timing du signal coup+1, avant qu'aucun capteur physique n'existe.

C'est un mode à ajouter à la CLI (`avsim replay --realtime`), qui rejoue vers
les mêmes points d'entrée API que consommerait un vrai bateau. Les interfaces
Team/Coach/Rameur se développent et se testent contre ce flux rejoué, sans
attendre le matériel — et basculent sur le flux réel sans modification le jour
où il existe.
