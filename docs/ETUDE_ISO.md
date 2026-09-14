# Candela en vue isométrique « à la Unrailed 2 » — étude de faisabilité (ISO0)

> Réponse à la question d'Adrien du 2026-09-13 : *« que coûterait de donner au
> jeu une vue 2D/3D à la Unrailed 2, en vue isométrique ? Quels mécanismes
> conserver, ce qui sera dur dans le code, le coût, la répartition entre
> sessions, avec quels modèles et quel niveau de réflexion, un trajet par
> étapes, des visuels et des prototypes. »*
>
> **Rien de ce document n'est engagé.** C'est l'étape ISO0 d'un chantier qui
> n'existe que sur le papier : elle se termine par une décision qui appartient à
> Adrien (jalon H15), et chaque étape suivante se lance sur demande explicite,
> comme le veut le protocole du dépôt.
>
> **Version en ligne, avec la galerie et le prototype à manipuler :**
> https://claude.ai/code/artifact/3beaf3fb-bddd-4aec-85c8-86909d503411
>
> **Comment elle a été faite.** Quatorze lecteurs et chercheurs (cinq sur le
> code, trois sur la ROADMAP, un sur l'historique git, quatre sur le web), deux
> architectes (approches A et B) et deux agents de prototypage ont travaillé en
> parallèle le 2026-09-13. Le troisième architecte (approche C), les deux juges
> et les huit réfutateurs prévus **ont été refusés par la limite hebdomadaire du
> forfait**, atteinte pendant l'étude ; le jugement des approches et la
> vérification des affirmations clés ont donc été faits par la session
> principale, à la main, contre la documentation officielle de Godot et contre
> le code. Ce qui est vérifié est dit vérifié ; ce qui est estimé est dit
> estimé. Tout `fichier:ligne` cité est celui du dépôt au commit `8f16f3a`.

## 0. La réponse en douze lignes

1. **C'est faisable sans toucher au réseau, à la prédiction, au rejeu ni aux
   cartes** : la simulation de Candela est déjà séparée de sa présentation
   (positions `Vector2`, éblouissement calculé sur l'image du cookie et un
   raycast physique, jamais sur les pixels rendus). La 3D peut être un
   « second écran » du même monde.
2. **Le point dur n'est pas la géométrie, c'est la lumière.** Le renderer
   `gl_compatibility` (décision actée) **ne supporte pas les projecteurs de
   lumière** : la torche à cookie, mécanique centrale du jeu, ne peut pas être
   une `SpotLight3D`. Et une lumière 3D à ombres coûte une passe de rendu par
   objet, mélangée en sRGB, avec un plafond de 8 lumières par maillage.
3. **La voie recommandée (B-projection)** garde le pipeline de lumière 2D
   actuel comme *seule* vérité — il est rendu dans une sous-vue par joueur et
   **projeté sur un sol 3D** — et n'ajoute en 3D que le relief : murs en
   boîtes basses, corps en voxels, caméra orthographique inclinée. Ce que
   l'écran montre est, au pixel près, ce que l'hôte fait payer.
4. **Les prototypes ont tranché deux questions** qu'aucun croquis n'aurait
   tranchées : un mur d'une tuile cache 0,78 tuile de sol à l'angle d'Unrailed
   (52°) et 1,41 en isométrie vraie — donc **murs bas (0,4 tuile) et caméra
   plongeante (60-65°)** ; et de vraies lumières 3D rendent les faces des murs
   **asymétriques entre les deux joueurs** (celui côté caméra « dessine » sur les
   murs, l'autre voit des blocs noirs) — ce que la projection du rendu 2D évite
   par construction.
5. **Coût** : 26 à 30 sessions-journées d'agents, réparties sur 4 à 6 semaines
   calendaires avec deux ou trois sessions en parallèle, plus six jalons
   d'Adrien (relevés de cadence au premier plan, planches, essais manette).
   C'est du même ordre que le chantier DIX CLASSES et la fusée réunis.
6. **Le forfait est la vraie contrainte** : cette étude seule (26 agents lancés,
   15 aboutis, ≈ 3,6 millions de tokens d'agents en Fable 5.1) a épuisé le
   reliquat hebdomadaire de Max 20x. Le chantier ne tient dans le forfait que
   si 80 % des sessions tournent en Sonnet 5 / Opus 5 et si Fable 5.1 est
   réservé à deux étapes.
7. **Le risque principal n'est pas technique**, c'est l'identité : le noir
   absolu gomme l'essentiel de ce qui fait le charme d'Unrailed (couleur,
   soleil, contours), et le pipeline d'assets « vue strictement de dessus »
   livré les 9-12 septembre serait à refaire. D'où l'alternative à peser :
   **l'iso pour les vitrines** (menus, killcam, écran de fin, fiches), **la
   vue de dessus pour le duel**.

## 1. Ce qu'est Unrailed 2, vu de près

Sources : les six captures officielles de la page Steam (app 2211170),
téléchargées et lues image par image par la session principale ; le blog
d'Indoor Astronaut (billet « Performance Update », sponsoring Godot) ; les
notes de patch Steam ; le dev snapshot Godot 4.4 dev 4 qui met le jeu en
couverture ; les critiques (NoobFeed, LadiesGamers, ChromaGlitch, Playfront).
URL en annexe A.

### 1.1 La caméra

- **Vue de trois quarts en perspective douce, pas une isométrie.** Dans la
  capture de l'éditeur de niveaux, les lignes de la grille convergent vers le
  haut ; sur les plans larges, les blocs lointains sont un peu plus petits.
  Inclinaison estimée 50-60° sous l'horizontale, rotation de 20-45° autour de
  la verticale selon les scènes (les rails courent presque à l'horizontale, ce
  n'est pas le losange à 45° des jeux « iso »).
- **Un flou de profondeur** (effet maquette, *tilt-shift*) en haut et en bas de
  l'image sur plusieurs captures, et un brouillard coloré aux bords.
- Le cadrage suit le train ; depuis juillet 2025 un mode « centré joueur »
  existe pour le Steam Deck. Pas de rotation libre en jeu.

### 1.2 Le monde

- **Une dalle-diorama** : le niveau est un plateau voxel posé sur un vide uni
  (bleu ciel dans l'éditeur, nuit bleue dans le biome nocturne).
- **Une tuile = un cube.** Reliefs d'une à deux unités, arbres et rochers en
  amas de voxels, eau en tuile creuse. Tout est aligné sur la grille.
- **Un seul soleil** (lumière directionnelle) avec ombres douces, une ambiance
  teintée par biome. **La nuit d'Unrailed n'est jamais noire** : elle
  assombrit, elle ne cache pas — l'inverse exact du contrat de Candela.

### 1.3 La lisibilité, qui est le vrai sujet

- Les personnages font une tuile ; chacun porte un **anneau de sa couleur** au
  sol ; wagons et objets portent un **contour blanc** (par *stencil buffer*,
  d'après le blog). À quatre joueurs et un train en feu, tout reste lisible :
  c'est ce que toutes les critiques retiennent. La lisibilité vient des
  contours, des anneaux et des palettes par biome — pas du voxel.
- **Les blocs hauts cachent ce qui est derrière eux** (capture nocturne : les
  tours de brique masquent l'espace à leur pied côté caméra). Dans Unrailed
  c'est décoratif ; dans Candela ce serait de l'information perdue. C'est le
  premier point d'équité de cette étude (§ 5.2).

### 1.4 La technique, ce qu'on en sait

Godot 4.3.1 → 4.5 → 4.6.3 ; quatre pilotes graphiques livrés et choisis
automatiquement (Vulkan, D3D12, OpenGL, ANGLE) plus un « mode compatibilité »
— **le rendu par défaut d'Unrailed 2 n'est donc pas Compatibility** ; toute la
simulation dans un fil séparé fusionné avant chaque image (35 → 85 i/s sur un
Intel HD 520 en 1080p) ; contours par stencil ; sortie le 11 juin 2026 sur
Switch, Switch 2 et PS5. Aucune conférence ni billet technique sur la caméra
ou le renderer : au-delà, il faut observer les captures et prototyper.

### 1.5 Ce qui se transpose à Candela, et ce qui ne se transpose pas

| Se transpose | Ne se transpose pas |
|---|---|
| La dalle-diorama, une tuile = un bloc (`map_geometry.gd` produit déjà les rectangles fusionnés : 4 à 11 boîtes par carte livrée) | Le soleil et toute lumière globale — Candela n'a **aucune** ambiance, par définition |
| Des murs bas, une caméra plongeante à rotation fixe | La perspective (échelle inégale selon la distance) : orthographique, pour que les deux joueurs voient la même image |
| Des personnages en petits blocs, avec la couleur de rôle bleu/rouge (décision du 2026-08-19) | Le flou de profondeur, qui cache de l'information |
| Le relief des corps et des murs comme aide à la lecture — dans la lumière seulement | Les contours et anneaux au sol : ils dévoileraient un corps dans le noir (à réserver à la killcam) |
| La grille 32×32 et le format de carte v3, inchangés | La palette saturée par biome : la charte reste encre / béton / ambre |

## 2. Ce que le jeu est aujourd'hui, en une page

Ce que les lecteurs ont établi dans le code, et qui décide de tout le reste.

- **La lumière est un protocole, pas un décor.** Quatre `PointLight2D` par
  joueur — torche à cookie peint par arme (`player.gd:753-790`,
  `weapon_data.gd:151-185`), rétrodiffusion, halo de proximité, flash de bouche
  — plus balles, mine, braises, torche fantôme, fusée, impact et un bandeau LED
  cuit en texture. Deux familles de masques disjointes, dans
  `canaux_lumiere.gd:26-85` : *qui est éclairé* (`light_mask` /
  `range_item_cull_mask` : décor 1, ennemi 2, joueur local 4, canal de vue
  16/32) et *qui fait de l'ombre* (`occluder_light_mask` /
  `shadow_item_cull_mask` : corps 4/8, torse 16/32). Un corps ombre la torche
  de l'autre, jamais la sienne ; le halo révèle l'ennemi proche chez son
  porteur seulement.
- **La logique de jeu ne lit jamais les pixels rendus.** L'éblouissement
  échantillonne l'*image* du cookie sur le processeur (`vision.gd:130-155`,
  `weapon_data.gd:203-215`, `game_state.gd:2005-2117`) et lance un raycast
  physique 2D ; le brouillage, la vision, l'occultation des fumées sont des
  formules pures. Neuf effets d'écran (voile, distorsion, vignette, flash de
  mort, planche de killcam, brouillage, estampe, affiche, cadre) vivent sur des
  `CanvasLayer` et passent au-dessus de n'importe quel monde.
- **La simulation est présentation-agnostique.** Réplication de six scalaires
  (`player.gd:551-566`), prédiction et interpolation sur position/rotation
  seulement (`player.gd:1386-1502`), compensation de latence sur des `Vector2`
  (`game_state.gd:3523-3550`), rejeu de positions et de scalaires à 60 Hz
  (`replay_system.gd:47-91`, à deux lectures de nœuds 2D près) ;
  `network_manager.gd` ne contient pas un mot visuel.
- **Mais `player.gd` est un mille-feuille** : 316 de ses 3 096 lignes
  référencent des nœuds visuels 2D, dans les mêmes fonctions que la simulation.
  Et la présentation autonome (dix gadgets, fusée, particules, décals, décor,
  bandeau LED) pèse ≈ 6 000 lignes qui dessinent en 2D et se dupliquent par
  vue.
- **Les cartes sont tabulaires et déterministes** : RLE v3, grille de solidité,
  `merge_rects` (55 rectangles de murs pour les six cartes livrées, aucune
  fosse intérieure), contours par *marching squares*. Une géométrie 3D en est
  une troisième vue, comme `menu_arene.gd` en est déjà une seconde.
- **La cadence** : cible `1 % bas ≥ 60` (`bench_framerate.gd:33`), dernier
  relevé au premier plan (2026-09-12, `cf68cf2`, `docs/ROADMAP.md:15706-15718`)
  vue unique **160 / 97**, écran scindé **150 / 84**. Le rendu par la racine
  vaut +15 % parce qu'il supprime une cible de rendu intermédiaire — un fait
  matériel du GPU à tuiles qui pèse sur l'approche recommandée (§ 3.2).
- **La barre de qualité** : 76 suites `--script` + scènes + 8 scénarios à deux
  instances, trois verdicts rouges (code, `SCRIPT ERROR`, `push_error`
  déclarés), rien qui regarde l'image. Les cinq défauts de rendu du chantier
  DIX CLASSES n'ont été vus qu'à la capture (`docs/ROADMAP.md:17570-17577`).

## 3. Trois façons d'y arriver

### 3.1 Ce que le renderer permet — vérifié dans la documentation officielle

| Compatibility (Godot 4.7) | État | Conséquence pour Candela |
|---|---|---|
| Ombres des `SpotLight3D` (1 rendu) et `OmniLight3D` (cubemap 6 faces) | ✅ depuis 4.2 — **rendues à l'image par le prototype** | la torche serait un spot, jamais une omni |
| Projecteur de lumière (`light_projector`, le cookie) | ❌ « only supported in the Forward+ and Mobile rendering methods » | **la torche à cookie n'existe pas en Light3D** |
| `Decal` | ❌ non supporté | sang, éclats, empreintes = quads plats |
| Lumières par maillage | 8 omni + 8 spot (réglable), 32 par image | un rectangle de mur fusionné est UN maillage |
| Chaque lumière avec ombre | une passe additive par objet, mélangée en sRGB (PR #77496, issue #90259) | l'apparence change quand on active l'ombre |
| `shadow_caster_mask` | ✅ depuis 4.4, « testé en Compatibility » — **vérifié au prototype** | les couches d'ombre se transposent |
| `GridMap` | ne porte pas de `layers` | murs en `MeshInstance3D`/`MultiMesh`, jamais en GridMap |
| Caméra orthographique + ombres directionnelles | régression de culling en 4.7.0, corrigée en **4.7.1** (PR #120711) | exiger 4.7.1 dès qu'une `DirectionalLight3D` entre |
| macOS | OpenGL 3.3 natif (ANGLE-over-Metal abandonné) ; Forward+/Mobile = Metal sur Apple Silicon | changer de renderer coûte 1-2 images de latence (issue #100025) |

### 3.2 Les approches

**A — Rester en 2D : la projection oblique par la matrice du canevas.** Le
calcul de lumière 2D se fait en espace canevas et n'est projeté à l'écran
qu'ensuite par `canvas_transform` ; remplacer cette matrice par une projection
oblique donne l'image affine exacte du rendu de dessus, cône, ombres et masques
compris. Par-dessus : des faces de murs extrudées et des sprites dressés
éclairés à leur pied (`LIGHT_VERTEX`/`SHADOW_VERTEX`). Coût nul en rendu,
aucun nœud 3D. Mais c'est un trucage par sprite : pas d'ombre d'un mur sur un
mur, pas d'objet en vol, et l'hypothèse fondatrice (le rasterizer projette
l'atlas d'ombres 2D comme une image affine) reste à prouver au premier plan.
**27 sessions, 13 jours** selon son architecte.

**B — Simulation 2D conservée, présentation 3D « miroir » — variante
B-projection.** Les deux `SubViewport` 2D existants deviennent les *lightmaps*
par joueur : ils continuent de rendre sol, murs noirs, encre, LED, décals,
nappes et toutes les lumières et ombres 2D avec leurs masques d'équité — seuls
les sprites de corps en sont retirés. La racine (vue unique) ou deux
`SubViewport` 3D (écran scindé) dessinent un sol plan qui affiche cette texture
projetée, des murs `BoxMesh` bas dont les faces verticales prennent la lumière
lue à leur pied, et des corps voxel construits par code qui suivent
`Player1`/`Player2` après interpolation. Deux sous-vues de 256² portent des
« capteurs » blancs aux pieds des corps avec les masques `JOUEUR_LOCAL` et
`masque_vue_adverse` : la lumière reçue par les corps, canal par canal, sans
réécrire un shader `light()`. Aucune `Light3D`. **26 sessions, 15 jours**
selon son architecte. Option ISO8 : de vraies `SpotLight3D` sans ombre pour
le relief seul.

**C — Passage complet en 3D** (`CharacterBody3D`, physique 3D, balles 3D,
cartes en GridMap, lumières natives). Son architecte n'a pas pu tourner ; la
session principale l'estime d'après les lectures : il faut réécrire
`player.gd` (3 096 lignes, prédiction et tir compris), `bullet.gd`
(ShapeCast2D et compensation de latence), la ligne de vue de l'éblouissement,
le rejeu, le format des instantanés, et refaire l'étalonnage réseau validé à
deux machines — pour un jeu dont l'information est la lumière, pas la
géométrie. Ordre de grandeur : **60 à 80 sessions**, avec la torche à cookie
toujours impossible en Compatibility. Écartée.

### 3.3 Le jugement — fait par la session principale, à défaut des juges

| | Jeu (immédiat, lisible) | Honnêteté (fonctionnel, léger, équitable) | Coût | Risque | Total |
|---|---|---|---|---|---|
| A — 2D oblique | 6 | 7 | 8 | 6 | 27 |
| **B — projection** | **8** | **9** | 7 | 6 | **30** |
| C — 3D complet | 8 | 4 | 2 | 2 | 16 |

Pourquoi B : (1) **l'honnêteté par construction** — l'image projetée au sol
*est* le rendu 2D qui décide de l'éblouissement ; A l'obtient aussi, mais par
un shader par sprite, et C la perd. (2) **Le relief réel** des corps et des
murs, que les deux prototypes montrent comme ce que la 3D apporte de plus
parlant (ombre portée des corps, faces allumées) — A ne l'a que pour les faces,
par extrusion. (3) **Les 6 000 lignes de présentation 2D ne sont pas
réécrites** : décals, nappes, fumées, LED restent dans la lightmap ; seuls les
objets debout deviennent des voxels. (4) **La symétrie du duel** : une face de
mur s'allume si et seulement si le sol à son pied est allumé, pour les deux
joueurs — là où de vraies lumières 3D dépendent du côté de la caméra (§ 5.2).
Pourquoi pas plus haut en coût : B **réintroduit une cible de rendu
intermédiaire** que le chantier R avait supprimée pour +15 %, et l'écran
scindé en paie deux. C'est *le* chiffre que l'étape ISO0.b doit produire.

**Greffes de A sur B** : l'idée de la matrice oblique sert de test de
non-régression (la lightmap projetée doit coïncider avec la vue de dessus à
± 2 % de luminance au même point) ; les faces de murs « éclairées à leur base »
sont le même geste dans les deux approches ; le test d'équité chiffré par
moitié de carte vient de A.

## 4. Les mécanismes à conserver — et ce qu'ils deviennent

| Mécanisme | Fichiers | En B-projection |
|---|---|---|
| Réseau hôte-autoritaire, prédiction, interpolation, compensation de latence, protocole versionné | `network_manager.gd`, `player.gd:551-566, 1386-1502`, `game_state.gd:3395-3550`, `protocol.gd` | **inchangés** ; la 3D vit dans un sous-arbre `Presentation3D` hors des nœuds porteurs de RPC (nommage stable) |
| Éblouissement, brouillage, vision, table des effets | `game_state.gd:2005-2117`, `vision.gd`, `eblouissement.gd`, `brouillage.gd`, `effect_policy.gd` | **inchangés** : ils lisent l'image du cookie et le monde physique 2D, qui restent vivants sous la 3D |
| Le protocole des canaux et des couches d'ombre | `canaux_lumiere.gd` | appliqué tel quel dans les sous-vues 2D ; la 3D le *lit* (layers 2/4, `Camera3D.cull_mask` ~4/~2) |
| Toutes les `PointLight2D` et `LightOccluder2D`, le plafond de 15 par item déjà maîtrisé | `player.gd`, `bullet.gd`, gadgets, `mur_led.gd` | continuent d'éclairer la lightmap ; **aucune Light3D** |
| Cartes : format v3, catalogue, géométrie, éditeur, vignettes, code de partage | `map_codec.gd`, `map_data.gd`, `map_geometry.gd`, `map_editor*.gd`, `map_thumbnail.gd` | inchangés ; `build_meshes()` = une troisième vue des mêmes rectangles (patron `menu_arene.gd:253-301`) |
| Sol dessiné, encre des murs, décor cuit, LED, décals, nappes, fumées et leurs six shaders `light()` | `candela_tileset.gd`, `mur_encre.gd`, `arena_decor.gd`, `blood_stain.gd`, `fusee.gd`… | **rien à réécrire** : ils apparaissent sur le sol 3D via la lightmap |
| Les neuf post-process d'écran et les matériaux de menu | `voile_eblouissement.gdshader`, `brouillage_vue.gd`, `killcam_overlay.gdshader`, `menu_*` | `CanvasLayer` au-dessus de la 3D ; seuls le brouillage (centre, rayon) et l'angle `relevement` du voile passent par `Camera3D.unproject_position` |
| Rejeu 60 Hz et killcam | `replay_system.gd`, `game_state.gd:1126-1163, 1636-1760` | les fantômes 2D existants sont mirrorés comme les joueurs ; deux lectures de nœuds à remplacer par des champs |
| Audio 2D, oreille sur le joueur | `audio_manager.gd` | inchangé (la simulation 2D reste, S7 reste valide) |
| Rendu par la racine en vue unique, écran scindé par masques | `game_state.gd:5114-5376`, `main.tscn` | reconduit en 3D : la racine adopte le `World3D` et la `Camera3D` de la vue regardée ; les vues non regardées en `UPDATE_DISABLED` (piège des 1,5 ms) |
| Lanceur de suites, banc, protocole de relevé, `ConditionsDeMatch` | `tools/run_suites.sh`, `tools/bench_framerate.gd`, `conditions_de_match.gd` | inchangés ; le banc apprend `--iso` et imprime ce qu'il rend |

## 5. Ce qui sera dur dans le code

Classé du plus décisif au plus mécanique.

### 5.1 La torche à cookie n'existe pas en 3D Compatibility

`Light3D.light_projector` : « only supported in the Forward+ and Mobile
rendering methods, not Compatibility ». Or la torche *est* un cookie peint par
arme (`assets/torche/cookie_<slug>.png`, 1024², posé par `flashlight.texture`,
cuit par `tools/fabrique_cookies.gd`), et c'est cette image que l'éblouissement
lit. Trois sorties : rouvrir la décision de renderer (Forward+/Mobile = Metal
sur Apple Silicon, mais 1-2 images de latence en plus et un chemin OpenGL
perdu sous Windows), réécrire la torche dans un shader spatial maison
(projection du cookie en espace lumière + ombres à la main — c'est l'essentiel
du coût d'un miroir à Light3D), ou **ne pas porter la lumière du tout et
projeter le rendu 2D** (B-projection). La troisième garde la même image comme
source de vérité pour le rendu et pour la règle.

### 5.2 Ce qu'une caméra inclinée cache, et ce qu'elle rend asymétrique

Mesuré aux prototypes (`h / tan θ`, mur d'une tuile) : **0,78 tuile** cachée
derrière chaque mur à 52° (Unrailed), **1,41** en isométrie vraie (35,26°),
**0,36** à 70°, 0 de dessus. Avec des murs de 0,4 tuile et un tangage de 60 à
65°, la bande tombe à 0,19-0,23 tuile (7-8 px), sous le rayon d'un corps
(18 px) : un corps collé derrière un mur montre encore son torse. La bande est
la même pour les deux joueurs (même caméra), mais elle dépend de l'orientation
des murs — d'où un lacet de 0° par défaut (45° « Unrailed » seulement après
preuve carte par carte) et un test d'équité chiffré sur les six cartes.

Et le constat qui casse la symétrie avec de vraies lumières 3D (prototype
Godot, Cloître, même torche) : la torche éclaire les faces tournées vers son
porteur, la caméra ne voit que les faces tournées vers elle ; **le joueur côté
caméra dessine sur les murs, l'autre voit un bloc noir posé sur un sol
éclairé**. Avec un lacet fixe, la moitié des visées montrent des murs noirs — et
ce n'est pas la même moitié pour les deux joueurs. La projection du rendu 2D
l'évite : une face s'allume quand le sol à son pied s'allume, ni plus ni moins,
des deux côtés.

### 5.3 Deux vérités d'ombre, ou une seule

Un miroir à `Light3D` fabrique une seconde ombre (shadow map, biais, filtrage,
résolution d'atlas) à côté de l'ombre au pixel des `LightOccluder2D` qui décide
du jeu — et le dépôt a déjà payé trois divergences entre « ce qui se voit » et
« ce qui se paie » (`gadget_torche_fantome.gd:24-30`, piège du 2026-08-24). Le
prototype Godot a en plus montré qu'un **sol Lambert efface le cône** (à cinq
tuiles la lumière arrive à 7°, un béton physique n'en garde que 12 %) : il faut
tricher explicitement sur le sol. B-projection n'a qu'une vérité et n'a pas ce
problème ; c'est l'argument qui l'emporte.

### 5.4 Les vues, les canaux, la racine

L'écran scindé sépare les deux mondes par `canvas_cull_mask` ~4/~2 et
duplique chaque décal pour J2 ; la vue unique prête le `World2D` à la racine.
En 3D il faut deux `SubViewport` 3D partageant un `World3D`, deux caméras avec
`cull_mask`, deux jeux de sol/murs sur des layers, la racine qui adopte le
monde et la caméra — et tout ce qui vit dans `game_state.gd:5114-5376` à
refaire sous garde `mode_iso`. C'est l'étape où **tout casse sans erreur
console** (masques, viewports arrêtés qui tournent, calques mal logés, RPC
déroutés par un nœud ajouté au mauvais endroit) : chaque piège est déjà consigné,
il faut la session qui lit le plus loin (Fable 5.1, § 7).

### 5.5 Les corps et les objets debout

Les sprites « vue strictement de dessus » à 1 texel par unité (décision du
2026-09-10 ; 100 PNG pour dix classes) n'ont aucun sens à 60° : on verrait un
casque couché. Trois voies : voxels construits par code (déterministes, sans
import, lisibles à la Unrailed — recommandé), sprites 3/4 à huit directions
(≈ 400 images Gemini, en série), ou `.vox` importés. Le shader d'équité de
l'ennemi (« gris plafonné, noir hors lumière », `player_enemy_light.gdshader`)
se réécrit en spatial en lisant le capteur au lieu de `LIGHT_ENERGY` — même
formule, autre source. La portée d'arme doit rester lisible sur le corps voxel
(l'invariant « l'arme ne ment pas », `docs/ROADMAP.md:10322-10389`).

### 5.6 Le reste, petit mais dispersé dans des fichiers partagés

Visée souris (`local_input_provider.gd:65-73` : rayon de caméra coupé par le
plan du sol), brouillage (ellipse en texels de framebuffer), angle du voile,
chiffres de dégâts, zoom killcam (0,7-2,8 → `size` orthographique), photographe
(source `vue`, cadrages), `test_rendu` (joueur centré), compteur F3,
`ConditionsDeMatch` (mode de rendu). Chacun tient en dix à vingt lignes, mais
chacun vit dans un fichier réservé : le chantier passe par des demandes
d'écriture à la session qui tient le fichier, jamais par un worktree autonome.

### 5.7 Ce qui ne se teste pas headless

Le lanceur ne rastérise rien. En 3D la surface non testable grandit
(z-fighting sol/quads, uv de projection décalés d'un texel, faces qui fuient la
lumière). Chaque étape a donc un jalon de planche de contact regardée par
Adrien, et le rythme du chantier est le sien, pas celui des agents.

## 6. Ce que ça coûte

### 6.1 L'unité et la calibration

Une **session-journée** = une session Claude Code desktop qui mène une étape de
bout en bout, suites vertes comprises, soit une demi-journée à une journée de
travail effectif. Calibration sur ce dépôt : le chantier DIX CLASSES a livré 28
étapes en 4 jours calendaires avec trois à quatre sessions en parallèle ; la
fusée éclairante, 12 jours avec retouches ; la refonte roman graphique, 4
jours. Le grain réel est petit et fréquent (médiane 80 lignes par commit hors
fusions ; 149 commits le 2026-09-09, dont 53 fusions). L'historique visible de
ce clone ne remonte qu'au 8 septembre : ces chiffres sont un plancher, pas une
loi.

### 6.2 Le chantier ISO en sessions-journées

| Étape | Objet | Sessions | Modèle / effort |
|---|---|---|---|
| ISO0 | Étude et prototypes (**fait**) ; ISO0.b : banc B-projection dans le vrai jeu + relevé + décision | 2 | Opus 5 / high |
| ISO1 | Fondations : géométrie 3D, caméra iso, sol projeté, murs | 3 | Opus 5 / high |
| ISO2 | Vues et canaux : lightmaps par joueur, capteurs, racine 3D, écran scindé | 4 | **Fable 5.1 / xhigh** |
| ISO3 | Corps voxel des dix classes, matériau d'équité | 4 | Sonnet 5 / high |
| ISO4 | Objets debout, leurre, balle, viseur, ligne de visée | 3 | Sonnet 5 / medium |
| ISO5 | Killcam, rejeu, entrées souris/stick, photographe du duel | 3 | Opus 5 / high |
| ISO6 | Outils : banc `--iso`, photographe, F3, diagnostic | 2 | Sonnet 5 / medium |
| ISO7 | Direction artistique et assets (Gemini en série) | 3 | Sonnet 5 / medium |
| ISO8 | *Option* : lumière seule + sol texturé, si la cadence l'exige | 4 | Opus 5 / high |
| ISO9 | Équité, mode de jeu (rendu imposé par l'hôte en classé), documentation | 2 | Opus 5 / medium |
| | **Total** | **26 (30 avec ISO8)** | |

**Calendrier** : 15 jours ouvrés selon l'architecte de B avec deux à trois
sessions en parallèle ; la session principale retient **4 à 6 semaines**, parce
que chaque étape attend une planche ou un relevé d'Adrien, que les pièges de
cache d'import et de fusion se paient à chaque vague, et qu'un chantier de
rendu produit des défauts qu'aucune suite ne voit.

### 6.3 Ce que ça coûte en forfait — mesuré sur cette étude

Faits vérifiés (support.claude.com, 2026-09-13) : il n'existe pas de forfait
« Ultra » ; 180 €/mois correspond à **Max 20x** (200 $, affiché en dollars hors
taxes sur la page française — à confirmer dans *Settings › Usage*). Mécanique :
fenêtre glissante de 5 h, **plafond hebdomadaire toutes-modèles**, plafond
hebdomadaire séparé pour Opus, pool commun à claude.ai, Claude Code, Desktop,
Cowork et Claude in Chrome. Fable 5.1 est inclus jusqu'à 50 % du plafond
hebdomadaire et « consomme plus vite » ; Opus « nettement plus » que Sonnet ;
aucun multiplicateur officiel n'est publié. L'ancre de coût relatif reste
l'API : **Sonnet 5 = 1×, Opus 5 = 2,5×, Fable 5.1 = 5×** en sortie (2/10, 5/25,
10/50 $ par million de tokens). Les sous-agents et les workflows *Ultracode*
comptent comme n'importe quelle session ; les *agent teams* coûtent ≈ 7×.

**Ce que cette étude a consommé** : un workflow de 26 agents dont 15 aboutis
(2,88 millions de tokens d'agents, 477 appels d'outils, 55 minutes) plus deux
agents de prototypage (0,68 million), presque tout en Fable 5.1 — et le plafond
hebdomadaire est tombé à 3 h du matin le 13 septembre, refusant les onze
derniers agents ; il s'est rouvert le 14 à 10 h UTC. **Une étude Ultracode
vaut donc, à elle seule, le reliquat d'une semaine de Max 20x.** À l'échelle
du chantier (26-30 sessions-journées), le forfait ne tient que si :

- 80 % des sessions tournent en **Sonnet 5 (medium/high) ou Opus 5 (high)** ;
  Fable 5.1 réservé à ISO2 et aux deux audits (≈ 15 % des sessions), lancé en
  début de semaine ;
- `CLAUDE_CODE_SUBAGENT_MODEL=sonnet` dans toutes les sessions (sinon les
  sous-agents héritent de Fable/Opus) ; pas d'*agent teams* ; **Ultracode
  en taille `small` et seulement pour l'audit d'équité** ;
- les sessions sont courtes et reprises depuis un résumé entre deux étapes
  (le cache d'une heure s'évapore après une pause ; un gros contexte se
  repaie à chaque tour) ;
- `/usage` est lu le lundi : une semaine peut se terminer le jeudi, comme
  celle-ci s'est terminée le samedi à 3 h.

Traduction honnête : **un mois de forfait pour deux à trois semaines de
chantier effectif**, si la discipline ci-dessus est tenue ; sinon des crédits
d'usage au tarif API, qui à ces volumes se chiffrent en dizaines d'euros par
session Fable.

## 7. Répartir le travail entre les sessions

### 7.1 Le principe, déjà éprouvé par le dépôt

Le partage se fait **par fichier, jamais par sujet** (`docs/JOURNAL_SESSIONS.md`,
`docs/WORKFLOW.md`) : une session = ses fichiers neufs en worktree ; les
fichiers partagés ne sont touchés que par la session qui les tient, sur
demande ; jamais de `git merge` dans la branche d'une autre session ; `grep`
de ses ancrages après toute fusion reçue ; `--import` et `grep -c` du cache de
classes après chaque fusion (les classes neuves `Presentation3D`, `CameraIso`
frapperont à chaque fois). La republication du suivi reste centralisée.

### 7.2 Les cinq sessions et leurs fichiers

| Session (nom de worktree) | Tient | Modèle | Effort | Rôle |
|---|---|---|---|---|
| **iso-pilote** | `presentation_3d.gd`, crochets dans `game_state.gd`, `main.tscn`, `ui.gd` (blocs voile/killcam/F3), `docs/ROADMAP.md`, `docs/JOURNAL_SESSIONS.md`, le suivi | Fable 5.1 pour ISO2 et les audits ; Opus 5 sinon | xhigh / high | planifie, tient les fichiers partagés, relit avant fusion, republie |
| **iso-geometrie** | `iso_geometrie.gd`, `camera_iso.gd`, `sol_projete.gdshader`, `mur_iso.gdshader`, `tools/test_iso_geometrie.gd`, `tools/test_iso_camera.gd`, `tools/banc_iso.*` | Opus 5 | high | ISO0.b, ISO1, ISO5 (entrées) |
| **iso-corps** | `voxel_corps.gd`, `voxel_catalogue.gd`, `miroir_joueur.gd`, `miroir_gadget.gd`, `corps_iso.gdshader`, leurs suites | Sonnet 5 | high | ISO3, ISO4 |
| **iso-outils** | `tools/iso_outils.gd`, ajouts à `bench_framerate.gd`, `photographe.gd`, `conditions_de_match.gd`, `test_banc.gd` (sur demande à leurs tenants) | Sonnet 5 | medium | ISO6, relevés, planches |
| **iso-assets** | `assets/iso/*`, `tools/verifie_tuilable.py`, `tools/test_iso_assets.gd`, la fiche de prompts | Sonnet 5 + Claude in Chrome (Gemini) | medium | ISO7, en série avec Adrien |

Quatre postes de réflexion à ne pas économiser : ISO0.b (le banc doit dire ce
qu'il mesure), ISO2 (les vues), le test d'équité d'ISO9, et la relecture de
chaque fusion par la pilote. Tout le reste est mécanique et se fait en Sonnet.

### 7.3 Les vagues — ce qui tourne en parallèle sans fichier commun

| Vague | En parallèle | Barrière de sortie |
|---|---|---|
| 0 | iso-geometrie : ISO0.b · iso-assets : premières planches Gemini | **H15** : relevé d'Adrien (3 exécutions, ordre base/iso/iso/base, vue unique **et** scindé) + décision go/no-go, tangage, lacet, hauteur de mur |
| 1 | iso-geometrie : ISO1 · iso-outils : banc `--iso` · iso-assets : ISO7 | ISO1 verte, fusionnée par la pilote |
| 2 | iso-pilote : ISO2 (Fable) · iso-corps : ISO3 puis ISO4 · iso-outils : ISO6 | H-ISO2 (écran scindé à deux manettes) ; H-ISO3 (planche des dix silhouettes) |
| 3 | iso-geometrie : ISO5 · iso-assets : fin d'ISO7 · (ISO8 si le relevé l'exige) | H-ISO5 : match complet manette + partie EOS à deux machines (H1 rejoué) |
| 4 | iso-pilote : ISO9 + audit Ultracode `small` | H-ISO9 : partie classée en ligne, dont le poste Windows à GPU intégré (H12) |

Gain de temps réel : les vagues 1 à 3 tiennent trois sessions occupées sans
fichier commun ; la barrière est toujours un jalon d'Adrien, pas un agent.
Deux sessions suffisent si Adrien n'est disponible qu'un jour sur deux — la
troisième n'attendrait que lui.

### 7.4 Gemini, nano banana et Claude in Chrome

« Nano Banana » désigne aujourd'hui **Nano Banana 2** (Gemini 3.1 Flash Image,
0,5K-4K, dix objets de référence) pour le volume et **Nano Banana Pro**
(Gemini 3 Pro Image, cohérence de personnages, texte) pour les planches de
référence ; Google AI Pro (21,99 €) donne « 4× » les limites gratuites, les
plafonds journaliers ne sont pas publiés (presse : ≈ 100 images/jour,
incertain). Ni fond transparent ni texture tuilable ne sont garantis : fond
vert uni + `tools/incruster_vert.py`, tuilabilité vérifiée par script. Claude in
Chrome peut enchaîner les générations mais **s'arrête sur tout CAPTCHA** et
consomme le pool Claude : une image à la fois, un onglet au premier plan, 30 s
de pause (piège du 2026-09-10, douze conversations parallèles ont bloqué le
compte deux fois). Les prompts sont en annexe B.

## 8. Le trajet par étapes — chantier ISO

Chaque étape est livrable et testable headless, porte ses fichiers créés et
ses fichiers partagés à demander, un critère « fait » et son jalon. Le détail
complet (fichiers, tests, sabotages attendus) est repris tel quel de la
conception B dans la section ISO de la ROADMAP au moment où l'étape est
ouverte, pas avant.

- **ISO0 — décider.** *Fait* : cette étude, deux prototypes, une planche de
  douze captures Three.js, dix captures Godot en `gl_compatibility`, les images
  « avant » du photographe. *Reste* (ISO0.b, 2 sessions) : un banc
  `tools/banc_iso.tscn` qui lance le vrai duel d'entraînement, retire les
  sprites de corps de `vp1` par un bit de visibilité, affiche la texture de
  `vp1` sur un plan dans la racine 3D, extrude les murs de la carte courante,
  pose deux corps grossiers qui suivent `Player1`/`Player2`, offre tangage
  (55/65/75°), lacet (0/45°), hauteur (0,3/0,45/0,7 tuile) et variante de
  lightmap, et **imprime médiane, 1 % bas, appels de dessin et taille des
  cibles** (formule de `ConditionsDeMatch.statistiques`). Aucun fichier du jeu
  touché. **Critère** : Adrien a joué trois minutes, relevé la cadence en vue
  unique et en écran scindé, et tranché par écrit (jalon H15).
- **ISO1 — fondations.** `Presentation3D` (enfant de la racine, jamais sous
  `Player*`/`GameState`), `iso_geometrie.gd` (`build_meshes` : troisième vue de
  `merge_rects(build_grid(...))`), `camera_iso.gd` (orthographique ; `size` =
  1080 × sin θ pour garder l'empreinte 1920×1080 au sol — même champ de vision
  équitable que `stretch/aspect = keep`), `sol_projete.gdshader`,
  `mur_iso.gdshader` (sommet noir, faces = lightmap au pied). Bascule
  `GameSettings.mode_iso`, désactivée par défaut ; un seul crochet après
  `rebuild_arena`. Tests : nombre de boîtes = rectangles sur les six cartes,
  déterminisme, **test d'équité géométrique** (bande masquée < 18 px ; chaque
  case de sol visible depuis la caméra, calcul analytique).
- **ISO2 — vues et canaux.** Les deux `SubViewport` 2D deviennent lightmaps
  (cull mask actuel + bit capteurs, sprites de corps hors image par
  `visibility_layer`, jamais `visible = false` que le rejeu lit) ; sous-vue
  `CapteurCorps` 256² par joueur ; racine 3D en vue unique, deux `SubViewport`
  3D en scindé ; brouillage et voile relogés. Tests : après aller-retour vue
  unique ↔ scindé ↔ 2D, monde, masques et caméra restaurés ; masques des
  capteurs miroir entre J1 et J2 ; aucun nœud 3D sous les porteurs de RPC.
  Jalon H-ISO2 : « je ne vois pas sa torche, il ne voit pas mon halo ».
- **ISO3 — corps voxel.** `voxel_catalogue.gd` (dix classes en listes de
  boîtes : casque, torse, épaules, avant-bras, arme par slug),
  `voxel_corps.gd` (un `MultiMesh` par corps), `miroir_joueur.gd` (position et
  rotation copiées en `_process` après interpolation), `corps_iso.gdshader`
  (mien = albédo × capteur ; ennemi = gris `Charte.ADVERSAIRE` × luminance du
  capteur, noir sous seuil). Tests : dix classes sans `push_error`, empreinte
  ≤ rayon 18 px + arme, ordre des portées d'armes conservé, aucun `randi`.
  Jalon H-ISO3 : lisibilité des dix silhouettes sur planche.
- **ISO4 — objets debout.** `miroir_gadget.gd` sur `child_entered_tree` :
  mine, bobine, torche fantôme, piquets du voile, plaque, cible, et le leurre
  qui reçoit le corps voxel de son poseur avec les masques de l'ennemi ; nappes
  et volumes restent à plat dans la lightmap ; viseur et ligne de visée en
  quads au sol. Tests : chaque gadget obtient (ou non) son miroir, le rejeu
  killcam aussi.
- **ISO5 — killcam, rejeu, entrées.** Fantômes mirrorés ; planche de killcam
  en `CanvasLayer` + `BackBufferCopy` au-dessus de la racine ; zoom → `size` ;
  souris = rayon caméra ∩ plan du sol → `Vector2` (repli 2D si pas de caméra
  iso) ; stick tourné du lacet. Tests : projection aller-retour < 0,5 px,
  `NetworkInputProvider` sans diff. Jalon H-ISO5 : match complet manette,
  puis partie EOS à deux machines.
- **ISO6 — outils.** Banc `--iso` (qui prouve qu'il a changé quelque chose),
  photographe (source `vue` = texture 3D, cadrages recalculés), F3, diagnostic
  F6 et `ConditionsDeMatch` (`mode_rendu`, tangage, hauteur, résolution des
  lightmaps).
- **ISO7 — direction artistique et assets.** Faces de murs (textures tuilables
  256 px, béton et encre), tranche de plateau pour les fosses, planches de
  référence des dix classes et des gadgets, illustrations iso pour l'accueil
  et les fiches — en série, fond vert. Tests : chaque texture existe, est
  connue de git, est tuilable, a ses mipmaps ; part molle < 0,25. Jalon
  H-ISO7 : la séance Gemini d'Adrien (≈ 40-60 images) et une planche validée.
- **ISO8 — option de cadence.** (a) « lumière seule » : la lightmap ne rend
  plus que des quads blancs à demi-résolution, le sol 3D porte ses propres
  textures — ou (b) « relief » : une `SpotLight3D` sans ombre par vue pour
  ombrer faces et corps par la normale, multipliée par la lightmap. À n'ouvrir
  que sur relevé.
- **ISO9 — équité et mode.** En classé, le rendu (2D ou iso) est imposé par
  l'hôte et transmis dans le salon (`Protocol.VERSION` +1) : deux joueurs d'un
  même match voient la même projection ; planche d'éblouissement rejouée en
  iso ; recensement des suites 2D devenues doubles ; ROADMAP, README,
  CLAUDE.md ; audit Ultracode `small` de l'équité. Jalon H-ISO9 : partie
  classée en ligne, dont le poste Windows à GPU intégré.

**Ce qui n'entre pas dans ce chantier** : l'éditeur reste en vue de dessus
(Unrailed 2 n'édite pas ses cartes en iso non plus) ; les vignettes restent des
plans ; le son reste en 2D ; la mise à jour du jeu installé n'est pas
concernée.

## 9. Les prototypes et les visuels

Deux prototypes ont été construits **à partir des six cartes livrées** : l'un
dans le navigateur, pour manipuler ; l'autre dans Godot 4.7 en
`gl_compatibility`, pour savoir ce que le moteur du jeu fait vraiment des
ombres. Ni l'un ni l'autre ne touche au jeu.

### 9.1 `docs/iso/proto_iso.html` — le prototype à manipuler (Three.js)

Une page autonome (Three.js r128, cartes embarquées) : on déplace J1 au
clavier, la torche suit la souris, un clic tire un flash ; quatre préréglages de
caméra (`1` à `4`), hauteur des murs, angle et portée de la torche, perspective
ou orthographie. Le décodage v3 est celui de `map_codec.gd` (vérifié contre un
décodeur indépendant : 348 murs sur `default`, 220 sur l'Arène Circulaire, 372
sur le Cloître et l'Usine, 360 sur la Croisée, 312 sur le Bunker) ; la règle
de solidité est celle de `map_geometry.gd`. Douze captures et une planche
(`docs/iso/planche_iso.jpg`) ; touches et paramètres d'URL dans
[iso/README_PROTO.md](iso/README_PROTO.md).

### 9.2 `tools/proto_iso.tscn` — le prototype dans le moteur

Une scène `Node3D` qui charge une carte par `MapCodec`, découpe murs et sol par
`MapGeometry.build_grid()` + `merge_rects()` — **les mêmes rectangles que la
physique et l'occlusion 2D** —, pose une boîte par rectangle de mur, une dalle
par rectangle de sol (rien dans les fosses : dans le jeu le vide est noir et la
lumière le traverse), deux joueurs, une `SpotLight3D` à ombres et un halo
`OmniLight3D` chacun, un flash en option, une `Camera3D` orthographique à
quatre préréglages. Arguments : `--carte=`, `--preset=`, `--pitch=`, `--yaw=`,
`--mur=`, `--torche=`, `--cible=`, `--flash`, `--capture=<png>`. Sa suite
`tools/test_proto_iso.gd` (dans `run_suites.sh`, ≈ 175 vérifications par
lot) recompte depuis les nœuds : murs + fosses + sol pavent la grille bordure
comprise, une boîte par rectangle, les dalles couvrent exactement les cases
praticables, les apparitions sont sur du sol, toutes les lumières ont
`shadow_enabled`, une seule caméra orthographique `current` cadre les huit
coins ; elle a prouvé qu'elle sait échouer (une assertion cassée → six échecs,
code 1 → remise en état, code 0). Les captures `docs/iso/captures_godot/*.png`
ont été rendues sous Xvfb avec Mesa (llvmpipe), **par le vrai chemin de rendu
`gl_compatibility` de Godot 4.7** : c'est ce qui rend les constats opposables.

| Carte | Grille | Murs | Fosses | Sol | `MeshInstance3D` |
|---|---|---|---|---|---|
| `default` | 32×32 | 4 | 4 | 1 | 9 |
| `arene_circulaire` | 24×24 | 9 | 4 | 12 | 25 |
| `map_001_le_cloitre` | 30×30 | 9 | 4 | 9 | 22 |
| `map_002_l_usine` | 32×26 | 11 | 4 | 17 | 32 |
| `map_003_la_croisee` | 28×28 | 11 | 4 | 14 | 29 |
| `map_004_le_bunker` | 26×26 | 11 | 4 | 8 | 23 |

Une carte tient en moins de trente-cinq maillages ; un cube par case en ferait
neuf cents — l'ordre de grandeur de la régression `arena_decor` (81 → 3 376
appels de dessin) qu'il ne faut pas rejouer.

### 9.3 Ce que les images apprennent

1. **Le sol Lambert efface le cône** (Godot) : avec `StandardMaterial3D`, le
   cône n'était qu'un fuseau brun ; avec `lambert` à 0 sur le sol (fonction
   `light()` sur mesure, qui fonctionne en Compatibility), il se dessine comme
   le cookie. Un portage à lumières 3D devrait tricher explicitement sur le
   sol ; B-projection n'en a pas besoin.
2. **La bande cachée** : 0,78 tuile à 52°, 1,41 à 35,26°, 0,36 à 70°, 0 de
   dessus (mur d'une tuile) ; moitié pour un mur de 0,5. À 35°, un adversaire
   collé derrière un mur côté caméra est **hors image**. L'isométrie vraie est
   exclue d'office.
3. **Les faces noires en contre-champ** (§ 5.2) : mesurées sur le Cloître,
   captures 03 et 12 du prototype Three.js, et confirmées dans Godot.
4. **Torche sous le haut du mur, sinon la règle tombe** : torche à 0,9 tuile,
   mur à 1,0 → ombre infinie (« un mur arrête la lumière ») ; torche à 1,3 →
   le dessus des murs s'allume mais l'ombre devient finie et la lumière passe
   par-dessus ; murs à 0,3 → la mécanique meurt. Les dessus de murs restent
   noirs : un mur se lit comme une dalle noire plus une face éclairée.
5. **Le halo doit ignorer l'ombre de son porteur** : `shadow_caster_mask` +
   `layers` règle le cas, vérifié à l'image — la preuve que les couches d'ombre
   de `canaux_lumiere.gd` se transposent.
6. **Huit lumières par objet** : deux torches, deux halos, deux flashs, une
   fusée, une mine et le bandeau LED font neuf ; un rectangle de mur fusionné
   est un seul objet. B-projection n'a pas ce plafond.
7. **Le flash est dramatique et honnête** : un disque de cinq tuiles autour du
   tireur, de longues ombres de piliers.
8. Lisibilité par préréglage, dans le navigateur comme dans Godot : **Unrailed
   ¾ (52°) > Dessus incliné (70°) > Dessus (90°) > Isométrie vraie**. Le
   volume des corps et leur ombre portée sont ce que la 3D apporte de plus
   parlant.

### 9.4 Réglages recommandés pour ISO0.b

| Réglage | Valeur | Pourquoi |
|---|---|---|
| Tangage | **60-65°** (52° et 70° aussi au banc, pour trancher à l'œil) | 0,2 tuile cachée pour un mur de 0,4 ; faces lisibles |
| Lacet | 0° par défaut, 45° en option | 45° rend la gêne dépendante de l'orientation des murs |
| Projection | orthographique, `size` = 1080 × sin θ | même empreinte au sol que la fenêtre logique, même image chez les deux joueurs |
| Murs | **0,4 tuile**, sommet noir strict | sous le rayon d'un corps ; la torche reste sous le haut du mur |
| Torche | inchangée (cookie 2D projeté) | c'est la lightmap |
| Ambiance | 0 | noir absolu |

### 9.5 Ce que les prototypes ne montrent pas

Aucun gadget, ni fusée, ni voile, ni brouillage, ni éblouissement, ni traînée
de balle, ni sang, ni sprite, ni HUD, ni écran scindé, ni réseau, ni killcam,
ni son. Les corps sont des cylindres, les murs des boîtes unies ; la torche
est une vraie lampe (pas le cookie) ; les ombres sont des shadow maps ; le
rendu est logiciel. **Et surtout : aucun des deux ne montre B-projection** —
c'est l'objet d'ISO0.b, dans le vrai jeu.

### 9.6 Les images « avant »

Le photographe du dépôt (`tools/run_photos.sh`, plans `duel`, `retrodiffusion`
et `plans`) a tourné sous le même Xvfb : le duel actuel en vue de dessus et les
six plans de carte sont dans l'artefact de l'étude, à côté des captures 3D.

## 10. Ce qui attend Adrien

1. **La question de fond avant le premier banc** : veut-il changer l'identité
   visuelle du duel (vue de dessus stricte, roman graphique, sprites livrés
   la semaine dernière), ou veut-il le relief d'Unrailed là où la lumière n'est
   pas une règle — accueil, fiches de classe, killcam, écran de fin, trailer ?
   La seconde option coûte trois à quatre sessions et réutilise les mêmes
   briques (géométrie, corps voxel), sans toucher au duel.
2. **Jalon H15** (après ISO0.b) : go / no-go ; tangage ; lacet ; hauteur des
   murs ; variante de lightmap ; écran scindé en iso ou maintenu en 2D. Sur
   trois relevés au premier plan.
3. **Décisions de direction artistique** : sommet des murs noir strict ou
   liseré d'arête ; tranche de plateau et gouffre ; palette des corps voxel ;
   interdiction confirmée des contours et anneaux hors killcam.
4. **Décision corps** : voxels par code (recommandé), sprites 3/4 à huit
   directions, ou `.vox` importés.
5. **Décision de mode** (ISO9) : rendu imposé par l'hôte en classé, ou réglage
   local après preuve d'équité.
6. **Ses séances** : Gemini en série (annexe B), quatre essais manette
   (H-ISO2, 3, 5, 9), trois relevés de cadence par étape décisive.
7. **Son forfait** : confirmer Max 20x dans *Settings › Usage*, lire `/usage`
   chaque lundi, décider s'il active les crédits d'usage pour les semaines
   Fable.

## Annexe A — Sources

Unrailed 2 : page Steam (app 2211170) et ses six captures officielles ;
`indoorastronaut.ch/unrailed-6-the-performance-update/` ;
`indoorastronaut.ch/godot-sponsoring/` ; notes de patch Steam
(`store.steampowered.com/news/app/2211170/`) ; dev snapshot Godot 4.4 dev 4 ;
PR godotengine/godot#106809 ; critiques NoobFeed, LadiesGamers, ChromaGlitch,
Playfront ; Unrailed 1 : `partnerships.ethz.ch` (moteur MonoGame/FNA).

Godot 4.7 : `docs.godotengine.org` — classes `Light3D`, `Decal`,
`ProjectSettings` (`rendering/limits/opengl/*`), `Camera3D`, `GridMap`,
`SpriteBase3D`, tutoriels « Renderers », « Lights and shadows », « Using
Viewports » ; PR #77496 (ombres en Compatibility), #85338
(`shadow_caster_mask`), #92287 et #120711 (caméra orthographique), #85785
(ANGLE macOS), #88199 (Metal) ; issues #90259, #100025, #81482 ; article
« Rendering priorities, September 2024 ».

Forfaits et outils : `claude.com/fr/pricing` ; `support.claude.com` (Max plan,
usage limits, Fable models on your plan, models in Claude Code, usage credits,
Claude in Chrome) ; `code.claude.com/docs` (model-config, sub-agents, desktop,
workflows, costs, chrome) ; `platform.claude.com/docs/en/about-claude/pricing` ;
`ai.google.dev/gemini-api/docs/nanobanana` ; `blog.google` (Nano Banana Pro) ;
`support.google.com/gemini` (forfaits).

Techniques : `blog.sethpyle.com` (ombres iso 2D), `connorwolf.com` (lumière
2D iso Godot 4.4), `simonschreibt.de` (Teleglitch), `cassettebeasts.com`
(« designed as if for a 2D top-down game »), `redblobgames.com/articles/visibility`.

## Annexe B — Fiche de génération Gemini (nano banana)

> Même logique que [GOOGLE_FLOW_PROMPTS.md](GOOGLE_FLOW_PROMPTS.md) : un bloc de
> style invariant en tête de chaque prompt, puis des prompts courts. Ces
> images servent à **décider** (ISO0) et, plus tard, à **produire** (ISO7).
> Elles ne remplacent aucun prototype : une image générée montre un *look*, le
> prototype montre ce que le moteur fait vraiment avec les ombres.
>
> ⚠️ **Une génération à la fois, au premier plan, 30 s de pause entre deux**
> (piège du 2026-09-10). Claude in Chrome enchaîne en série, jamais en
> parallèle, et s'arrête sur tout CAPTCHA : Adrien à portée de clic.

### B.1 — Bloc invariant de style (à coller en tête de chaque prompt)

```text
Isometric 3/4 view of a small tabletop diorama, orthographic-looking camera tilted about 60 degrees, no perspective distortion. Brutalist raw-concrete bunker arena built from clean rectangular blocks on a square grid (each block = one floor tile), walls exactly one tile thick and low (about 0.4 tile high, flat black tops), floor of large grey concrete slabs with faint grid seams, bottomless black pits. ABSOLUTE DARKNESS everywhere except what a single hand-held flashlight reveals: a warm amber (#F5B03D) cone with a warm off-white (#FAE8CC) core, hard-edged shadows cast behind walls, wall faces lit only where the floor at their base is lit, fine dust in the beam. Graphic-novel noir look, restrained palette (ink black, desaturated concrete grey, amber), heavy contrast, 80% of the frame pure black. Tiny stylised blocky low-poly figures, one tile tall. 16:9, 1920x1080, no text, no UI, no logo.
```

Prompt négatif (quand l'outil le permet) :

```text
daylight, sky, sun, global lighting, colorful, saturated greens, grass, trees, water, cute, cartoon faces, photorealistic skin, blur, depth of field, outlines glowing in the dark, text, watermark, HUD.
```

### B.2 — Les prompts d'exploration (pour choisir)

| # | Ce qu'on veut voir | Prompt (après le bloc invariant) |
|---|---|---|
| 1 | La promesse du jeu en iso | `Two figures in the arena. Figure A, foreground left, holds the flashlight: its amber cone crosses the floor, is cut clean by a wall corner and reveals figure B standing 8 tiles away, fully lit, its long shadow thrown on the concrete behind it. Everything outside the cone is black.` |
| 2 | La rétrodiffusion | `One figure shines the flashlight straight at a concrete wall two tiles away. The wall face glows amber and a soft warm bounce faintly reveals the figure itself and the floor around it. The rest of the arena is invisible.` |
| 3 | Le flash de tir | `Pitch black arena; a single muzzle flash freezes the scene for one frame: a violent white-amber point light at a pistol, illuminating the shooter, the nearest walls and a target figure across the room, with hard radial shadows behind every block.` |
| 4 | Mur bas vs mur haut (la question d'équité) | Deux générations, même scène : `walls 0.4 tile high, everything behind them visible from the camera` puis `walls two tiles high, the space directly behind each wall hidden from the camera`. |
| 5 | Le sol et la matière | `Close view of six floor tiles under the beam: poured concrete with hairline cracks, tile seams, a bullet casing and a dried blood smear, amber light raking across.` |
| 6 | La fosse | `A bottomless pit cut into the concrete floor, the flashlight beam crossing over the gap and landing on the far edge, the pit itself pure black with a thin lit rim.` |

### B.3 — Les prompts de production (ISO7)

**Textures tuilables** (fond neutre, éclairage plat — la lumière viendra du
moteur) :

```text
Seamless tileable texture, 1024x1024, top-down, flat even lighting, no shadows, no vignette: poured grey concrete slab with hairline cracks and subtle aggregate, desaturated (#5c5c57 average), suitable as a PBR albedo. Also provide a matching height map (white = raised).
```

Variantes : `wall face concrete with formwork lines`, `wall top edge, chipped`,
`pit rim, rough broken concrete`. La normale se dérive de la carte de hauteur
par un filtre de Sobel (`tools/fabrique_normales.py`, à créer, sur le patron de
`tools/incruster_vert.py`).

**Planches de référence des personnages** (pour guider le catalogue voxel) :

```text
Character sheet on a flat #00B140 green screen, three orthographic views side by side (front, side, top), same scale: a blocky low-poly figure one head wide, dark tactical clothing, holding a steel flashlight in the left hand and a pistol in the right, no face details, flat lighting, no shadows.
```

Une planche par classe (arme et gadget à la main). Le fond vert passe par
`tools/incruster_vert.py`. **Ce que Gemini ne fournit pas** : un maillage 3D,
une animation, une texture strictement raccordée à une autre. Les personnages
voxel se fabriquent en code (quelques boîtes, comme le prototype) ; les images
servent de référence de proportions et de matière, pas de ressource brute.
