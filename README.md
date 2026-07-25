# AvSim-v1 — DataR0w

Simulateur physique local d'aviron (multi-classes), pour choisir quels
capteurs de télémétrie acheter avant de câbler un bateau réel.

**Avant tout** : lire `STATE.md`, qui décrit l'état exact du code et les
trois chantiers en cours, dans l'ordre. Puis `docs/brief-simulateur-v2.md`
pour la spécification physique complète.

- `docs/` — briefs, état des lieux, questions ouvertes
- `src/avsim/core/` — noyau physique
- `params/` — paramètres gelés et sourcés, par classe de bateau
- `data/` — données de référence (coques, anthropométrie, hydrodynamique de palette)
- `tests/` — critère d'arrêt du chantier en cours
