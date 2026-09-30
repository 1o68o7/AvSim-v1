# Inventaire Stitch Bassin (direction retenue)

Projet : [`1254927388471488287`](https://stitch.withgoogle.com/projects/1254927388471488287)  
DS : `assets/8677461250639537695` · Tokens : [`DA.md`](./DA.md) · Challenge : [`DA-CHALLENGE-2026.md`](./DA-CHALLENGE-2026.md)

Une planche = un état. **Pas de Flutter.**

## Posées

| Id | État | Screen id | Format |
|---|---|---|---|
| DR-01 | liste 3 profils (pilier) | `cb8c8ae9164a4f2e874c40fe559f9a1d` | portrait |
| DR-01 | vide | `b898970ee0424ecd9843846291c1d2fd` | portrait |
| DR-02 | fiche vide | `a5263904646e4c88968231f205c3356e` | portrait |
| DR-03 | onboarding identité | `3f265fae8d544ee79c7a7eea108bf586` | portrait |
| DR-04 | licence inconnue → loisir | `e88841a220374bcf88708de7d402565f` | portrait |
| DR-10 | Connexion OFF (pilier) | `de251f1a5e214d47b1fa6a5b343e2176` | portrait |
| DR-11 | Connexion ON | `391e417bdd634702869d058cb1482fd3` | portrait |
| DR-12 | Réglages connecté | `96232dced0824ec4951f5105c4f95de0` | portrait |
| DR-20 | affecté (pilier) | `453bd9855d6745fd9f75bd48c9b10e01` | portrait |
| DR-20 | sans affectation | `0cded8b518f2455eb259d8a85ba69902` | portrait |
| DR-21 | barreur affecté 8+ | `eeba19d108f94b929d09c5368589581a` | portrait |
| DR-30 | accueil coach | `1d55126036ea49438a160b62b24eb9d8` | portrait |
| DR-31 | composition 8+ semi | `7c07a177f03541f2ac61a72dc7297659` | portrait |
| DR-32 | join code | `f542211afbb44b4e9318abbae8e25d60` | portrait |
| DR-33 | coach live (pilier) | `e08d021b58c74847946c9e712f6502ee` | paysage |
| DR-34 | séances liste | `a62c7168aa22497b98cfebfbd17881e6` | portrait |
| DR-34 | séances vide | `d8ff79e9906d4a64a03663f7dd92cbe1` | portrait |
| DR-35 | fiche séance cloud | `87afc9475fbb4557924e09e9b12e31db` | portrait |
| DR-40 | accueil admin | `86a2341dbcb14ba0b6e4ec147f90c6cf` | portrait |
| DR-40b | accueil intendant | `7f010e03e04d476dbcc01da67ca5931b` | portrait |
| DR-42 | import cabane | `98282dea12044f0db9ac14e9e4315ddf` | portrait |
| DR-50 | pré-séance 4x (pilier) | `9b65f164e6c042ec8753384198211e16` | portrait |
| DR-51 | tare idle | `9e72f192d065423492f34d0c359aaf42` | portrait |
| DR-51 | tare running | `52a3c131c9514628891bbd6e9b3200eb` | portrait |
| DR-52 | live nominal (pilier) | `148b587626d34495802b73e50a1294a5` | paysage |
| DR-52 | alerte bâbord | `7717ec879d1d4c5c83fef2246a2340da` | paysage |
| DR-52 | compétition quai | `9a850e7400f64810bebce0fe9650e82f` | paysage |
| DR-53 | live barreur nominal | `043827fc79fc494d9c7b758c1b381473` | paysage |
| DR-54 | quai | `42f2f067da5847ba9b403383ca4f7325` | portrait |
| DR-55 | replay rameur | `6fefff567c1f46d5a17bef2bb0d78bc3` | portrait |
| DR-60 | mes séances liste | `6191c071b782477bac6e1c1ce3c0e21e` | portrait |
| DR-61 | mes objets | `9ee09309444a4ec0a4e73de0630e33ab` | portrait |
| DR-62 | consentement santé | `26191fe4ca2840a08d36aab4e07103a0` | portrait |
| DR-63 | physio placeholder | `ac01ad8078b54effb6c6b3e51d24f170` | portrait |
| DR-70 | sortie de parc | `9c8ef2a038ab4aecaf46424eb705180c` | portrait |

## Manques restants

| Id | États manquants |
|---|---|
| DR-01 | erreur nav |
| DR-02 | remplie |
| DR-04 | champ vide / trouvée |
| DR-12 | local only |
| DR-13 | callback erreur auth |
| DR-20 | loisir solo |
| DR-21 | vide |
| DR-31 | semi-rempli / vide *(génération timeout — à reposer)* |
| DR-34 | — (liste + vide OK) |
| DR-41 | fiche club |
| DR-43 | calendrier catalogue |
| DR-44 | fiche événement |
| DR-45 | plans d’eau |
| DR-50 | 1x / 8+ barreur / compétition |
| DR-51 | ready / orientation refusée |
| DR-52 | alerte tribords |
| DR-53 | alerte sens inverse |
| DR-56 | replay coach |
| DR-60 | vide |
| DR-71 | retour de parc |
| DR-72 | départ / alignement |
| DR-73 | maintenance + impact |
| DR-74 | fiche coque |
| DR-80 | spinoscope |
| DR-90 | bandeau sync 36 px (composant) |

## Notes honnêteté (à corriger en edit Stitch)

- DR-32 a inventé « balises UDP » — hors brief, à retirer.
- DR-20/21 Hangar inventaient « Capteurs prêts » ; Bassin à vérifier à l’œil.
- Cadence absente = texte « cadence non mesurée » (OK sur DR-54, DR-35, DR-55).
