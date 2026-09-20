# Point J — Profil rameur : objets connectés + constantes physiques par session

> **Statut** : cadrage figé. À coder après H1–H3 (architecture) et R1 (capteur dorsal).  
> **Dépend de** : Point I (identité), Point R (cardio BLE), Point H (Riverpod + repositories).  
> **Ne pas coder avant** : H1–H3 mergés.

---

## 1. Objectif

Une fois le setup de base fait (identité, taille, poids, côté, pelles), le rameur **connecte ses objets connectés** (patch dorsal maison, sangle pectorale, brassard, montre) et retrouve **toutes ses constantes physiques** — FC, SpO2, température, orientation, HRV — **par session**, récupérables et comparables dans le temps.

L'app devient le **carnet de bord physiologique** du rameur, pas juste un logger de gîte.

---

## 2. Benchmark marché (sourcé, sept 2026)

On ne réinvente pas l'UI. On pompe les patterns des apps les plus abouties, puis on les adapte à la vision DataR0w (aviron + capteur dorsal + multi-coach).

### 2.1 Apps aviron / outdoor (les plus avancées)

| App | Note | Forces UI à pomper | Faiblesses à éviter |
|---|---|---|---|
| **CrewNerd** | 4.6 (257 avis) | Écrans flexibles, graphiques post-séance, export Strava, multi-bateau | UI datée, splits incohérents en sprint |
| **ErgData** (Concept2) | 4.7 (5.1k avis) | Zones FC claires, configs d'affichage multiples, Real Time Loop | Indoor only, pas d'eau |
| **Rowlytics** | récent | Stroke-by-stroke, overlay FC sur timeline, cartes colorées vitesse | Android only, pas de BLE capteur maison |
| **asensei rowing** | 4.8 (4k avis) | Programmes guidés, sync Logbook | Payant, indoor |
| **CrewSpeed** | — | Audio + transcription cox, lineups | Focus cox, pas rameur |

### 2.2 Apps sport / profil perso (les plus abouties, meilleurs retours)

| App | Forces UI à pomper | Pourquoi c'est la référence |
|---|---|---|
| **Garmin Connect** | Training Readiness, Body Battery, HRV, load, historique multi-années, widgets personnalisables | Le plus profond gratuitement. Le rameur veut *ça* pour l'aviron. |
| **WHOOP** | Recovery Score 0–100, Strain, journal comportemental, boucle quotidienne | La boucle « récupération → effort → récupération » est addictive et claire. |
| **Oura** | Readiness, sommeil, température, tendance maladie | Silencieux, non intrusif, excellent pour le repos. |
| **Strava** | Segments, heatmaps, kudos, feed social | La couche sociale / compétition. À garder légère (pas de réseau social lourd). |
| **TrainingPeaks** | Plans structurés, zones, TSS/IF | Pour les compétiteurs qui suivent un plan. |

### 2.3 Ce qu'on pompe (patterns UI, pas le code)

- **Garmin** : écran « Readiness » du matin (score 0–100 + 3 sous-métriques), historique en courbes empilées, widgets redimensionnables.
- **WHOOP** : boucle Recovery → Strain → Sleep, journal taggé (sommeil, hydratation, fatigue), tendance 7/28 jours.
- **Oura** : tendance température corporelle, détection repos vs effort.
- **CrewNerd / Rowlytics** : overlay FC + SPM + vitesse sur une timeline unique post-séance, splits 500 m.
- **ErgData** : presets d'affichage (sécurité / perf / cardio), mémorisés par profil.

**On n'importe PAS** : le social Strava lourd, les abonnements, le lock-in Concept2, les pubs.

---

## 3. Modèle de données (à ajouter à `lib/identity/`)

```dart
class ConnectedDevice {
  String id;            // UUID local
  String rowerId;
  DeviceType type;      // patchDorsal | chestStrap | armBand | watch | other
  String name;          // « Patch dorsal #3 », « Polar H10 »
  String? bleId;        // adresse MAC / UUID BLE
  bool isPrimary;       // capteur principal de la séance
  DateTime pairedAt;
  DateTime? lastSeenAt;
  BatteryLevel? lastBattery; // % si exposé par le device
}

enum DeviceType { patchDorsal, chestStrap, armBand, watch, other }

class SessionPhysio {
  String sessionId;
  String rowerId;
  DateTime startedAt;
  DateTime endedAt;
  // Constantes instantanées (buffer jsonl → sync)
  List<PhysioSample> samples;   // 1 Hz : hrBpm, spo2Pct, skinTempC, hrDerived, patchRoll/Pitch/YawDeg
  // Résumé par session
  double? avgHr; double? maxHr; double? minHr;
  double? avgSpo2; double? minSpo2;
  double? avgSkinTemp; double? maxSkinTemp;
  double? hrRestingBaseline;     // FC repos du matin (si saisie)
  double? hrvRmssd;              // dérivé du patch (optionnel)
  double? readinessScore;        // 0–100, calculé (WHOOP-like)
  String? deviceIdPrimary;
  Map<String, dynamic> extras;   // libre : hydratation, sommeil, notes
}

class PhysioSample {
  DateTime t;
  int? hrBpm;
  double? spo2Pct;
  double? skinTempC;
  double? patchRollDeg;   // orientation torse (point capteur dorsal)
  double? patchPitchDeg;
  double? patchYawDeg;
  double? hrDerivedRr;    // intervalle RR si exposé
}
```

Règle : **une session = un `SessionPhysio`**, lié au `sessionId` existant (gîte / V sol / distance). Le jsonl reste le buffer ; `SessionPhysio` est la vue agrégée persistée.

---

## 4. Fonctionnalités (ordre de build)

### J1 — Connexion objets connectés (sans écran métier lourd)
- Scan BLE des devices compatibles (profil GATT 0x180D Heart Rate + custom patch dorsal).
- Appairage → `ConnectedDevice` stocké localement.
- Indicateur batterie si exposé.
- Tests : round-trip JSON, rejet device non conforme.
- **Commit** : `feat(datar0w): connected devices model + BLE scan`

### J2 — Écran « Mes objets » (dans le profil rameur)
- Liste des devices appairés, statut (connecté / hors portée / batterie).
- CTA « + Connecter un appareil » → scan.
- Possibilité de désigner le device **primaire** de la séance.
- Lien vers le point R (patch dorsal) : si aucun device, bandeau « Connecte ton patch dorsal pour débloquer la FC ».
- **DA** : Deck (#0B0E12 / #E8C547), pas de jargon technique.
- **Commit** : `feat(datar0w): rower devices screen`

### J3 — Capture des constantes pendant la séance
- Pendant `/live`, si un device primaire est connecté : écrire `PhysioSample` 1 Hz dans le buffer (en plus du gîte / V sol).
- Si patch dorsal : orientation torse (roll/pitch/yaw) → utile pour croiser avec le gîte bateau (point capteur).
- Si sangle/brassard : FC + SpO2 + température.
- Fallback : si aucun device, la séance reste valide (gîte seul), comme aujourd'hui.
- **Commit** : `feat(datar0w): physio samples during live session`

### J4 — Tableau de bord « Mes constantes » (post-séance + historique)
- Écran `/physio` (accessible depuis le profil rameur ou le quai) : 
  - **Readiness du jour** (score 0–100, style WHOOP/Garmin) : FC repos, HRV, tendance 7 jours.
  - **Courbe FC** de la dernière séance, overlay SPM + vitesse (style Rowlytics).
  - **Splits 500 m** avec FC moyenne par split.
  - **Tendance** : FC moyenne, SpO2 min, température — 7 / 28 jours.
  - **Comparaison** : séance vs séance précédente, vs moyenne 4 semaines.
- Presets d'affichage mémorisés par profil (sécurité / perf / cardio) — pompé ErgData.
- **Commit** : `feat(datar0w): physio dashboard + history`

### J5 — Sync + export
- `SessionPhysio` suit le buffer jsonl → sync Supabase (point B).
- Export CSV / `.fit` (Garmin-compatible) pour qui veut pousser vers Strava / TrainingPeaks.
- Opt-in : partage des constantes avec le coach (pas les données brutes par défaut).
- **Commit** : `feat(datar0w): physio sync + export`

---

## 5. UI — patterns pompés (à figer en Stitch si besoin)

**Écran Readiness (matin)** — pompé Garmin/WHOOP :
- Score 0–100 en grand, couleur (vert > 70, ambre 40–70, rouge < 40).
- 3 sous-métriques : FC repos, HRV, tendance température.
- Lien « Pourquoi ce score ? » → détail.

**Écran séance** — pompé Rowlytics/CrewNerd :
- Timeline unique : FC (ligne), SPM (barres), vitesse (aire).
- Splits 500 m en cartes horizontales scrollables.
- Chip device utilisé (« Patch dorsal #3 · 87 % »).

**Écran tendance** — pompé Garmin :
- Courbes empilées 7 / 28 jours.
- Comparaison « cette semaine vs semaine dernière ».
- Pas de social, pas de feed.

---

## 6. Hors scope (volontaire)

- Pas de plan d'entraînement auto (TrainingPeaks) au MVP.
- Pas de réseau social / segments (Strava) — juste export.
- Pas de sommeil / nutrition détaillée (Oura/WHOOP) — juste tags libres.
- Pas de verrouillage d'abonnement.
- Pas de scraping de données tierces (Garmin/Oura API) au MVP — on lit nos propres devices BLE.

---

## 7. Prompt Cursor (J1 → J5)

```
DataR0w — Point J : profil rameur + objets connectés + constantes physiques.
Lis docs/CADRAGE-PROFIL-RAMEUR-PHYSIO.md, docs/CADRAGE-ARCHITECTURE.md,
    docs/CADRAGE-CARDIO-BLE-RAMEUR.md, docs/CADRAGE-CAPTEUR-PATCH-DORSAL-OPEN.md.

Ne pas toucher AvSim. Ne pas revert compileSdk 37 / NDK 30.
Pas de sdkmanager. Pas de windows/. H1–H3 (Riverpod + repos) déjà mergés.

## J1 — modèle + BLE scan (aucun écran)
lib/identity/devices.dart : ConnectedDevice, DeviceType, store local.
Scan BLE : profil 0x180D (Heart Rate) + custom patch dorsal (point R).
Tests : round-trip, rejet non conforme.
Commit : feat(datar0w): connected devices model + BLE scan

## J2 — écran « Mes objets » (dans profil rameur)
Liste devices, statut, batterie, CTA connecter, device primaire.
Bandeau si aucun device : « Connecte ton patch dorsal ».
DA Deck. Commit : feat(datar0w): rower devices screen

## J3 — capture pendant /live
Si device primaire connecté : PhysioSample 1 Hz dans le buffer
(hrBpm, spo2Pct, skinTempC, patchRoll/Pitch/YawDeg).
Sinon : séance valide sans physio (rétro-compat).
Commit : feat(datar0w): physio samples during live session

## J4 — tableau de bord « Mes constantes »
/physio : Readiness 0–100, courbe FC + SPM + vitesse, splits 500 m,
tendance 7/28 j, comparaison. Presets mémorisés.
Commit : feat(datar0w): physio dashboard + history

## J5 — sync + export
SessionPhysio → buffer jsonl → Supabase (point B).
Export CSV / .fit. Opt-in partage coach.
Commit : feat(datar0w): physio sync + export

flutter analyze clean. Tests J1 verts.
Un commit par lot J1…J5.
```

---

## 8. Décisions figées

1. **Readiness 0–100** calculé localement (FC repos + HRV + tendance), pas imposé par un tiers.
2. **Device primaire** : un seul par séance, choisi par le rameur.
3. **Opt-in coach** : les constantes ne sont pas partagées par défaut.
4. **Pas de scraping** Garmin/Oura/WHOOP au MVP — on lit nos devices BLE uniquement.
5. **Export .fit** pour compatibilité Strava / TrainingPeaks, sans lock-in.

---

*Point J — 20 sept 2026. Suite logique de I (identité) + R (cardio) + H (archi).*
