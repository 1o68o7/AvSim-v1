# AvSim-v1 — DataR0w

Deux produits dans ce dépôt :

1. **Simulateur physique** (Python + React) — choisir quels capteurs
   acheter avant de câbler un bateau réel. Sorties = **Simulé**, jamais
   des mesures.
2. **App club / télémétrie** Flutter `apps/datar0w` — produit actif
   (identité, parc, séances, sync Supabase). Pas de moteur AvSim dedans.

**Avant tout** : lire `STATE.md` (physique) et `apps/datar0w/README.md`
(app téléphone). Puis `docs/brief-simulateur-v2.md` pour la spec physique.

- `apps/datar0w/` — application Flutter DataR0w (téléphone)
- `supabase/` — migrations RLS / identité / sessions
- `docs/` — briefs, état des lieux, questions ouvertes
- `docs/brief-interface-utilisateur.md` — Phase 7 UI simulateur (deux surfaces)
- `src/avsim/core/` — noyau physique
- `src/avsim/api/` — FastAPI (rôles Analyste / Produit + `/datarow`)
- `web/` — React + Vite + Plotly (surface simulateur)
- `params/` — paramètres gelés et sourcés, par classe de bateau
- `data/` — données de référence (coques, anthropométrie, hydrodynamique de palette)
- `tests/` — critère d'arrêt du chantier physique

### Interface locale (Phase 7)

```bash
pip install -e '.[api]' --break-system-packages
python -m avsim.api          # http://127.0.0.1:8000
cd web && npm install && npm run dev   # http://127.0.0.1:5173
```

Toute sortie simulateur affiche le badge **Simulé**. Classes hors `8+`/`1x` :
badge **Bêta — non calibrée**.

### Déploiement (Render)

1. Sur [render.com](https://dashboard.render.com) : **New → Blueprint**.
2. Connecter le dépôt GitHub (Render demande les credentials à la connexion
   du compte — rien à mettre dans le repo).
3. Render lit `render.yaml` à la racine et crée :
   - **avsim-api** — service web Python (FastAPI / uvicorn)
   - **avsim-web** — site statique (build Vite) avec `VITE_API_URL` pointant
     vers l’URL publique de l’API
4. Après le premier deploy, si l’URL API n’est pas encore bakée dans le
   frontend : **Manual Deploy → Clear build cache & deploy** sur `avsim-web`.

En local, ne pas définir `VITE_API_URL` : le proxy Vite `/api → :8000` reste
le défaut.
