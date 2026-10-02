# Gel Stitch Redesign → Flutter (DataR0w)

*1er oct 2026 — remplace Hangar / Bassin (`docs/stitch-mvp/`, ambre CTA).*

**Source of truth :** Stitch [DataR0w App Redesign](https://stitch.withgoogle.com/projects/17394974384541320335)  
`projects/17394974384541320335` · DS **Technical Nautical Deck** (`assets/bf355ec435254956a0d5b06ef278b745`).

## Tokens (Flutter `DeckColors` / `DeckType`)

| Rôle | Hex | Usage |
|---|---|---|
| Deep Ink | `#0A0A0A` | Fond app |
| Surface | `#111418` | Cartes / pods |
| Elevated | `#181D24` | Inputs / sheets |
| Hairline | `#2A2F36` | Bordures 1px (pas d’ombre) |
| Texte | `#F4F6F8` | Valeurs / titres |
| Muted | `#8C96A5` | Unités / secondaire |
| **Volt** | `#D6FF3C` | CTA, pacing, onglet actif, sélection |
| Tribord | `#46C275` | Starboard, CLOUD, delta + |
| Bâbord | `#E05353` | Port, erreur, MOCK |
| Ambre | `#E8C547` | EN FILE, maintenance, alerte gîte |

Typo : **Inter** (UI sentence-case) + **JetBrains Mono** (métriques).  
Rayons : chip 6 · bouton 12 · carte 14. Pas de coins carrés Hangar.

## Badges honnêtes

`DeckHonestChip` — LOCAL / EN FILE / CLOUD / DÉMO / CLUB.

Sync ST-09 : le bandeau global 36 px n’apparaît **que** si alerte
(EN FILE, CTA club, statut retry). LOCAL / CLOUD calmes restent dans
les headers / pilules des écrans hub — pas de strip permanent sous AppBar.

## Mapping DR → routes Flutter

| Stitch | Route | Layout / notes |
|---|---|---|
| DR-01 Qui rame | `/identity` | `IdentityListScreen` |
| DR-02 Fiche rameur | `/identity/edit` | |
| DR-03 Licence & club | `/onboarding/rower`, `/club` | |
| DR-10 Connexion | `/auth` | Volt CTA · sans bottom nav |
| DR-20 Aujourd’hui rameur | `/home/rower` | `HomeRowerScreen` + shell |
| DR-30 Aujourd’hui Coach | `/home/coach` | `HomeCoachScreen` + shell |
| DR-31 Composer équipage | `/crew` | |
| DR-32 Rejoindre par code | `/join` | |
| DR-33 Live Coach | `/coach` | |
| DR-34 Séances du club | `/club/sessions` | |
| DR-40 Aujourd’hui Staff | `/home/admin` | |
| DR-41 Fiche bateau | `/club/boat` | |
| DR-42 Trésorerie | — | **hors scope** téléphone / MVP |
| DR-43 Calendrier | `/calendar` | |
| DR-45 Plans d’eau | `/waters` | |
| DR-50 Préparer séance | `/presession` | |
| DR-51 Tare | `/tare` | |
| DR-52 Gîte paysage | `/live` | Cockpit 3 col. + `HeelGauge` |
| DR-53 Live barreur | `/cox` | |
| DR-54 Quai | `/quai` | |
| DR-55 Replay rameur | `/replay` | `RowerReplayScreen` + `ReplayBody` |
| DR-56 Replay flotte | `/replay-coach` | `CoachReplayScreen` |
| DR-60 Mes séances | `/sessions` | shell |
| DR-61 Objets BLE | `/devices` | |
| DR-62 Santé / consentement | `/consent` | |
| DR-63 Journal BLE | `/devices/journal` | `BleJournalScreen` · diag local |
| DR-64 Réglages | `/settings` | lien journal + objets |
| DR-70 Sortir coque | `/ops/out` | |
| DR-71 Rentrer coque | `/ops/in` | |
| DR-72 Alignement | `/ops/departure` | |
| Plus (grille) | `/plus` | shell |

Shell standard : 3 onglets `Aujourd’hui` · `Séances` · `Plus` (indicateur Volt 2px) —  
`DeckTabScaffold` (`lib/widgets/deck_shell.dart`) + route `/plus`.  
Mode eau : plein pont telemetry, pas de bottom nav.

## Obsolète

- `docs/stitch-mvp/` (Hangar / ambre `#E8C547` CTA, coins carrés, ALL CAPS) — **ne plus porter**.
- Cyan High-Vis `#00E676` — interdit.
- DS Bauhaus dans le projet Stitch redesign — non utilisé côté app.
