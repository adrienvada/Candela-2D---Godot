# Le point de braise de la fusée, rouge après le plein feu (session cloud « fusée-point », branche `claude/cloud-fusee-point`)

*27/09/2026, heure de Paris. En cours — plan posé à 02:35.*

## Plan
1. **Isoler la cause de D1** (le point jaune pâle après le plein feu) : la couleur donnée au point (celle de la lumière,
   orange à la braise) et le mélange ADDITIF du halo sur un sol déjà orange. Preuve : couleur calculée hors rendu, puis
   le halo seul sur fond noir contre le halo sur le sol éclairé.
2. **Isoler D3** (le blanc qui déborde du plein feu) : le blanc suit l'énergie relative, qui glisse 1,5 s dans la braise.
3. **Corriger dans le code du point seul** (`iso_volumes.gd`, `_suivre_coeur_fusee`, et s'il le faut le mélange de ce
   seul halo) : le blanc décidé par l'ACTE (plein feu), pas par l'énergie ; après, un rouge fixe. La Light2D, la comète,
   les autres halos ne bougent pas ; `Protocol.VERSION` reste 18.
4. **Garde headless** : la couleur du point par acte, pour les deux variantes (défaut et `--fusee-rouge-long`).
5. **Suite complète**, puis **planche par âges** refaite avant/après (plan `loupe-fusee-ages`, âges 0,5 à 8 s, un demi-pas
   au-delà des bornes), couleur du point mesurée sous chaque image, et **noir absolu** (torches éteintes, A, B, A').
