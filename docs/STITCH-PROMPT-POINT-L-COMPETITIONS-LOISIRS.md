# Brief Stitch — Point L : Compétitions loisirs & randonnées

## Objectif
Produire les écrans UI pour le calendrier étendu (régates ouvertes, Randon'Aviron, master), les garde-fous licence AL/AC/EC, le signalement de participation, et l'import de résultats loisir. Aucun code. Même DA (#0B0E12 / #E8C547 / #46C275 / #E05353).

## Benchmarks pompes (sources vérifiées)
- **TeamSnap** : calendrier unifié multi-équipes, vues liste/semaine, détails événement, disponibilité, sync iCal. Cards scannables, mobile-first.
- **My Dragon Boat** : calendrier régattes global + carte, filtres (pays, classe, distance), RSVP, catégories 100m–2000m. Très proche aviron.
- **Strava Events** (2026) : hub courses, filtres distance/date/lieu/sport, cards avec RSVP, transition vers plan d'entraînement.
- **Garmin Connect** : dark mode, cards In Focus, calendrier coloré par type d'activité.
- **DragonBoat Hub / PaddlesUp!** : gestion festivals/régates, lineups, résultats.
- **FFA** : calendrier annuel public (cartes HTML, pas d'API). On curate en JSON.

## DA figée
Fond #0B0E12, texte blanc, labels #9AA0A6, filets #2A2F36, CTA #E8C547 texte noir, TRIBORD #46C275, BÂBORD #E05353. Police cockpit/mono. Pas de cyan, pas de social feed, pas de paiement in-app.

## Écrans à produire

### L1 — Calendrier loisirs étendu (portrait 390×844)
- Header : DATAR0W / CALENDRIER. Toggle Liste | Carte.
- Filtres chips : Tout / Régate ouverte / Randon'Aviron / Master / Indoor. Multi-sélection.
- Vue liste : cartes événement. Chaque carte : date (jour+mois), nom, lieu, distance, type (chip couleur), licence requise (AL/AC/EC), distance depuis moi.
- Vue carte : OSM (OpenFreeMap Dark) pins colorés par type.
- Bandeau si profil AL : « Licence AL — compétition AC réservée ». Si AC : tout visible.
- CTA bas : « Ajouter à mon calendrier » (.ics) sur chaque fiche.
- Empty : « Aucun événement ce mois » + lien FFA.

### L2 — Fiche événement loisir/rando/master (portrait)
- Hero : nom + dates + lieu (adresse + mini-carte 120px).
- Infos : type, distance, catégories, organisateur, définition loisir (texte orga), licence requise, inscription (deep-link MyFFA/site orga).
- Bloc « Pour toi » : suggestion selon niveau (loisir/compétiteur) et côté.
- CTA : « M'inscrire (externe) » + « Signaler ma participation » (opt-in).
- Section résultats (si passé) : classement loisir/compétiteur, temps de course réels.
- Si Randon'Aviron : labellisé, pas de chrono officiel, km parcourus.

### L3 — Signalement de participation (portrait)
- Depuis fiche ou profil : « J'ai participé » / « Mon équipage a participé ».
- Champs : événement, date, équipage (siège + côté), temps (si chronométré), classement loisir, distance (si rando).
- Option : importer PDF/CSV de résultats (pattern Point D : prévisualisation, mapping colonnes).
- Confirmation : « Participation signalée — visible dans ton profil / spinoscope ».

### L4 — Historique rameur (portrait, sur profil)
- Liste participations : régate / rando / master, date, temps, classement.
- Tendance : « 3 régates loisir, 1 rando, 1 master — meilleur temps 1:05:59 ».
- Chip « Un rameur, un parcours » (loisir ou compétiteur, pas de blocage).

### L5 — Spinoscope loisir (portrait, club)
- Effectif engagé, km rando, podiums loisir, régates ouvertes.
- Cards : top rameurs loisir, top clubs rando (Trophée Randon'Aviron).
- Pas de réseau social, pas de like/comment.

## Interdit
Paiement in-app, gestion licence FFA, chronométrage officiel, arbitrage, Code des régates, login Google, scraping live FFA (catalogue curaté).

## Livrable
5 écrans + HTML. Même DA. Prêt à geler avant code L1–L5.
