# Le disque violacé de l'écran scindé — d'où il vient

Session cloud, branche `claude/cloud-disque-violace`, partie d'`origin/claude/cloud-ecart-11` (2a2c099), le 28/09/2026
entre ~05:10 et ~07:30 (heure de Paris). Lancée par la session coordinatrice « CLOUD ISO UNRAILED ».

## Pour Adrien, en cinq lignes

1. Le rond violet très pâle qu'on voyait dans la moitié de J1, en écran scindé, n'est ni le voile d'éblouissement ni
   une lumière du jeu : c'est la **petite lampe qui suit ton curseur dans les menus**, restée allumée pendant la partie.
2. Il y en a deux, une bleue (J1) et une rouge (J2), posées l'une sur l'autre sur le dernier bouton choisi : ensemble,
   elles font du violet. Elles allument le noir jusqu'à 21 sur 255, là où il devrait rester noir.
3. Elle est d'un seul côté parce qu'elle est collée à l'écran, pas au monde : elle reste là où était le bouton dans le
   menu, et ce bouton était à gauche. Elle change de place d'un lancement à l'autre parce que le bouton n'était pas
   toujours au même endroit au moment où le curseur s'y est posé.
4. La correction tient en deux lignes : la lampe s'éteint quand le menu se ferme, comme le curseur à côté d'elle. Elle
   est prête sur cette branche, avec un test qui échoue sans elle, mais **elle n'est pas dans le jeu** tant que tu ne
   l'as pas acceptée.
5. Avec elle : plus aucun pixel allumé à l'endroit du rond, les deux moitiés sont pareilles, et quand un joueur regarde
   vraiment la lampe de l'autre, les deux sont toujours éblouis, exactement autant.

## 1. Reproduction et mesures

Commande du § 5 de l'évaluation 11, reprise telle quelle (`--scenes=equite`, jeu par défaut, lacet 45° B, zoom ×1,5,
1920×1080, `--fixed-fps 60`). **Première image regardée : aucune intro** (l'outil la congédie), le disque est là au premier
lancement.

| lancement | centre écran (moitié de J1) | couleur au centre | pixels violacés | bouge d'une image à l'autre ? |
|---|---|---|---|---|
| `user://` déjà servi (`.xdg`, 3 lancements) | (653, 259) — sur le sommet du pilier nord | (21, 17, 20) sur le noir | ≈ 9 100 au cœur, 12 400 allumés > 7/255 | **non** : 6 prises à 20 images d'intervalle, jeu en marche, centre à ±0,5 px |
| `user://` neuf (`.xdg-neuf`, 2 lancements) | (97, 36) — coin haut gauche, coupé par le bord | (19, 15, 19) | ≈ 9 300 | non |

C'est exactement ce que l'évaluation 11 a vu : « au défaut : coin haut gauche » (son lancement `defaut` était le premier
sur un `user://` neuf) ; « au témoin et avec les essais : sur le pilier » (les lancements suivants).

- **Rayon** : la flaque a 250 px de rayon nominal (`MenuTorch.RAYON`), mais ses anneaux extérieurs tombent sous 1/255 ;
  ce qui se voit fait ~180 px de rayon (boîte des pixels changés : 361 × 338 px). Dix anneaux concentriques
  (`draw_circle` empilés), d'où le motif en cible.
- **Position dans le monde : aucune.** Le disque est dessiné par un `Control` de l'interface, à une place fixe de
  l'ÉCRAN. Il ne suit ni caméra ni joueur ; qu'il tombe « sur le pilier » est une coïncidence de cadrage.

## 2. Le nœud qui le dessine

Outil `tools/photo_disque.gd` (héritier de `photo_ecart.gd`, la même scène `equite`) : jeu en pause, une **descente
dans l'arbre** — à chaque niveau, cacher un à un les enfants qui dessinent (CanvasItem, CanvasLayer, Node3D ; pour un
nœud qui n'est ni l'un ni l'autre, tous ses descendants cachables d'un coup), reprendre l'image, compter le disque dans
le jeu même, descendre dans celui dont l'absence l'éteint. Cinq essais suffisent :

```
REFERENCE j1=977 j2=0
ESSAI 1 /root/PhotoDisque                     → j1=0
ESSAI 2 /root/PhotoDisque/Main                → j1=0
ESSAI 3 /root/PhotoDisque/Main/SplitScreen    → j1=981   (les deux vues du jeu cachées : le disque RESTE)
ESSAI 4 /root/PhotoDisque/Main/UI             → j1=0
ESSAI 5 /root/PhotoDisque/Main/UI/TorcheCurseur → j1=0
```

L'essai 3 dit l'essentiel : **tout le rendu du duel caché, le disque reste.** Ce n'est donc ni le voile (qui est dans
l'UI mais n'a pas été retenu), ni une lumière, ni un halo, ni la présentation 3D.

**Le coupable : `Main/UI/TorcheCurseur`**, un `MenuTorch` (`menu_torch.gd`, M9 « la torche du curseur »), enfant direct
du `CanvasLayer` de l'interface, `top_level`, plein écran (0, 0, 1920 × 1080), sans matériau, `visibility_layer` 1,
`light_mask` 1, `z_index` 0. Au moment de la prise :

```
_cibles    = { 0: { pos (648.0, 264.34), teinte (0.29, 0.72, 0.97) },     ← J1, Charte.BLEU
               1: { pos (648.0, 264.34), teinte (0.95, 0.29, 0.33) } }    ← J2, Charte.ROUGE
_positions = { 0: (648.0, 264.34), 1: (648.0, 264.34) }
_intensite = 1.0 · _pulse = 0.0 · process = false (lampe posée, plus rien ne bouge)
curseurs de menu (liserés) : cachés
```

**Pourquoi violacé :** deux flaques au même point, bleu + rouge. Vérifié en changeant la teinte posée dans la scène
lancée : rouge seul → (31, 4, 4), vert seul → (4, 31, 4), bleu seul → (4, 4, 30) au centre ; les deux teintes du jeu
superposées → (21, 17, 20). L'alpha au centre, 10 anneaux × `ALPHA 0,05 × part² × 0,35`, cumule ~0,07 par flaque.

**La piste du voile d'éblouissement est écartée**, et pas seulement par l'élimination : le voile est crème
(`Charte.HALOGENE`), plein cadre (il n'a pas de bord, c'est sa règle), et il est posé des deux côtés au même niveau dans
cette scène (J1 et J2 à 0,060, la rétrodiffusion de leur propre torche : **personne n'y est ébloui**, le pilier coupe la
ligne entre eux).

## 3. Pourquoi chez J1 seul, et pourquoi il change de place

**Le mécanisme.** `ui._set_focus(joueur, contrôle)` — le point de passage de toute sélection de menu — allume la flaque
du joueur au centre du contrôle visé (`menu_torch.viser(joueur, centre, couleur)`). Le code de `MenuTorch.viser` dit :
« `null` éteint la torche de ce joueur — **hors menu, il n'y a pas de lampe** ». Mais **aucun appel ne passe `null`**,
nulle part dans le dépôt. Et même passé, `viser(j, null)` n'aurait rien effacé : il retire la cible sans demander de
redessin, et `_draw` ne tourne que sur demande. `_update_focus_rings()` cache bien les deux liserés quand aucun menu
n'est ouvert — mais pas la flaque qui les accompagne.

Donc, à chaque lancement de manche depuis un menu, les deux flaques restent peintes par-dessus le match, au centre du
dernier contrôle visé par chaque joueur, jusqu'au prochain menu.

**Chez J1 seul :** parce que le contrôle visé est dans la moitié gauche de l'écran. Ce n'est pas une affaire de vue ni
de joueur : un bouton à droite l'aurait mis chez J2. En vue unique (en ligne, entraînement), la flaque est aussi là, en
plein milieu du seul écran.

**Il change de place d'un lancement à l'autre, jamais d'une image à l'autre** (§ 1) : sa place est celle du contrôle
au moment où le curseur s'y est posé. Le contrôle mesure 196 × 37 px (la taille des boutons de classe des râteliers J1/J2,
`MilieuDuSalon/Rateliers/…/Classes/@Button`). Dans un `user://` neuf, il n'était **pas encore mis en page** : rectangle
en (0, 0), centre (98, 18) — le coin haut gauche, disque coupé par le bord, centre mesuré (97, 36). Dans un `user://`
déjà servi, le même geste tombe après la mise en page : centre (648, 264). Je n'ai pas identifié lequel des contrôles de
196 × 37 est visé en dernier (§ « Pas pu prouver »).

**Ce n'est pas un effet du rendu llvmpipe.** Le dessin est un `draw_circle` d'interface à couleur et alpha constants, sans
shader ni lumière : le même partout. Ce qu'il faudrait regarder sur le Mac pour le confirmer en jeu réel (je ne l'ai pas
vu hors de l'outil de prise) : **lancer « 1v1 écrans scindés » en cliquant JOUER, puis, torches allumées, faire une
capture et l'amplifier ×6 à l'endroit où se trouvait le dernier bouton cliqué ou survolé** (souris ou manette) ; on doit
y trouver un disque de ~180 px de rayon, ≈ (19, 15, 19) sur le noir — bleuté si seul J1 a visé ce bouton. Avec le
correctif, rien. Remarque : sur le Mac, un survol de souris déplace aussi la sélection, donc la place suivra le dernier
bouton sous la souris.

## 4. La correction proposée — non appliquée au jeu par défaut

Commit **cd5b300** « la torche de menu s'éteint hors du menu (proposition) », qui ne touche que `menu_torch.gd` et
`ui.gd` (12 lignes dont 9 de commentaire) :

- `ui._update_focus_rings()`, dans la branche « aucun menu ouvert » qui cache déjà les deux liserés :
  `menu_torch.viser(0, null, …)` et `viser(1, null, …)` — la flaque s'éteint avec le liseré ;
- `MenuTorch.viser(j, null)` : `queue_redraw()` **seulement si** une flaque était allumée (`Dictionary.erase` renvoie
  vrai). `_update_focus_rings` tourne à chaque image : sans cette condition, le match redessinerait à vide à chaque image,
  contre la règle de la vitrine (« un menu au repos ne doit rien consommer »).

Aucun masque de lumière, aucun shader, aucun drapeau, `Protocol.VERSION` inchangé. Ce n'est pas un ajout visuel : c'est
l'extinction d'un effet de menu qui débordait. **Je ne l'ai pas mise derrière un drapeau** : un drapeau qui garderait le
défaut allumé n'aurait pas de sens ; la branche est la proposition, l'intégration la reprendra avec ton accord.

**La garde** — commit **b6f41a9**, `tools/test_torche_hors_menu.gd`, ajouté aux suites : menu ouvert, les deux curseurs
posés → les deux flaques allumées ; menu fermé comme au lancement d'une manche (`hide_game_over`) → liserés cachés, flaques
éteintes, torche redessinée, puis plus aucun redessin ; menu rouvert → la flaque revient.
**Sans le correctif : 3 échecs** (flaque J1 allumée, flaque J2 allumée, aucun redessin). **Avec : 10/10.**

**Cueillette à blanc** sur `origin/integration-iso14` (a30a407), dans un worktree : `git cherry-pick cd5b300 b6f41a9`,
sans conflit ; la garde y passe.

**La preuve à l'image**, quatre lancements (avant = le code d'aujourd'hui, après = avec cd5b300), `user://` déjà servi :

| scène | lacet | disque avant (px violacés J1 / J2) | après | allumés > 7/255 sur du NOIR, avant → après | luminance moyenne J1 / J2 après |
|---|---|---|---|---|---|
| `equite` (torches, pas d'éblouissement) | 45° B | 9 107 / 0 | **0 / 0** | 12 230 → **0** | 19,51 / 19,72 |
| `equite` | 0° | 2 265 / 0 | **0 / 0** | 2 724 → **0** (le reste du disque tombait sur du sol éclairé) | 17,43 / 17,51 |
| `eblouis` (face à face) | 45° B | disque sous le voile | disparu | — | **58,52 / 58,09** |
| `eblouis` | 0° | idem | disparu | — | **60,34 / 60,02** |

- **Hors du disque, avant et après ne diffèrent que par les deux corps**, et pareillement dans les deux moitiés
  (`img/equite_45_difference.jpg`) : les gestes des corps ne sont pas déterministes sous llvmpipe. Pixels changés de plus
  de 7/255 hors disque, moitié de J2 : 194 à 45°, 0 à 0°.
- **L'éblouissement légitime est intact et égal** : scène `eblouis`, J1 et J2 face à face sur la rangée 7 du Cloître, à
  5 cases (175 px), miroir gauche-droite (aucune paire symétrique par le CENTRE ne se voit : le pilier central coupe toutes
  les droites qui y passent). **`dazzle` J1 = J2 = 0,654, avant comme après, aux deux lacets** ; les deux voiles posés,
  luminance des deux moitiés à 0,5 près (`img/eblouis_45_apres.jpg`). Le correctif ne touche aucun chemin de l'éblouissement.
- Une première tentative à 13 cases (455 px) n'éblouissait personne : la torche cesse d'éblouir vers 400 px
  (`Eblouissement.intensite_proximite`). Notée pour qui voudra refaire une scène d'éblouissement.

## Images (`img/`, JPEG qualité 85, 3,4 Mo)

- `enquete_reference_x6.jpg` / `enquete_torche_cachee_x6.jpg` : la même image gelée, ×6, avec et sans `TorcheCurseur`.
- `repro_user_neuf_x6.jpg` : le cas « coin haut gauche » d'un `user://` neuf.
- `equite_{45,0}_{avant,apres}[_x6].jpg`, `equite_{45,0}_difference.jpg` (blanc = pixel changé) : la preuve à l'image.
- `eblouis_{45,0}_{avant,apres}.jpg` : l'éblouissement légitime, des deux côtés.
- `mesures.json` : les chiffres du tableau (`mesurer.py`).

## Pièges et défauts découverts, à reporter dans la feuille de route

1. **La torche de menu (M9) débordait sur le match** — cause du disque violacé, corrigée par la proposition cd5b300.
   Leçon : `MenuTorch.viser` documentait un contrat (« `null` éteint ») que personne n'appelait et qu'il n'aurait pas tenu
   (pas de redessin). **Un `CanvasItem` qui ne dessine que sur demande garde son dernier dessin indéfiniment** : retirer
   une donnée sans `queue_redraw()` n'efface rien.
2. **Les prises « vue » du photographe cachent l'interface** (`_capturer_la_vue_iso` en vue unique) : c'est pourquoi
   seules les prises « ecran » (écran scindé) voyaient le disque. Un défaut d'interface qui déborde sur le jeu est
   invisible à toute prise « vue » — à savoir avant de conclure « le noir est propre » sur une prise « vue ».
3. **La place d'un effet collé à un contrôle dépend de l'histoire du `user://`** : un premier lancement vise un contrôle
   pas encore mis en page, donc en (0, 0). Deux lancements « identiques » ne le sont pas si l'un part d'un `user://` neuf.
4. **Pour une scène d'éblouissement : moins de ~400 px entre les joueurs**, sinon personne n'est ébloui.
5. Hors tâche, signalé : **les autres effets « vitrine » posés par `_set_focus` peuvent avoir le même défaut** — le fond
   de menu (`menu_backdrop.viser`), le regard (`menu_watcher.reveiller`). Je ne les ai pas vus à l'image (l'élimination
   n'a rien trouvé d'autre d'allumé), je ne les ai pas lus en entier : à vérifier par qui tient la vitrine.

## Pour tout refaire

```bash
git fetch origin claude/cloud-disque-violace && git checkout claude/cloud-disque-violace
godot --headless --path . --import                       # la première fois
pip install pillow numpy scipy
# 1. L'enquête (dérive image à image puis élimination par descente dans l'arbre), sur le code d'AVANT le correctif :
git worktree add ../dv-avant HEAD && (cd ../dv-avant && git checkout ceeca1d -- menu_torch.gd ui.gd && cp -r ../Candela-2D---Godot/.godot .)
(cd ../dv-avant && XDG_DATA_HOME=$PWD/../Candela-2D---Godot/.xdg xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 \
  --path . res://tools/photo_disque.tscn -- --no-eos --led-murs-fige --sortie=user://disque/enquete --scenes=equite)
#    variante : --suspect=/root/PhotoDisque/Main/UI/TorcheCurseur (décrit le nœud, ses variables, le bouton sous la flaque,
#    et change la teinte en rouge/vert/bleu) ; un XDG_DATA_HOME vide rejoue le cas « coin haut gauche ».
# 2. Les prises avant/après (ARBRE = ../dv-avant pour avant, . pour après ; NOM = avant2_45, apres2_0… ; LACET = 45 ou 0) :
XDG_DATA_HOME=$PWD/.xdg xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path ARBRE \
  res://tools/photo_disque.tscn -- --no-eos --led-murs-fige --lacet=LACET --sortie=user://disque/NOM --scenes=equite --prises
XDG_DATA_HOME=$PWD/.xdg python3 docs/iso/cloud/disque-violace/mesurer.py
# 3. La garde seule, puis la suite complète :
godot --headless --path . --script res://tools/test_torche_hors_menu.gd
GODOT=/usr/local/bin/godot ./tools/run_suites.sh
```

Sur le Mac : les mêmes commandes sans `xvfb-run`, fenêtre au premier plan.

## Ce que je n'ai PAS pu prouver

- **Le disque dans le jeu réel, hors de l'outil de prise.** L'outil lance la manche par `_on_replay_requested()` après
  `hub.push(SCREEN_LOCAL)`, sans clic. Le mécanisme (aucune extinction hors menu) est lu dans le code et vaut pour tout
  chemin, mais je ne l'ai pas vu après un vrai clic sur JOUER — à regarder sur le Mac (§ 3).
- **Lequel des contrôles de 196 × 37 px** est visé en dernier, ni par quel appel (graine de focus `_seed_focus` ou autre) ;
  seulement sa taille, sa place et que les deux joueurs l'ont visé au même point.
- **La vue unique en ligne** : je n'ai pas pris d'image en ligne (aucun appel EOS ici) ; par le code, la flaque de J1 y est
  aussi, et celle de J2 sans doute (graine de focus des deux joueurs).
- **Le comportement de la pause avec le correctif** : en ouvrant la pause, la flaque ne se rallume qu'au premier
  déplacement du curseur (avant, elle restait allumée depuis le menu précédent, à une place périmée). Couvert par la garde
  pour le menu principal, pas vu à l'image pour la pause.
- **Aucune cadence** : le correctif retire un dessin et n'ajoute rien par image (vérifié par la garde : zéro redessin une
  fois éteinte), mais je ne l'ai pas mesuré — la cadence se mesure au Mac.

## État final

Commits sur `claude/cloud-disque-violace` : b9d5add (plan), ceeca1d (outil d'enquête), **b6f41a9 (garde)**,
**cd5b300 (correctif proposé)**, puis l'outil de prises, les mesures, les images et ce rapport. Suite complète : voir
la dernière ligne ci-dessous.
