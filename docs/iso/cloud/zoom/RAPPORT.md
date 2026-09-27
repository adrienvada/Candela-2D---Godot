# Q15 — le zoom du duel, sur image (session cloud « zoom-2 »)

> **Pour Adrien, en cinq lignes.**
> 1. Ouvre `planche.html` (dans ce dossier) : le même duel à ×1,25, ×1,5 (aujourd'hui), ×1,75 et ×2, sur le Cloître et la Croisée, en plein écran et en écran partagé.
> 2. Le zoom ne change pas jusqu'où la torche éclaire : il change la taille des choses à l'écran et ce qu'on voit autour de sa lumière.
> 3. Plus on zoome, plus les corps sont gros (de ~47 à ~75 px de large) et plus la carte est cachée (de ~73 % à ~35 % de ces cartes à l'écran).
> 4. Plus on zoome, plus un adversaire peut vous éclairer depuis l'extérieur de votre écran, surtout dans votre dos (4 armes sur 10 à ×1,25, toutes à ×2).
> 5. Rien n'a changé dans le jeu ; le choix reste le tien. La fluidité, elle, n'a pas pu être jugée ici (à mesurer sur ton Mac).

**État : terminé** — 27/09, de 02:20 à ~05:00 (heure de Paris). Branche `claude/cloud-zoom-2`, partie de
`origin/integration-iso14` (`60e5c6d`). Refait la tâche d'une première session dont les commits n'avaient pas pu être poussés.

## Ce qui a été fait

- **Aucune ligne du jeu n'a changé.** Un outil de prise de vues, hors du jeu : `tools/planche_zoom.gd` (+ `.tscn`), qui
  hérite du photographe ; les deux corrections Xvfb du photographe reprises de `claude/cloud-photographe` (`0c67705`),
  dans un commit à part.
- 4 zooms × 2 cartes : pour chacun, la vue unique 1920×1080 (HUD compris, rendu du joueur), la même au sommet de la
  respiration du bandeau LED, l'écran scindé, un recadrage 1:1 du corps adverse ; plus un contrôle en 2560×1440 (×1,5,
  Croisée). Toutes au lacet 45°, option B, décalage 0,15, torche ×0,75 : les valeurs du jeu en ligne, seul le zoom varie.
- Les chiffres (`images/mesures-*.json`) sont pris **dans le jeu en marche**, sur la caméra iso réellement posée, avec
  ses propres formules (`CameraIso.vers_ecran` / `vers_sol`), pas recalculés à côté.
- `planche.html` : autonome, images en chemins relatifs, plans des cartes en SVG.

## Comment le zoom s'applique (lu dans le code avant de photographier)

- `settings_manager.gd` : `ZOOM_DUEL_DEFAUT = 1.5`, borné 1,0–3,0. `--zoom=X` ne vaut qu'en build de débogage et
  **jamais en ligne** : `valeurs_du_duel(en_ligne=true)` impose 1,5 aux deux machines. La killcam en repart
  (`killcam_cadrage.gd`), le coup reçu dézoome de 2 % puis y revient (`camera_hit_kick`).
- `game_state.gd` pose le zoom sur les deux `Camera2D` du duel ; `camera_iso.gd` lit leur transformation de canevas,
  zoom compris : `size = (1080 / zoom) × sin 52°`. À l'écran, un pixel de sol vaut `zoom / sin 52°` ≈ 1,27 × zoom en
  largeur et `zoom` en profondeur.
- **La portée de la torche ne dépend pas du zoom** : elle ne dépend que de `WeaponData.facteur_portee` (0,75). Zoomer
  grossit le cône à l'écran ; la torche éclaire exactement le même sol.
- **Le regard décalé** (`regard_duel.gd`) avance la caméra de 0,15 × la hauteur VISIBLE vers la visée, soit
  162 / zoom px de monde : plus on zoome, moins il avance dans le monde (130 px à ×1,25, 81 px à ×2). À l'écran, le
  joueur reste au même endroit (à 162 px du centre) quel que soit le zoom. Au-delà de ×1,0, la caméra s'arrête aux bords
  de la carte (dans ses axes tournés de 45°) : sur ces petites cartes (28 à 30 cases, ~1 000 px), c'est fréquent à ×1,25.

## Les chiffres

Pixels d'écran pour 1080 lignes ; sur 1440 lignes le jeu se rastérise à la fenêtre (`stretch = keep`), tout est ×4/3
(vérifié : la prise en 2560×1440 de ×1,5 à la Croisée, réduite à 1080 lignes, coïncide avec la prise 1080 à 0,3/255
d'écart moyen, contre 0,67 dès qu'on la décale de 2 px ; même cadrage, même contenu, rastérisé plus fin). Moyenne des deux cartes quand elles diffèrent.

| Zoom | Corps (l × h), 1080 | Corps, 1440 | Zone de touche Ø36 à l'écran | Torche (pistolet) à l'écran, au plus long | part de la demi-largeur | Carte visible, Cloître / Croisée | Écran scindé (vue de J1) |
|---|---|---|---|---|---|---|---|
| ×1,25 | 47 × 57 | 63 × 77 | 57 × 45 | 487 px | 51 % | 73 % / 73 % | 40 % / 47 % |
| **×1,5** | 56 × 68 | 75 × 91 | 68 × 54 | 585 px | 61 % | 55 % / 59 % | 29 % / 34 % |
| ×1,75 | 66 × 80 | 88 × 107 | 80 × 63 | 682 px | 71 % | 40 % / 46 % | 22 % / 26 % |
| ×2,0 | 75 × 92 | 100 × 122 | 91 × 72 | 780 px | 81 % | 32 % / 37 % | 17 % / 20 % |

- **Corps** : la boîte des maillages voxel de J2, projetée par la caméra (c'est l'encombrement, pas un compte de pixels
  allumés). Elle varie d'une carte à l'autre de ~5 px parce que J2 n'y a pas la même orientation.
- **Écran scindé** : chaque joueur a une vue de 957 × 1080 ; les corps et la torche y ont la même taille qu'en vue
  unique (même échelle), seule la largeur de monde montrée diminue — d'où la dernière colonne.
- **Zone de touche** : le disque de 18 px de rayon au sol, à l'écran (largeur × hauteur : le sol est raccourci en
  profondeur).
- **Carte visible** : la part de la surface de la carte que couvre l'empreinte au sol de l'écran, dans la scène
  photographiée (caméra arrêtée aux bords comprise). Ces deux cartes sont petites : ailleurs la part serait plus faible.

### Voir avant d'être vu

Jusqu'où l'écran montre le sol depuis le joueur, en px de monde, en terrain ouvert (formule de la caméra, confirmée par
la mesure dans la scène de la Croisée : 468 devant et 252 derrière à ×1,5, au pixel près). Le pire cas est la visée vers
le HAUT de l'écran, parce que l'image est moins haute que large.

| Zoom | Visée haute : devant | derrière | côtés | Visée à droite : devant | derrière | côtés | Torches qui portent plus loin que votre dos (visée haute) |
|---|---|---|---|---|---|---|---|
| ×1,25 | 562 | 302 | 605 | 735 | 476 | 432 | 4 sur 10 : pistolet (307, à 5 px près), fusil, sentinelle, arbalète |
| **×1,5** | 468 | 252 | 504 | 612 | 396 | 360 | 7 sur 10 : + incendiaire, spectre, fumiste |
| ×1,75 | 401 | 216 | 432 | 525 | 340 | 309 | 9 sur 10 : + occulteur, allumeur |
| ×2,0 | 351 | 189 | 378 | 459 | 297 | 270 | 10 sur 10 : même la pompe (192) |

Portées des torches, ×0,75 compris (px de monde) : pompe 192, allumeur 230, occulteur 250, incendiaire 269, spectre 269,
fumiste 288, pistolet 307, fusil 346, sentinelle 499, arbalète 672.

Lecture :
- **Devant**, à tous les zooms, l'écran montre plus loin que la torche du pistolet (de 562 à 351 contre 307) : la lumière
  d'un adversaire qui arrive en face apparaît avant qu'il n'entre dans votre faisceau. Mais la marge fond : 255 px de
  monde à ×1,25, 44 à ×2. Le bout du faisceau des armes longues sort de l'écran : sentinelle (499) dès ×1,5 en visée
  haute, arbalète (672) à tous les zooms.
- **Derrière et sur les côtés**, un porteur d'une torche plus longue que ce que montre votre écran peut vous éclairer —
  donc vous voir — depuis un endroit que vous ne voyez pas : vous voyez la lumière vous toucher, pas d'où elle vient.
- **Équité** : c'est la même chose pour les deux joueurs à un zoom donné, et en ligne tout le monde est à ×1,5. Le zoom ne
  crée aucun avantage de l'un sur l'autre ; il règle combien d'information chacun a au-delà de sa propre lumière.

## Conclusion, d'après les images (sans recommandation)

Ce que montrent toutes les images, avant le détail par zoom : **à 45°, une carte carrée devient un losange**, et la
caméra ne s'arrête qu'au rectangle qui l'englobe. Près d'un bord (le Cloître, ici), un triangle entier de l'écran tombe
hors carte, dans le noir — d'autant plus grand qu'on dézoome. Et **au sommet de la respiration du bandeau LED**, la bande
dessine le plan de tout ce qui est à l'écran : plus on dézoome, plus elle révèle de carte.

- **×1,25** — *gagne* : on voit presque toute la carte (73 % de ces deux cartes, caméra souvent arrêtée au bord), on voit
  venir la lumière adverse de loin, seules les armes longues peuvent vous éclairer hors champ ; au sommet de la
  respiration du bandeau, la bande dessine tout le plan. *Perd* : les corps sont les plus petits (~47 × 57 px), le détail
  des voxels se lit mal, le faisceau n'occupe qu'un quart de l'écran et l'image est surtout du noir autour ; c'est le
  contraire du « plus claustrophobique » demandé en ISO8, et le joueur n'est plus au centre quand la caméra bute au bord.
- **×1,5 (aujourd'hui)** — *gagne* : un compromis : corps ~56 × 68 px, faisceau à ~60 % de la demi-largeur, environ la
  moitié de la carte visible. *Perd* : 7 armes sur 10 peuvent vous éclairer depuis votre dos sans être à l'écran quand vous
  visez vers le haut ; les armes longues sortent de l'écran devant.
- **×1,75** — *gagne* : des corps nettement plus lisibles (~66 × 80 px), un faisceau qui remplit l'écran, le sentiment
  d'enfermement. *Perd* : 40 à 46 % de la carte visible, 9 armes sur 10 éclairent hors champ dans le dos, la marge devant
  sur le pistolet tombe à ~94 px de monde.
- **×2,0** — *gagne* : les plus gros corps (~75 × 92 px, ~100 × 122 sur un écran 1440), l'image la plus « serrée ».
  *Perd* : un tiers de la carte visible, toutes les armes peuvent vous éclairer hors champ, et devant l'écran s'arrête à
  peine plus loin que la torche du pistolet (351 contre 307) : on voit la lumière adverse presque en même temps qu'on
  l'éclaire. En écran scindé (957 px de large par joueur), c'est là que la vue est la plus étroite.

## Commandes pour tout refaire

```bash
# Cloud (Linux, Godot 4.7 en /usr/local/bin/godot, xvfb-run présent) ; ~7 min par couple (zoom, carte) en rendu logiciel.
GODOT=/usr/local/bin/godot docs/iso/cloud/zoom/refaire.sh
# Le contrôle en 1440 lignes (écran Xvfb à la même taille) :
TAILLE=2560x1440 ZOOMS=1.5 CARTES=map_003_la_croisee GODOT=/usr/local/bin/godot docs/iso/cloud/zoom/refaire.sh
# La planche :
python3 docs/iso/cloud/zoom/fabrique_planche.py
# Sur le Mac (vraie fenêtre, sans Xvfb) :
XVFB="" GODOT=/Applications/Godot.app/Contents/MacOS/Godot docs/iso/cloud/zoom/refaire.sh
```

`refaire.sh` lance une exécution par couple : `godot --fixed-fps 60 --path . res://tools/planche_zoom.tscn --
--zoom=Z --taille=1920x1080 --sortie=<dossier> --cartes=res://assets/maps/<carte>.json`.

## Ce que je n'ai PAS pu prouver

- **La fluidité** à chaque zoom : le rendu du cloud (llvmpipe) tourne à quelques images par seconde, aucun chiffre de
  cadence n'en sort. Un zoom plus large met plus de murs et de sol à l'écran ; son coût se mesure au banc sur le Mac.
- **L'éblouissement et les gestes des corps** : non représentatifs ici (voile de J2 dans l'écran scindé compris).
- **Une seule scène par carte, une seule classe (pistolet), un seul lacet (45°, option B)** : pas de 0°, pas d'autre arme
  en main, pas de killcam photographiée à chaque zoom.
- **« Voir avant d'être vu » est géométrique** : au sol, en terrain ouvert, sans murs, sans la décroissance de la lumière
  en bout de faisceau (le bout d'un cône est faible), sans la hauteur des corps, sans le HUD qui mange le coin haut-gauche.
  Ce n'est pas une mesure de partie jouée.
- **La taille des corps** est une boîte englobante projetée, pas un compte de pixels visibles ; les recadrages 1:1 de la
  planche la montrent à l'œil.
- **La part de carte visible** ne vaut que pour ces deux cartes (petites) et ces positions.

## Pièges découverts (à reporter dans la feuille de route)

1. **Le bandeau LED des murs respire, et deux images prises à deux instants ne se comparent pas.** `mur_led.gd` :
   période 8,47 s, sur l'horloge de manche (`GameState._horloge_led`), creux à t = 0. Au sommet, sur une carte en couloirs
   comme la Croisée, presque tout le sol s'allume (~18/255 au lieu du noir). Mon premier jet prenait l'écran scindé ~2 s
   après la vue unique et l'a vu « éclairé partout » ; j'ai d'abord accusé le changement de carte en pleine manche, et
   écrit cette fausse cause dans le message du commit `ac13aed` — **elle est fausse**, corrigée dans l'outil et ici. Toute
   planche comparative doit fixer la phase (ce que fait `planche_zoom.gd`) ou passer `--led-murs-fige`.
2. **Le zoom ne touche pas la portée de la torche**, et le regard décalé se compte en part de la hauteur VISIBLE : en
   pixels de monde il diminue quand on zoome. Tout raisonnement « la torche à l'écran » passe par `zoom / sin 52°`.
3. **`--zoom=` est lu deux fois par le photographe** : par `GameSettings` (le zoom du jeu, en build de débogage) et par le
   photographe lui-même (`_vivants`, qui le repose à chaque image). Les deux valeurs sont les mêmes, donc rien ne se voit ;
   mais le manifeste le présente comme « un geste de photographe, pas un réglage du jeu », alors que c'est aussi le zoom du
   jeu (et donc le décalage de regard qui en dépend).

## Défauts hors de ma tâche (signalés, non corrigés)

- `camera_iso.gd:3`, `:14` et `:20` : l'en-tête dit « lacet 0° » et que la garantie « ne montre jamais plus de carte que la
  caméra 2D » ne vaut qu'à 0°, « la valeur actée ». Depuis Q28 (2026-09-25), le lacet par défaut est 45° partout, en
  ligne compris : la phrase décrit un état passé comme présent — le défaut exact contre lequel CLAUDE.md met en garde.
  (`grep -n "lacet 0°\|valeur actée" camera_iso.gd`)
