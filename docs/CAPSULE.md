# Capsule et bannière de boutique — gabarits et commande

*Item **DA7.1**. Inscrit le 2026-09-09.*

⚠️ **Rien n'est généré, et c'est délibéré.** Les gabarits ci-dessous dépendent
de la boutique, et le choix de boutique est l'un des champs `À TRANCHER` du
[presskit](PRESSKIT.md). Générer une capsule Steam avant de savoir qu'on publie
sur Steam, c'est produire un asset au mauvais rapport de forme et le refaire.
Ce document est donc prêt à exécuter le jour où la boutique est choisie — pas
avant.

## Les gabarits

### Steam

| Emplacement | Taille | Où il apparaît |
|---|---|---|
| Capsule d'en-tête | 460 × 215 | Listes, recommandations, panier |
| Petite capsule | 231 × 87 | Résultats de recherche |
| Capsule principale | 616 × 353 | Mises en avant de la page d'accueil |
| Capsule verticale | 374 × 448 | Encarts éditoriaux |
| Capsule de bibliothèque | 600 × 900 | La bibliothèque du joueur |
| Bandeau de bibliothèque | 1920 × 620 | Haut de la fiche dans la bibliothèque |
| Logo de bibliothèque | 1280 × 720, fond transparent | Superposé au bandeau |
| Fond de page | 1438 × 810 | Derrière la fiche |

### itch.io

| Emplacement | Taille | Note |
|---|---|---|
| Image de couverture | 630 × 500 | Obligatoire, recadrée en vignette |
| Bandeau | 1920 × 620 environ | Facultatif, haut de page |

## La règle qui décide de la composition

**Le wordmark doit rester lisible à 231 × 87.** C'est le plus petit gabarit, et
c'est celui que le plus de gens verront. Une capsule qui ne fonctionne qu'en
grand est une capsule ratée.

Conséquence directe : **la capsule n'est pas une illustration réduite.** Elle se
compose à part — un cône, un wordmark, du noir. La planche 4 de l'intro
(`ill_intro_allumage`) et la planche 5 (`ill_intro_prix`) sont les deux seules
sources dont la composition survive au recadrage, parce que leur sujet occupe
une bande étroite et que tout le reste est noir. **Le noir se recadre ;
un décor ne se recadre pas.**

## Le prompt, si l'on génère

Reprendre **mot pour mot** le bloc invariant de
[INTRO_PLANCHES.md](INTRO_PLANCHES.md) — c'est la seule garantie que la capsule
ne jure pas avec les vingt et une images déjà produites au même procédé — puis :

> Composition en bandeau horizontal, sujet cadré dans le tiers droit, les deux
> tiers gauches en noir d'encre plein réservés à un titre qui sera posé ensuite.
> Un homme de dos, torche allumée, dont le cône traverse le cadre vers la droite
> et révèle une silhouette lointaine. Aucun texte dans l'image.

Le wordmark se pose **après**, au pochoir, sur la zone noire — il ne se génère
pas (décision DA1.5 : « un logo ne se génère pas »).

## Ce qui manque

| Manque | Qui |
|---|---|
| Le choix de boutique | Adrien |
| Le wordmark en fichier séparé, PNG transparent | dérivable de DA1.6 |
| La génération elle-même | une session, une fois la boutique connue |
