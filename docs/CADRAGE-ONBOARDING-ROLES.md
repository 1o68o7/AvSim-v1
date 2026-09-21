# Cadrage — Onboarding, rôles club, Google OAuth

*21 septembre 2026. Figé après audit UX + décision produit.*
Complète `docs/ETAT-DATAROW.md` §6, `docs/CADRAGE-IDENTITE-CLUB-EQUIPAGE.md` §3
(« pas de login fédéré » → **révoqué**), `docs/CADRAGE-SUPABASE.md` §décisions §2.

---

## 0. Une phrase

**Deux portes d'entrée, pas une.** Le rameur entre simple (Google ou sans compte,
licence FFA optionnelle). Le club (coach, dirigeants) entre par une autre porte,
verrouillée. Un rameur peut devenir barreur plus tard — même branche, rôle
additionnel. Les dirigeants ne mélangent jamais avec la branche rameur.

---

## 1. Auth — Google via Supabase (décision figée)

| Avant (MVP B) | Maintenant |
|---|---|
| Email + magic link seulement | **Google OAuth** = login principal |
| « Pas de login fédéré » | Révoqué — Google est le chemin nominal |
| Magic link = seul | Magic link = **fallback** (compte sans Gmail, ou refus OAuth) |

**Pourquoi Google, pas un tiers :** Supabase Auth a le provider Google **natif**,
gratuit sur le plan Free (jusqu'à 50 000 MAU). Pas de service tiers, pas de coût
supplémentaire. Le `auth.users.id` Supabase reste la clé — Google ne fait que
prouver l'identité à l'inscription / connexion.

### 1.1 Setup (humain, dashboard — une fois)

1. **Google Cloud Console** → projet (ou existant) → APIs & Services →
   **OAuth consent screen** (External, test users = le club au début) →
   **Credentials** → Create OAuth client ID → **Web application**.
   - Authorized JavaScript origins : `http://localhost:<port>` (dev),
     URL de prod plus tard.
   - Authorized redirect URIs : l'URL callback **Supabase**
     (`https://<ref>.supabase.co/auth/v1/callback`) — affichée sur la page
     provider Google du dashboard Supabase.
2. Copier **Client ID** + **Client Secret**.
3. **Supabase Dashboard** → Authentication → Providers → **Google** → ON →
   coller Client ID + Secret → Save.
4. Authentication → URL Configuration → Redirect URLs : ajouter
   `datarow://auth/callback` (déjà là pour magic link, on garde les deux).
5. Secrets app : **aucun nouveau dart-define**. `SUPABASE_URL` +
   `SUPABASE_ANON_KEY` suffisent — le flow OAuth passe par le SDK
   `supabase_flutter` (`signInWithOAuth(provider: OAuthProvider.google)`).
   Le Client Secret Google **ne quitte jamais** le dashboard Supabase.

### 1.2 Côté Flutter

- Bouton « Continuer avec Google » → `supabase.auth.signInWithOAuth(
  provider: OAuthProvider.google, redirectTo: 'datarow://auth/callback')`.
- Deep link `datarow://auth/callback` récupère la session (même handler que
  magic link).
- Fallback : lien « Se connecter par email » → magic link existant.
- Session persistée : `supabase_flutter` gère le refresh token ; l'app
  démarre connectée si session valide.
- **Jamais** stocker le token Google en dur ; pas de `service_role`.

### 1.3 Ce que Google ne fait PAS

- Ne crée **pas** le `Rower` ni le `club_members` tout seul. Après le 1er
  login Google, l'app demande le parcours (§2) et crée les lignes SQL.
- Ne remplace **pas** la licence FFA : le rameur la saisit (ou scanne) dans
  son profil, c'est une donnée métier, pas une preuve d'identité.

---

## 2. Deux parcours (figés)

```
                    ┌─ « Continuer avec Google » ─┐
Écran d'entrée ─────┤                             ├─→ Parcours A : RAMEUR
                    └─ « Sans compte (loisir) » ──┘         (branche simple)
                                        │
                                        └─→ Parcours B : CLUB
                                              (branche verrouillée)
```

Les deux portes sont **visuellement et route-ment distinctes**. Un utilisateur
club ne doit jamais atterrir sur le flow rameur, et inversement. Après login,
l'app route selon le rôle résolu (§3) — pas de choix « tu es quoi ? » flottant.

### 2.1 Parcours A — Rameur (simple, friction minimale)

1. Google (ou « Sans compte ») → session.
2. Si 1er login : écran **« Ton profil rameur »** — nom, date de naissance,
   sexe. Licence FFA : **optionnelle** (saisie libre ou « je n'en ai pas »).
   Catégorie FFA = `ageCategory(birthDate)`, lecture seule.
3. Rattachement club : code court du club (`join_club`) **ou** « je rame seul
   (loisir) » → pas de club, mode local.
4. Ensuite = flux actuel : `/presession` → `/tare` → `/live` → STOP 2× →
   `/quai`. Rien de plus à l'écran.
5. **Barreur** : même branche. Un rameur peut **ajouter le rôle barreur**
   plus tard (depuis son profil → « Je barre aussi ») : même `user_id`,
   `club_members.role` passe `rower` → `cox` (ou double appartenance si le
   schéma l'autorise — à trancher en implémentation, défaut = rôle unique
   modifiable). Pas de nouvelle porte d'entrée.

### 2.2 Parcours B — Club (coach / dirigeants, verrouillé)

1. Entrée **séparée** : « Espace club » (lien discret sur l'écran d'entrée,
   ou route `/club/login`). Pas mélangé avec le CTA rameur.
2. Auth : **Google obligatoire** pour créer/rejoindre un club (pas de
   « sans compte » ici — un dirigeant a une identité). Magic link en
   fallback seulement.
3. 1er login : l'app vérifie `club_members` pour cet `user_id`.
   - Déjà membre → route vers `/home/{rôle}`.
   - Pas membre → écran **« Rejoindre ou créer un club »** :
     - code court existant → `join_club(code)` avec rôle demandé
       (`coach` / `treasurer` / `director` / `intendant`) — **soumis à
       validation admin** (pas d'auto-promotion) ;
     - ou « Créer mon club » → INSERT `clubs` (trigger → `admin`) puis
       attribution du rôle dirigeant.
4. Rôles club (§3) : coach, trésorier, intendant, directeur, admin.
   Chacun a sa home et ses écrans ; le verrou RLS (§4) empêche un
   rameur d'écrire le parc ou de voir la trésorerie.

### 2.3 Ce qui ne change PAS

- Séance **sans profil** (« Passer ») reste possible (loisir, rétro-compat).
- Un téléphone = un club actif au MVP (décision §6.6 d'`ETAT-DATAROW`).
- Pas d'Accueil sur `/live` `/cox` `/coach` (STOP 2×).
- Côté / pelles = `Assignment`, pas `Rower.sidePref`.
- Catégorie FFA = fonction de `birthDate`.

---

## 3. Rôles club (étendus)

Aujourd'hui SQL : `admin | coach | rower | cox`. On **ajoute** les fonctions
support sans casser l'existant :

| Rôle | Qui | Accès |
|---|---|---|
| `rower` | Rameur | Son profil, ses séances, son affectation. Pas le parc éditable. |
| `cox` | Barreur | Comme rower + composition si besoin. |
| `coach` | Coach | Parc éditable, import rameurs, composition `/crew`, live coach. |
| `treasurer` | Trésorier | Cotisations / budget (écran futur, hors ce lot). |
| `intendant` | Intendant / parc | Maintenance, sorties, inventaire pelles. |
| `director` | Directeur | Vue d'ensemble club, validation des demandes de rôle. |
| `admin` | Créateur / gestionnaire | Tout + gestion membres. |

**Règle de verrou :** un rôle `rower`/`cox` **ne peut pas** écrire
`boats`, `assignments`, ni importer des rameurs (RLS `rowers_write` /
`boats_write` = `admin|coach` seulement — déjà en place dans `0001`).
Les nouveaux rôles `treasurer` / `intendant` / `director` héritent des
politiques `coach` pour le parc, et auront leurs propres politiques SQL
quand leurs écrans existeront. **Pas d'écran trésorier dans ce lot** —
juste le rôle réservé en SQL pour ne pas le redécouper plus tard.

---

## 4. RLS & données (rappel, non négociable)

- Tenant = `clubs.id`. Un membre ne lit/écrit **que** son club.
- `rowers_write` / `boats_write` / `assignments_write` : `admin | coach`.
- **Master data** (rameurs importés, parc) → écriture **directe** Supabase
  au moment de l'import (lot R2 du prompt import rameurs). Pas d'outbox.
- **Séances** → local-first, sync silencieuse plus tard (autre chantier).
- Jamais de `samples.jsonl` / IMU / GPS / télémétrie 1 Hz dans Postgres.
- Jamais de `service_role` côté client. Secrets = dart-define uniquement.

---

## 5. Lots d'implémentation (ordre)

Chaque lot = 1 commit, `flutter analyze` clean, tests verts.
Ne pas toucher AvSim, firmware, #50, secrets, écrans Stitch.

### Lot O1 — Auth Google + fallback magic link (fondation, peu d'UI)
- Dashboard : activer provider Google (§1.1) — **humain**, noté dans la PR.
- `lib/sync/auth_google.dart` : `signInWithGoogle()`, handler deep link
  unifié (réutilise le callback magic link existant).
- `/auth` : bouton « Continuer avec Google » + lien « par email » (magic
  link). Persistance session inchangée.
- Tests : mock provider, session créée, fallback email déclenché.
- Commit : `feat(datar0w): auth Google OAuth + magic link fallback`

### Lot O2 — Routage post-login (deux portes)
- Après login : résoudre `club_members` → si rôle club → `/home/{rôle}`
  (branche B) ; sinon → écran « Ton profil rameur » ou « Sans compte »
  (branche A).
- Route `/club/login` (entrée club, distincte de `/auth`).
- « Sans compte (loisir) » → `/` (flux actuel, rétro-compat).
- Tests : 3 chemins (Google+club, Google+rameur, sans compte).
- Commit : `feat(datarow): onboarding routing — rameur vs club`

### Lot O3 — Parcours rameur + licence FFA optionnelle
- Écran profil rameur 1er login : nom, naissance, sexe, licence FFA?
  (champ libre, non bloquant). Catégorie FFA lecture seule.
- `join_club(code)` ou « je rame seul ».
- « Je barre aussi » : modifier `club_members.role` rower→cox (ou
  double appartenance — à implémenter, défaut rôle unique).
- Commit : `feat(datarow): rower onboarding + optional FFA licence`

### Lot O4 — Parcours club + rôles étendus
- Migration SQL `0004_club_roles.sql` : étendre le check `role` de
  `club_members` pour accepter `treasurer | intendant | director`
  (sans casser `admin|coach|rower|cox`). Politiques : `intendant` =
  `boats_write` comme `coach` ; `treasurer`/`director` = lecture club +
  validation des demandes de rôle (pas d'écran trésorier ici).
- Écran « Rejoindre ou créer un club » + validation admin des rôles.
- Home par rôle (coach / intendant / director) — squelette, pas de
  refonte Stitch.
- Commit : `feat(datarow): club roles extended + join/create flow`

### Lot O5 — Verrou & tests d'isolation
- Tests RLS : un `rower` ne peut pas INSERT `boats` / `rowers` ;
  un `coach` d'un club A ne lit pas le club B.
- Script `supabase/tests/isolation_rls.sql` (aussi sur la branche #50,
  à porter sur main).
- Commit : `test(datarow): RLS isolation — rower cannot write park`

---

## 6. Hors scope (volontaire)

- Écrans trésorier / budget (rôle réservé, UI plus tard).
- Scrap FFA en runtime pour valider la licence (interdit ; saisie manuelle).
- Multi-club par téléphone.
- Paiement / abonnement.
- Refonte `/live` `/tare` `/coach` carte / replay.
- Nouveaux écrans Stitch.
- Sync séances cloud (autre chantier, local-first).

---

## 7. Décisions figées (ne pas rouvrir sans en discuter)

1. **Google = login principal**, magic link = fallback. Pas de service tiers.
2. **Deux portes d'entrée** : rameur (simple) vs club (verrouillé). Pas de
   mélange.
3. **Rameur → barreur** = même branche, rôle additionnel. Pas de 2e entrée.
4. **Rôles club étendus** : `treasurer | intendant | director` en plus de
   `admin | coach | rower | cox`. Verrou RLS strict.
5. **Licence FFA** = donnée métier optionnelle, pas preuve d'identité.
6. **Master data** (rameurs/parc) → Supabase direct ; **séances** →
   local-first.
7. **Un téléphone = un club actif** au MVP.
8. **Pas d'Accueil** sur `/live` `/cox` `/coach` (STOP 2×).
9. Secrets = dart-define uniquement ; Client Secret Google reste dans le
   dashboard Supabase.
10. Ne pas toucher AvSim, firmware, #50, compileSdk 37.

---

## 8. Prompt Cursor

> Coller tel quel. Lot O1 d'abord.

```
DataR0w — onboarding Google + deux parcours (rameur / club).
Lis docs/CADRAGE-ONBOARDING-ROLES.md, docs/ETAT-DATAROW.md, docs/CADRAGE-SUPABASE.md.
Ne pas toucher AvSim, firmware, #50, secrets, écrans Stitch, compileSdk 37.

## Lot O1 — Auth Google + fallback magic link
- Activer provider Google dans le dashboard Supabase (humain, noté en PR).
- lib/sync/auth_google.dart : signInWithGoogle() + deep link unifié.
- /auth : « Continuer avec Google » + « par email » (magic link).
- Tests : session créée, fallback déclenché.
Commit : feat(datar0w): auth Google OAuth + magic link fallback

## Lot O2 — Routage post-login
- Résoudre club_members → /home/{rôle} (club) ou profil rameur / « Sans compte ».
- Route /club/login (entrée club distincte).
- Tests : 3 chemins.
Commit : feat(datarow): onboarding routing — rameur vs club

## Lot O3 — Parcours rameur + licence FFA optionnelle
- Profil 1er login : nom, naissance, sexe, licence FFA? (non bloquant).
- join_club(code) ou « je rame seul ». « Je barre aussi » → rôle cox.
Commit : feat(datarow): rower onboarding + optional FFA licence

## Lot O4 — Parcours club + rôles étendus
- Migration 0004_club_roles.sql : treasurer|intendant|director + politiques.
- « Rejoindre ou créer un club » + validation admin.
- Home squelette par rôle.
Commit : feat(datarow): club roles extended + join/create flow

## Lot O5 — Verrou RLS
- Tests : rower ne write pas boats/rowers ; isolation inter-clubs.
- Porter supabase/tests/isolation_rls.sql sur main.
Commit : test(datarow): RLS isolation — rower cannot write park

flutter analyze clean. Tests verts. 1 commit par lot, ordre O1→O5.
```

*Fin du cadrage — 21 septembre 2026.*
