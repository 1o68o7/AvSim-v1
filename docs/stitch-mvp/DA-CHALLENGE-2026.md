# DataR0w — Challenge DA Hangar vs Bassin

*30 sept 2026. Pas de branchement Flutter. Planches Stitch = vérité visuelle.*  
Projet historique Deck **ne pas copier** : `1264451048753434333`.  
Nouveau projet challenge : [`1254927388471488287`](https://stitch.withgoogle.com/projects/1254927388471488287).

IA cible : COMPTE → MOI → (CLUB) → SÉANCE. Plus de hub `/` « SÉLECTION PROFIL ».

Design systems Stitch :
- Hangar A : `assets/18287499718879528967`
- Bassin B : `assets/8677461250639537695`

---

## Tokens communs (C3)

| Token | Valeur |
|---|---|
| Device | iPhone 14/15 logical **390×844** portrait ; live **844×390** paysage |
| Display live | 56–72 |
| Title | 20–24 |
| Body | 15–17 |
| Meta | 12–13 |
| Hit | ≥ 48×48 |
| CTA primaire | full width, **52** tall |
| Chip statut | max 24 px — LOCAL / EN FILE / CLOUD / Démo / Non mesuré |
| Tribord | `#46C275` (imposé) |
| Bâbord | `#E05353` (imposé) |

Non négociable : pas Accueil/Retour sur live·cox·coach·tare running ; pas cyan High-Vis ; pas jargon SYS_ID ; cadence absente = « cadence non mesurée » ; compétition = « Téléphone au quai ».

---

## Direction A — Hangar (évolution Deck)

Instrument sombre, moins Caps Lock, hiérarchie claire.

| Token | Hex | Usage |
|---|---|---|
| bg | `#0B0E12` | fond |
| surface | `#151A20` | cartes / champs |
| hairline | `#2A313A` | règles |
| text | `#F2F4F6` | titres sentence case |
| muted | `#8B939C` | meta |
| primary CTA | `#E8C547` | CTA + alerte gîte seulement |
| on-primary | `#0B0E12` | texte sur CTA |
| warning | `#E8A838` | gîte soft (distinct si besoin) |
| danger | `#E05353` | = bâbord |
| Radius | 8–12 px | |
| Type UI | Manrope | texte |
| Type télémétrie | JetBrains Mono | chiffres live uniquement |

---

## Direction B — Bassin (challenger)

Plus club que cockpit. Accueils « club » ; live reste instrument.

| Token | Hex | Usage |
|---|---|---|
| bg | `#0E1418` | eau bleue-gris |
| surface | `#1A2229` | cartes (pas blanc sport-app) |
| hairline | `#2C3640` | |
| text | `#EEF2F5` | |
| muted | `#9AA6B2` | |
| primary CTA | `#3D9B8F` | teal — lisible soleil, ≠ bâbord rouge, ≠ tribords vert |
| on-primary | `#061210` | |
| warning | `#D4A017` | bandeau gîte (pas le CTA) |
| danger | `#E05353` | |
| Radius | 12 px | |
| Type | IBM Plex Sans | tout ; mono optionnel chiffres live |

Justification accent teal : contraste eau/soleil, pas de collision Bâbord `#E05353` ni Tribord `#46C275`, pas l’ambre Deck.

---

## Inventaire Stitch — 12 piliers

| Id | Direction | Screen id | Notes |
|---|---|---|---|
| DR-01 | Hangar A | `29ed063493e84a4d92608d8e881cfe48` | Qui rame ? liste 3 profils |
| DR-10 | Hangar A | `e5d0301709a74ac89dcbd7d74376ae19` | Connexion OFF |
| DR-20 | Hangar A | `0a9b30aac25c4bfb9b74ee69ab548fca` | Accueil — **bottom nav inventée** (pénalité jury) |
| DR-50 | Hangar A | `cdf344f6fd024fe7bc66ccd20511b62f` | Pré-séance |
| DR-52 | Hangar A | `3de0c450fb8c4deab4ad2b1b91f8530e` | Live gîte TRIBORD/BÂBORD + STOP |
| DR-33 | Hangar A | `bc2607505391435d8b78482aeda32afd` | Coach live — cadence inventée « 32 tr/min » |
| DR-01 | Bassin B | `cb8c8ae9164a4f2e874c40fe559f9a1d` | Qui rame ? teal CTA |
| DR-10 | Bassin B | `de251f1a5e214d47b1fa6a5b343e2176` | Connexion OFF |
| DR-20 | Bassin B | `453bd9855d6745fd9f75bd48c9b10e01` | Accueil — pas de bottom nav |
| DR-50 | Bassin B | `9b65f164e6c042ec8753384198211e16` | Pré-séance |
| DR-52 | Bassin B | `148b587626d34495802b73e50a1294a5` | Live instrument teal STOP |
| DR-33 | Bassin B | `e08d021b58c74847946c9e712f6502ee` | Coach live carte + note |

Captures locales : `/opt/cursor/artifacts/da-challenge/`.

---

## Jury (/5)

| Critère | Hangar A | Bassin B | Commentaire |
|---|---|---|---|
| 1. Orientation 3 s | 3 | 5 | Hangar DR-20 ajoute une tab bar « Hangar / Télémétrie » hors IA |
| 2. Métier distinct | 3 | 3 | Piliers = rameur + coach live seulement ; accueils coach/admin à venir |
| 3. Live soleil / gîte | 5 | 5 | Chiffres grands, TRIBORD/BÂBORD corrects, STOP×2 |
| 4. Honnêteté | 2 | 4 | Hangar invente « Capteurs prêts », cadence coach ; Bassin plus sobre |
| 5. Famille visuelle | 5 | 5 | 6 écrans cohérents dans chaque direction |
| 6. Français humain | 4 | 5 | Sentence case OK ; Hangar garde badges ALL CAPS type EMBARQUEMENT |
| 7. Pouce | 4 | 5 | CTA bas ; Hangar tab bar concurrence le pouce |
| **Total** | **26/35** | **32/35** | |

Rejets automatiques : aucun des deux n’est Strava, n’a Accueil sur live, ni hub rôle. OK.

### Verdict

**Direction retenue : Bassin (B).**  
Challenge réel du Deck (teal ≠ ambre, club ≠ cockpit), accueil plus propre, alerte gîte séparable du CTA (`#D4A017`).  
Hangar reste une piste d’évolution Deck si continuité ambre exigée — ne pas mélanger les tokens.

Tokens gelés → [`DA.md`](./DA.md).  
Suite inventaire §D **uniquement** en Bassin. **Pas de branchement Flutter** dans ce lot.

---

## Suite (hors ce PR)

1. Générer le reste inventaire §D en Bassin (états séparés).  
2. Agent reshape IA (`PROMPT-CURSOR-RESHAPE-IA.md`) peut rester parallèle — ne change pas les pixels.  
3. Branchement `DeckScaffold` / thème Flutter **après** gel DA.md + planches quai/tare/parc.
