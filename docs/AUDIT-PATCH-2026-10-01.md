# Patch audit UX / UI / fonctionnel — 1er octobre 2026

Réf. audit collé en session agent. Branche `cursor/datarow-audit-ux-oct1-7a63`.

## Fait (priorités 1–8 + README)

| Réf. | Patch |
|---|---|
| S1 | `clubRole` défaut = `rower` ; `parse()` connaît `admin` ; inconnu → `rower` |
| S2 | Migration `0007_audit_rls_oct2026.sql` : `session_meta` / Storage = owner ∪ staff |
| S3 | Delete RLS propriétaire (`session_meta`, Storage, `rower_physio`) |
| S4 | `DATAROW_API_KEY` + header `X-DataR0w-Phone-Key` ; CORS via `AVSIM_CORS_ORIGINS` |
| S5 | `clubs_insert` plafonné à 5 clubs admin / user |
| N2 | Retours coach → `/identity` ; quai / settings / join → home du rôle |
| U1–U2 | Liste séances : pas vide+erreur ; fiche `byCode` try/catch + messages lisibles |
| U3 | Erreurs sync humanisées ; bandeau LOCAL durable ; statut 6 s |
| U4–U5 | Jargon retiré / adouci ; MOCK → « Simuler un patch » |
| U6 | Libellé « Continuer la séance » |
| U9 | Alerte tribord = `tribordAlert` ; « trop tribord » |
| U13 / P4 / P5 | Nom vide → message ; rôles rower/cox ; noms + confirmation validation |
| P1 | Titres « Profils » / « Rôle bateau » |
| U11 | Réglages → objets + consentement |
| F1 | Check-in coque : dialogue pelles OK / manquantes |
| §6 | README : deux produits (simulateur + Flutter) |

## Non fait (hors lot / à vérifier appareil)

P2/P6 allègement accueils (refonte IA) · N1 gardes routeur · N3 swipe · N4 navigateFromIdentity · F2/F3 cadence/tare · F6 web React · export compte UI complet · U14 outdoor.

## Env

- Prod `/datarow` : définir `DATAROW_API_KEY` et envoyer `X-DataR0w-Phone-Key`.
- CORS : `AVSIM_CORS_ORIGINS=https://…` (sinon localhost + Render web).
