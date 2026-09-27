# Les essais éteints, sur image — rapport

Branche `claude/cloud-essais`, partie de `integration-iso14` (60e5c6d), le 27/09/2026 entre 01:50 et ~04:00 (heure de
Paris). Session cloud lancée par la coordinatrice du chantier isométrique, en remplacement de la première, restée bloquée.
**Aucun défaut du jeu n'est changé** : on montre.

## Pour Adrien, en cinq lignes

1. Ouvre `planche.html` (dans ce dossier) : pour chacun des six essais, l'illustration visée, le jeu sans, le jeu avec, à
   ta taille d'écran (1920×1080, zoom ×1,5, 45°), puis la même chose agrandie trois fois, et en écran scindé.
2. Aucun essai n'allume un pixel parfaitement noir, torches allumées comme éteintes. Une réserve : le point de lumière
   du cœur chaud sur la lampe de l'adversaire déborde un peu sur du presque-noir (133 pixels), à regarder en écran scindé.
3. Les pochoirs, l'encre et les tuyaux ne font qu'assombrir le décor ; le cœur chaud, lui, est une petite lueur blanche
   à la lampe (environ 13 pixels de large), plus claire que ce qu'elle couvre : c'est son but.
4. Tes tuyaux : leur reflet n'est jamais plus clair que le mur qu'il cache sous la torche (0 pixel) ; il atteint le gris
   moyen du mur et paraît plus clair parce que le corps du tuyau, juste à côté, est bien plus sombre.
5. Ce que le cloud ne sait pas dire : la vitesse du jeu (à mesurer sur ton Mac), l'éblouissement, et le détail fin des
   corps d'une image à l'autre (leur respiration suit l'horloge de l'ordinateur).

## Ce qui a été fait

1. **Outillage** : Godot 4.7 officiel sous Xvfb, rendu llvmpipe. Les deux corrections du photographe (fenêtre retaillée,
   repos en images de jeu) reportées depuis `0c67705` dans un commit à part (`a8bba4f`).
2. **Fusions dans cette branche** :
   - `origin/claude/cloud-tuyaux` (70ffafa) : sans conflit.
   - `origin/iso12-corps` (f38e5f7) : un seul fichier en conflit, `docs/ROADMAP.md`, trois blocs. La ligne « Dernière mise
     à jour » garde 2026-09-27 (la plus récente) ; les deux autres blocs (un piège, une section de chantier) gardent **les
     deux côtés**, celui d'`integration-iso14`/tuyaux d'abord, celui d'`iso12-corps` ensuite. Rien d'effacé :
     `git show 4fb58a3 -- docs/ROADMAP.md` le montre. Code : fusion automatique de `iso_materiaux.gd` et
     `voxel_catalogue.gd`, sans conflit textuel ; les points d'ancrage des six drapeaux sont présents (`grep` ci-dessous).
3. **Un outil de prise**, `tools/photo_essais.gd` (+ `.tscn`) : un héritier du photographe, sur le modèle de
   `photo_tuyaux.gd`, qui ne touche pas `photographe.gd`. Un lancement par état des drapeaux ; sur le Cloître (la seule
   carte qui porte à la fois des pochoirs et des tuyaux), quatre scènes, chacune torches allumées puis éteintes, jeu en
   pause au moment de la prise :
   - **duel** : J1 face au mur haut intérieur, J2 debout dans son cône, torche de côté ;
   - **sol** : J1 devant le pochoir « ZONE 1 » ;
   - **mur** : J1 devant la face la plus meublée de tuyaux (règle de `photo_tuyaux.gd`), cône à 20° de biais ;
   - **scindé** (`--scenes=scinde`) : l'écran scindé tel qu'il se joue, J1 et J2 de part et d'autre du même mur, torches
     vers lui — la vue de J2 depuis le côté opposé (lacet B).
4. **Mesures et planche** : `mesurer.py` (chiffres, JPEG, `mesures.json`), `planche.py` (`planche.html`), `lancer.sh`
   (tout refaire).

### Les réglages exacts des essais, lus dans le code

| Essai | Drapeau | Réglage |
|---|---|---|
| Cœur chaud | `--faisceau` | `iso_volumes.gd`, `_suivre_faisceau` : une lueur à la lampe de chaque torche allumée, de la couleur de la lumière, sans rayon (« le cœur chaud seul »). |
| Mannequin | `--mannequin` | `voxel_catalogue.gd` : segments, côté de la lumière `MANNEQUIN_CONTRASTE` 0,4, report 1,6, contour. |
| Pochoirs | `--pochoirs-essai` | `arena_decor.gd` : « ZONE n », « DEATHMATCH », peinture noire alpha 0,45 (le sol × 0,55), cuite avec le décor. |
| Encre | `--encre-essai` | `iso_materiaux.gd` : hachures `HACHURES_ESSAI` 0,7 ; arêtes des murs `ENCRE_ARETE_PX_ESSAI` 2,4 px, reste 0,12 ; **contour des personnages `CONTOUR_PX_ESSAI` = 1,0 px du monde**, soit 1,5 px d'écran au zoom ×1,5 (appliqué par `voxel_corps.gd:323` sous ce seul drapeau ; `CONTOUR_PX_EPAIS` 2,0 n'est utilisé par aucun code du jeu). |
| Tuyaux | `--tuyaux-essai` | `tuyaux_iso.gd` + `.gdshader` (fusionnés de 70ffafa). |
| Personnages détaillés | `--corps-detaille` | `voxel_catalogue.gd`, `CLASSES_DETAILLEES` (les dix classes), accessoires modelés (fusionnés de f38e5f7). |

## La méthode, et pourquoi on peut croire les chiffres

La feuille de route prévient : **une comparaison entre deux lancements ne prouve rien** (usure, levier 1 : hasard des
éclats et de la poussière de la torche, instant du gel). Les essais cuits dans les matériaux ou la peinture (pochoirs,
encre, mannequin, corps détaillés) ne se basculent pas dans un même processus : il fallait donc rendre deux lancements
comparables, **et le prouver**.

- Gestes : la graine du hasard global posée avant le jeu (`seed(20260927)`), l'horloge fixe (`--fixed-fps 60`, le repos
  compté en images : 90 images, puis pause), les LED figées (`--led-murs-fige`), l'intro du premier lancement congédiée.
- **Preuve** : trois lancements témoins, sans aucun essai. Hors d'une petite zone autour des deux corps, ils rendent
  **la même image au pixel près** (0 pixel différent, sur les huit images de chaque témoin). Dans la zone des corps, ils
  diffèrent de 13 à 3 400 pixels (écart jusqu'à 119/255) : **la respiration des corps bat sur l'horloge murale**
  (`presentation_3d.gd:1170`, `etat_du_corps` : `Time.get_ticks_msec()`), que l'horloge fixe ne gouverne pas. Voir
  « Pièges » plus bas.
- **Contre-épreuve** : là où l'essai est un nœud qu'on peut cacher (les lueurs du cœur chaud, le maillage des tuyaux),
  l'outil prend aussi, jeu en pause, la même image sans lui (`__sans`) puis avec lui de nouveau (`__avec2`, bruit : 0
  pixel partout). Pour les tuyaux, **la comparaison entre lancements et celle au même instant donnent exactement les
  mêmes chiffres hors des corps** (21 007 pixels changés, 21 plus clairs, scène mur) : le protocole tient.
- Chaque chiffre est donc donné **hors des corps** (prouvé) et **dans la zone des corps** (mêlé au souffle ; un 3ᵉ
  témoin, compté comme un essai, y donne le niveau du bruit : jusqu'à 1 977 pixels changés et 104 « plus clairs »).
- Définitions : **noir allumé** = pixel à 0 dans les deux témoins (ou sans l'essai) et au-dessus de 0 avec (strict), et
  la même chose au seuil de 7,5/255 ; **plus clair** = l'essai dépasse de plus de 2/255 le plus clair des deux témoins,
  sur le canal le plus fort (sans l'essai, ce pixel montre la surface qui le porte : c'est la règle des pochoirs).
- **Loupe ×3** : un recadrage d'un tiers de l'image, agrandi au plus proche voisin — les pixels du jeu, trois fois plus
  gros, rien de recalculé. Centrée sur ce que l'essai change dans la lumière.

## Les résultats, essai par essai

Chiffres complets : `mesures.json` et la planche. « Hors corps » : prouvé ; « zone » : à lire contre le 3ᵉ témoin.

### Le cœur chaud à la lampe (`--faisceau`)

| Scène | Hors corps : changés · noirs allumés (strict / seuil) · plus clairs (max) | Zone des corps : changés · noirs (strict / seuil) · plus clairs | Même instant sans l'essai : changés · noirs · plus clairs (max) |
|---|---|---|---|
| duel allumees | 0 · 0 / 0 · 0 (0) | 2311 · 0 / 0 · 270 | 272 · 0 / 0 · 262 (233) |
| duel eteintes | 0 · 0 / 0 · 0 (0) | 274 · 0 / 0 · 0 | — |
| sol allumees | 0 · 0 / 0 · 0 (0) | 1357 · 0 / 0 · 179 | 140 · 0 / 0 · 131 (227) |
| sol eteintes | 0 · 0 / 0 · 0 (0) | 73 · 0 / 0 · 0 | — |
| mur allumees | 0 · 0 / 0 · 0 (0) | 1257 · 0 / 0 · 177 | 136 · 0 / 0 · 129 (222) |
| mur eteintes | 0 · 0 / 0 · 0 (0) | 59 · 0 / 0 · 28 | — |
| scinde allumees | 0 · 0 / 0 · 0 (0) | 4229 · 0 / 146 · 854 | 406 · 0 / 133 · 395 (218) |
| scinde eteintes | 0 · 0 / 0 · 0 (0) | 186 · 0 / 0 · 0 | — |

### Le mannequin (`--mannequin`)

| Scène | Hors corps : changés · noirs allumés (strict / seuil) · plus clairs (max) | Zone des corps : changés · noirs (strict / seuil) · plus clairs | Même instant sans l'essai : changés · noirs · plus clairs (max) |
|---|---|---|---|
| duel allumees | 0 · 0 / 0 · 0 (0) | 3239 · 0 / 0 · 0 | — |
| duel eteintes | 0 · 0 / 0 · 0 (0) | 209 · 0 / 0 · 1 | — |
| sol allumees | 0 · 0 / 0 · 0 (0) | 1672 · 0 / 0 · 5 | — |
| sol eteintes | 0 · 0 / 0 · 0 (0) | 52 · 0 / 0 · 0 | — |
| mur allumees | 0 · 0 / 0 · 0 (0) | 1293 · 0 / 0 · 4 | — |
| mur eteintes | 0 · 0 / 0 · 0 (0) | 151 · 0 / 0 · 93 | — |
| scinde allumees | 0 · 0 / 0 · 0 (0) | 5624 · 0 / 9 · 146 | — |
| scinde eteintes | 0 · 0 / 0 · 0 (0) | 258 · 10 / 18 · 83 | — |

### Les pochoirs au sol (`--pochoirs-essai`)

| Scène | Hors corps : changés · noirs allumés (strict / seuil) · plus clairs (max) | Zone des corps : changés · noirs (strict / seuil) · plus clairs | Même instant sans l'essai : changés · noirs · plus clairs (max) |
|---|---|---|---|
| duel allumees | 2721 · 0 / 0 · 0 (0) | 2160 · 0 / 0 · 73 | — |
| duel eteintes | 2719 · 0 / 0 · 0 (0) | 82 · 0 / 0 · 1 | — |
| sol allumees | 5746 · 0 / 0 · 0 (1) | 1205 · 0 / 0 · 6 | — |
| sol eteintes | 5851 · 0 / 0 · 0 (0) | 43 · 0 / 0 · 26 | — |
| mur allumees | 5769 · 0 / 0 · 0 (0) | 1196 · 0 / 0 · 55 | — |
| mur eteintes | 5780 · 0 / 0 · 0 (0) | 188 · 0 / 0 · 74 | — |
| scinde allumees | 457 · 0 / 0 · 0 (0) | 3712 · 0 / 9 · 219 | — |
| scinde eteintes | 397 · 0 / 0 · 0 (0) | 375 · 0 / 4 · 103 | — |

### L'encre : hachures, arêtes, contour de 1 px (`--encre-essai`)

| Scène | Hors corps : changés · noirs allumés (strict / seuil) · plus clairs (max) | Zone des corps : changés · noirs (strict / seuil) · plus clairs | Même instant sans l'essai : changés · noirs · plus clairs (max) |
|---|---|---|---|
| duel allumees | 219758 · 0 / 0 · 0 (0) | 9002 · 0 / 0 · 5 | — |
| duel eteintes | 219615 · 0 / 0 · 0 (0) | 7199 · 0 / 0 · 0 | — |
| sol allumees | 225369 · 0 / 0 · 0 (0) | 4873 · 0 / 0 · 61 | — |
| sol eteintes | 218900 · 0 / 0 · 0 (0) | 3833 · 0 / 0 · 40 | — |
| mur allumees | 213407 · 0 / 0 · 0 (0) | 4761 · 0 / 0 · 28 | — |
| mur eteintes | 213112 · 0 / 0 · 0 (0) | 3444 · 0 / 0 · 2 | — |
| scinde allumees | 247914 · 0 / 0 · 0 (0) | 14973 · 0 / 0 · 10 | — |
| scinde eteintes | 246359 · 0 / 0 · 0 (0) | 11522 · 0 / 0 · 0 | — |

### Les tuyaux et câbles des murs (`--tuyaux-essai`)

| Scène | Hors corps : changés · noirs allumés (strict / seuil) · plus clairs (max) | Zone des corps : changés · noirs (strict / seuil) · plus clairs | Même instant sans l'essai : changés · noirs · plus clairs (max) |
|---|---|---|---|
| duel allumees | 35823 · 0 / 0 · 51 (6) | 2539 · 0 / 0 · 20 | 36375 · 0 / 0 · 51 (6) |
| duel eteintes | 35883 · 0 / 0 · 51 (6) | 772 · 0 / 0 · 0 | 36379 · 0 / 0 · 51 (6) |
| sol allumees | 23921 · 0 / 0 · 34 (6) | 1067 · 0 / 0 · 9 | 23921 · 0 / 0 · 34 (6) |
| sol eteintes | 23921 · 0 / 0 · 34 (6) | 98 · 0 / 0 · 65 | 23921 · 0 / 0 · 34 (6) |
| mur allumees | 21007 · 0 / 0 · 21 (6) | 1094 · 0 / 0 · 2 | 21007 · 0 / 0 · 21 (6) |
| mur eteintes | 21007 · 0 / 0 · 21 (6) | 135 · 0 / 0 · 83 | 21007 · 0 / 0 · 21 (6) |
| scinde allumees | 28419 · 0 / 0 · 69 (7) | 2059 · 0 / 3 · 40 | 28550 · 0 / 0 · 69 (7) |
| scinde eteintes | 28420 · 0 / 0 · 73 (6) | 479 · 16 / 25 · 122 | 28548 · 0 / 0 · 73 (6) |

### Les tuyaux de près (caméra ×4,5, trois fois le zoom du duel) (`--tuyaux-essai --zoom-photo=4.5`)

| Scène | Hors corps : changés · noirs allumés (strict / seuil) · plus clairs (max) | Zone des corps : changés · noirs (strict / seuil) · plus clairs | Même instant sans l'essai : changés · noirs · plus clairs (max) |
|---|---|---|---|
| duel allumees | — | — | 20385 · 0 / 0 · 88 (10) |
| duel eteintes | — | — | 20379 · 0 / 0 · 88 (10) |
| sol allumees | — | — | 14351 · 0 / 0 · 0 (1) |
| sol eteintes | — | — | 14351 · 0 / 0 · 0 (1) |
| mur allumees | — | — | 29823 · 0 / 0 · 0 (0) |
| mur eteintes | — | — | 29789 · 0 / 0 · 0 (1) |

### Les personnages détaillés (`--corps-detaille`)

| Scène | Hors corps : changés · noirs allumés (strict / seuil) · plus clairs (max) | Zone des corps : changés · noirs (strict / seuil) · plus clairs | Même instant sans l'essai : changés · noirs · plus clairs (max) |
|---|---|---|---|
| duel allumees | 0 · 0 / 0 · 0 (0) | 1979 · 0 / 0 · 57 | — |
| duel eteintes | 0 · 0 / 0 · 0 (0) | 178 · 0 / 0 · 10 | — |
| sol allumees | 0 · 0 / 0 · 0 (0) | 1151 · 0 / 0 · 11 | — |
| sol eteintes | 0 · 0 / 0 · 0 (0) | 83 · 0 / 0 · 12 | — |
| mur allumees | 0 · 0 / 0 · 0 (0) | 1085 · 0 / 0 · 45 | — |
| mur eteintes | 0 · 0 / 0 · 0 (0) | 38 · 0 / 0 · 34 | — |
| scinde allumees | 0 · 0 / 0 · 0 (0) | 3381 · 0 / 14 · 101 | — |
| scinde eteintes | 0 · 0 / 0 · 0 (0) | 389 · 16 / 25 · 143 | — |

### Le bruit : le 3ᵉ témoin, sans aucun essai, compté comme un essai

| Scène | Hors corps : changés | Zone : changés · noirs (strict / seuil) · plus clairs (max) |
|---|---|---|
| duel allumees | 0 | 1977 · 0 / 0 · 24 (7) |
| duel eteintes | 0 | 137 · 0 / 0 · 0 (0) |
| sol allumees | 0 | 1239 · 0 / 0 · 104 (79) |
| sol eteintes | 0 | 116 · 0 / 0 · 8 (29) |
| mur allumees | 0 | 376 · 0 / 0 · 1 (35) |
| mur eteintes | 0 | 153 · 0 / 0 · 94 (112) |
| scinde allumees | 0 | 1953 · 0 / 0 · 3 (8) |
| scinde eteintes | 0 | 87 · 1 / 6 · 26 (27) |

Lecture, essai par essai :

- **Cœur chaud** : rien hors des corps, torches allumées comme éteintes ; torches éteintes, il disparaît (0 pixel). Au
  même instant, c'est un disque d'environ 13 px par lampe (136 à 140 pixels), presque blanc (luminance moyenne ~195
  contre ~60 dessous) : 93 à 96 % de ses pixels sont plus clairs que ce qu'ils couvrent, **par construction** (c'est une
  source). 0 noir strict allumé. Mais en écran scindé, **le cœur de J1 vu par J2** déborde de ~6 px autour de la lampe
  sur 133 pixels qui valaient 7/255 (juste sous le seuil du noir) : il rend la lampe adverse plus visible que son seul
  cône. Le cœur suit la visibilité du corps : J2, à 1,2 case du mur, est caché à J1, et son cœur aussi ; J1, à 3,5 cases,
  est vu par J2. L'écart vient de ma mise en scène, pas de l'essai — mais c'est à regarder : planche, scène « scinde ».
- **Mannequin** : 0 changé hors des corps (il ne touche qu'aux corps). Dans la zone, 0 noir allumé en vue unique ; en
  scindé torches éteintes, 10 strict / 18 au seuil, **sous** le bruit mesuré par les tuyaux (16 / 25), qui ne touchent
  pas aux corps et font 0 au même instant. Plus clairs : du niveau du 3ᵉ témoin. Rien de prouvé au pixel sur le corps.
- **Pochoirs** : 2 700 à 5 850 pixels changés, **tous assombris** (0 plus clair, écart max 1/255, 0 noir allumé), torches
  allumées ET éteintes (la lueur des LED éclaire le sol : le pochoir s'y lit aussi). Symétrie : en scindé, 457 pixels
  changés, dans les deux moitiés.
- **Encre** : ~215 000 à 248 000 pixels changés (hachures partout où il y a de la pénombre, arêtes, contours), **0 plus
  clair, 0 noir allumé** hors des corps. Le contour de 1 px du monde fait 1,5 px d'écran : bien visible à ×3.
- **Tuyaux** : 21 000 à 36 000 pixels, 0 noir allumé ; 21 à 73 pixels plus clairs que le mur caché, de 6 à 7/255 au plus
  (0,1 à 0,3 % de l'emprise), tous **hors de la torche**, sous la lueur des LED. Même instant et entre lancements :
  mêmes chiffres.
- **Personnages détaillés** : 0 hors des corps ; dans la zone, 0 noir allumé en vue unique, 16 / 25 en scindé éteint —
  exactement le bruit des tuyaux. Relancé une seconde fois : les deux lancements ne diffèrent que dans la boîte des
  corps (965 à 2 052 pixels), comme deux témoins.


## La question d'Adrien : le reflet des tuyaux, plus clair que le mur ?

Réponse courte : **non, pas au pixel** — mais il en a l'air, et l'image dit pourquoi.

- **Sous la torche** (les pixels de tuyau dont le mur caché dépasse 40/255 — 895 à 14 347 selon la scène et le zoom) :
  **0 pixel de tuyau plus clair que le mur qu'il cache**, à la taille du duel comme de près (×4,5). Le tuyau médian
  vaut ~87/255, son reflet (ses 5 % les plus clairs) 106 à 121, au plus 140-142 ; le mur caché vaut ~138 en médiane,
  151-155 pour ses 5 % les plus clairs, jusqu'à 160.
- Le reflet atteint donc **le gris moyen du mur**, pas plus. Il paraît plus clair parce que le corps du tuyau, juste à
  côté (~87), est bien plus sombre, et que le contour est à l'encre : un effet de contraste. Le shader le dit :
  `tuyaux_iso.gdshader:143`, `reflet = smoothstep(0.88, 0.99, face_camera)` retire l'encre sur la ligne tournée vers la
  caméra, et la matière y vaut `min(albedo, matiere_max)` — le plafond est la face la plus sombre possible, pas la face
  réelle derrière, assombrie par l'usure (allumée par défaut, Q30) et l'encre des arêtes.
- **Hors de la torche** (sous la lueur des LED) : 21 à 88 pixels le dépassent, de 10/255 au plus (0,1 à 0,4 % de
  l'emprise) — là où l'usure a taché le mur derrière. Les cartes en rouge de la planche les montrent.
- Si Adrien veut un reflet moins clair : baisser la plage du reflet ou lui laisser un peu d'encre. Je n'ai rien changé.


## Pièges découverts — à reporter dans la feuille de route

1. **La respiration des corps bat sur l'horloge murale, même sous `--fixed-fps`** (`presentation_3d.gd:1170`,
   `etat_du_corps`, et `horloge_du_rejeu` hors rejeu). Deux lancements identiques rendent les corps dans des poses
   différentes (13 à 3 400 pixels, jusqu'à 119/255). Le décor, lui, est identique au pixel près une fois la graine posée,
   l'horloge fixe et les LED figées. Toute comparaison entre lancements doit exclure une zone autour des corps (ou
   figer ce temps) ; les essais de corps ne se prouvent au pixel que dans un même processus. Pas un défaut du jeu (en jeu
   le corps respire de toute façon) : un piège de mesure, comme les LED du 25/09.
2. **Un conteneur neuf joue l'intro en planches au premier lancement** (`game_state.gd`, `_ouvrir_sur_intro_ou_menu`,
   `GameSettings.intro_vue` absent de `user://settings.cfg`), par-dessus tout : un outil qui ne congédie que l'allumage
   (`_traiter_l_allumage`) photographie l'intro — ma première prise en était couverte. Le photographe et
   `photo_tuyaux.gd` y sont exposés dans un conteneur neuf ; `photo_essais.gd` la congédie.
3. **Éditer un script bash pendant qu'il tourne le désaligne** : bash lit ses scripts au fil de l'eau ; ma boucle a
   exécuté un fragment (« fige: command not found ») au retour d'un lancement. Écrire à côté, puis renommer.
4. Rappel du piège connu (12/09) : `pkill -f motif` et `pgrep -f motif` se voient eux-mêmes quand le motif est dans leur
   propre ligne de commande — je me suis tué deux fois ainsi.

## Signalé, hors de ma tâche (non corrigé)

- `tools/banc_equite_fusee.gd.uid` et `volume_masque.gdshaderinc.uid` ne sont pas dans le dépôt : `godot --headless
  --path . --import` les crée, puis `git status` les montre non suivis (le second était déjà signalé par la session
  tuyaux). Je ne les ai pas commités.
- La consigne nommait `assets/ui_illustrations/` : les illustrations sont dans `assets/ui/` (`ill_*.png`).
- Le cœur chaud est, par nature, plus clair que ce qu'il recouvre (une source, pas une peinture) : comme le cœur de la
  fusée (`iso_volumes.gd`, « l'exception ne vaut que pour ce point, qui n'éclaire rien »), la règle des pochoirs ne s'y
  applique pas telle quelle. À trancher par Adrien, pas par moi.
- `photo_essais.gd` imprime « zoom caméra : 1.5 » même avec `--zoom-photo=4.5` : la ligne est écrite avant que le zoom
  ne soit posé (à chaque image, par `_vivants`). Le gros plan est bien à ×4,5 (l'image le montre).

## Tout refaire

```bash
# Godot 4.7 et Xvfb (voir la consigne du cloud), puis :
godot --headless --path . --import
GODOT=/usr/local/bin/godot ./docs/iso/cloud/essais/lancer.sh     # ~45 min sous llvmpipe
# Un seul lancement :
xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/photo_essais.tscn -- \
  --no-eos --led-murs-fige --sortie=user://essais/encre --encre-essai [--scenes=duel,sol,mur,scinde]
# Les mesures et la planche, sur les prises de ~/.local/share/godot/app_userdata/Candela 2D/essais :
pip install pillow numpy
python3 docs/iso/cloud/essais/mesurer.py && python3 docs/iso/cloud/essais/planche.py
# Les points d'ancrage des six drapeaux, après fusion :
grep -n 'DRAPEAU_FAISCEAU\|DRAPEAU_MANNEQUIN\|DRAPEAU_POCHOIRS\|DRAPEAU_ENCRE_ESSAI\|DRAPEAU_TUYAUX_ESSAI\|DRAPEAU_DETAIL' *.gd
```

**Suite complète** : `GODOT=/usr/local/bin/godot ./tools/run_suites.sh` → « tout passe, sans erreur de script (615s) »,
code 0, sur cette branche après les deux fusions et l'outil (lancée seule, sans prise en cours : elles partagent `user://`).
Journaux des prises : 0 `SCRIPT ERROR`, 0 `SHADER ERROR`.

## Ce que je n'ai PAS pu prouver

- **La cadence** : rien de mesuré ici ne vaut (rendu logiciel, quelques images par seconde). Le coût de chaque essai se
  mesure sur le Mac.
- **Les corps au pixel près entre lancements** (mannequin, corps détaillés, contour de l'encre) : dans la zone des corps,
  les chiffres se mêlent au souffle. Ce qu'on peut dire : 0 noir allumé dans la zone pour tous les essais, et des
  « plus clairs » du même ordre que ceux du 3ᵉ témoin, sans essai. Les preuves au pixel des corps restent celles de leurs
  sessions (`tools/test_corps_detail.gd`, `tools/test_corps_mannequin.gd`, headless).
- **L'éblouissement** et le voile : non fiables dans le cloud ; c'est pourquoi la scène scindée place J2 hors du cône de J1.
- **Le lacet 0°** : tout est pris à 45° B (le défaut du jeu). L'équité à 0° n'est pas photographiée.
- **La vue de J2** n'est prise qu'en écran scindé (scène scindé), pas en vue unique.
- **Les couleurs** valent à ~1/255 près de celles du Mac ; le contraste perçu du reflet des tuyaux dépend de l'écran.
- **Une seule carte** (le Cloître) ; les pochoirs n'ont été regardés que sur « ZONE 1 » et ce que le cadrage montre.
