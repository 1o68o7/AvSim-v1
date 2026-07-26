# Brief interface utilisateur — DataR0w

*25 juillet 2026 · Phase 7 · mis à jour après revue PR #7*

## État (main `447d5cc` + suite StrokeGeometry)

- API sous `src/avsim/api/` : rôles `X-DataR0w-Role`, routes classes/params/
  validate/simulate ; `/api/pose` + `/api/pose/series` (géométrie Python).
- `BoatSchematic` (§4.1a) : vue de dessus — **garder tel quel**.
- `StrokeGeometry` (§4.1b) : vue latérale — **une seule source** via
  `avsim.core.pose` / `/api/pose` (pas d'IK TypeScript).
- Badges Simulé + Validée/Bêta. Surface Produit encore en stubs.
- Séparation de rôle = convention d'interface (pas auth forte) — OK usage interne.

## Priorité restante

1. Perf `/simulate` (~17 s 8+) avant Produit/replay
2. Surface Produit + `avsim replay --realtime`
3. Maquettes 🟡 → réel quand Phases 4/5 existent
