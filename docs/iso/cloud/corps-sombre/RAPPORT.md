# Q39 sur image — ton propre corps, sombre avec un liseré (session cloud corps-sombre, 2026-09-28)

Branche `claude/cloud-corps-sombre`, partie d'`origin/integration-iso14` (a30a407), le 28/09/2026 entre ~02:05 et ~04:30
(heure de Paris). Lancée par la session coordinatrice « CLOUD ISO UNRAILED ». **Rien ne change par défaut** : l'essai est
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
   `img/`, ~3 Mo).

## Les chiffres

Cloître, la place du duel du photographe, 1920×1080, lacet 45° (J2 : 225°, le côté B), zoom du duel ×1,5. Luminance
Rec. 709 des valeurs sRGB, 0..255. « Lisible » : pixel du corps qui diffère d'au moins 10/255 de ce qu'il cache.
« Corps » : moyenne sur l'empreinte du corps ; « liseré » : son 90ᵉ centile.

TABLEAU_CHIFFRES

**Lecture.**
- **Dans le noir** (torches éteintes ; le sol n'y est pas à 0 : les bandeaux LED des murs le tiennent vers 22) : aujourd'hui
  le corps entier à ~104, lisible à 100 % ; l'essai, un contour seulement (liseré à ~108, le reste noir), lisible à ~93 %.
  On se retrouve : le contour a la clarté de la silhouette d'aujourd'hui.
- **Sous sa torche / au bord de sa lumière** : le corps descend de ~133 à ~50, le liseré reste vers 108. Lisible de 62 à
  85 %. Moins voyant qu'aujourd'hui, mais la question n'est pas « voyant » : sur un sol à ~23, un corps à 50 cerné de
  bleu se lit.
- **Dans la torche adverse** (J1 ébloui : le voile laiteux s'ajoute au corps comme au sol) : la part lisible tombe de
  ~60-89 % à ~35-48 %. C'est le cas le moins favorable à l'essai : un corps sombre sous un voile clair se rapproche du
  sol éclairé. À juger au Mac, où l'éblouissement n'est pas celui de llvmpipe.
- **Sous une fusée** : aujourd'hui, le bleu clair (~119) vaut presque le sol rougi (~124) — **20 % du corps lisible** ; avec
  l'essai, le corps sombre (~52) se détache — **~100 %**. C'est la scène où l'essai gagne le plus, et la plus proche des
  illustrations (un corps noir sur une lumière).
- **Écran scindé, deux couleurs** : J1 (bleu) et J2 (rouge) chacun dans sa vue. Dans le noir, les deux contours restent
  lisibles à ~90 % ; J2 (rouge) descend de ~109 à ~55 sous sa lampe.

## Le noir absolu et la vue de l'adversaire

- **Hors du corps de soi, l'essai ne change rien** : 0 pixel sur toutes les prises propres, 0 pixel noir rallumé, dans
  les scènes à une vue comme dans les deux moitiés de l'écran scindé.
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
3. **Pas de fusée pour une 4ᵉ classe dans la même manche** : la 4ᵉ `lancer_fusee()` d'une séance ne part pas (quota de la
   manche, je suppose — non vérifié). Contourné par une séance par fusée.

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
   endroit après une fusée photographie la fumée, pas le corps (corps « introuvable » : empreinte vide). Fusées en
   dernier, ou une séance par fusée.
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
