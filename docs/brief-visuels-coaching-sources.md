# Brief — visuels enrichis, sourcés sur de vrais systèmes de coaching

*26 juillet 2026 · à destination de Cursor*
*Sources : Durham Boat Co. (Jim Dreher, système FM Peach/FES, ~40 ans d'usage
réel) et South Niagara Rowing Club (terminologie/schémas de classes)*

---

## Ce qui a été lu, et pourquoi c'est fiable

Contrairement à nos propres visuels (construits pour ce projet), ceux
décrits ici viennent d'un système de mesure de force réellement utilisé en
boat et en bassin d'entraînement depuis des décennies (Peach Innovations UK,
FES Allemagne), avec des milliers de séances de données (Kleshnev cite une
base de 7000+ entrées). Ce ne sont pas des idées de design — ce sont des
patterns qui ont fait leurs preuves pour transmettre de l'information
rapidement à un rameur ou un coach en mouvement, sous contrainte de temps.
On les reprend pour cette raison, pas parce qu'ils sont jolis.

---

## 1. Barre de longueur de coup — le pattern le plus transposable, absent chez nous

**Ce que ça montre** (un par rameur) : une barre horizontale dont la
longueur représente la course de coulisse, le point de départ représente
l'angle de catch, et la partie **grisée** représente la portion où la
palette est effectivement immergée (au-delà d'un seuil de force).

**La règle de lecture, immédiate et sans jargon** :
- Pas de blanc au début de la barre → catch rapide, franc
- Blanc excessif à la fin → sortie prématurée (« washing out »)

**Où l'implémenter** : Vue Équipage (analyste) — une barre par poste,
alignées verticalement, permet de repérer en un coup d'œil quel poste a un
problème de catch sans lire un seul chiffre. Même composant réutilisable
en Coach live (densité par poste déjà prévue) et Coach Replay.

**Donnée nécessaire** : déjà disponible — `catch_slip` (glissement
mesuré cette semaine), position de coulisse, seuil d'immersion déjà dans
le modèle de capteur `coulisse`.

---

## 2. Superposition des courbes de force — « nesting » de l'équipage

**Ce que ça montre** : les courbes de force de tous les rameurs, superposées
sur un seul graphique. Chez un équipage bien synchronisé, les pics
« s'emboîtent comme des poupées russes » — même timing, amplitude
différente selon chaque rameur.

**Pourquoi c'est directement utile ici** : c'est un diagnostic visuel
immédiat pour exactement ce qu'on cherche à mesurer avec `check_factor` et
`phase_lag_ms` depuis le début du projet — un équipage désynchronisé se
voit tout de suite comme des pics qui ne s'alignent pas, sans lire un
chiffre.

**Où l'implémenter** : Vue Équipage (analyste), et Coach Replay pour le
diagnostic post-séance. Overlay Plotly multi-lignes, une couleur par poste,
axe X en `u` (déjà notre convention) pas en temps absolu — pour que la
comparaison soit valide même si les rameurs ont des cadences légèrement
différentes.

---

## 3. Courbe « poisson » — vitesse de poignée vs angle, cycle complet

**Ce que ça montre** : la vitesse angulaire de la poignée tracée contre
l'angle de l'aviron (pas le temps), sur les 360° du cycle complet
(propulsion **et** retour). Chez un coup efficace, la forme ressemble à un
petit poisson — la moitié propulsion (positive) est à peu près le miroir
de la moitié retour (négative).

**Pourquoi c'est un diagnostic direct pour nous** : une asymétrie visible
entre les deux moitiés de ce poisson est exactement la signature d'un
problème de `check_factor` — celui qu'on a chassé toute la semaine. Une
version asymétrique de cette courbe rendrait visible, d'un coup d'œil,
ce qu'on a dû sortir des dizaines de diagnostics texte pour comprendre.

**Où l'implémenter** : Vue Coup (analyste), comme alternative ou complément
au graphique force/angle déjà là — courbe supplémentaire, pas un
remplacement, avec la même synchronisation de curseur déjà en place.

---

## 4. Piste synchronisée empilée, curseur unique — déjà amorcé, à étendre

**Ce que le système FM fait** : plusieurs graphiques empilés (angle de
dame en haut comme référence, force en dessous, vitesse et accélération
du bateau en bas), tous partageant le même axe horizontal, avec une ligne
verticale unique qui traverse tous les graphiques au même instant — en
bougeant le curseur sur un seul graphique, on voit où on en est sur tous
les autres simultanément.

**Où on le fait déjà, partiellement** : Vue Coup a déjà un curseur `u`
synchronisé avec `StrokeGeometry`. **À étendre** : ajouter la vitesse et
l'accélération du bateau comme pistes supplémentaires empilées sous le
graphique de force existant, partageant le même curseur — pas un nouveau
composant, une extension du même.

---

## 5. Tableau de bord compact à 4 quadrants — modèle direct pour Team / Coach live

**Layout exact, testé en conditions réelles (bassin, mouvement, lisibilité
sous contrainte)** :
- Haut-gauche : courbe de force (impulsion)
- Bas-gauche : courbe de vitesse de poignée
- Haut-droite : barre de longueur de coup (§1 ci-dessus) — recense aussi
  la synchro port/starboard pour le couple
- Bas-droite : chiffres seuls — puissance (W), cadence

**Pourquoi le reprendre tel quel** : c'est un layout conçu spécifiquement
pour qu'un rameur ou coach ne puisse regarder qu'un seul quadrant à la
fois (contrainte déjà notée dans le document personas — pas de grand écran
stable garanti) et en retire quand même l'essentiel. Ne pas réinventer une
disposition différente sans raison.

**Où l'implémenter** : structure de base pour `TeamView` (déjà existante,
à réorganiser en 4 quadrants plutôt qu'en liste) et `CoachLiveView`.

---

## Ce qui n'est PAS repris, et pourquoi

Le contenu biomécanique/musculaire (searowing.wales) — utile pour la
compréhension humaine du mouvement, mais rien de visuel qui manque à
notre outil aujourd'hui. Les schémas top-down de classes de bateau
(rowsnrc.ca) — confirment simplement que la convention déjà utilisée par
`BoatSchematic` (vue de dessus, alternance de côté) est la bonne, rien à
changer.

---

## Ordre de construction recommandé

**Règle stricte, pas une préférence** : une section, un commit, un
rapport — jamais plusieurs sections dans la même branche ou le même
commit, même si l'ordre ci-dessous les liste toutes à la suite. Ce
document décrit la cible complète pour que le contexte soit clair, pas
une autorisation de tout construire d'un coup. Si ce document est lu
seul, sans un prompt scopé à une seule étape qui l'accompagne : s'arrêter
après la première section et rapporter, ne pas enchaîner.

1. Barre de longueur de coup (§1) — le plus simple, le plus impactant,
   réutilisable sur 3 vues d'un coup
2. Superposition des courbes de force par équipage (§2) — Vue Équipage
   d'abord, Coach Replay ensuite
3. Extension du curseur synchronisé avec vitesse/accélération bateau (§4)
   — petit ajout à un composant existant
4. Réorganisation de TeamView en 4 quadrants (§5)
5. Courbe « poisson » (§3) — la plus nouvelle conceptuellement, en dernier

Chaque étape reste testée sur `2x` (seule classe validée par
l'enveloppe) et `8+`, avec les mêmes badges Simulé/Bêta déjà en place —
rien de tout ça ne change la discipline déjà établie, juste la richesse
visuelle de ce qui est déjà affiché.
