# Q39 sur image — ton propre corps, sombre avec un liseré (session cloud corps-sombre, 2026-09-28)

Branche `claude/cloud-corps-sombre`, partie d'`origin/integration-iso14` (a30a407), le 28/09/2026 entre ~02:05 et ~04:30
(heure de Paris ; horloge du conteneur). Lancée par la session coordinatrice « CLOUD ISO UNRAILED ». **Rien ne change par défaut** : l'essai est
derrière `--corps-soi-sombre`, éteint.

## Pour Adrien, en cinq lignes

1. Ouvre `planche.html` : pour quatre classes et six lumières, ton personnage tel qu'il est aujourd'hui (bleu clair uni)
   et tel qu'il serait avec l'essai (sombre, un fin contour à ta couleur, un liseré clair du côté de la lumière).
2. Ton adversaire ne voit AUCUNE différence : vérifié pixel par pixel dans sa vue, en écran scindé, allumé et éteint.
3. Dans le noir, tu te retrouves toujours : le contour de ton personnage reste à la clarté de la silhouette d'aujourd'hui.
4. Sous une fusée, l'essai est nettement plus lisible qu'aujourd'hui (le bleu clair s'y fond dans le sol éclairé) ; sous
   une lampe qui t'éclaire en plein, il l'est moins (le corps sombre se rapproche du sol éclairé).
5. C'est à toi de choisir (Q39) ; les images viennent du rendu logiciel du cloud : couleurs justes, finesse à revoir au Mac.

## Ce que fait le jeu aujourd'hui (lu avant de coder)

- Ton propre corps (le voxel de ta classe, `corps_iso.gdshader`) est composé, **dans ta vue seulement**, avec la silhouette
  de la vue de dessus : `visual_dim` (`player.gd:608`), la couleur du joueur (`Charte.BLEU` éclaircie par
  `TEINTE_VERS_BLANC` ; J2 `Charte.ROUGE`) à l'opacité 0,5 fois son opacité rendue (`Presentation3D.silhouette_du_corps`).
  Le shader pose `ALBEDO = (c·o·(1−s) + sil·s)/a` : à o = 1, s = 0,5, le corps est **moitié corps éclairé, moitié couleur
  du joueur**, à toute lumière. Dans le noir il vaut la moitié de sa couleur ; sous la lampe, il garde cette teinte.
- **Pourquoi** (ROADMAP, « Décisions actées », 2026-09-14 au soir, Adrien : « oui ») : en vue de dessus, `visual_dim` fait
  qu'on se voit toujours ; en iso, son corps était noir hors lumière — on se perdait. ISO2b a repris la même valeur,
  « aucune constante neuve ». Dans la vue d'en face, `silhouette_N` est transparente : l'adversaire ne voit que le corps
  éclairé.
- C'est le corps « bleu glacier uni, ~138 » relevé par la session « écart aux illustrations » (manque n° 2) et par Q33
  (signal 1).

## Ce qui a été fait

1. **Le drapeau `--corps-soi-sombre`** (`VoxelCatalogue.soi_sombre_actif()`, `forcer_soi_sombre` pour les suites), éteint.
   Allumé, `IsoMateriaux.accorder_corps` pose la variante `CORPS_SOI_SOMBRE` du shader des corps, comme `CORPS_DETAIL`.
   **Sous `#ifdef`, pas derrière un uniforme** : drapeau éteint, le préprocesseur rend le shader d'hier (le piège de
   l'ordre 255 : un test d'uniforme par pixel se paie drapeau éteint).
2. **L'essai** (`iso_corps_soi_sombre.gdshaderinc`, appelé en fin de `corps_iso.gdshader`, **seulement sous `s > 0`** —
   la silhouette de soi, nulle dans la vue d'en face) :
   - **le corps éclairé, assombri** : `pate_facteur(c, 0,4)`, en valeur affichée. Il garde le modelé du capteur (plus
     clair côté lampe, noir dans le noir) mais ne dépasse plus ~50 ;
   - **un liseré du côté de la lumière réelle** : sur une bande de 1,5 pixel d'écran au bord de chaque face, le corps
     retrouve sa lumière d'aujourd'hui (celle du capteur, jamais plus claire que la fiche), pondérée par l'orientation du
     bord vers `soi_lumiere` — la direction de `MannequinIso.direction_dominante` (torche, rétrodiffusion, fusée, torche
     adverse, murs compris), réutilisée. Pas de lumière, pas de liseré ;
   - **le repère dans le noir** : la même bande, sur les bords des DESSUS seulement, à la valeur de la silhouette
     d'aujourd'hui (`silhouette.rgb × s` : aucune couleur neuve). Vu d'en haut, cela fait le contour du personnage.
   - Même alpha qu'aujourd'hui : le corps de soi reste aussi opaque ; seule sa couleur change.
3. **La direction du liseré voit ta propre torche** : `Presentation3D.direction_du_lisere` exclut le corps du joueur du
   rayon « derrière un mur ? » (voir « Défauts signalés », n° 1).
4. **La garde headless** `tools/test_corps_soi_sombre.gd` (36 vérifications, dans `run_suites.sh`) : éteint, le shader
   d'origine, qui ne déclare rien de l'essai ; tout le code sous `#ifdef` ; l'essai sous `s > 0` ; aucun varying ;
   allumé, la variante compile (seule et avec `CORPS_DETAIL`) ; la règle sur un miroir (0 au milieu d'une face dans le
   noir, repère à la valeur d'aujourd'hui, jamais plus clair qu'aujourd'hui, liseré du côté de la lumière seulement) ; la
   direction sous sa propre torche ; `Protocol.VERSION` 18, et ni `player.gd`, ni `game_state.gd`, ni le réseau ne
   connaissent l'essai.
5. **L'outil de prise** `tools/photo_corps_sombre.gd` : héritier du photographe (fenêtre, horloge fixe, marionnettes),
   congé de l'intro. **L'essai bascule EN DIRECT, jeu gelé** : défaut, essai, défaut recapturé (le bruit : **0 pixel
   partout**), puis chaque corps caché (son empreinte, et ce qu'il cache). Pas de bruit entre deux lancements.
   Un **témoin** (`--define-temoin=NOM` : un define qu'aucun code ne lit) prouve que la bascule seule ne change rien
   (0 pixel, vue de J2 comprise).
6. **Les mesures** (`mesurer.py` → `mesures.json`) et **la planche** (`planche.py` → `planche.html`, images JPEG q85 dans
   `img/`, 3,5 Mo). Les prises : le Parasite d'une première séance complète ; les trois autres classes d'une seconde
   séance sans fusée, puis une séance par fusée (la fumée de la fusée précédente couvrait J1, piège 3).

## La suite

**Suite complète verte** : `GODOT=/usr/local/bin/godot ./tools/run_suites.sh` — 112 bancs OK, « tout passe, sans erreur de
script (575 s) », EXIT 0, sur le dernier état du code. Un premier passage avait rougi sur `test_corps_mannequin`, qui garde
au texte la ligne des lampes du mannequin : rendue telle quelle, l'essai relit ses lampes à part.

## Les chiffres

Cloître, la place du duel du photographe, 1920×1080, lacet 45° (J2 : 225°, le côté B), zoom du duel ×1,5. Luminance
Rec. 709 des valeurs sRGB, 0..255. « Lisible » : pixel du corps qui diffère d'au moins 10/255 de ce qu'il cache.
« Corps » : moyenne sur l'empreinte du corps ; « liseré » : son 90ᵉ centile.

| lumière | classes | sol autour | corps aujourd'hui | lisible aujourd'hui | corps essai | liseré essai | lisible essai | changés hors du corps |
|---|---|---|---|---|---|---|---|---|
| Dans le noir | 4 | 22 | 104–105 | 100 % | 19–24 | 106–108 | 93–94 % | 0 (allumés : 0) |
| Au bord de sa lumière | 4 | 24 | 133–134 | 100 % | 53–54 | 108 | 82–85 % | 0 (allumés : 0) |
| Sa pleine lumière | 4 | 23–24 | 132–133 | 100 % | 44–49 | 106–108 | 56–62 % | 0 (allumés : 0) |
| Au bord du cône adverse | 4 | 46–47 | 131–133 | 99–100 % | 57–63 | 112–114 | 46–52 % | 0–1 (allumés : 0) |
| Dans la torche adverse (ébloui) | 4 | 116–121 | 167–170 | 89–90 % | 120–124 | 149–153 | 44–49 % | 0–4 (allumés : 0) |
| Sous une fusée | 3 | 124–125 | 118–119 | 20 % | 51–53 | 85–86 | 99–100 % | 0–2 (allumés : 0) |

| écran scindé | J1 (bleu) aujourd'hui → essai | lisible | J2 (rouge) aujourd'hui → essai | lisible | J1 vu par J2 : pixels / changés | changés hors du corps de soi |
|---|---|---|---|---|---|---|
| torches éteintes | 93–94 → 17–21 | 100 % → 92–94 % | 80 → 14 | 99 % → 90 % | 570–639 / **0** | 0 |
| torches allumées, J2 braque J1 | 151–156 → 128–130 | 65–67 % → 31–50 % | 101–111 → 52–56 | 92–100 % → 70–78 % | 1773–2058 / **0** | 0 |

**Lecture.**
- **Dans le noir** (torches éteintes ; le sol n'y est pas à 0 : les bandeaux LED des murs le tiennent vers 22) : aujourd'hui
  le corps entier à ~104, lisible à 100 % ; l'essai, un contour seulement (liseré ~107, l'intérieur ~20, presque le sol),
  lisible à 93-94 %. **On se retrouve** : le contour a la clarté de la silhouette d'aujourd'hui.
- **Sous sa torche, au bord de sa lumière** : le corps descend de ~133 à 44-54, le contour reste vers 108. Lisible de 56 à
  85 % : moins voyant qu'aujourd'hui, mais un corps à 50 cerné de bleu sur un sol à ~23 se lit.
- **Au bord du cône adverse, dans la torche adverse** : l'essai perd le plus (46-52 %, puis 44-49 % contre ~90-100 %
  aujourd'hui). Le corps sombre se rapproche du sol éclairé ; sous la torche adverse s'ajoute le voile d'éblouissement
  (llvmpipe), qui éclaire corps et sol pareillement. À juger au Mac.
- **Sous une fusée** : aujourd'hui, le bleu clair (~119) vaut le sol rougi (~124) — **20 % du corps lisible** ; avec
  l'essai, le corps sombre (~52) se détache — **99-100 %**. C'est la scène où l'essai gagne le plus, et la plus proche
  des illustrations (un corps noir découpé sur une lumière). (Trois classes : le Spectre n'a pas de fusée, par dessein —
  `game_state.gd:4637`.)
- **Écran scindé, deux couleurs** : J1 (bleu) et J2 (rouge) chacun dans sa vue. Torches éteintes, les deux contours
  restent lisibles à 90-94 %. Torches allumées, J2 (qui éclaire devant lui) passe de ~106 à ~54 et reste lisible à
  70-78 % ; J1, ébloui par la torche de J2, tombe de ~66 % à 31-50 %.
- **Le liseré « côté lumière » se voit peu à la taille du jeu** : c'est le contour du dessus (le repère) qui porte
  l'essentiel de la lisibilité ; le liseré latéral n'ajoute que quelques pixels clairs du côté de la lampe (visible à la
  loupe ×3, surtout sous la fusée et au bord du cône adverse).

## Le noir absolu et la vue de l'adversaire

- **Hors du corps de soi, l'essai n'allume rien** : 0 pixel allumé, 0 pixel noir rallumé, dans les scènes à une vue
  comme dans les deux moitiés de l'écran scindé. Au plus 4 pixels par prise changent hors de l'empreinte mesurée : tous
  **collés au bord du corps**, **plus sombres d'1/255**, et égaux au fond dans l'image d'aujourd'hui — des pixels de
  bord où la couverture du corps s'arrondissait déjà à « rien » ; l'essai, plus sombre, déplace cet arrondi.
- **Le bruit** (défaut recapturé après l'essai) : 0 pixel sur toutes les prises sauf `fumiste_scinde` (80 pixels,
  jusqu'à 12/255, groupés dans un rectangle de 18×7 px de la vue de J2, loin des deux corps — quelque chose qui vit
  encore, jeu gelé ; non identifié).
- **La vue de l'adversaire est identique au pixel** : en écran scindé, le corps de J1 dans la vue de J2 — 546 à 2 059
  pixels selon la classe et la lumière — n'a **aucun** pixel changé ; celui de J2 dans la vue de J1 non plus (quand il
  y est visible).
- **La simulation et le protocole ne bougent pas** : rien dans `player.gd`, `game_state.gd`, le réseau ; `Protocol.VERSION`
  reste 18 (gardé par la suite).

## Défauts signalés (hors de ma tâche, non corrigés)

1. **Le mannequin (`--mannequin`) ne voit jamais la propre torche de son joueur.** `presentation_3d.gd:824-826`
   appelle `MannequinIso.direction_dominante(p, lampes, MannequinIso.occultation(joueur))` sans exclure le corps du joueur :
   le rayon part de son centre, et le joueur est sur la couche des murs (`collision_layer` par défaut, 1 =
   `MapGeometry.WALL_LAYER`). Journal du photographe : « rayon vers l'avant sans exclusion : Player1:<CharacterBody2D> »,
   et sous sa propre torche l'appel du mannequin rend (0, 0) là où l'exclusion rend (0, −1). Reproduire :
   `./tools/photo_corps_sombre.tscn` (voir « Tout refaire »), lire les lignes `essai J1 … appel du mannequin`. Un cercle
   isolé en headless ne le reproduit pas (un rayon qui naît dans une forme ne la touche pas) : c'est la forme réelle du
   joueur qui le coupe. Remède probable : passer `[joueur.get_rid()]` à `occultation`, comme `direction_du_lisere`.
2. **`volume_masque.gdshaderinc.uid` n'est pas suivi** sur la base : l'import le crée à chaque conteneur neuf (fichier
   non suivi dans `git status`). Je l'ai effacé plutôt que de le committer (pas ma tâche).

## Pièges découverts, à reporter dans la feuille de route

1. ⚠️ **Deux `varying` de plus dans `corps_iso.gdshader` changeaient le corps dans la vue d'EN FACE**, sous
   `gl_compatibility` (llvmpipe) : jusqu'à 43/255 sur 582 à 791 pixels du corps de J1 dans la vue de J2, alors que la
   branche de l'essai n'y est pas prise (s = 0) et qu'une variante témoin sans code ne change rien. Retirés (les axes du
   modèle sont lus dans `fragment()` par `MODEL_MATRIX`), l'écart tombe à 0. **Ne pas ajouter de varying au shader des
   corps sans comparer au pixel la vue de l'adversaire.** Cause exacte non établie (décalage des interpolants ? limite
   de varyings du pipeline de compatibilité ?) ; à revérifier sur le GPU du Mac.
2. ⚠️ **Changer le shader d'un `ShaderMaterial` en direct demande de reposer ses paramètres** pour une comparaison au
   pixel ; et **`accorder_corps` n'est pas une bascule** : le rappeler repose l'encre et le modelé (première séance : des
   arêtes changées sur les deux corps). L'outil ne change que le shader, puis repose chaque paramètre.
3. ⚠️ **Une fusée brûle plus de 10 s de jeu, et sa fumée efface les corps** : une séance qui enchaîne des prises au même
   endroit après une fusée photographie la fumée, pas le corps (corps « introuvable » : empreinte vide — payé une fois
   ici, trois classes à refaire). Une séance par fusée. Et le Spectre n'en a aucune (`spectre.fusees = _fusees(0, 0.0)`).
4. ⚠️ **« Dans le noir » n'est pas noir sur le Cloître** : les bandeaux LED des murs tiennent le sol vers 22/255 torches
   éteintes. Toute mesure « dans le noir » est une mesure sur ce sol-là.

## Décisions prises seul, et pourquoi

- **Le repère sur les bords des dessus seulement** : sur toutes les arêtes, la première prise montrait un fil de fer
  (chaque boîte cernée). Vus d'en haut, les dessus font le contour ; c'est le « liseré ténu à la couleur du joueur ».
- **Le repère à la valeur exacte de la silhouette d'aujourd'hui** (`sil × s`) : aucune couleur neuve à justifier, et
  l'invariant « rien de plus clair qu'aujourd'hui » est tenu par construction.
- **Le liseré à la lumière d'aujourd'hui du fragment** (celle du capteur), pas plus claire : la règle des pochoirs et le
  plafond de fiche restent tenus ; la contrepartie est un liseré discret (il est vif sous la fusée, pâle sous sa torche).
- **Facteur sombre 0,4** : il met la fiche (~128 en pleine lumière) vers ~50, la clarté des personnages des illustrations
  (40-60). Non étalonné plus finement : c'est un réglage de beauté, pour Beauté et Adrien.
- **Quatre classes** : Parasite (pistolet), Terrassier (pompe), Fumiste, Spectre — deux silhouettes à bouteille, deux sans,
  un gabarit large (pompe).

## Tout refaire

```bash
# Godot 4.7 et Xvfb installés (voir le brief) ; depuis la racine du dépôt :
godot --headless --path . --import
godot --headless --path . --script res://tools/test_corps_soi_sombre.gd      # la garde
GODOT=/usr/local/bin/godot ./tools/run_suites.sh                              # la suite complète
./docs/iso/cloud/corps-sombre/lancer.sh                                       # les images, les mesures, la planche
# Le témoin de la bascule (doit rendre 0 pixel changé partout) :
xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/photo_corps_sombre.tscn -- \
  --no-eos --led-murs-fige --sortie=user://temoin --define-temoin=CORPS_TEMOIN_NEUTRE --classes=pistolet --scenes=scinde
# En jeu, l'essai :
godot --path . -- --corps-soi-sombre
```

## Ce que je n'ai PAS pu prouver

- **La cadence** : rien mesuré (le cloud n'en dit rien). L'essai ajoute, dans la vue de soi seulement, quelques
  opérations par fragment du corps et un calcul de direction par image (le même que le mannequin) ; à mesurer au Mac.
- **L'éblouissement réel** : la scène « adverse » est prise sous le voile de llvmpipe ; la lisibilité sous la torche
  adverse est à juger au Mac.
- **Le mouvement** : les prises sont gelées. Un liseré de 1,5 px sur un corps qui marche peut scintiller ; non vu.
- **La cause des varyings** (piège 1) : constatée et contournée, pas expliquée.
- **La lumière 3D** (`corps_iso_eclaire.gdshader`, éteinte par défaut) ne porte pas l'essai.
- **La killcam** : le fantôme porte la silhouette dans les vues qui voient sa couche (règle d'ISO5), donc l'essai s'y
  applique aussi, mais sa direction de lumière n'y est pas suivie (`_suivre` passe le fantôme avant). Non photographié.
- **L'équité à 0° de lacet** : prises à 45° (et 225° pour J2) seulement. L'essai ne touchant que la vue de soi, l'équité
  entre joueurs n'est pas en jeu ; la lisibilité de soi à 0° n'est pas mesurée.
