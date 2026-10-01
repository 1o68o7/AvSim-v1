# Stroke Sensor — Brief design mécanique v1

> Document de conception du clip et du boîtier du stroke sensor.
> Version : 1.0 — 1er octobre 2026
> Statut : brief validé, modèle FreeCAD à produire
> Complète : docs/hardware/stroke-sensor/brief.md (électronique)
> Réorganisé le 1er octobre 2026 dans docs/hardware/stroke-sensor/

---

## 1. Objectif

Concevoir le boîtier et le clip du stroke sensor : un capteur clipé sur le manche de la rame, étanche, léger, et amovible sans abîmer la rame. Le boîtier porte le PCB 25×30 mm, la LiPo, le port USB-C et les LED.

## 2. Contraintes fonctionnelles

| Contrainte | Valeur / exigence |
|---|---|
| Masse totale | < 30 g (capteur + clip + batterie) |
| Fixation | Amovible, sans outil, sans abîmer la rame (règle FFA : pas de modification permanente) |
| Étanchéité | IP67 minimum — immersion occasionnelle, sueur, pluie |
| Vibrations | Résister aux chocs et vibrations du coup d'aviron (fréquence ~1–2 Hz, pics d'accélération > 5 g) |
| Température | -5 °C à +45 °C en fonctionnement ; recharge interdite sous 0 °C |
| USB-C | Accessible sans démonter le clip ; LED visibles de l'extérieur |

## 3. Géométrie du clip

### 3.1 Profil en U

- Forme en **U** qui épouse le manche de la rame
- Diamètre intérieur du U : 28 mm (manche standard rame aviron ~25–27 mm) — prévoir une tolérance de ±1 mm
- Longueur du clip : 60 mm minimum pour la stabilité (pas de rotation autour du manche)
- Épaisseur des parois : 2 mm

### 3.2 Nervures internes

- 4 nervures longitudinales en silicone (ou TPU souple) réparties sur le pourtour du U
- Hauteur de nervure : 1,5 mm — elles absorbent les vibrations et compensent les tolérances entre rames
- Matériau des nervures : plus souple que le corps du clip (TPU 85A vs 95A)

### 3.3 Fixation

- **Option A (retenue pour le prototype)** : clip souple en TPU — le clip lui-même fait ressort, il s'enfile et se retire à la main
- Option B (alternative) : sangle élastique type BladeWork — le boîtier est fixé par une sangle autour du manche. À considérer si le clip TPU glisse sur les rames en carbone
- Le clip doit rester amovible : un clip qui se coince = rame rayée = rameur énervé

## 4. Boîtier électronique

### 4.1 Dimensions internes

| Élément | Dimensions |
|---|---|
| PCB | 25 × 30 mm, 1,6 mm d'épaisseur |
| LiPo | 4 × 20 × 2,5 mm |
| Port USB-C | ~9 × 3,5 mm (réceptacle SMD) |
| LED verte + rouge | 0402, visibles par des fenêtres translucides |
| Bouton SW1 | ~4 mm de diamètre |

### 4.2 Dimensions externes du boîtier

- Longueur : 45 mm (PCB + marge pour le port USB-C)
- Largeur : 30 mm
- Hauteur : 12 mm (PCB 1,6 + LiPo 2,5 + espace de câblage + paroi 2 mm) + 3 mm pour le port USB-C qui dépasse → **~15 mm au total**
- Le port USB-C est sur la face latérale, accessible sans démonter

### 4.3 Intégration clip + boîtier

- Le boîtier est **soudé ou clipsé** sur le dessus du clip (pas de vis — vibrations)
- Ou : le boîtier et le clip forment une seule pièce monobloc en TPU (plus simple à imprimer, moins de points de défaillance)
- **Recommandation** : monobloc pour le prototype skiff

## 5. Étanchéité

### 5.1 Prototype skiff (DIY)

- **Potting résine époxy** : le PCB assemblé est coulé dans de la résine époxy dans un moule en silicone ou un gobelet — encapsulation complète, zéro joint
- Alternative : joint torique (O-ring) NBR 70 Shore entre le couvercle et le corps du boîtier
- Le port USB-C : capuchon silicone rabattable (type capuchon de port téléphone) — à ouvrir uniquement pour recharger
- Les LED : fenêtres en résine translucide ou en TPU clair

### 5.2 Production (futur)

- **Surmoulage LSR** sur substrat rigide : le PCB est inséré dans un moule, le silicone liquide est injecté à basse pression et cuit entre 160 et 200 °C
- Adhérence silicone-plastique : traitement de surface plasma ou primaire obligatoire, sinon décollement au bout de quelques mois d'eau et de sueur
- Coût moule : 5–12 k€ (LSR simple), 15–50 k€ (production acier)
- Seuil de rentabilité : ~500–1000 pièces

## 6. Matériaux

| Pièce | Matériau | Justification |
|---|---|---|
| Corps du clip | TPU 95A | Rigide mais souple, résiste aux UV et à l'eau de mer |
| Nervures | TPU 85A ou silicone | Absorption des vibrations |
| Boîtier électronique | TPU 95A (monobloc) ou ABS + joint torique | ABS plus rigide si on sépare boîtier et clip |
| Résine de potting | Époxy bi-composant | Encapsulation complète |

## 7. Processus de fabrication prototype

1. **Modélisation** : FreeCAD (gratuit) — profil en U, nervures, boîtier monobloc
2. **Impression** : FabLab Cap Sciences (quai de Bacalan, Bordeaux) — imprimantes résine, jeudi/vendredi/samedi 14h–18h. B3D Makers (Talence) en alternative pour l'impression résine à coût réduit
3. **Itération** : une soirée d'impression par version, coût matière 2–5 €
4. **Test** : montage sur rame réelle, test en eau, vérification de l'étanchéité (immersion 30 min)

## 8. Points de vigilance

- **Résine 3D poreuse** : une pièce imprimée couche par couche laisse passer l'eau par les micro-pores → sceller au vernis ou compter sur le potting
- **Port USB-C** : le capuchon doit être facile à ouvrir d'une main (rameur en train de ramer)
- **LED** : visibles même sous lumière directe du soleil
- **Bouton SW1** : accessible sans démonter, mais pas trop facile à actionner par accident
- **Masse** : viser < 25 g pour ne pas perturber le comportement de la rame

## 9. Fichiers à produire

- [ ] Modèle FreeCAD du clip monobloc (STL pour impression)
- [ ] Dessin 2D des côtes (PDF) pour validation
- [ ] Modèle du moule de potting (si potting retenu)

## 10. Prochaines étapes

1. Dessiner le clip monobloc dans FreeCAD à partir de ce brief
2. Imprimer une première version au FabLab
3. Tester sur rame réelle (montage, retrait, étanchéité)
4. Itérer jusqu'à validation
5. Si OK → envisager le surmoulage LSR pour la production

---

*Document généré le 1er octobre 2026. À mettre à jour à chaque itération de conception.*