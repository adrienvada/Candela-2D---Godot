# Le rouge de la fusée contre celui de son illustration — essai `--fusee-rouge-sang` (session cloud « fusée-rouge »)

*27/09/2026, 02:26 → 04:00 environ, heure de Paris. Branche `claude/cloud-fusee-rouge`, base `origin/claude/cloud-fusee`
(85ce792). Planche : [`planche.html`](planche.html) (autonome, images en chemins relatifs).*

## Pour Adrien, en cinq lignes

1. **Non : le rouge de l'illustration ne s'obtient pas sans changer le jeu.** Ce qui le rend « sang », c'est surtout qu'il est
   **sombre**, et un sol plus sombre, c'est un jeu qui montre moins.
2. **La teinte, elle, peut bouger, à coût nul pour le jeu** : avec `--fusee-rouge-sang`, le sol passe de l'orange (4 à 12°) à
   350-5°, tout près des 353° de l'illustration. Ce que le jeu fait voir reste identique : même lecture des corps, même
   éblouissement, même luminance du sol (à 2 % près), même noir.
3. **Mais à luminance égale, le rouge devient ROSE**, pas sang : saturation 0,58 à 0,62 contre 0,65 aujourd'hui et 0,69 sur
   l'illustration. Regarde `sang/a1_5-loupe.jpg` à côté de `defaut/a1_5-loupe.jpg`.
4. **Sous la fumée pleine** (le moment de l'illustration, rouge long à 3,5 s), l'essai ne fait que la moitié du chemin :
   4,6° au lieu de 11,5°. La fumée tire le sol vers l'orange.
5. Rien n'a changé par défaut. Le drapeau est éteint, et c'est à toi de trancher sur la planche : un rouge plus rosé à
   luminance égale, ou le rouge d'aujourd'hui. Un rouge vraiment sombre changerait ce que le jeu fait voir.

## 1. D'où vient la couleur, et ce que le jeu en lit (établi AVANT de toucher au code)

**La couleur, à chaque âge.** `FuseeModele.temperature_a(age)` rend 0 en vol et au plein feu, glisse de 0 à 1 sur les 1,5 s
du raccord (`RACCORD_PLEIN_FEU_BRAISE`), puis rend 1 (braise, agonie, résidu). `fusee.gd::_appliquer_age` la traduit :
`COULEUR_DETRESSE.lerp(Charte.AMBRE, température)`, soit un rouge (0,96 ; 0,293 ; 0,334) au plein feu et l'ambre
(0,96 ; 0,69 ; 0,24) à la braise, posé sur un `PointLight2D` (`_lumiere.color`), avec l'énergie `FuseeModele.energie_a`
(3,0 au plein feu, 1,2 à la braise). **Le rouge est le canal maximal à toute température (0,96 aux deux bouts).** Les halos
de la vue iso (`iso_volumes.gd` : la lueur, la comète, le point de braise) reprennent `lumiere.color` : ils suivent.

**Le sol éclairé.** La lumière 2D **multiplie** la tuile, canal par canal, en valeurs affichées : la lightmap sous la fusée
vaut (126, 36, 27), et divisée par la lumière elle rend (1 ; 0,94 ; 0,62), le brun des tuiles (ROADMAP, ISO13, « Les 8°
vers l'orange »). Le bleu du sol perd 38 %, le vert 6 % : le vert passe devant le bleu, et le sol tourne à 5,5° dans la
lightmap, 4 à 14° à l'écran. **L'évaluation ancienne a raison sur la cause** : ce n'est ni la pâte (poids de neutralité nul
pour ce rouge) ni un réglage d'affichage. **Elle a tort sur « rien ne se corrige »** : la teinte du sol se déplace par la
couleur de la lumière, sans rien changer à ce que le jeu lit (voir 3).

**Ce que le jeu lit de cette lumière :**

| lecteur | fichier | ce qu'il lit | sensible à la teinte ? |
|---|---|---|---|
| capteur du corps **adverse** (ce qui fait apparaître l'ennemi) | `capteur_adverse.gdshader` | `max(R, G, B) × énergie`, ×4 puis plafond ; le disque blanc sort **gris**, puis `pate_luminance(fiche × gris)` | **non** : seul le canal maximal compte |
| capteur de **son propre** corps | `capteur_local.gdshader` → `corps_iso.gdshader` | la couleur canal par canal, puis `pate_luminance` (Rec. 709) | oui, par la **luminance** |
| le seuil commun des dix classes (Q32, 0,10) | `corps_iso.gdshader` (`niveau`), `voxel_catalogue.gd` (`GRIS_EGAUX` 0,65) | la **luminance** de `fiche × capteur` ; le banc d'équité le calcule en luminance × énergie × masque | par la luminance ; pour le corps adverse, le capteur est déjà gris |
| l'éblouissement | `fusee.gd::energie_relative` → `game_state._sources_eblouissantes` | l'**énergie** seule | **non** |
| le point noir de la lightmap (8/255) | `iso_lightmap.gdshaderinc` (`seuil_noir_2d`) | la **luminance** | par la luminance |

Donc une couleur qui garde **le canal rouge** (0,96), **la luminance** et **l'énergie** laisse toutes ces lectures en place.

## 2. La règle, fixée AVANT les chiffres (commit `4a1bd03`, poussé avant tout code)

Une couleur n'est une solution que si, à chaque âge et à chaque distance : (a) capteurs de corps et seuil de Q32 à 1 % près ;
(b) même éblouissement (énergie inchangée) ; (c) luminance du sol éclairé à ±3 % à l'image ; (d) noir absolu inchangé
(torches éteintes, prises A, B, A') ; (e) la lumière reste rouge (FU2.1), `Protocol.VERSION` reste 18.

## 3. L'essai

**Le rouge sang : (0,96 ; 0,272 ; 0,54)**, dans `fusee_couleur.gd`, derrière `--fusee-rouge-sang`, éteint par défaut.
Calcul : deux équations, sur le brun des tuiles. (1) La teinte du sol à 353,3°, celle de l'illustration : il faut
0,62·B − 0,94·V = (7/60)·(0,96 − 0,94·V). (2) La luminance de la couleur inchangée : 0,7152·V + 0,0722·B = constante. Le
rouge ne bouge pas. Solution : V = 0,272, B = 0,540. La lumière elle-même est à 337°, saturation 0,72 : un rouge framboise,
jamais blanc. **La braise garde l'ambre** : l'illustration montre le plein feu, et la braise orange est voulue (FU2.1).
Le raccord glisse donc du rouge sang vers l'ambre, avec le rouge à 0,96 tout du long.

**Ce qui change dans le code** : `fusee.gd` appelle `FuseeCouleur.couleur_a(température, COULEUR_DETRESSE)` aux trois
endroits où il posait la détresse (lumière au départ, cœur 2D au départ, `_appliquer_age`). Sans le drapeau, c'est la
même expression, `detresse.lerp(AMBRE, t)`, et la garde la compare **au bit** à chaque pas de 1/120 s, défaut et rouge
long. `fusee_couleur.gd` ne dépend que de la charte, parce que `fusee.gd` nomme des autoloads et ne compile pas sous
`--script`.

**Protocol.VERSION : 18, inchangé, et vérifié.** La couleur n'entre dans aucun RPC ni dans aucun calcul de la simulation.
Elle se lit localement, au chargement, comme `--fusee-rouge-long`. Mais contrairement à celui-ci, elle ne touche pas
l'horloge : deux pairs dont un seul porte le drapeau jouent la même partie, avec deux couleurs à l'écran.

## 4. Les preuves

### 4a. La garde headless — `tools/test_fusee_rouge_sang.gd` (ajoutée à `run_suites.sh`) : verte
- éteint : la couleur d'avant **au bit**, à chaque âge, défaut et rouge long (0 écart) ;
- allumé : énergie identique à chaque âge (0 écart) ; **capteur adverse : 0,000 %** (le canal max ne bouge pas) ;
  **capteur local et seuil de Q32 : 0,033 %** au pire ; durées lisibles au seuil 0,10 **égales** à 50, 100, 125, 150 et
  200 px (15,908 / 15,908 / 15,908 / 14,700 / 0 s), défaut et rouge long ;
- sol calculé sur le brun des tuiles : 5,4° → **353,3°**, luminance **−1,18 %** ;
- rouge : canal maximal à toute température, 336,6°, saturation 0,72 ; la pâte le compte coloré (poids de neutralité 0,
  comme la détresse) ; `Protocol.VERSION` 18.

### 4b. La planche par âges (plan `loupe-fusee-ages`, quatre passages)
Scène de la session « fusée » : Cloître, fusée posée dans le noir à 377 px de J1, vue de J1, lacet 45°, zoom ×1,5,
1920×1080. **Le défaut reproduit au dixième les chiffres de la session « fusée »** (3,9° / 12,4° / 14,9° … 25,3°) : la
scène est la même. Sol : l'anneau de 24 à 64 px autour de la fusée, vu de J1 puis torches éteintes (la fusée seule).

| âge | défaut | **rouge sang** | rouge long | **long + sang** | écart de luminance sang / réf. (J1 ; éteintes) |
|---|---|---|---|---|---|
| 0,5 | 3,9° · 0,65 · L 42,7 | **350,4° · 0,62** · L 41,8 | 3,9° · 0,65 | **350,4° · 0,62** | −2,11 % ; −2,10 % |
| 1,5 | 12,4° · 0,65 · L 105,0 | **4,5° · 0,58** · L 104,5 | 12,4° · 0,65 | **4,5° · 0,58** | −0,48 % ; −0,51 % |
| 2,5 | 14,9° · 0,70 (braise) | 11,0° · 0,65 | 8,1° · 0,68 | **0,0° · 0,61** | −0,60 % ; long : −0,98 % |
| 3,0 | 19,4° · 0,71 | 17,9° · 0,69 | 7,8° · 0,68 | **359,6° · 0,61** | −0,33 % ; long : −1,18 % |
| **3,5** | 24,5° · 0,71 | 24,5° (braise, même couleur) | **11,5° · 0,67 · L 114,1** | **4,6° · 0,60 · L 113,5** | 0 ; long : −0,53 % |
| 4,0 | 24,7° | 24,7° | 13,7° · 0,66 | **6,9° · 0,60** | 0 ; long : −1,00 % |
| 5,0 | 24,6° | 24,6° | 19,3° · 0,72 | 17,8° · 0,70 | 0 ; long : −0,34 % |
| 8,0 | 25,3° | 25,3° | 25,3° | 25,3° | 0 ; 0 |

Format : teinte · saturation · luminance (0-255, Rec. 709), vue de J1. **Illustration** (sol, x 240-560, y 480-560) :
**353,3° · 0,69 · L 67,9.**

**Lecture.**
- **La teinte est gagnée là où la fumée est mince** : 350° à 0,5 s, contre 353° sur l'illustration. **Sous la fumée, la
  moitié seulement** : 4,5° à 1,5 s, 4,6° dans la fumée pleine du rouge long à 3,5 s (−7° à −8° contre le défaut, au lieu
  des −17° de la lightmap). La fumée a sa propre couleur éclairée, et elle ramène le sol vers l'orange. Je n'y ai pas touché :
  la ROADMAP tranche « pas d'essai sur la couleur de la fumée ».
- **La saturation baisse** de 0,65 à 0,58-0,62, donc le sol s'éloigne de l'illustration (0,69) de ce côté. C'est
  l'arithmétique de la règle. À rouge et luminance fixés, faire passer le bleu devant le vert rapproche le plus petit canal
  du plus grand. **Le résultat se voit rose** (planche, 0,5 et 1,5 s).
- **La profondeur est hors d'atteinte sous la règle.** L'illustration a un sol à L 68, le jeu au plein feu sous fumée
  L 105-114. Le « sang » de l'illustration, c'est d'abord cette obscurité. L'imiter, c'est assombrir de 35 à 40 % le sol
  qu'éclaire la fusée, donc changer ce qu'elle fait voir. La règle (c) l'interdit. Ça reste une décision de jeu, pas de
  couleur.
- **La luminance du sol tient** : écart le plus grand −2,11 % (0,5 s), tous les autres sous 1,2 %. **La règle (c) passe.**

### 4c. Le noir absolu (torches éteintes, prises A = fumée coupée, B = fumée rétablie, A' = recoupée)
- **Noir croisé** : dans chaque prise, les pixels noirs (0,0,0) chez la référence et allumés chez la variante, à la même
  image de jeu. Au plein feu, de 0 à 37 pixels par prise (au plus 27/255) sur ~0,9 à 1,8 million de pixels noirs.
- **Le témoin nul** : à 5 s et 8 s, les deux couleurs sont **les mêmes** (température 1, l'ambre). Or deux passages y
  donnent **jusqu'à 86 pixels « allumés »** (au plus 47/255, `longsang` contre `long` à 8 s), et 57 à 285 pixels différents
  loin de toute lumière de la fusée. **C'est le bruit du rendu entre deux passages**, pas la couleur. Le rouge sang reste
  dans ce bruit (au plein feu, 37 au plus contre 86 au témoin). Et il **éteint** plus de pixels qu'il n'en allume (prise B :
  −72 à −265). **La règle (d) passe à la précision du banc.** Le témoin nul le montre : la précision n'est pas le pixel près.
- **Le noir sali par la fumée** (défaut D2 de la session « fusée », masque de la fumée éteint) : identique à ±0,5 % dans les
  deux couleurs (par exemple à 2,5 s, 45 306 pixels par défaut et 45 132 en rouge sang ; au rouge long à 3,0 s, 45 689 et
  45 429). L'essai n'y ajoute rien et n'en retire rien.

### 4d. La suite complète
`GODOT=/usr/local/bin/godot ./tools/run_suites.sh` sur `3d691c0` (x86, Godot 4.7 officiel) : **« tout passe, sans erreur de script (610 s) », code 0**, 138 suites OK dont `test_fusee_rouge_sang`. Le code du jeu n'a pas changé depuis ce commit : seuls le rapport et les images ont suivi.

## 5. Verdict sur la règle

**La couleur (0,96 ; 0,272 ; 0,54) tient la règle entière** : (a) 0 % et 0,033 %, (b) énergie identique, (c) −2,11 % au
pire, (d) dans le bruit du témoin, (e) rouge, VERSION 18. **Elle est donc une solution au sens de la règle.** Mais elle
ne donne **pas** le rouge de l'illustration. Elle donne sa teinte (sans fumée), et le prix est une saturation plus basse,
qui se voit rose. Ce qui manque, la profondeur, la règle l'exclut. D'où la réponse en tête : **non, pas sans changer le
jeu** ; oui pour la teinte seule, au prix d'un rouge plus rosé.

## Décisions et leur pourquoi
- **Garder le rouge et la luminance exacts, pas seulement « à 1 % »** : le capteur adverse est l'équité, et il ne lit que le
  canal max. En le gardant exact, la question « l'ennemi apparaît-il plus tôt ? » ne se pose pas. La luminance suit la
  même logique pour son propre corps et pour le seuil de Q32.
- **Viser la teinte de la lightmap (353,3°), pas celle de l'écran sous fumée** : la seconde demanderait une lumière encore
  plus magenta (≈ 320°). Elle dépasserait l'illustration là où la fumée est mince, et elle serait encore plus rose. Une
  seule cible, vérifiable par le calcul.
- **La braise n'est pas touchée** : l'illustration montre le plein feu, et l'orange de la braise est voulu (FU2.1).
  L'ajuster n'aurait rapproché aucune image de la planche.
- **Un fichier à part (`fusee_couleur.gd`)** : la garde doit appeler la vraie fonction, et `fusee.gd` ne compile pas sous
  `--script`. `COULEUR_DETRESSE` reste où `test_iso_beaute.gd` la lit, dans le texte de `fusee.gd`.
- **Le point de braise suit la couleur de la lumière** (`iso_volumes.gd`, Q34) : je n'y ai pas touché (hors sujet). Au
  plein feu il est blanc (230, 230, 229) dans les deux couleurs. Au raccord (3,0 s), il passe de (230, 216, 152) à
  (229, 219, 165).
- **Le témoin nul (5 et 8 s) plutôt qu'un seuil décrété** pour le noir : deux passages ne sont pas identiques au pixel,
  même sous `--fixed-fps 60`. Le témoin dit ce que vaut le zéro.

## Pièges découverts, à reporter dans la feuille de route
1. **Premier lancement dans un conteneur neuf : l'intro en bandes dessinées joue et le photographe la photographie.**
   `GameSettings.intro_vue` n'est posé qu'au premier lancement (`game_state._ouvrir_sur_intro_ou_menu`). Quatre passages
   lancés ensemble sur un `user://` neuf ont TOUS pris l'intro (« UNE TOUCHE POUR PASSER ») à la place du jeu, et
   `run_photos.sh` est sorti en 0. Les chiffres étaient faux mais plausibles : un sol à 33°. Parade : un premier lancement
   seul, ou `intro_vue=true` dans `user://settings.cfg` avant la planche. Signalé : le photographe devrait fermer l'intro
   ou la refuser (`tools/photographe.gd`). Non corrigé, hors tâche.
2. **Deux passages du photographe ne sont pas identiques au pixel**, même horloge fixe et même âge : jusqu'à 86 pixels
   noirs d'un côté et allumés de l'autre, 285 pixels différents loin de la lumière. Toute comparaison de noir entre deux
   passages a besoin d'un témoin nul (un âge où les deux variantes sont identiques).
3. **Sous la fumée, la teinte du sol ne suit la lumière qu'à moitié** : −17° dans la lightmap, −7 à −8° à l'écran sous
   fumée pleine. Toute retouche de la couleur de la fusée se juge à l'image, sous fumée, et pas sur la lightmap.
4. **À rouge et luminance fixés, déplacer la teinte d'un rouge sur le brun des tuiles le désature** : c'est obligatoire,
   pas un défaut de l'essai.

## Refaire
```bash
git checkout claude/cloud-fusee-rouge
godot --headless --path . --import
godot --headless --path . --script res://tools/test_fusee_rouge_sang.gd      # la garde
# ⚠️ sur un user:// neuf, l'intro serait photographiée à la place du jeu : poser intro_vue=true dans la section
# [display] de user://settings.cfg (ou faire UN passage seul d'abord, et le jeter).
for v in defaut sang long longsang; do
  case $v in defaut) extra="";; sang) extra="--fusee-rouge-sang";; long) extra="--fusee-rouge-long";;
    longsang) extra="--fusee-rouge-long --fusee-rouge-sang";; esac
  xvfb-run -a -s "-screen 0 1920x1080x24" env GODOT=/usr/local/bin/godot GODOT_ARGS="--fixed-fps 60" \
    ./tools/run_photos.sh --plan=loupe-fusee-ages --taille=1920x1080 --zoom=1.5 --lacet=45 \
    --sortie=user://rouge-$v $extra > /tmp/rouge-$v.log 2>&1 &
done; wait
U="$HOME/.local/share/godot/app_userdata/Candela 2D"   # Mac : ~/Library/Application Support/Godot/app_userdata/Candela 2D
pip install pillow numpy
python3 docs/iso/cloud/fusee-rouge/mesurer.py \
  --variante "defaut=/tmp/rouge-defaut.log,$U/rouge-defaut" --variante "sang=/tmp/rouge-sang.log,$U/rouge-sang" \
  --variante "long=/tmp/rouge-long.log,$U/rouge-long" --variante "longsang=/tmp/rouge-longsang.log,$U/rouge-longsang" \
  --sortie docs/iso/cloud/fusee-rouge
```
Au Mac, pour juger en jouant : `godot --path . -- --fusee-rouge-sang` (et `--fusee-rouge-long` en plus pour l'instant de
l'illustration).

Fichiers : `<variante>/aX_Y-loupe.jpg` (loupe ×3 vue de J1), `aX_Y-loupe-eteint.jpg` (torches éteintes, la fusée seule),
`aX_Y-plein.jpg` (fenêtre entière) ; `illustration.jpg` ; `mesures.json` (tout, y compris le noir croisé prise par prise) ;
`mesurer.py` (reprend `docs/iso/cloud/fusee/mesurer.py`).

## Ce que je n'ai PAS pu prouver
- **L'éblouissement à l'image** : le cloud ne le rend pas fidèlement. Il est prouvé **par le code** (il ne lit que
  l'énergie, et l'énergie est identique, garde à 0 écart), pas vu.
- **La cadence** : rien mesuré (interdit ici). L'essai ne change qu'une couleur, sans coût attendu, mais ce n'est pas
  mesuré.
- **Les corps sous la fusée, à l'image** : la scène n'a aucun corps dans la lumière de la fusée. Leur lecture est prouvée
  par le calcul (capteur adverse inchangé exactement, local à 0,033 %), pas photographiée.
- **Les murs** : une lumière plus bleue éclaire un peu plus une surface bleutée (poids du bleu 0,07 dans la luminance) ;
  non mesuré. Les murs du Cloître sont bruns, l'effet y va dans le même sens que le sol, à moins de ±3 %. Non prouvé.
- **Les couleurs du Mac** : llvmpipe, à ~1/255 près.
- **La scène de l'illustration** (fusée tenue, murs éclairés, fumée rouge) : non reproduite. On compare des sols, pas des
  compositions.
- **Une variante « sous fumée » (≈ 320°)** : pas essayée à l'image. Estimée plus rose encore (voir « Décisions »).

## Hors tâche, signalé
- `tools/loupe_fusee_ages.gd.uid` manquait à la base (généré par l'import) : committé ici.
- Le photographe et l'intro du premier lancement : piège 1 ci-dessus.
