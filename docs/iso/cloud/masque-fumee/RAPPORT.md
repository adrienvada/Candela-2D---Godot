# Un masque de la fumée qui ne coûte pas 2,4 ms — rapport de la session cloud « masque-fumée »

> Branche `claude/cloud-masque-fumee`, partie de `origin/integration-iso14` (`60e5c6d`), 2026-09-27, à partir de 06:08
> (Paris). **État : en cours — plan seulement.**

## Plan

1. **Lire** le masque (`volume_iso.gdshader`, `volume_masque.gdshaderinc`, `iso_volumes.gd`, l'usure
   `iso_usure.gdshaderinc`) et son histoire (Q31, `b8c1b49`, `ef758bd`) ; écrire ici, AVANT de coder, ce qu'il calcule,
   pour quels pixels, avec quelles textures et quelles boucles, et ce qu'il fait de plus que la fumée sans lui.
2. **Compter** sans chronomètre, sur la scène de mesure (pompe sous une fusée, vue unique, 45° B, usure au défaut) :
   - les appels, passes, copies d'écran et sous-vues (l'outil `tools/cloud_budget/` de la session Budget), avec et sans
     `--fumee-masque` ;
   - les fragments de fumée à l'écran, sur-dessin compris ;
   - dans le GLSL que Godot génère réellement (Mesa sait le sortir : `MESA_SHADER_CAPTURE_PATH` / `MESA_GLSL=dump`, et
     la forme optimisée NIR), les lectures de texture, les tours de boucle et la taille du code par fragment, masque
     éteint, masque sans usure, masque avec usure.
   Première piste, lue dans le code et la ROADMAP : le masque SANS usure coûtait +0,28 ms (V1f, 25/09) ; AVEC usure
   +2,0 à 2,4 ms, et la bande des faces, qui ne calcule plus l'usure que près du seuil, n'a rien rendu. Le prix suivrait
   donc la PRÉSENCE du code de l'usure dans le shader (taille, registres, boucle de 48 impacts) plus que son exécution —
   à établir par les comptes, pas à croire.
3. **Deux ou trois variantes** moins chères, chacune derrière son drapeau, éteintes par défaut, qui gardent la promesse
   (0 pixel noir allumé ; au plus près du masque actuel là où il y a de la lumière ; symétrie J1/J2, 0° et 45°).
4. **La série pour le Mac** (M0, M1, variantes ; ordre en miroir, règle 278), commandes et lignes de preuve.

Livrables : un commit par variante avec sa garde headless, suite verte, ce rapport, `planche.html`.
