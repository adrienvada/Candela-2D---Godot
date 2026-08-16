# La boucle — travailler jusqu'à épuisement, puis proposer

> `docs/ROADMAP.md` dit *quoi* et *pourquoi*. `docs/WORKFLOW.md` dit *comment
> paralléliser*. Ce document dit **quand s'arrêter, et quoi faire ensuite**.

## Le problème que cette boucle résout, et celui qu'elle pourrait créer

Une session autonome finit par manquer de travail déclaré. Deux mauvaises issues
guettent alors : s'arrêter en croyant avoir fini alors qu'il reste des chantiers,
ou générer des idées à l'infini jusqu'à noyer le jeu.

Le second risque est le plus sérieux, et il faut le nommer : **la force de
Candela est la lisibilité dans le noir.** Un générateur d'effets qui tourne sans
limite produit un jeu plus chargé, donc moins lisible, donc moins bon — tout en
donnant l'impression d'avancer. La boucle ci-dessous est conçue pour être
*difficile à alimenter*, pas facile.

## Les six temps

### 1. Auditer — mécaniquement, jamais à l'estime

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/audit_reste.gd
```

Code de sortie **2** : il reste du travail implémentable → temps 2.
Code de sortie **0** : plus rien → temps 5.

L'audit compte, il ne juge pas. Il voit quatre choses : les suites de tests
présentes mais non enregistrées dans la CI (déjà arrivé deux fois, et rien ne le
signale), les phases et étapes ouvertes, les décisions en attente d'Adrien, et
les ressources manquantes. Ce qu'il sait voir est étroit, et c'est délibéré : un
audit qui prétend tout voir n'est plus cru.

**Une session ne se déclare jamais terminée sans cette sortie 0.** C'est le seul
garde-fou contre « j'ai l'impression d'avoir fini ».

### 2. Planifier — par fichier, jamais par sujet

Grouper ce qui reste en vagues de travaux **sans fichier commun**. C'est la seule
règle de découpage qui tienne : deux agents sur des sujets différents dans le
même fichier conflictent à chaque poussée. Voir `docs/WORKFLOW.md`.

### 3. Exécuter — en parallèle, en worktrees isolés

Un agent par fichier, jamais de commit par un agent, jamais de fichier partagé
confié à un agent. La session principale garde pour elle ce qui converge —
typiquement `ui.gd`.

### 4. Intégrer — en vérifiant soi-même

Relire ce que l'agent a produit plutôt que le croire sur parole, rejouer les
suites, commiter, récupérer `main`, fusionner, pousser. Petit et souvent : une
branche qui vieillit coûte cher à fusionner quand d'autres sessions poussent.

### 5. Proposer — seulement quand l'audit rend 0

Trois angles, dans cet ordre de valeur décroissante :

1. **Réveiller ce qui dort.** Un système déjà câblé mais jamais alimenté a le
   meilleur ratio du projet. Les chercher : du code écrit que personne n'appelle,
   une ressource déclarée qui n'existe pas, un signal jamais connecté.
2. **Renforcer la boucle.** Le kill, le rematch, l'écran de fin — l'endroit où
   « encore une » se décide.
3. **Épaissir le monde.** Ambiance, matière, présence. Le plus facile à produire
   en quantité, donc le plus dangereux : c'est ici que la boucle dérape.

### 6. Filtrer — cinq portes, et la plupart des idées n'en passent pas une

Une proposition qui échoue à **une seule** porte est refusée, pas amendée.

**Porte 1 — zone franche ou en manche ?**
Le kill, la killcam, les écrans de fin et le menu sont des zones franches : la
manche est finie, le budget est libre. Pendant la manche, la contrainte est
absolue.

**Porte 2 — l'information.**
L'effet apprend-il au joueur quelque chose qu'il n'avait pas ? Si oui, **ce n'est
pas du polish, c'est du game design** : la proposition part dans la liste des
décisions d'Adrien, jamais directement à l'implémentation. C'est la porte qui
protège l'équilibre du jeu, et la plus facile à franchir par distraction.

**Porte 3 — le budget.**
Tout ce qui touche à la manche se mesure sur `tools/bench_framerate.tscn` avant
d'être accepté. Cible : 1 % bas ≥ 120 fps. Une mesure, pas une intuition.

**Porte 4 — la lisibilité.**
Le canal d'information du jeu est la lumière. Un effet qui ajoute de la lumière
dans l'aire de jeu **réduit le signal**. Un écran plus joli mais moins lisible
est une perte nette, même si personne ne s'en plaint tout de suite.

**Porte 5 — la phrase.**
Si la proposition ne peut pas dire en UNE phrase ce qu'elle rend meilleur, elle
est refusée. Pas reformulée : refusée. Une idée qui a besoin d'un paragraphe pour
justifier son existence n'en a pas.

## Les conditions d'arrêt

Une boucle sans frein produit du remplissage. Trois freins, à respecter tels
quels :

1. **Plafond de réserve.** Si plus de **quinze** propositions acceptées attendent
   d'être implémentées, le temps 5 est sauté. La boucle produit alors plus vite
   qu'elle ne consomme, et générer davantage ne fait qu'allonger une liste que
   personne ne lira.
2. **Le playtest est le seul juge.** Après chaque vague touchant au ressenti, le
   jalon H3 doit être **repris** par Adrien. Une boucle qui ne redemande jamais
   dérive : elle optimise ce qu'elle sait mesurer, et le plaisir n'en fait pas
   partie.
3. **Rien ne s'invente tant qu'il reste à faire.** Le temps 5 est interdit si
   l'audit ne rend pas 0. Inventer est plus agréable que finir ; c'est
   précisément pour cela qu'il faut l'interdire.

## Le journal des refus

**Une proposition refusée s'écrit, avec sa porte et sa raison.**

Sans cela, le cycle suivant reproposera exactement ce que le précédent a écarté —
c'est le défaut propre à tout processus récursif sans mémoire, et il se paie en
temps perdu à re-décider les mêmes choses. Le journal vit dans la section
« Refusé, et pourquoi » de `docs/ROADMAP.md`.

Un refus n'est pas définitif : une porte peut s'ouvrir si le contexte change (une
mesure de performance meilleure, une décision d'Adrien). Il faut alors dire **ce
qui a changé**, pas simplement reproposer.
