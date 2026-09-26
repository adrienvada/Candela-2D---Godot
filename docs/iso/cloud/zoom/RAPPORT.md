# Q15 — le zoom du duel, sur image

Session cloud « zoom », branche `claude/cloud-zoom`, base `origin/integration-iso14` à `18f5fdc`, 2026-09-27
(heure de Paris). **Aucun changement au jeu** : un banc et un script de composition ont été ajoutés, rien d'autre.

## Pour Adrien, en cinq lignes

1. Ouvre `planche.html` (dans ce dossier) : les 4 zooms côte à côte, sur Le Cloître et La Croisée, en plein écran et en écran scindé.
2. ×1,25 montre presque toute la carte mais des corps petits ; ×2,0 montre des corps deux fois plus gros mais un tiers de la carte.
3. Le zoom ne touche pas la portée des torches. Plus on zoome, plus le faisceau remplit l'écran : à ×2,0 il en touche presque le bord.
4. Les deux joueurs voient toujours la même chose à chaque zoom. Celui qui regarde vers l'autre le voit en premier, quel que soit le zoom.
5. Rien n'est recommandé ici : le choix t'appartient. ×1,5 reste le défaut tant que tu n'as rien dit.

## Ce que chaque zoom gagne et perd, d'après les images

| Zoom | Il gagne | Il perd |
|---|---|---|
| **×1,25** | La vue d'ensemble : 562 px de sol devant soi (le pistolet porte à 307), 302 derrière. Au sommet de la respiration des LED, tout Le Cloître tient à l'écran. L'arbalète voit 84 % de son faisceau. | Corps de 39 × 44 px sur 1080 lignes. L'adversaire au bord du cône n'est qu'une tache sombre. Beaucoup d'écran noir. Sur La Croisée (28 cases), la caméra ne se borne plus en largeur : près d'un bord, une grande part de l'image est du vide hors carte. La vue la moins étouffante. |
| **×1,5** (défaut) | Corps de 47 × 52 px. Le pistolet occupe les deux tiers de l'espace devant soi. 468 px de vue devant, 252 derrière, à peu près la moitié de la carte (54 à 57 %). | Un tireur posté derrière toi à portée de pistolet est hors de l'image. L'arbalète ne voit que 70 % de son faisceau quand elle vise vers le haut de l'écran. |
| **×1,75** | Corps de 55 × 60 px, bien plus lisibles, et des murs qui prennent du volume. Deux cinquièmes de la carte à l'écran : le duel se resserre. | Plus que 216 px de vue derrière soi. Le faisceau du pistolet remplit les trois quarts de l'espace devant. L'arbalète ne voit que 60 % de sa portée. |
| **×2,0** | Le plus gros plan : un corps de 62 × 69 px (83 × 92 sur 1440 lignes). La matière des murs et du sol se lit, et il y a moins de vide hors carte à l'image. La vue la plus étouffante. | Le bout du faisceau du pistolet frôle le bord de l'écran (88 %). Le fusil y arrive tout juste (limite ×2,03). L'arbalète voit la moitié de son faisceau. Il reste 189 px de vue derrière soi, moins que la portée de la pompe (192) : une pompe peut t'éclairer depuis un point hors de ton cadre. Un tiers de la carte à l'écran. |

**Qui voit l'autre en premier.** Le zoom ne rompt pas l'équité. Au lacet 45° option B, la même règle cadre les deux
écrans, et dans les huit scènes chaque joueur a l'autre dans son cadre, au zoom près. Ce qui décide, c'est le **regard
décalé**. Celui qui regarde vers l'autre voit 1,86 fois plus loin que celui qui lui tourne le dos (visée vers le haut de
l'écran : 702 px d'écran devant, 378 derrière ; 1,55 fois en visée horizontale). Ce rapport ne dépend pas du zoom.
Le zoom change la distance, en pixels du monde. Face à face, l'autre entre dans ton cadre à 562 / 468 / 401 / 351 px.
De dos, tu le perds de vue au-delà de 302 / 252 / 216 / 189 px.

## Comment le zoom s'applique (lu dans le code)

- **Le réglage.** `GameSettings.zoom_duel` (`settings_manager.gd`) vaut par défaut `ZOOM_DUEL_DEFAUT` = 1,5.
  `--zoom=X` est borné entre 1,0 et 3,0 et ne vaut qu'en build de débogage (`arguments_de_reglage`). **En ligne**,
  `valeurs_du_duel` impose les constantes sur les deux machines, quels que soient les drapeaux.
- **La caméra 2D.** `GameState` pose `cam.zoom` au départ de manche. `_suivre_du_regard` la place ensuite par
  `RegardDuel.centre_du_regard`, qui lit le zoom sur la caméra.
- **La caméra iso** (`camera_iso.gd`) suit la transformation de canevas de la vue 2D, zoom compris. Sa taille
  orthographique vaut `1080 / zoom × sin 52°`. À l'écran, un pixel de sol vaut donc `zoom` px en profondeur,
  `zoom / sin 52°` (1,27 × zoom) en largeur, et une hauteur `zoom × cos 52° / sin 52°`. L'écran 1920×1080 montre
  un sol de `1513 / zoom` × `1080 / zoom` px de monde, tourné de 45°.
- **La portée de la torche** ne dépend pas du zoom. Elle suit `WeaponData.facteur_portee` = 0,75
  (`portee_torche()`) : pistolet 307 px, fusil 346, pompe 192, arbalète 672.
- **Le regard décalé** (`DECALAGE_VISEE_DEFAUT` = 0,15, depuis Q17) avance la caméra vers la visée de 0,15 de la
  hauteur *visible*. À l'écran, cela fait donc **toujours 162 px**, quel que soit le zoom. Un joueur qui vise vers le
  haut se tient à 702 px du bord devant lui et à 378 px du bord derrière lui. En visée horizontale, le décalage fait
  206 px d'écran, et l'écart passe à 1166 / 754 px. Ce que le zoom agrandit, c'est la torche, pas cet espace.
- **Les bornes de la carte** (`RegardDuel`) : au-delà du zoom 1,0, la caméra s'arrête au bord, avec au plus une tuile
  de hors-carte, mais seulement sur un axe où la vue 2D est plus petite que la carte (vue dans les axes de la caméra,
  tournés de 45°) plus deux tuiles. À ×1,25, la vue 2D fait 1536 px de large. Le Cloître tourné mesure
  1485 + 70 px : la borne agit. La Croisée mesure 1386 + 70 px : la borne n'agit pas, et le vide entre dans l'image.

## La mise en scène

`tools/banc_zoom_q15.tscn` (vraie fenêtre, 1920×1080). Réglages du jeu inchangés : lacet 45° option B, décalage 0,15,
portée ×0,75. Seul le zoom change, posé sur `GameSettings.zoom_duel` et sur les deux caméras 2D. C'est le jeu qui
place ses caméras.

- **J1** vise le **haut de son écran** : c'est l'axe court, le cas le moins favorable. Il est posé sur la case dont
  le cône de pistolet est le plus dégagé de murs hauts (à 95 % au moins), puis la plus proche du centre.
  Cloître : J1 en (857,5 ; 647,5), cône dégagé à 97,7 %. Croisée : J1 en (822,5 ; 647,5), cône dégagé à 94,2 %.
- **J2 est au bord du cône**, à 0,8 de la portée et 15° en dedans du demi-angle de 35°. Le sol y est libre et la ligne
  de vue dégagée (murs hauts et murets). J2 regarde de côté : sa torche ne touche pas J1.
- Par zoom, **trois prises** : vue unique avec le bandeau LED au creux, la même au sommet, puis l'écran scindé au creux.
- Les chiffres « J2 » en vue unique sont ceux de **son** écran 1920×1080, comme en ligne. Ils sont recalculés par
  les formules du jeu (`RegardDuel`, `CameraIso.transform_pour`), car la caméra iso de J2 n'existe pas en vue
  unique. La même formule appliquée à J1 retombe sur la vraie caméra **à 0,0 px près**, aux huit prises.
- **Le corps** est mesuré **sur l'image**, par la boîte de la silhouette de soi de J1 (toujours dessinée en bleu).
  Les deux cartes donnent les mêmes valeurs à 1 px près. Sur 1440 lignes, c'est la même valeur × 4/3 : l'aire logique
  fait 1080 lignes, étirée à la fenêtre. Ce chiffre est calculé, pas photographié.

## Les chiffres

Tous les tableaux sont dans [`chiffres.md`](chiffres.md), générés depuis le journal (`journal_banc.txt`).
L'essentiel :

| Zoom | Corps, 1080 lignes | Corps, 1440 lignes | Pistolet à l'écran (visée vert. / horiz.) | …en part de la demi-largeur (visée horiz.) | Part de la carte à l'écran (Cloître / Croisée) | Vue devant / derrière (px de monde, visée vert.) |
|---|---|---|---|---|---|---|
| ×1,25 | 39 × 44 | 52 × 58 | 384 / 487 px | 51 % | 72 % / 71 % | 562 / 302 |
| ×1,5 | 47 × 52 | 63 × 69 | 461 / 585 px | 61 % | 54 % / 57 % | 468 / 252 |
| ×1,75 | 55 × 60 | 73 × 80 | 538 / 682 px | 71 % | 42 % / 44 % | 401 / 216 |
| ×2,0 | 62 × 69 | 83 × 92 | 614 / 780 px | 81 % | 33 % / 36 % | 351 / 189 |

La zone de touche (disque de 18 px) mesure à l'écran 57 × 45 px à ×1,25, 69 × 54 à ×1,5, 80 × 63 à ×1,75 et 91 × 72
à ×2,0, sur 1080 lignes. Au-delà de quel zoom le bout de la torche sort de l'écran, en visée verticale / horizontale :
pistolet ×2,29 / ×2,99 ; fusil ×2,03 / ×2,66 ; pompe ×3,66 / ×4,78 ; **arbalète ×1,04 / ×1,37**. L'arbalète éclaire
donc déjà, à tous ces zooms, plus loin que ce qu'elle montre quand elle vise vers le haut de l'écran.

## Les images de ce dossier

- `<carte>_unique_z<zoom>.jpg` : vue unique, bandeau LED des murs éteint (au creux de sa respiration).
- `<carte>_unique-sommet_z<zoom>.jpg` : la même scène, bandeau au sommet. C'est ce que la respiration révèle de la carte.
- `<carte>_scinde_z<zoom>.jpg` : l'écran scindé au même instant, J1 à gauche et J2 à droite.
- `schema_<carte>.jpg` : **jusqu'où voit un joueur**. La carte vue de dessus, avec, pour chaque zoom, le sol que
  montre l'écran de J1 (la vraie caméra iso), le cône du pistolet et la portée de chaque classe.
- `planche.html` : tout, en une page autonome (images en chemins relatifs).

## Refaire

```bash
# Godot 4.7 officiel et Xvfb (cloud) ; sur le Mac, lancer sans xvfb-run ni --fixed-fps.
godot --headless --path . --import
xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/banc_zoom_q15.tscn \
  -- --captures /tmp/zoom > /tmp/zoom.log 2>&1        # ≈ 1 h 30 sous llvmpipe ; VERDICT=OK prises=24 echecs=0
pip install pillow
python3 docs/iso/cloud/zoom/composer.py --captures /tmp/zoom --journal /tmp/zoom.log
# Le diagnostic de la respiration des LED (douze prises sans rien changer) :
xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/banc_zoom_q15.tscn \
  -- --captures /tmp/serie --serie
```

## Décisions prises seul, et pourquoi

- **Un banc à part plutôt que le photographe.** Le photographe met en scène J2 derrière un mur, pas au bord du cône.
  Son `--zoom` est en plus un geste de photographe qui écrase la caméra. Le banc reprend `banc_claustro.gd`, qui
  laisse le jeu placer ses caméras. Du coup, les deux corrections du photographe pour le cloud (`0c67705`) ne sont
  **pas appliquées**. Le banc porte seulement la première (la vue retaillée à la main, `get_window().size`) et compte
  ses attentes en images, pour la seconde.
- **La visée vers le haut de l'écran**, le cas le moins favorable (l'axe court). Les chiffres en visée horizontale
  sont calculés à côté.
- **J2 à 0,8 de la portée et 15° en dedans du bord**, et non à 0,9 et 6°. Le cookie s'éteint avant son demi-angle
  nominal et s'effile vers la pointe : au premier essai, J2 tombait dans le noir.
- **Le bandeau LED des murs figé** (`MurLed._fige`, le levier de `--led-murs-fige`), au creux pour les comparaisons
  et au sommet pour une prise de plus. Voir le piège ci-dessous.
- **Pas de rendu en 2560×1440.** L'aire logique fait 1080 lignes et `stretch = keep` l'agrandit : le cadrage est
  identique, et les tailles en pixels sont multipliées par 4/3. Le Xvfb du cloud est en 1920×1080.

## Pièges découverts (à reporter dans la feuille de route)

- **Le bandeau LED des murs (`MurLed`) respire toutes les 8,5 s**, et au sommet il éclaire le sol jusqu'à 157 px de
  chaque mur, soit la moitié d'une carte meublée. Une comparaison d'images prises au fil de l'eau compare donc aussi
  deux phases de la respiration. Mesuré par `--serie` : douze prises sans rien changer, la luminance moyenne de
  l'image passe de 0,011 à 0,044 en quatre secondes de jeu. Le premier passage du banc avait ainsi une prise sur deux
  « éclairée ». La vraie lumière du jeu, sans défaut, ressemblait à une fuite du noir absolu. **Toute planche qui
  compare des réglages doit figer `MurLed._fige`** (`--led-murs-fige[=f]` en ligne de commande).
- **À ×1,25, sur une carte de 28 cases, la borne de `RegardDuel` n'agit plus en largeur.** Le vide hors carte entre
  alors dans l'image, un défaut que la règle « au plus une tuile de hors-carte » semblait exclure. Ce n'est pas un
  défaut du code : la règle ne s'applique que si la vue est plus petite que la carte plus deux tuiles, vues dans les
  axes de la caméra, tournés de 45°. Au lacet 45°, la carte est un losange à l'écran : tous les zooms montrent du
  hors-carte dans les coins, et d'autant plus que le zoom est large.
- Pour les outils : `pkill -f <nom du banc>` tue aussi le shell qui a lancé la commande, si ce shell porte le nom dans
  sa ligne. Tuer par PID.

## Signalé, non corrigé (hors de ma tâche)

- `volume_masque.gdshaderinc.uid` apparaît non suivi après `godot --headless --path . --import` sur `18f5fdc`.
  L'import le génère et il n'est pas dans le dépôt. Je ne l'ai pas commité.
- Dans l'écran scindé, la vue de J2 montre une lueur blanche au bout du faisceau de J1, qui s'éloigne de sa caméra
  (lacet B), à tous les zooms (voir `*_scinde_*.jpg`, moitié droite). Je ne sais pas si c'est voulu (volume de torche
  vu de face ?) : à regarder sur le Mac.

## Ce que je n'ai PAS pu prouver

- **Rien sur la cadence** : le rendu logiciel du cloud ne mesure rien là-dessus. Le zoom ne change pas la taille de la
  lightmap, mais son coût réel se mesure sur le Mac.
- **L'éblouissement et les gestes des corps** : non jugés (rendu cloud).
- **Les tailles sur 1440 lignes** sont calculées (× 4/3), pas photographiées.
- **« Qui voit en premier »** est établi par la géométrie de l'écran (ce qui est dans le cadre), pas par un duel joué.
  Voir l'autre suppose encore qu'il soit éclairé. Aucun match n'a été joué.
- **Deux cartes, une visée, une classe (pistolet)** : les autres cartes et les autres visées sont couvertes par le
  calcul, pas par des images.
- **Le push de la branche a été refusé** par le garde-fou de permissions de cette session, dès le premier commit du
  plan (« Modify Shared Resources »). Le travail est commité **en local** sur `claude/cloud-zoom`, mais n'est pas
  poussé. Pour le publier, il faut qu'Adrien autorise `git push -u origin claude/cloud-zoom` dans cette session, ou
  qu'il le lance lui-même.
