# ISO12 — La lumière 3D, bridée par la lightmap

Brief écrit le 15/09/2026 à 22:0x par la session cloud « Fable 5.1 - CLOUD ISO UNRAILED »,
pour « Iso 1 Opus ». Branche `iso12-lumiere3d` depuis la tête d'`iso11-retours`.
Un lot à la fois (`pgrep -x Godot`), un commit, un lot vert et un delta par lot ;
rien de fusionné sans mon mot, rien de poussé.

## La décision d'Adrien

À 21:5x : « Réponds-moi sincèrement : est-ce qu'on ne se fourvoie pas à persévérer en 2D ?
Vu les images de référence générées, est-ce qu'on ne devrait pas faire la 3D ? »
Avec deux rendus voxel : un mannequin près d'une bougie dans une salle dallée, un tireur
au fusil à pompe avec flash de bouche et corps au sol. Ce que ces images ont et que le jeu
n'a pas : des faces éclairées selon leur angle à la lampe, des ombres portées par les corps
et les murs, un flash qui éclaire le tireur, des coins qui s'assombrissent.

Ma réponse : le jeu reste 2D (simulation, réseau, hitbox, rejeu) et la présentation est
déjà 3D ; ce qui plafonne, c'est la lumière restée 2D. ISO7b a prouvé à 14:19 que le
gradient de la lightmap ne dit pas la direction ; les corps uniformes en sont le symptôme.
La règle « pas de Light3D » de l'étude tombe, à une condition : la bride ci-dessous.

À 22:0x : « Ok pour ISO12, enchaîne avec les lumières 3D. » Donc : le lot 0 (plan et banc)
est jugé sur image et sur cadence, puis les lots suivent sans nouvelle décision d'Adrien,
sauf si la cadence casse (voir « Si la cadence casse »).

## Ce qui ne change pas

- La simulation 2D autoritaire, le protocole (VERSION 18), la hitbox à 18 px, le rejeu,
  les 111 suites : intacts. Aucune lumière 3D n'entre dans une décision de jeu.
- Le noir absolu : aucune lumière ambiante, aucun environnement, aucune lumière qui ne
  soit une source du jeu (torche, flash, fusée, braise, mine, lampe de gadget).
- L'équité : la lightmap 2D reste la vérité de ce qui est visible. En ligne, mêmes
  valeurs pour tout le monde ; aucun curseur ne touche la bride.
- La caméra : lacet 0°, tangage 52°, zoom ×1,5 (L3 d'ISO11), regard décalé 0,25,
  deux vues en écran scindé. `--zoom=`, `--decalage=`, `--torche=` gardent la main.
- Le rendu : `gl_compatibility`. Vérifié dans la documentation Godot : ombres des
  lumières positionnelles oui, PCSS non, SSAO non, brouillard volumétrique non, glow oui,
  MSAA 3D oui, **huit lumières par maillage** (plafond à tenir : deux torches, fusées,
  flashs, braises sur un même sol ; au-delà, les lumières de rang faible perdent l'ombre
  ou fusionnent).
- La cible de cadence : **1 % bas ≥ 60**, vue unique ET écran scindé, fenêtre 2560×1440
  au premier plan. Elle se mesure au banc du lot 0, pas au test final : c'est une décision
  de faisabilité, l'exception au report des relevés est explicite.
- Les effets d'écran restent 2D et inchangés : voile d'éblouissement, rétrodiffusion,
  silhouette de soi, effacement (ISO2b). Si le voile lit la vue iso, il lit la nouvelle.

## La bride (c'est elle qui protège l'équité)

    couleur_finale = lumiere_3D(surface) × bride(L2D)
    bride(L2D)     = smoothstep(seuil_bas, seuil_haut, L2D)      # L2D = 0  ⇒  noir, quoi qu'éclaire la 3D

- `L2D` se lit là où le jeu le lit déjà : aux pieds d'un corps (le capteur d'ISO2/ISO3),
  au pied d'une face de mur, sur la dalle pour le sol. Rien de nouveau ne devient
  visible : la lumière 3D ne fait que MODELER dans la zone déjà visible.
- Les lumières 3D copient leurs paramètres des Light2D : même source de vérité (la classe :
  angle du cône, portée après `facteur_portee`, couleur), même position, même hauteur que
  celle que Gadgets a définie pour les sources (fusée qui passe par-dessus un muret).
- Seuils : à poser au banc ; `seuil_bas` proche de 0 (le bord du cône reste celui de la
  2D, qui est bon depuis la loupe), `seuil_haut` bas aussi, pour que le modelé 3D
  s'exprime sur toute la zone visible et non sur son seul centre.
- Preuve exigée (test headless ou mesure au banc) : masque des pixels visibles en 3D
  ⊆ masque des pixels où `L2D > 0`, sur plusieurs positions et orientations.

## Lot 0 — le plan, puis le banc (2 à 3 h), jugé avant tout

1. **Plan-delta d'abord** (30 min, à moi avant de coder) : où se branchent les Light3D
   dans `Presentation3D` ; comment `sol_iso` et `mur_iso` passent en shaders spatiaux avec
   `light()` (ou matériau standard + surcouche) sans perdre les textures d'ISO7, l'encre,
   le lavis, le contact au pied ; comment se calcule la bride ; comment les lumières
   propres à un joueur (silhouette de soi) se masquent par vue (`Camera3D.cull_mask`,
   `light_cull_mask`) ; ce qui se casse ou change de sens : `peinture_iso` (la division
   par la peinture n'a plus lieu d'être si la peinture module l'albédo), `contact_des_corps`
   (l'ombre de contact devient une vraie ombre), `halo_iso` et les nappes de fumée (relisent
   la lumière 3D ou gardent leur lecture 2D), la killcam et le rejeu (mêmes lumières
   pilotées par le rejeu).
2. **Le banc** (`tools/banc_lumiere3d.tscn`, plans dans le photographe) : carte d'essai des
   murs bas et Le Cloître ; J1 pistolet (cône de la classe), J2 Braconnier (5°) ; une fusée
   posée (OmniLight3D à sa hauteur) ; un flash de tir ; les corps voxel en matériau
   standard ; les deux vues. Variantes : ombres oui/non ; taille de l'atlas d'ombres
   (1024 / 2048 / 4096) ; deux couples de seuils de bride.
3. **Livrables** : une planche aux mêmes cadrages que la loupe (bord du cône, pilier,
   corps J1 et J2, sol, fusée, écran scindé) en PNG octet pour octet dans la galerie
   (par ISO Assets ou directement), et par variante et par vue : fps médiane, 1 % bas,
   appels de dessin, ms GPU si le banc les donne. Je juge sur image et sur chiffres.

## Les lots suivants (un commit, un lot vert, un delta chacun)

- **L1 Torches** : une `SpotLight3D` par joueur (main du joueur, hauteur de source,
  direction de visée, angle et portée de la classe, atténuation), avec ombres ; bride sur
  le sol et les faces.
- **L2 Sol et murs** : matériaux 3D éclairés par la lumière 3D × bride, textures d'ISO7,
  encre, lavis et contact au pied gardés ; la lightmap ne sert plus aux faces que par la
  bride ; la peinture (sang) module l'albédo, le mur rougi de 1f devient naturel.
- **L3 Corps** : matériau standard sur les voxels, ombres portées et reçues, modelé par la
  lampe ; référence du look = les dix portraits de classe validés par Adrien (plâtre
  rouillé, encre, accessoires par blocs) : teinte et matière par classe ; silhouette de
  soi et effacement préservés ; hitbox intacte.
- **L4 Fusées, flashs, braises, gadgets** : `OmniLight3D` à la hauteur des sources ; le
  flash de tir éclaire le tireur ; fumée et halo : selon le plan du lot 0.
- **L5 Killcam et voile** : le rejeu pilote les mêmes lumières ; le voile lit la nouvelle
  vue ; la killcam calme d'ISO11 L2 reste calme.
- **L6 Planche finale et loupe** (mêmes cadrages que les tours 1 et 2), ROADMAP (décision
  actée : la lumière 3D bridée remplace la lecture directe de la lightmap par les faces et
  les corps ; ISO7b faces : remplacée, sa preuve reste), message de fin.

## Si la cadence casse

Revenir à Adrien avec les économies chiffrées, dans cet ordre : atlas d'ombres réduit ;
pas d'ombre sur les omni (fusées, flashs) ; une seule lumière ombrée par joueur ;
ombres en vue unique seulement (l'écran scindé garde la bride sans ombre). Le second
levier, plus lourd, est le rendu Forward+ (Metal) : SSAO, brouillard volumétrique, PCSS ;
c'est une décision actée à rouvrir avec une mesure, pas dans ce chantier.

## Pièges connus qui s'appliquent

- Huit lumières par maillage en compatibility ; MSAA 3D ×4 déjà activé à la création de
  la vue iso ; tout shader déclarant `hint_screen_texture` copie l'écran (piège ISO10) ;
  un sub-viewport ne rend un élément que si lui et ses parents partagent une couche avec
  son masque ; `player.gd` rallume la torche à chaque image ; images remplacées ⇒
  `godot --headless --path . --import` ; `--fixed-fps` absent des arguments.
- Un chevauchement ou une lecture qui décide d'un état se vérifie sous toutes les
  orientations du corps (piège ISO11 L1).
