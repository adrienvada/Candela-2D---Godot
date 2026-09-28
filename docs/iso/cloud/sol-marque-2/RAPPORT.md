# Le sol marqué, deuxième passage — les points allumés dans le noir

Session cloud, branche `claude/cloud-sol-marque-2`, partie d'`origin/claude/cloud-sol-marque` (9e398d5), le 28/09/2026.
Lancée par la session coordinatrice « CLOUD ISO UNRAILED ».

## Plan (écrit à 07:25, avant tout code)

1. **Reproduire** le défaut de l'évaluation 11 (`docs/iso/cloud/ecart-11/RAPPORT.md` § 4 : torches éteintes, Croisée,
   taches jaunes de 2 à 5 px sur le liseré du sommet d'un mur haut, avec `--sol-marque-essai` seul en cause).
2. **La cause, par une prise dédiée, écrite AVANT la correction** : quelle marque, à quelle distance de l'arête, quelle
   peinture au point où le liseré lit la lumière (`mur_iso.gdshader`, `lire_lumiere_moyenne(… d_bord + pied …)`,
   `pied = 8` posé par `presentation_3d.gd`, quatre lectures à ±0,625 et ±1,875 px le long de l'arête).
   Premier constat, lu dans le code : la garde de l'essai tient les marques à **12 px** des cases de mur, et le liseré lit
   à **8 px** de l'arête, dans une peinture à 1 texel par pixel de monde, filtrée linéairement. Sur le papier, 4 px de
   marge : il faut donc trouver ce que le papier ne voit pas (une emprise plus large que promise, une arête qui n'est pas
   celle d'une case de mur, un autre calque de peinture).
3. **Corriger dans l'essai seulement** (tenir les marques loin des points de lecture, filtrage compté), avec une garde
   headless sur les six cartes. Le shader des murs n'est pas touché : si la division par la peinture est la vraie cause,
   c'est écrit ici pour Gadgets.
4. **Les pochoirs** (`--pochoirs-essai`) : même calcul, même prise ; signalés s'ils peuvent faire la même tache.
5. **La preuve** : six cartes, 45° B, vue unique et écran scindé, torches éteintes, prises A/B/A' ; torches allumées,
   rien de plus clair que la surface qui porte ; drapeau éteint, rien ne change au bit ; suite complète verte.

## 1. La cause (établie à 08:50, AVANT toute correction)

**Ce ne sont pas les marques de la Croisée. Ce sont celles du Cloître** : quand la carte change pendant que la vue iso est
allumée, les murs de la nouvelle carte continuent de diviser leur lumière par la PEINTURE DE L'ANCIENNE (`peinture_iso.gd`).
Le banc de l'évaluation 11 (`tools/photo_ecart.gd`, scènes `croisee` et `bunker`) passe du Cloître à la Croisée dans la même
partie, vue allumée ; les marques du Cloître tombent sous des points où les murs de la Croisée lisent la lumière.

### Le mécanisme, dans le code

- `presentation_3d.gd:493` : quand `rebuild_arena()` rappelle le crochet pendant que la vue tient (`_reconstruire`), la
  présentation refait **les murs** (`_construire_les_murs`) — et rien d'autre. La peinture n'est refaite que par
  `_allumer` (`presentation_3d.gd:606`, `_poser_peinture`), c'est-à-dire quand la vue s'allume.
- La peinture (`peinture_iso.gd`) est faite de **copies** des calques de l'arène (`CustomFloor_P1`, `ArenaDecor_P1`,
  `MurEncre_P1`), enfants de la sous-vue. `rebuild_arena` libère les originaux ; les copies restent, avec l'ancienne
  texture cuite du décor (`_decor_source` n'est plus valide, `_process` ne la remplace plus). Le cadre reste aussi celui de
  l'ancienne carte.
- `mur_iso.gdshader`, `lire_lumiere` : `l × réf ÷ max(peinture, plancher)`. Sous la lumière des LED (réelle), une
  peinture étrangère plus sombre que le sol — une marque, une encre de mur, un mur — gonfle la lecture jusqu'à ×3,3
  (réf 0,163 ÷ plancher 0,05).

### La preuve, par une prise dédiée (`tools/photo_sol_marque_noir.gd`)

Croisée, torches éteintes, J1 et J2 à la place de l'évaluation 11, LED figées, les neuf drapeaux d'hier ; chaque prise est
triple au même instant, jeu en pause (A marques, B marques retirées et décor recuit, A' remises). Pixels de l'évaluation 11 :
(1041, 305) et (1046, 309).

| lancement | peinture lue par les murs | A | B | A' |
|---|---|---|---|---|
| Croisée posée directement, sol marqué | 1050 × 1050 (la sienne) | (4, 0, 0) | (4, 0, 0) | (4, 0, 0) |
| **par le Cloître**, sol marqué (`--par=map_001_le_cloitre`) | **1120 × 1120 (celle du Cloître)** | **(49, 36, 14)** | **(49, 36, 14)** | **(49, 36, 14)** |
| par le Cloître, sans essai (`--temoin`) | 1120 × 1120 (celle du Cloître) | (4, 0, 0) | (4, 0, 0) | (4, 0, 0) |

- Posée directement, la Croisée n'a pas les taches, marques ou pas : **0 pixel noir allumé par l'essai** (A contre B).
- Passée par le Cloître, les taches sont là **aussi en B**, marques de la Croisée retirées : ce ne sont pas elles.
- Elles disparaissent du témoin sans essai passé par le Cloître : elles viennent des marques **du Cloître**, dans la
  peinture restée branchée (la ligne `PEINTURE` du journal donne la taille que le matériau des murs lit : 1120, pour une
  carte de 980 + 70).
- Reproduit aussi sur le code même de l'évaluation 11 (worktree de `origin/claude/cloud-ecart-11`, 2a2c099) : sa commande
  donne (49, 36, 14) avec le drapeau et (4, 0, 0) sans ; ma prise triple, Croisée posée directement, n'en montre aucune.

**Le calcul le confirme** (`lecture.py` : les quatre lectures bilinéaires de chaque arête exposée de mur haut, divisées puis
moyennées, comme le shader). Avec les murs de la Croisée et la peinture cuite du Cloître, six arêtes lisent autrement ; celle
de la case (7, 7), face nord, lecture en (258,75 ; 233) — le sommet photographié — gagne **×1,73** (peinture 0,163 → 0,054) ;
la pire, case (25, 4), ×2,27. Au Bunker, par le Cloître, sept arêtes, ×1,66 au pire : les taches « sous le bruit » de
l'évaluation 11. **Avec la peinture de leur propre carte, 0 arête sur les six cartes** (sol marqué comme pochoirs), dans la
texture cuite comme dans la peinture vidée en jeu : les marques les plus proches d'une case non-sol en sont à **13,5 px**
(centre du texel), les lectures à 12 px, le filtre bilinéaire n'atteint qu'1 px au-delà.

### Deux erreurs de lecture qu'il faut corriger ailleurs

- **`pied` vaut 12 px en jeu, pas 8.** `mur_iso.gdshader` le déclare à 8 et `presentation_3d.gd:1698` pose 8
  (`PIED_PX`), mais `IsoMateriaux.accorder_mur`, appelé juste après (l. 1700), repose `PIED_FACE_PX` = 12. L'évaluation 11
  a lu le 8 du shader. Le sol marqué ne tenait donc que par une marge d'un demi-pixel (13,5 − 12 − 1), et parce que les
  emprises promises à la garde sont plus larges que le dessin.
- **Ce n'est pas le sol marqué qui enfreint la règle des pochoirs, c'est la peinture périmée**, et elle l'enfreint AUSSI
  sans aucun essai : témoin sans essai posé directement → même témoin passé par le Cloître, **822 pixels noirs s'allument**
  (521 au-dessus de 30/255, 55 au-dessus de 100, jusqu'à 255) : des pans entiers de faces de la Croisée lisent les murs et
  l'encre du Cloître (`img/cause_direct_temoin.jpg` contre `img/cause_par_cloitre_temoin.jpg`, éclaircies ×4).

![la loupe](img/cause_loupe.jpg)

### Ce que cela change pour la tâche

- **Il n'y a rien à corriger dans le sol marqué pour ce défaut.** La correction qui supprime les taches est dans
  `presentation_3d.gd` (refaire la peinture quand la carte change, vue allumée) : c'est le jeu par défaut, hors de ma tâche —
  **signalé, pas corrigé** (§ 5).
- **Les mesures de l'évaluation 11 sur la Croisée et le Bunker sont faites sur la peinture du Cloître** (duel comme noir) :
  à refaire, carte posée directement, ou après la correction.
- Dans l'essai, je rends la marge explicite au lieu de la laisser au hasard (§ 2).

## 2. Dans l'essai : la marge rendue explicite (le défaut n'y est pas, la marge l'était par hasard)

Le sol marqué ne cause pas les taches (§ 1) ; il n'y a donc rien à « corriger » dans ce qu'il peint. Mais sa garde
promettait moins qu'il ne fallait, et la table ne passait que par chance :

- la garde tenait les marques à **12 px** de tout mur (`DEGAGEMENT_MUR`, écrit à la main), alors que la face et le liseré
  lisent la peinture **à** 12 px de l'arête et que le filtrage bilinéaire en prend un texel au-delà : une marque tenant sa
  promesse pouvait peser d'un demi-texel dans la lecture ;
- les gravats promettaient 5 px en travers, posés à une demi-case (17,5 px) d'un mur : leur bord promis tombait à 12,5 px.

**Ce qui change** (`arena_decor.gd`, `tools/test_sol_marque.gd`) :

1. La garde lit le dégagement dans la constante du jeu : `IsoMateriaux.PIED_FACE_PX` (12) + 1 texel de filtre = **13 px**.
   Si `pied` grandit un jour, elle rougit.
2. Les gravats se resserrent à **4,5 px** de leur axe (éclats à ±1,9 au lieu de ±2,2 ; grains d'un pixel entre −4,5 et
   4,5 au lieu de −4 et 5). **Même nombre de tirages** : chaque tas garde son motif, décalé d'un demi-pixel au plus, et son
   jumeau reste son image exacte. Les autres familles tenaient déjà 13 px.
3. Une vérification de plus : la garde rougit sur un tas à 12,5 px d'un mur (l'ancienne emprise), pas à 13 px — 35
   vérifications, 0 échec.

**Mesuré sur les textures cuites** (`distance.py`, `lecture.py`) : drapeau éteint, les empreintes md5 des six cartes sont
**identiques** à celles de la base (`docs/iso/cloud/sol-marque/cuisson_md5.txt`) — rien ne change au bit. Drapeau allumé, le
texel marqué le plus proche d'une case non-sol est à 13,5 px (centre) sur les six cartes, et **0 arête** de mur haut sur 1 552
ne lit autrement.

**Ce que la correction ne fait PAS** : protéger contre la peinture périmée. Aucune place de marque ne le peut — sur une
peinture étrangère, les murs, l'encre et le sol de l'autre carte gonflent déjà la lecture (§ 1, 822 pixels sans essai).

## 3. Les pochoirs (`--pochoirs-essai`)

Même calcul (`lecture.py`, `distance.py`, `croise.py`). **Sur leur propre carte, ils ne peuvent pas faire la tache** : le texel
de pochoir le plus proche d'une case non-sol en est à 42,5 px (l'Usine et le Bunker ; 45,5 au Cloître et à la Croisée, 59,5
et 77,5 aux deux arènes), 0 arête lue autrement. **Par une peinture périmée, si**, comme le sol marqué et plus fort (ils sont
plus sombres et plus larges) : jusqu'à ×2,93 sur une lecture (`croise.txt`, 36 couples de cartes : Arène Standard → Cloître,
Usine ou Bunker ; Cloître → Arène Circulaire ou Croisée ; Usine → Arène Circulaire ; Bunker → Arène Circulaire). Signalé,
pas corrigé : la cause est la même, dans `presentation_3d.gd`.

## 5. Défauts hors de ma tâche — signalés, pas corrigés (à reporter dans la feuille de route)

1. **La peinture iso n'est pas refaite quand la carte change vue allumée** (le défaut de fond, jeu par défaut). Fichier :
   `presentation_3d.gd:493` (`_process` : `if _reconstruire: _construire_les_murs()`) ; la peinture n'est posée que par
   `_allumer` (l. 606). Effet : les faces et les liserés de la nouvelle carte divisent leur lumière par la peinture de
   l'ancienne — pans de faces éclairés à tort (822 pixels noirs allumés à la Croisée par le Cloître, SANS essai, jusqu'à
   255/255), et toute peinture sombre de l'ancienne carte (marques, pochoirs, encre, sang) devient une tache.
   Reproduire : `XDG_DATA_HOME=$PWD/.xdg ./docs/iso/cloud/sol-marque-2/lancer.sh cause`, puis
   `python3 docs/iso/cloud/sol-marque-2/entre.py "<user://>/sm2/direct_temoin" "<user://>/sm2/par_temoin"`.
   Correction proposée (une ligne, non appliquée) : refaire la peinture avec les murs,
   `if _reconstruire: _construire_les_murs(); _poser_peinture()` — `_poser_peinture` retire l'ancienne d'abord. À qui tient
   le rendu iso (Gadgets, selon la session coordinatrice). **Chemin en jeu : non établi.** `_do_start_round` appelle
   `rebuild_arena()` à chaque manche ; tant que le changement de carte passe par le menu principal (où la vue iso s'éteint,
   `_vues_a_projeter`), la peinture est refaite à l'allumage. Les bancs qui changent de carte en cours de partie
   (`photo_ecart.gd` de l'évaluation 11, `_poser_la_carte`) y tombent à coup sûr. Le commentaire de `presentation_3d.gd:491`
   cite lui-même « un salon en ligne adopte celle de l'hôte » : ce cas-là est à vérifier.
   Même carte (revanche) : les copies d'un décor libéré restent, au même contenu — non mesuré au-delà.
2. **Les mesures Croisée et Bunker de l'évaluation 11 (duel et noir) sont faites sur la peinture du Cloître** : à refaire,
   carte posée directement (ou après la correction 1). Le § 4 de son rapport attribue les taches au sol marqué ; c'est faux.
3. **`pied` a deux valeurs écrites et une seule vraie** : `mur_iso.gdshader:46` (8) et `presentation_3d.gd:158`
   (`PIED_PX` = 8, posé l. 1698) sont écrasés par `IsoMateriaux.accorder_mur` (`PIED_FACE_PX` = 12, l. 226) juste après.
   Une lecture du shader ou de la présentation donne 8 : c'est ce qui a égaré l'évaluation 11.
4. **Les pochoirs** : même exposition que le sol marqué à la peinture périmée (jusqu'à ×2,93), aucune sur leur carte (§ 3).

## 6. Pour tout refaire

```bash
git fetch origin claude/cloud-sol-marque-2 && git checkout claude/cloud-sol-marque-2
godot --headless --path . --import                                   # la première fois
pip install numpy pillow
export XDG_DATA_HOME=$PWD/.xdg                                        # un user:// à soi (l'intro est congédiée par le banc)
U="$XDG_DATA_HOME/godot/app_userdata/Candela 2D"
# La garde headless, et la suite complète :
godot --headless --path . --script res://tools/test_sol_marque.gd
GODOT=/usr/local/bin/godot ./tools/run_suites.sh
# La géométrie des six cartes, les textures cuites (sans, sol marqué, pochoirs), et les calculs :
godot --headless --path . --script res://docs/iso/cloud/sol-marque-2/grilles.gd -- --sortie=/tmp/sm2/grilles.json
for v in base: sol:--sol-marque-essai poch:--pochoirs-essai; do mkdir -p /tmp/sm2/${v%%:*}
  xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --script res://docs/iso/cloud/sol-marque/cuisson.gd -- ${v#*:} --sortie=/tmp/sm2/${v%%:*}; done
python3 docs/iso/cloud/sol-marque-2/distance.py /tmp/sm2/grilles.json /tmp/sm2/base /tmp/sm2/sol      # ≥ 13 px partout
python3 docs/iso/cloud/sol-marque-2/lecture.py  /tmp/sm2/grilles.json /tmp/sm2/base /tmp/sm2/sol      # 0 arête
(cd docs/iso/cloud/sol-marque-2 && python3 croise.py /tmp/sm2/grilles.json /tmp/sm2/base /tmp/sm2/sol /tmp/sm2/poch)
# La cause en jeu (quatre lancements, la Croisée), puis la preuve (six cartes, deux lancements) :
./docs/iso/cloud/sol-marque-2/lancer.sh cause
python3 docs/iso/cloud/sol-marque-2/entre.py "$U/sm2/direct_temoin" "$U/sm2/par_temoin"
python3 docs/iso/cloud/sol-marque-2/entre.py "$U/sm2/par_temoin" "$U/sm2/par_avec"
./docs/iso/cloud/sol-marque-2/lancer.sh preuve
python3 docs/iso/cloud/sol-marque-2/noir.py "$U/sm2/seul"; python3 docs/iso/cloud/sol-marque-2/noir.py "$U/sm2/tout"
python3 docs/iso/cloud/sol-marque-2/images.py "$U/sm2" cause
python3 docs/iso/cloud/sol-marque-2/images.py "$U/sm2/seul" preuve
```

Sur le Mac : `ENVELOPPE= GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./docs/iso/cloud/sol-marque-2/lancer.sh …`.

## État

- [x] reproduction (sur cette branche et sur celle de l'évaluation 11)
- [x] cause établie
- [x] correction et garde (la marge explicite ; la cause, hors de l'essai, signalée)
- [x] pochoirs
- [ ] preuves six cartes
- [ ] suite complète
