# Cadrage — fix UX audit 21 septembre 2026

Source : audit `AUDIT-UX-UI-ET-ANALYSE-2026-09-21.md`.  
Vérité produit : `docs/ETAT-DATAROW.md`. Physique : `STATE.md` (gelée).

HEAD de travail : `main` (dart-defines #56 mergée). Produit = `apps/datar0w`.

---

## §0 Règles (ne pas négocier)

1. Lots A et B : ne pas ouvrir C (LIVE-AFFORDANCE, COACH-IA, etc.).
2. **Live / cox / coach** : aucun leading, aucun Accueil. Sortie live/cox = STOP 2× → `/quai`.
3. **Pas de #50.** Ne pas merger / rebase `cursor/datarow-supabase-b1-b4-7a63`. Ne pas toucher `lib/sync/` hors lecture.
4. **Pas de secrets.** Pas de `dart_defines.json`, pas de `service_role`, pas d’URL/JWT projet.
5. **Pas d’AvSim.** Ne pas rouvrir η / check_factor / sensors virtuels / StrokeGeometry / `params/*.yaml`.
6. **DA Deck inchangé** sauf `ColorScheme.error` : `#0B0E12` / blanc / `#9AA0A6` / `#2A2F36` / CTA `#E8C547` / TRIBORD `#46C275` / BÂBORD `#E05353`. Pas de cyan High-Vis.
7. Gîte : alerte **ambre** (`DeckColors.alert`) ; BÂBORD/TRIBORD **inchangés**. L’erreur bloquante n’est plus l’ambre.
8. Pas d’Accueil sur `/live` `/cox` `/coach`. compileSdk 37 / NDK : ne pas revert.
9. Tests **nouveaux** pour delete ; ne pas affaiblir des seuils existants.
10. Zéro scrape FFA. Zéro firmware.

---

## Lot A (cette PR)

| Ticket | Fichiers | Attendu |
|---|---|---|
| CONFIRM-DELETE | `screen_who.dart` | `AlertDialog` avant `deleteRower`. Annuler = no-op. Confirmer = retire le profil. |
| TITLES-HUMAN | pré-session, tare, accueil barreur | Plus de `2A` / `2B` / `DATAR0W /` dans les **titres UI**. « PRÉ-SESSION », « ÉTALONNAGE / TARE ». |
| COLOR-ERROR | `deck_theme.dart` | `ColorScheme.error` ≠ ambre CTA. Rouge `#E05353`. `primary` reste ambre. |
| AppBar | `deck_scaffold.dart` | Titre **14–16 px**. Sous-titre plus petit, optionnel. |

Hors Lot A (fait ailleurs) : NAV-BACK = Lot B. Pas de LIVE-AFFORDANCE / COACH-IA / #50.

---

## §2.4 Lot B — NAV-BACK (convention Retour)

| Surface | Leading |
|---|---|
| `/live` `/cox` `/coach` | **Aucun**. Pas d’Accueil. |
| Tare `running` | **Aucun** (ne pas jeter l’étalonnage). |
| `/identity` | Aucun (racine). |
| Gate « Réservé au coach » | **Retour** → toujours `/` |
| Accueils rôle | **Retour** → pop si `canPop`, sinon `/` |
| Ailleurs (`DeckScaffold`) | **Retour** → pop si `canPop`, sinon hub `/home/{rower,cox,coach}` |

Libellé unique : « Retour » (plus de « Retour profil » / Accueil).

---

## Tests Lot A

- Tap icône delete → dialogue ; profil encore listé.
- ANNULER → profil encore listé.
- SUPPRIMER → profil disparu.
- `ColorScheme.error != DeckColors.amber`.
- Titre AppBar `fontSize` ∈ [14, 16].
- Pré-session / tare : pas de `2A` / `2B` visibles.

## Tests Lot B

- `/live` et `/cox` : pas d’Accueil, pas de `DeckRetour` / Retour leading.
- Gate « Réservé au coach » : Retour → `/`.
- Tare en cours : pas de Retour (déjà `nav_test`).

