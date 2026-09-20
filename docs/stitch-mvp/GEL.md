# DataR0w — gel Stitch MVP (16 sept. 2026)

Référence unique pour Flutter `/apps/datar0w`. Intention Deck, **pas** pixel-perfect.
HTML gelé dans `docs/stitch-mvp/gel/`. Ne pas porter les fichiers « jeter ».

Contrats : `docs/CURSOR-SESSION-MVP-RAMEUR.md`, `docs/CONVENTION-BABORD-TRIBORD.md`,
`docs/CARTE-LIVE-REPLAY.md`. DA : `#0B0E12` / blanc / `#9AA0A6` / `#2A2F36` / alerte `#E8C547`.

## Gel (source Flutter)

| Écran | Fichier gel | Source upload | Format |
|---|---|---|---|
| 1 Profils | `gel/01-profils.html` | `code_cran_1_profils_datar0w_marine_avionics_deck` | 390×844 |
| 2A Pré-session | `gel/02a-presession.html` | `code_cran_2a_pr_session_marine_avionics_deck` | 390×844 |
| 2B Tare | `gel/02b-tare-gite.html` | `code_cran_2b_tare_g_te_marine_avionics_deck` | 390×844 |
| 3 Live rameur | `gel/03-live-rameur.html` | `code_cran_3_rameur_live_paysage_844_390_marine_avionics` | **844×390** |
| 4 Alerte | `gel/04-alerte-gite.html` | `code_cran_4_rameur_alerte_paysage_844x390` | **844×390** |
| 5 Coach live | `gel/05-coach-live.html` | `code_cran_5_coach_live_openstreetmap_bordeaux_lac` | **844×390** |
| 6 Coach replay | `gel/06-coach-replay.html` | `code_cran_6_coach_replay_844_390_marine_avionics` | **844×390** |
| 7 Quai | `gel/07-quai.html` | `code_cran_7_quai_marine_avionics_deck_pur` | 390×844 |

Replay rameur (6r) : même fichier séance que 6, carte + V + distance au curseur + 2 courbes.
Pas de HTML dédié — dériver de 6, sans colonne « évaluation ».

## Jeter (ne pas copier dans Flutter)

| Upload | Motif |
|---|---|
| `code_cran_1_entr_e_profil_marine_avionics_deck` | Hub télémétrie, 4G RTK, SYS READY, onglets CONFIG/REPLAY/DEBRIEF, avatar |
| `code_cran_2b_tare_g_te_paysage_844_390_instrument` | 2B labo paysage (déjà hors contrat) |
| `code_cran_3_rameur_live_marine_avionics_deck` | REC, 10 Hz, horizon 3D, split /500 m |
| `code_cran_5_coach_live_marine_avionics_deck` | RTK, watts, diagnostic biomécanique, PORT/STARBOARD, onglets |
| `code_cran_6_coach_replay_marine_avionics_deck` | 3 courbes, RTK, onglets, verdicts |
| `code_cran_7_quai_fin_de_s_ance_marine_avionics_deck` | RTK LOCK, « télémétrie officielle », DEBRIEF, onglets |

## Patches obligatoires au portage (HTML gelé ≠ spec produit)

- **2A** : classe **1x verrouillée**. BLE = `— aucun`. Pas de FIX RTK / 10 Hz. CTA `Continuer — tare gîte`.
- **2B** : Démarrer inactif tant que tare ≠ OK (σ < 0,2° sur 30 s). Gauche = BÂBORD.
- **3** : cadence `—` si période instable 6 coups. Pastille GPS, **pas** `SOG 10HZ`. Vitesse légendée `sol — pas eau`. STOP 2 appuis.
- **4** : même 3 colonnes que 3. Bandeau **36 px `#E8C547` texte noir** `GÎTE — trop tribords`. Le HTML source a un bandeau **cyan `#00E676`** — **ne pas** le porter.
- **5** : carte sombre + trace ; pas de couloirs FISA sans GeoJSON. Chip `réf. rameur`. `ANNOTER`. Pas d’envoi de consigne.
- **6** : 2 courbes seulement (cadence, V sol). Δ brut autorisé, pas de bon/mauvais.
- **7** : 4 chiffres + chip `en attente réseau` + `Partager au coach` / `Retour accueil` (déjà dans le HTML pur). Replay rameur depuis ce quai.

## Hors contrat (rappel)

Watts, η, slip, Analyste, RTK, 10 Hz GNSS, micro/caméra, barreur, pixel High-Vis, solveur AvSim.
