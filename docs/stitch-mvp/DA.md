# DataR0w — DA gelée (direction Bassin)

*Gel après challenge Hangar vs Bassin — 30 sept 2026.*  
Projet Stitch : `1254927388471488287` · DS : `assets/8677461250639537695`.  
**Pas de Flutter tant que les planches §D restantes ne sont pas posées.**

IA : `COMPTE → MOI → (CLUB) → SÉANCE`.

---

## Couleurs (8 tokens + imposés)

| Token | Hex | Usage |
|---|---|---|
| `bg` | `#0E1418` | fond app |
| `surface` | `#1A2229` | cartes, champs, listes |
| `hairline` | `#2C3640` | séparateurs 1 px |
| `text` | `#EEF2F5` | titres + corps |
| `muted` | `#9AA6B2` | meta, helpers |
| `primary` | `#3D9B8F` | CTA primaire uniquement |
| `onPrimary` | `#061210` | texte / icône sur CTA |
| `warning` | `#D4A017` | bandeau gîte (≠ CTA) |
| `tribord` | `#46C275` | imposé — gauche rameur |
| `babord` / `danger` | `#E05353` | imposé — droite rameur |

Chips honnêteté : **Local** / **En file** / **Cloud** / **Démo** / **Non mesuré**.  
Jamais `0` ou `—` pour une cadence absente → « cadence non mesurée ».

---

## Type

| Rôle | Famille | Taille |
|---|---|---|
| Display live | IBM Plex Sans ou mono (chiffres seuls) | 56–72 |
| Title | IBM Plex Sans | 20–24 |
| Body | IBM Plex Sans | 15–17 |
| Meta | IBM Plex Sans | 12–13 |

Sentence case partout sur accueils / compte. Pas d’ALL CAPS cockpit hors labels TRIBORD / BÂBORD / STOP.

---

## Forme & hit

- Radius **12 px**
- Hit ≥ **48×48**
- CTA primaire full width, **52** tall, une action primaire par écran
- Chip statut max **24 px**
- Live / tare running / coach live : **pas** Accueil, **pas** Retour — sortie STOP×2
- Ailleurs : un seul leading **Retour**

---

## Piliers Stitch (référence)

| Id | Screen id |
|---|---|
| DR-01 | `cb8c8ae9164a4f2e874c40fe559f9a1d` |
| DR-10 | `de251f1a5e214d47b1fa6a5b343e2176` |
| DR-20 | `453bd9855d6745fd9f75bd48c9b10e01` |
| DR-50 | `9b65f164e6c042ec8753384198211e16` |
| DR-52 | `148b587626d34495802b73e50a1294a5` |
| DR-33 | `e08d021b58c74847946c9e712f6502ee` |

Détail challenge + scores : [`DA-CHALLENGE-2026.md`](./DA-CHALLENGE-2026.md).
