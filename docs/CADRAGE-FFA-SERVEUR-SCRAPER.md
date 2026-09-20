# Point F — Scraper serveur FFA + API interne (hors app)

> **Statut** : cadrage exploratoire. **Pas d'écran app dans ce lot.**
> Le scraper tourne **côté serveur** (worker Python/Node), pas dans Flutter.
> L'app consomme une **API interne** (`/v1/clubs`, `/v1/events`) — jamais ffaviron.fr directement.
> Vérifié en live le 20/09/2026 sur ffaviron.fr.

---

## 0. Ce qui existe vraiment (vérifié)

| Source FFA | URL | Contenu public | Scrapable ? |
|---|---|---|---|
| Annuaire clubs | `ffaviron.fr/clubs/` | ~413 clubs : nom, adresse, CP, ville, lien fiche | Oui (HTML simple, pagination) |
| Fiche club | `ffaviron.fr/clubs/<slug>/` | adresse, parfois site/contact | Oui |
| Événements | `ffaviron.fr/suivre-les-competitions/tous-les-evenements-ffa/` | cartes : nom, dates, lieu, type (Compétition/Randonnée), parfois club | Oui (HTML) |
| Classements clubs | `ffaviron.fr/competitions/les-classements/` + PDF | points par club, par discipline | PDF → parser |
| Clubs labellisés | `.../les-clubs-labellises/` | label EFA / étoiles + mentions (AviFit, Santé, Handi) | Oui (tableau) |
| Réglementation sportive | PDF annuel | calendrier national | PDF → parser |
| **API officielle** | — | **aucune** | — |
| **Nb licenciés par club** | — | **non public** (intranet `intranet.ffaviron.fr` seulement) | Non |
| **Logo / blason club** | — | **non exposé** dans l'annuaire | Non (certains clubs ont un site propre) |

**Conséquence** : on ne peut pas promettre « le nombre exact de licenciés FFA par club » sans partenariat. On expose ce qui est public + un champ `licensees_est` (estimation / saisie club) clairement labellisé.

---

## 1. Décisions figées

- **D1** Le scraper est un **service serveur indépendant** (repo séparé ou dossier `services/ffa-scraper/`), pas dans l'app Flutter.
- **D2** Respect strict : `robots.txt`, **1 requête / seconde**, User-Agent identifié (`DataR0wBot/0.1 (+contact)`), cache 24 h, pas de charge de nuit agressive.
- **D3** **Fallback catalogue curaté** : si le scrape casse (changement HTML FFA), on bascule sur un JSON versionné maintenu à la main. L'app ne voit jamais la différence.
- **D4** L'app **ne parle jamais à ffaviron.fr**. Elle appelle uniquement l'API interne.
- **D5** Les données FFA sont en **lecture seule** côté app. Un club peut **corriger / compléter** (logo, nb licenciés, bassin) via son espace — jamais écraser la source FFA.
- **D6** Pas de PII : on ne scrape **pas** les tuteurs, présidents, emails, listes de licenciés. Uniquement structures + événements + classements agrégés.
- **D7** Licence des données : usage **non commercial interne** DataR0w ; attribution « source FFA » affichée dans l'UI.

---

## 2. Architecture

```
[ffaviron.fr] --scrape (1/s)--> [worker Python] --upsert--> [Postgres : ffa_clubs, ffa_events, ffa_rankings]
                                                      |
                                                      v
[Flutter app] --HTTPS--> [API interne /v1] --lecture--> [Postgres]
```

- Worker : Python + `httpx` + `selectolax`/`beautifulsoup4`, planifié (cron quotidien).
- Stockage : Postgres (Supabase) tables `ffa_*` séparées des tables club/app (`clubs`, `boats`).
- API : FastAPI, endpoints lecture seule, cache HTTP, clé API optionnelle pour l'app.

---

## 3. Schéma Postgres (côté serveur)

```sql
-- Clubs FFA (miroir public)
create table ffa_clubs (
  ffa_id        text primary key,          -- code club C0XXXXXX si dispo, sinon slug
  name          text not null,
  slug          text,
  address       text,
  postcode      text,
  city          text,
  department    text,
  region        text,                      -- ligue
  lat           double precision,
  lon           double precision,
  label_efa     text,                      -- EFA / 1* / 2* / 3* / null
  mentions      text[],                    -- {avifit, sante, handi}
  website_url   text,                      -- si trouvé sur la fiche
  source_url    text,
  scraped_at    timestamptz,
  raw_hash      text
);

-- Événements FFA
create table ffa_events (
  ffa_event_id  text primary key,
  name          text not null,
  kind          text,                      -- competition | randonnee | autre
  discipline    text,                      -- riviere | mer | banc_fixe | indoor | ...
  start_date    date,
  end_date      date,
  venue_name    text,
  venue_address text,
  venue_city    text,
  venue_postcode text,
  venue_lat     double precision,
  venue_lon     double precision,
  host_club_ffa_id text references ffa_clubs(ffa_id),
  source_url    text,
  scraped_at    timestamptz
);

-- Classements clubs (agrégés)
create table ffa_rankings (
  season        text,
  ranking_type  text,                      -- performance | femme | homme | jeune | mer | indoor | master | para
  rank          int,
  club_ffa_id   text references ffa_clubs(ffa_id),
  points        numeric,
  primary key (season, ranking_type, club_ffa_id)
);

-- Corrections / compléments club (saisis par le club, jamais écrasés par le scrape)
create table club_overrides (
  club_id       uuid primary key references clubs(id),  -- table app
  ffa_id        text references ffa_clubs(ffa_id),
  logo_url      text,
  licensees_est int,                       -- estimation, labellisée « non FFA »
  blason_colors text[],
  notes         text,
  updated_at    timestamptz
);
```

---

## 4. API interne `/v1` (lecture)

| Méthode | Route | Réponse |
|---|---|---|
| GET | `/v1/clubs?q=&city=&dept=&label=` | liste clubs (miroir FFA + overrides) |
| GET | `/v1/clubs/{id}` | fiche club enrichie |
| GET | `/v1/events?from=&to=&kind=&discipline=&city=` | calendrier |
| GET | `/v1/events/{id}` | fiche événement + mini-carte |
| GET | `/v1/rankings?season=&type=` | classement clubs |
| GET | `/v1/meta` | `scraped_at`, version catalogue, source |

Auth : clé API statique pour l'app (même mécanisme que `DATAROW_API_BASE`). Pas d'OAuth ici.

---

## 5. Lots serveur (ordre de build)

1. **F1 — Worker scrape clubs** : parser `ffaviron.fr/clubs/` (+ pagination), upsert `ffa_clubs`, géocode Nominatim, tests sur fixture HTML.
2. **F2 — Worker scrape événements** : parser la page événements, upsert `ffa_events`, tests fixture.
3. **F3 — Worker classements** : télécharger PDF classements, parser, upsert `ffa_rankings`.
4. **F4 — API `/v1`** : endpoints lecture + cache, brancher sur Postgres.
5. **F5 — Overrides club** : table `club_overrides`, endpoint PATCH (auth club), l'app peut uploader logo / nb licenciés / couleurs.
6. **F6 — Sync app** : client Dart `FfaApi` (lecture seule) branché sur les écrans calendrier / club (points E / D). Fallback catalogue JSON si API down.

Chaque lot = 1 commit, tests verts, `flutter analyze` clean côté app (F6).

---

## 6. Ce que l'app gagne (sans nouvel écran dans ce lot)

- Calendrier (point E) : source = `/v1/events` au lieu d'un JSON statique.
- Fiche club (point D) : logo / nb licenciés via `club_overrides`, source FFA en lecture seule.
- Spinoscope : classements `/v1/rankings`.
- Rien ne casse si le scrape est en panne : fallback catalogue.

---

## 7. Limites assumées (à dire aux coachs)

- **Pas de nb licenciés FFA officiel** par club → estimation saisie, labellisée.
- **Pas de logo FFA** → le club uploade le sien, ou on tente le site du club (best-effort, non garanti).
- **Délai** : scrape quotidien, donc l'app peut avoir 0–24 h de retard vs le site FFA.
- **Changement HTML FFA** : le scrape peut casser → fallback catalogue + alerte ops.

---

## 8. Prompt Cursor (serveur, pas l'app)

```
Crée le service serveur services/ffa-scraper/ (Python 3.12).
- Worker httpx + selectolax, 1 req/s, User-Agent DataR0wBot/0.1, respecte robots.txt.
- Parse ffaviron.fr/clubs/ (pagination) → upsert ffa_clubs (Postgres/Supabase).
- Parse /suivre-les-competitions/tous-les-evenements-ffa/ → ffa_events.
- Télécharge PDF classements → ffa_rankings.
- Schéma SQL §3. Tests sur fixtures HTML (pas de réseau en CI).
- Fallback : si scrape échoue, lit data/ffa_catalog_fallback.json versionné.
- API FastAPI /v1 lecture seule (§4), clé API statique.
- Table club_overrides pour logo / licensees_est / couleurs (jamais écrasée par le scrape).
- README : lancer worker, variables d'env, exemple curl /v1/clubs.
- Ne touche PAS à apps/datar0w ni AvSim.
Commit : feat(ffa-scraper): worker clubs + events + rankings + API /v1
```

---

*Point F — 20/09/2026. Sources vérifiées en live. À trancher avant F1 : hébergement du worker (même Supabase ? VPS dédié ?) et politique de rétention des snapshots.*
