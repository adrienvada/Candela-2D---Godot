# Le faisceau VISIBLE dans l'air, allumé par défaut (Q41) — rapport de la session cloud « faisceau-visible »

> Branche `claude/cloud-faisceau-visible`, partie de `claude/candidat-0.7.0` (`511c459`), 2026-09-28, de 16:00 à ~17:15
> (Paris). Décision d'Adrien (28/09 vers 15:25, relayée par la session coordinatrice, puis confirmée par Adrien dans cette
> session) : « Q41 : faisceau visible dans l'air » — l'exception à « rien de plus clair que la surface qui le porte » pour le
> faisceau seul, allumé par défaut dans la 0.7.0. **État : fait côté cloud** — voir « État final » en bas.

## Pour Adrien, en cinq lignes

1. **Le faisceau est allumé par défaut, et il éclaire l'air** : ses couches AJOUTENT maintenant la lumière au lieu de la
   mélanger. La tache de ta lampe gagne un coin clair, plus fort près de toi, comme sur les illustrations.
2. **Le noir reste noir** : dans toutes les prises (quatre densités, J1 et J2, vue unique et écran scindé, 45° et 0°), il
   n'allume aucun pixel noir. Une seule faute trouvée en route — quelques pixels à 1-7/255 à la lisière de la lumière, en
   écran scindé — corrigée (le rayon se tait sur la frange très sombre) et revérifiée : zéro.
3. **J'ai choisi la densité 1,20 à l'image** : à 0,70 on le devinait, à 2,0 il lavait la tache ; à 1,20 on voit un faisceau
   clair et le carrelage reste lisible dessous.
4. **Il ne dit rien de plus à l'adversaire** que la tache de lumière au sol, qu'il voyait déjà ; il ne change ni le jeu, ni
   les capteurs, ni l'éblouissement : c'est une image.
5. **Son coût se mesure sur ton Mac** : par lampe allumée, quatre dessins de plus par vue ; le cloud ne sait pas chronométrer.

## 1. Ce qui a changé, et pourquoi

**Le constat de la session « faisceau-air »** (`claude/cloud-faisceau-air`, `docs/iso/cloud/faisceau-air/RAPPORT.md`) :
une couche qui ne montre que la lumière LISSÉE sous elle, MÉLANGÉE au sol, ne peut que ramener la tache vers sa moyenne
— le cœur du cône foncait de 14/255 à 0,45. Un faisceau comme les illustrations demande d'AJOUTER de la lumière dans l'air.
Adrien a accordé cette exception au faisceau seul.

**Le code** :

| fichier | quoi |
|---|---|
| `volume_iso.gdshader` | sous `#ifdef FAISCEAU_LUMINEUX` : `blend_add` au lieu de `blend_mix`. Même couleur (la lightmap lissée sous la couche, dans la pâte, à la température), même opacité (densité × forme × texture de la lampe × grain) : la couche ajoute `couleur × opacité` à l'écran. Sans le define, le shader compilé est celui d'avant (fumée, suie, poussière restent en mélange normal). |
| `iso_volumes.gd` | `faisceau_air` **vrai par défaut** ; `--sans-faisceau-air` l'éteint **en build de débogage seulement** (comme `--sans-fumee-masque`) ; `--faisceau-air=<densité>` règle toujours. Les couches du rayon reçoivent `FAISCEAU_LUMINEUX` par-dessus leur forme pochoir (`_poser_forme_imposee(…, lumineux)`) ; le juge du pochoir non (il n'écrit aucune couleur). `VOLUME_FAISCEAU_AIR` : 0,36 tuile, 3 couches, **densité 1,20**. La ligne du journal dit l'état : `[faisceau air] allumé — 3 couches lumineuses (additives)…` ou `[faisceau air] éteint (--sans-faisceau-air)`. |
| `tools/test_iso_gadgets.gd` (dans `run_suites.sh`) | les gardes (§ 3) |
| `tools/loupe_faisceau_air.gd`, `tools/loupe.gd`, `tools/faisceau_air/` | la preuve à l'image et la planche (repris de `claude/cloud-faisceau-air`) |

**Ce qui ne bouge pas** : le pochoir (une couche se tait là où ce que le pixel montre derrière elle s'affiche noir) ; les
couches sous les murets (la plus haute à 12,6 px < 14,0) ; la forme = la texture de la lampe, tournée comme elle (rien hors du
cône) ; chaque vue lit SA lightmap (le rayon d'en face n'apparaît que sur une lumière que ce joueur voit déjà) ; rien n'entre
dans la lightmap, donc ni les capteurs, ni l'éblouissement, ni l'apparition ne changent. `Protocol.VERSION` reste 18 ; ni
`player.gd` ni la simulation ne sont touchés.

## 2. La densité, choisie à l'image

Bloc `adv` (le rayon de J2 vu par J1, vue unique, 45° B, J1 lampe éteinte), densités 0,35 / 0,70 / 1,20 / 2,0 — B − A sur le
canal le plus fort, cœur = quart le plus clair du sol éclairé que le rayon change, bord = quart le plus sombre :

| densité | cœur du cône (sol sans rayon ≈ 125/255) | bord (sol ≈ 21) | pixels changés | fuite dans le noir | à l'œil (loupe 1:1) |
|---|---|---|---|---|---|
| 0,35 | +11,5 | +2,1 | 35 679 | **0** | on le devine |
| 0,70 | +21,8 | +3,1 | 38 880 | **0** | un coin pâle, discret |
| **1,20** | **+36,4** | **+4,1** | 40 972 | **0** | **un faisceau clair ; les dalles restent lisibles** |
| 2,0 | +54,7 | +6,2 | 42 617 | **0** | le cœur blanchit, la tache se lave |

(0,05 / 0,10 / 0,20 essayées d'abord : +2 à +7 au cœur, invisibles.) **1,20 retenue** : la plus forte qui ne lave pas la
tache. Le rayon est le plus clair près de la lampe (la lumière y est la plus forte) et s'éteint vers le bout du cône, comme
les illustrations ; les trois couches, décalées en hauteur, y tracent des stries parallèles à la visée.

## 3. Les gardes (`tools/test_iso_gadgets.gd`, dans `run_suites.sh`)

Headless, donc sans pixel : ce que la suite peut tenir.
- **défaut allumé** : un `IsoVolumes` neuf a `faisceau_air` vrai ; dans la manche, lampe de J1 allumée, le rayon est posé sans
  aucun drapeau ;
- **éteint en débogage seulement** : la ligne `elif arg == DRAPEAU_SANS_FAISCEAU_AIR and OS.is_debug_build():` ; éteint, aucune
  couche ;
- **la variante lumineuse, et elle seule** : les couches portent `FAISCEAU_LUMINEUX` et le pochoir ; le juge ne porte pas
  `FAISCEAU_LUMINEUX` ; dans `volume_iso.gdshader`, `blend_add` n'existe QUE sous `#ifdef FAISCEAU_LUMINEUX`, le `#else` garde
  `blend_mix` ; le define est posé AVANT le choix du mélange (sinon la variante mélangerait en silence) ;
- **noir absolu, dans ce que la suite peut voir** : le pochoir sur les couches et son juge qui l'écrit ; jamais hors du cône
  (la forme est la texture de la lampe) ; jamais sans lampe (lampe éteinte, le rayon part) ; sous les murets ;
- **la vue d'en face** : les couches lisent la lightmap de chaque vue (J1 et J2) ;
- **l'équité des volumes** : couper les images ne change ni les lumières 2D, ni les capteurs (garde existante, rayon compris).

**Le noir absolu au pixel ne peut pas entrer dans `run_suites.sh`** : rien n'est rastérisé en headless. Il se prouve par le plan
`loupe-faisceau-air` du photographe (fenêtre réelle), § 4.

## 4. Les preuves à l'image

Le plan `loupe-faisceau-air` (repris de la session « faisceau-air ») : le Cloître, LED figées, respiration de la torche figée,
une seule lampe allumée par bloc, la scène tenue au bit près, le rayon basculé sur place ; A (sans rayon) cinq fois, B aux
quatre densités (0,35 / 0,70 / 1,20 / 2,0) puis à la densité du moment (`b`). Critère : là où les cinq A sont noires, chaque
B l'est. ⚠️ Les images sortent en **1280×720** : la base `candidat-0.7.0` n'a pas le correctif du photographe qui retaille la
fenêtre sous Xvfb (`claude/cloud-photographe`, `0c67705`) — signalé, pas corrigé (hors de ma tâche). La preuve du noir vaut à
cette taille de fenêtre ; la planche n'est pas au 1:1 de 1920×1080.

### 4a. Le noir, bloc par bloc (zéro vérifié non vide : pixels noirs dans les cinq A)

| bloc | ce qu'on juge | 45° B : noirs / fuite aux 4 densités + `b` | 0° : noirs / fuite |
|---|---|---|---|
| `adv` | le rayon de J2 vu par J1, vue unique | 405 298 / **0 0 0 0 · 0** | 407 309 / **0 0 0 0 · 0** |
| `eq-est`, `eq-sud-ouest` | J2 au nord du pilier, lampe allumée ; J1 lampe éteinte | 404 950, 414 984 / **0**, **0** | 407 172, 416 904 / **0**, **0** |
| `s1` | écran scindé, lampe de J1 : la moitié de J2 | 231 856 / **0 0 0 0 · 0** (après la marge) | 156 704 / **0 0 0 0 · 0** (après) |
| `s2` | écran scindé, lampe de J2 : la moitié de J1 | 129 087 / **0 0 0 0 · 0** (après la marge) | 147 470 / **0 0 0 0 · 0** (après) |
| `sien` | sa propre lampe, sa propre vue | 0 noir (son voile d'éblouissement relève tout) | non jugeable au noir |

**La fuite de l'écran scindé, et sa correction** (la seule faute trouvée). Avant la marge, les sous-vues de l'écran scindé
allumaient quelques pixels noirs : à 45° B, `s1` **5 / 14 / 22 / 31** pixels à 0,35 / 0,70 / 1,20 / 2,0 (1 à 7/255), `s2`
0 / 4 / 7 / 11 (1/255) ; à 0°, 1 à 8 pixels (1/255). **Leur nombre suivait la densité : c'était le rayon.** Tous à la
lisière de la lumière (des pixels affichés noirs au milieu d'une frange à 8-12/255) : le juge les croyait visibles (écrits
au-dessus de 8/255), l'écran de la sous-vue les montrait noirs. En mélange, une couche ne changeait rien à un tel pixel ; en
additif, elle y ajoute. Jamais en vue unique. **Correction** : le juge du faisceau seul prend `FAISCEAU_LUMINEUX_JUGE`, un
point noir à 16/255 au lieu de 8 (`volume_masque.gdshaderinc`) ; le rayon se tait sur la frange très sombre, où il
n'ajoutait que ~3/255. La fumée garde son juge à 8. **Contre-épreuve** (mêmes scènes, écran scindé seul, `--faisceau-blocs=s1,s2`) :
**0 fuite** aux quatre densités, à 45° B et à 0°, dans les deux moitiés — et le rayon reste aussi visible (+54/255 au cœur à
1,20 en `s1`).

⚠️ Les blocs en vue unique (`adv`, `eq-*`, `sien`) ont été pris AVANT la marge (ils ne fuyaient pas) ; la marge ne peut que
taire davantage le rayon (un seuil plus haut dit « noir » plus souvent), jamais l'allumer ailleurs. Leur prise `b` est à la
densité de ce moment (0,70) ; les prises à 1,20 sont les `b120`.

### 4b. Ce que le rayon ajoute (densité 1,20)

| | 45° B | 0° |
|---|---|---|
| `adv`, cœur / bord | +36,4 / +4,1 | +38,0 / +4,6 |
| `s1` (J1 vu de J2), cœur / bord | +54,2 / +3,9 | +55,5 / +3,1 |
| `s2` (J2 vu de J1), cœur / bord | +43,3 / +4,9 | +37,1 / +4,7 |
| `sien` (J1, voile compris), cœur / bord | +58,1 / +17,0 | +56,7 / +14,8 |

Le rayon adverse (`adv`, `s2`) et le sien vu de l'autre (`s1`) ont la même allure ; l'écart tient au sol sous chaque cône (J1
et J2 ne visent pas le même carrelage). Le plus clair du rayon ne dépasse pas le plafond de l'écran (230 à 255/255 dans les
deux cas) : il éclaire le cône sans le brûler.

### 4c. L'équité

Le rayon ne se dessine que par-dessus ce que l'écran montre déjà éclairé (le pochoir) : dans les prises d'équité, **0 pixel
noir allumé** ; il change 40 000 à 45 000 pixels, tous dans la tache de lumière. Il ne dit donc rien de plus que la tache
(d'où part la lumière, où elle va) : il la rend plus lisible, à égalité pour les deux joueurs (chaque vue lit sa lightmap).
Ce qu'un rayon SANS masque aurait dit — une lueur au-dessus d'un sol noir, derrière un mur ou au-delà d'un muret — il ne le
dit pas.

### 4d. La planche

`planche.html` (dans ce dossier, images sous `img/`, 8 Mo) : les neuf illustrations à faisceau ; puis, à 45° B et à 0° :
le tableau des mesures ; pour chaque bloc, sans / avec le rayon, la différence ×8, la carte du noir (rouge = fuite : il n'y en
a pas), les loupes ×3 sur le cône (centrées sur ce que le rayon change), et les quatre densités (`adv`, `s1`, `s2`). Regardée
avant d'écrire ses légendes.

## 5. Le prix

**Appels de dessin et primitives** : la géométrie est exactement celle de l'essai éteint (trois couches et un juge par lampe
allumée et par vue), mesurée avec l'outil de la session Budget par la session « faisceau-air » (six cartes, 0° et 45°) :
**+8,5 appels et +17 primitives en vue unique** (pire carte +10), **+13 à +16 appels et +26 à +32 primitives en écran scindé**
(pire +18) ; aucune vue rendue, copie d'écran, lumière ni ombre de plus. Le passage au mélange additif ne change aucun de ces
compteurs (un mode de mélange, pas un objet) ; je ne l'ai pas re-relevé ici. Allumé par défaut, ce prix est désormais payé dans
toute manche où une lampe est allumée.

**Ce que le cloud peut dire de la cadence, sans chronomètre** : les couches, compilées SANS masque (le pochoir teste le
stencil avant leur shader), sont le shader ordinaire d'un volume (≈ 2 000 instructions, 9 lectures de lightmap) ; le juge pose
la question du masque (forme compacte, bande resserrée) une fois par pixel de son carré (~ 320 px de monde de demi-côté).
C'est le même travail que la fumée d'une fusée sous `--fumee-masque-pochoir`, pour une surface plus petite, et deux lampes au
plus. **La cadence reste à mesurer sur le Mac** : la série en miroir du banc (le pompe sous une fusée, les deux torches
allumées), le défaut contre `--sans-faisceau-air`, avec la règle des 3 %. Aucun chiffre de temps ici.

## Refaire

```bash
# Godot 4.7 (Linux), Xvfb ; une fois : godot --headless --path . --import ; pip install numpy pillow
godot --headless --path . --script res://tools/test_iso_gadgets.gd
GODOT=/usr/local/bin/godot ./tools/run_suites.sh
GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" env GODOT=/usr/local/bin/godot \
  ./tools/run_photos.sh --plan=loupe-faisceau-air --led-murs-fige --sortie=user://v45 > v45.log 2>&1
GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" env GODOT=/usr/local/bin/godot \
  ./tools/run_photos.sh --plan=loupe-faisceau-air --led-murs-fige --lacet=0 --lacet-j2=A --sortie=user://v0 > v0.log 2>&1
python3 tools/faisceau_air/preuve.py ~/.local/share/godot/app_userdata/Candela\ 2D/v45/loupe v45.log p45
python3 tools/faisceau_air/preuve.py ~/.local/share/godot/app_userdata/Candela\ 2D/v0/loupe v0.log p0
python3 tools/faisceau_air/planche.py docs/iso/cloud/faisceau-visible "45° B=p45" "0° A=p0"
# Sur le jeu : il est allumé ; godot --path . -- --sans-faisceau-air l'éteint (débogage) ; --faisceau-air=0.7 règle la densité.
```
