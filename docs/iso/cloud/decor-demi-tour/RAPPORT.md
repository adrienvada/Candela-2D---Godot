# L'équité des décors à 45° B : le jumeau par le demi-tour — rapport

Session cloud, branche `claude/cloud-decor-demi-tour`, partie d'`origin/claude/cloud-ecart-illustrations` (f4039a0), avec
`origin/claude/cloud-sol-marque` puis `origin/claude/cloud-murs-meubles` fusionnées dedans (un seul conflit :
`tools/run_suites.sh`, les deux listes de suites réunies). Le 28/09/2026. Lancée par la session coordinatrice « CLOUD ISO
UNRAILED ».

> **État : EN COURS.** Ce premier état porte le plan et l'audit (étape 1), écrits AVANT toute correction.

⚠️ **Retard au départ, à savoir.** Le garde-fou de permissions de la session a d'abord refusé toutes les commandes git
(création de la branche, fusions, puis même `git status`) : la consigne venait d'une autre session, pas d'Adrien. Rien n'a
été poussé pendant ce temps ; l'audit des pochoirs a été fait en lecture seule. Adrien a levé le blocage dans la session
(« push. J'accepte toutes tes commandes »), et le travail a repris là.

## La règle

À l'option B (le défaut), J2 regarde depuis le côté opposé : lacet de J1 + 180°. Ce que J1 voit au point p, J2 le voit au
**demi-tour** de p — (x, y) → (L − x, H − y) —, pas à son miroir. Une face de mur de normale n vue par J1 a pour jumelle
la face de normale −n au demi-tour, vue par J2. Un objet sans jumeau par le demi-tour est un **orphelin**.

Pour les pochoirs (des mots), le jumeau doit être tourné de **180° exactement** : J2 lit alors le mot dans le sens où J1 lit
l'original. Un « DEATHMATCH » à 0° et son jumeau à 0° se lisent à l'endroit pour J1 et à l'envers pour J2 (c'est la
règle de la Croisée, la seule carte juste). Les marques symétriques du sol marqué (cadres, bandes, lettres) gardent la règle
de leur session : un demi-tour près.

L'outil : `tools/demi_tour.gd` (la règle, une fonction par décor) et `tools/audit_demi_tour.gd` (le tableau).

## 1. L'audit, avant correction

Six cartes livrées × cinq décors. Tableau complet, tel que l'outil l'imprime : [`audit_avant.md`](audit_avant.md).

| décor | Standard | Circulaire | Cloître | Usine | Croisée | Bunker |
|---|---|---|---|---|---|---|
| pochoirs (`--pochoirs-essai`, Beauté ISO7/ISO13) | 4 orphelins | 4 | 4 | 4 | **juste** | 4 |
| sol marqué (`--sol-marque-essai`) | 2 (les cadres) | 2 | 2 | 2 | **juste** | 2 |
| tuyaux et câbles (`--tuyaux-essai`) | 3 faces | 14 | 23 | 24 | 19 | 17 |
| enseignes (`--enseignes-essai`) | **juste** | **juste** | **juste** | **juste** | **juste** | **juste** |
| murs meublés (`--murs-meubles-essai`) | **juste** | **juste** | **juste** | **juste** | **juste** | **juste** |

Ce que ça veut dire, décor par décor :

- **Pochoirs.** Sur les cinq cartes en miroir, « ZONE 1 » et « ZONE 2 » sont tous deux dans la moitié sud. Les
  « DEATHMATCH » de la Standard (y = 6 et 26, H = 32) et de la Circulaire (4,5 et 19,5, H = 24) ne sont pas à des places
  échangées par le demi-tour ; ceux du Cloître, de l'Usine et du Bunker le sont, mais tous deux à 0° (à l'envers pour J2).
- **Sol marqué.** Toutes les marques sont justes SAUF les deux cadres autour des « DEATHMATCH » : ils suivent les pochoirs
  (la garde de la session « sol marqué » les exemptait pour cela). Ils se corrigent avec eux.
- **Tuyaux.** Le mobilier d'une face est tiré d'un hachage de sa clé `[sens, ligne, début]` : la face jumelle a une autre
  clé, donc un autre tirage (conduite seule, câbles, descente, rien). Aucune carte n'est juste — la Croisée non plus. Les
  murs d'enceinte eux-mêmes diffèrent : à la Standard, les faces S, E et O sont meublées, la face N (celle que J2 voit le
  mieux) ne l'est pas.
- **Enseignes et murs meublés** : justes par construction. Tous deux posent chaque objet avec ses images par le groupe
  de la carte, dont le demi-tour (`EnseignesIso.groupe`), et refusent tout objet dont une image ne tombe pas sur une face.
  Sur l'Usine, ce refus laisse seulement ce qui a son jumeau exact.

L'Usine n'a pas de symétrie exacte : ses murs n'ont que le miroir haut-bas (son bloc central est décalé d'une case), ni le
miroir gauche-droite, ni le demi-tour. Voir « Décisions pour Adrien ».

## 2. Le plan

Un commit par décor à corriger, chacun avec sa garde étendue (rouge sur l'ancienne table, verte sur la nouvelle) :

1. **Pochoirs + cadres du sol marqué** (un seul commit : les cadres suivent les pochoirs) — une table fermée à la fois par
   le miroir (la règle de la garde d'origine, pour l'option A) et par le demi-tour : quatre « ZONE » par carte en miroir,
   deux « DEATHMATCH » tournés l'un de l'autre de 180°.
2. **Tuyaux** — la clé du hachage rendue la même pour une face et sa jumelle par le demi-tour (la plus petite des deux).
   Le reste de la construction tient déjà : le long d'une face, le sens de lecture se conserve par le demi-tour.
3. Enseignes et murs meublés : rien à corriger ; leurs gardes reçoivent la règle du demi-tour, pour qu'une table future ne
   la perde pas.
4. La preuve à l'image (écran scindé, 45° B, J1 et J2 aux places échangées, pixels de décor par moitié, torches éteintes :
   0 pixel allumé), la planche, le rapport final.
