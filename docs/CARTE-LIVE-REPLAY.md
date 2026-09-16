# Carte — live et replay

*16 septembre 2026.*

Le GPS téléphone pose le bateau sur le plan d'eau. Vitesse = SOG. Distance = intégrale de la trace. Pas de vitesse eau, pas de RTK.

## Écran 5 — Live (844×390, profil Coach)

- Fond : carte sombre + polygone bassin si GeoJSON dispo, sinon fond neutre + trace seule.
- Point bateau = dernier fix. Trait = points de la séance.
- Nord en haut.
- Colonne droite, mêmes grandeurs que le live rameur : cadence (ou —), **V sol**, **distance**, gîte.
- Curseur temps = maintenant. Chip `live` si fix OK, `GPS perdu` sinon (on coupe le trait, on n'interpole pas).
- ANNOTER pose un repère sur le point GPS courant (timestamp + lat/lon + V + distance).

Le rameur au cale-pied **n'a pas** cette carte (lisible à 80 cm). Il garde l'écran 3.

## Écran 6 — Replay (844×390, profil Coach)

Même carte, même trace enregistrée.
- Play / pause / scrub : le point bateau **se déplace sur la trace**.
- À chaque instant du curseur on affiche la V sol et la distance **de cet instant**, pas les totaux seuls.
- Deux courbes temps (cadence, V sol) alignées sur le même curseur que la carte.
- Notes 1 / 2 = saut du curseur + du point sur la carte.
- Δ brut autorisé (ex. Δ cadence = +2) entre deux curseurs ou vs début. Pas de verdict.

## Données à logger (STOP → fichier)

À ~1 Hz : `t`, `lat`, `lon`, `sog_m_s`, `distance_m`, `gite_deg`, `cadence_spm|null`.
C'est ce fichier que 5 (queue live) et 6 (lecture) consomment.

## Hors contrat

Couloir FISA, splits officiels, interpolation quand le fix saute, carte rameur paysage au cale-pied.
