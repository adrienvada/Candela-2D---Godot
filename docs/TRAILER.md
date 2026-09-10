# Le trailer — l'outil et le film

*Item **DA7.2**. Écrit le 2026-09-09, refait le même soir.*

## Ce document a d'abord annoncé un blocage qui n'existait pas

Sa première version disait : *« Bloqué sur un manque réel : il n'existe aucune
capture vidéo. »* **C'était faux.** Godot filme depuis toujours —
`--write-movie`, cadence fixe forcée, `--quit-after` pour compter les images.
Personne n'avait tapé `godot --help`.

Le plus coûteux n'est pas l'erreur, c'est ce qu'elle est devenue : **ce document
a servi de preuve à son propre blocage**, et l'item est resté marqué « bloqué »
dans la ROADMAP et dans le suivi de projet, sur la foi d'une affirmation que
personne n'a vérifiée parce qu'elle était écrite. Un manque annoncé coûte plus
qu'un silence.

Il ne manquait donc pas un outil de capture. Il manquait la **mise en scène** —
et elle existait déjà chez le photographe de DA6.

## Les deux outils

### `tools/cineaste.gd` — le photographe dont l'obturateur reste ouvert

Il **hérite** du photographe : sélection des plans, préconditions, éclairage,
cadrage, marionnettes. Il ne surcharge presque rien.

| ce qu'il ajoute | pourquoi |
|---|---|
| `_prendre()` tient au lieu de déclencher | le moteur écrit chaque image tout seul |
| la classe `Comedien` | la marionnette du photographe rend un mouvement NUL et ne tire jamais — elle existe pour qu'une image soit nette |
| les chorégraphies | un plan de film a besoin d'un mouvement, d'une cause et d'une conséquence ; une pose n'en a aucun |
| le mode `--carton` | ffmpeg n'a pas `drawtext` sur ce poste : le texte vient du moteur, dans la fonte de l'enseigne |
| le mode `--enseigne` | l'ouverture : le logo naît d'un noir en vacillant — DA7.8 prise à l'envers |

### `tools/run_trailer.sh` — tourner et monter

```bash
./tools/run_trailer.sh                      # tout
./tools/run_trailer.sh --plans=duel,torche  # quelques plans
./tools/run_trailer.sh --monter-seulement   # remonter sans retourner
```

Un plan par lancement — le mode film enregistre tout, y compris les transitions
entre deux mises en scène. Le cinéaste imprime des **numéros d'image**, le
script les convertit en secondes et découpe. Exact, et indépendant de la charge
de la machine.

## Ce que le film raconte

Quatorze segments, quarante-deux secondes, en **alternance planche / carton /
jeu** — la structure du site.

1. **L'enseigne** naît d'un noir en vacillant.
2. **Deux planches** de l'introduction : la descente, le seuil.
3. *LA SEULE INFORMATION EST LA LUMIÈRE.*
4. **On cherche, seul.**
5. **La dotation**, puis *ÉCLAIRER, C'EST VOIR.*
6. **On se cherche à deux**, sans se trouver.
7. *ÉCLAIRER, C'EST ÊTRE VU.*
8. **Les cônes se croisent**, puis **on tire dans le noir**, torches éteintes.
9. **Le prix** — l'ombre sur le mur.
10. **Quelqu'un tombe.** Le gel n'est pas monté : le jeu s'arrête tout seul.
11. **L'extinction.**

Les planches viennent de l'intro du jeu (DA6.6), **filmée** au premier
lancement : elles portent déjà leur lettrage et leur cadre d'encre. Les coupes
ne sont pas devinées — ffmpeg trouve six changements de plan espacés exactement
de 2,50 s, la durée d'une planche.

## Cinq choses payées, et qui se rejoueront ailleurs

**Une pose n'est pas un plan.** Le premier film était quinze poses tenues trois
secondes : un diaporama. Le mécanisme prouvé sur un seul plan n'avait pas été
appliqué aux six autres, ce qui a coûté un deuxième montage pour rien.

**Le photographe replace J2 par rapport à J1 à chaque image.** C'est ce qui
cadre une photo de duel — et à l'écran, le second semblait *suivre la lampe* du
premier. Les chorégraphies n'appellent donc plus son `tenir`, seulement de quoi
garder les joueurs debout. Les deux balaient à des rythmes **premiers entre eux**
pour qu'aucun spectateur ne puisse lire une relation entre leurs faisceaux.

**L'unité du temps est l'image dessinée, et la clôture d'une boucle se compte en
temps réel.** Trois versions ont été écrites. Compter les tours est juste pour
un plan de jeu et faux pour un carton — scène quasi vide, la boucle tourne des
dizaines de fois par image écrite, et un carton de 2,4 s sortait à 0,12 s.
Compter les images est juste, mais un garde-fou vingt fois trop serré coupait
avant la fin. **La bonne solution a été jetée à cause de sa clôture** : le
premier réflexe fut de changer la logique, il fallait changer la limite.

**Un budget d'images serré tronque en silence.** `--quit-after` compte les
images écrites, et l'encodage coûte de 60 à 950 ms par image selon la charge :
un budget calculé au plus juste coupe le plan sans erreur et sans repère de fin.

**Le décompte d'avant-manche coûtait la moitié du tournage.** Le photographe
démarre une vraie partie locale ; ses trois secondes de décompte valent deux
cents images **enregistrées puis jetées au montage**. Le cinéaste les écourte —
la manche démarre normalement, seule l'attente disparaît. Un plan se tourne en
trente-sept secondes.

## Ce qui reste ouvert

- **Le film sort en 1280×720.** Le mode film verrouille sa résolution à
  l'initialisation du moteur, avant que quoi que ce soit ne pose la fenêtre.
  Pour du 1080p : changer la taille de fenêtre du projet, ou filmer un build
  exporté.
- **Deux plans de la famille `fins` sont cassés dans le photographe** —
  `affiche` et `verdict-victoire` échouent sur « Lambda capture at index 0 was
  freed », pour la photo comme pour la vidéo. Signalé à la session qui tient
  l'outil. Le film se termine donc sur l'extinction.
- **Le rythme est régulier**, pas croissant.
