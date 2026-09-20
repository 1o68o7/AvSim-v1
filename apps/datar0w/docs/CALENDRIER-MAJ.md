# Mise à jour du calendrier FFA (curaté)

Le fichier `assets/ffa_calendar_2026.json` est un **catalogue local**.
L’app **ne** interroge **pas** `ffaviron.fr` (ToS). Pas de scraper.

## Format `events[]`

| Champ | Type | Notes |
|---|---|---|
| `id` | string | Stable, préfixe `ffa-` |
| `name` | string | Nom public |
| `start` / `end` | `YYYY-MM-DD` | Inclus |
| `city` | string | |
| `lat` / `lon` | number | WGS84 |
| `type` | string | `championnat` `regate_ouverte` `randonnee` `master` |
| `discipline` | string | `riviere` `bassin` `lac` |
| `open_to_loisir` | bool | |
| `definition_loisir` | string? | Texte club / FFA public |
| `licence_requise` | string | `aucune` `AL` `AC` |
| `labellise` | string? | ex. `RandonAviron` |
| `water_id` | string | Clé dans `assets/waters.json` |
| `url` | string? | Page **publique** déjà connue, jamais fetch auto |

`waters.json` : `id`, `name`, `type`, `city`, `lat`, `lon`, `length_m?`.

## Comment un humain met à jour

1. Recopier les infos **publiques** (affiche club, PDF FFA déjà téléchargé).
2. Éditer les JSON (pas d’e-mail, pas de date de naissance).
3. `updated` ISO date en tête du calendrier.
4. `flutter test test/calendar_catalog_test.dart` depuis `apps/datar0w`.

Zéro `http.get` vers le domaine FFA dans `lib/`.
