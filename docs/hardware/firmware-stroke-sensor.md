# Stroke sensor — Guideline firmware (build, flash, mises à jour)

> Couvre le cycle complet du firmware du stroke sensor : outils à acheter, premier flash, mises à jour après coup.
> Version : 1.0 — 1er octobre 2026
> Prévaut avec : `docs/hardware/stroke-sensor/brief.md`
> Cible : nRF52840-QFAA (QFN48), PCB 25×30 mm, LiPo + USB-C charge seule.

---

## 1. Réponse courte

Oui, le firmware se met à jour après coup. Mais pas par le port USB-C.

Le boîtier retenu, **nRF52840-QFAA**, n'a pas les broches USB routées. Le connecteur USB-C du capteur ne sert qu'à charger la LiPo (MCP73831). Il ne transporte pas de données.

Deux chemins :

| Moment | Comment | Outil |
|---|---|---|
| Premier flash (puce vide) | **SWD** obligatoire | nRF52840 DK ou J-Link |
| Mises à jour suivantes | **BLE DFU** (MCUboot) | téléphone ou nRF Connect, sans ouvrir le boîtier |
| Secours si le BLE DFU est cassé | retour SWD | même programmateur |

Pour le test skiff : un flash filaire par carte, puis toutes les itérations firmware en Bluetooth.

---

## 2. Ce qu'il faut acheter

### Indispensable

| Outil | Rôle | Prix indicatif | Où |
|---|---|---|---|
| **nRF52840 DK** (PCA10056) | Programmateur J-Link embarqué + carte de référence pour développer avant d'avoir le PCB | ~40–50 € | Mouser, DigiKey, Farnell |
| Câbles Dupont femelle-femelle | Relier P20 du DK aux pads SWD du capteur | ~3 € | n'importe quel électronique |
| Pinces de test ou Tag-Connect TC2030 | Contact sur les 4 pads sans souder un connecteur | pinces ~5 € ; Tag-Connect ~30 € | Tag-Connect si série de flashs |

Le DK suffit. Pas besoin d'un J-Link séparé en plus.

### Utile, pas bloquant

| Outil | Rôle | Prix |
|---|---|---|
| J-Link EDU Mini | Plus compact si tu ne veux pas trimballer le DK | ~20 € (licence éducation, pas pour un produit vendu) |
| Multimètre | Vérifier 3,0–3,6 V sur VDD avant de flasher | déjà courant |
| Loupe ou microscope USB | Lire la sérigraphie des pads SWD | optionnel |

### À ne pas acheter pour ce proto

- nRF52840 Dongle : il se flashe en USB parce qu'il a l'USB. Notre QFAA ne l'a pas. Inutile comme programmateur du capteur.
- ST-Link / Pico CMSIS-DAP : ça peut marcher, c'est plus lent et le recover Nordic est moins fiable. À éviter pour le premier proto.

### Logiciel (gratuit)

- **nRF Connect for Desktop** + application **Programmer** (flash, recover, lecture mémoire).
- **nRF Connect SDK** via **nRF Util** / Toolchain Manager (Zephyr, `west`).
- **VS Code** + extension nRF Connect (optionnel, plus confortable que la ligne de commande).
- macOS, Linux ou Windows. Sur macOS, installer les drivers J-Link Segger si le DK n'est pas vu.

---

## 3. Pads à prévoir sur le PCB (KiCad)

Quatre pads minimum, accessibles **avant potting** et idéalement via une fenêtre du clip :

| Pad | Signal | Vers le DK (header Debug out P20) |
|---|---|---|
| 1 | SWDIO | SWD IO |
| 2 | SWCLK | SWD CLK |
| 3 | GND | GND |
| 4 | VDD | VDD nRF (3,0–3,3 V, pas le 5 V USB) |

Optionnels : RESET, SWO (trace, pas nécessaire au flash).

Règle DK : pour programmer la carte externe et pas la puce du DK, relier **VDD du connecteur P1 vers SWD SEL sur P20**, puis SWDIO, SWDCLK, GND, VDD vers le capteur. Sans ce strap SWD SEL, le Programmer écrit dans le DK.

Ne pas alimenter le capteur par le 5 V USB-C pendant le flash SWD si la LiPo est absente et le régulateur pas encore validé. Pour le premier flash, alimenter en 3,3 V depuis le DK.

---

## 4. Installer la chaîne

1. Installer **nRF Connect for Desktop** : https://www.nordicsemi.com/Products/Development-tools/nRF-Connect-for-Desktop
2. Dans Toolchain Manager, installer le **nRF Connect SDK** (branche stable, pas une preview).
3. Ouvrir un terminal « nRF Connect » (le toolchain met `west` et le compilateur dans le PATH).
4. Brancher le DK en USB. Dans Programmer, il doit apparaître comme J-Link.

Vérif :

```bash
west --version
nrfutil --version
```

---

## 5. Développer avant le PCB custom

Tant que le PCB EMS Proto n'est pas là, le firmware se développe sur le **nRF52840 DK** avec un BMI323 sur breadboard (I2C). Même puce, même SDK. Le board Zephyr est `nrf52840dk_nrf52840`.

Quand le PCB custom existe, on ajoute un board overlay (`stroke_sensor`) : pins I2C, LED, bouton, NTC, pas d'USB.

Repo prévu : `datar0w-firmware` (séparé de l'app Flutter). Dossier cible : `firmware/stroke/`.

---

## 6. Ce que le firmware doit faire

Aligné sur `stroke-sensor/brief.md` :

- Lecture BMI323 en I2C à 50 Hz.
- Filtrage gîte, tau = 0,32 s.
- BLE service `0xA000`, caractéristique stroke `0xA001`, 12 octets : timestamp (4), gîte (2), acc X/Y/Z (2+2+2). Envoi 10 Hz.
- `0xA002` : intervalle d'envoi.
- Bouton SW1 : appairage / reset.
- LED verte : état BLE. LED rouge : charge.
- Charge : refuser sous 0 °C (NTC sur THERM du MCP73831 + sonde interne nRF). Le NTC coupe déjà en hardware ; le firmware est la deuxième couche.
- Veille profonde ~0,4 µA quand pas de session.
- MCUboot + BLE DFU pour les mises à jour.

Protocole à figer avant le premier tag : le brief actuel envoie à **10 Hz**. L'ancien cadrage envoyait **1 paquet par coup**. Le firmware suit le brief du 1er octobre (10 Hz) tant qu'on n'a pas re-décidé.

---

## 7. Build

Depuis le toolchain nRF Connect, dans le repo firmware :

```bash
cd firmware/stroke
west init -l .          # seulement la première fois, si le workspace n'existe pas
west update             # seulement la première fois
west build -b nrf52840dk_nrf52840 -p always app
```

Pour la carte custom, remplacer le board :

```bash
west build -b stroke_sensor -p always app
```

Sortie utile : `build/zephyr/zephyr.hex` et, si MCUboot est activé, `build/zephyr/app_update.bin` (le fichier à envoyer en BLE DFU).

Build signé DFU (une fois MCUboot dans le projet) :

```bash
west build -b stroke_sensor -p always app -- -DCONFIG_BOOTLOADER_MCUBOOT=y
```

La clé de signature de dev est dans le repo firmware. Ne pas réutiliser la clé d'exemple Nordic en production.

---

## 8. Premier flash (puce vide)

1. Strap **SWD SEL** sur le DK (VDD P1 → SWD SEL P20).
2. Relier SWDIO, SWCLK, GND, VDD.
3. Capteur alimenté (LED DK ou 3,3 V mesuré au multimètre).
4. Programmer → le device listé doit être la cible externe. Si le DK se programme lui-même, le strap SWD SEL est absent.
5. Flash :

```bash
west flash
```

ou dans nRF Connect Programmer : Add file → `zephyr.hex` → Write.

6. Débrancher SWD. Le capteur doit être visible en BLE (nom à figer, ex. `DataR0w Stroke`).

Si la puce est verrouillée (APPROTECT) :

```bash
nrfutil device recover
```

Puis re-flasher. `recover` efface toute la flash.

---

## 9. Mise à jour après coup (sans ouvrir le clip)

Condition : le premier flash a installé **MCUboot** + l'application avec le transport BLE DFU.

1. Build → récupérer `app_update.bin` (paquet signé).
2. Sur le téléphone : **nRF Connect Device Manager** (ou nRF Connect for Mobile, selon le transport SMP).
3. Connexion au capteur, mode DFU (bouton SW1 maintenu 3 s, à figer dans le firmware), envoi du bin.
4. Le bootloader vérifie la signature, swap, reboot. L'ancienne image reste en slot secondaire jusqu'au confirm.

Si la nouvelle image ne boote pas, MCUboot revient à l'ancienne. Si les deux slots sont morts, retour au flash SWD (section 8).

Limite : on ne peut pas changer le bootloader lui-même en BLE sans un design double-banque explicite. Les mises à jour courantes (détection de coup, seuils, protocole) passent en BLE. Un changement de bootloader = SWD.

---

## 10. Ordre de travail réel

1. Acheter le nRF52840 DK.
2. Faire clignoter la LED du DK (sanity check toolchain).
3. Brancher un BMI323, lire acc/gyro en série RTT.
4. Ajouter le service BLE `0xA000` et vérifier les 12 octets dans nRF Connect mobile.
5. Ajouter MCUboot, faire une mise à jour BLE sur le DK.
6. Porter sur le PCB custom, premier flash SWD, puis DFU seulement.
7. Potting **après** le premier flash validé. Les pads SWD restent accessibles (fenêtre ou pastilles non recouvertes) pour le secours.

---

## 11. Pièges

- Flasher en croyant que l'USB-C du capteur est un port de données. Il ne l'est pas sur le QFAA.
- Oublier SWD SEL : on écrit dans le DK.
- Alimenter le SWD en 5 V. Le nRF52840-QFAA accepte 1,7–3,6 V.
- Potter avant le premier flash réussi.
- Perdre la clé de signature DFU : plus aucune mise à jour BLE possible sur les cartes déjà parties.
- Recharge LiPo sous 0 °C : le firmware doit refuser, le NTC doit couper.

---

*Guideline générée le 1er octobre 2026. À mettre à jour quand le repo `datar0w-firmware` existe.*
