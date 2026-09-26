# La fusée — Q34 = C et Q35 = B, sur image (session cloud « fusée », branche `claude/cloud-fusee`)

*27/09/2026, heure de Paris. Planche : [`planche.html`](planche.html) (autonome, images en chemins relatifs).*

## Pour Adrien, en cinq lignes

1. **Le rouge long fait ce que tu voulais à 3,5 s** : la fusée est encore au plein feu, point blanc, sol rouge, dans une fumée déjà pleine ; par défaut, à 3,5 s, elle est déjà passée à la braise orange.
2. **Mais le rouge du jeu reste un rouge corail clair**, pas le rouge sang de l'illustration : ~11° de teinte contre 353° sur l'illustration (18° vers l'orange).
3. **Après le plein feu, le point de braise sort JAUNE pâle, pas rouge** (230, 230, 146) — ce n'est pas ce que dit Q34 = C (« puis rouge »). Image : `defaut/a3_5-loupe.jpg`.
4. **Le noir est sali par la fumée** : torches éteintes, la fumée allume jusqu'à 48 000 pixels (jusqu'à 92/255) autour de la flaque de lumière, là où le sol est noir. C'est le masque de la fumée (Q31), éteint par défaut depuis le 26/09 à cause de son prix. Image : `defaut_noir_sali_long_a3_0.jpg`.
5. Le blanc du point dure un peu plus que le plein feu (encore blanc à 2,5 s par défaut, 0,5 s après la fin du plein feu). Rien n'a été changé dans le jeu : seulement un outil de photo et des mesures.

## Défauts vus, en tête (avec l'image)

### D1 — Le point de braise n'est pas rouge après le plein feu : il est jaune pâle
- Par défaut, à 3,0 s : (230, 216, 152) ; à 3,5, 4, 5 et 8 s : **(230, 230, 146)**, teinte 60°, saturation 0,37. Même chose avec le rouge long à 5 s (230, 216, 151) et 8 s. Images : `defaut/a3_5-loupe.jpg`, `defaut/a8_0-loupe.jpg`, `long/a8_0-loupe.jpg`.
- Q34 = C dit « presque blanc pendant le plein feu, puis rouge ». Le code (`iso_volumes.gd`, `_suivre_coeur_fusee`) donne au point **la couleur de la lumière**, qui à la braise est orange (température) — pas rouge. Et le halo est ADDITIF (`halo_iso.gdshader`, `blend_add`), posé sur un sol déjà orange, avec une intensité jusqu'à 1,5 : le rouge plafonne, le vert monte, le point vire au jaune. **Hypothèse** sur le mécanisme (je n'ai pas isolé le halo seul) ; le constat à l'image, lui, est sûr.
- Tous les points plafonnent à **230/255** (aucun pixel du point au-dessus) : un plafond de la sortie écran, que je n'ai pas cherché.
- À trancher par Adrien : « puis rouge » voulait-il dire la couleur de la lumière (orange à la braise) ? Si oui, c'est l'additif qui le jaunit ; sinon, c'est la couleur même qui est à revoir. **Rien corrigé ici** (hors de ma tâche, et un défaut du jeu se signale).

### D2 — Le noir sali par la fumée (masque de la fumée éteint par défaut)
- Protocole : torches ÉTEINTES, trois prises fumée coupée / rétablie / recoupée (celui de `loupe-fusee-masque-preuve`). Un pixel noir (0,0,0) dans les **deux** prises coupées et allumé dans la rétablie = la fumée allume hors de la lumière.
- Résultat : **à chaque âge, dans les deux variantes, de 6 500 à 48 000 pixels**, tous (à 4 près) dans le disque de fumée, jusqu'à 92/255. Carte : `defaut_noir_sali_long_a3_0.jpg` (à gauche, la prise fumée rétablie, gain ×6 ; à droite, gris = sol allumé sans fumée, **rouge = pixels noirs sans fumée, allumés avec**) : une couronne rouge autour de la flaque de lumière.
- C'est la question Q31 : le masque de la fumée l'efface (preuve à l'image acquise), il est **ÉTEINT par défaut depuis le 26/09 23:29** (prix 0,863 de la cadence sur l'état intégré). Je l'ai gardé éteint, comme demandé. **Le rouge long n'aggrave rien de ce côté** : aux mêmes âges, mêmes ordres de grandeur (la fumée est la même, voir plus bas).

### D3 — Le point blanc dure plus que le plein feu
- Par défaut, à 2,5 s (0,5 s après la fin du plein feu) le point est encore (230, 230, 229) ; il n'a bougé qu'à 3,0 s. Le blanc suit l'énergie relative (`smoothstep(0.6, 0.95, relative)`), qui glisse vers la braise en 1,5 s (`RACCORD_PLEIN_FEU_BRAISE`) ; plus l'écrêtage de l'additif. Donc « blanc 2 s » est en fait ~2,5 s et plus (non mesuré au dixième). Avec le rouge long, même glissement après 4 s (blanc à 4,0, jaune-orangé à 5,0).

### Pas vu
- **Point absent** : non, présent à tous les âges, dans les deux variantes.
- **Âge faux** : non (voir « L'âge vérifié »), à une nuance d'arrondi près à 4,0 s.

## Ce que montre la planche

Vue de J1, lacet 45° (J2 en B), zoom ×1,5, 1920×1080, carte du Cloître (la carte de la loupe), fusée posée dans le noir à 377 px de J1, hors de sa torche. Loupe ×3 = 640×360 autour de la fusée, agrandis au plus proche. Dans chaque ligne : illustration | défaut (Q34) | `--fusee-rouge-long` (Q35).

| âge | défaut : acte, énergie | sol teinte / sat. | point | rouge long : acte, énergie | sol teinte / sat. | point | fumée α |
|---|---|---|---|---|---|---|---|
| 0,5 | plein feu 1,0 | 3,9° / 0,65 | blanc | plein feu 1,0 | 3,9° / 0,65 | blanc | 0,17 |
| 1,5 | plein feu 1,0 | 12,4° / 0,65 | blanc | plein feu 1,0 | 12,4° / 0,65 | blanc | 0,50 |
| 2,5 | braise 0,8 | 14,9° / 0,69 | blanc | plein feu 1,0 | 8,1° / 0,68 | blanc | 0,83 |
| 3,0 | braise 0,6 | 19,4° / 0,71 | (230,216,152) | plein feu 1,0 | 7,8° / 0,68 | blanc | 1,00 |
| **3,5** | **braise 0,4** | **24,5° / 0,71** | **jaune (230,230,146)** | **plein feu 1,0** | **11,5° / 0,67** | **blanc** | **1,00** |
| 4,0 | braise 0,4 | 24,7° / 0,71 | jaune | plein feu 1,0 (dernier pas) | 13,7° / 0,66 | blanc | 1,00 |
| 5,0 | braise 0,4 | 24,6° / 0,73 | jaune | braise 0,6 | 19,3° / 0,72 | (230,216,151) | 1,00 |
| 8,0 | braise 0,4 | 25,3° / 0,70 | jaune | braise 0,4 | 25,3° / 0,70 | jaune | 1,00 |

« blanc » = (230, 230, 229). Illustration, même mesure sur son sol éclairé (x 240-560, y 480-560 de l'image 1024×640) : **teinte 353,3°, saturation 0,69** ; cœur de la flamme (255, 255, 255).

**Lecture.** À 3,5 s le rouge long donne ce que l'illustration montre dans sa structure — le plein feu, le point blanc, la fumée à son opacité pleine (α 1,0) — alors que le défaut y est à la braise orange (24,5°). La saturation est celle de l'illustration (0,67 contre 0,69). **La teinte, non** : 11,5° contre 353° (18° vers l'orange), et la luminance du sol rouge est haute (le rouge du jeu est clair, corail, là où l'illustration est sombre et profonde). La ROADMAP (ISO13, « Les 8° vers l'orange ») en donne la cause côté lumière 2D ; sous la fumée pleine j'en mesure 8 à 14°, plus que ses 5,5° sous la fusée seule.

**La fumée est la même dans les deux variantes, à chaque âge** : α et rayon identiques au millième (0,167 / 201,3 px à 0,5 s … 1,0 / 220 px à 8 s). C'est la promesse de Q35 « à durée totale égale » (`echelle_fumee_a` rapporte l'âge à la durée de combustion), vérifiée à l'image. À 0,5, 1,5 et 8,0 s, les deux variantes donnent les **mêmes chiffres** — attendu : même acte, même énergie, même température.

**La « part de fumée visible »** (pixels du disque où la fumée change l'image d'au moins 4/255, torches éteintes) va de 10 % (0,5 s) à 42 % (rouge long, 4 s) ; au même âge, le rouge long en montre un peu plus (35 % contre 32 % à 3,5 s ; 42 contre 39 % à 4 s) — la même fumée, mieux éclairée.

## L'âge vérifié
- L'âge est piloté en **temps de jeu** : une seule fusée, posée à l'âge 0 (`forcer_age(0.0)`, l'atterrissage), vieillit par son propre `_physics_process` sous `--fixed-fps 60`, arrêtée à chaque âge le temps des prises puis relancée. L'âge est **lu** sur la fusée (`age_combustion()`), jamais écrit.
- Lu : 0,5 ; 1,5 ; 2,5 ; 2,99999999999999 ; 3,49999999999999 ; 3,99999999999999 ; 4,99999999999999 ; 7,99999999999998 (l'accumulation des 1/60 s). Donc **à « 4,0 s » l'image du rouge long montre le dernier pas du plein feu** (1e-14 s avant la bascule), pas la braise : le journal l'imprime (`PLEIN_FEU`).
- Sur l'image : défaut, point blanc et sol rouge (4-12°) jusqu'à 1,5 s, énergie 0,8 et sol qui vire (15°) à 2,5 s, orange (19-25°) ensuite ; rouge long, sol rouge (8-14°) et point blanc **jusqu'à 4,0 s**, orange à 5 s. Le plein feu dure bien 2 s par défaut et 4 s avec le drapeau ; le journal imprime « plein feu 2.0 s, braise 10.0 s, vie 20.0 s » puis « plein feu 4.0 s, braise 8.0 s, vie 20.0 s ».

## Décisions et leur pourquoi
- **Fusion d'`origin/iso11-menus`** (commit `889fdba`) : conflit dans `iso_volumes.gd` résolu en prenant le **commentaire et la valeur du masque de la fumée du côté intégré** (`masque_fumee := false`, ordre 416, décision du 26/09 23:29) et **ceux du point du côté iso11-menus** (`coeur_fusee := 2`, Q34). Le reste du `_init` (les drapeaux `--sans-fusee-coeur`, l'impression de l'état éteint du masque) avait fusionné seul. Conflit dans `docs/ROADMAP.md` : un ajout de chaque côté au même endroit des « Pièges connus » ; les deux gardés, rien écrit de plus.
- **Corrections du photographe** (0c67705 de `cloud-photographe`) appliquées en commit à part, comme demandé.
- **Un nouveau fichier d'outil** (`tools/loupe_fusee_ages.gd`) branché dans `tools/loupe.gd` par 8 lignes (une entrée de catalogue, un appel) plutôt que du code dans `loupe.gd` : sept branches tournent, et la surface de conflit reste minuscule.
- **La scène est celle de la loupe** (Cloître, fusée dans le noir hors de la torche de J1), pas celle de l'illustration (un couloir, des murs éclairés) : c'est le cadrage « la fusée posée, vue par le joueur » demandé, et c'est une scène déjà outillée (lieux dans le noir, projection de la caméra).
- **Le noir se mesure torches éteintes et en trois prises (A, B, A')**. Premier passage en deux prises : des dizaines de milliers de « fuites » partout dans l'écran, au bord des taches noires de l'environnement — ce qui bouge seul d'une image à l'autre (le bandeau LED respire, voir plus bas). Exiger A et A' noirs les écarte (compté à part : « instables »).
- **Le bandeau LED des murs respire (allumé par défaut)** et je l'ai laissé respirer : c'est le jeu par défaut. Conséquence : la luminance du sol et la part de fumée varient d'un âge à l'autre sans que la fusée change (à énergie constante 0,4, luminance 98 / 104 / 70 / 110). **Les deux variantes, au même âge, sont au même instant de jeu** (mêmes chiffres à 0,5, 1,5 et 8 s) : la comparaison Q34 / Q35 à âge égal est juste ; la comparaison entre âges mêle la respiration. `--led-murs-fige` la tiendrait.
- **Pas de pull request** : la consigne de la session coordinatrice l'interdit (elle publie à partir de la branche).

## Pièges découverts, à reporter dans la feuille de route
1. **Une seule image « joueur » n'a AUCUN pixel noir** (0 sur 2 073 600 à tous les âges) : le voile d'éblouissement de J1 (0,06, sa torche) soulève tout l'écran. Tout compte du noir absolu se fait torches éteintes — la leçon de `loupe-fusee-bord-noir`, qui revient ici.
2. **Deux prises successives torches éteintes ne sont pas comparables au pixel** : le bandeau LED respire. Une paire A/B « fumée coupée / rétablie » compte cette respiration comme une fuite ; il faut A, B, A' (ou `--led-murs-fige`).
3. **Un âge de fusée atteint par pas de 1/60 s s'arrête juste AVANT les bornes entières** (3,99999999999999) : une prise « à 4,0 s » tombe dans l'acte d'avant. À dire sur toute planche par âges, ou viser un demi-pas au-delà.
4. **Le plan de loupe écrit dans `user://`, le chemin de la tâche disait `assets/ui_illustrations/ill_creer_ligne.png`** : l'illustration est `assets/ui/ill_creer_ligne.png`.
5. **`run_photos.sh` sort en 0 sur une erreur d'exécution de script** (`SCRIPT ERROR` au premier passage : l'argument typé `Node` d'un `RefCounted`) : il ne détecte que les erreurs d'analyse. Premier passage « réussi » sans une image. Signalé, non corrigé (hors tâche) : `tools/run_photos.sh`, ligne du `grep -qE 'Parse Error|Failed to load script'`.

## Hors tâche, signalé
- `tools/banc_equite_fusee.gd.uid` et `volume_masque.gdshaderinc.uid` sont générés par l'import mais pas dans le dépôt (venus d'iso11-menus sans leur `.uid`). Non committés ici.

## Refaire
```bash
git checkout claude/cloud-fusee
godot --headless --path . --import
# les deux passages (≈ 20 min chacun dans le cloud ; en parallèle, ils ne se gênent pas : horloge fixe)
for v in defaut long; do
  extra=""; [ $v = long ] && extra="--fusee-rouge-long"
  xvfb-run -a -s "-screen 0 1920x1080x24" env GODOT=/usr/local/bin/godot GODOT_ARGS="--fixed-fps 60" \
    ./tools/run_photos.sh --plan=loupe-fusee-ages --taille=1920x1080 --zoom=1.5 --lacet=45 \
    --sortie=user://fusee-$v $extra > /tmp/fusee-$v.log 2>&1
done
U="$HOME/.local/share/godot/app_userdata/Candela 2D"      # Mac : ~/Library/Application Support/Godot/app_userdata/Candela 2D
pip install pillow numpy
python3 docs/iso/cloud/fusee/mesurer.py --variante "defaut=/tmp/fusee-defaut.log,$U/fusee-defaut" \
  --variante "long=/tmp/fusee-long.log,$U/fusee-long" --sortie docs/iso/cloud/fusee
```
Au Mac, sans Xvfb : `GODOT_ARGS="--fixed-fps 60" ./tools/run_photos.sh --plan=loupe-fusee-ages --zoom=1.5 --lacet=45 …` (l'horloge fixe reste nécessaire pour que l'âge soit piloté en pas de jeu comptés).

Fichiers : `defaut/` et `long/` — `aX_Y-loupe.jpg` (loupe ×3), `aX_Y-plein.jpg` (fenêtre entière, vue de J1), `aX_Y-noir.jpg` (torches éteintes, fumée rétablie) ; `illustration.jpg` ; `mesures.json` (tout, y compris la géométrie à l'écran) ; `defaut_noir_sali_long_a3_0.jpg`.

## Ce que je n'ai PAS pu prouver
- **Rien sur la cadence** (rendu logiciel ; interdit ici) : la cadence sous fusée au pompe reste à faire au Mac.
- **Rien sur l'éblouissement** : le cloud ne le rend pas fidèlement ; la seule chose sûre est que J1 était à 0,06 à chaque prise (sa torche), le même dans les deux variantes.
- **Les couleurs à ~1/255 près du Mac** seulement : les teintes du tableau sont celles du rendu llvmpipe.
- **Le mécanisme exact du point jaune** (D1) : hypothèse (additif + couleur orange de la lumière), non isolée.
- **La scène de l'illustration** (fusée tenue, près de murs éclairés) n'est pas reproduite : la comparaison se fait sur la fusée posée, sur un sol, comme demandé ; les teintes du sol se comparent, pas les compositions.
- **Le masque de la fumée allumé** n'a pas été photographié ici (hors tâche : il est éteint par défaut, et sa preuve existe déjà).
- La suite complète : voir la ligne suivante.

## Suite
*(en cours)*
