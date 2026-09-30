# Prompt Cursor — firmware stroke sensor (nRF52840)

> **Statut** : prompt prêt à coller. Lot S4 du cadrage `docs/CADRAGE-STROKE-SENSOR-DIY.md`.
> **Repo cible** : `1o68o7/AvSim-v1` (dossier `firmware/stroke/`) ou repo séparé `AvSim-stroke` si on veut isoler le firmware.
> **Date** : 2026-09-30

---

## Prompt

```
Stroke sensor firmware — nRF52840 (lot S4).
Lis docs/CADRAGE-STROKE-SENSOR-DIY.md (protocole v0.1, §3) et
docs/CONVENTION-BABORD-TRIBORD.md.
Repo : dossier firmware/stroke/ (créer si absent). Ne pas toucher apps/datar0w,
AvSim, sync, secrets.

## Objectif
Firmware complet pour le capteur stroke DIY :
- nRF52840 (SoftDevice S140, BLE 5 central+peripheral)
- BMI323 en I2C (addr 0x68) : acc ±8 g 16 bits @ 200 Hz + gyro ±500 °/s @ 200 Hz
- Détection de coup : seuil SEUIL_MG (paramètre, défaut 2000) + fenêtre
  réfractaire 800 ms
- Paquet BLE 12 octets (voir protocole §3.2) envoyé en notify sur char 0xA001
- Gîte : moyenne gyro z sur 200 ms autour du pic (signe bâbord-)
- Veille : 0.4 µA entre les coups (nRF52840 System OFF + RTC wake)
- Batterie CR2032 : lecture ADC sur VDD, % dans le paquet
- OTA : DFU via BLE (Nordic) pour mises à jour firmware

## Lots (1 commit chacun)

F1 — projet nRF Connect SDK (CMake + Kconfig) + init I2C BMI323 + lecture
   acc/gyro brute. Test : print valeurs toutes les 100 ms.
   Commit : feat(stroke): nrf52840 project + bmi323 i2c driver

F2 — détection de coup (seuil + réfractaire) + compteur + gîte.
   Test unitaire sur PC : série ax synthétique → coups détectés aux bons t.
   Commit : feat(stroke): stroke detection + gite estimate

F3 — BLE peripheral : service 0xA000, char 0xA001 (notify 12 octets),
   char 0x2A19 (battery), advertising nom "DataR0w-Stroke".
   Test : nRF Connect scan → service visible, paquet parsable.
   Commit : feat(stroke): ble peripheral + stroke packet notify

F4 — veille 0.4 µA (System OFF + RTC) + wake sur interruption BMI323.
   Test : consommation mesurée (PPK2 si dispo) < 1 µA veille.
   Commit : feat(stroke): ultra-low-power sleep + bmi323 wake

F5 — OTA DFU + version firmware dans device info (0x180A).
   Commit : feat(stroke): ota dfu + device info

## Hors scope

- apps/datar0w (autre lot S1–S3)
- AvSim, sync session_meta, Google OAuth, Stitch, #50, secrets
- PCB layout (autre chantier, après validation F1–F5)

## Git

Branche feat/stroke-firmware depuis origin/main.
PR : feat(stroke): nrf52840 firmware v0.1 — detection, BLE, veille
Hors draft si tests verts.
```

---

## Notes

- Le firmware est en **C** (nRF Connect SDK), pas en Dart. C'est normal : le capteur n'est pas une app Flutter.
- La validation de l'algo (seuil, réfractaire) se fait sur le banc AvSim AVANT de flasher le premier PCB (voir §5 du cadrage).
- Si le nRF52840 n'est pas dispo, fallback ESP32-C3 (même structure, autre SDK).
