# Audit UX / UI / parcours — 2026-10-02

Passe agents sur `main` @ `092af6d` (post DR-52 / DR-55–56 gels).
Critère produit : expérience club réelle — découvrir → s’inscrire → licence →
ramer / barrer → (option) coach / staff. Filtrer le verbeux digne d’une IA.

## 1. GitHub / repo privé

L’agent cloud est authentifié via l’intégration GitHub Cursor (`gh` + clone
HTTPS sur `1o68o7/AvSim-v1`). Aujourd’hui le dépôt est **PUBLIC**.

Si tu le passes en **privé** :
- **Oui**, on continue à le voir **tant que** l’app GitHub Cursor / le token
  d’installation garde l’accès à ce dépôt privé (même compte / org).
- **Non**, si tu retires l’accès de l’app Cursor, ou si le token n’a plus
  scope `repo` privé.

À faire après bascule : vérifier dans GitHub → Settings → Applications →
Cursor que `AvSim-v1` reste dans les repos autorisés.

## 2. Verbosité (bruit IA) — priorité

### P0 — quai / tare / live (ralentit le rameur)

| Zone | Exemples de bruit | Coupe |
|------|-------------------|-------|
| Tare | Essai 3 phrases, σ / clamp / 12 Hz, pitch-yaw, CAPS | 1 ligne : « Coque calme → tare = 0° » |
| Pré-session | Paragraphe FFA + « PARAMÉTRAGE… » + poll API / Lot G | Mode + classe + siège |
| Live DR-52 | `DR-52` visible, `//`, alerte ×3, `SEUIL EXCÉDÉ` | Une alerte courte ; ambre gîte |
| Quai | `GÎTE RMS`, chips pile, filenames JSONL | Résumé 3 métriques + Share/Replay |
| Mode banner | Mur « compétition / flash / pas de 4G » | « Course : tel au quai » |

### P1 — hubs athlète

Stockage flash / JSONL / « informatif pas médical » ×3 / UUID BLE /
`DATAR0W // TELEMETRY DECK` / double santé (consent + constantes).

### P2 — staff / coach

Badges `DR-31` / `DR-56`, sous-titre `session_meta cloud`, toolbar CAPS
parc, essais « Tu rames aussi ?… ».

**Ordre de coupe copy-only (sans changer la physique) :**
1. tare + pré-session + mode banner  
2. live alertes + cox units  
3. hubs athlète / auth  
4. staff : virer IDs Stitch + `session_meta`

## 3. Parcours réel vs app

| Étape réelle | App | Statut |
|--------------|-----|--------|
| Découvrir club (histoire, plan d’eau, victoires) **sans** compte | Départ = `/identity` | **Manquant** |
| S’inscrire | `/auth` + profil local | Partiel |
| Licence FFA pour ramer | Optionnelle / PASSER | **Manquant** (vs règle club) |
| Devenir rameur | `/home/rower` + tunnel eau | OK |
| Parfois barreur | Self-serve `becomeCox` | Partiel |
| Ensuite coach / staff | Join + rôles ; `/club/login` → `/auth` | Partiel |
| Athlète ≠ outils staff | Redirects IA reshape | OK route / UX floue |

**Trous majeurs**
1. Mauvaise porte d’entrée : « Profils sur ce téléphone » ≠ vitrine club.  
2. Visiteur ne peut pas explorer calendrier / waters / histoire avant identité.  
3. Licence soft → stack eau accessible (et « Passer sans profil »).  
4. Coach atteignable via rôle séance / deep link sans membership claire.  
5. « Rôle bateau » (Plus → `/`) orphelin après reshape IA.  
6. Cox hors `DeckTabScaffold` (pas les 3 onglets).

IA reshape (`sessionRoleHome`, hubs staff) = **bon filtre interne**, pas un
**modèle de parcours**.

## 4. Design Stitch — trous raquette

| Écran | Flutter | Sévérité |
|-------|---------|----------|
| DR-52 live | Cockpit OK ; alerte Volt au lieu d’ambre ; portrait non porté | Athlète |
| DR-53 cox | HUD fonctionnel Hangar CAPS | Athlète |
| Tare / pré-session | Hangar CAPS + essais | Athlète |
| DR-54 quai | Hangar | Athlète |
| DR-55/56 replay | Gels riches ; UI = map+courbes Hangar (sentence-case cosmétique) | Athlète |
| Home cox | Pas de shell 3 onglets | IA |
| Hubs 20/30/60 | Proches Deck | Polish |

## 5. IA cible (recommandée)

**Cold start `/` = Club discover** (public) : Histoire · Plan d’eau ·
Calendrier/victoires · CTA Rejoindre / Ramer.

| Persona | Home | Arbre | Gate |
|---------|------|-------|------|
| Visiteur | `/` discover | waters, calendar lecture | auth pour ramer |
| Compte sans licence | onboard licence **required** | profil + discover | bloque `/live` |
| Rameur (+ cox mode) | `/home/rower` (cox = mode) | session eau | staff → home rower |
| Coach | `/home/coach` | crew, join, calendar | athlete stack explicite |
| Staff | `/home/{role}` | cartes filtrées | comme aujourd’hui |

Production : tuer « Passer → /home/rower » ; « sans compte » = discover only.
Licence + membership = redirects globaux à côté de `resolveRootRedirect`.

## 6. Lots — statut (2026-10-02)

| Lot | PR | Statut |
|-----|-----|--------|
| P0 copy tare/pré-session/live/quai | #97 | Merged |
| Audit doc | #96 | Merged |
| P1 hubs athlète + auth | #98 | Merged |
| P2 staff/coach | #99 | Merged |
| Alerte gîte ambre | #100 | Merged |
| Porte club discover + licence | #101 | Merged |
| Stitch athlète cox/quai/replay | #102 | Merged |

## Livré — porte club (MVP)

Cold start = **`/discover`** (`ClubDiscoverScreen`) : marque DataR0w, CTAs
calendrier / plans d’eau / rejoindre (`/auth`) / profils locaux (secondaire).
`GoRouter(initialLocation: AppRoutes.discover)` ; `/` via `resolveRootRedirect`
→ discover si aucun profil, sinon hubs métier.

**Gate licence (tunnel eau)** : `needsLicence` + redirect sur
`/presession`, `/tare`, `/live`, `/cox` → `/onboarding/rower` + SnackBar
si profil actif sans `ffaLicence`.

**Échappatoires** : « Passer (sans profil) » (debug only) et auth « Sans
compte » → `/discover`, plus `/home/rower` / stack identité.

## Livré — Stitch athlète

Home cox dans `DeckTabScaffold` ; quai DR-54 hero+pods ; replay DR-55/56
cartes métriques + export + éval coach si notes.
