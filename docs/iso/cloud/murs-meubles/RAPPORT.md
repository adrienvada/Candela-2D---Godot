# Les murs meublés, en essai — rapport de la session cloud « murs meublés »

Branche `claude/cloud-murs-meubles`, depuis `origin/claude/cloud-ecart-illustrations` (`f4039a0`). Ordre de la session
coordinatrice « Fable 5.1 - CLOUD ISO UNRAILED », 2026-09-28. Le manque n° 4 de l'évaluation de l'écart aux
illustrations (`docs/iso/cloud/ecart-illustrations/RAPPORT.md`).

## Pour Adrien, en cinq lignes

1. Les murs peuvent maintenant porter des portes d'acier, des grilles, des boîtiers électriques et des nappes de câbles
   serrés, comme dans onze des illustrations — **éteint par défaut** (`--murs-meubles-essai` l'allume).
2. Tout est **plus sombre que le mur** qui le porte et reste noir dans le noir : personne ne ressort mieux devant une
   porte qu'ailleurs.
3. Chaque objet a son jumeau de l'autre côté de la carte : les deux joueurs ont les mêmes murs sous les yeux.
4. Coût : jusqu'à quatre appels de dessin de plus par vue (un par famille), et des milliers de petits triangles pour les
   câbles. La cadence reste à mesurer sur ton Mac.
5. À toi de juger sur `planche.html` : ça se voit de près, c'est **discret à taille réelle** ; et si tu gardes aussi les
   tuyaux, les deux essais se chevauchent aujourd'hui (voir « À décider »).

> État : **fait.** Code, garde, **suite complète verte sur l'état final** (« tout passe, sans erreur de script (741 s) », EXIT 0, `test_iso_murs_meubles` compris), trois séances de prises, mesures, comptes de dessin et planche poussés. Rien d'allumé en jeu.

## Ce que les illustrations posent aux murs (relevé AVANT de coder)

Relevé à l'œil sur les vingt illustrations de `assets/ui/ill_*.png`. Les tailles sont rapportées au mannequin (≈ 1,8 m) ;
la matière et la couleur sont celles du dessin, pas celles qu'a le jeu (voir « écart assumé »). Les tuyaux, les câbles
pendants et les enseignes sont déjà des essais (`--tuyaux-essai`, `--enseignes-essai`) : ils ne sont notés ici que pour
mémoire.

| Illustration | Posé aux murs | Famille | Taille | Matière, couleur | Densité |
|---|---|---|---|---|---|
| `ill_accueil` | deux **portes à grilles** (barreaux verticaux) de part et d'autre du poteau ; une plaque rouillée vierge au mur droit ; une descente de tuyau | porte, (grille) | porte : ~1 × 2,2 m, jusqu'au linteau | acier sombre à barreaux, cadre de fer, rouille | 2 portes pour ~6 m de mur |
| `ill_amical` | trois **petits boîtiers** électriques (un à chaque pilier, un sur le mur droit), un interrupteur, conduites horizontales cerclées, descentes ; une porte au fond à gauche (cadre) | boîtier, porte | boîtier : ~0,3 × 0,4 m à hauteur d'épaule ; porte ~1 × 2 m | tôle grise, un fil qui en descend | 1 boîtier par pilier / tous les ~3 m |
| `ill_amical_ligne` | des baies de serveurs **sur toute la hauteur** des deux murs, façades à grilles et LED cyan ; câbles en guirlandes au plafond | grille (façade), câbles | baie : ~0,6 × 2 m, jointives | acier noir, fentes d'aération, LED | le mur entier |
| `ill_competitif` | un grand **tableau électrique** à deux portes (disjoncteurs, « MAIN FEED », « UNIT 4A »), des câbles qui en sortent par le bas, deux conduites horizontales | boîtier (grand) | ~1 × 1,2 m, centre à hauteur de poitrine | acier gris-bleu, rivets, étiquettes | 1 pour ~4 m de couloir |
| `ill_creer_ligne` | un **plafond de faisceaux de câbles** serrés tenus par des colliers, des conduites rouges ; mur nu | câbles (faisceau) | faisceau de ~10 câbles, ~0,3 m d'épaisseur | caoutchouc noir, colliers de fer | tout le plafond |
| `ill_creer_local` (= `ill_rejoindre_local`, même fichier) | graffitis, une petite plaque « … VOLT », des **boîtiers** sur la mezzanine, câbles pendants au fond | boîtier | ~0,3 × 0,4 m | tôle sombre | épars |
| `ill_ecran_scinde` | piliers et poutres nus, une fissure ; presque rien | — | — | — | nu |
| `ill_entrainement` | **câbles** courant en travers du mur du fond et le long du pilier, un **interrupteur** (petit boîtier) sur le pilier, une lampe au plafond | câbles, boîtier | boîtier ~0,15 × 0,2 m ; câbles isolés, 3-4 en nappe lâche | caoutchouc noir, tôle claire | 1 boîtier, 1 nappe |
| `ill_intro_seuil` | une **porte d'acier rivetée** à panneaux (trois rangées de rivets horizontales, deux verticales, charnières), dans un chambranle riveté ; « ARENA » au-dessus | porte | ~1 × 2,2 m, jusqu'au linteau | acier rouillé brun-orangé, rivets sombres | 1 |
| `ill_quitter` | au bout du couloir, une **porte rivetée** à deux battants avec une serrure-boîtier ; à droite un petit **boîtier** (interrupteur à clé) | porte, boîtier | porte ~1,2 × 2,2 m ; boîtier ~0,15 × 0,25 m | acier bleu-gris rouillé | 1 + 1 |
| `ill_rejoindre_ligne` | des **faisceaux de câbles serrés** (8 à 12 câbles) le long des deux murs, sur trois hauteurs, tenus par des **colliers-étriers** verticaux tous les ~1,5 m, qui fléchissent entre deux ; une descente de tuyau ; au fond un **boîtier** bleu | câbles (faisceau), boîtier | faisceau ~0,25-0,4 m d'épaisseur ; boîtier ~0,3 × 0,5 m | caoutchouc noir luisant, étriers de fer ; boîtier gris | les deux murs entiers |
| les autres (`amical_local`, `intro_allumage`, `intro_descente`, `intro_dotation`, `intro_extinction`, `intro_prix`, `mise_a_jour`, `retour`) | écrans, béton nu criblé, escalier, portes de coffre (métaphores de menu) : pas de mobilier mural qui manque au duel | — | — | — | — |

Onze illustrations, quatre familles :

1. **La porte rivetée** (accueil, amical, intro_seuil, quitter) : une plaque d'acier plate, un chambranle, des bandes
   rivetées, de la rouille ; certaines à barreaux.
2. **Le boîtier électrique** (amical, competitif, creer_local, entrainement, quitter, rejoindre_ligne) : une boîte de tôle
   qui avance de la face, petite (interrupteur, coffret) ou grande (tableau à deux portes), avec un câble qui en descend.
3. **La grille d'aération** (accueil, amical_ligne) : une plaque plate à fentes horizontales, dans un cadre.
4. **Le faisceau de câbles serrés** (creer_ligne, entrainement, rejoindre_ligne) : huit à douze câbles jointifs, en nappe
   horizontale le long d'un mur, tenus par des étriers verticaux, qui fléchissent un peu entre deux. Différent des câbles
   de `--tuyaux-essai` (un à trois câbles lâches, en guirlande sous l'arête).

**Écart assumé avec les illustrations** : elles les peignent en tôle claire, rouille orange, caoutchouc luisant ; au jeu,
la règle des pochoirs l'emporte — tout est **plus sombre que la face qui le porte**, et noir hors de la lumière. La LED
cyan des baies et le boîtier bleu qui irradie de `ill_rejoindre_ligne` sont des lumières : **exclus** (le noir absolu).

## Ce qui est construit

- `murs_meubles_iso.gd` (nouveau) — la classe `MursMeublesIso`, le drapeau `--murs-meubles-essai` (éteint par défaut), la
  table des six cartes, l'atlas des objets plats, les maillages des quatre familles.
- `presentation_3d.gd` — **+35 lignes, aucune retirée** : les ancrages des enseignes, pour les murs meublés (le script
  préchargé, trois variables, la construction avec les murs juste après les enseignes, la peinture posée et retirée,
  `_materiaux()`).
- `tools/test_iso_murs_meubles.gd` (nouveau), ajouté à `tools/run_suites.sh` (1 ligne changée).
- `tools/photo_murs_meubles.gd` + `.tscn` (nouveaux) — la séance du photographe ; `docs/iso/cloud/murs-meubles/mesurer.py`
  et `planche.py` — les mesures et la planche.
- `tools/cloud_budget/` — l'outil de la session « Budget », repris tel quel d'`origin/claude/cloud-budget` (`a31cde9`).
- **Aucun shader nouveau**, aucun fichier d'un autre essai modifié.

### Ce que pose la table

| Carte | portes | grilles | boîtiers | faisceaux | objets | triangles (portes + grilles + boîtiers + faisceaux) |
|---|---|---|---|---|---|---|
| par défaut (`00000001`) | 8 | 4 | 10 | 8 | 30 | 16 + 8 + 336 + 7 200 |
| le Cloître (`map_001`) | 4 | 4 | 10 | 8 | 26 | 8 + 8 + 336 + 8 624 |
| l'Usine (`map_002`) | 2 | 4 | 10 | 8 | 24 | 4 + 8 + 336 + 8 624 |
| la Croisée (`map_003`) | 4 | 4 | 6 | 4 | 18 | 8 + 8 + 224 + 3 956 |
| le Bunker (`map_004`) | 8 | 4 | 10 | 6 | 28 | 16 + 8 + 336 + 6 468 |
| l'Arène circulaire (`00000002`) | 4 | 4 | 8 | 6 | 22 | 8 + 8 + 280 + 5 044 |

Sept à neuf entrées écrites à la main par carte ; le reste, ce sont leurs jumeaux.

### Les décisions, et leur pourquoi

1. **Réutiliser les shaders des enseignes et des tuyaux, pas en écrire un.** Les deux relisent déjà la lumière du pixel
   de FACE que l'objet recouvre à l'écran (le rayon de la caméra prolongé jusqu'au plan de la face — la leçon de la
   parallaxe des volumes) et la multiplient par un facteur plafonné par `TuyauxIso.matiere_max()`, la matière la plus
   sombre qu'une face puisse porter. Leurs gardes prouvent la copie mot pour mot de la lecture de `mur_iso.gdshader`. Un
   nouveau shader aurait été une nouvelle preuve à faire ; celle-ci est déjà payée. Les portes et les grilles sont plates
   (le shader des enseignes et un atlas à elles), les boîtiers et les faisceaux en volume (celui des tuyaux, un
   `corps_sombre` plus léger pour les boîtiers, dont les faces planes ne tournent jamais un reflet vers la caméra).
2. **Quatre matériaux, quatre maillages** : un par famille, comme le demandait l'ordre. Deux suffiraient (un par shader) ;
   quatre laissent Adrien garder une famille sans l'autre et chaque famille se compter à part.
3. **Une table de représentants, pas une table de toutes les copies.** Chaque entrée est écrite à la main (case de mur,
   côté, décalage, variante) ; ses jumeaux sont ses images par le groupe de la carte (`EnseignesIso.groupe` : la symétrie
   qui échange les départs, et le demi-tour de l'option B). Écrire les jumeaux à la main, c'était quatre fois plus de
   lignes et autant d'occasions d'une faute qui casserait l'équité en silence ; calculés, ils sont exacts par construction.
   Une entrée dont UNE image tombe hors d'une face exposée, trop près d'un bout, sur un autre objet ou sur une enseigne
   est refusée tout entière (`refus`), et la garde exige zéro refus. L'Usine, dont les murs ne sont symétriques que
   haut-bas, ne porte donc des objets que sur les faces dont l'image gauche-droite existe aussi.
4. **Des atlas symétriques gauche-droite.** L'image miroir d'une porte est alors la même porte : le jumeau par un miroir
   se dessine avec la même texture, sans texture retournée à maintenir. La garde le vérifie au texel.
5. **Des objets plus sombres que dans l'illustration**, et au départ trop peu : à la première planche le faisceau se
   lisait comme une bande grise (clarté avec / sans ≈ 0,72). Câbles 0,85 → 0,6, étriers 0,75 → 0,5 (commit `52f64e2`).
6. **La hauteur.** Portes posées sur la bande de sol (au-dessus de `hauteur_bas`), grilles à 70 % du mur, boîtiers à
   hauteur de poitrine, faisceaux à 80 % ; tout sous l'arête moins la saillie vue sous le tangage.

### Ce que la garde prouve (`tools/test_iso_murs_meubles.gd`, 292 vérifications)

Drapeau éteint : ni nœud, ni matériau (la présentation sort avant). Allumé : un nœud par famille présente, calque commun,
sans ombre ni enfant, une surface chacun, le bon shader, l'atlas posé ; éteint de nouveau, tout est retiré. Le script ne
construit ni collision, ni occluder, ni lumière, et ne tire aucun hasard. Atlas : identique deux fois, chaque texel ≤ 0,70,
chaque motif plein et symétrique au texel, transparent hors des motifs. Par carte : zéro refus, deux constructions
identiques, chaque famille présente, aucun doublon, **chaque objet a ses jumeaux par tout le groupe**, J1 et J2 voient
autant d'objets de chaque famille à 0° B et à 45° B ; chaque sommet sous l'arête moins la saillie, au-dessus de la bande de
sol, devant sa face de sa saillie au plus, sur une face exposée à la marge de ses bouts ; enroulement comme une `BoxMesh`.
Matériaux : `matiere_max` des murs, instrument de banc éteint, lus au pied de la face ; les deux shaders portent bien le
plafond. Une carte hors de la table ne porte rien.

**Éprouvée par sept mutations** : un texel d'atlas asymétrique → 2 échecs ; jumeaux non posés → 59 ; enroulement des
boîtes inversé → 12 ; faisceau trop haut → 6 ; une lame à 0,95 → 1 ; saillie du faisceau sous-estimée → 6 ; une grille
posée sur « ARENA » → 1 (refusée). Décaler une entrée de 0,3 case ne la fait PAS rougir, à raison : ses jumeaux la suivent.

## Les preuves en images

`planche.html` (images dans `img/`, mesures brutes dans `mesures.json`). Carte : le Cloître, 1920×1080, lacet 45° B,
zoom du duel. Trois lancements de `tools/photo_murs_meubles.gd`, chacun avec `--murs-meubles-essai` :

- **seul** : le seul drapeau des murs meublés (`--led-murs-fige`) ;
- **tous** : plus les neuf drapeaux des essais de la nuit (`--faisceau --mannequin --pochoirs-essai --encre-essai
  --tuyaux-essai --corps-detaille --enseignes-essai --fusee-rouge-long --fusee-rouge-sang`) ;
- **contrôle** : `--sans-usure --sans-led-murs` — sans l'usure des murs ni le bandeau LED, pour isoler ce que les deux
  premiers ne tranchent pas.

Pour chaque famille, J1 devant un objet que sa caméra dessine, torche dessus ; puis, jeu en pause (même instant), **A**
les murs meublés cachés, **B** montrés, **A'** cachés de nouveau, **M** leur emprise en blanc — torches allumées, puis
éteintes. Luminance Rec. 709 des valeurs sRGB. Bruit A contre A' : **0 pixel** dans toutes les séries.

### Noir absolu (torches éteintes, prises A, B, A')

| séance | famille | emprise à l'écran (px) | dont sur un pixel noir en A et A' | noirs allumés par B (0 → plus) | au seuil 7,5/255 |
|---|---|---|---|---|---|
| seul | portes / grilles / boîtiers / faisceaux | 13 924 / 12 482 / 8 691 / 12 483 | 0 / 17 / 0 / 232 | **0 / 0 / 0 / 0** | 0 / 0 / 0 / 0 |
| tous | idem | 10 933 / 9 693 / 6 827 / 10 042 | 0 / 17 / 0 / 190 | **0 / 0 / 0 / 0** | 0 / 0 / 0 / 0 |
| contrôle | idem | 13 924 / 12 482 / 8 691 / 12 483 | **13 924 / 12 482 / 8 691 / 12 483** | **0 / 0 / 0 / 0** | 0 / 0 / 0 / 0 |

Sur l'écran entier, les ~1,0 à 2,0 millions de pixels noirs en A et A' restent noirs en B, partout. **Le contrôle est la
vraie preuve** : torches éteintes et sans le bandeau LED, les murs sont noirs, TOUTE l'emprise des objets est sur du noir
— et aucun de ses pixels ne s'allume. Dans les deux autres séances, le bandeau LED au pied des murs éclaire faiblement
toutes les faces : les objets n'y sont presque jamais sur du noir (voir « Pièges », n° 1).

### Jamais plus clair que la face (au pixel, B contre A)

| séance, torches | portes | grilles | boîtiers | faisceaux | clarté avec / sans sur l'emprise éclairée (médiane ; max) |
|---|---|---|---|---|---|
| seul, allumées | 2 | 2 | 22 | 13 | 0,72-0,73 ; 1,12 à 1,38 |
| seul, éteintes | 2 | 2 | 22 | 13 | idem |
| tous, allumées | 6 | 4 | 232 | 20 | 0,75-0,78 ; 1,19 à 1,47 |
| tous, éteintes | 6 | 4 | 15 | 13 | idem |
| **contrôle, allumées** | **0** | **0** | **0** | **0** | 0,42-0,76 ; **0,88 à 0,97** |

(pixels dont la luminance monte de plus de 0,5 ; chaque pixel changé par l'essai l'est DANS son emprise : 0 hors d'elle.)
Les quelques pixels plus clairs de « seul » (2 à 22 sur 8 700 à 13 900, de +1 à +5 niveaux sur 255) sont alignés en
traits verticaux : les **fissures et taches de l'usure**, qui assombrissent la face derrière l'objet sans que l'objet,
qui relit la lumière et non l'usure, les suive — l'exception déjà écrite pour les tuyaux et les enseignes. Sans usure (le
contrôle), il n'en reste **aucun**, et le plus clair des pixels d'objet vaut 0,97 fois la face. Dans « tous », le tableau
électrique monte à 232 pixels torches allumées (15 éteintes) : **non localisé** ; l'hypothèse est l'encre des arêtes et
les hachures de `--encre-essai`, qui assombrissent la face comme l'usure, mais je ne l'ai pas vérifiée pixel à pixel. ⚠️ Le contrôle coupe aussi le bandeau LED : il prouve que l'écart vient de l'usure OU du bandeau ; le
bandeau n'assombrit rien, et l'alignement sur les fissures désigne l'usure, mais aucune séance ne coupe l'un sans l'autre.

### Symétrie J1 / J2 à 45° B

Écran scindé, J1 devant un faisceau, J2 à son image par le demi-tour (dimension de la carte moins la position, visée
opposée), caméras à 45° et 225° (lues dans le journal). Emprise des murs meublés : **7 122 px dans la moitié de J1, 7 109
dans celle de J2** ; 511 pixels d'une seule moitié au meilleur recalage (2 px en x, la ligne de séparation), c'est-à-dire
le liseré des bords ; luminance moyenne sur l'emprise **33,8 contre 33,45**. La garde, elle, prouve l'égalité exacte des
ensembles d'objets par le groupe de chaque carte.

### Ce qu'on y voit

À ×3, la porte (deux battants, joint, bandes), la grille à lames, le tableau et la nappe de câbles avec ses étriers se
lisent. À 1:1 : une porte ~29 × 61 px d'écran, une grille ~22 × 29, le tableau ~32 × 53, un faisceau de six cases une
bande de ~6 px de haut. Discret, plus sombre que le béton comme le veut la règle ; dans la vue d'ensemble, à peine visible
hors du cône.

## Les comptes de dessin

`tools/cloud_budget/` (de la session « Budget »), six cartes livrées, J1 et J2 immobiles torches allumées, lacet 45°,
vue unique et écran scindé ; `eteint` (sans drapeau) contre `meubles` (`--murs-meubles-essai`). Tableaux complets dans
`budget/TABLEAUX.md`, journaux dans `budget/`.

| carte | passe visible 3D, appels (vue unique) | passe visible 3D, primitives | total primitives |
|---|---|---|---|
| par défaut | 47 → **51** | 534 → 8 094 | 6 378 → 13 838 |
| le Cloître | 52 → **56** | 594 → 9 570 | 6 734 → 15 610 |
| l'Usine | 54 → **58** | 618 → 9 590 | 6 838 → 15 708 |
| la Croisée | 53 → **57** | 606 → 4 802 | 6 244 → 10 338 |
| le Bunker | 54 → **58** | 618 → 7 446 | 6 126 → 12 842 |
| l'Arène circulaire | 52 → **56** | 594 → 5 934 | 5 408 → 10 648 |

**+4 appels exactement par vue 3D, sur les six cartes** (un par famille) ; en écran scindé, +4 dans chacune des deux vues
(+8). Le total des appels de l'image ne bouge pas au-delà de son bruit (médiane −2,5 en vue unique, +1 en scindé) : les
4 appels sont noyés dans les variations d'un relevé logiciel ; la passe 3D, elle, est exacte. Ni copie d'écran, ni vue,
ni lumière à ombre de plus. **Les primitives doublent** (+7 088 en médiane, +8 876 au pire, vue unique) : presque toutes
viennent des faisceaux (sept tubes à quatre côtés par nappe ; 4 000 à 8 600 triangles par carte, contre 336 pour tous
les boîtiers et 16 pour les portes). Un tube dessiné pour une face qu'aucune caméra ne voit est écrasé en un point par
le shader, mais ses triangles sont soumis quand même. Si la cadence le demande au Mac, c'est là qu'on coupe : trois côtés
au lieu de quatre, ou cinq câbles au lieu de sept.

## À décider (Adrien)

1. **Garder, et quelles familles.** Chaque famille est un nœud à part : on peut n'en garder qu'une.
2. **Les murs meublés et les tuyaux s'ignorent.** Allumés ensemble, 10 à 22 objets par carte croisent un tuyau ou un
   câble de `--tuyaux-essai` (compté sommet par sommet : le Cloître 22 sur 26, l'Usine 10 sur 24) ; un tuyau passe devant
   une porte ou une grille (il est à 0,5 px, elles à 0,25), mais traverse un boîtier ou un faisceau. Si les deux sont
   gardés, l'un doit céder la place à l'autre (les tuyaux sont tirés d'un hachage, la table est écrite à la main : le
   plus simple serait que les tuyaux évitent les rectangles de la table). Non fait : ce serait toucher à l'essai des
   tuyaux, hors de ma tâche.
3. **La taille.** À 1:1, une porte fait ~29 × 61 px d'écran, une grille ~22 × 29, le tableau ~32 × 53 : lisibles si l'on
   s'arrête, discrets au passage — le même constat que pour les enseignes.

## Pour tout refaire

```bash
git fetch origin claude/cloud-murs-meubles && git checkout claude/cloud-murs-meubles
godot --headless --path . --import                                            # la première fois
godot --headless --path . --script res://tools/test_iso_murs_meubles.gd      # la garde seule (292 vérifications)
GODOT=/usr/local/bin/godot ./tools/run_suites.sh                              # la suite complète
pip install pillow numpy
# Les trois séances (~20 à 40 min chacune sous llvmpipe) ; sur le Mac : sans xvfb-run, fenêtre au premier plan.
TOUS="--faisceau --mannequin --pochoirs-essai --encre-essai --tuyaux-essai --corps-detaille --enseignes-essai --fusee-rouge-long --fusee-rouge-sang"
un() { nom=$1; shift; XDG_DATA_HOME=/tmp/xdg xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . \
  res://tools/photo_murs_meubles.tscn -- --murs-meubles-essai --no-eos --sortie=user://mm/$nom "$@" > /tmp/photo_$nom.log 2>&1; }
un seul --led-murs-fige
un tous --led-murs-fige $TOUS
un controle --sans-usure --sans-led-murs --scenes=portes,grilles,boitiers,faisceaux
python3 docs/iso/cloud/murs-meubles/mesurer.py "/tmp/xdg/godot/app_userdata/Candela 2D/mm" /tmp/photo_seul.log /tmp/photo_tous.log
python3 docs/iso/cloud/murs-meubles/planche.py
# Les comptes de dessin (outil de la session « Budget ») :
XDG_DATA_HOME=/tmp/xdgb GODOT=/usr/local/bin/godot LACETS="45" SCENES="cartes" \
  ./tools/cloud_budget/run_budget.sh /tmp/budget "eteint=" "meubles=--murs-meubles-essai"
python3 tools/cloud_budget/synthese.py /tmp/budget --reference=eteint
# En jeu :
godot --path . -- --murs-meubles-essai
```

## Ce que je n'ai PAS pu prouver

- **La cadence.** Le cloud rend en logiciel ; les appels et les primitives sont comptés, pas chronométrés. Le prix des
  faisceaux (des milliers de triangles) se mesure au Mac.
- **Cinq des six cartes en images.** Seul le Cloître est photographié ; les autres ne sont prouvées que par la garde
  (bornes, symétrie, zéro refus).
- **L'écran scindé au pixel près.** L'emprise des deux moitiés diffère de 13 pixels sur 7 100 et de 511 pixels de bord au meilleur recalage ; je n'ai pas cherché d'où vient ce liseré (placement sous-pixel de la caméra ou de la ligne de séparation), ni fait la même mesure sans les murs meublés pour savoir si les murs nus en ont autant.
- **L'éblouissement et la lisibilité en mouvement** (le cloud ne vaut pas pour eux), ni l'impression d'ensemble à la
  vraie taille d'un écran de jeu.
- **La cause des 232 pixels plus clairs du tableau dans la séance « tous »** (hypothèse : l'encre de `--encre-essai`),
  ni la part de l'usure contre celle du bandeau LED dans l'écart de « seul » (le contrôle coupe les deux à la fois).
- **La densité.** Sept à neuf entrées par carte, un choix à l'œil : ni plus ni moins meublé n'a été essayé.
- **Les impacts de balle sur un objet.** Comme les tuyaux et les enseignes, un objet relit la lumière de la face mais pas
  son usure : là où une fissure, une tache ou un impact assombrit la face derrière, l'objet ne l'est pas (voir les mesures).

## Pièges et défauts découverts, à reporter dans la feuille de route

1. **Torches éteintes, le mur n'est pas noir : c'est le bandeau LED.** La session « enseignes » (son piège n° 4) avait
   vu la face rester allumée sous ses enseignes torches coupées, sans en trouver la cause. Avec `--sans-led-murs`, les
   mêmes faces tombent à 0 (contrôle : 100 % de l'emprise sur du noir). Le bandeau au pied des murs (`mur_led.gd`, au
   défaut depuis le 2026-09-11) éclaire faiblement TOUTES les faces : une preuve du noir sur un objet mural doit donc
   couper le bandeau, sinon elle ne teste presque rien. Reproduire : les séries `*_eteintes` de `seul` et de `controle`.
2. **L'emprise d'un instrument ne se compte pas au seuil 250.** La vue mise à l'échelle mêle les bords de l'objet au mur :
   au seuil, 1 700 à 1 950 pixels changés par l'essai tombaient « hors de l'emprise ». Compter tout pixel que
   l'instrument change (M ≠ A) : il n'en reste aucun.
3. **Les murs meublés et les tuyaux s'ignorent** (voir « À décider ») : 10 à 22 objets par carte croisent un tuyau.
   Mesuré par un script jetable, sommet de tuyau par rectangle d'objet ; non corrigé (l'essai des tuyaux n'est pas à moi).
4. **Tuer un lancement par `pkill -f` depuis l'outil Bash peut tuer le shell de l'outil lui-même** (code 144) quand le
   motif figure dans sa propre ligne de commande : viser les numéros de processus (`ps`, puis `kill`).
5. **`tools/photo_ecart.gd.uid` manquait** à `claude/cloud-ecart-illustrations` : l'import le crée ; committé ici
   (`4ad83d9`), il faudra le garder à l'intégration.
6. **`--scenes=` d'un outil du photographe ne dit rien d'une scène inconnue** : une faute de frappe donne une séance vide
   et EXIT 0. Pas corrigé (hors tâche) ; relire la liste des `SCENE` du journal.

## Commits de la branche

- `92fd1bb` le relevé des onze illustrations et le plan ;
- `e55839d` le drapeau, la table, les quatre familles et leur garde ;
- `f1662ec` l'outil de prise, les mesures et la planche ; l'outil « Budget » repris ;
- `52f64e2` câbles et étriers assombris ; l'emprise comptée sur tout pixel changé ;
- `39ac267` le rapport rédigé ; `cdf0804` les comptes de dessin ; `4ad83d9` une première planche ;
- `b07a92c` les trois séances, la planche complète et ce rapport ; le suivant, le verdict de la suite.
