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

| Stitch | Route | Notes |
|---|---|---|
| DR-10 Connexion | `/auth` | Volt CTA |
| DR-02 Fiche rameur | `/identity/edit` | |
| DR-03 Licence & club | `/onboarding/rower`, `/club` | |
| DR-FR-00 Promesse funnel | `/funnel/onboard` | Lot 1 — pratique + premier morceau · `e9d5f8dc25fe4b32834c57bf4d5b479c` · gel `dr-fr-00-promesse.html` |
| DR-FR-H Home carte jour | `/home/rower` | Carte `Aujourd’hui · {distance}` · gel `dr-fr-h-home.html` |
| DR-FR-A Ateliers brevet | `/funnel/ateliers` | Lot 2 — 5 min / 3×1 / 1 000 annoncé / relais · `d849835042894645b5b618070d8db897` · gel `dr-fr-a-ateliers.html` |
| DR-FR-3 Preview erg | `/funnel/preview` | DF, cues, CTA « Je suis sur l’erg » · `4c582f4f795d462ab7998917f9fb7876` · gel `dr-fr-3-preview.html` |
| DR-FR-P PM5 | `/funnel/pm5` | Lot 3 — scan/relier PM5, DF live · gel `dr-fr-p-pm5.html` (local ; sync Stitch si dispo) |
| DR-FR-5 Player erg | `/funnel/player` | Split hero, restant, stop → partiel · `ac0af2e8becb4c0a909ee70b9e0ed03f` · gel `dr-fr-5-player.html` |
| DR-FR-R Relais 4×500 | `/funnel/player` | Jambe N/4, barre 4 segments · `3b811b20bbc74512bdbcd5c9a5761372` · gel `dr-fr-r-relais.html` |
| DR-FR-6 Preuve | `/funnel/proof` | Temps / split / cadence / watts / DF · `92091af51d0d404f9df3fc6e454c86e2` · gel `dr-fr-6-preuve.html` |
| DR-30 Aujourd’hui Coach | `/home/coach` | |
| DR-31 Composer équipage | `/crew` | |
| DR-32 Rejoindre par code | `/join` | |
| DR-33 Live Coach | `/coach` | |
| DR-34 Séances du club | `/club/sessions` | |
| DR-40 Aujourd’hui Staff | `/home/admin` | |
| DR-41 Fiche bateau | `/club/boat` | |
| DR-42 Trésorerie | — | hors MVP téléphone |
| DR-43 Calendrier | `/calendar` | |
| DR-45 Plans d’eau | `/waters` | |
| DR-52 Gîte paysage | `/live` | Cockpit 3 col. + `HeelGauge` avionique · gel `dr52-gite-paysage.html` / `dr52-cockpit-956.html` |
| DR-52 Sur l’eau (portrait) | `/live` | Même route ; planche Stitch portrait non portée séparément |
| DR-53 Live barreur | `/cox` | |
| DR-54 Quai | `/quai` | |
| DR-55 Replay rameur | `/replay` | `RowerReplayScreen` + `ReplayBody` · gel `dr55-replay.html` |
| DR-56 Replay flotte | `/replay-coach` | `CoachReplayScreen` · gel `dr56-replay-flotte.html` |
| DR-60 Mes séances | `/sessions` | |
| DR-61 Objets BLE | `/devices` | |
| DR-62 Santé / consentement | `/consent` | |
| DR-63 Journal BLE | `/devices` (diag) | |
| DR-70 Sortir coque | `/ops/out` | |
| DR-71 Rentrer coque | `/ops/in` | |
| DR-72 Alignement | `/ops/departure` | |

Shell standard : 3 onglets `Aujourd’hui` · `Séances` · `Plus` (indicateur Volt 2px) —  
`DeckTabScaffold` (`lib/widgets/deck_shell.dart`) + route `/plus`.  
Mode eau : plein pont telemetry, pas de bottom nav.

| Stitch hub | Route Flutter | Layout |
|---|---|---|
| DR-20 Aujourd’hui rameur | `/home/rower` | `HomeRowerScreen` + shell |
| DR-30 Aujourd’hui coach | `/home/coach` | `HomeCoachScreen` + shell |
| DR-60 Séances | `/sessions` | `SessionHistoryScreen` + shell |
| Plus (grille) | `/plus` | `PlusScreen` + shell |
| DR-10 Connexion | `/auth` | layout redesign (sans bottom nav) |

## Obsolète

- `docs/stitch-mvp/` (Hangar / ambre `#E8C547` CTA, coins carrés, ALL CAPS) — **ne plus porter**.
- Cyan High-Vis `#00E676` — interdit.
- DS Bauhaus dans le projet Stitch redesign — non utilisé côté app.
