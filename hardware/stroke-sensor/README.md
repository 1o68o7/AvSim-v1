# Stroke sensor — fichiers de prod rev 0.1

Pas des Gerbers d'usine. KiCad n'a pas pu tourner ici.
Ouvrir le projet dans KiCad 8, poser les empreintes du BOM, router, DRC, puis tracer les Gerbers.

- `bom.csv` : références d'achat
- `placement.csv` : positions indicatives, mm, origine coin bas-gauche du PCB 25 × 30
- `stroke-sensor.kicad_sch` : schéma de principe, pas un ERC vert
- `stroke-sensor.kicad_pcb` : contour 25 × 30 mm, non routé

Avant commande EMS Proto : DRC propre, garde de cuivre sous l'antenne AE1.
