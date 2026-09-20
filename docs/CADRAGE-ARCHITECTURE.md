# Point H — Architecture DataR0w (avant C / D / E)

> **Statut :** cadrage figé. Code non démarré.
> **Prérequis :** I1–I5 mergés, télémétrie P0/P1 en prod.
> **But :** poser la colonne vertébrale avant les points C (parc opérationnel), D (import cabane), E (calendrier FFA), F/G (scraper serveur / licenciés agrégés).
> **Règle :** pas de feature métier nouvelle tant que H1–H3 ne sont pas mergés.

---

## 0. Constat (vérifié sur `main`, HEAD `f836f560`)

### Ce qui est solide
- Feature-first : `features/` (live, coach, identity, cox, tare, quai, replay) + `session/`, `sensors/`, `identity/`, `theme/`, `widgets/`.
- GoRouter centralisé (`lib/router.dart`), thème Deck (`#0B0E12` / `#E8C547`), widgets partagés.
- Logique pure testable : `heel.dart`, `tare_math.dart`, `ffa_categories.dart`, `is_lightweight.dart`.
- `flutter_riverpod: ^2.6.1` **déjà dans le pubspec** — mais **jamais utilisé** (0 `Provider` / `Consumer` dans le code).

### Trous de design (patterns manquants)

| # | Trou | Impact dès que… | Sévérité |
|---|---|---|---|
| 1 | Pas de couche data/domain | Supabase (B), parc opérationnel (C), import (D) | **Bloquant** |
| 2 | Deux stores parallèles (`identity/store`, `session/store`) sans pattern commun | Sync multi-coach, conflits | Haut |
| 3 | State management absent (Riverpod déclaré, non branché) | Live poll, multi-coach, sync | **Bloquant** |
| 4 | Pas d'offline-first unifié (pas de file de sync, pas de SQLite, pas de stratégie de conflit) | B / C / D / E | Haut |
| 5 | Auth absente — routeur sans guard, « Passer (sans profil) » contourne tout | Parc (C), licenciés (G), rôles coach/admin | **Bloquant** |
| 6 | API client orphelin (`session/api_client.dart`) non branché systématiquement | B / F / G | Moyen |
| 7 | Pas de modèle d'erreurs / retry / timeout unifié | Tout réseau | Moyen |
| 8 | Pas de logging / crash reporting | Prod | Bas (plus tard) |
| 9 | Pas de tests d'intégration (widget + store) | Régressions | Moyen |

En une phrase : l'app est un bon prototype feature-first, mais il manque la colonne vertébrale — repositories + state management + auth + sync. Sans ça, les points B→G se casseront la figure.

---

## 1. Décisions figées

| # | Décision | Choix | Pourquoi |
|---|---|---|---|
| H-D1 | State management | **Riverpod 2.x** (déjà en dépendance) | Déjà déclaré, pas de migration, écosystème Flutter mature, testable. |
| H-D2 | Couche data | **Repository pattern** : interface abstraite + impl local (JSON) + impl remote (Supabase) | Permet de basculer local→remote sans toucher aux écrans. |
| H-D3 | Persistance locale | Rester sur JSON `Documents/datar0w/` pour H1–H3 ; **SQLite (drift)** reporté à H4 si volume le justifie | Évite une migration lourde avant d'avoir besoin de requêtes complexes. |
| H-D4 | Auth | **Supabase Auth** (magic link email) — même fournisseur que la sync (Point B) | Un seul compte, pas de double login. Rôles : `rower` / `cox` / `coach` / `admin`. |
| H-D5 | Sync | File offline-first : écriture locale immédiate + queue de sync + résolution de conflit last-write-wins avec horodatage | Le coach rame même sans réseau. |
| H-D6 | Erreurs | `Result<T, AppError>` (sealed) partout dans les repositories ; pas d'exception qui remonte dans l'UI | UI prévisible, tests faciles. |
| H-D7 | Navigation | GoRouter + **redirect guard** basé sur l'état auth/rôle | « Passer (sans profil) » reste possible mais marqué `anonymous` ; les routes `/club`, `/crew`, `/ops/*` exigent un rôle habilité. |
| H-D8 | Tests | Unit (repositories, use cases) + widget (écrans) + 1 golden par écran critique | Couverture minimale avant C. |
| H-D9 | Hors scope H | Pas de clean-arch stricte (pas de use-cases séparés tant que les écrans restent simples) ; pas de micro-frontends ; pas de changement de DA. | Rester pragmatique. |

---

## 2. Architecture cible

```
┌─────────────────────────────────────────────────────────┐
│  UI (features/*)  —  widgets + écrans, DA Deck          │
│         │ lit/écrit via providers                        │
├─────────▼───────────────────────────────────────────────┤
│  State (Riverpod)                                       │
│   - authProvider, sessionProvider, clubProvider…        │
│   - pas de logique métier ici, juste de l'état          │
├─────────▼───────────────────────────────────────────────┤
│  Use cases (lib/domain/)  —  optionnel, pur Dart        │
│   - composeCrew, checkoutBoat, importCabane…            │
├─────────▼───────────────────────────────────────────────┤
│  Repositories (lib/data/repo/)                          │
│   interface ──┬── LocalRepo (JSON, aujourd'hui)        │
│               └── RemoteRepo (Supabase, Point B)        │
├─────────▼───────────────────────────────────────────────┤
│  Sources : sensors/ (télémétrie), api/ (HTTP), fs/ (JSON)│
└─────────────────────────────────────────────────────────┘
```

Règles :
- Les **écrans ne connaissent pas** Supabase ni le filesystem. Ils parlent aux providers.
- Les **providers** parlent aux repositories.
- Les **repositories** choisissent local ou remote selon la connectivité + la file de sync.
- La **télémétrie** (`sensors/`, `session/live_hub.dart`) reste un domaine à part : elle écrit dans `session/store` (échantillon 1 Hz) — ce store devient un repository comme les autres à H2.

---

## 3. Lots (ordre de build)

### H1 — Fondations Riverpod + repositories (aucun écran)
- `lib/data/repo/` : interfaces `RowerRepository`, `ClubRepository`, `BoatRepository`, `AssignmentRepository`, `SessionRepository`.
- Impl `Local*Repository` : délègue aux stores actuels (`identity/store.dart`, `session/store.dart`) sans les casser.
- Providers Riverpod : `rowerRepositoryProvider`, etc. (override local par défaut).
- `AppError` sealed (`network`, `storage`, `validation`, `auth`, `unknown`).
- Brancher **un** écran pilote (ex. `IdentityListScreen`) sur le provider — preuve que le pattern marche.
- Tests : round-trip local, erreur simulée.
- **Commit :** `refactor(datar0w): riverpod + repository interfaces (local)`

### H2 — Auth + guard routeur
- `lib/auth/` : `AuthRepository` (Supabase Auth magic link), `authProvider` (session, rôle).
- Rôles : `rower` | `cox` | `coach` | `admin` | `anonymous`.
- GoRouter `redirect` : `/club`, `/crew`, `/ops/*`, `/home/coach` → rôle `coach|admin` ; `/home/rower|/home/cox` → `rower|cox|coach` ; le reste public.
- « Passer (sans profil) » → `anonymous` : accès télémétrie seul, pas de parc/composition.
- Migration : profils locaux existants → liés au compte au premier login (pas de perte).
- Tests : guard refuse / autorise selon rôle.
- **Commit :** `feat(datar0w): auth supabase + route guards`

### H3 — Sync offline-first (branche remote)
- `Remote*Repository` (Supabase) + `SyncQueue` (file locale, retry exponentiel).
- Stratégie : écriture locale **immédiate**, push async, last-write-wins + `updated_at`.
- Conflit : dernier écrit gagne ; affichage « synchronisé / en attente » dans l'UI.
- Branchement : `ClubRepository` + `BoatRepository` d'abord (parc), puis `AssignmentRepository`.
- Tests : file, retry, conflit simulé.
- **Commit :** `feat(datar0w): offline-first sync queue + remote repos`

### H4 — (Optionnel, si volume) SQLite via drift
- Uniquement si les requêtes JSON deviennent lentes (gros parc, historique sorties). Pas avant.
- **Commit :** `feat(datar0w): sqlite drift for local store`

### H5 — Qualité
- Golden tests : 1 par écran critique (identité, club, crew, live).
- Logging structuré (console dev, Sentry plus tard).
- CI : `flutter analyze` + `flutter test` sur chaque PR.
- **Commit :** `ci(datar0w): analyze + test + goldens`

---

## 4. Hors scope (volontaire)
- Refonte visuelle / nouvelle DA.
- Changement de télémétrie (P0/P1 gelés).
- Multi-plateforme (iOS/web) — Android d'abord.
- Micro-services, clean-arch stricte, BLoC.
- Points C/D/E/F/G : **après** H1–H3.

---

## 5. Prompt Cursor

```
Point H — architecture DataR0w. Lis docs/CADRAGE-ARCHITECTURE.md.
Ne pas toucher AvSim. Ne pas revert compileSdk 37 / ndkVersion 30.0.16248370.
Pas de sdkmanager. Pas de windows/. Pas de nouvelle feature métier (C/D/E interdits ici).
flutter_riverpod est DÉJÀ dans pubspec — l'utiliser, ne pas l'ajouter.

## H1 — Riverpod + repositories (aucun écran métier)
- lib/data/repo/ : interfaces RowerRepository, ClubRepository, BoatRepository,
  AssignmentRepository, SessionRepository.
- Impl Local*Repository : délègue aux stores actuels (identity/store.dart,
  session/store.dart) SANS les casser. Comportement identique.
- Providers : rowerRepositoryProvider, clubRepositoryProvider, … (override local).
- AppError sealed (network|storage|validation|auth|unknown) — Result<T,AppError>.
- Brancher UN écran pilote (IdentityListScreen) sur le provider pour prouver le pattern.
- Tests : round-trip local, erreur simulée. flutter analyze clean.
Commit : refactor(datar0w): riverpod + repository interfaces (local)

## H2 — Auth + guard routeur
- lib/auth/ : AuthRepository (Supabase Auth magic link), authProvider (session+rôle).
- Rôles : rower|cox|coach|admin|anonymous.
- GoRouter redirect : /club /crew /ops/* /home/coach → coach|admin ;
  /home/rower /home/cox → rower|cox|coach ; reste public.
- « Passer (sans profil) » → anonymous (télémétrie seule, pas de parc).
- Migration : profils locaux existants liés au 1er login (pas de perte).
- Tests : guard refuse/autorise. flutter analyze clean.
Commit : feat(datar0w): auth supabase + route guards

## H3 — Sync offline-first
- Remote*Repository (Supabase) + SyncQueue (file locale, retry exponentiel).
- Écriture locale immédiate, push async, last-write-wins + updated_at.
- Conflit : dernier écrit gagne ; chip « synchronisé / en attente ».
- Branchement : ClubRepository + BoatRepository d'abord, puis AssignmentRepository.
- Tests : file, retry, conflit simulé. flutter analyze clean.
Commit : feat(datar0w): offline-first sync queue + remote repos

## H4/H5 — seulement si H1–H3 verts
- H4 SQLite (drift) si requêtes lentes. H5 goldens + CI analyze/test.
Ordre strict : H1 → H2 → H3. Stop si analyze casse.
Un commit par lot. Pas de PR fourre-tout.
```

---

## 6. Critère de sortie

H est **terminé** quand :
1. Au moins un écran lit/écrit via un provider Riverpod (plus d'accès direct au store depuis l'UI).
2. Le routeur refuse `/club` à un `anonymous`.
3. Un repository a une impl remote branchée (même stub) + file de sync testée.
4. `flutter analyze` clean, tests H1–H3 verts.

Alors seulement : ouvrir le point C (parc opérationnel).
