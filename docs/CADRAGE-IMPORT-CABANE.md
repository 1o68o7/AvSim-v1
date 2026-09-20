# Cadrage — Point D : import cabane (CSV/XLSX), enrichissement club, spinoscope

> Statut : **à construire**. Pas de débat — on code dans l'ordre ci-dessous.
> App : `apps/datar0w`. Ne pas toucher AvSim. Ne pas revert `compileSdk = 37` / `ndkVersion "30.0.16248370"`. Pas de `sdkmanager`. Pas de `windows/`.
> Prérequis : I1–I5 mergés (identité locale), Point C (parc opérationnel) prévu en parallèle ou avant D3.
> Chaque lot = 1 commit, `flutter analyze` clean, tests, APK qui s'installe.
> Public cible : **coachs peu techniques**. Un fichier Excel/CSV posé sur le téléphone doit suffire — pas de ligne de commande, pas de script, pas de connaissance web.

---

## 0. Pourquoi ce chantier

Aujourd'hui le parc se saisit **à la main, coque par coque** (écran `/club/boat`). Ça va pour 2–3 bateaux. Un club réel a 15–40 coques, des dizaines de pelles, un historique, des marques, des types (pointes / coupleuses), et des rameurs loisirs qui veulent un **blason** à défendre.

Le coach ne va pas taper 40 fiches à la cabane. Il a déjà un tableur (Excel, Google Sheets exporté, ou un vieux fichier du club). Il veut **poser le fichier → importer → vérifier → c'est dans l'app**.

Le trou réel :

- Pas d'**import CSV / XLSX** : `file_picker` est dans le `pubspec`, mais aucun parser, aucun écran, aucune route, aucun mapping.
- Pas de **modèle de fichier** documenté (en-têtes, exemples, tolérance aux fautes).
- Pas de **marque / modèle / type** (pointe, coupleuse, skiff) sur `Boat`.
- Pas de **blason / identité visuelle** du club (logo, couleurs) pour les loisirs.
- Pas de **spinoscope** : vue compétition / loisirs / coupettes, lisible par coachs ET rameurs.
- Pas de **téléchargement d'un modèle** depuis l'app (le coach doit savoir quoi remplir).

Sans ça, le parc reste un inventaire de démonstration, pas un outil de club.

---

## 1. Ce qui existe déjà (I1–I5, sur `main`)

| Élément | État |
|---|---|
| `Club` : nom + code court | ✅ I3 |
| `Boat` : nom, classe 1x–8+, cox, `oarRack`, statut ready/maint/out | ✅ I3 |
| `ParkBoat` : nom, classe, sièges, cox, oarRack, statut | ✅ I3 |
| Écran `/club` : CRUD coach, lecture rameur | ✅ I3 |
| Écran `/club/boat` : édition coach (nom, classe, cox, pelles, statut) | ✅ I3 |
| Restriction loisir : pas de catalogue | ✅ I5 |
| **Import CSV / XLSX** | ❌ |
| **Modèle de fichier + exemples** | ❌ |
| **Marque / modèle / type (pointe/coupleuse)** | ❌ |
| **Blason / couleurs club** | ❌ |
| **Spinoscope compétition/loisirs/coupettes** | ❌ |
| **Téléchargement modèle depuis l'app** | ❌ |

`file_picker` est déclaré dans `pubspec.yaml` mais **non utilisé**. Aucun import de code ne le référence.

---

## 2. Fonctionnalités (ordre de build)

### 2.1 Import cabane (cœur)

1. **Télécharger un modèle** — depuis `/club` (coach) : bouton « Télécharger le modèle CSV ». Génère un fichier `datarow_parc_modele.csv` avec en-têtes + 2 lignes d'exemple, partageable (share sheet). Le coach l'ouvre dans Excel / Numbers / Google Sheets, le remplit, le renvoie.
2. **Choisir un fichier** — bouton « Importer un fichier » → `file_picker` (CSV, XLSX, XLS). Sur Android : accès au stockage / Drive / Downloads. Pas de drag & drop (mobile).
3. **Parser** — CSV (séparateur `;` ou `,`, encodage UTF-8, tolérant aux guillemets) + XLSX (via `excel` ou parsing minimal). XLS (ancien) : optionnel, message « exportez en XLSX » si non supporté au MVP.
4. **Prévisualisation** — tableau des lignes parsées : colonnes reconnues en vert, colonnes inconnues en ambre, lignes en erreur en rouge avec motif. Le coach **valide avant écriture** — rien n'est écrit tant qu'il n'a pas confirmé.
5. **Mapping intelligent** — reconnaissance des en-têtes (insensible à la casse, accents, synonymes : `Nom`/`name`/`Coque`, `Classe`/`class`/`Type`, `Pelles`/`oars`/`Rack`). Si une colonne obligatoire manque → message clair « colonne Nom manquante », pas de plantage.
6. **Création / mise à jour** — lignes valides → `Boat` créés ou mis à jour (clé = nom + classe, ou id si présent). Doublon exact → mise à jour silencieuse avec trace « 3 coques mises à jour ». Nouveau → création.
7. **Rapport d'import** — écran récap : N créées, M mises à jour, K ignorées (erreur), avec détail téléchargeable. Le coach sait ce qui s'est passé.
8. **Annulation** — un import peut être annulé (supprime les coques créées par cet import, garde les mises à jour). Simple flag `importId` sur `Boat`.

### 2.2 Enrichissement du modèle bateau

9. **Type de coque** — `boatType: pointe | coupleuse | skiff | inconnu`. Décrit la forme, pas la classe (1x–8+ reste la classe FFA).
10. **Marque / modèle** — `brand` (ex. Empacher, Filippi, Hudson, WinTech), `model` (ex. E8, F1, Carbone 2021). Texte libre + suggestions.
11. **Année / matériau** — `year`, `material: carbone | composite | bois`. Utile pour la maintenance et le spinoscope.
12. **Numéro de série / immat club** — optionnel, pour la traçabilité.
13. **Notes libres** — champ texte (historique, particularités). Déjà esquissé en I3, à garder simple.

### 2.3 Identité club (blason, couleurs)

14. **Blason / logo** — upload d'une image (PNG/JPG) depuis la galerie ou la caméra. Affiché sur l'accueil coach/rameur et le spinoscope. Stockage local d'abord.
15. **Couleurs club** — 2 couleurs (primaire + secondaire), choisies via sélecteur. Appliquées aux chips / bandeaux du club (pas au deck global, qui reste #0B0E12).
16. **Nom complet + slogan** — `Club.fullName`, `Club.slogan` (ex. « Toujours plus loin »). Affichés sur l'accueil et le spinoscope.
17. **Année de fondation** — optionnel, pour l'historique.

### 2.4 Spinoscope (compétition / loisirs / coupettes)

18. **Vue d'ensemble club** — écran `/spinoscope` : blason, couleurs, nom, effectif (licenciés / loisirs / compétiteurs), parc (nombre de coques par type/classe), sorties du jour.
19. **Répartition compétition / loisirs** — camembert ou barres simples : X licenciés compétiteurs, Y loisirs. Pas de stats avancées.
20. **Coupettes / trophées** — liste simple de « coupettes » (nom, date, résultat) saisissable par le coach. Affichée sur le spinoscope. Pas de classement FFA en ligne.
21. **Visibilité** — coach : édition. Rameur : lecture. Loisir : voit son blason + les coupettes du club.
22. **Pas de réseau social** — pas de fil d'actualité, pas de like, pas de chat. Juste une vitrine du club.

### 2.5 Hors scope assumé

- Synchronisation cloud de l'import (reste local, Point B plus tard).
- Import de rameurs (autre chantier, hors Point D).
- Import de séances / samples.
- OCR d'une photo de tableau Excel (trop fragile).
- Connexion Google Sheets / API distante.
- Génération PDF du spinoscope.
- Statistiques avancées (progression, moyennes).

---

## 3. Règles figées (pas de débat)

| # | Règle |
|---|---|
| D1 | Import = **prévisualisation obligatoire** avant écriture. Rien n'est écrit sans confirmation. |
| D2 | Le **modèle CSV** est téléchargeable depuis l'app (pas de doc externe à chercher). |
| D3 | En-têtes **tolérants** : casse, accents, synonymes reconnus. Colonne manquante → message clair, pas de crash. |
| D4 | Doublon = **mise à jour**, pas erreur bloquante. Rapport indique « mis à jour ». |
| D5 | Annulation d'import possible via `importId` sur les `Boat` créés. |
| D6 | `file_picker` déjà dans le pubspec — **réutiliser**, ne pas ajouter de dépendance lourde. XLSX via package léger (`excel`) ; XLS ancien → message « exportez en XLSX ». |
| D7 | Blason / couleurs = **identité club**, pas le deck global (reste #0B0E12). |
| D8 | Spinoscope = **vitrine**, pas un réseau social. Pas de fil, pas de like. |
| D9 | Scope MVP = D1–D5. D6+ (spinoscope avancé) = plus tard. |

---

## 4. Lots (ordre de build)

**D1 — Modèle enrichi + parser CSV/XLSX + tests, AUCUN écran**
- Étendre `Boat` : `boatType`, `brand`, `model`, `year`, `material`, `serial`, `notes`, `importId?`.
- Étendre `Club` : `fullName`, `slogan`, `foundedYear`, `primaryColor`, `secondaryColor`, `crestPath?`.
- `lib/import/csv_parser.dart` : parse CSV (`;`/`,`, UTF-8, tolérant), mapping en-têtes, validation, rapport.
- `lib/import/xlsx_parser.dart` : parse XLSX (package `excel`), même mapping.
- `lib/import/model_template.dart` : génère le CSV modèle (en-têtes + 2 exemples).
- Tests : parse CSV valide, CSV avec accents/casse, XLSX, colonne manquante, doublon, ligne vide, encodage pourri.
- Commit : `feat(datar0w): boat/club model enrichi + csv/xlsx parser + tests`

**D2 — Écran import (coach)**
- `/club/import` : 2 CTA — « Télécharger le modèle » (share sheet) + « Importer un fichier » (file_picker).
- Prévisualisation : tableau lignes parsées, colonnes reconnues/inconnues/erreurs, couleurs.
- CTA « Confirmer l'import » → écriture + rapport (N créées, M mises à jour, K ignorées).
- Lien « Annuler cet import » si `importId` présent.
- Accessible depuis `/club` (coach only).
- Commit : `feat(datar0w): club import screen csv/xlsx`

**D3 — Blason + couleurs club**
- Sur `/club` (édition) : upload blason (galerie/caméra), sélecteur 2 couleurs, nom complet, slogan, année fondation.
- Affichage sur accueil coach/rameur + spinoscope.
- Stockage local (path), sync cloud plus tard.
- Commit : `feat(datar0w): club crest + colors + identity`

**D4 — Spinoscope (vitrine club)**
- `/spinoscope` : blason, couleurs, nom, effectif (compétiteurs/loisirs), parc (coques par type/classe), sorties du jour, coupettes.
- Saisie coupettes (nom, date, résultat) par le coach.
- Visibilité : coach édition, rameur/loisir lecture.
- Commit : `feat(datar0w): club spinoscope vitrine`

**D5 — Sync Supabase (branche Point B, plus tard)**
- Tables `boat_imports`, `club_identity`. RLS par club.
- Photos blason : upload Storage au sync.
- Commit : `feat(datar0w): club import sync`

Hors scope D1–D5 : import rameurs, OCR, Google Sheets, PDF spinoscope, stats avancées, réseau social.

---

## 5. Prompt Cursor — Lots D1 → D5 (à coller tel quel)

```
DataR0w — Point D : import cabane (CSV/XLSX), enrichissement club, spinoscope.
Lis d'abord docs/CADRAGE-IMPORT-CABANE.md et docs/CADRAGE-IDENTITE-CLUB-EQUIPAGE.md.

Ne pas toucher AvSim. Ne pas revert compileSdk 37 / ndkVersion "30.0.16248370".
Pas de sdkmanager. Pas de windows/. Pas d'Accueil sur /live /cox /coach (sortie = STOP 2×).
Ne pas porter le jargon Stitch (SYS_ID, STAGE PROTOCOL, SENSOR SYNC, entraxe, calage).

DA : #0B0E12 / blanc / #9AA0A6 / #2A2F36 / CTA #E8C547 / TRIBORD #46C275 / BÂBORD #E05353.
Public cible : coachs PEU TECHNIQUES. Un fichier Excel posé sur le téléphone doit suffire.

## Règles métier (figées)
- Import = PRÉVISUALISATION OBLIGATOIRE avant écriture. Rien n'est écrit sans confirmation.
- Le MODÈLE CSV est téléchargeable depuis l'app (pas de doc externe).
- En-têtes TOLÉRANTS : casse, accents, synonymes. Colonne manquante → message clair, pas de crash.
- Doublon = MISE À JOUR, pas erreur bloquante. Rapport indique « mis à jour ».
- Annulation d'import possible via importId sur les Boat créés.
- file_picker déjà dans le pubspec — RÉUTILISER. XLSX via package léger (excel) ; XLS ancien → message « exportez en XLSX ».
- Blason / couleurs = identité club, pas le deck global (reste #0B0E12).
- Spinoscope = vitrine, pas un réseau social. Pas de fil, pas de like.
- Scope MVP = D1–D5. D6+ = plus tard.

## D1 — modèle enrichi + parser CSV/XLSX + tests, AUCUN écran
Étendre Boat : boatType (pointe|coupleuse|skiff|inconnu), brand, model, year, material, serial, notes, importId?
Étendre Club : fullName, slogan, foundedYear, primaryColor, secondaryColor, crestPath?
lib/import/csv_parser.dart : parse CSV (; ou ,, UTF-8, tolérant), mapping en-têtes, validation, rapport.
lib/import/xlsx_parser.dart : parse XLSX (package excel), même mapping.
lib/import/model_template.dart : génère le CSV modèle (en-têtes + 2 exemples).
Tests : CSV valide, accents/casse, XLSX, colonne manquante, doublon, ligne vide, encodage pourri.
Commit : feat(datar0w): boat/club model enrichi + csv/xlsx parser + tests

## D2 — écran import (coach)
/club/import : 2 CTA — « Télécharger le modèle » (share sheet) + « Importer un fichier » (file_picker).
Prévisualisation : tableau lignes parsées, colonnes reconnues/inconnues/erreurs, couleurs.
CTA « Confirmer l'import » → écriture + rapport (N créées, M mises à jour, K ignorées).
Lien « Annuler cet import » si importId présent.
Accessible depuis /club (coach only).
Commit : feat(datar0w): club import screen csv/xlsx

## D3 — blason + couleurs club
Sur /club (édition) : upload blason (galerie/caméra), sélecteur 2 couleurs, nom complet, slogan, année fondation.
Affichage sur accueil coach/rameur + spinoscope.
Stockage local (path), sync cloud plus tard.
Commit : feat(datar0w): club crest + colors + identity

## D4 — spinoscope (vitrine club)
/spinoscope : blason, couleurs, nom, effectif (compétiteurs/loisirs), parc (coques par type/classe), sorties du jour, coupettes.
Saisie coupettes (nom, date, résultat) par le coach.
Visibilité : coach édition, rameur/loisir lecture.
Commit : feat(datar0w): club spinoscope vitrine

## D5 — sync Supabase (branche Point B, plus tard)
Tables boat_imports, club_identity. RLS par club.
Photos blason : upload Storage au sync.
Commit : feat(datar0w): club import sync

## Hors scope
Import rameurs, OCR, Google Sheets, PDF spinoscope, stats avancées, réseau social.
Ne pas redessiner /live /cox /tare /coach carte /replay /crew /club (sauf enrichissement D3).

flutter analyze clean. Tests import verts.
Un commit par lot D1…D5, dans cet ordre.
```

---

## 6. Prochaine action

Lancer **D1** directement dans Cursor (modèle + parser + tests, pas d'écran), comme I1 et C1.

*Document vivant — ordre de build figé. À enrichir au fil des lots.*
