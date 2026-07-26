# AGENTS.md — avsim (DataR0w)

Simulateur physique local d'aviron (multi-classes : 1x à 8x), destiné à
choisir quels capteurs acheter avant de câbler un bateau réel. Ce n'est pas
une source de données — aucune sortie ne doit être présentée comme une mesure.

## Avant d'écrire une ligne
Lis `STATE.md` puis `ROADMAP-PRODUCTION.md`. Phase 0 (fermeture v1) est
**terminée** sur `main`. Point ouvert central : plausibilité §9.2 hors cibles
(`F_peak` au-dessus de la plage eau — piste `I_oar` / traînée / pertes palette).

Puis `brief-simulateur-v2.md` §2 (classes), §3 (enveloppe), §4 (fermeture),
§9.2–§9.4. Interface : `docs/brief-interface-utilisateur.md` (Phase 7
démarrée — badges Simulé / Validée / Bêta obligatoires).

## Build & test
```
pip install -e . --break-system-packages
pytest tests/ -q
```
Les simulations de validation multi-classes passent par
`load_params(boat_class=...)`, pas `load_params()` nu (defaults seuls).

## Phase en cours
Phase 7 UI/API démarrée (brief interface). Dette ouverte : Phase 1
(`test_plausibility`, `test_class_scaling`, triangulation skip D6).
Ne pas avancer `sensors/`, `estimation/`, `analysis/` sans triage explicite.
Les 6 classes hors 8+/1x restent badge **Bêta** jusqu'à `test_class_scaling`.

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
