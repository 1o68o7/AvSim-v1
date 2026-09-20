# Point G — Agrégats licenciés par club (sans PII)

> **Statut** : cadrage. **Pas d'écran app dans ce lot.**
> Complète le point F (scraper serveur). Objectif : l'app devient utile à **tout l'aviron**
> (loisir + compétition) en montrant la **taille** des clubs, jamais la liste des rameurs.
> Vérifié en live le 20/09/2026.

---

## 0. Contrainte produit (figée)

- On veut **le nombre de licenciés par club** (agrégat), pour que DataR0w aide
  l'aviron au-delà d'un seul club.
- On **ne veut jamais** exposer les rameurs d'un club : pas de noms, pas de dates
  de naissance, pas de catégories individuelles, pas de contacts.
- La donnée personnelle FFA est **réservée** : accessible uniquement au club
  lui-même (via son espace / MyFFA) ou avec une **habilitation FFA** (intranet).
- Donc : **agrégat public possible**, **liste nominative jamais**.

---

## 1. Ce qui existe vraiment (vérifié)

| Source | Contenu public | Nb licenciés par club ? |
|---|---|---|
| `ffaviron.fr/clubs/` (~413 clubs) | nom, adresse, CP, ville, fiche | **Non** |
| Fiche club publique | adresse, parfois site/contact | **Non** |
| Classements clubs (PDF) | points sportifs, pas d'effectifs | Non |
| Labels EFA | label + mentions | Non |
| **Intranet FFA** (`intranet.ffaviron.fr`) | effectifs, licences par type/catégorie | **Oui, mais fermé** |
| Rapports AG / guide dirigeants (PDF) | totaux nationaux, parfois par ligue | Partiel, pas par club exploitable |
| **API officielle FFA** | — | **Aucune** |

**Conclusion** : le nombre exact de licenciés par club **n'est pas scrapable**
publiquement. On ne peut pas promettre « le chiffre FFA officiel » sans
partenariat. On construit un **canal d'agrégat** propre, labellisé, et on
interdit formellement tout scraping de listes nominatives.

---

## 2. Décisions figées

- **G1** Aucun scraping de **PII** : pas de noms, emails, téléphones, listes de
  licenciés, mutations, photos de profil. Interdit dans le worker et dans l'API.
- **G2** Le nombre de licenciés par club arrive par **deux canaux seulement** :
  1. **Saisie club** (self-report) via l'espace club → `club_overrides.licensees_est`.
  2. **Partenariat FFA** (futur) : un export agrégé officiel, jamais nominatif,
     poussé dans `ffa_club_stats`.
- **G3** Chaque valeur affichée porte un **label de provenance** :
  `source = self_report | ffa_partner | estimated` + date.
  Jamais « source FFA » si ce n'est pas le cas.
- **G4** L'app affiche l'agrégat en **lecture seule**. Pas de détail par catégorie
  d'âge / sexe / type de licence tant qu'on n'a pas un canal officiel.
- **G5** La liste des rameurs d'un club reste **privée** : visible uniquement par
  les membres habilités du club (hors scope de ce lot, géré par auth club).
- **G6** Respect RGPD : agrégats ≥ 5 personnes pour publication publique
  (évite la ré-identification). En dessous → masqué « < 5 ».
- **G7** Le worker FFA (point F) **ne tente jamais** de dériver un effectif
  depuis le HTML public. Si un jour la FFA publie un agrégat, on l'ingère
  proprement dans `ffa_club_stats`, pas en le devinant.

---

## 3. Schéma Postgres (complément point F)

```sql
-- Agrégats licenciés par club (JAMAIS de ligne par personne)
create table ffa_club_stats (
  club_id       uuid primary key references clubs(id),   -- table app
  ffa_id        text references ffa_clubs(ffa_id),      -- lien miroir FFA
  season        text not null,                          -- ex '2025-2026'
  licensees     int,                                    -- total licenciés (agrégat)
  practitioners int,                                    -- pratiquants (si dispo)
  source        text not null,                          -- self_report | ffa_partner | estimated
  reported_by   uuid,                                   -- user_id club (si self_report)
  reported_at   timestamptz,
  verified      boolean default false,                  -- true si canal FFA officiel
  unique (club_id, season)
);

-- Vue publique (sans PII, agrégat seulement)
create view v_club_public as
select c.id, c.name, c.city, c.department,
       s.licensees, s.practitioners, s.source, s.season, s.reported_at
from clubs c
left join ffa_club_stats s on s.club_id = c.id
where s.licensees is null or s.licensees >= 5;   -- G6
```

La table `club_overrides` (point F) garde `licensees_est` comme **fallback**
tant que `ffa_club_stats` n'existe pas pour la saison.

---

## 4. API interne `/v1` (lecture, agrégat)

| Méthode | Route | Réponse |
|---|---|---|
| GET | `/v1/clubs/{id}/stats?season=` | `{licensees, practitioners, source, season, reported_at}` ou 404 si < 5 |
| GET | `/v1/clubs?with_stats=1` | liste clubs + agrégat (si ≥ 5) |
| PATCH | `/v1/clubs/{id}/stats` (auth club) | saisie self_report → `ffa_club_stats` |

- **Jamais** d'endpoint listant des personnes.
- Auth club = même mécanisme que le reste (session / magic link, point B).
- Cache HTTP 1 h. Attribution « agrégat, non nominatif » dans chaque réponse.

---

## 5. Lots (ordre de build)

1. **G1 — Schéma + RLS** : tables `ffa_club_stats`, vue `v_club_public`, politiques
   RLS (lecture publique agrégat ; écriture = membre du club ou admin).
   Tests SQL.
2. **G2 — Endpoint PATCH stats** : saisie club (self_report), validation ≥ 5,
   provenance labellisée. Tests API.
3. **G3 — Endpoint GET stats** : lecture agrégat, masquage < 5, cache.
   Tests API.
4. **G4 — Client Dart** : `ClubStatsApi` branché sur fiche club / spinoscope.
   Fallback `club_overrides.licensees_est` si pas de stats saison.
5. **G5 — (Futur) Partenariat FFA** : ingestion d'un export agrégé officiel
   dans `ffa_club_stats` avec `source = ffa_partner`. Hors scope immédiat.

Chaque lot = 1 commit. **Aucun scraping de listes.** Ne touche pas à
`apps/datar0w` sauf G4.

---

## 6. Ce que l'app gagne

- Fiche club : « ~120 licenciés (saisi par le club, 2025-2026) » — honnête.
- Spinoscope : répartition / taille des clubs sans exposer personne.
- Confiance : on ne ment pas sur la source. Quand la FFA ouvrira un canal
  agrégé, on bascule `source` sans changer l'UI.

---

## 7. Limites assumées (à dire aux coachs)

- **Pas de chiffre FFA officiel** par club aujourd'hui → self_report labellisé.
- **Pas de liste de rameurs** dans DataR0w, même pour son propre club, sans
  habilitation (géré par auth club, hors ce lot).
- **Seuil 5** : petits clubs (< 5) n'affichent pas de nombre public.
- **Pas de dérivation** d'un effectif depuis le site public FFA.

---

## 8. Prompt Cursor

```
Point G — agrégats licenciés par club, sans PII.
Lis docs/CADRAGE-FFA-LICENCIES-AGREGES.md et docs/CADRAGE-FFA-SERVEUR-SCRAPER.md.
Ne scrape AUCUNE liste de personnes. Interdit PII dans worker + API.

1) Schéma Postgres : table ffa_club_stats (club_id, season, licensees, practitioners,
   source, reported_by, reported_at, verified) + vue v_club_public (masque < 5).
   RLS : lecture publique agrégat ; écriture = membre club ou admin.
2) API FastAPI : PATCH /v1/clubs/{id}/stats (auth club, self_report, ≥ 5),
   GET /v1/clubs/{id}/stats (lecture, labellisé), GET /v1/clubs?with_stats=1.
   Jamais d'endpoint listant des personnes.
3) Client Dart ClubStatsApi : branche fiche club + spinoscope.
   Fallback club_overrides.licensees_est si pas de stats saison.
4) Tests : seuil 5, provenance, pas de PII dans les fixtures.
5) README : comment un club saisit son effectif, variables d'env, curl exemples.
Ne touche pas apps/datar0w sauf lot G4. Un commit par lot G1→G4.
```

---

*Point G — 20/09/2026. S'appuie sur le point F. À brancher après F1–F4.*
