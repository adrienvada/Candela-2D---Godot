# Q33 — les personnages détaillés en jeu, sur image (session cloud q33, 2026-09-27)

## Pour Adrien, en cinq lignes

1. J'ai photographié les dix classes en vrai duel, avec et sans le personnage détaillé, au même instant et au même cadrage : la planche est `planche.html` (et d'un coup d'œil `planche_q33.jpg`).
2. Au bord de la lumière, là où l'adversaire commence à peine à se voir, le détail ne change rien : chaque classe garde de 99 % à 103 % de ce qu'elle montrait sans détail, et rien ne s'allume dans le noir.
3. Mais à la taille du jeu, le détail ne se voit presque pas non plus : l'adversaire y est un petit corps sombre et à moitié transparent ; il faut la loupe ×3 pour distinguer la sangle.
4. Ton propre personnage n'est jamais « éclairé par ta torche » : le jeu le dessine en silhouette bleue unie. L'image que tu voulais de lui n'existe donc pas dans le jeu tel qu'il est.
5. Ces chiffres viennent du rendu logiciel du cloud : ils sont indicatifs. L'étalonnage au seuil qui fait foi se fait sur ton Mac.

## Ce qui mérite d'être lu en premier (défauts et signaux)

Aucun triangle noir, aucune pièce qui passe devant ce qu'elle devrait suivre, aucune classe qui se montre plus AVEC le détail
que sans lui. Quatre signaux, dont aucun ne vient du détail :

1. **Le corps du joueur est une silhouette bleue unie, pas un corps éclairé.** Colonne « soi » de la planche, les dix classes :
   la prise réelle et la prise forcée en pleine lumière ont le même nombre de pixels (100 % visibles, sous 0,92 au capteur).
   Le détail s'y lit à peine (la bandoulière en gris plus foncé). La demande « le corps du joueur éclairé par sa propre torche »
   n'a pas d'image possible sans changer ce rendu — c'est une décision de jeu, pas de ce chantier.
   Image : `img/<classe>_soi_d0_x3.jpg` / `_d1_x3.jpg`.
2. **À la même place, le capteur lit une lumière différente selon la classe de J2, sans détail.** Même position, même torche
   (Parasite), à la place où le Parasite lit 0,100 : Terrassier 0,093, Braconnier 0,092, Fumiste 0,095, Sentinelle 0,097,
   Spectre 0,104 ; à mi-distance, 0,25 (Terrassier) à 0,29 (Spectre). Le jeu donne donc, au même endroit, un peu moins de
   lumière à certaines classes. Je n'ai pas cherché pourquoi (hors de ma tâche) ; si c'est voulu (furtivité par classe), rien
   à faire ; sinon, c'est un écart d'équité d'environ 10 % au seuil. Commande : `planche_q33` (ci-dessous), lire la colonne
   « capteur » du journal.
3. **La part visible du corps n'est PAS la même pour les dix classes, avec comme sans détail.** À 0,10 : Terrassier et Fumiste
   0,58, Illusionniste et Allumeur 0,62, Incendiaire 0,63, Braconnier 0,65, Sentinelle 0,66, Occulteur 0,67, Parasite et
   Spectre 0,74 — 16 points d'écart, bien au-delà des 5 points demandés. Le détail ne bouge chaque classe que d'un point au
   plus. **Ce chiffre en jeu n'est pas celui de Q32** (voir « Limites ») : ici, la part visible dépend de la forme (quelle
   part du corps fait face à la torche), de la lumière reçue (signal 2), et du sol éclairé vu au travers du corps. L'équité de
   Q32 (apparition au même seuil) n'est pas contredite ; la « même part visible à 5 points » ne tient pas en jeu, et elle ne
   tenait déjà pas sans détail.
4. **L'adversaire est dessiné à 65 % d'opacité dans la vue de J1** (`opacite_1` = 0,6475, relevé à chaque prise), partout, du
   bord de la lumière à mi-distance. Le sol éclairé transparaît donc à travers son corps. Je le signale parce que cela change la
   lecture de toute mesure « pixels visibles du corps » en jeu, et parce que je ne sais pas si c'est voulu.

Et un petit point du détail lui-même, sous le bruit de mesure mais à regarder au Mac : sur le Parasite au bord (0,10), un
amas de 2 à 3 pixels sort du contour à la hanche gauche (l'étui ?) — `img/pistolet_b10_contour_x3.jpg`, vert = présent
seulement avec le détail. Les autres différences de contour sont des arêtes d'un pixel, au niveau du bruit.

## Les chiffres (indicatifs)

Le tableau complet (dix classes × cinq scènes) est dans `tableau.md` et `chiffres.json` ; la planche les reprend sous chaque
paire. L'essentiel :

| Classe | part visible à 0,15, sans → avec | à 0,10, sans → avec | pixels visibles à 0,10, avec / sans | allumés hors lumière, sans / avec |
|---|---|---|---|---|
| Parasite | 0,77 → 0,77 | 0,74 → 0,73 | 1,016 | 0 / 0 |
| Illusionniste | 0,63 → 0,64 | 0,62 → 0,62 | 1,012 | 0 / 0 |
| Terrassier | 0,56 → 0,56 | 0,58 → 0,58 | 0,993 | 0 / 0 |
| Braconnier | 0,67 → 0,67 | 0,65 → 0,65 | 1,024 | 0 / 0 |
| Occulteur | 0,66 → 0,66 | 0,67 → 0,67 | 0,998 | 0 / 0 |
| Fumiste | 0,56 → 0,56 | 0,59 → 0,58 | 0,988 | 0 / 0 |
| Incendiaire | 0,66 → 0,66 | 0,63 → 0,64 | 1,030 | 0 / 0 |
| Sentinelle | 0,69 → 0,69 | 0,66 → 0,66 | 1,007 | 0 / 0 |
| Allumeur | 0,64 → 0,64 | 0,62 → 0,62 | 1,010 | 0 / 0 |
| Spectre | 0,75 → 0,76 | 0,74 → 0,74 | 1,018 | 0 / 0 |

- **Critère de recalibrage de Q29/Q33** (au moins 0,95 des pixels visibles du corps sans kit, à 0,10 comme à 0,15) : tenu
  par les dix, de 0,988 (Fumiste) à 1,030 (Incendiaire) à 0,10, de 0,989 à 1,024 à 0,15.
- **Noir absolu** : à la scène « hors lumière » (capteur 0), 0 pixel du corps plus clair que le sol et 0 pixel allumé sur
  sol noir, pour les dix classes, avec et sans détail. (Deux classes comptent 1 « pixel visible » : il est sur un marquage du
  sol éclairé, sous le corps, pas sur le corps.)
- **Silhouette** : de −22 à +37 pixels sur ~1 500 à 2 400 (plus grand avec détail le plus souvent), en arêtes d'un pixel
  réparties sur le contour, sauf l'amas du Parasite cité plus haut. Le bruit de fond (ci-dessous) est du même ordre : je ne
  peux pas affirmer mieux que « silhouette inchangée à un pixel d'arête près ».
- **Même image ?** Non au pixel : de 100 à 550 pixels diffèrent autour du corps entre les deux modes, mais **deux prises
  identiques du même mode en diffèrent autant** (bruit de fond, 69 à 533 pixels, jusqu'à 82/255 à mi-distance, 8 à 13/255 au
  bord). Au bord de la lumière, l'écart avec/sans détail (9 à 13/255) est au niveau de ce bruit.

## Comment c'est fait

- **Base** : `origin/integration-iso14` (18f5fdc), plus `origin/iso12-corps` (f38e5f7) fusionné. Un seul conflit,
  `docs/ROADMAP.md` : la date d'en-tête (gardée la plus récente, 2026-09-27) et deux ajouts à la fin des « Pièges connus »
  (les deux gardés, celui d'integration-iso14 d'abord). Puis les deux corrections Xvfb du photographe (0c67705), commit à part.
- **L'outil** : `tools/planche_q33.gd` (+ `.tscn`), qui hérite du photographe sans toucher à ses plans. Le vrai `main.tscn`, la
  vraie vue iso (45° B, cadrage ×1,5 du jeu, 1920×1080), la carte d'essai des murs bas. J1 = Parasite, torche allumée, dans
  une ligne de sol libre ; J2 de chaque classe, torche éteinte, regardant de côté, dans l'axe du cône à quatre places :
  mi-distance (154 px), bord à 0,15 (255 px), bord à 0,10 (285 px), hors lumière (414 px). Les places « bord » sont trouvées
  en lisant le **capteur du corps** de J2 dans la vue de J1 (la luminance, comme le shader des corps, sur l'anneau où il
  lit) : c'est l'équivalent en jeu du niveau de lumière du banc des corps. Puis J1 de chaque classe, seul, sous sa torche.
- **Le détail bascule dans le même processus** (`VoxelCatalogue.forcer_detail`, corps reconstruits sur place par la
  présentation) : même partie, mêmes places, même instant.
- **Trois prises par scène** : la réelle ; une où le corps regardé est forcé en pleine lumière (sa silhouette) ; une sans ce
  corps (le sol seul). Silhouette = ce qui diffère du sol seul ; pixels visibles = pixels de la silhouette non noirs dans la
  prise réelle.
- **Le même instant, et ce qu'il a coûté.** Six choses bougeaient seules d'une prise à l'autre ; toutes sont tenues par
  l'outil, et écrites dans son en-tête : la respiration et la pose des corps (reposés à leur place et leur visée exactes juste
  avant chaque rendu), le souffle de la torche (fréquence du bruit à 0), le bandeau LED des murs qui éclaire aussi les
  marquages du sol (`--led-murs-fige=0.5`, drapeau du jeu), la poussière du faisceau (plus aucun grain émis, les anciens
  éteints — c'est un effet MONDE que les réglages ne coupent pas, le retirer est un choix de mise en scène), la caméra (lissage
  remis à zéro, vitesses nulles), et l'intro en planches du premier lancement, qui s'était posée par-dessus la première image.
  Avant ces gestes, deux prises identiques différaient sur 340 000 pixels ; après, sur 900 à 1 600, tous sur les arêtes et la
  face éclairée des deux corps — ce reste, je ne l'ai pas expliqué (voir « Pas prouvé »).
  ⚠️ Le message du commit e0ab2e3 dit « de 1 412 à 320 pixels » grâce à la caméra : **c'est faux**. L'essai qui l'a mesuré
  tournait pendant qu'un lancement précédent, que je croyais arrêté, écrivait dans le même dossier. Refait proprement, la
  caméra recalée ne change pas le bruit.

## Pour tout refaire

```bash
# Outils (une fois)
godot --version   # 4.7.stable ; sinon le zip officiel, lié en /usr/local/bin/godot
godot --headless --path . --import

# Les 254 prises (≈ 35 min dans le cloud, 4 cœurs) — dans user://q33/
xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/planche_q33.tscn -- \
  --sortie=user://q33 --led-murs-fige=0.5
#   --classes=pistolet,spectre  pour quelques classes seulement

# Chiffres, découpes JPEG, planche.html, tableau.md, chiffres.json
pip install numpy pillow
python3 docs/iso/cloud/q33/analyse_q33.py "$HOME/.local/share/godot/app_userdata/Candela 2D/q33" docs/iso/cloud/q33
```

Sur le Mac : même commande sans `xvfb-run` ni `--fixed-fps 60`, dossier
`~/Library/Application Support/Godot/app_userdata/Candela 2D/q33`. ⚠️ Pour arrêter un lancement, tuer le processus
`godot` lui-même : un `pkill` sur le nom du binaire manque le lien `godot` (c'est ce qui a mêlé deux séances ici).

## Les livrables

- `planche.html` — autonome, images en chemins relatifs : les deux illustrations cibles, puis pour chaque classe l'image
  entière avec et sans détail, et pour chaque scène la paire à la taille du jeu (1:1), la paire en loupe ×3, le contour, et
  ses chiffres.
- `planche_q33.jpg` — les dix classes en une image : loupe ×3, mi-distance, bord 0,15, bord 0,10, soi ; sans / avec.
- `img/` — 270 JPEG (qualité 85) ; `tableau.md`, `chiffres.json` ; `analyse_q33.py`.
- Au total ≈ 5 Mo, aucun fichier au-dessus de 1 Mo.

## Ce que je n'ai PAS pu prouver

- **Rien sur le GPU du Mac.** Tout est rendu par llvmpipe : les pixels au bord du seuil, l'étalonnage 0,15 → 0,09 et la
  preuve « même image » se refont au Mac. Aucune cadence mesurée, aucune affirmée.
- **Le bruit de fond restant** (arêtes et face éclairée des corps, 900 à 1 600 pixels entre deux prises identiques) n'est pas
  expliqué. Pistes non essayées faute de temps : llvmpipe en un seul fil (`LP_NUM_THREADS=1`) pour savoir si c'est le rendu
  logiciel ; un relevé de la transformation de la caméra 3D à chaque prise. Tant qu'il est là, « silhouette inchangée » et
  « même image » ne valent qu'au pixel d'arête près.
- **La part visible en jeu n'est pas la grandeur de Q32.** Q32 comptait des pixels au banc, corps opaque sur fond noir, lumière
  uniforme. Ici le corps est à 65 % d'opacité sur un sol éclairé, sous une lumière qui varie d'un côté à l'autre du corps.
  Comparer les classes entre elles avec ce chiffre demande de l'étalonner d'abord (par exemple, même mesure sur les corps
  gris, sans portrait).
- **Pas d'autre angle ni d'autre carte** : une seule visée (celle du photographe), une seule carte, J2 toujours de profil.
  À 0°, et J2 vu depuis l'autre côté (lacet B de J2), rien n'est mesuré.
- **La preuve `--fusion-ab`** de Beauté n'a pas été refaite ici (elle passe dans le cloud d'après la consigne).
- **Poussée** : le premier `git push` vers `claude/cloud-q33` a été refusé par le garde-fou de la session ; je ne l'ai pas
  retenté. Les commits sont locaux (voir le rapport de fin de session).

## À reporter dans la feuille de route (par l'intégration)

- **Piège : un outil qui compare deux prises « au même instant » doit figer six choses**, dont trois qu'on ne devine pas :
  le bandeau LED éclaire les marquages du sol (340 000 pixels de différence entre deux prises identiques), la poussière du
  faisceau vit plusieurs secondes (reposer la graine ne suffit pas), et la pose des corps suit l'horloge murale. La liste et
  les gestes sont dans l'en-tête de `tools/planche_q33.gd`.
- **Piège : dans le cloud, `pkill` sur le nom du binaire Godot manque le lien `godot`** ; deux séances du photographe ont alors
  écrit dans le même dossier, sans erreur, et un chiffre faux est entré dans un message de commit.
- **Signal d'équité (hors Q33)** : à la même place, le capteur de J2 lit de 0,092 à 0,104 selon sa classe.
- **Question pour Adrien** : son propre personnage en silhouette bleue unie, et l'adversaire à 65 % d'opacité — voulus ?
- **Q33 à l'étape « images »** : le détail tient l'équité au bord de la lumière (≥ 0,988 du corps sans kit) et le noir ; il est
  presque invisible à la taille du jeu.
