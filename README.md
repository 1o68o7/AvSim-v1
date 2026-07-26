# AvSim-v1 — DataR0w

Simulateur physique local d'aviron (multi-classes), pour choisir quels
capteurs de télémétrie acheter avant de câbler un bateau réel.

**Avant tout** : lire `STATE.md`, qui décrit l'état exact du code et les
trois chantiers en cours, dans l'ordre. Puis `docs/brief-simulateur-v2.md`
pour la spécification physique complète.

- `docs/` — briefs, état des lieux, questions ouvertes
- `docs/brief-interface-utilisateur.md` — Phase 7 UI (deux surfaces)
- `src/avsim/core/` — noyau physique
- `src/avsim/api/` — FastAPI (rôles Analyste / Produit)
- `web/` — React + Vite + Plotly
- `params/` — paramètres gelés et sourcés, par classe de bateau
- `data/` — données de référence (coques, anthropométrie, hydrodynamique de palette)
- `tests/` — critère d'arrêt du chantier en cours

### Interface locale (Phase 7)

```bash
pip install -e '.[api]' --break-system-packages
python -m avsim.api          # http://127.0.0.1:8000
cd web && npm install && npm run dev   # http://127.0.0.1:5173
```

Toute sortie simulateur affiche le badge **Simulé**. Classes hors `8+`/`1x` :
badge **Bêta — non calibrée**.

### CLI

```bash
pip install -e . --break-system-packages
avsim run --class 8+ --param technique__F_peak_N=1100 --strokes 6 --discard 2 --out /tmp/r.npz
avsim replay --realtime --result /tmp/r.npz   # NDJSON coup à cadence T
```
