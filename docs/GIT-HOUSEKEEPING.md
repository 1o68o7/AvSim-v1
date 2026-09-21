# Ménage Git — 21 septembre 2026

HEAD de référence : `main` = `6c45c1e` (merge #54 + add-ons Stitch).  
Produit actif : `apps/datar0w`. AvSim 1DOF gelé.  
Aucune fusion, aucun rebase, aucun force-push. Aucun fichier métier modifié.

## PR

| PR | Branche | Action | Raison |
|---|---|---|---|
| #8 | `cursor/stroke-geometry-36e5` | CLOSE stale | Analyste juillet, base `447d5cc` ; StrokeGeometry gelé |
| #9 | `cursor/analyst-bilan-equipage-36e5` | CLOSE stale | idem juillet AvSim |
| #10 | `cursor/cli-run-replay-36e5` | CLOSE stale | idem juillet AvSim |
| #12 | `cursor/phase1-credibility-36e5` | CLOSE stale | tests physiques gelés |
| #13 | `cursor/phase4-sensors-36e5` | CLOSE stale | capteurs virtuels CAN, hors produit club |
| #14 | `cursor/diag-eta-cf-triang-36e5` | CLOSE stale | diag 1DOF gelé |
| #16 | `cursor/reconcile-envelope-plaus-36e5` | CLOSE stale | idem juillet AvSim |
| #38 | `cursor/datarow-stitch-gel-6855` | CLOSE supersédé | gel HTML stale ; `docs/stitch-mvp/GEL.md` est sur main |
| #46 | `cursor/datarow-tare-orientation-7a63` | CLOSE supersédé | cherry-pick dans #54 mergée (`setDisplayRotation` / tare gîte sur main) |
| #50 | `cursor/datarow-supabase-b1-b4-7a63` | **REFUS close** | HEAD n’est pas ancêtre de main ; sync B1–B4 unique (outbox, LWW, RLS, `sync_engine`) |
| #52 | `cursor/datarow-import-cabane-d1-d5-7a63` | CLOSE supersédé | Point D déjà sur main ; base ≠ main |
| #55 | `feat/datarow-stitch-addons` | CLOSE déjà sur main | tip ancêtre de `6c45c1e` ; diff vs main vide après merge |

Commentaire de close (FR, toutes les PR fermées ci-dessus) :

> Stale / déjà sur main. Chantier AvSim juillet ou lot DataR0w supersédé par main `6c45c1e` (#53/#54 + add-ons).
> On ne merge pas. Branche remote à supprimer après close.
> Produit actif = apps/datar0w (entraînement hub tél. / compétition patch autonome).

Sur #50 : commentaire « À vérifier » uniquement. PR laissée **ouverte** (draft).

## Branches remote

### Conservées

| Branche | Raison |
|---|---|
| `main` | HEAD produit |
| `cursor/datarow-supabase-b1-b4-7a63` | HEAD de #50 ouverte ; commits DataR0w absents de main |

Tags existants : intacts.

### Supprimées (après close, plus HEAD d’une PR ouverte)

| Branche | Action | Raison |
|---|---|---|
| `cursor/stroke-geometry-36e5` | delete remote | PR #8 closed |
| `cursor/analyst-bilan-equipage-36e5` | delete remote | PR #9 closed |
| `cursor/cli-run-replay-36e5` | delete remote | PR #10 closed |
| `cursor/phase1-credibility-36e5` | delete remote | PR #12 closed |
| `cursor/phase4-sensors-36e5` | delete remote | PR #13 closed |
| `cursor/diag-eta-cf-triang-36e5` | delete remote | PR #14 closed |
| `cursor/reconcile-envelope-plaus-36e5` | delete remote | PR #16 closed |
| `cursor/datarow-stitch-gel-6855` | delete remote | PR #38 closed |
| `cursor/datarow-tare-orientation-7a63` | delete remote | PR #46 closed |
| `cursor/datarow-import-cabane-d1-d5-7a63` | delete remote | PR #52 closed |
| `feat/datarow-stitch-addons` | delete remote | PR #55 closed ; tip dans l’historique de main |
| `feat/datarow-reste-agent` | delete remote | entièrement dans main (#54 mergée) |
| `feat/datarow-stitch-final` | delete remote | entièrement dans main (#53 mergée) |
| `feat/datarow-mvp` | delete remote | entièrement dans main (#39/#40 mergées) |
| `cursor/blade-vn-catch-36e5` | delete remote | cimetière juillet, pas de PR ouverte |
| `cursor/chargeur-multi-classes-36e5` | delete remote | cimetière juillet |
| `cursor/check-factor-kleshnev-r-36e5` | delete remote | cimetière juillet |
| `cursor/com-theta-table-36e5` | delete remote | cimetière juillet |
| `cursor/crew-force-overlay-80b4` | delete remote | cimetière juillet |
| `cursor/datarow-fgs-kgp-7a63` | delete remote | mergée (#44) |
| `cursor/datarow-fix-baro-gradle-7a63` | delete remote | mergée (#43) |
| `cursor/datarow-gite-ecran-6855` | delete remote | mergée (#41) |
| `cursor/datarow-identity-i1-i5-7a63` | delete remote | plus de PR ouverte |
| `cursor/datarow-mvp-api-coach-7a63` | delete remote | mergée (#45) |
| `cursor/datarow-nav-cox-7a63` | delete remote | mergée (#48) |
| `cursor/datarow-parc-ops-c1-c6-7a63` | delete remote | mergée (#51) |
| `cursor/datarow-telemetrie-p0-7a63` | delete remote | mergée (#42) |
| `cursor/datarow-ux-tare-cox-7a63` | delete remote | mergée (#47) |
| `cursor/diag-cf-cycle-overview-36e5` | delete remote | cimetière juillet |
| `cursor/diag-vmin-drive-36e5` | delete remote | cimetière juillet |
| `cursor/doc-limits-cf-eta-36e5` | delete remote | cimetière juillet |
| `cursor/doc-power-inst-phase5-36e5` | delete remote | cimetière juillet |
| `cursor/drag-fpeak-hypothese-36e5` | delete remote | cimetière juillet |
| `cursor/eta-definition-gap-36e5` | delete remote | cimetière juillet |
| `cursor/events-sqlite-persist-36e5` | delete remote | cimetière juillet |
| `cursor/fermeture-force-36e5` | delete remote | cimetière juillet |
| `cursor/fish-curve-80b4` | delete remote | cimetière juillet / mergée |
| `cursor/fix-boatschematic-theta-36e5` | delete remote | cimetière juillet |
| `cursor/fix-oar-colinear-pose-36e5` | delete remote | cimetière juillet |
| `cursor/mode-c-observability-2x-36e5` | delete remote | cimetière juillet |
| `cursor/phase0-close-docs-36e5` | delete remote | cimetière juillet |
| `cursor/phase3-envelope-36e5` | delete remote | cimetière juillet |
| `cursor/product-coach-live-replay-36e5` | delete remote | cimetière juillet |
| `cursor/product-rameur-view-36e5` | delete remote | cimetière juillet |
| `cursor/product-team-replay-36e5` | delete remote | cimetière juillet |
| `cursor/render-da-tokens-80b4` | delete remote | cimetière juillet |
| `cursor/render-deploy-36e5` | delete remote | cimetière juillet |
| `cursor/shadcn-foundation-80b4` | delete remote | cimetière juillet |
| `cursor/stroke-length-bar-36e5` | delete remote | cimetière juillet |
| `cursor/stroke-v-a-tracks-80b4` | delete remote | cimetière juillet |
| `cursor/sweep-kdrag-fpeak-36e5` | delete remote | cimetière juillet |
| `cursor/team-view-4q-80b4` | delete remote | cimetière juillet |
| `cursor/ui-phase7-36e5` | delete remote | cimetière juillet |
| `cursor/widen-transition-blends-36e5` | delete remote | cimetière juillet |

**Totaux :** 11 PR closed, 0 merge, 54 branches remote supprimées, 1 PR refusée (#50).

Après `git fetch --prune`, les refs `origin` restantes sont `main` et `cursor/datarow-supabase-b1-b4-7a63`.
