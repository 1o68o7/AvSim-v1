# Stroke Sensor — Brief clip latex (moule maison) v1

> Document de conception du clip latex du stroke sensor, alternative DIY au clip TPU imprimé 3D.
> Version : 1.0 — 1er octobre 2026
> Statut : brief validé, moule à réaliser
> Complète : docs/hardware/stroke-sensor-design-brief.md (clip TPU) et docs/hardware/stroke-sensor-brief.md (électronique)

---

## 1. Objectif

Produire un clip en **latex** pour le stroke sensor, moulé à la main avec un moule maison en plâtre (technique de la cire perdue). Le latex est souple, étanche et épouse le manche de la rame sans le rayer — idéal pour le prototype skiff avant d'investir dans du TPU imprimé ou du surmoulage silicone.

## 2. Pourquoi le latex

| Critère | Latex | TPU imprimé 3D |
|---|---|---|
| Souplesse | Excellente — épouse le manche | Bonne mais couche par couche |
| Étanchéité | Naturelle, sans joint | Poreux — à sceller |
| Risque pour la rame | Aucun (souple) | Faible mais possible |
| Durée de vie | 6–12 mois (vieillit) | Plusieurs années |
| Coût prototype | Quelques euros | 2–5 € de matière |

## 3. Processus de moulage (cire perdue)

### 3.1 Étapes

1. **Sculpter le maître en cire** : profil en U, diamètre intérieur 28 mm, longueur 60 mm, parois 2 mm, 4 nervures internes de 1,5 mm de hauteur. La cire doit être facile à sculpter (cire à modeler ou cire d'abeille fondue)
2. **Couler le plâtre** autour du maître : plâtre de Paris ou plâtre dentaire, dans un contenant (boîte en carton, gobelet). Laisser prendre 30–60 min
3. **Faire fondre la cire** : four à 80–100 °C, ou eau chaude. La cire s'écoule, il reste la cavité
4. **Couler le latex liquide** dans la cavité : latex liquide de moulage (type pour moules souples), laisser polymériser 24–48 h à température ambiante
5. **Casser le plâtre** : le plâtre est à usage unique, chaque clip nécessite un nouveau moule

### 3.2 Matériel nécessaire

- Cire à modeler ou cire d'abeille
- Plâtre de Paris (quelques euros le sac)
- Latex liquide de moulage (type pour moules souples, ~15–25 € le litre)
- Contenant pour le plâtre (boîte, gobelet)
- Four ou eau chaude pour faire fondre la cire

## 4. Géométrie du clip (identique au brief TPU)

| Paramètre | Valeur |
|---|---|
| Diamètre intérieur du U | 28 mm (manche standard ~25–27 mm, tolérance ±1 mm) |
| Longueur | 60 mm minimum |
| Épaisseur des parois | 2 mm |
| Nervures internes | 4, hauteur 1,5 mm, réparties sur le pourtour |
| Masse cible | < 25 g (latex plus lourd que TPU à volume égal — surveiller) |

## 5. Intégration avec le boîtier électronique

- Le boîtier électronique (PCB 25×30 mm, LiPo, USB-C) est **clipsé ou collé** sur le dessus du clip latex
- Alternative : le clip latex fait office de boîtier — le PCB est potté directement dans le latex (encapsulation complète, étanchéité maximale)
- **Recommandation pour le prototype** : clip latex séparé + boîtier potté en résine époxy, assemblés ensemble. Plus facile à itérer

## 6. Limites et points de vigilance

- **Vieillissement** : le latex durcit et se fissure au bout de 6–12 mois, surtout avec l'eau de mer et le soleil. Prévoir un remplacement régulier
- **Moule à usage unique** : chaque clip nécessite un nouveau moule plâtre. Bon pour 2–3 prototypes, pas pour une série
- **Réparation** : le latex se répare facilement avec de la colle à latex ou du ruban adhésif
- **Stockage** : à l'abri de la lumière et de la chaleur pour prolonger la durée de vie
- **Pas pour la production** : pour une série, revenir au TPU imprimé ou au surmoulage silicone (voir brief design)

## 7. Coût estimé (par clip)

| Poste | Coût |
|---|---|
| Plâtre (moule) | 1–2 € |
| Latex liquide | 2–4 € |
| Cire (maître) | < 1 € |
| **Total par clip** | **~4–7 €** |

Coût initial du matériel (latex 1 L, plâtre, cire) : ~30–40 €. Rentabilisé dès le 5e clip.

## 8. Fichiers à produire

- [ ] Maître en cire sculpté (pas de fichier numérique nécessaire — sculpture directe)
- [ ] Photos du processus de moulage (documentation)

## 9. Prochaines étapes

1. Sculpter le maître en cire (profil en U + nervures)
2. Réaliser le premier moule plâtre
3. Couler le premier clip latex
4. Tester sur rame réelle (montage, retrait, étanchéité — immersion 30 min)
5. Si OK → produire les 2 clips pour le test skiff
6. Si le latex vieillit trop vite → basculer sur le clip TPU imprimé (brief design)

---

*Document généré le 1er octobre 2026. À mettre à jour à chaque itération de conception.*