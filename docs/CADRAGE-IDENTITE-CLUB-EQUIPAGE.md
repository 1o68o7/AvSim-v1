# Cadrage exploratoire — Identité rameur, club, parc à bateaux, composition d'équipage

> Statut : **exploratoire, en cours de construction**. Pas de mockups : chaque lot doit livrer du code réel (modèles, persistance, UI, tests) qui compile et s'installe sur le OnePlus.
> App : `apps/datar0w`. Ne pas toucher le solver AvSim. Ne pas revert `compileSdk = 37` / `ndkVersion = "30.0.16248370"`. Pas de `sdkmanager`. Pas de `windows/`.
> Ce document est **vivant** : on l'augmente au fur et à mesure des décisions. Chaque lot ci-dessous devient un commit distinct.
>
> **I1–I5 : mergés sur `main`.** Point B (Supabase) : lots B1–B4. Local JSON reste la vérité UI.

---

## 0. Pourquoi ce chantier

Aujourd'hui DataR0w démarre **sans identité** : pas de login, pas de rameur nommé, pas de club, pas de parc à bateaux. Le téléphone est un hub anonyme qui logge une séance.

Or en pratique :

- Un rameur a un **profil propre** (poids, taille, catégorie d'âge FFA, côté privilégié, pelles).
- Un même rameur fait de la **couple ET de la pointe**, à **bâbord ET à tribord** selon le bateau — ce n'est pas un attribut fixe, c'est un **rôle par affectation**.
- Un **club** possède un parc à bateaux (coques + pelles) et des licenciés.
- Un **coach** compose des équipages : il choisit deux profils compatibles (ex. compétiteur bâbord + compétiteur tribord) et leur attribue un bateau + des pelles (P4, P1/P2/P4…).

Donc l'identité n'est pas une ligne : c'est un **graphe** Rower ↔ Club ↔ Boat ↔ Assignment. Ce document le modélise et découpe l'implémentation.

---

## 0.1 Navigation séance (déjà sur `main`, ne pas casser)

```
/ profil (rôles de séance, pas encore profils licenciés)
 ├ rameur  → 2A → tare → /live → quai → replay 6r
 ├ barreur → 2A → tare → /cox  → quai → replay 6r (+ replay coach si code)
 └ coach   → join → /coach → replay-coach
```

- 2A / 2B : « Retour profil » (sauf tare en cours).
- **Pendant `/live`, `/cox`, `/coach` : pas de bouton Accueil / leading profil.**
  Sortie de séance = **STOP 2× → `/quai`** uniquement. On ne quitte pas un enregistrement par accident.
- I2 s'insère **avant** cet écran profil-rôles : « Qui rame ? » → puis les 3 cartes actuelles.

---

## 1. Entités (modèle de données)

Trois entités racines, plus des affectations. Tout persiste en local (JSON dans `Documents/datar0w/`) dès le lot 1 ; sync club/API = lot ultérieur.

### 1.1 `Rower` (le rameur)

| Champ | Type | Notes |
|---|---|---|
| `id` | UUID | stable |
| `displayName` | string | prénom + nom (pas de données sensibles au-delà) |
| `birthDate` | date ISO | **source de vérité** pour la catégorie d'âge |
| `sex` | `M` \| `F` \| `X` | pour poids léger / cases FFA |
| `weightKg` | float? | saisi, jamais inventé |
| `heightCm` | float? | saisi ; IMC = calculé plus tard, **pas** un champ stocké |
| `sidePref` | `babord` \| `tribord` \| `none` | préférence, **pas** une contrainte dure |
| `oarSpec` | string? | ex. `"P1/P2/P4"`, libre pour l'instant |
| `level` | `loisir` \| `competiteur` \| `inconnu` | tag coach |
| `clubId` | UUID? | rattachement (1 club pour le MVP) |
| `createdAt` / `updatedAt` | datetime | |

**Catégorie d'âge** : fonction pure `ageCategory(birthDate, seasonStart)` — **jamais** saisie à la main. Grille FFA (saison type, à figer dans `lib/identity/ffa_categories.dart`) :

| Code | Libellé | Années de naissance (saison 2025-26, à ajuster chaque 1er sept.) |
|---|---|---|
| BB | Baby athlé | 2021+ |
| EA | École athlétisme | 2018–2020 |
| PO | Poussin(e) | 2016–2017 |
| BE | Benjamin(e) | 2014–2015 |
| MI | Minime | 2012–2013 |
| CA | Cadet(te) | 2010–2011 |
| JU | Junior | 2008–2009 |
| ES | Espoir | 2005–2007 |
| SE | Senior | 1993–2004 |
| MA | Masters | 1992 et avant (sous-classes M0…M10) |

Règle : la catégorie se **recalcule** à chaque ouverture de profil et à chaque saison. On stocke `birthDate`, pas `"master"` en dur.

**Poids léger** : constante FFA — 72,5 kg (H), 59 kg (F) pour la ligne ; moyenne d'équipage plus tard. Juste un booléen dérivé `isLightweight` pour l'affichage coach, pas de contrôle bloquant au MVP.

### 1.2 `Club`

| Champ | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `name` | string | ex. "Cercle Nautique de …" |
| `shortCode` | string? | 3–4 car. pour codes séance |
| `createdAt` | datetime | |

Un téléphone = **un club actif** au MVP (pas de multi-club). Le club peut être créé à la première utilisation ("Créer mon club") ou rejoint via un code (plus tard, API).

### 1.3 `Boat` (parc à bateaux du club)

| Champ | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `clubId` | UUID | |
| `name` | string | nom affiché ("Empacher", "Stélie…") |
| `class` | `1x`\|…\|`8+` | réutilise `boat_class.dart` existant |
| `seats` | int | 1…8 |
| `cox` | bool | barreur ? |
| `oarRack` | list<string> | inventaire pelles du bateau, ex. `["P1","P2","P4"]` |
| `status` | `ready` \| `maintenance` \| `out` | simple |

### 1.4 `Assignment` (équipage composé)

C'est là que le côté et les pelles deviennent **par affectation**, pas par rameur :

| Champ | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `boatId` | UUID | |
| `seatIndex` | int (1 = stroke) | null si barreur |
| `rowerId` | UUID | |
| `side` | `babord` \| `tribord` | **décidé à la composition**, pas lu depuis `sidePref` |
| `oars` | list<string> | pelles attribuées à ce poste |
| `role` | `rower` \| `cox` | |
| `coxPosition` | `rear` \| `front` | si barreur |

Un `Assignment` est **jetable** : on recrée l'équipage à chaque séance. On ne fige pas "rameur X = toujours bâbord".

### 1.5 Lien avec la séance existante

`meta.json` de séance gagne des références optionnelles :

```json
{
  "rowerId": "…",
  "clubId": "…",
  "boatId": "…",
  "assignmentId": "…",
  "seatIndex": 3,
  "side": "babord"
}
```

Rien de cassé si absent : la séance anonyme reste possible (mode loisir, pas de club). **Rétro-compatible**.

---

## 2. Parcours utilisateur

### 2.1 Rameur (côté téléphone)

1. Premier lancement → écran **"Qui rame ?"** : créer un profil (nom, date de naissance, sexe) ou choisir un profil existant sur ce téléphone.
2. Profil éditable : poids, taille, côté préféré, pelles, niveau. Catégorie d'âge **affichée en lecture seule**, calculée.
3. Rattachement club : créer / choisir le club du téléphone.
4. Ensuite = flux actuel (2A classe → 2B tare → live). Le profil nourrit `meta.json`.

### 2.2 Coach (côté même téléphone, rôle `coach`)

1. Voit la liste des rameurs du club (locaux pour le MVP).
2. **Composer un bateau** : choisir une coque du parc → placer des rameurs sur les sièges → choisir le côté de chaque poste → attribuer les pelles → (optionnel) barreur + position.
3. L'affectation est **stockée** et réutilisable comme modèle, mais chaque séance recrée une instance.
4. Pendant la séance : le téléphone du coach affiche l'équipage + le live du hub qui logge (comme aujourd'hui, écran 5). Pas de télémétrie par siège tant qu'il n'y a qu'un téléphone.

---

## 3. Auth (décision MVP)

**Pas de login fédéré.** Trop lourd, hors scope téléphone-seule.

- Sur un téléphone : profils **locaux**, sélectionnés par nom (pas de mot de passe). Suffisant pour un rameur qui utilise son propre tél.
- PIN optionnel plus tard si le téléphone est partagé entre rameurs du même club.
- Sync multi-téléphones / véritable authentification = **lot API** (après G), pas maintenant.
- Une séance **sans profil** reste possible (bouton "Passer") — rétro-compat, mode loisir.

---

## 4. Lots d'implémentation (code réel, pas de mockup)

Chaque lot = 1 commit, `flutter analyze` clean, tests unitaires sur la logique pure, APK qui s'installe.

**État au 18 sept. 2026 : I1–I6 = à coder. Aucun fichier `lib/identity/` sur `main`.**

### Lot I1 — Modèle + persistance (fondations) — PROCHAIN
- `lib/identity/models.dart` : `Rower`, `Club`, `Boat`, `Assignment` (+ sérialisation JSON).
- `lib/identity/ffa_categories.dart` : fonction pure `ageCategory(birthDate)` + tests sur la grille.
- `lib/identity/store.dart` : CRUD local (réutilise le pattern `session/store.dart`).
- `lib/identity/is_lightweight.dart` : booléen dérivé H/F.
- Tests : catégorie pour 6 dates de naissance, léger/lourd, sérialisation round-trip.
- **Aucun écran** dans ce lot — juste le moteur. Commit : `feat(datar0w): identity model + FFA categories`.

### Lot I2 — Écran profil rameur (UI réelle)
- Nouveau flow au premier lancement : "Qui rame ?" → créer / choisir.
- Formulaire : nom, date de naissance (date picker), sexe, poids, taille, côté préféré, pelles, niveau. Catégorie affichée en live (lecture seule).
- Persistance immédiate. Liste des profils locaux + suppression.
- Bouton "Passer (sans profil)" → flux actuel inchangé (3 cartes rôle).
- Commit : `feat(datar0w): rower profile screen + local store`.

### Lot I3 — Club + parc à bateaux
- Création du club du téléphone (nom, code court).
- CRUD bateaux : classe (réutilise `boat_class.dart`), nom, cox, inventaire pelles, statut.
- Écran "Mon club" accessible depuis le profil.
- Commit : `feat(datar0w): club + boat park CRUD`.

### Lot I4 — Composition d'équipage (côté coach)
- Écran coach : choisir un bateau du parc → grille des sièges → affecter un rameur + côté + pelles par poste ; barreur + position si `cox`.
- Validation : pas deux rameurs sur le même siège ; côtés cohérents avec la classe (pair = alternance, etc. — *souple*, on n'impose pas encore).
- Sauvegarde du modèle d'affectation (réutilisable) + instance de séance.
- Le téléphone qui logge la séance hérite de son `assignmentId` → `meta.json` enrichi.
- Commit : `feat(datar0w): crew composition screen`.

### Lot I5 — Branchement séance + affichage
- `meta.json` : références optionnelles rower/club/boat/assignment (rétro-compat).
- Écran 5 (coach) : affiche l'équipage composé + live du hub.
- Écran quai 7 : chip "siège n / côté / pelles" si affectation présente.
- Commit : `feat(datar0w): session meta + crew display`.

### Lot I6 — (plus tard) Sync API / hôte (Supabase envisagé)
- Endpoints `/datarow/club/*`, `/datarow/rowers/*`, `/datarow/assignments/*` — **après** stabilisation locale. Hors de ce cadrage pour l'instant.

---

## 5. Hors scope (volontairement)

- Login fédéré / licence FFA en ligne.
- Multi-club par téléphone.
- Télémétrie par siège (plusieurs téléphones) — ça, c'est Lot G étendu.
- Algorithme automatique d'appariement "meilleur pair" — produit, pas fondation.
- IMC stocké / courbes de forme — calculé à la volée plus tard, jamais persisté comme métrique médicale.
- Modification du solver AvSim, watts, RTK, 10 Hz, micro, caméra, podomètre.
- Ajouter un bouton Accueil sur `/live`, `/cox` ou `/coach` (sortie = STOP 2× seulement).

---

## 6. Décisions figées (ne pas rouvrir sans en discuter)

1. **Catégorie d'âge = fonction de `birthDate`**, jamais un champ saisi.
2. **Côté et pelles = attributs de l'`Assignment`**, pas du `Rower`. Un rameur change de côté d'un bateau à l'autre.
3. **Auth locale d'abord** (nom + PIN optionnel), sync API ensuite.
4. **Séance sans profil possible** (rétro-compat, mode loisir).
5. **Un téléphone = un club actif** au MVP.
6. **Pas de mockups** : chaque lot livre du Dart qui compile et s'installe.
7. **Pas d'Accueil pendant l'enregistrement** (`/live`, `/cox`, `/coach`). Sortie = STOP 2× → quai.

---

## 7. Prochaine action

Exécuter **Lot I1** (modèle + FFA + tests, sans écran). Ensuite I2. On augmente ce document au fur et à mesure : toute décision nouvelle s'ajoute en §6 ou modifie un lot.

*Document vivant — créé pour cadrer l'identité DataR0w. À enrichir, pas à figer.*

---

## 8. Prompt Cursor — Lots I1 → I5 (à coller tel quel)

> Ce bloc est le prompt exact à passer à Cursor. Il fige les règles métier (parc éditable = coach seulement, loisir sans accès catalogue) et l'ordre des commits. Ne pas rouvrir sans en discuter.

```
DataR0w — lots I1 → I5 identité + restriction parc.
Lis d'abord docs/CADRAGE-IDENTITE-CLUB-EQUIPAGE.md et apps/datar0w/README.md.

Ne pas toucher AvSim. Ne pas revert compileSdk 37 / ndkVersion "30.0.16248370".
Pas de sdkmanager. Pas de windows/. Pas d'Accueil sur /live /cox /coach (sortie = STOP 2×).
Ne pas porter le jargon Stitch (SYS_ID, STAGE PROTOCOL, SENSOR SYNC, entraxe, calage, calibration factory).

DA : #0B0E12 / blanc / #9AA0A6 / #2A2F36 / CTA #E8C547 / TRIBORD #46C275 / BÂBORD #E05353.

## Règles métier (figées)
- Côté et pelles = Assignment, pas Rower.sidePref.
- Catégorie FFA = ageCategory(birthDate), jamais saisie.
- Séance sans profil possible (« Passer »).
- Un tél. = un club actif.
- PARC ÉDITABLE = COACH SEULEMENT. Loisir / rameur / barreur : voient UNIQUEMENT
  l'affectation coach (écrans 6/7) ou l'état vide (écran 9). Pas de picker catalogue.
- Continuer sans Assignment → flux actuel 2A (classe + siège hub), PAS choix d'une coque du parc.
- Coque OUT / MAINTENANCE : non assignable à I4.
- Rameur déjà affecté « aujourd'hui » : grisé à la composition.

## I1 — modèle + tests, AUCUN écran
lib/identity/models.dart : Rower, Club, Boat, Assignment
lib/identity/ffa_categories.dart + is_lightweight.dart + store.dart (JSON Documents/datar0w/)
Tests : 6 dates → codes FFA, léger H/F, JSON round-trip.
Commit : feat(datar0w): identity model + FFA categories

## I2 — Qui rame + fiche + accueil rameur (écrans 1, 2, 6, 9)
Routes avant le / profil-rôles actuel :
  /identity          liste profils + CTA créer + « Passer (sans profil) » → /
  /identity/edit     fiche (nom, naissance, sexe, poids, taille, sidePref, oars, level)
                     cat. FFA lecture seule
  /home/rower        si Assignment → coque/siège/côté/pelles + CONTINUER → /presession
                     sinon état vide écran 9 + CONTINUER → /presession
                     PAS de liste parc. Lien club = lecture seule ou absent si loisir.
Le / actuel (3 cartes Rameur/Coach/Barreur) RESTE après Passer ou après choix profil.
Commit : feat(datar0w): rower profile screen + local store

## I3 — club + parc
  /club              coach : CRUD + Ajouter. Autre rôle : lecture, pas de + Ajouter.
  /club/boat         coach : nom, classe (boat_class.dart), cox, pelles, statut.
                     PAS entraxe / calage / notes usine.
Commit : feat(datar0w): club + boat park CRUD

## I4 — composition (écran 5 paysage, COACH ONLY)
  /crew              si rôle ≠ coach → redirect /home/rower ou /
  Coques READY only. Sièges + rameur + side + oars. 4+/8+ barreur avant/arrière.
  1 tél. = 1 place. Sauvegarde Assignment.
Commit : feat(datar0w): crew composition screen

## I5 — branchement séance
meta.json optionnel : rowerId clubId boatId assignmentId seatIndex side (rétro-compat si absent).
Quai : chip « siège n / côté / pelles » si Assignment.
Écran 5 coach live existant : ligne équipage si Assignment, sans casser la carte OSM.
Accueil barreur /home/cox : bateau + position + liste sièges LECTURE + CONTINUER → /presession
  (2A forcera 4+/8+ + rôle cox comme aujourd'hui).
Accueil coach /home/coach : Composer → /crew ; Rejoindre → /coach-join ; parc → /club.
Commit : feat(datar0w): session meta + crew display

## Hors scope
Login FFA, multi-club, télémétrie par siège, IMC stocké, micro/caméra, watts, RTK.
Ne pas redessiner /live /cox /tare /coach carte /replay.

flutter analyze clean. Tests identité verts.
Un commit par lot I1…I5, dans cet ordre.
```

---

## 9. Point B — Sync Supabase (cadrage + prompt Cursor)

> **Prérequis** : I1–I5 mergés sur `main` (identité locale stable). Ce point B ne remplace pas le local : il **ajoute** une couche cloud. Le téléphone reste utilisable hors-ligne.
>
> **Hôte** : Supabase (Postgres + Auth + Realtime). Pas de serveur maison. Le projet Supabase est créé **par toi** dans le dashboard ; Cursor ne crée pas le projet cloud, il écrit le SQL + le client Dart.
>
> **Secrets** : `SUPABASE_URL` + `SUPABASE_ANON_KEY` dans `--dart-define` / CI secrets. **Jamais** dans le repo. Pas de `service_role` côté client.

### 9.1 Décisions figées (point B)

1. **Offline-first** : le local (JSON `Documents/datar0w/`) reste la source de vérité UI. Supabase = miroir + sync. Écriture locale **immédiate**, push en file d'attente, pull au reconnect.
2. **Auth** : Supabase Auth, **email + magic link** (passwordless). Un user = un `auth.users.id`. Le `Rower` local gagne un `userId` nullable (rattachement au login). Pas de Google/OAuth au MVP B.
3. **Multi-tenant = club** : `clubs.id` = tenant. RLS : un membre ne voit/écrit **que** les lignes de ses clubs. Rôles club : `coach` | `rower` | `cox` | `admin` (admin = coach + gestion membres).
4. **RLS strict** : activé sur **toutes** les tables. Politiques `USING` + `WITH CHECK`. Fonctions `security definer` pour `is_club_member(club_id)` / `club_role(club_id)` avec `search_path = ''`.
5. **Realtime** : Postgres Changes sur `assignments`, `boats`, `rowers` (filtrés par `club_id`) pour que 2 coachs / 2 tél voient la même composition. Pas de polling.
6. **Conflits** : last-write-wins sur `updated_at`. Pas de merge manuel au MVP.
7. **Pas de télémétrie live dans Supabase** : les samples `samples.jsonl` restent **locaux** (1 Hz, fichiers lourds). Seuls les **métadonnées de séance** (début/fin, rowerId, boatId, assignmentId, distance, gîte max) montent au cloud. La télémétrie par siège (Lot G) viendra plus tard.
8. **Deep links** : scheme `datarow://auth/callback` (AndroidManifest + iOS Info.plist). Magic link → retour app.
9. **Ne pas casser** I1–I5 : le store local reste ; on ajoute `lib/sync/` par-dessus. Mode « sans compte » (Passer) continue de marcher.
10. **Pas de PowerSync / Brick** au MVP B : sync maison légère (outbox + delta `updated_at`). On pourra migrer si ça coince.

### 9.2 Schéma Postgres (à pousser via `supabase/migrations/`)

```sql
-- 0001_identity_core.sql
create extension if not exists pgcrypto;

create table public.clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  short_code text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.club_members (
  club_id uuid not null references public.clubs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('admin','coach','rower','cox')),
  rower_id uuid, -- lien optionnel vers public.rowers
  joined_at timestamptz not null default now(),
  primary key (club_id, user_id)
);
create index club_members_user_id_idx on public.club_members(user_id);

create table public.rowers (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  display_name text not null,
  birth_date date not null,
  sex text not null check (sex in ('M','F','X')),
  weight_kg float,
  height_cm float,
  side_pref text not null default 'none' check (side_pref in ('babord','tribord','none')),
  oar_spec text,
  level text not null default 'inconnu' check (level in ('loisir','competiteur','inconnu')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index rowers_club_id_idx on public.rowers(club_id);

create table public.boats (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  name text not null,
  class text not null,          -- 1x..8+
  seats int not null,
  cox boolean not null default false,
  oar_rack text[] not null default '{}',
  status text not null default 'ready' check (status in ('ready','maintenance','out')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index boats_club_id_idx on public.boats(club_id);

create table public.assignments (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  boat_id uuid not null references public.boats(id) on delete cascade,
  rower_id uuid not null references public.rowers(id) on delete cascade,
  seat_index int,              -- null si barreur
  side text check (side in ('babord','tribord')),
  oars text[] not null default '{}',
  role text not null default 'rower' check (role in ('rower','cox')),
  cox_position text check (cox_position in ('rear','front')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index assignments_club_id_idx on public.assignments(club_id);

-- helpers RLS
create or replace function public.is_club_member(p_club_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.club_members cm
    where cm.club_id = p_club_id and cm.user_id = auth.uid()
  );
$$;
revoke all on function public.is_club_member(uuid) from public;
grant execute on function public.is_club_member(uuid) to authenticated;

create or replace function public.club_role(p_club_id uuid)
returns text language sql stable security definer set search_path = '' as $$
  select role from public.club_members
  where club_id = p_club_id and user_id = auth.uid() limit 1;
$$;
revoke all on function public.club_role(uuid) from public;
grant execute on function public.club_role(uuid) to authenticated;

-- RLS
alter table public.clubs enable row level security;
alter table public.club_members enable row level security;
alter table public.rowers enable row level security;
alter table public.boats enable row level security;
alter table public.assignments enable row level security;

-- clubs : membre lit ; admin crée/modifie
create policy clubs_select on public.clubs for select to authenticated
  using (public.is_club_member(id));
create policy clubs_write on public.clubs for all to authenticated
  using (public.club_role(id) = 'admin')
  with check (public.club_role(id) = 'admin');

-- club_members : voit ses lignes ; admin gère
create policy cm_select on public.club_members for select to authenticated
  using (public.is_club_member(club_id));
create policy cm_write on public.club_members for all to authenticated
  using (public.club_role(club_id) = 'admin')
  with check (public.club_role(club_id) = 'admin');

-- rowers / boats / assignments : membre lit ; coach+ admin écrivent
create policy rowers_select on public.rowers for select to authenticated
  using (public.is_club_member(club_id));
create policy rowers_write on public.rowers for all to authenticated
  using (public.club_role(club_id) in ('admin','coach'))
  with check (public.club_role(club_id) in ('admin','coach'));

create policy boats_select on public.boats for select to authenticated
  using (public.is_club_member(club_id));
create policy boats_write on public.boats for all to authenticated
  using (public.club_role(club_id) in ('admin','coach'))
  with check (public.club_role(club_id) in ('admin','coach'));

create policy assignments_select on public.assignments for select to authenticated
  using (public.is_club_member(club_id));
create policy assignments_write on public.assignments for all to authenticated
  using (public.club_role(club_id) in ('admin','coach'))
  with check (public.club_role(club_id) in ('admin','coach'));
```

### 9.3 Client Dart (offline-first)

- `pubspec.yaml` : `supabase_flutter: ^2.17.2` (stable). Pas de `service_role`.
- `lib/sync/supabase_client.dart` : init depuis `--dart-define`.
- `lib/sync/outbox.dart` : file locale (SQLite ou JSON) des mutations en attente.
- `lib/sync/sync_engine.dart` : `push()` (outbox → Supabase), `pull()` (delta `updated_at > last_sync`), `onConnectivityChanged`.
- `lib/identity/store.dart` : **inchangé** pour l'UI ; on ajoute `store.syncToCloud()` qui pousse le diff.
- Realtime : `supabase.from('assignments').stream(primaryKey: ['id']).eq('club_id', clubId)` → provider Riverpod.
- Auth UI : écran « Se connecter » (email + magic link) **optionnel** — accessible depuis « Qui rame ? » / profil. Sans login, le mode local continue.
- Deep link `datarow://auth/callback` dans `AndroidManifest.xml` + `Info.plist`.

### 9.4 Lots B (code réel, pas de mockup)

Chaque lot = 1 commit, `flutter analyze` clean, tests sur la logique pure (RLS testable via SQL, sync via mock).

**B1 — Schéma + RLS (SQL only, pas d'UI)**
- Dossier `supabase/migrations/0001_identity_core.sql` (ci-dessus).
- README : comment créer le projet Supabase, coller la migration, activer Realtime sur `assignments/boats/rowers`.
- Test SQL (optionnel) : 2 clubs, 2 users → isolation prouvée.
- Commit : `feat(datar0w): supabase schema + RLS identity core`.

**B2 — Auth magic link + rattachement Rower**
- `lib/sync/auth_screen.dart` : email → magic link → deep link → session.
- `Rower.userId` nullable ; au login, proposer « rattacher ce profil local à mon compte ».
- `club_members` : à la création de club, le créateur devient `admin`.
- Commit : `feat(datar0w): supabase auth magic link + rower link`.

**B3 — Sync offline-first (outbox + delta)**
- `lib/sync/outbox.dart` + `sync_engine.dart`.
- `store.dart` : après chaque CRUD local → enqueue outbox.
- `pull()` : `updated_at > last_sync_at` par table, merge LWW.
- Connectivity : `connectivity_plus` (déjà dispo via FGS) déclenche sync.
- Commit : `feat(datar0w): offline-first sync outbox + delta pull`.

**B4 — Realtime composition + écran coach**
- Provider `assignmentsStream(clubId)` → écran 5 coach se met à jour tout seul.
- Chip « sync » sur écran 8 (accueil coach) : dernière sync / hors-ligne.
- Commit : `feat(datar0w): realtime assignments + coach sync chip`.

### 9.5 Hors scope (point B)

- Télémétrie `samples.jsonl` dans le cloud (trop lourd, 1 Hz).
- PowerSync / Brick / ElectricSQL (trop tôt).
- OAuth Google / Apple.
- Multi-club par user (un user = un club au MVP B ; multi plus tard).
- Résolution de conflits manuelle (UI diff).
- Edge Functions métier (on reste sur RLS + client).
- Migration du store local existant vers SQLite (on garde JSON + outbox JSON).

### 9.6 Recette test (2 téléphones, 1 club)

1. Projet Supabase créé, migration B1 appliquée, Realtime ON.
2. Tél A : créer club « CNB », devenir admin, ajouter 2 rameurs, 1 bateau 2x READY.
3. Tél B : se connecter (magic link) → rejoindre le club (code ou invitation) en `rower`.
4. Tél A : composer équipage 2x → Tél B voit l'affectation **en temps réel** (Realtime).
5. Couper le réseau sur Tél A : composer un 2ᵉ équipage → remettre le réseau → Tél B le reçoit (outbox + pull).
6. Tél B (loisir) : ouvrir « Qui rame ? » → voit **uniquement** son affectation, pas le catalogue parc.
7. `flutter analyze` clean, APK debug sur les 2 tél.

---

## 10. Prompt Cursor — Point B (Lots B1 → B4)

> À coller **après** I1–I5 mergés. Ne pas rouvrir les décisions §9.1 sans en discuter.

```
DataR0w — point B : sync Supabase offline-first (lots B1→B4).
Lis d'abord docs/CADRAGE-IDENTITE-CLUB-EQUIPAGE.md §9 et apps/datar0w/README.md.

Ne pas toucher AvSim. Ne pas revert compileSdk 37 / ndkVersion "30.0.16248370".
Pas de sdkmanager. Pas de windows/. Pas d'Accueil sur /live /cox /coach.
Secrets : SUPABASE_URL + SUPABASE_ANON_KEY via --dart-define / CI. JAMAIS service_role côté client.
Ne pas porter le jargon Stitch. Ne pas casser I1–I5 (store local reste, on ajoute lib/sync/).

## Règles (figées §9.1)
- Offline-first : local = vérité UI, Supabase = miroir + sync.
- Auth = email + magic link. Rower.userId nullable.
- Tenant = club. RLS sur toutes les tables. Helpers is_club_member / club_role (security definer, search_path '').
- Realtime Postgres Changes sur assignments/boats/rowers (filtrés club_id).
- Pas de samples.jsonl dans le cloud (métadonnées séance seulement).
- Conflits = LWW updated_at. Pas de merge manuel.
- Mode « Passer » (sans compte) continue de marcher.

## B1 — Schéma + RLS (SQL only)
Créer supabase/migrations/0001_identity_core.sql (voir §9.2).
README : créer projet Supabase, coller migration, activer Realtime.
Test SQL isolation 2 clubs / 2 users (optionnel).
Commit : feat(datar0w): supabase schema + RLS identity core

## B2 — Auth magic link + rattachement Rower
lib/sync/auth_screen.dart : email → magic link → deep link datarow://auth/callback.
Rower.userId nullable ; proposer rattachement au login.
Création club → créateur = admin (club_members).
Deep links AndroidManifest + Info.plist.
Commit : feat(datar0w): supabase auth magic link + rower link

## B3 — Sync offline-first (outbox + delta)
lib/sync/outbox.dart + sync_engine.dart.
store.dart : après CRUD local → enqueue outbox.
pull() : updated_at > last_sync_at, merge LWW.
connectivity_plus déclenche sync.
Commit : feat(datar0w): offline-first sync outbox + delta pull

## B4 — Realtime composition + chip coach
Provider assignmentsStream(clubId) → écran 5 se met à jour.
Chip « sync » sur /home/coach (dernière sync / hors-ligne).
Commit : feat(datar0w): realtime assignments + coach sync chip

## Hors scope
Télémétrie samples dans le cloud, PowerSync/Brick, OAuth Google/Apple,
multi-club, conflits manuels, Edge Functions métier.
Ne pas redessiner /live /cox /tare /coach carte /replay /identity.

flutter analyze clean.
Un commit par lot B1…B4, dans cet ordre.
Recette §9.6 sur 2 tél.
```

*Document vivant — point B ajouté pour cadrer la sync Supabase. À enrichir au fil des retours.*
