# DataR0w — cadrage fonctions × capteurs × profils

*Mis à jour lot G / coach / classes (sept. 2026). Hub = un smartphone (une place).*

Légende : **OK** · **PART** · **NO** · **HORS**.

Réf. gîte : gauche écran = **TRIBORD** `#46C275` · droite = **BÂBORD** `#E05353` · `+` = tribords. Voir `docs/CONVENTION-BABORD-TRIBORD.md`.

---

## 1. Capteurs téléphone

| Source | Permission | Package | Contrat MVP | Intégré |
|---|---|---|---|---|
| GNSS | when-in-use puis background | `geolocator` | V sol, distance, carte | **OK** |
| Localisation arrière-plan | background | FGS location | écran verrouillé | **OK** |
| Accéléro / gyro | Motion | `sensors_plus` | gîte τ≈0,32 s + imu.jsonl | **OK** |
| Magnétomètre | Motion | `sensors_plus` | `hdg_mag` | **OK** (fichier) |
| Baromètre | capteur | `sensors_plus` `barometerEventStream` | `p_hpa` / `alt_baro` | **OK** (null si absent) |
| Batterie / réseau | — | `battery_plus` / `connectivity_plus` | pastilles | **OK** |
| Wakelock | — | `wakelock_plus` | cale-pied allumé | **OK** |
| FGS | notification | `flutter_foreground_task` 11 | « DataR0w — séance » | **OK** |
| BLE / micro / caméra | — | — | interdit / hors | **HORS** |

**Retiré :** `environment_sensors` (jcenter, casse AGP 9). Ne pas le réintroduire.

Fichiers séance `Documents/sessions/{id}/` : `meta.json` (class, seats, cox, role, seatIndex), `samples.jsonl` 1 Hz Démarrer→STOP, `imu.jsonl`, `notes.json`.

Distance = haversine si `acc_h < 25 m`, pas d’interpolation. Cadence `—` sauf 6 coups stables (`estim. tel`).

---

## 2. Profils × classes

Classes produit : `1x` `2x` `2-` `4x` `4-` `4+` `8+` (sélecteur 2A **actif**). Physique AvSim **non** touchée.

- 1x : un tel au cale-pied (inchangé).
- 2x / 2- / 4- / 4x : même live rameur + chip siège n/n. Autres places en attente (API) ou ignorées (local).
- 4+ / 8+ : profil Barreur. Écran paysage réduit (V sol, distance, gîte bateau). Pas de SPM inventé. Pas de jauge par siège à un seul tél.
- Coach : class + sièges déclarés ; live = flux du tel qui logge.
- MVP local = **un logger à la fois**. Un smartphone = un hub ; multi-sièges = plusieurs tél. + API.

### Rameur

Tare, live gîte lissée, alertes 2 côtés, V sol (`sol — pas eau`), STOP, quai, replay 6r sans colonne évaluation.

### Coach

Join : code, dernière séance locale, **séance live** si `DATAROW_API_BASE`. Écran 5 : OSM (pas de couloirs FISA sans GeoJSON), point lat/lon, V, distance, gîte même signe, chip `réf. rameur`, ANNOTER → `notes.json` + POST notes. Replay 6 : fichier importé ou dernière séance, 2 courbes, playhead.

### Barreur

Dégrisé. 2A impose 4+ / 8+. IMU du tel bateau, sinon poll API.

---

## 3. API optionnelle (`/datarow/*`)

Préfixe à côté des routes AvSim, **sans OAuth**. Si `DATAROW_API_BASE` vide : comportement local (fichier + join même tél.). Échec HTTP ≠ stop logger.

`POST /sessions` → `{id, code}` 6 car. expire 12 h · `POST .../tick` · `GET .../by-code/{code}` · `GET .../live` · `POST .../notes` · `GET .../export`.

---

## 4. Hors cadrage

Watts, RTK, 10 Hz GNSS affiché, V eau, High-Vis cyan, micro, caméra, podomètre, Windows desktop, moteur AvSim.
