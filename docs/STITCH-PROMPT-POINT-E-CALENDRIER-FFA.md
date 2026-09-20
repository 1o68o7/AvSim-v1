# Brief Stitch — Point E : Calendrier FFA + Plans d'eau + Localisation club

## Objectif
Produire les écrans UI pour le calendrier de compétitions FFA, les plans d'eau, et la localisation du club. Aucun code. Même DA que le deck existant (#0B0E12 / #E8C547 / #46C275 / #E05353).

## Benchmarks pompes (sources vérifiées)
- **TeamSnap** (9.3/10, 25M+ users) : calendrier unifié multi-équipes, vues liste/semaine/mois, détails événement (date, lieu, adresse, notes), sync iCal/Google, disponibilité. UI propre, mobile-first.
- **My Dragon Boat** (récent, App Store) : calendrier régattes global + carte monde, filtres (pays, classe, distance, rayon), ajout à l'équipe, RSVP, catégories 100m–2000m. Très proche de notre besoin aviron.
- **DragonBoat Hub** : liste + carte + calendrier, filtres communautaires.
- **LeagueApps / SportsEngine** : vues liste/calendrier/table, filtres multi-sélection, recherche.
- **FFA** : calendrier annuel public (cartes HTML, pas d'API). On curate en JSON.

## DA figée
Fond #0B0E12, texte blanc, labels #9AA0A6, filets #2A2F36, CTA #E8C547 texte noir, TRIBORD #46C275, BÂBORD #E05353. Police cockpit/mono. Pas de cyan, pas de social feed.

## Écrans à produire

### E1 — Calendrier compétitions (portrait 390×844)
- Header : DATAR0W / CALENDRIER. Toggle Liste | Carte (haut droit).
- Filtres chips : Tout / Championnats / Randon'Aviron / Master / Loisir / Indoor. Multi-sélection.
- Vue liste (défaut) : cartes événement empilées. Chaque carte : date (jour+mois), nom, lieu, distance, type (chip couleur), distance depuis moi (km).
- Vue carte : OSM (OpenFreeMap Dark) avec pins colorés par type. Tap pin → bottom sheet résumé.
- CTA bas : « Ajouter à mon calendrier » (export .ics) sur chaque fiche.
- Empty state : « Aucun événement ce mois » + lien FFA.

### E2 — Fiche événement (portrait)
- Hero : nom + dates + lieu (adresse + mini-carte 120px).
- Infos : type, distance, catégories, organisateur, inscription (deep-link MyFFA ou site orga — pas de paiement in-app).
- Bloc « Pour toi » : si profil rameur, suggestion selon niveau (loisir/compétiteur) et côté.
- CTA : « M'inscrire (externe) » + « Signaler ma participation » (opt-in, alimente spinoscope).
- Section résultats (si passé) : classement loisir/compétiteur, temps.

### E3 — Plans d'eau (portrait)
- Liste des bassins : nom, type (entraînement / compétition / rando), distance depuis moi, statut (ouvert/fermé).
- Carte : pins par plan d'eau, couleur selon type.
- Fiche plan d'eau : description, profondeur, longueur, accès, horaires, lien club rattaché.
- CTA : « Prochaine régate ici » si événement lié.

### E4 — Localisation club (portrait, sur fiche club existante)
- Carte OSM centrée sur le club (pin #E8C547).
- Adresse + géocode (Nominatim, gratuit).
- Rayon : « événements dans 50 km » (compteur).
- Pas d'édition pour le rameur ; coach peut corriger l'adresse.

## Interdit
Réseau social, chat, paiement in-app, scraping live FFA (catalogue curaté), login Google.

## Livrable
4 écrans + HTML. Même DA. Prêt à geler avant code E1–E5.
