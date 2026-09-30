# Prompts Stitch — backlog écrans 2026-09-30

> **Pas de code.** Stitch = maquettes Deck uniquement.
> Cadrage : `docs/CADRAGE-BACKLOG-LOTS-2026-09-30.md`.
> Après export PNG/SVG : Cursor branche les widgets (`docs/PROMPT-CURSOR-BACKLOG.md`).
> DA : fond `#0B0E12`, ambre CTA, `ColorScheme.error` `#E05353`, titres humains (plus de 2A/2B), AppBar 15 px, hit ≥ 48×48.
> Convention Retour : Lot B UX — live/cox sans Accueil ni Retour.

Coller **un écran par génération** Stitch. Nom de fichier = id ci-dessous.

---

## ST-01 — /auth état session ON

```
Écran DataR0w /auth — session déjà ouverte.
Smartphone portrait, DA Deck sombre #0B0E12.
Titre : CONNEXION
Sous-titre : compte cloud · pas de mot de passe local
Carte verte discrète : « Connecté en tant que antoine@… »
Boutons pleine largeur ambre : CONTINUER
Lien texte : Rattacher ce téléphone
Bouton secondaire contour : DÉCONNEXION
Pas de « Espace club ». Pas de « Envoyer le lien ». Pas de « Passer ».
```

## ST-02 — /auth état session OFF

```
Même DA. Titre CONNEXION.
Bouton Google (logo + « Continuer avec Google »).
Champ email + bouton ENVOYER LE LIEN.
Lien texte : Sans compte (debug only, petit, bas d'écran).
Pas d’Espace club. Pas de troisième porte.
```

## ST-03 — Accueil staff /home/admin

```
AppBar 15 px : ACCUEIL CLUB. Leading Retour → /.
Corps : nom club « Bordeaux », rôle ADMIN.
3 cartes : Import cabane, Demandes, Séances cloud.
Chip discret bas : CLOUD ou EN FILE.
Bouton texte bas : Déconnexion.
Pas de cartes Rameur/Coach/Barreur ici.
```

## ST-04 — Accueil rameur /home/rower

```
AppBar : ACCUEIL. Pas de menu club.
Cartes : Nouvelle séance, Mes séances, Profil.
Chip LOCAL / CLOUD discret.
Lien réglages (engrenage) → déconnexion + capteurs plus tard.
Simple, loisir OK sans licence.
```

## ST-05 — /club/sessions (coach)

```
Titre : SÉANCES DU CLUB
Liste : code 6 lettres (QEPSSL), date, « 53 Ko », pastille CLOUD.
État vide : « Aucune séance cloud — les zips arriveront après STOP. »
Tap ligne → fiche (ST-06).
Filtre none. Pas de bouton Sync.
```

## ST-06 — Fiche séance cloud

```
Titre : QEPSSL
Méta : 1x, bassin, début/fin, taille zip, owner.
Bloc résumé : dist, km/h, tps/500, gîte RMS.
Cadence : « cadence non mesurée » si absente (jamais « — » ou 0).
Pas de graphe IMU dans ce lot.
```

## ST-07 — Import CSV coach

```
Titre : IMPORT CABANE
2 zones drop/fichier : Bateaux.csv · Rameurs.csv
Après parse : « 42 bateaux OK · 3 erreurs ligne 12, 18, 21 »
CTA ambre : ENVOYER VERS LE CLUB
Texte : données yearly · stockées cloud, pas sur le téléphone.
```

## ST-08 — Liaison licence FFA

```
Onboarding rameur, une étape.
Titre : TA LICENCE
Champ : n° licence FFA (optionnel).
Helper : « Loisir sans licence : tu peux passer. »
CTA : CONTINUER · lien PASSER.
État trouvé : nom + club. État inconnu : « Profil loisir », pas d’erreur rouge.
```

## ST-09 — Bandeau sync (composant, pas écran plein)

```
Bandeau 36 px sous AppBar, pas overlay.
États : LOCAL gris · EN FILE ambre · CLOUD vert.
Texte court à droite : « 2 en file ».
La barre titre reste cliquable. Hit bandeau = chip seulement.
```

## ST-10 — Réglages + déconnexion rameur

```
Titre : RÉGLAGES
Lignes : Profil local, Compte cloud, Capteurs (bientôt), Déconnexion.
Déconnexion = dialogue Annuler / Déconnecter.
Sous-texte : « Tes séances restent sur ce téléphone. »
```

## Hors Stitch (ne pas dessiner)

Play Protect, écran keystore, majors deps, LSTM #50, firmware, girouette,
propeller, mail Pitto. LIVE 3 colonnes déjà livré — ne pas redesign.

## Ordre de génération

ST-01 → ST-02 → ST-10 (auth/logout) puis ST-03 → ST-05 → ST-06 (coach)
puis ST-07 → ST-08. ST-09 en composant dès C1 Cursor.
