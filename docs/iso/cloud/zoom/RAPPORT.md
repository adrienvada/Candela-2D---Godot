# Q15 — le zoom du duel, sur image (session cloud « zoom-2 »)

> **État : en cours** (commencé le 27/09 à 02:20, heure de Paris). Ce fichier est
> d'abord le PLAN ; il deviendra le rapport complet à la fin.

Branche : `claude/cloud-zoom-2`, partie de `origin/integration-iso14` (`60e5c6d`).
Refait la tâche d'une première session dont les commits n'ont pas pu être poussés.

## Ce que la tâche est, et n'est pas

Adrien doit choisir entre garder ×1,5 (défaut depuis ISO11) et un autre cadrage. On lui
MONTRE ; **rien ne change dans le jeu**. Le seul ajout est un outil de prise de vues
(`tools/planche_zoom.gd`), hors du jeu.

## Ce que dit le code (lu avant de photographier)

- `settings_manager.gd` : `ZOOM_DUEL_DEFAUT = 1.5`, borné 1,0–3,0 ; `--zoom=X` ne vaut
  qu'en build de débogage et **jamais en ligne** (`valeurs_du_duel` impose 1,5 aux deux
  machines).
- Le zoom est posé sur les deux `Camera2D` du duel (`game_state.gd`) ; la caméra iso
  (`camera_iso.gd`) lit la transformation de canevas de la vue 2D, zoom compris.
- **Le zoom ne touche PAS la portée de la torche dans le monde** : elle dépend du seul
  `WeaponData.facteur_portee` (0,75, `--torche=`). Zoomer grossit donc le cône à l'écran
  et montre moins de carte autour ; la torche éclaire le même sol.
- Le regard décalé (`regard_duel.gd`) avance la caméra vers la visée de 0,15 × la
  hauteur VISIBLE (donc 0,15 × 1080 / zoom px de monde) : plus on zoome, moins il avance
  en pixels de monde, et la caméra se borne aux bords de la carte au-delà de ×1,0.

## Le plan

1. Un outil `tools/planche_zoom.gd` (hérite du photographe) : une exécution par zoom
   (`--zoom=1.25 | 1.5 | 1.75 | 2.0`), lacet 45° option B (défaut), deux cartes
   (`map_001_le_cloitre`, `map_003_la_croisee`). Mêmes positions à tous les zooms
   (calculées sans dépendre du zoom) : J1 sur un sol dégagé, J2 au bord de son cône.
2. Par zoom et par carte : la vue unique 1920×1080 (capture de la fenêtre, HUD compris),
   l'écran scindé au même instant, et des recadrages sur le corps adverse.
3. Les chiffres, pris avec les formules du jeu (`CameraIso.vers_ecran` / `vers_sol`) sur
   la caméra réellement posée : taille du corps à l'écran (1080 et 1440 lignes), portée de
   la torche en px et en part de la demi-largeur, part de la carte visible, portée du
   regard à l'écran dans chaque direction comparée à la portée de la torche (« peut-on être
   éclairé par quelqu'un qu'on ne voit pas ? »).
4. « Jusqu'où voit un joueur » : le plan de chaque carte en SVG avec, par zoom, l'empreinte
   au sol de l'écran et le cercle de portée de la torche.
5. `planche.html` autonome, images en JPEG, et ce rapport complet : cinq lignes pour
   Adrien, conclusion honnête sans recommandation, commandes pour tout refaire, ce qui
   n'est pas prouvé.
