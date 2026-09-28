# L'ombre des classes, suite : l'orientation, et une compensation par classe (session cloud ombre-orientation, 2026-09-27/28)

> **Poussé le 2026-09-28 (vers 12:50, heure de Paris).** Le garde-fou de permissions avait refusé `git push` pendant
> la séance (« Out-of-Place Publication ») ; je ne l'ai pas contourné. La branche est partie après le feu vert d'Adrien,
> relayé par la session coordinatrice : « Fais en sorte que les sessions cloud 30h qui n'ont pas fini terminent ».

## Pour Adrien, en cinq lignes

1. La voie (d) — « un chiffre par classe pour égaliser la lumière » — **ne tient pas** : elle égalise une moyenne qui ne
   décide pas où un corps apparaît, et elle dérègle ce qui le décide.
2. Surprise : **aujourd'hui, les dix classes apparaissent déjà au même endroit** (au pixel près, dans cinq orientations
   sur huit). Un corps s'allume par son point le plus éclairé, et l'ombre de l'arme ne le cache pas. Les « 11 % »
   d'hier sont la largeur du liseré éclairé, pas le moment où l'on voit l'adversaire.
3. Avec un chiffre par classe, certaines classes s'allument 6 à 8 px plus tôt que d'autres ; avec un chiffre recalculé
   selon la torche, jusqu'à 16 px. Là où il n'y avait pas d'écart, (d) en crée un.
4. Le vrai écart est l'**orientation** : torche sur le côté droit du corps (celui de l'arme), trois classes (Fumiste,
   Incendiaire, Occulteur) restent **entièrement noires, même à mi-portée**. Aucun multiplicateur n'y peut rien : zéro
   fois un chiffre fait zéro.
5. Rien n'a changé dans le jeu : l'essai est un drapeau éteint, en version de test seulement, jamais en ligne.

## La réponse courte

| | Aujourd'hui | (d1) facteur constant | (d2) facteur selon la torche |
|---|---|---|---|
| Écart de lumière moyenne entre classes, b10, 8 orientations | 6 à 100 % (11 % de profil) | 21 à 100 % (26 % de profil) | 4 à 100 % (10 % de profil) |
| Écart du **maximum** de l'anneau (ce qui allume le premier pixel) | **0 %** dans 5 orientations sur 8 | 25 % partout | 9 à 42 % |
| Écart d'**apparition** entre classes (0°, prédit, validé à l'image) | **0 px** dans 5 orientations, 4 px dans une | 6 à 8 px | 2 à 16 px |
| Classes invisibles torche à leur droite | 3 (Fumiste, Incendiaire, Occulteur), même à mi-portée | les mêmes | les mêmes |
| Seuil 0,10 à recaler pour le Parasite | — | **0** (facteur 1 par construction) | **0** |
| Ce qui change à l'image | — | liseré plus clair ou plus sombre selon la classe (±12 à 18 %) ; ombre au sol intacte | idem, variable avec l'orientation |
| Coût | — | rien de mesurable (une table par forme) | une lecture de table par corps et par image ; à mesurer au Mac |

Chiffres complets : `orientation.md` (capteur, 10 classes × 8 orientations × 2 places × 2 lacets), `apparition.md`
(apparition prédite pour tous les cas, contrôlée à l'image), `planche.html` (les dix classes, aujourd'hui / d1 / d2).

## 1. L'orientation

Banc `tools/planche_orientation.gd` (héritier de `planche_ombre.gd`) : mêmes places que la base, retrouvées au dixième
de pixel (b10 à 285,0 px de J1, mi à 153,6), même torche (Parasite), J2 tourné de huit façons. `face` : il regarde la
torche ; `dos` : il lui tourne le dos ; `_g` / `_d` : la torche à sa gauche / sa droite (`profil_g` est le profil de la
base, et ses dix valeurs sont celles de la base au dix-millième). Ombre d'aujourd'hui (l'étoile).

**Place b10 (capteur moyen, 45° B ; identique au bit à 0°)** :

| Classe | face | diag face g | profil g | diag dos g | dos | diag dos d | profil d | diag face d | écart entre orientations |
|---|---|---|---|---|---|---|---|---|---|
| Parasite | 0,0657 | 0,0877 | 0,0997 | 0,1014 | 0,0865 | 0,0647 | 0,0284 | 0,0095 | 91 % |
| Illusionniste | 0,0657 | 0,0877 | 0,0997 | 0,1014 | 0,0865 | 0,0647 | 0,0284 | 0,0095 | 91 % |
| Terrassier | 0,0888 | 0,0827 | 0,0930 | 0,0886 | 0,0718 | 0,0697 | 0,0330 | 0,0293 | 68 % |
| Braconnier | 0,0574 | 0,0845 | 0,0920 | 0,0951 | 0,0977 | 0,0819 | 0,0573 | 0,0276 | 72 % |
| Occulteur | 0,0638 | 0,0858 | 0,0997 | 0,1014 | 0,0782 | 0,0546 | 0,0219 | **0** | 100 % |
| Fumiste | 0,0638 | 0,0827 | 0,0955 | 0,0913 | 0,0717 | 0,0450 | 0,0122 | **0** | 100 % |
| Incendiaire | 0,0638 | 0,0846 | 0,0997 | 0,0993 | 0,0846 | 0,0546 | 0,0122 | **0** | 100 % |
| Sentinelle | 0,0710 | 0,0846 | 0,0972 | 0,0993 | 0,0846 | 0,0653 | 0,0348 | 0,0127 | 87 % |
| Allumeur | 0,0742 | 0,0877 | 0,0997 | 0,1014 | 0,0846 | 0,0653 | 0,0348 | 0,0127 | 87 % |
| Spectre | 0,0691 | 0,0877 | 0,1039 | 0,1064 | 0,0876 | 0,0707 | 0,0352 | 0,0366 | 67 % |
| **écart entre classes** | 35 % | 6 % | 11 % | 17 % | 27 % | 45 % | 79 % | 100 % | |

À mi-distance (0,28 pour le Parasite de profil), même dessin : **Fumiste et Incendiaire lisent 0 (moyenne ET maximum)
torche à leur droite et en diagonale face-droite, l'Occulteur en diagonale face-droite** — un corps entièrement noir au
milieu du faisceau. Sans ombre propre (`sans`, 14 prises par place, trois classes, huit orientations), le capteur est le
même au dix-millième : 0,1577 à b10, 0,4939 à mi. Contrôle : la première orientation reprise après les sept autres,
identique au dix-millième pour les dix classes.

**Pourquoi** (`etoiles.svg`, en tête de la planche) : l'étoile de chaque silhouette déborde l'anneau de 15 px où le
corps lit sa lumière **du côté droit du corps**, celui où l'arme est tenue. Torche à droite, les points de l'anneau de ce
côté sont DANS l'étoile, ceux de l'autre côté DERRIÈRE elle : rien n'est éclairé. Torche à gauche, l'anneau dépasse
de l'étoile, et c'est le cas le plus clair (profil g, diag dos g). L'écart entre classes est faible là (6 à 17 %) et
énorme de l'autre côté. **L'écart d'une même classe entre orientations (67 à 100 %) est bien plus grand que l'écart
entre classes à orientation donnée.**

**La géométrie retrouve ces chiffres** (`analyse_ombre.py` de la base, repris pour les huit orientations dans
`analyse_orientation.py` ; la vraie torche, l'occluder relevé, aucun paramètre) : erreur moyenne 0,0023 à b10 (au pire
0,012), 0,0051 à mi (au pire 0,038) ; 35 et 41 prises sur 80 prédites à 0,0005 près ; le maximum à 0,0025 en moyenne.
Les écarts restants sont aux bords d'ombre (un point de l'anneau tranché d'un côté ou de l'autre) — même limite que la base.

**0° et 45°** : le capteur est un calcul du monde 2D, le lacet de la caméra n'y entre pas. Mesuré : les 160 prises
d'étoile sont **identiques au bit** entre les deux passes. Ce qui dépend du lacet est ce que la caméra voit du corps
(plus bas, l'apparition).

## 2. La voie (d)

### Le code (`--ombre-compensee=1|2`, éteint)

- `ombre_compensee.gd` (`OmbreCompensee`) : le facteur = part de l'anneau éclairée pour le Parasite / pour la classe.
  Part éclairée : 64 points de l'anneau (rayon 15), rayons de la torche pris parallèles, un point est dans l'ombre si
  l'étoile s'étend, sur sa ligne vers la torche, plus près de la torche que lui (intérieur compris) — la règle d'une
  Light2D. Une table de 64 directions par forme, remplie à la demande, interpolée.
  - **(d1)** constante par classe : les parts **moyennées sur les 64 directions**. Pourquoi pas le profil de la base
    comme orientation de référence : les facteurs de profil seul et en moyenne n'ont rien à voir (Terrassier 1,145 de
    profil, 0,983 en moyenne ; Braconnier 1,109 / 0,913 ; Spectre 0,973 / 0,888), la mesure ci-dessus montre que le
    profil n'est représentatif de rien, et un joueur tourne dans tous les sens.
  - **(d2)** : la part de la direction réelle de la torche adverse dans le repère du corps, relue à chaque image.
  - Facteurs (d1) : Parasite 1, Illusionniste 1,006, Terrassier 0,983, Braconnier 0,913, Occulteur 1,084,
    Fumiste 1,184, Incendiaire 1,089, Sentinelle 0,995, Allumeur 0,973, Spectre 0,888. Bornés à 0,25-4.
- Les deux shaders des corps voxel (`corps_iso`, `corps_iso_eclaire`) : `uniform float compensation_ombre = 1.0`, et
  la lumière lue multipliée **seulement si `!= 1.0`** — éteint, aucune opération de plus. `presentation_3d.gd` ne pose
  l'uniforme que sous le drapeau (et rend 1,0 si l'essai s'éteint en route).
- Verrous : build de débogage seulement, jamais en ligne (`NetworkManager.current_mode` autre que LOCAL), comme
  `--ombre-ronde`. `OmbreCompensee.mode_force` pour un outil, mêmes verrous.
- Ni les masques de lumière de `player.gd`, ni la simulation, ni `Protocol.VERSION` (18). L'ombre au sol et le liseré
  ne changent pas de forme : l'occluder n'est pas touché.
- **Garde** `tools/test_ombre_compensee.gd` (dans `run_suites.sh`) : la règle pure (12 cas), la géométrie (anneau
  contenu = 0, pas d'occluder = 1, rond isotrope, table = calcul direct, Parasite = 1 exactement), les shaders
  (uniforme, défaut 1,0, multiplication gardée) et les vrais corps de `main.tscn` en vue iso, dix classes : éteint,
  **rien n'est posé sur les matériaux** (le capteur lu est celui d'aujourd'hui au bit près : la texture du capteur n'est
  pas touchée, et le shader ne multiplie pas) ; allumé, le facteur de la classe ; en ligne, 1,0 ; éteint à nouveau, 1,0.
  Lancée avec `--ombre-compensee=1`, elle rougit (vérifié).
- **Piège payé en route** : les facteurs du jeu et de l'analyse Python différaient jusqu'à 0,05 pour un même polygone
  (au millième). Les points de l'anneau (pas 1/64) et les directions de la table tombaient pile sur les rayons de
  l'étoile (pas 1/32), et un sommet à 15 px pile est SUR l'anneau : un point ni éclairé ni dans l'ombre, tranché au
  hasard des arrondis (Vector2 de Godot en 32 bits). Points et directions décalés d'un demi-pas, projections en 64 bits :
  les deux calculs s'accordent à la quatrième décimale. Leçon : **un facteur tiré de 64 points bouge d'un point
  (1,6 %) sur un rien** ; (d1) et (d2) ne sont pas plus précis que ça.

### L'écart restant, orientation par orientation (place b10 ; mi est au tableau d'`orientation.md`)

La compensation n'agit que dans le shader du corps : le capteur n'est pas modifié, et « capteur mesuré × facteur » EST
ce que le corps lit sous le drapeau.

| Écart entre classes | face | diag face g | profil g | diag dos g | dos | diag dos d | profil d | diag face d |
|---|---|---|---|---|---|---|---|---|
| moyenne, aujourd'hui | 35 % | 6 % | 11 % | 17 % | 27 % | 45 % | 79 % | 100 % |
| moyenne, (d1) | 40 % | 21 % | 26 % | 21 % | 23 % | 29 % | 75 % | 100 % |
| moyenne, (d2) | 16 % | 4 % | 10 % | 5 % | 8 % | 9 % | 64 % | 100 % |
| **maximum, aujourd'hui** | **0 %** | **0 %** | **0 %** | **0 %** | **0 %** | 7 % | 20 % | 100 % |
| maximum × (d1) | 25 % | 25 % | 25 % | 25 % | 25 % | 21 % | 12 % | 100 % |
| maximum × (d2) | 31 % | 9 % | 16 % | 16 % | 30 % | 42 % | 84 % | 100 % |

- (d1) **aggrave** l'écart de la moyenne dans cinq orientations sur huit : un chiffre moyen ne corrige aucune orientation
  réelle, et les classes ne se classent pas dans le même ordre d'une orientation à l'autre.
- (d2) le réduit (4 à 16 % hors du côté droit), sans l'annuler : rayons parallèles (la vraie torche est à distance
  finie : 3 points d'anneau d'écart au pire à b10, 10 à mi), interpolation de table, et surtout **la part éclairée n'est
  pas la lumière lue** — les points face à la torche sont plus éclairés que ceux du bord.
- Aucune des deux ne fait rien là où l'anneau est tout entier dans l'ombre (100 %).

## 3. Le seuil, et où un corps apparaît

**Ce que dit le code, et ce que l'image confirme** : chaque fragment du corps lit l'anneau dans SA direction
(`lecture_au_bord = 1`). Le premier pixel qui s'allume est donc celui qui lit le **maximum** de l'anneau, pas sa
moyenne. Mesuré à l'image (banc `tools/planche_apparition.gd`, J2 reculé pixel par pixel jusqu'à son dernier pixel
allumé) à 0° : le Parasite de profil s'allume encore à 319 px (maximum de l'anneau 0,106), plus à 320 px (0,102). **Le
seuil d'apparition porte sur le maximum, et il vaut ≈ 0,10 : c'est le seuil de Q32**, retrouvé en jeu. À b10 (la
moyenne à 0,10), le maximum vaut 0,21 : le corps y est bien visible, et apparaît en réalité ~34 px plus loin.

**Recalage du seuil** : la compensation est normalisée sur le Parasite, dont le facteur vaut 1 exactement dans les deux
variantes (garde). Son apparition ne bouge pas : 319 / 319 / 321 px à 0° dans les trois modes (le bruit de la mesure est
de ±1 à 2 px, voir plus bas). **Recalage nécessaire : 0.**

**Les dix au même endroit ?** Prédit pour les 10 classes × 8 orientations × 3 modes par le balayage du capteur sans
ombre propre (tous les 2 px de b15 à noir) et la géométrie de chaque étoile : le premier pixel s'allume quand
facteur × maximum de l'anneau éclairé ≥ T, T lu à l'image sur le Parasite. Écart entre classes, en pixels de distance
(0°, T = 0,104) :

| | face | diag face g | profil g | diag dos g | dos | diag dos d | profil d | diag face d |
|---|---|---|---|---|---|---|---|---|
| aujourd'hui | **0** | **0** | **0** | **0** | **0** | 4 | Fumiste invisible ; Occulteur, Incendiaire à 306 | 3 classes invisibles |
| (d1) | 8 | 6 | 6 | 6 | 6 | 6 | idem | idem |
| (d2) | 12 | 2 | 4 | 4 | 10 | 16 | idem | idem |

Aujourd'hui toutes les classes s'allument à 318 px dans les cinq premières orientations. (d1) avance le Fumiste à 322,
l'Occulteur et l'Incendiaire à 320, recule le Spectre et le Braconnier à 314-316 : **l'ordre d'apparition devient celui
des facteurs**. (d2) disperse davantage, et fait même disparaître plus tôt certaines classes dans les diagonales
(Braconnier à 264 px en diagonale face-droite, contre 318 aujourd'hui).

**Contrôle à l'image, 0°** : Parasite de profil 319 / 319 / 321 px (prédit 318) ; Terrassier torche à droite
318 / 316 / 315 (prédit 318 / 318 / 314 ; son facteur (d2) y vaut 0,909, d'où l'avance). La prédiction tient à 1-3 px.

**45° B** : même dessin, un peu décalé. Prédit avec T lu sur le Parasite à 45° (0,068) : écart entre classes aujourd'hui
2 / 0 / 0 / 0 / 0 / 2 px dans les six premières orientations ; (d1) 4 à 6 px ; (d2) 2 à 10 px ; les mêmes classes
invisibles côté droit. L'image y est **plus bruitée** : pour trois scènes identiques (le Parasite, facteur 1 dans les
trois modes), 331 / 325 / 331 px sans graine, 325 / 326 / 322 px avec la graine reposée ; le Terrassier torche à droite
321 / 316 / 315 puis 320 / 319 / 325. **À 45°, l'image ne résout pas un écart de moins de ±3 px** ; elle ne contredit pas
la prédiction, elle ne peut pas la départager. À 0°, le bruit est de ±1 px, et c'est là que la prédiction est validée.

**Donc** : (d) ne fait pas apparaître les dix au même endroit ; elle défait l'égalité qui existe aujourd'hui. Aucun
recalage du seuil n'y remédie : le seuil est commun, l'écart vient des facteurs.

## 4. Ce que la compensation change à l'image

**Ce qui ne change pas, par construction** : l'occluder n'est pas touché, donc **l'ombre au sol en forme d'arme est
identique**, et **le liseré côté lampe garde sa forme** (les mêmes points de l'anneau sont éclairés ; seule leur valeur
lue est multipliée). Le noir absolu tient : 0 × facteur = 0, et aucun pixel ne s'allume hors de la lumière (prises
« torche du côté de l'arme » : 0 pixel allumé pour le Fumiste dans les trois modes, à b10 comme à mi).

**Ce qui change** : la clarté du corps éclairé, dans le sens du facteur. Mesuré sur la planche (10 classes, profil g,
b10 et mi, 45° B, graine reposée ; `apparition.json`, rubrique `planche`), hausse moyenne sur les pixels du corps qui
changent :

| Facteur | Classes (mode) | mi | b10 |
|---|---|---|---|
| ×0,888 | Spectre (d1) | −2,9/255 | +1,0 |
| ×0,913 | Braconnier (d1) | +0,6 | −0,8 |
| ×1,084 à 1,089 | Occulteur, Incendiaire (d1) | **+7,1 et +7,0** | +0,8 et +1,1 |
| ×1,145 à 1,184 | Terrassier (d2), Fumiste (d1, d2) | +3,8 à +6,6 | +1,4 à +2,0 |
| **×1 (témoin)** | Parasite (d1, d2), Illusionniste, Allumeur (d2) | **+0,1 à +4,3** (b10 et mi mêlés) | idem |

À mi-distance le signal dépasse le bruit (attendu : ≈ +8/255 pour ×1,18 sur un corps éclairé autour de 100/255, le
facteur passant par la courbe d'écran) ; à b10, où le corps est sombre (20 à 28/255 au plus), il est dans le bruit.
**Ce bruit est celui de la scène à 45° dans le cloud** : même avec la graine de la poussière reposée, 60 à 1 170 pixels
diffèrent entre deux prises identiques (facteur 1), jusqu'à 118/255, dans et hors du corps. Je n'en ai pas trouvé la
source (voir « ce que je n'ai pas pu prouver ») ; il interdit de donner la hausse pixel par pixel. **Plus clair que le sol
qui le porte ?** Le décompte (pixels du corps plus clairs que le sol vide au même endroit) varie autant avec le facteur 1
qu'avec la compensation : non établi.

Planche : `planche.html` — les dix étoiles, puis les dix classes (aujourd'hui / d1 / d2, b10 et mi, 1:1 et loupe ×3,
corps rendu opaque), puis « torche du côté de l'arme » (Fumiste et Spectre en diagonale face-droite).

## 5. Ce que le Mac devra mesurer (si (d2) était retenue malgré tout)

(d2) fait, par corps et par image, deux lectures de table et une inversion de transformée ; la première fois qu'une
direction est vue, un calcul de 64 × 32 tests en GDScript (une fois par forme et par direction : 64 × 2 formes au plus
par classe). (d1) ne calcule rien après la première image. Série prête, règle 278 (M0 le défaut, M1 le drapeau, ordre
M0 M1 M1 M0 M0 M1), le banc habituel, pompe sous une fusée, vue unique, fenêtre au premier plan :

```bash
G=/Applications/Godot.app/Contents/MacOS/Godot
M0="--iso --vue-unique --fusee --classe=pompe --seconds 60"
M1="$M0 --ombre-compensee=2"
for M in "$M0" "$M1" "$M1" "$M0" "$M0" "$M1"; do
  $G --path . res://tools/bench_framerate.tscn -- $M
done
```

Verdict : médiane M1 / médiane M0 ≥ 0,970, 1 % bas M1 ≥ 60, références M0 dans les 5 % entre elles. Le banc tourne en
local (le drapeau est actif) et en build de débogage (l'éditeur l'est). Je n'ai aucun chiffre de cadence : le cloud ne
mesure pas la cadence.

## Pour tout refaire

```bash
godot --version                               # 4.7.stable
godot --headless --path . --import
pip install numpy pillow
godot --headless --path . --script res://tools/test_ombre_compensee.gd     # la garde
GODOT=/usr/local/bin/godot ./tools/run_suites.sh                          # la suite (verte, 666 s)

X='xvfb-run -a -s "-screen 0 1920x1080x24"'   # sur le Mac : sans xvfb-run ni --fixed-fps
# L'orientation (≈ 50 min par passe dans le cloud)
eval $X godot --fixed-fps 60 --path . res://tools/planche_orientation.tscn -- --sortie=user://orient45 --led-murs-fige=0.5
eval $X godot --fixed-fps 60 --path . res://tools/planche_orientation.tscn -- --sortie=user://orient0 --led-murs-fige=0.5 --lacet=0
# L'apparition : balayage + recherches + planche (45°), recherches seules (0°)
eval $X godot --fixed-fps 60 --path . res://tools/planche_apparition.tscn -- --sortie=user://appar45 --led-murs-fige=0.5 \
  --cas=pistolet:profil_g,pompe:profil_d
eval $X godot --fixed-fps 60 --path . res://tools/planche_apparition.tscn -- --sortie=user://appar0 --led-murs-fige=0.5 \
  --lacet=0 --cas=pistolet:profil_g,pompe:profil_d --sans-balayage --sans-planche
# Analyses
U="$HOME/.local/share/godot/app_userdata/Candela 2D"
python3 docs/iso/cloud/ombre-orientation/analyse_orientation.py "$U/orient45" "$U/orient0" docs/iso/cloud/ombre-orientation
python3 docs/iso/cloud/ombre-orientation/schema_etoiles.py "$U/orient45" docs/iso/cloud/ombre-orientation
python3 docs/iso/cloud/ombre-orientation/analyse_apparition.py docs/iso/cloud/ombre-orientation "$U/orient45" \
  "$U/appar45" "$U/appar0"
# Essayer en jeu (build de débogage, hors ligne)
godot --path . -- --ombre-compensee=1
godot --path . -- --ombre-compensee=2
```

## Ce que je n'ai PAS pu prouver

- **Rien sur le GPU du Mac**, et aucune cadence. Le capteur est lu en 8 bits : son maximum avance par pas de 1/255,
  soit environ 2 px de distance au bord de la torche ; les apparitions sont vraies à ce pas près.
- **L'apparition à 45° B à l'image** est plus bruitée qu'à 0° (voir plus haut) ; la conclusion repose sur la prédiction
  par le capteur, validée à l'image à 0°.
- **Le miroir** (torche de J2 sur le corps de J1, vue de J2) n'est pas mesuré ; symétrique par construction.
- **Une seule ligne de tir, une seule torche** (le Parasite), sans le halo de proximité ni la rétrodiffusion : la
  compensation multiplie TOUTE la lumière lue, y compris celle qu'aucune ombre propre ne cache (sa propre torche, une
  fusée) — un défaut de principe de (d), non mesuré.
- **La killcam** : le fantôme garde le dernier facteur posé sur le corps vivant (la présentation ne recalcule pas pour les
  fantômes). Sans importance pour une mesure.
- **Le corps opaque** : les apparitions sont mesurées corps forcé opaque ; en jeu, un corps hors de la lumière s'efface
  aussi (opacité de la vue de dessus), une règle distincte de l'ombre propre, non étudiée ici.
- **Le bruit de la scène à 45° dans le cloud** : même la graine reposée, deux prises identiques diffèrent (60 à 1 170
  pixels, jusqu'à 118/255). Source non trouvée ; il borne la précision des mesures à l'image à 45° (±3 px d'apparition,
  hausse au pixel inaccessible).
- **Pourquoi l'image à 45° allume un pixel plus loin qu'à 0°** pour le même corps (≈ 331 contre 319 px, T 0,068 contre
  0,104) : non expliqué — le modelé des faces que la caméra voit (le dessus à ×1,15) en est un suspect, pas vérifié.

## Défauts vus hors de ma tâche (signalés, pas corrigés)

- **L'invisibilité torche à droite** (Fumiste, Incendiaire, Occulteur) n'est pas un défaut de (d) : c'est l'état du jeu
  aujourd'hui. `godot … res://tools/planche_orientation.tscn -- --classes=fumiste` la reproduit (capteur 0,0000 à
  `mi_etoile_profil_d` et `diag_face_d`). Elle mérite une décision à elle (voir plus bas).
- `tools/planche_ombre.gd.uid` et `tools/test_ombre_ronde.gd.uid` manquaient sur la base (créés par l'import, committés à
  part, aucun code touché).

## À reporter dans la feuille de route (par l'intégration)

- **Décision en attente d'Adrien, élargie** : l'écart du capteur entre classes vient de l'ombre propre, et il dépend
  **surtout de l'orientation** (67 à 100 % pour une même classe, contre 11 % entre classes de profil). Torche du côté
  de l'arme, trois classes sont noires même à mi-portée. La voie (d) est **écartée par la mesure** : elle ne touche pas
  l'apparition, qui est aujourd'hui la même pour les dix classes dans 5 orientations sur 8, sauf pour la défaire (6 à
  16 px d'écart). Restent (a) garder, (b) le capteur qui ignore sa propre ombre (qui règle AUSSI l'orientation : sans
  ombre propre, le capteur est le même dans les huit orientations au dix-millième), (c) l'ombre ronde.
- **Mesure à corriger dans le rapport de la base** : « 11 % de lumière en moins, c'est apparaître ≈ 7 px plus tard » est
  faux ; le premier pixel suit le maximum de l'anneau, égal pour les dix classes de profil.
- **Piège** : le premier pixel d'un corps iso suit le MAXIMUM de l'anneau lu, pas sa moyenne. Juger une apparition par
  la moyenne du capteur (Q33, la base) mesure la largeur du liseré.
- **Piège** : mesurer « les pixels visibles d'un corps » contre le sol vide compte aussi l'ombre de contact et le sol
  autour ; contre le même corps sans lumière lue (capteur coupé, opaque), seul l'éclairage du corps compte. Et reposer la
  graine avant chaque prise (poussière du faisceau), comme Q33.
- **Piège** : un calcul géométrique sur 64 points et une étoile de 32 rayons tombe sur des égalités exactes (sommet SUR
  l'anneau) ; décaler l'échantillonnage d'un demi-pas.
- **Outils** : `planche_orientation`, `planche_apparition`, `ombre_compensee.gd` + `--ombre-compensee` et sa garde
  `test_ombre_compensee` (dans `run_suites.sh`), analyses dans `docs/iso/cloud/ombre-orientation/`.
