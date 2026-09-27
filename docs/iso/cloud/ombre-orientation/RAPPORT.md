# L'ombre des classes, suite : l'orientation, et une compensation par classe (session cloud ombre-orientation, 2026-09-27)

> **État : plan (premier commit).** Le rapport complet remplacera ce fichier.

## Le plan

Base : `claude/cloud-ombre-classes` (`cdd18fd`), son banc `tools/planche_ombre.gd`, son analyse `analyse_ombre.py`, son
drapeau `--ombre-ronde`. Rien ne change par défaut.

1. **L'orientation.** Un héritier de `planche_ombre.gd` (`tools/planche_orientation.gd`) : J2 tourné de huit façons
   par rapport à la torche de J1 (de face, de dos, profils gauche et droit, quatre diagonales), les dix classes, places
   `b10` et `mi` (les mêmes, retrouvées de la même façon), ombre d'aujourd'hui. Pour chaque prise : la moyenne de
   l'anneau (le « capteur » de Q33), son maximum, le profil 64 points, l'occluder en coordonnées du monde. Le mode
   `sans` (pas d'ombre propre) n'est pris qu'une fois par place : sans ombre propre, la classe et l'orientation ne
   changent rien (constaté par la base, revérifié ici par des prises de contrôle).
   Puis le calcul géométrique d'`analyse_ombre.py` refait pour les huit orientations.
2. **La voie (d).** Un drapeau d'essai `--ombre-compensee=1|2`, éteint, débogage seulement, jamais en ligne :
   - (d1) un facteur constant par classe = part éclairée de l'anneau du Parasite / part éclairée de la classe,
     calculées par la géométrie de la silhouette (l'étoile de `Charte.ombre_de_silhouette`) ; l'orientation de
     référence est discutée dans le rapport ;
   - (d2) le même rapport, recalculé pour la direction et la distance réelles de la torche adverse.
   Le facteur multiplie la lumière que le corps lit dans son capteur (uniforme du shader des corps). Ni les masques de
   `player.gd`, ni la simulation, ni `Protocol.VERSION` (18). Une garde headless : éteint, rien ne bouge au bit près.
3. **Le seuil.** Normalisée sur le Parasite, la compensation ne change pas le Parasite : le recalage du seuil devrait
   être nul par construction — à vérifier. **Et une question que les chiffres de la base posent déjà** : le MAXIMUM de
   l'anneau est le même pour les dix classes (0,2118 à `b10`, 0,6471 à `mi`, `chiffres.json` de la base) ; seule la
   moyenne diffère. Or chaque fragment du corps lit l'anneau dans SA direction : le premier pixel qui apparaît est
   celui qui lit le maximum. Si c'est vrai, les dix classes **apparaissent déjà au même endroit** (de profil), l'écart
   de 11 % est un écart de LARGEUR du liseré, et une compensation multiplicative ferait apparaître les classes
   compensées PLUS TÔT. À mesurer à l'image (distance du premier pixel, classe par classe), pas à supposer.
4. **Pour le Mac** : une série M0/M1 (règle 278) si (d2) calcule quelque chose à chaque image.

Livrables : ce rapport, `planche.html`, les chiffres, les commandes pour tout refaire.
