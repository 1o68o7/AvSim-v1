# Stitch — Point D : import cabane, identité club, spinoscope (ultra-détaillé)

> **Usage** : coller ce brief dans Stitch (même projet que la planche identité I2–I5).
> **Ne pas** refaire les 9 écrans identité déjà gelés (Qui rame, Fiche rameur, Mon club, Fiche bateau, Composer, 3 accueil, variante vide).
> **Ne pas** refaire live / tare / cox / coach carte / replay / crew.
> **Public** : coachs peu techniques. Un fichier Excel posé sur le téléphone doit suffire.
> **DA figée** : fond `#0B0E12`, texte blanc, labels `#9AA0A6`, filets `#2A2F36`, CTA `#E8C547` texte noir, TRIBORD `#46C275`, BÂBORD `#E05353`. Police cockpit / mono. **Pas** de cyan High-Vis, pas de RTK, 10 Hz, watts, SYS READY, 2000 m FISA.

---

## 0. Contexte produit (1 phrase)

Le coach arrive à la cabane avec son tableur (Excel / Google Sheets exporté). Il doit **télécharger un modèle → le remplir → l'importer → vérifier → c'est dans l'app**. Aucune ligne de commande, aucun script, aucune connaissance web.

Aujourd'hui le parc se saisit **coque par coque** (écran `/club/boat`). Ça va pour 2–3 bateaux. Un club réel a 15–40 coques. Sans import, le parc reste une démo.

---

## 1. État réel du code (à ne pas contredire)

| Élément | État |
|---|---|
| `Club` : nom + code court seulement | ✅ I3 |
| `ParkBoat` : nom, classe 1x–8+, cox, `oarRack`, statut ready/maint/out | ✅ I3 |
| Écran `/club` : CRUD coach, lecture rameur | ✅ I3 |
| Écran `/club/boat` : nom, classe (chips), pelles (texte libre), statut | ✅ I3 |
| `file_picker` dans pubspec | ✅ déclaré, **non utilisé** |
| Import CSV / XLSX | ❌ |
| Marque / modèle / type (pointe/coupleuse) | ❌ |
| Blason / couleurs club | ❌ |
| Spinoscope | ❌ |
| Téléchargement modèle depuis l'app | ❌ |

**Champs à AJOUTER au modèle bateau (D1)** : `boatType` (pointe / coupleuse / skiff / inconnu), `brand`, `model`, `year`, `material` (carbone / composite / bois), `serial`, `notes`, `importId?`.
**Champs à AJOUTER au modèle club (D1)** : `fullName`, `slogan`, `foundedYear`, `primaryColor`, `secondaryColor`, `crestPath?`.

---

## 2. Écrans à produire (5 écrans)

### Écran D1 — Import cabane (portrait 390×844) — COACH ONLY

**Titre** : `IMPORT PARC` · sous-titre `CSV · XLSX`.
**Deux CTA principaux** (pleine largeur, empilés) :
1. `TÉLÉCHARGER LE MODÈLE` (outline) → génère `datarow_parc_modele.csv` (en-têtes + 2 lignes d'exemple) → share sheet.
2. `IMPORTER UN FICHIER` (jaune) → `file_picker` (CSV, XLSX, XLS).

**Zone d'aide** (texte muted, 2 lignes) :
> « Remplissez le modèle dans Excel ou Google Sheets. Séparateur `;` ou `,`. Les en-têtes sont reconnus même avec fautes de frappe. »

**Si fichier choisi** → bascule en **prévisualisation** (même écran, scroll) :
- Tableau : 1 ligne d'en-tête + lignes parsées.
- Cellules : vert = colonne reconnue, ambre = inconnue, rouge = erreur (motif court, ex. « classe invalide »).
- Compteur en haut : `12 reconnues · 1 inconnue · 0 erreur`.
- Si erreur bloquante : bandeau ambre « 1 ligne ignorée — corrigez et réimportez ».
- **CTA** : `CONFIRMER L'IMPORT` (jaune, désactivé si 0 ligne valide) → écriture + rapport.
- Lien texte : `Annuler` → retour état initial.

**Rapport post-import** (remplace le tableau) :
- `14 créées · 3 mises à jour · 1 ignorée`
- Liste courte des ignorées (nom + motif).
- CTA `TERMINÉ` → `/club`.
- Lien `Annuler cet import` (supprime les créées de cet import, garde les mises à jour) — visible 24 h.

**Interdit** : écrire sans prévisualisation. Drag & drop (mobile). OCR photo.

---

### Écran D2 — Fiche bateau enrichie (portrait 390×844) — COACH ONLY

**Étendre** l'écran `/club/boat` existant (ne pas en créer un deuxième). Ajouter sous le nom :

| Champ | Type | Exemple |
|---|---|---|
| Type de coque | chips : Pointe / Coupleuse / Skiff / Inconnu | Coupleuse |
| Marque | texte + suggestions | Empacher |
| Modèle | texte libre | E8 |
| Année | nombre | 2021 |
| Matériau | chips : Carbone / Composite / Bois | Carbone |
| N° série / immat | texte optionnel | EMP-884-SFK |
| Pelles | texte libre (existant) | P1/P2/P4 |
| Statut | chips prêt / maintenance / hors d'eau (existant) | prêt |
| Notes | textarea 2 lignes | « Pagaie tribord usée » |

**CTA** : `ENREGISTRER` (jaune). `RETOUR` (leading).
**Rameur / loisir** : même écran en **lecture seule** (pas de CTA, pas d'édition) — cohérent avec la règle « parc éditable = coach ».

**Hors MVP** : entraxe, calage, tolérance, calibration factory (déjà exclus du cadrage parc opérationnel).

---

### Écran D3 — Identité club (portrait 390×844) — COACH ONLY

**Étendre** `/club` (ne pas créer d'écran séparé). Ajouter sous nom + code court :

| Champ | Type |
|---|---|
| Nom complet | texte (ex. « Émulation Nautique de Bordeaux ») |
| Slogan | texte court |
| Année de fondation | nombre |
| Couleur primaire | sélecteur (pastille) |
| Couleur secondaire | sélecteur (pastille) |
| Blason / logo | upload galerie ou caméra (PNG/JPG) — aperçu rond 64 px |

**Règle** : couleurs = **identité club**, pas le deck global (reste `#0B0E12`). Le blason s'affiche sur l'accueil coach/rameur et le spinoscope.
**Stockage** : local (path) au MVP. Sync cloud = Point B plus tard.
**CTA** : `ENREGISTRER LE CLUB` (existant, garder).

---

### Écran D4 — Spinoscope (vitrine club) (portrait 390×844) — LECTURE (coach + rameur + loisir)

**Titre** : `CLUB` · blason rond 80 px + nom complet + slogan en dessous.
**Couleurs club** : bandeau fin (primaire → secondaire) sous le slogan.

**Sections** (scroll, séparées par filets) :
1. **Effectif** — 2 barres simples : `X compétiteurs` / `Y loisirs` (pas de camembert 3D, pas de stats avancées).
2. **Parc** — compteurs : `n pointes · n coupleuses · n skiffs` + répartition par classe (1x, 2x, 4+, 8+…) en chips.
3. **Sorties du jour** — si Point C (parc opérationnel) actif : `2 coques sorties · 1 en maintenance`. Sinon masquer.
4. **Coupettes** — liste : nom + date + résultat (ex. « Régate Lac — 12/06 — 2e »). CTA coach : `+ AJOUTER UNE COUPETTE` (ouvre mini-formulaire : nom, date, résultat). Rameur/loisir : lecture seule.

**Visibilité** : coach édite les coupettes + identité. Rameur/loisir : lecture. Loisir voit **son** blason + les coupettes du club.
**Interdit** : fil d'actualité, like, chat, classement FFA en ligne, PDF, stats de progression.

---

### Écran D5 — Accueil club (variante identité) (portrait 390×844)

**Petit écran de transition** entre « Qui rame ? » et les 3 cartes rôle, **si** un club est actif :
- Blason 64 px + nom du club + slogan.
- Compteur : `n licenciés · n coques`.
- CTA `CONTINUER` (jaune) → `/` (3 cartes Rameur/Coach/Barreur).
- Lien `Changer de club` → `/club`.

Si **pas** de club actif : masquer, aller direct aux 3 cartes (comportement actuel).

---

## 3. Flux complet

```
Qui rame ? → (si club actif) Accueil club (D5) → 3 cartes rôle
Club (coach) → Fiche bateau enrichie (D2) ⇄ Import (D1)
Club (coach) → Identité club (D3)
N'importe qui → Spinoscope (D4) [lecture]
```

---

## 4. Interdit (global)

- Recréer les 9 écrans identité I2–I5.
- Recréer live / tare / cox / coach carte / replay / crew.
- Login Google, licence FFA en ligne, IMC, 8 IMU.
- OCR photo de tableau, Google Sheets, PDF spinoscope, réseau social.
- Écrire un import sans prévisualisation.
- Laisser un loisir picker le catalogue parc.

---

## 5. Livrable

5 écrans (D1–D5) + HTML. Même DA que la planche identité.
Ordre de build code (après Stitch gelé) : **D1** (modèle + parser + tests, pas d'écran) → D2 (écran import) → D3 (identité club) → D4 (spinoscope) → D5 (accueil club). Un commit par lot.

---

*Brief Stitch Point D — à coller tel quel. Document vivant.*
