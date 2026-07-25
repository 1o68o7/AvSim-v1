# AGENTS.md — avsim (DataR0w)

Simulateur physique local d'aviron (multi-classes : 1x à 8x), destiné à
choisir quels capteurs acheter avant de câbler un bateau réel. Ce n'est pas
une source de données — aucune sortie ne doit être présentée comme une mesure.

## Avant d'écrire une ligne
Lis `STATE.md` (racine du repo) — décrit l'état exact, dans l'ordre :
1. chargeur multi-classes absent (`params.py` ne lit que `defaults.yaml`)
2. fermeture cinématique fausse (sur-détermine le coup, cf. brief §4.1-§4.4)
3. `n_rowers` figé à 8 dans `defaults.yaml`

Puis `brief-simulateur-v2.md` §2 (classes), §3 (enveloppe), §4 (fermeture),
§11 (ordre de construction). Ignore §10 et au-delà pour l'instant — web app et
dashboards viennent après, pas maintenant.

## Build & test
```
pip install -e . --break-system-packages
pytest tests/ -q
```
Critère d'arrêt de cette tâche : `pytest tests/` entièrement vert, sur au
moins deux classes différentes (ex. 1x et 8+).

## Interdits
- Ne jamais modifier une valeur de `params/defaults.yaml` ou
  `params/classes/*.yaml` pour améliorer l'allure d'un résultat. Chaque
  valeur est sourcée (`src: L/E/N`) ; toute modification exige une référence
  citée dans le commit.
- Ne jamais coder en dur le nombre de rameurs — tout se dimensionne sur
  `n_rowers` de la classe.
- Ne pas toucher aux fichiers dans `tests/` pour les faire passer.
- Ne pas avancer vers `sensors/`, `estimation/`, `analysis/`, `api/` ou
  `web/` tant que `pytest tests/` n'est pas vert.

## En cas de doute sur la physique
Demander plutôt que deviner. Une convention de signe fausse se propage
silencieusement dans tout le bilan énergétique (déjà arrivé une fois, cf.
STATE.md).
