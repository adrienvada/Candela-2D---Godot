# Une lampe plus claire et plus pâle — essai `--lampe-claire` (session cloud « lampe-claire », Q40)

*28/09/2026, 02:05 → 04:10 (heure de Paris). Branche `claude/cloud-lampe-claire`, base `origin/integration-iso14` (a30a407).
Planche : [`planche.html`](planche.html) (autonome, images en chemins relatifs). Chiffres : [`mesures.json`](mesures.json).*

## Pour Adrien, en cinq lignes

1. **Oui, la lampe peut éclairer en crème comme sur les dessins, sans rien changer au jeu.** Avec l'essai, le cœur du cône
   passe de ~125 (ocre) à ~205-210 (crème pâle), sur les six cartes.
2. Ce que le jeu « sait » de la lumière ne bouge pas : même portée, même forme du cône, même moment où un adversaire
   apparaît, même éblouissement, et le noir reste noir (aucun pixel noir allumé, sur 32 prises).
3. **Une chose change pour les yeux du joueur** : un adversaire debout dans ton cône se découpe maintenant en silhouette
   SOMBRE sur un sol clair (comme sur les illustrations), au lieu de se fondre dans un sol ocre. Il n'est ni plus ni moins
   éclairé qu'avant ; c'est le sol autour de lui qui change.
4. Ouvre `planche.html` : chaque carte, aujourd'hui et avec l'essai, au même instant, en taille réelle et en loupe ×3, à
   côté des dix illustrations qui montrent une lampe.
5. Rien n'a changé par défaut ; le drapeau est éteint. **Q40 est à toi** : garder l'ocre, ou passer à la crème (et, si oui,
   plus ou moins pâle : un seul réglage, la « pâleur »).

## 1. Qui lit la lumière de la torche (établi dans le code AVANT de coder)

La torche est une `PointLight2D` (`player.gd`, `flashlight`) de couleur `Charte.HALOGENE` (0,98 ; 0,91 ; 0,80), d'énergie
2,5 (souffle compris), de texture et d'échelle tirées de l'arme (`weapon.get_torch_texture()`, `echelle_torche()`, portée
`portee_torche()` × `facteur_portee` d'ISO8). **La lumière est déjà crème.** L'ocre du sol vient de ce qu'elle éclaire :
le damier brun des tuiles de la 2D, puis la chaleur de la pâte (`pate_temperature_graduee`, teinte braise au bord du bain)
que le sol iso (`sol_iso.gdshader`) applique à la lightmap.

| lecteur | fichier | ce qu'il lit | touché par l'essai ? |
|---|---|---|---|
| capteur du corps **adverse** (quand un ennemi apparaît) | `capteur_corps.gd`, `capteur_adverse.gdshader` | sa **propre sous-vue 2D** (256×256, un disque blanc sous le corps, masque de lumière du sprite) : `max(R,G,B) × énergie × 4`, plafonné | **non** : autre sous-vue, autre shader ; la 3D n'y entre pas. Mesuré : identique au bit (32 scènes) |
| capteur de **son propre** corps | `capteur_local.gdshader` | idem, `LIGHT_COLOR × COLOR` | **non** (même mesure) |
| le seuil commun des dix classes (Q32, 0,10) | `corps_iso.gdshader` (`niveau`), `voxel_catalogue.gd` (`GRIS_EGAUX`) | la luminance de `fiche × capteur` | **non** : ni la fiche ni le capteur ne changent ; le corps à l'écran est identique (voir 4c) |
| éblouissement | `game_state._sources_eblouissantes`, `eblouissement.gd`, `player.integrer_eblouissement` | torche allumée, portée de l'arme, direction ; aucune couleur, aucun pixel | **non** : `dazzle_amount` identique au même instant ; aucun script de jeu ne connaît l'essai (garde) |
| point noir de la lightmap (8/255) | `iso_lightmap.gdshaderinc`, `lire_lightmap` (`seuil_noir_2d`) | la lightmap LUE | **non** : en amont de la courbe |
| point noir de la sortie 3D (`POINT_NOIR_ECRIT`, 8/255) | `volume_masque.gdshaderinc` (la fumée se tait sur le noir) | ce que le sol et les murs ÉCRIVENT, recalculé : « noir ou pas » | **aucune réponse ne change** : la courbe est l'identité sous 20/255, et le point noir écrit × sa hausse maximale vaut 11/255 (garde) |
| rétrodiffusion | `player.gd` (`body_light`, HALOGENE), `lumieres_iso.gd` en lumière 3D | une `Light2D` de plus dans la lightmap | **non** comme lumière ; son reflet au sol, s'il passe le genou, est relevé comme le reste (c'est de la lumière de lampe) |
| son | `AudioManager.set_player_torch` | allumée / éteinte | **non** |

**Donc** : le seul endroit où agir sans toucher à aucune de ces lectures est **en aval de la lightmap, à la sortie des
matériaux qui dessinent le sol et les murs de la vue iso**. Ni la couleur de la lumière (elle entre dans les capteurs par
`max(R,G,B)` et `LIGHT_COLOR`), ni son énergie (capteurs, éblouissement de la fusée, portée visible), ni la matière 2D des
tuiles (elle est dans la lightmap que lisent les masques).

## 2. L'essai — où, quoi, pourquoi

**Où.** `lampe_claire.gdshaderinc`, appelé en **dernière ligne** avant `ALBEDO` dans les quatre matériaux :
`sol_iso.gdshader:170`, `mur_iso.gdshader:284` (le jeu par défaut), `sol_iso_eclaire.gdshader:346` et
`mur_iso_eclaire.gdshader:369` (la lumière 3D, éteinte par défaut, branche d'identité — la garde d'identité de
`tools/test_banc.gd` exige que chaque ligne du fragment 2D y soit). `lampe_claire.gd` pose les réglages ;
`presentation_3d.gd` lit le drapeau (`var lampe_claire := LampeClaire.demandee()`) et les repose après chaque
`IsoMateriaux.accorder_sol/mur` (construction et bascule de la lumière 3D) ; `poser_lampe_claire(bool)` sert au banc.

**Quoi.** Sur la luminance ÉCRITE x (≈ l'écran, hors du pied de la sortie 3D) :
- poids `w = smoothstep(0,08 ; 0,40 ; x) × neutralité` — l'identité sous 20/255, plein effet au-dessus de 102/255 ;
- la neutralité de la lumière REÇUE (`1 − (max − min)/max` de la lightmap au point, seuils 0,36 → 0,50) : l'halogène
  (0,82) passe, la fusée (0,21), la LED ambre (0,25) et la détresse (0,31) gardent leur couleur et leur clarté ;
- une épaule `h = max(x, 0,96 × (1 − (1 − x)³))` : 126 → 213, 200 → 243, plafond 245 ;
- la couleur : celle d'avant portée à la nouvelle luminance, mêlée à 0,8 × w de la **crème de la lampe elle-même**
  (`HALOGENE`) à la même luminance — « plus pâle », sans inventer une teinte.

Garanties (gardées) : éteint ou sous le genou, la couleur est rendue telle quelle, au bit ; 0 → 0 ; monotone ; jamais plus
sombre ; symétrique (la courbe ne lit que la lumière du point, jamais le joueur ni la vue).

**Pourquoi pas ailleurs.** Relever l'énergie de la torche aurait allongé la portée visible et changé les capteurs.
Changer sa couleur aurait changé le capteur local et la luminance lue par Q32. Éclaircir les tuiles 2D aurait changé
la lightmap, donc les masques. Une passe sur l'image entière aurait touché les corps, le HUD et les halos.

**Local, jamais en réseau.** L'essai n'entre dans aucun RPC ni calcul de simulation : `Protocol.VERSION` reste 18.

**Deux faux départs, pour Gadgets.** (1) La première courbe travaillait sur la valeur « affichée » de la pâte
(`pate_vers_affiche`, linéarisée) : le cœur du cône y vaut ~0,21, au pied du genou, et l'essai ne montait qu'à 163. Passée
sur la valeur écrite, elle atteint 205-212. (2) La pâleur à 0,6 laissait une saturation de 0,26-0,30 dans le cœur ; à 0,8,
0,20-0,23, la crème pâle des illustrations les plus claires (voir 4a).

## 3. La garde headless — `tools/test_lampe_claire.gd` (30 vérifications, ajoutée à `run_suites.sh`)

- **Éteinte par défaut, au bit** : sans le drapeau, la force posée vaut 0 ; le shader la teste EN TÊTE et rend `c` avant
  tout calcul ; sous le genou (poids nul), `c` rendu tel quel ; au sol, aucune lecture de lightmap de plus quand c'est éteint.
- **À la sortie, et seulement là** : les quatre shaders l'appellent juste avant `ALBEDO` (rien entre les deux) ; aucun
  autre fichier (capteurs, corps, scripts de jeu) ne la connaît ; la présentation la repose après chaque accord.
- **La courbe** (copie GDScript, expressions vérifiées dans le shader) : identité sous le genou à toute neutralité,
  monotone, jamais plus sombre, force 0 ⇒ identité, 0 → 0, 126/255 → 213/255 ; fusée, LED ambre, détresse intactes ;
  l'halogène pleinement dedans.
- **Le noir** : 8/255 × 1,4 (la hausse maximale que le masque de la fumée prévoit) = 0,044 < genou 0,08.
- `Protocol.VERSION` = 18.

**Une garde voisine adaptée, d'une ligne.** `tools/test_iso_beaute.gd` (« toute couleur de mur naît d'une lecture de
lightmap ou du noir ») tient la liste des réécritures permises de `c` dans `mur_iso.gdshader` ; elle a rougi sur
`c = lampe_claire_sur(c, brute);` (trois vérifications, un seul drapeau interne). Cette ligne rejoint la température dans
la liste, **mot pour mot** : elle réécrit `c` à partir de `c`, 0 → 0, identité sous le genou, jamais plus sombre — ce que
garde `test_lampe_claire`. Toute autre réécriture reste refusée.

**Elle rougit** (mutations faites puis annulées, 2026-09-28) : test de force inversé (`<` au lieu de `<=`) → 1 échec ;
appel déplacé avant le contact des corps → 1 ; genou à 0,02, sous le noir → 2 ; neutralité ouverte à 0,15 → 5 (fusée, LED).

## 4. Les chiffres (Xvfb, llvmpipe, 1920×1080, lacet 45° B, zoom du duel, `--fixed-fps 60`, LED figées)

Protocole : `tools/photo_lampe.gd`. Pour chaque scène, jeu en pause, **trois prises au même instant** : aujourd'hui,
l'essai (basculé à chaud sur le sol et les murs), aujourd'hui encore. **Bruit : 0 pixel** entre les deux « aujourd'hui »,
dans les 32 scènes : tout écart est l'essai. Le sol éclairé par la torche : les pixels que la scène montre au moins 6/255 plus
clairs que torches éteintes ; le cœur : ceux qui valent au moins 60 aujourd'hui. Luminance Rec. 709 des valeurs sRGB, 0..255.

### 4a. Le cœur du cône, vue unique (duel : J1 face à un mur à 3,5 cases, J2 debout dans son cône)

| carte | aujourd'hui (médiane · p99 · teinte · sat.) | **l'essai** | 1 % le plus clair de l'image, aujourd'hui → essai |
|---|---|---|---|
| Le Cloître | 128 · 190 · 37,6° · 0,30 | **212 · 239 · 37,8° · 0,20** | (172, 144, 98) → (225, 201, 161) |
| L'Usine | 122 · 219 · 38,4° · 0,33 | **204 · 242 · 37,9° · 0,22** | (221, 183, 112) → (241, 215, 167) |
| La Croisée | 124 · 205 · 37,8° · 0,33 | **208 · 241 · 37,5° · 0,21** | (178, 150, 104) → (236, 214, 176) |
| Le Bunker | 123 · 205 · 36,8° · 0,34 | **207 · 241 · 37,1° · 0,22** | (171, 145, 103) → (236, 214, 179) |
| L'Arène circulaire | 122 · 194 · 34,4° · 0,36 | **205 · 236 · 36,2° · 0,22** | (160, 133, 95) → (230, 207, 172) |
| La carte d'essai | 121 · 216 · 37,2° · 0,35 | **202 · 242 · 37,3° · 0,23** | (171, 147, 107) → (237, 215, 180) |

Le « aujourd'hui » du Cloître retrouve **au niveau près** le chiffre de la session « écart » : (172, 144, 99). La teinte ne
bouge pas (±2°) : l'essai éclaircit et pâlit, il ne recolore pas.

**Les illustrations à lampe** (1 % le plus clair) : accueil 170 (222, 180, 131) · amical 185 (224, 197, 164) · écran
scindé 201 (244, 205, 147) · entraînement 211 (246, 222, 189) · intro allumage 235 (254, 238, 221) · intro prix 225
(254, 228, 198) · intro seuil 201 · quitter 163 · créer/rejoindre local 191 (249, 196, 108) · intro descente 183. Teinte 30
à 37°, saturation 0,13 à 0,57 (médiane ~0,35) ; seuil du 1 % le plus clair 163 à 235. **L'essai tombe dans leur
fourchette** : seuil du 1 % le plus clair 186 à 209 (141 au Cloître, dont le cône est petit dans le cadre ; aujourd'hui
118 à 138), du côté pâle de leur saturation (0,24-0,31 sur le 1 %) : la pâleur à 0,6 rapprocherait du milieu.

**Tout ce que la torche éclaire** (bord compris) : la médiane bouge peu (104 → 144 au Cloître, 27 → 29 sur l'Arène), parce
que le bord du cône est sous le genou et ne bouge pas. C'est voulu : même portée, même fondu vers le noir.

### 4b. Écran scindé (J1 et J2 de part et d'autre du mur, J2 vu depuis le côté opposé, lacet B)

| carte | cœur, vue de J1 | cœur, vue de J2 |
|---|---|---|
| Le Cloître | 120 → **191** (sat. 0,31 → 0,21) | 114 → **167** (0,35 → 0,25) |
| L'Usine | 118 → **185** | 107 → **166** |
| La Croisée | 121 → **192** | 114 → **180** |
| Le Bunker | 120 → **192** | 118 → **183** |
| L'Arène circulaire | 117 → **186** | 111 → **178** |

La carte d'essai n'a pas d'écran scindé : sa mise en scène (bordure nord, sans muret) ne place pas de J2 de l'autre côté.

**Équité.** La courbe est la même fonction pour les deux vues ; elle ne lit que la lumière du point. L'écart J1/J2 est
déjà là aujourd'hui (le cœur de J2 est un peu plus sombre : p99 131-161 contre 187-196), parce que la scène n'est pas
symétrique (J2 regarde l'autre face du mur, depuis le côté opposé) ; l'essai le suit, il ne le crée pas.

### 4c. Les dix classes au bord du cône, et les capteurs

Scène (Cloître) : J2 à 0,92 × la portée de la torche de J1 (282 px sur 307), dans l'axe, de côté ; le sol autour de lui
est presque noir (médiane 0 à 8) : c'est le bord. Les dix classes l'une après l'autre ; chaque prise refaite corps de J2
caché, pour le masque de son corps.

- **Capteurs** : lecture brute des quatre disques (maximum et somme, par vue et par corps), **identiques au bit** entre
  aujourd'hui, l'essai et aujourd'hui encore, dans les **32 scènes** (dont les dix classes : maximum 1,0, somme 1 086 à
  1 143 sur 3 835 — le bord du cône traverse le disque).
- **Le corps à l'écran** : 1 604 à 1 904 pixels de corps propre par classe ; **13 à 24 d'entre eux diffèrent, d'au plus
  1/255** (bord anticrénelé du corps sur le sol qui change derrière lui). Les 163 à 209 pixels de son ombre de contact au
  sol, eux, sont du sol : ils suivent l'essai.
- **Contraste** : le corps garde sa médiane (39-41) ; le sol du cœur passe de ~125 à ~205. Dans le cœur du cône, un
  adversaire se lit donc en silhouette plus sombre que le sol (planche, l'Usine : J2 près du mur). C'est ce que montrent
  les illustrations (personnages sombres), mais **c'est un changement de lecture pour l'œil**, que le code ne voit pas.

### 4d. L'éblouissement

`dazzle_amount` de J1 et J2, lu à chaque prise : identique entre aujourd'hui et l'essai dans toutes les scènes (0,06 / 0,64
au duel, J2 dans le cône de J1 ; 0 torches éteintes). Rien dans la simulation ne connaît l'essai (garde) : l'éblouissement
est donc le même par construction, et le même au même instant par mesure. Ce que le cloud ne dit pas : si un sol plus
clair **paraît** plus éblouissant à l'œil (voir « Ce que je n'ai pas pu prouver »).

### 4e. Le noir

- **0 pixel noir allumé** par l'essai (noir chez aujourd'hui, non noir chez l'essai), dans les **32 scènes** — duel,
  scindé, torches allumées et éteintes ; **0 pixel plus sombre**.
- Torches éteintes, l'essai change 5 500 à 17 700 pixels en vue unique (37 000 à 41 000 en écran scindé) : **le halo de
  proximité** du joueur (halogène, neutre), d'**un niveau** (Cloître : médiane 26,5 → 27,5, maximum 87 → 88). Aucun hors de
  la lumière.

## 5. Ce que je n'ai PAS pu prouver

- **La cadence.** L'essai ajoute, allumé seulement, une lecture de lightmap par fragment de sol et une dizaine d'opérations
  à la sortie ; éteint, un test en tête. Le cloud ne mesure pas la cadence : **à mesurer au Mac** (`bench_framerate`, drapeau
  posé et non posé).
- **L'éblouissement perçu** et le confort de l'œil devant un sol à ~210 dans le noir absolu : le cloud ne vaut ni pour
  l'éblouissement ni pour l'œil. À regarder au Mac, en jeu, fenêtre au premier plan.
- **La lisibilité du viseur et de la ligne de visée** : leurs traits clairs posés au sol (planche, Cloître, loupe) se
  détachent moins d'un sol crème que d'un sol ocre. Je ne l'ai pas chiffré.
- **Les autres lumières neutres.** Le flash de tir, la rétrodiffusion, le halo de proximité et les halos de gadgets
  halogènes passent aussi par la courbe quand ils éclairent le sol au-dessus du genou (c'est de la lumière de lampe). Seul
  le halo de proximité a été pris (torches éteintes, +1 niveau) ; le flash de tir, non.
- **La lumière 3D** (`--lumiere-3d`, éteinte par défaut) : la courbe y est branchée (branche d'identité) mais n'a pas été
  photographiée.
- **Le drapeau lui-même, jusqu'à l'image** : lancé avec `--lampe-claire`, la présentation démarre bien essai allumé
  (`lampe claire au départ : true`, carte d'essai, 04:00) ; mais les prises basculent l'essai à chaud
  (`poser_lampe_claire`), et deux lancements ne se comparent pas au pixel (les corps respirent sur l'horloge murale :
  53 000 pixels d'écart entre deux lancements, essai comme défaut). Le chemin drapeau → `accorder` est gardé
  textuellement, pas prouvé au pixel.
- **Le lacet 0°** : pris à 45° B seulement (la consigne), à 0° non.

## 6. Pièges à reporter dans la feuille de route

- **« La lumière de la torche est déjà crème. »** `HALOGENE` vaut (250, 232, 204) ; l'ocre vient des tuiles brunes et de la
  chaleur de la pâte. Qui veut « une lampe plus claire » en touchant la lampe change les capteurs sans rien gagner.
- **L'espace de la valeur « affichée » de la pâte n'est pas l'écran.** `pate_vers_affiche` linéarise : 126/255 à l'écran y
  vaut ~0,21. Une courbe de tons posée là travaille au pied de sa plage. Pour « ce que l'écran montre », prendre la valeur
  écrite (identique hors du pied de la sortie 3D, cf. `volume_masque.gdshaderinc`).
- **`tools/photo_essais.gd` (branche `claude/cloud-essais`) ne compile pas sur `integration-iso14`** : il précharge
  `res://tuyaux_iso.gd`, qui n'y est pas. Un outil qui en hérite échoue en « Could not resolve class » et Godot reste ouvert
  sans rien faire (fenêtre vide, aucune sortie d'erreur fatale). `tools/photo_lampe.gd` recopie donc ses deux fonctions.
  Reproduire : `godot --headless --path . --check-only --script res://tools/photo_essais.gd` sur a30a407 avec le fichier
  de `origin/claude/cloud-essais`.
- **`pgrep -f <motif>` dans une boucle d'attente se trouve lui-même** (le motif est dans sa propre ligne de commande) :
  la boucle ne finit jamais. Piège d'outillage, payé ici trois fois.

## 7. Refaire

```bash
# Godot 4.7 et Xvfb (voir la consigne), puis, à la racine :
godot --headless --path . --import
godot --headless --path . --script res://tools/test_lampe_claire.gd        # la garde
GODOT=/usr/local/bin/godot ./tools/run_suites.sh                            # la suite complète
docs/iso/cloud/lampe-claire/lancer.sh                                       # prises (~23 min), mesures, planche
# En jeu, au Mac :
godot --path . -- --lampe-claire
```

## 8. Commits

- `f39d5d5` le plan ; `456fc1b` les deux corrections du photographe pour Xvfb (reprises de `claude/cloud-photographe`) ;
- `cac94de` l'essai, la garde, l'outil de prises ;
- `54655ad` mesures, planche, images, rapport ; `00fbe59` la ligne ajoutée à `test_iso_beaute` (suite complète verte, 633 s) ;
- le dernier : le message de l'outil sur le drapeau, et ce rapport.

**Poussés** sur `claude/cloud-lampe-claire` (aucun n'attend d'accord). Aucun fichier de secret ; 1,8 Mo d'images.
