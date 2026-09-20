# Brief Stitch — Point R : Cardio BLE pour le dashboard rameur

## Objectif
Produire les écrans UI pour le pairing BLE, le chip FC/SpO2 discret sur le live, la courbe FC en replay, et la visibilité coach. Aucun code. Même DA (#0B0E12 / #E8C547 / #46C275 / #E05353).

## Benchmarks pompes (sources vérifiées)
- **Garmin Connect** (dark mode par défaut) : cards In Focus, courbes empilées FC/activité, zones colorées, calendrier coloré.
- **WHOOP** : Recovery 0–100, 4 contributeurs (sommeil, FC repos, variabilité, respiration), tendance 28 jours.
- **Oura** : trends empilés, readiness score, courbes longitudinales.
- **ErgData / CrewNerd** (aviron) : overlay FC/SPM/vitesse, presets d'affichage, courbes 2ᵉ axe.
- **Polar Verity Sense / Aviron Pulse** : brassard optique, FC + SpO2, BLE GATT standard.

## DA figée
Fond #0B0E12, texte blanc, labels #9AA0A6, filets #2A2F36, CTA #E8C547 texte noir, TRIBORD #46C275, BÂBORD #E05353. Police cockpit/mono. Pas de cyan, pas de social feed.

## Écrans à produire

### R1 — Pairing BLE (portrait 390×844)
- Header : DATAR0W / MES CAPTEURS.
- Liste appareils appairés : nom, type (sangle/brassard/patch), batterie, dernier vu.
- CTA « Scanner » : scan GATT 0x180D (FC) / 0x1822 (SpO2). Liste trouvée : nom, RSSI, « Appairer ».
- États : connecté (vert), déconnecté (ambre), erreur (rouge discret).
- Note : « 1 capteur = 1 rameur. Le coach voit la FC via l'API, pas en direct BLE. »
- Empty : « Aucun capteur — branche une sangle Polar/Garmin ou ton patch dorsal. »

### R2 — Chip FC/SpO2 sur live rameur (overlay, pas écran dédié)
- Sur `/live` existant : chip discret en haut, à côté de la gîte.
  `♥ 142` (vert < seuils, ambre zone 4, rouge > 180) + `SpO2 97%` si présent.
- Tap → mini-panneau : batterie capteur, nom appareil, « Déconnecter ».
- Pas de gros chiffre, pas de push layout. Si déconnexion : `♥ —` (pas d'erreur bloquante).
- SpO2 optionnel : pastille seulement si dispo, sinon masqué.

### R3 — Courbe FC en replay (portrait/paysage)
- Sur replay existant : 2ᵉ axe FC (comme la gîte), SpO2 en pastilles ponctuelles.
- Zones colorées : récupération / aérobie / seuil / max.
- Toggle : afficher/masquer FC, SpO2, gîte.
- Export : FC dans le jsonl (si capteur branché).

### R4 — Visibilité coach (lecture, sur fiche rameur)
- Si API live transmet `hrBpm` : chip FC sur la fiche rameur (coach).
- Sinon : « — » (le coach ne pair pas le BLE lui-même).
- Tendance 7/28 jours : courbe FC moyenne par séance.
- Consentement : toggle « Partager ma FC avec le coach » (opt-in, défaut off).

### R5 — Consentement santé (portrait, sur profil)
- 3 toggles : FC live coach / SpO2 / tendance récupération.
- Texte : « Données de santé, usage informatif, pas médical. Tu contrôles le partage. »
- Pas de diagnostic, pas d'alerte médicale.

## Interdit
ANT+, SDK propriétaire Polar/Garmin, diagnostic médical, alertes urgence, SpO2 en continu temps réel, montre Apple comme source, Concept2 PM5/FTMS (autre chantier).

## Livrable
4 écrans + 1 overlay + HTML. Même DA. Prêt à geler avant code R1–R5.
