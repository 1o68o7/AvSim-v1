# DataR0w — cadrage fonctions × capteurs × profils

*Audit au commit `2e1e15d` / `main` (17 sept. 2026). Hub = smartphone au cale-pied, 1x.*

Légende intégration : **OK** code + permission + affichage ou fichier · **PART** code incomplet ou capteur lu mais pas exposé · **NO** prévu MVP, pas branché · **HORS** hors contrat (ne pas compter comme manque).

Réf. affichage gîte : gauche écran = **TRIBORD** `#46C275` · droite = **BÂBORD** `#E05353` · `+` = tribords. Voir `docs/CONVENTION-BABORD-TRIBORD.md`.

---

## 1. Capteurs téléphone — inventaire

| Source | Permission | Package | Contrat MVP | Intégré |
|---|---|---|---|---|
| GNSS (lat, lon, alt, SOG, COG, acc_h) | Localisation when-in-use | `geolocator` | Oui — V sol, distance, carte | **OK** |
| Localisation arrière-plan | Background location | — | Séance écran verrouillé | **NO** (demandée « plus tard » dans `permissions.dart`) |
| Accéléromètre | Motion / sensors | `sensors_plus` | Fusion gîte + imu.jsonl | **OK** (fusion) |
| Gyroscope | Motion | `sensors_plus` | Fusion gîte τ≈0,32 s | **OK** |
| Magnétomètre | Motion | `sensors_plus` | Cap capteur vs COG | **NO** |
| Attitude / roll lissé | dérivé | `imu.dart` + `heel.dart` | Gîte live 12,5 Hz, deadband ±0,15° | **OK** |
| Baromètre | capteur | — | Alt relative log | **NO** |
| Batterie | — | `battery_plus` | Pastille % | **OK** |
| Réseau (Wi-Fi / cell / none) | — | `connectivity_plus` | Chip 4G / hors ligne | **OK** |
| Horloge | — | Dart | `t` échantillon | **OK** |
| Écran allumé (wakelock) | — | — | Cale-pied lisible | **NO** (`wakelock_plus` absent du pubspec) |
| BLE force / angle aviron | Bluetooth | — | Stub `— aucun` | **HORS** MVP (pas de capteur maison) |
| Micro / caméra / FC | — | — | Interdit | **HORS** |

Fichier séance (`Documents/sessions/{id}/`) :

| Fichier | Contenu | Intégré |
|---|---|---|
| `meta.json` | tareOffsetDeg, code, classe, début | **OK** |
| `samples.jsonl` | 1 Hz UI / carte | **OK** |
| `imu.jsonl` | brut pendant séance | **OK** |
| `notes.json` | annotations coach | **PART** (modèle + écran 5 ANNOTER à vérifier sur device) |

Logger 1 Hz **uniquement** Démarrer → STOP.

---

## 2. Fonctions par écran × profil × capteurs

### Profil RAMEUR (tél. au cale-pied)

| # | Fonction | Capteurs nécessaires | Intégré |
|---|---|---|---|
| 1 | Choisir profil Rameur | aucun | **OK** |
| 2A | Config 1x + bassin texte + état GPS/IMU/BLE | lecture permission GPS/IMU (BLE affiché `—`) | **PART** (BLE toujours aucun ; classe 1x figée visuellement) |
| 2B | Tare gîte 30 s, σ < 0,2°, Démarrer off sinon | IMU live lissé | **OK** code |
| 2B | Affichage TRIBORD gauche / BÂBORD droite | IMU | **OK** code |
| 3 | Live paysage : V sol, distance, gîte, cadence `—`, pastilles GPS/IMU/réseau/batt | GNSS + IMU + batt + net | **OK** code |
| 4 | Bandeau rouge trop bâbord / vert trop tribords si \|gîte\| > 3° | IMU après tare | **OK** code |
| 3/4 | STOP 2× / 3 s → coupe logger | — | **OK** code |
| 3 | Écran reste allumé au cale-pied | wakelock | **NO** |
| 3 | GPS continue écran off | background location + FGS Android | **NO** |
| 7 | Quai : durée, km, cadence moy. ou `—`, gîte RMS, chip réseau | fichier local | **OK** code |
| 7 | Partager jsonl + meta | `share_plus` | **OK** code |
| 6r | Replay carte + V/distance au curseur + 2 courbes | fichier (pas de capteur live) | **OK** code |
| — | Cadence SPM fiable | accéléro pics **ou** BLE | **NO** volontaire (`null`) |

### Profil COACH (berge / canot / même tel)

| # | Fonction | Capteurs nécessaires | Intégré |
|---|---|---|---|
| 1 | Entrer profil Coach | aucun | **OK** |
| Join | Code 6 car. ou « dernière séance » | aucun (local) | **OK** mode local |
| 5 | Carte + point bateau + V sol + distance + gîte + ANNOTER | *sur le tel rameur* : GNSS+IMU ; *tel coach* : réseau si live | **PART** — live 2e tel = Lot G (`DATAROW_API_BASE` vide ⇒ local seulement) |
| 5 | Même signe gîte que le rameur | dérivé fichier / hub | **OK** code |
| 6 | Replay 2 courbes + carte + playhead | fichier | **OK** code |
| G | Tick 1 Hz vers API + poll coach | connectivité 4G/Wi-Fi | **PART** client stub, routes FastAPI absentes |

Le téléphone **coach** n’a pas besoin d’IMU/GPS pour le MVP local. Il a besoin du **fichier** ou, plus tard, du **réseau**.

### Profil BARREUR

| Fonction | Capteurs | Intégré |
|---|---|---|
| UI + lock 1x | — | **OK** (grise + « bateau barré ») |
| Cadence / gîte collective 4+/8+ | GNSS+IMU du bateau + profil | **HORS** 1x |

---

## 3. Matrice condensée (ce que le tel rameur doit ouvrir)

| Grandeur affichée | Capteur | Rameur | Coach | Barreur 1x |
|---|---|---|---|---|
| V sol | GNSS SOG | OK | OK (fichier / live) | — |
| Distance | GNSS haversine | OK | OK | — |
| Trace carte | GNSS lat/lon | 6r only | 5 + 6 | — |
| Gîte | gyro+acc − tare | OK | OK même signe | — |
| Alertes 2 côtés | gîte lissée | OK | via 5 | — |
| Cadence | IMU ou BLE | `—` | `—` | HORS |
| Batterie / réseau | batt + connectivity | OK | chip | — |
| Code séance | — | affiché Démarrer | saisie join | — |

---

## 4. Verdict audit

**Couvert pour une séance 1x un téléphone :** profils, tare, live gîte lissée + invert + alertes 2 côtés, V sol, distance, STOP, quai, replay carte, partage, join coach local, pins Android.

**Manques capteur / plateforme (vrais) :**

1. Wakelock — écran peut s’éteindre au cale-pied.  
2. GPS background / foreground service — trace coupée si l’OS endort l’app.  
3. Magnéto + baro — logués nulle part.  
4. Cadence — volontairement vide.  
5. Live coach 2e appareil — client HTTP prêt, serveur `/datarow/*` non.  
6. GeoJSON bassin — carte sans bornage.

**Pas des manques :** watts, RTK, vitesse eau, micro, caméra, Barreur 4+, moteur AvSim, Windows desktop.

---

## 5. Checklist device (OnePlus `2e1e15d`)

- [ ] Dialogues Localisation + capteurs ; refus 2A sans crash  
- [ ] 2B : chiffre stable à quai, suit une inclinaison ~0,4 s  
- [ ] Tare 30 s → Démarrer s’active  
- [ ] Gauche vert / droite rouge ; bandeaux des deux bords > 3°  
- [ ] Marche 200 m : SOG et km avancent ; label `sol — pas eau`  
- [ ] STOP 2× → 7 → Replay montre le trait  
- [ ] Coach « dernière séance » relit le même fichier  
- [ ] Écran qui s’éteint ou pas (wakelock) — noter le trou  
