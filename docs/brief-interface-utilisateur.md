# Brief interface utilisateur — DataR0w

*25 juillet 2026 · à destination de Cursor · Phase 7 de ROADMAP-PRODUCTION.md*

---

## 0. Principes directeurs — à lire avant d'écrire une ligne

**Deux surfaces, un seul backend, séparation stricte.** Analyste (moi/toi,
qui décide des capteurs à acheter) et Produit (rameur/team/coach, qui
utilise le système sur l'eau) ne partagent aucune vue, mais consomment la
même API FastAPI. Ne jamais mélanger les deux dans un même composant.

**Rien de fictif à l'écran.** Aucune vue ne doit jamais afficher une donnée
de capteur simulée comme si elle venait d'un vrai capteur, ni une sortie de
simulation présentée comme une mesure. Toute vue alimentée par le
simulateur porte un badge visuel constant : **« Simulé »**. Toute vue
alimentée par un vrai flux (Phase 8, matériel) porte **« Mesuré »**. Ce
n'est pas un détail cosmétique, c'est la règle qui a gouverné tout le
chantier physique cette semaine — elle continue côté interface.

**Statut de validation par classe, visible partout où une classe se
choisit.** Vérifié au 25/07 :

| Classe | Statut | Base |
|---|---|---|
| `8+` | **Validée** | Suite complète (30 tests), Phase 2 examinée en détail |
| `1x` | **Validée** | Suite complète, fixtures dédiées |
| `2x`, `2-`, `4x`, `4-`, `4+`, `8x` | **Test de fumée seulement** | Tourne sans exception, ordres de grandeur raisonnables — pas de calibration `test_class_scaling.py` (pas encore écrit) |

Tant que `test_class_scaling.py` n'existe pas, les 6 classes en test de
fumée s'affichent avec un badge **« Bêta — non calibrée »**, visible sur
le sélecteur de bateau ET dans l'en-tête de chaque vue qui en dépend. Ne
jamais les présenter à égalité avec `8+`/`1x`.

**Ce qui est constructible maintenant vs plus tard.**

- 🟢 **Constructible maintenant** — données déjà disponibles (moteur physique)
- 🟡 **Bloqué** — attend un backend d'une phase antérieure

**Stack** : FastAPI (backend), React + Vite + Plotly (frontend).

---

## Surfaces

Voir sections 2 (Analyste) et 3 (Produit) du brief original agent.
Vues Analyste 🟢 : Bateau, Coup, Bilan, Équipage.
Vues Analyste 🟡 : Capteurs, Observabilité, Sensibilité, Détectabilité.
Surface Produit 🟡 (prototype rejeu) : Rameur, Team, Coach live, Coach Replay.

## Composants partagés

- Schéma de bateau adaptatif (1–8, couple/pointe)
- Badge de statut (validé / bêta / simulé / mesuré)
- Indicateur de calcul en cours

## Ordre de construction

1. Composants partagés
2. Vue Bateau
3. Vue Coup
4. Vue Bilan
5. Vue Équipage
6. Surface Produit (rejeu)
7. Maquettes 🟡
