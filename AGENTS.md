# AGENTS.md — avsim (DataR0w)

Simulateur physique local d'aviron (multi-classes : 1x à 8x), destiné à
choisir quels capteurs acheter avant de câbler un bateau réel. Ce n'est pas
une source de données — aucune sortie ne doit être présentée comme une mesure.

## Avant d'écrire une ligne
Lis `STATE.md` puis `ROADMAP-PRODUCTION.md`. Phase 0 (fermeture v1) est
**terminée** sur `main`. Point ouvert central : plausibilité §9.2 hors cibles
(`F_peak` au-dessus de la plage eau — piste `I_oar` / traînée / pertes palette).

Puis `brief-simulateur-v2.md` §2 (classes), §3 (enveloppe), §4 (fermeture),
§9.2–§9.4 (plausibility / scaling / triangulation), §11 (ordre). Ignore §10
et au-delà — web app et dashboards viennent après, pas maintenant.

## Build & test
```
pip install -e . --break-system-packages
pytest tests/ -q
```
Les simulations de validation multi-classes passent par
`load_params(boat_class=...)`, pas `load_params()` nu (defaults seuls).

## Phase en cours
Phase 1 : écrire `test_plausibility.py`, `test_class_scaling.py`,
`test_triangulation.py` (brief : écrire d'abord, faire échouer). Ne pas
avancer `sensors/`, `estimation/`, `analysis/`, `api/`, `web/` tant que
plausibility / class_scaling ne sont pas traités (triangulation : skip OK si
table D6 absente).

## Interdits
- Ne jamais modifier une valeur de `params/defaults.yaml` ou
  `params/classes/*.yaml` pour améliorer l'allure d'un résultat. Chaque
  valeur est sourcée (`src: L/E/N`) ; toute modification exige une référence
  citée dans le commit.
- Ne jamais coder en dur le nombre de rameurs — tout se dimensionne sur
  `n_rowers` de la classe.
- Ne pas toucher aux fichiers dans `tests/` pour les faire passer
  (affaiblir un seuil / masquer un échec). Écrire de **nouveaux** tests
  Phase 1 qui échouent pour de vraies raisons est attendu.
- Ne pas inventer la table de triangulation (MANQUES D6) — skip documenté.

## En cas de doute sur la physique
Demander plutôt que deviner. Une convention de signe fausse se propage
silencieusement dans tout le bilan énergétique (déjà arrivé une fois, cf.
STATE.md).
