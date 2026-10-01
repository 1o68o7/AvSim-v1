# Patch coque — vitesse eau, vent, logger

> Cadrage du 1er octobre 2026. Inspiration, pas une copie de pièce.
> La sueur et le patch dorsal sont abandonnés. Ce document ne les reprend pas.

## Rôle

Un seul logger sur la coque.

- Entraînement : BLE vers le téléphone.
- Course : radio coupée, mémoire locale, vidange USB au ponton.
- IMU (BMI323), pression (BMP390), température / humidité (SHT40) restent dans le boîtier.
- La vitesse fond vient du GNSS du téléphone. La vitesse eau ne sert que si le courant compte (rivière, Tideway).

## Vent

Anémomètre + girouette, petit mât, **entraînement seulement**, BLE. Pas en course : traînée et règlement. Ce n'est pas une éolienne.

## Vitesse eau — ce qu'on ne prend pas

- Propulseur SUP type 9KM (moteur 360 W, télécommande). Ça pousse, ça ne mesure pas. [Fiche Alibaba](https://www.alibaba.com/product-detail/9KM-H-Speed-Directional-SUP-Propeller_1601381452913.html).
- Passe-coque voilier (Airmar ST800, NASA, nke) : perçage 42–51 mm, incompatible avec un skiff.

## Références aviron

| Produit | Lien | Note |
|---|---|---|
| NK SpeedCoach Impeller, SKU 0151, ~30 $ | https://nksports.com/speedcoach-impeller_1 | Roue + adhésif 3M, sans perçage. Sortie uniquement SpeedCoach GPS ou OC Model 2. Pose conseillée 5–6 m de la proue. |
| Coxmate Micro Impeller 2 | https://www.coxmate.com.au/product/micro-impeller-2/ | Petite roue, moins de traînée et d'herbes. Lue par SX / HC. Le SX accepte aussi une roue NK, facteur K calibré sur ~250 m aller-retour. |

Fil de départ : [r/Rowing — water speed sensor](https://www.reddit.com/r/Rowing/comments/ojao1k/water_speed_sensor_discussion/). Retours : la roue casse ou s'herbe ; le GPS suffit pour la forme ; la vitesse eau sert à comparer des jours de courant différent ; NK ne parle pas aux montres.

## Principes libres, pas les pièces

On ne copie ni le moule Coxmate, ni leur trame, ni leur K.

- Roue + aimant + Hall. Fréquence des impulsions = vitesse. [US3596513A](https://patents.google.com/patent/US3596513A/en) (Finch, 1971).
- Sans pièce mobile : effet Faraday, aileron hors couche limite. [US5357794A](https://patents.google.com/patent/US5357794A/en) (Nielsen-Kellerman, 1992, expiré en 2002). Piste propre contre les herbes.
- Pose : adhésif, pas de perçage. Roue sacrifiable si on reste sur une roue.

## Banc

1. Acheter un Micro Impeller 2 pour la taille et la pose, pas pour le cloner.
2. Logger : BLE à l'entraînement, muet en course.
3. Anémomètre BLE seulement hors course.
4. Loch maison plus tard : aileron clipé, roue ou électrodes du brevet expiré, impulsions à nous, calibration GPS aller-retour.
