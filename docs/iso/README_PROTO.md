# Candela en isométrique 3D — prototype visuel

Étude « à la Unrailed 2 » demandée par Adrien : à quoi ressemblerait Candela si
l'arène était dressée en volumes et regardée de trois quarts, au lieu de la vue de
dessus actuelle. **Rien ici ne touche au jeu** : c'est une page HTML autonome
(Three.js r128) qui lit les *vraies* cartes de `assets/maps/` et une série de
captures. Le jeu, sa feuille de route et ses tests sont intacts.

Fichiers :

| Fichier | Rôle |
|---|---|
| `proto_iso.html` | Le prototype, un seul fichier, cartes embarquées |
| `captures/*.png` | Douze captures 1920×1080, < 400 Ko chacune |
| `planche_iso.jpg` | Planche 3×4 des captures, légendée |
| `capturer_iso.mjs` | Script Playwright qui refait les captures |
| `planche_iso.py` | Compression des PNG et composition de la planche |

## Ouvrir la page

Double-cliquer sur `docs/iso/proto_iso.html` (ou `open docs/iso/proto_iso.html`).
Three.js est chargé depuis cdnjs ; **hors ligne**, poser `three.min.js` (r128) à côté
de la page suffit, elle s'y rabat d'elle-même. Un GPU ordinaire tient 60 im/s : deux
maillages instanciés (dalles, murs), deux torches avec ombres 2048², un halo, un flash.

Le panneau de gauche règle tout ; `P` le masque.

### Touches

| Touche | Effet |
|---|---|
| `Z Q S D` / `W A S D` / flèches | déplacer J1 (relatif à la caméra : haut de l'écran = loin de la caméra), collision contre murs et fosses |
| souris | viser (la torche suit le curseur projeté au sol, lissage `aim_lerp_speed` = 18 comme `player.gd`) |
| clic gauche / `F` | tirer : flash de bouche (lumière ponctuelle, 0,16 s) |
| `T` | torche J1 allumée / éteinte |
| `Y` | torche J2 |
| `1` `2` `3` `4` | préréglages caméra : Unrailed ¾ (52°/45°), Isométrique vraie (35,26°/45°), Dessus incliné (70°/0°), Dessus (90°/0°) |
| `V` | perspective ↔ orthographique |
| `C` | centrer la caméra sur J1 plutôt que sur la carte |
| `R` | recadrer |
| `P` | masquer / afficher le panneau |

### Ce que montre la scène

- **Décodage v3** identique à `map_codec.gd::decode_runs` (runs `x,y,len`, longueur
  bornée à 128, cellules hors grille ignorées comme dans `map_geometry.gd::build_grid`).
  Vérifié : les six cartes donnent dans la page le même nombre de murs, de sols et de
  fosses qu'un décodeur Python indépendant (32×32 / 348 murs pour `default`, 24×24 / 220
  pour l'Arène Circulaire, 30×30 / 372 pour le Cloître, 32×26 / 372 pour l'Usine,
  28×28 / 360 pour la Croisée, 26×26 / 312 pour le Bunker).
- **Règle de solidité** de `map_geometry.gd` : un mur est une boîte (arrête joueur,
  balles et lumière) ; une case sans sol ni mur est une fosse — pas de dalle, trou noir,
  la lumière et le regard passent, le joueur non ; la ceinture d'une case autour de la
  grille est une fosse. ⚠️ **Aucune des six cartes livrées n'a de fosse intérieure**
  (leurs ceintures de murs font trois cases d'épaisseur, la seule fosse est le bord de
  carte, invisible derrière les murs). La case « Fosse d'essai » creuse un trou 4×3 au
  centre pour voir la règle en 3D — c'est synthétique, et dit comme tel.
- **Torche** = `SpotLight` à la pointe du nez (le `Flashlight` de `player.tscn` est à
  28 px), demi-angle 35° (`torch_angle_deg` du pistolet — c'est un DEMI-angle, comme
  dans `weapon_data.gd`), portée 12 tuiles (`portee_torche()` = 512 × 0,5 × 1,6 = 410 px
  = 11,7 tuiles), couleur entre AMBRE `#F5B03D` et HALOGÈNE `#FAE8CC` de `charte.gd`.
  Décroissance ½ : plein feu sur les deux premiers tiers puis extinction, comme le cookie.
- **Rétrodiffusion** : une petite lumière ponctuelle au nez du porteur (`body_light` du
  jeu) — la seule chose qui révèle un porteur de torche à distance, hors flash.
- **Halo de proximité** sur J1 seul (`ambient_light` n'éclaire que la vue de son
  porteur ; la caméra est celle de J1, J2 n'en a donc pas).
- J1 se voit faiblement dans le noir (émissif léger, l'équivalent de `VisualDim`) ; J2
  n'existe que s'il est éclairé.
- Sol et murs : `MeshStandardMaterial` gris béton (`#5c5c57` / `#4a4a46`, lus comme
  albédo linéaire ≈ 36 % / 29 %), grain généré, léger damier SOL_A/SOL_B, un liseré
  d'encre aux arêtes de chaque dalle et de chaque boîte. Fond noir, ambiance 0,015.
  Tonemapping ACES, exposition 1,2.

## Mode capture (paramètres d'URL)

Dès qu'un paramètre est présent, la page est **stable** : aucun souffle de torche,
aucun aléa (les variations de dalles sortent d'un générateur à graine), et
`window.__pret = true` après la deuxième image rendue. `window.__stats` donne les
comptes de la carte, `window.__erreurs` les erreurs JavaScript.

| Paramètre | Valeurs | Défaut |
|---|---|---|
| `carte` | `default`, `arene_circulaire`, `map_001_le_cloitre`, `map_002_l_usine`, `map_003_la_croisee`, `map_004_le_bunker` | `default` |
| `preset` | `unrailed`, `iso`, `incline`, `dessus` | `unrailed` |
| `pitch`, `yaw` | degrés (10–90, 0–360) ; priment sur le préréglage | du préréglage |
| `zoom` | 0,5–3 | 1 |
| `persp` | `1` pour la perspective | ortho |
| `mur` | hauteur des murs en tuiles, 0,3–1,5 | 1 |
| `torche` | demi-angle en degrés (5–60), ou `off` | 35 |
| `portee`, `intensite`, `teinte`, `hauteur`, `halo` | portée (tuiles), intensité, ambre→halogène 0–1, hauteur de la torche (tuiles), halo | 12, 5, 0,7, 0,9, 1 |
| `cible` | `x,y` en tuiles : J1 vise le centre de cette case | J2 |
| `j1`, `j2` | `x,y` : position des joueurs (sinon leur spawn) | spawns |
| `j2torche` | `suit` (vise J1), un angle en degrés (convention Godot : 0 = est, 90 = sud), ou `off` | `suit` |
| `flash` | `1` : flash de tir figé à son pic | non |
| `fosse` | `1` : fosse d'essai | non |
| `ambiance`, `exposition`, `suivre` | | 0,015, 1,2, non |
| `hud` | `0` masque le panneau | affiché |

Exemple : `proto_iso.html?carte=map_004_le_bunker&preset=unrailed&yaw=315&zoom=1.5&hud=0`.

## Refaire les captures

```bash
# Prérequis (une fois) : Node ≥ 18, Playwright et son Chromium, Pillow.
npm i playwright && npx playwright install chromium
pip install pillow

# Depuis la racine du dépôt :
node docs/iso/capturer_iso.mjs
# → PNG bruts dans <tmp>/candela_iso_brut/, puis planche_iso.py compresse vers
#   docs/iso/captures/ (< 400 Ko, palette réduite par paliers) et compose planche_iso.jpg.

# Options : --seulement 03_le_cloitre_unrailed,06_le_bunker_unrailed   --brut DIR
#           --three /chemin/three.min.js   (réseau fermé : servi sous l'URL du CDN par page.route)
#           --sans-planche   puis   python3 docs/iso/planche_iso.py --brut DIR
```

Le catalogue des douze captures (carte, préréglage, paramètres, légende) est la
constante `CAPTURES` en tête de `capturer_iso.mjs`. Chromium tourne sans GPU par
SwiftShader (`--use-angle=swiftshader --enable-unsafe-swiftshader`) : compter 6 à
13 s par image ; ne pas paralléliser les navigateurs, quatre cœurs n'en ont pas tenu
cinq.

Dans l'environnement où ces captures ont été faites, Chromium ne passait pas le proxy
sortant (handshake TLS coupé, alors que `curl` passait) : Three.js a été téléchargé par
curl puis servi à la page par `page.route()` sous l'URL cdnjs. Commande exacte :

```bash
NODE_PATH=/opt/node22/lib/node_modules node docs/iso/capturer_iso.mjs \
  --brut "$SCRATCH/brut" --three "$SCRATCH/three.min.js"
```

Pour rafraîchir les cartes embarquées après une modification de `assets/maps/` :
remplacer le contenu du bloc `<script id="cartes" type="application/json">` par le
tableau des six JSON, chacun augmenté d'un champ `__slug` (nom du fichier sans
extension), `default` en tête.

## Les captures, et ce qu'elles apprennent

| # | Fichier | Contenu |
|---|---|---|
| 01–06 | `0N_<carte>_unrailed.png` | chaque carte en Unrailed ¾, J1 sur son spawn visant J2, J2 sur son spawn visant J1 |
| 07–10 | `default_preset_*.png` | Arène Standard dans les quatre préréglages, J2 avancé à 8 tuiles pour être dans le faisceau |
| 11 | `default_flash.png` | flash de tir au pic, torche allumée |
| 12 | `le_cloitre_contre_champ.png` | le Cloître avec la caméra **en face** de la visée : le cas défavorable |

**La découverte qui compte** (captures 03 et 12, même carte, même torche) : la torche
éclaire les faces tournées vers J1, la caméra ne voit que les faces tournées vers elle.
Elles coïncident quand la caméra regarde dans le sens de la visée (03 : face ouest du
pilier éclairée, ombre nette derrière) ; quand J1 vise vers la caméra (12), le pilier
n'est plus qu'une silhouette noire dans un sol éclairé, et la mécanique « je vois le mur
que j'éclaire » disparaît. Dans un jeu, la caméra a un yaw fixe et le joueur vise
partout : **la moitié des visées montrent des murs noirs.** Les captures 01–11 sont
prises caméra derrière J1 (yaw 315 pour un J1 qui vise l'est, 225 sur la Croisée) — le
meilleur cas, choisi sciemment.

Lisibilité par préréglage (captures 07 à 10) :

- **Unrailed ¾ (52°)** — le meilleur compromis : faces des murs, volume des corps,
  cônes au sol elliptiques mais lisibles, ombres portées des corps très parlantes.
  Un mur d'une tuile cache derrière lui une bande de sol de 0,78 tuile.
- **Isométrique vraie (35,26°)** — plus « plateau de jeu », faces des murs plus
  grandes, mais un mur cache 1,4 tuile de sol derrière lui et les cônes s'aplatissent.
- **Dessus incliné (70°)** — proche du jeu actuel avec un soupçon de volume ; un mur
  ne cache que 0,36 tuile. Les faces éclairées sont fines.
- **Dessus (90°)** — c'est le jeu : disques, cônes coupés par les occluders, ombres
  en coin. Les murs ne sont lisibles que par leur silhouette dans le faisceau (les
  dessus sont noirs), exactement comme les tuiles noires + `mur_encre` d'aujourd'hui.

La Croisée (05) depuis son spawn n'est qu'un « V » sur le bloc qui protège
l'apparition : c'est la carte, pas le rendu ; `cible=20,5` (viser le long du couloir
nord) la montre bien mieux.

## Limites du prototype — ce qu'il ne montre PAS

- Aucun gadget, aucune classe, aucune fusée, mine, voile, brouillage, poudre.
- Ni éblouissement ni voile, ni traînées de balles, douilles, impacts, sang, étincelles.
- Pas de sprites, pas d'animation, pas de HUD de jeu, pas d'écran scindé, pas de réseau,
  pas de killcam, pas de son.
- Les corps sont des cylindres à calotte, pas les silhouettes du jeu ; les murs sont des
  boîtes unies, sans texture peinte ni contour d'encre au sens de `mur_encre.gd`.
- Les balles ne sont pas simulées : le flash est une lumière, rien ne part.
- La torche est une vraie lampe : le sol lointain reçoit une lumière rasante, le cône du
  jeu (cookie 2D uniforme en hauteur) est plus « plein ». La décroissance ½ et
  l'intensité 5 compensent, pas plus.
- Ombres par shadow map (PCF doux 2048²) : bords légèrement flous, pas les ombres au
  pixel des `LightOccluder2D`.
- Le dessus des murs est noir hors halo (ambiance 0,015) : fidèle au « noir absolu »,
  mais une carte ne se lit pas d'un coup d'œil comme dans Unrailed, qui est en plein jour.
- Rendu logiciel dans les captures (SwiftShader) : l'anticrénelage y est celui de
  Chromium sans GPU ; sur une vraie carte graphique la page est plus nette.

## Réglages recommandés pour « Candela en iso »

1. **Pitch 50–55°** (Unrailed ¾), jamais l'iso vraie : à 35° un mur d'une tuile cache
   1,4 tuile de sol, à 52° 0,78 — et il faut un mécanisme pour les faces sombres (fond
   de 0,02–0,03, ou liseré des arêtes), sinon la moitié des visées montrent des murs noirs.
2. **Murs à 1,0 tuile, torche à 0,9** : la torche reste SOUS le haut du mur, donc l'ombre
   est infinie — la règle du jeu (« un mur arrête la lumière »). Monter la torche à 1,3
   dessine le dessus des murs dans le faisceau au prix d'ombres finies (3,3 × la
   distance) ; baisser les murs à 0,3 laisse passer la lumière par-dessus et tue la
   mécanique. Le curseur « Haut. torche » le montre en direct.
3. **Demi-angle 30–35°** (le pistolet) : au-delà de 45° le cône devient un projecteur de
   chantier et deux torches face à face ne font plus qu'un losange plat.
4. **Intensité 5, exposition ACES 1,2, décroissance ½, halo 1,0** : sol lisible dans le
   cône jusqu'aux deux tiers de la portée, faces des murs franches sans saturer.
5. **Portée 12 tuiles** (celle du jeu) : à 15–19 tuiles de spawn à spawn, personne ne
   voit personne au départ, comme aujourd'hui ; l'allonger changerait l'équilibre, pas
   la lisibilité.
