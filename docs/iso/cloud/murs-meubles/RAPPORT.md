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

> État : **fait.** ⟨ÉTAT⟩

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

⟨MESURES⟩

## Les comptes de dessin

⟨BUDGET⟩

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
- **L'écran scindé au pixel près.** ⟨SYM⟩
- **L'éblouissement et la lisibilité en mouvement** (le cloud ne vaut pas pour eux), ni l'impression d'ensemble à la
  vraie taille d'un écran de jeu.
- **Les impacts de balle sur un objet.** Comme les tuyaux et les enseignes, un objet relit la lumière de la face mais pas
  son usure : là où une fissure, une tache ou un impact assombrit la face derrière, l'objet ne l'est pas (voir les mesures).

## Pièges et défauts découverts, à reporter dans la feuille de route

⟨PIEGES⟩

## Commits de la branche

⟨COMMITS⟩
