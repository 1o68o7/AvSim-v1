# MVP club — brief Stitch

*16 septembre 2026 · pack d'écrans à produire.  
Complète `STATE.md` (physique) et `docs/ETAT-DATAROW.md` (chantiers).  
Ceci n'est **pas** l'UI Analyste ni l'aide à l'achat capteurs.*

DA **verrouillée** le 16/09 : instrument cockpit paysage 3 colonnes (maquette validée).  
Prompt de correction Stitch : `docs/STITCH-PROMPT-CORRECTION.md`.  
Le projet Stitch portrait `1264451048753434333` n'est **pas** la référence.

---

## 0. Produit en une phrase

Application native (iOS + Android) : le smartphone du bateau est le **concentrateur**. Il affiche les instruments au rameur, agrège GPS / IMU / BLE, et pousse un flux 4G/5G vers le coach. Personne ne voit tout.

Nom de travail à l'écran : **DataR0w** (pas « AvSim », pas « Analyste »).

---

## 1. Décisions figées

| Sujet | Décision |
|---|---|
| Premier bateau | **1x (skiff)** |
| Autres classes | Mêmes écrans ; schéma 2 / 4 / 8 cases + profil Barreur si bateau barré |
| Fixation | Support au **cale-pied**, ou au **portant** s'il passe au-dessus. Téléphone **paysage**, axe long // axe bateau |
| Niveau | Support réglé mécaniquement à l'horizontale. L'app fait une **tare gîte à quai**, pas un offset inventé à chaque coup |
| Coach live | **4G/5G** bateau → cloud → téléphone coach. Trou réseau = log local, sync à quai |
| Stack UI | Native iOS + Android (Flutter par défaut si non tranché) |
| DA | Cockpit instrument, fond `#0B0E12`, 3 colonnes, **pas** Material / fitness |
| Aide à l'achat capteurs | Outil **maison**, hors ce pack |

---

## 2. Deux surfaces mentales

| Surface | Public | Dans Stitch ? |
|---|---|---|
| **Club** | Rameur, Barreur, Coach | **Oui** |
| **Maison** | Analyste, Pareto capteurs, YAML | **Non** |

---

## 3. Profils — qui voit quoi

Session unique. Trois fenêtres.

### 3.1 Rameur (1x, paysage, 80 cm, soleil)

**Afficher**

- Gros : cadence (coups/min), vitesse GPS, distance **ou** temps (un seul des deux en gros)
- Moyen : **gîte** (horizon artificiel / bille, axe bateau) — libellé `GÎTE`, jamais « inclinaison talon »
- Petit : état capteurs (OK / perdu), batterie téléphone, pastille réseau (4G / hors ligne)

**Ne jamais afficher au rameur**

- Watts, η palette, check_factor, slip, Mode C, YAML
- Force / angle des autres postes
- Liste d'annotations coach
- Plus d'une alerte à la fois

**Feedback** : un seul motif — gîte hors bande **ou** rupture de cadence. Pas les deux.

Légende obligatoire sous la vitesse : `sol — pas eau` (GPS ≠ vitesse surface).

### 3.2 Barreur (4+ / 8+ seulement — écran prêt, profil grise sur 1x)

**Afficher** : même socle + schéma postes (qui décroche) + cap / dérive + dernière consigne coach (une ligne).

**Ne pas afficher** : courbe de force du barreur.

### 3.3 Coach (canot / rive, portrait acceptable, paysage préféré)

**Live** : carte + cadence équipage + 3 alertes max + bouton **Annoter** (1 tap = timestamp).

**Replay quai** : timeline + **2 courbes max** + liste annotations. Écarts bruts seulement. Pas de seuil inventé (« bon / mauvais »).

**Ne pas afficher** : réglage physique, Observabilité, badges labo.

Consigne **vers** le rameur pendant le live : **hors MVP**.

---

## 4. Les 7 écrans à dessiner

Orientation **paysage 844×390** pour 3, 4, 5. Portrait OK pour 1, 2, 6, 7 **seulement si** la DA reste cockpit (pas de retour Material).

### Écran 1 — Entrée / profil

- Logo DataR0w
- Trois rangées plates (pas de cartes élevées) : **Rameur** | **Coach** | **Barreur**
- Barreur **grisé** + `besoin d'un bateau barré` tant que classe = 1x
- Pas de sélecteur Analyste

### Écran 2 — Pré-session

- Classe : `1x` sélectionné
- Bassin (texte libre v1)
- Capteurs : `GPS` `IMU` + BLE `— aucun`
- **Tare gîte (30 s)** — bateau à quai, coque calée
- État tare : `non faite` / `OK ±0,2°`
- CTA : **Démarrer la session**

### Écran 3 — Rameur live (paysage) — écran roi · DA validée

Trois colonnes, pas de scroll.

```
┌───────────────┬────────────┬───────────┐
│  28                 │   GÎTE         │  ● GPS  │
│  coups/min          │   [horizon]    │  ● IMU  │
│  4.2                │   ±3°          │  4G     │
│  m/s sol — pas eau  │   +1.4° trib.  │  62%    │
│  1.24 km            │                │  STOP   │
└───────────────┴────────────┴───────────┘
```

### Écran 4 — Rameur alerte

Même layout. Bandeau haut `#E8C547` : `GÎTE — trop tribords` **ou** `Cadence — rupture`. Une seule cause.

### Écran 5 — Coach live

- Gauche 60 % : carte sombre, une trace GPS
- Droite : cadence, V sol, gîte, chip `live` / `retard` / `hors ligne`
- Bas : **ANNOTER**
- Pas de « envoyer au bateau »

### Écran 6 — Coach replay

Timeline + 2 courbes max (cadence | V sol | gîte) + annotations. Écarts bruts seulement.

### Écran 7 — Quai

Durée, distance GPS, cadence moyenne, gîte RMS. Sync. Partage coach.

---

## 5. Extension autres bateaux

Mêmes 7 écrans. Schéma 2 / 8 cases seulement si `n_rowers > 1`. Barreur si `4+` / `8+`.

---

## 6. Capteurs — ce que l'UI a le droit de montrer

| Source | MVP 1x | Badge |
|---|---|---|
| GPS téléphone | oui | Mesuré |
| IMU téléphone (gîte, cadence approx.) | oui | Mesuré |
| BLE force / angle | slot vide | — |
| Modèle physique AvSim | **interdit** sur Club | Maison seulement |

Cadence IMU ≠ catch slip. Ne pas étiqueter « slip ».

---

## 7. Ton visuel — figé

| Token | Valeur |
|---|---|
| Fond | `#0B0E12` |
| Chiffres | blanc, tabular |
| Labels | `#9AA0A6`, 11 px |
| Filets | `#2A2F36` |
| Alerte | `#E8C547` |
| Canvas live | **844 × 390** |

Interdit : cartes Material, ombres, blur, violet, teal, tab bar, hamburger.
Référence : cockpit / horizon, pas Strava.

---

## 8. Hors scope Stitch

Analyste, Pareto, YAML, haptique Coup+1, LoRa, 3D, paiement.

---

## 9. Prompts

- Pack initial (périmé pour la DA) : ne plus coller le bloc court « 7 écrans » sans contrainte canvas.
- **Correction à coller maintenant** : `docs/STITCH-PROMPT-CORRECTION.md`

---

## 10. Lien repo

| Fichier | Rôle |
|---|---|
| `docs/STITCH-PROMPT-CORRECTION.md` | Prompt de correction DA — source à coller |
| `STATE.md` | Vérité physique simulateur |
| `docs/ETAT-DATAROW.md` | Trois chantiers |
| `web/` | Prototype desktop — ne pas cloner |
