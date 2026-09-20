# Brief Stitch — Point C : Parc opérationnel (sortie, alignement, pelles, impact)

## Objectif
Produire les écrans UI pour le cycle de vie opérationnel des coques : sortie de parc, retour, départ/alignement, jeu de pelles dédié, verrou multi-coach, signalement d'impact. Aucun code. Même DA que le deck existant (#0B0E12 / #E8C547 / #46C275 / #E05353).

## Benchmarks pompes (sources vérifiées)
- **TeamSnap** (9.3/10, 25M+ users) : calendrier unifié, vues liste/semaine, détails événement, disponibilité, sync iCal. UI propre, mobile-first, cards scannables.
- **My Dragon Boat** : calendrier régattes + carte, filtres, RSVP, catégories distance. Très proche aviron.
- **DragonBoat Hub / PaddlesUp!** : lineups drag & drop, balance gauche/droite, gestion festivals/régates.
- **Garmin Connect** : dark mode par défaut, cards In Focus, calendrier coloré par type d'activité.
- **Strava Events** : hub courses, filtres distance/date/lieu, cards événement avec RSVP.

## DA figée
Fond #0B0E12, texte blanc, labels #9AA0A6, filets #2A2F36, CTA #E8C547 texte noir, TRIBORD #46C275, BÂBORD #E05353. Police cockpit/mono. Pas de cyan, pas de social feed.

## Écrans à produire

### C1 — Sortie de parc (coach, portrait 390×844)
- Header : DATAR0W / SORTIE PARC. Chip « Coach : [Nom] ».
- Liste coques `ready` : nom, classe, statut (pastille verte), rack pelles (chips P1/P2/P4).
- CTA par coque : « Sortir ». Tap → bottom sheet :
  - Jeu de pelles (sous-ensemble du rack) : sélecteur quantité par spec.
  - Heure prévue de retour (picker).
  - Option « Photo d'impact » (caméra, opt-in).
- Coques `out` : grisées, chip « Sortie par [Coach X] jusqu'à 15h30 » (file d'attente).
- Empty : « Aucune coque prête ».

### C2 — Retour de parc (coach, portrait)
- Liste coques `out` : nom, sortie à [heure], coach, pelles attendues.
- CTA « Rentrer » : vérifie pelles (OK / manquant), option photo impact.
- Si manquant : bandeau ambre « Pelles manquantes — à signaler ».
- Après retour : coque `ready` ou `maintenance` (si impact).

### C3 — Départ / alignement (coach, paysage 844×390)
- Vue coach : coques sorties + équipages + pelles, ordre d'embarquement.
- Colonnes : Coque | Équipage | Pelles | Départ prévu.
- Tri auto : 8+ d'abord, 1x en dernier (ou par quai).
- CTA « Lancer la séance » → propose check-in auto à la fin.
- Pas de télémétrie ici.

### C4 — Signalement d'impact (coach/barreur, portrait)
- Depuis C1/C2 : CTA « Signaler un impact ».
- Caméra (une photo) + note courte (champ libre).
- Coque → `maintenance`, file visible coach/admin.
- Rameur affecté : notification « ta coque est en maintenance » (sans détail photo si sensible).
- File maintenance : liste coques signalées, photo + note, statut jusqu'à réparation.

### C5 — Fiche coque enrichie (lecture, portrait)
- Sur fiche bateau existante : ajouter cycle de vie (dernière sortie, prochaine prévue, historique 5 dernières).
- Tag `loisir_ok` visible (coach only éditable).
- Pas d'édition pour le rameur.

## Interdit
Réservation J-1, calendrier multi-jours, usure pelles (compteurs), GPS hangar, inspection IA, télémétrie par siège, paiement, login Google.

## Livrable
5 écrans + HTML. Même DA. Prêt à geler avant code C1–C6.
