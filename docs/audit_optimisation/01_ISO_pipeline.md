# 01 — ISO : la chaîne de présentation isométrique (audit d'optimisation, 2026-10-04)

Dépôt `52a29c1` (0.8.3 + SOLO S12). Lecture seule, Godot non lancé. Fichiers lus en entier : `presentation_3d.gd`, `iso_volumes.gd`,
`camera_iso.gd`, `iso_geometrie.gd`, `lumieres_iso.gd`, `miroirs_iso.gd`, `portee_ecran.gd`, `capteur_corps.gd`, `etoile_de_corps.gd`,
`echelle.gd`, `main.tscn`, `arena.tscn`, `player.tscn` ; dans `game_state.gd` les accords de vues (l. 445-475, 1617-1649, 5905-6010,
6233-6343, 6440-6466) ; dans `ui.gd` tout ce qui touche aux vues (l. 2519-2521, 8865-8890, 9326-9336) ; en renfort `peinture_iso.gd`,
`murs_bas_rendu.gd`, `settings_manager.gd`, `project.godot`, `iso_lightmap.gdshaderinc`.

**Convention.** PROUVÉ = lu dans le code (ou dans une mesure de la ROADMAP citée). ESTIMÉ = déduit du nombre d'appels / de pixels et de
mes connaissances du moteur Godot 4.x (aucune source du moteur sur cette machine : à vérifier). Aucune mesure nouvelle n'a été prise.

---

## 0. En dix lignes

1. L'iso est une **B-projection** : la vue de dessus 2D (une `SubViewport` « lightmap » par joueur regardé) reste le moteur de lumière ;
   elle est **rendue dans une texture** que le sol 3D, les faces des murs et les volumes relisent. Aucune `Light3D` en jeu
   (`lumiere_3d` faux ; `poser_lumiere_3d(true)` n'est appelée que par des outils : `tools/bench_framerate.gd:440`,
   `tools/photographe.gd:190`, `tools/banc_lumiere3d.gd:489`, `tools/test_lampe_modele.gd:109`).
2. **Vue unique** : 4 passes minimum par image (lightmap 1920×1080 + 2 capteurs 256² + racine 3D à la taille de la fenêtre, MSAA ×4),
   +1 passe 256² par gadget posé. **Écran scindé** : 9 passes minimum (2 lightmaps 957×1080, 4 capteurs, 2 `VueIso` 3D, racine).
3. Les vues cachées ne rendent pas en match (vue 2D non regardée, `VueIso` en vue unique, capteurs des vues non regardées : tous arrêtés ou
   non créés). **Exception : sous les menus, `vp1` et `vp2` repassent en `UPDATE_ALWAYS`** (ISO-07).
4. La lightmap `1080p` est **toujours 1920×1080, quelle que soit la fenêtre** : 2,25 fois les pixels de la fenêtre par défaut 1280×720 du
   build publié (ISO-01). Les relevés Mac de la ROADMAP sont pris en build debug, où `DEBUG_WINDOW_FACTOR` double la fenêtre (2560×1440).
5. Le CPU pousse **≈ 300 `set_shader_parameter` par image** (deux torches allumées, carte à murs bas, usure des murs allumée comme
   par défaut), dont les deux tiers sont des constantes ou des valeurs déjà posées ailleurs (ISO-04). `Presentation3D._process` n'est mesuré nulle part.
6. Un parcours de **tous les enfants de l'arène à chaque image** (jusqu'à ~700 nœuds de traces en fin de manche) sert à retrouver l'onde
   de mort (ISO-03).
7. Les **capteurs 256²** ne sont lus que sur 5,5 % de leurs texels (ISO-06) ; la lightmap n'est lue que sur 79 % de sa largeur (ISO-02).
8. Le coût dominant de la passe lightmap, hors périmètre ici, est la surface des **quads de torche** (carré de 936 px de monde, ~1,5 Mpx à
   ×1,5, 86 à 98 % transparent selon la classe) : voir Questions ouvertes.
9. La régression de la 0.8.0 (« portée au bord de l'écran » + rayon dans l'air) est **rattrapée dans le cloud** (Q75, Q76) ; **jamais
   remesurée sur le Mac** depuis la série du 2026-09-30.
10. Le banc de cadence chauffe 30 s : il est **aveugle, par construction, aux hoquets de premier usage** des matériaux iso (ISO-09). La
    ROADMAP a pourtant **prouvé au Mac** que ce mécanisme coûte 143 à 150 ms par première sorte de lampe 3D (l. 27616-27618) et a noté
    « préchauffer les variantes à la construction de l'arène — pas fait ici » (l. 27519-27521) ; rien d'équivalent n'existe pour les
    matériaux de jeu (faisceau, halos, quads, gadgets, onde).

---

## 1. Carte des chemins chauds

### 1.1 Schéma des passes par image (questions 1 et 2)

Fenêtre logique 1920×1080 (`canvas_items` + `keep`, `project.godot:76`). `e` = hauteur de la fenêtre / 1080. Réglages par défaut du jeu :
iso, tangage 52°, lacet 45° (option B : J2 à 225°, `settings_manager.gd:188-189`), zoom ×1,5 en vue unique et ×1,25 en écran scindé
(`settings_manager.gd:143-144`), portée de torche 468 px, lightmap `1080p` (`settings_manager.gd:223`), lumière 3D éteinte.

**A. Vue unique (en ligne, entraînement) — le mode classé**

| # | Passe | Cible | Mise à jour | Qui l'alimente |
|---|---|---|---|---|
| 1 | **Lightmap** de la vue regardée (`vp1` ou `vp2`) | `SubViewport` 1920×1080 RGBA8 = 2,07 Mpx (8,3 Mo), `size_2d_override` = 1920×1080 | `UPDATE_ALWAYS` (`game_state.gd:5922-5924`) | tout le monde 2D : sol, murs, décor, encre, LED, **toutes les Light2D** et leurs ombres, sang, douilles, particules |
| 2 | **Capteurs de corps** × 2 | `CapteurCorps` 256² chacun (`capteur_corps.gd:62,88`), disque de 32 points, zoom 2 | `UPDATE_ALWAYS` (`:90`), arrêtés au gel du kill (`presentation_3d.gd:809`) | un disque + toutes les lumières de la scène qui touchent sa fenêtre de 128×128 px de monde |
| 2b | **Capteurs d'objets** × (0 à ~4) | 256² chacun, **un par objet posé et par vue regardée** (`miroirs_iso.gd:241`) | `UPDATE_ALWAYS`, aucun arrêt hors écran | mine, ombre habitée, voile, torche fantôme, fusée posée, leurre |
| 3 | **Peinture** de la carte | `PeintureIso` ≈ cadre de la carte, 910-1190 px de côté pour les cartes livrées (3,2-5,4 Mo), plafonnée à 4096² (`peinture_iso.gd:53`) | `UPDATE_ONCE` à la demande (`:101,200`) : 0,6 rendu/s en duel (ROADMAP l. 26759) | copies non éclairées des traces |
| 4 | **Racine** | fenêtre `W×H` (3,69 Mpx à 2560×1440 ; 0,92 Mpx à 1280×720), **MSAA ×4** (`presentation_3d.gd:123,588`) | chaque image | 3D : 1 sol (quad), 4-11 boîtes de murs, 2 corps voxel (≈ 9 boîtes × 2 passes chacun), volumes, halos, quads ; puis le canevas 2D (HUD, calques d'effets) |

Passes : 4 + nombre d'objets. Les deux `VueIso` (3D) existent mais sont `UPDATE_DISABLED` et leurs `TextureRect` invisibles
(`presentation_3d.gd:1688-1694`). La vue 2D non regardée est `UPDATE_DISABLED`. La racine n'adopte plus le `World2D` du duel
(`rendu_racine_autorise = false`, `presentation_3d.gd:611`) : **le gain du chantier R (pas de cible intermédiaire) n'existe plus en iso**,
la lightmap EST la cible intermédiaire (ROADMAP l. 23834-23836 le disait dès ISO0.b).

**B. Écran scindé local (« 1v1 écrans scindés »)**

| Passe | Cible | Mise à jour |
|---|---|---|
| 2 lightmaps | 957×1080 + 958×1080 = 2,07 Mpx au total, **deux** collectes de lumières / ombres | `UPDATE_ALWAYS` |
| 4 capteurs de corps (+ 2 par objet) | 256² | `UPDATE_ALWAYS` |
| 2 `VueIso` | `(cadre × e)` : 1276×1440 + 1277×1440 à 2560×1440 (3,68 Mpx), MSAA ×4 (`presentation_3d.gd:1954`) | `UPDATE_ALWAYS` (`:1682`) ; mêmes murs / corps rendus deux fois (caméras à `cull_mask` différent) |
| racine | 2 `TextureRect` (blit 3,68 Mpx) + HUD ; **aucune Camera3D courante**, donc pas de passe 3D racine (`:1679`) | chaque image |

Passes : 9 + 2 par objet. La lumière 3D reste éteinte en scindé même demandée (`lumiere_3d_ecran_scinde` faux, `:269,1982`).

**C. Menus (iso éteinte)** : `Presentation3D` s'éteint (`:556-563`) — mais `vp1` et `vp2` repassent `UPDATE_ALWAYS`
(`game_state.gd:6464-6466`, `main.tscn:34,48`) : deux passes 2D 957×1080 sous le hub, voir ISO-07.

**D. `--2d` (débogage)** : vue unique = la racine rend le monde 2D directement (chantier R) ; scindé = deux `SubViewport`.

**Autres cibles hors écran / lectures d'écran (question 2)**

| Cible | Quand elle rend |
|---|---|
| `BackBufferCopy` `VoileBB` (`ui.gd:2620-2624`, mode VIEWPORT) | seulement si un joueur est ébloui au-delà de `aberration_debut` (`ui.gd:8878-8885`) ; coût mesuré 0,53 ms à 2560×1440 (ROADMAP l. 4317) |
| `BackBufferCopy` `CopieEcran` du brouillage (`brouillage_vue.gd:66-70`, mode RECT) | seulement pendant le flou d'éblouissement |
| `KillcamBB` (`game_state.gd:635-640`, dans le canevas de `vp1`) | killcam seulement — **en iso, il copie la lightmap pour un voile qui n'y est plus** (`presentation_3d.gd:1789` retire le voile 2D de la lightmap, pas ce nœud) ; zone franche |
| `VoileKillcamIso` (CanvasLayer, `presentation_3d.gd:1801-1814`) | killcam seulement ; relit l'écran (`killcam_overlay.gdshader`) |
| `pate_ecran_iso` / `pate_vue_iso` | `lumiere_3d` + `variante_pate_3d == 2` : jamais en jeu |
| `CuissonDecor` (`arena_decor.gd:186-206`) | une fois par carte, puis libérée ; **lit le résultat par `get_image()`** (synchro GPU) au début de manche |
| `menu_arene` | hub seulement, arrêté hors vie (`menu_arene.gd:211`) |
| textures de lumière | lightmaps (`vp1`/`vp2` `get_texture()`), `peinture`, cookies Light2D, `led_texture` ; aucune texture régénérée ni `ImageTexture.update` par image dans mes fichiers |

### 1.2 Ce que le CPU fait par image (question 3)

`Presentation3D._process` (priorité 10000, `presentation_3d.gd:463,495-523`) puis deux crochets `frame_pre_draw`.

| Poste | Fichier:ligne | Quantités (vue unique, 2 torches allumées, carte à murs bas, 0 gadget) | PROUVÉ / ESTIMÉ |
|---|---|---|---|
| `_vues_a_projeter` | `presentation_3d.gd:546-568` | 1 `get_node_or_null("/root/GameSettings")` + 3 `Object.get()` + tableau typé | PROUVÉ |
| `_tenir` | `:724-753` | par vue : `_lightmap_en_place` → `_cadre` (`get_theme_constant`, `get_global_rect`), `variante_lightmap()` ×2, `_etirement()` (`DisplayServer.window_get_size`) ; **20 `Object.get(nom)`** sur les `APPUIS_JOUEUR` | PROUVÉ |
| `_suivre` — uniformes | `:799-800, 820-824, 886-900, 1432` | **≈ 47** `set_shader_parameter` (67 en scindé) : `style` ×5 matériaux, `canevas_N_x/y/o` + `taille_N` ×5 matériaux (**20 formats `%` de noms**), `centre`, `opacite_N`/`silhouette_N` ×4 par corps, `contact_corps_N` ×4 | PROUVÉ (décompte) |
| `_suivre` — corps | `:855-901, 1356-1409` | 2 × (`etat_du_corps` : **Dictionary de 11 clés** + `VoxelCorps.poser` ~ 20 écritures de transformation) | PROUVÉ |
| `_pousser_zone_morte_capteurs` (`frame_pre_draw`) | `:763-792` | par capteur : `uniformes_de_vue` (**`PackedVector4Array(64)` + Dictionary de 10**) + 8 uniformes ; 2 capteurs (4 en scindé) | PROUVÉ |
| `GameState._pousser_zone_morte` (`frame_pre_draw`) | `game_state.gd:5979-6010` | **boucle `for pid in 2` sans tester la vue regardée** : 2 × (`uniformes_de_vue` + 2 `poser_sol` + 2 `poser_corps`) = **64 uniformes**, sauf carte sans mur bas | PROUVÉ |
| `MiroirsIso.suivre` | `miroirs_iso.gd:147-175` | 1 parcours de `bullet_container` ; par balle 2 quads (4 uniformes chacun) ; par objet ~10 uniformes | PROUVÉ |
| `IsoVolumes.suivre` | `iso_volumes.gd:409-447` | 1 parcours de `bullet_container` ; **1 parcours de `arena.get_children()`** (`:427`) ; éclats (12 uniformes), lentilles (20), faisceau ×2 | PROUVÉ |
| faisceau dans l'air, par torche | `:686-713, 854-866, 1908-1927, 2085-2125` | 3 couches + 1 juge = 4 matériaux : `_poser_couches` 27 + `_poser_longueur` 7 + `_pousser_lightmaps` 40 (6 de lightmap + 2 de contact + 2 d'usure par matériau ; 16 `get_shader_parameter`) = **≈ 74** ; ×2 torches = **≈ 148** ; **plus 4 balayages par torche du code source GLSL du shader** (`shader.code.contains`, `:2108`, 15,8 Ko chacun) | PROUVÉ (décompte) |
| `_suivre_usure` (usure des murs, **allumée par défaut** depuis Q30 = A, `iso_materiaux.gd:147-165`) | `presentation_3d.gd:521-522, 2215-2230` | `get_tree().get_nodes_in_group("wall_impact")` à chaque image (≤ 90 nœuds copiés), pose des impacts seulement au changement | PROUVÉ |
| `_decrire` → `etat` | `presentation_3d.gd:523, 1827-1852` | 3-4 `%` multi-arguments, `PackedStringArray`, `join`, `load()` + `get_script_constant_map()` (`iso_geometrie.gd:53-60`) | PROUVÉ |
| `PeintureIso._process` | `peinture_iso.gd:183-200` | 2 `get("_cuit")`, boucle des douilles en attente | PROUVÉ |
| **Total uniformes** | | **≈ 300 `set_shader_parameter` + ~75 `get_shader_parameter` + ~60 formats de noms + 8 balayages de 15,8 Ko de texte par image** | décompte PROUVÉ ; coût en µs ESTIMÉ (0,2-0,4 ms côté script) |

Temps : jamais mesuré. `bench_framerate.gd` lit `RENDER_*_MEM` mais pas `Performance.TIME_PROCESS` ; `--temps-par-vue` donne le temps CPU de
rendu par viewport (racine : 1,54 ms médian, `docs/iso/iso12/mesure_fusee_prises.csv`) et **0,00 pour le GPU sur ce Mac**.

**Matériaux distincts (regroupement).** En 3D Compatibility il n'y a pas de regroupement automatique entre `MeshInstance3D` : chaque
instance est un appel. Murs : 1 matériau et 1 `BoxMesh` partagés par toutes les boîtes (`iso_geometrie.gd:121-137`) ✔. Corps : 2
matériaux par corps (couleur + profondeur) partagés par ses ~9 boîtes (`voxel_corps.gd:899-915`), chaque boîte dessinée **deux fois**. Au
total, ESTIMÉ par lecture : **30-40 `ShaderMaterial` vivants** en duel (mur 1, sols 2, corps 4, `_mat_pate_vue` 1 inutilisé, quads du
viseur / de la ligne 4 + 2 par balle, éclats 4, lentilles 4, faisceau 4 par torche allumée, volumes de gadgets), **70-100 appels de dessin
3D**. Mesuré : 67-80 appels (tous types) en vue unique HUD caché, 141-156 en scindé (ROADMAP l. 26234), 188-198 sous une fusée
(l. 26760, `cout_de_a.md`).

**Allocations et recherches par image** : 2 `Dictionary` d'état de corps, 2-6 `PackedVector4Array(64)`, ~60 chaînes formatées, 1
`Array` typé par appel de `_materiaux()` (3-4 appels), `RandomNumberGenerator.new()` par gadget de braises (`iso_volumes.gd:615`),
`"%d:%d"` par `_entree` (6-8/image). Aucune `ImageTexture` régénérée, aucun maillage régénéré (les éventails du faisceau sont mis en
cache statique par cookie et par cran, `:812-814, 871-888`), sauf `ImmediateMesh` de l'onde de mort (0,4 s) et de la toile du voile.

### 1.3 Miroirs et portée au bord de l'écran (question 4)

**`miroirs_iso.gd` n'ajoute aucune passe 3D** ; il ajoute (a) **une passe 256² par objet posé et par vue regardée** (`:227-246`) ;
(b) 2 quads (ligne de visée, viseur) par joueur, toujours créés, visibles seulement en visée ; (c) 2 quads **et 2 `ShaderMaterial` neufs
par balle** (`:352-359, 389-399`), libérés à la mort. Le « miroir des sources » `lumieres_iso.gd` (une `Light3D` par `Light2D`) est du
**code mort en jeu** (jamais instancié sans banc).

**`portee_ecran.gd`** : calcul pur, aucun coût d'exécution (appelé par `GameSettings.accorder_au_mode` à chaque manche et par le test
`test_portee_ecran`). C'est la **règle** qu'il pose (468 px = bord le plus proche de l'écran de la vue unique) qui coûtait. Historique
mesuré (cloud, llvmpipe, scène fusée + Terrassier, rapports de temps d'image à la 0.7.1, ROADMAP l. 30489-30622, 30772-30777, 30907-30912) :

| État | cadrage du banc (×1,25) | vrai cadrage vue unique (×1,5) |
|---|---|---|
| candidat 0.8.0 (portée au coin 728 px) | 0,680 | 0,629 |
| + couches du rayon taillées en éventails | 0,739 | 0,680 |
| + Q75 (juge taillé, rayon à la longueur de la 0.7.1) | 0,930 | 0,861 |
| + **Q76 (468 px)** | **1,007** | **0,893** |

(Chaque ligne vient d'une série différente : la ROADMAP interdit de comparer d'une série à l'autre, l. 30790 ; seul le sens compte.)

Sur le Mac : une seule série (candidat 0.8.0 avant allègement : médianes 50-51 contre 60-65 pour la 0.7.1, 1 % bas 46-47 contre 50) ;
l'extrapolation « 0,88-0,95 » est écrite comme telle (l. 30616-30618). **Rien n'a été remesuré depuis Q75/Q76 sur Mac.** Reste ~11 %
d'écart à ×1,5 sous llvmpipe : le rayon dans l'air (« son juge ~72 ms, ses trois couches ~64 ms », l. 30633-30635) et les quads de torche.
Q76 a aussi **uniformisé** le coût : les dix classes portent 468 px, donc le banc `--classe=pompe` est représentatif de toutes.

### 1.4 Zoom et résolution de fenêtre (question 5)

*Zoom.* Il pilote la surface écran des lumières (∝ zoom², soit ×1,44 de ×1,25 à ×1,5), des couches du faisceau, de la fumée, et à
l'inverse le nombre de tuiles / décors / murs à parcourir (∝ 1/zoom²). Mesuré (llvmpipe, l. 30503 puis 30907-30912) : ×1,5 coûte +9 %
(portée au coin) puis **+12 %** (Qz 383,2 contre Q 342,0 ms) par rapport à ×1,25. En écran scindé les quads de torche (936 px de monde
= 1170 px à ×1,25) recouvrent déjà toute la vue de 957 px : le zoom y change peu la surface de lumière, mais la lumière est rendue
**deux fois** (une par lightmap, les deux torches voyant les deux vues). Le zoom est une règle d'équité (`valeurs_du_duel`) : aucune
proposition ici. Piège connu : le `--vue-unique` du banc joue à ×1,25 (ROADMAP l. 3659) ; il faut `--zoom=1.5`.

*Fenêtre.* En iso, la résolution de la fenêtre ne pilote **que** la passe 3D racine (fragments du sol / des murs, MSAA ×4, blit) et le
HUD ; la passe 2D est **indépendante** de la fenêtre en `1080p` et **proportionnelle** à la fenêtre en `plein`.

| Fenêtre | lightmap 1080p | lightmap plein | capteurs 2×256² | racine 3D (échantillons MSAA ×4) |
|---|---|---|---|---|
| 1280×720 (**défaut du build publié**, `project.godot:74-75`, `settings_manager.gd:789`) | 2,07 Mpx | 0,92 Mpx | 0,13 Mpx | 0,92 Mpx (3,7) |
| 1920×1080 | 2,07 | 2,07 | 0,13 | 2,07 (8,3) |
| 2560×1440 (build debug ×2, `DEBUG_WINDOW_FACTOR` : **les relevés Mac de la ROADMAP**) | 2,07 | 3,69 | 0,13 | 3,69 (14,7) |

Conséquence (pixels écrits par image hors échantillons MSAA : lightmap + capteurs + racine 3D + canevas 2D de la racine) : à 1280×720 la
lightmap pèse la moitié du total (2,07 sur 4,04 Mpx), à 2560×1440 environ un cinquième (2,07 sur 9,58). Un chiffre pris à 2560×1440 ne
dit donc rien de la fenêtre par défaut d'un joueur.

### 1.5 Chiffres connus de la ROADMAP (tous Mac M3 sauf mention)

| Poste | Valeur | Source |
|---|---|---|
| torches dans la lightmap (avant 0.8.0) | 3,65 ms / image | l. 24387 |
| seconde vue 2D, torches éteintes (août) | 1,52-1,60 ms | l. 34099, `game_state.gd:5839` |
| fusée (iso, vue unique) | 3,39 ms dont fumée 2,66 ms ; l'ombre 2D 0,09 ms | `mesure_fusee.md` |
| MSAA ×4 sur les vues iso | +0,09 à +0,21 ms | `presentation_3d.gd:119-122` |
| copie plein cadre du voile (retirée au repos) | 0,53 ms à 2560×1440 | l. 4317 |
| lumière 3D mode A (éteinte par défaut) | +2,69 ms | `cout_de_a.md` |
| peinture, rendu forcé à chaque image (1120²) | −0,37 à +1,1 ms (bruit) ; 0,6 rendu/s en duel | l. 26756-26760 |
| iso vue unique, témoin sans fusée (2026-09-23) | médiane 103-105 fps, 1 % bas 63-75 ; scindé 80/50 | l. 27629-27631, CSV |
| racine, temps CPU de rendu | 1,54 ms médian | `mesure_fusee_prises.csv` |

---

## 2. Constats

### ISO-01 — La lightmap `1080p` ne descend jamais sous 1920×1080 : 2,25 fois les pixels de la fenêtre par défaut

- **Où** : `presentation_3d.gd:933-936` (`taille_lightmap`), `:992-1007` (`_poser_lightmap`) ; `settings_manager.gd:78,223,789-790` ;
  `project.godot:74-75`.
- **Constat** :
  ```gdscript
  static func taille_lightmap(variante: String, logique: Vector2i, etirement: float) -> Vector2i:
  	if variante == "plein":
  		return Vector2i((Vector2(logique) * etirement).round())
  	return logique          # « 1080p » : l'aire logique, jamais la fenêtre
  ```
  `logique` vaut 1920×1080 en vue unique ; la fenêtre du build publié est 1280×720 (`resolution_index` 0 → `_apply_windowed(Vector2i(1280, 720))`,
  le facteur ×2 n'existant qu'en build debug, `settings_manager.gd:815`). La passe 2D rend 2,07 Mpx pour afficher une 3D de 0,92 Mpx : chaque
  texel de lightmap couvre 0,44 pixel d'écran en surface (1,2 texel par pixel en largeur utile, 1,5 en hauteur), **sans bénéfice visuel**
  (sous-échantillonnage sans mipmap) et avec le coût de toutes les lumières, tous les décors et toutes les ombres à cette taille.
- **Coût** : par image, en permanence. PROUVÉ : −55 % de pixels 2D possibles à 1280×720 (2,07 → 0,92 Mpx), −31 % à 1600×900. Le temps
  gagné n'est pas mesuré ; ESTIMÉ 1 à 2 ms sur un GPU intégré ou modeste (la passe lumières domine, l. 24387 : 3,65 ms de torches au Mac
  avant la 0.8.0). **Aucun gain sur le Mac d'Adrien en 2560×1440** (la lightmap y est plus petite que la fenêtre : 0,75 texel par pixel).
- **Proposition** : faire de `1080p` un « au plus l'aire logique » : `min(logique, pixels de la fenêtre)` par axe, c'est-à-dire basculer
  sur le chemin `plein` (déjà écrit, `_poser_lightmap` `plein` : `stretch = false`, `top_level`) quand l'étirement `e` est inférieur à 1 ;
  ou une troisième valeur `auto`. Ne rien changer au-dessus de 1080p.
- **Gain attendu** : jusqu'à −55 % des pixels de la passe 2D à la fenêtre par défaut ; nul sur la machine de référence.
- **Risque** : visuel (la lightmap passe de 1,2 / 1,5 texel par pixel à 0,8 / 1,0 : le crénelage de minification disparaît plutôt qu'il n'apparaît ;
  l'art des tuiles est vu à la densité de la fenêtre) ; réglage persisté `iso_lightmap` et ses deux boutons (`LIGHTMAPS_ISO`) ;
  tests `test_iso_vues`, `test_banc` (tailles de lightmap), `test_iso_camera` ; ne touche ni l'équité ni le réseau.
- **Effort** : S à M.
- **Sévérité** : MAJEUR hors machine de référence (la fenêtre par défaut d'un joueur), MINEUR sur le Mac d'Adrien.
- **Statut ROADMAP** : CONNU-OUVERT pour la taille de lightmap (l. 25315 : « la plus petite lightmap qui tient l'aspect… » ; l. 26285-26287 :
  « la pleine résolution par défaut reste la question d'Adrien ») ; l'angle « plafonner à la fenêtre » est NOUVEAU (la discussion n'a
  porté que sur plus grand).
- **Vérifier** : build exporté (pas le build debug) à 1280×720 : `bench_framerate.tscn -- --iso --vue-unique --zoom=1.5 --lightmap 1080p`
  contre `--lightmap plein`, 60 s, `--temps-par-vue` ; F3 affiche la taille de chaque lightmap et le rendu (`_decrire`). Le gain GPU ne se
  lit pas dans `--temps-par-vue` (GPU = 0,00 sur Mac) : comparer médiane et 1 % bas.

### ISO-02 — 21 % des colonnes de la lightmap ne sont jamais échantillonnées par la caméra iso

- **Où** : `camera_iso.gd:93-101` ; `presentation_3d.gd:1004` (`vue.size_2d_override = logique`).
- **Constat** :
  ```gdscript
  static func empreinte_au_sol(tangage: float, vue: Vector2) -> Vector2:
  	var taille := taille_orthographique(tangage, vue.y)          # vue.y × sin θ
  	return Vector2(taille * vue.x / vue.y, taille / sin(deg_to_rad(tangage)))   # largeur = vue.x × sin θ
  ```
  À 52° la caméra garde la profondeur de la vue de dessus et montre `1920 × sin 52° = 1513` px de large pour une lightmap de 1920 (en
  écran scindé : 754 pour 957). PROUVÉ : `sin 52° = 0,788`, donc 21,2 % des colonnes (2 × 203 px logiques, quel que soit le zoom) ne sont
  lues par aucun fragment ; l'en-tête de `camera_iso.gd` le dit (« l'iso voit MOINS large ») sans en tirer la conséquence sur la lightmap.
- **Coût** : par image. **Borné par ce qui est rastérisé hors bande** : sol, décor, murs et LED sont rastérisés sur toute la largeur ;
  mais les quads de torche (936 px de monde = 1404 px logiques à ×1,5) tiennent dans la bande utile de 1513 px : ils ne rétrécissent
  presque pas (≤ 8 % quand la caméra est avancée vers la visée). Le gain porte donc surtout sur la passe de base, la LED et les halos,
  pas sur les torches. ESTIMÉ ≤ 0,3 ms ; non mesuré.
- **Proposition** : rogner la **largeur** de la lightmap à l'empreinte + marge (`vue.size = size_2d_override = (ceil(vue.x × sin θ) + 2×16, 1080)`),
  centrée sur la même caméra 2D. **Pas** d'écrasement anamorphique : horizontalement l'écran est déjà 1,27 fois plus dense que la lightmap.
  Condition : les lecteurs de `get_visible_rect()` (`game_state.gd:452` regard / bornes de carte, `:2292` killcam, `player.gd:3142` cadrage
  du rectangle visible de la caméra, `brouillage_vue.gd:259`) doivent continuer à lire 1920×1080 logiques, sans quoi le cadrage près des
  bords change.
- **Gain attendu** : ≤ 0,3 ms (ESTIMÉ) ; plus si Adrien réduit aussi les carrés de torche (voir Questions ouvertes).
- **Risque** : cadrage (`RegardDuel.centre_du_regard` borne la caméra à une tuile de hors-carte avec la largeur de la vue 2D : la borne
  bougerait de ~135 px à ×1,5 près des murs est / ouest — c'est une règle de champ de vision, donc à trancher par Adrien) ; uniformes
  `taille_N` des 12 shaders ; marge pour les faces de murs en bord d'écran ; `test_iso_camera`, `test_iso_vues`.
- **Effort** : M.
- **Sévérité** : MINEUR.
- **Statut ROADMAP** : NOUVEAU (la largeur « 1513 px à 52° » est actée, l. 23969, mais pas son effet sur la taille de la lightmap).
- **Vérifier** : `banc_iso.gd` (captures avant / après au pixel dans la bande utile), `test_iso_camera`, `test_iso_vues`, puis cadence.

### ISO-03 — Un parcours de tous les enfants de l'arène, à chaque image, pour retrouver l'onde de mort

- **Où** : `iso_volumes.gd:425-429` ; sources des nœuds : `bullet_casing.gd:19,42,169`, `blood_stain.gd:37,528`, `wall_impact.gd:45,165`,
  `footprint.gd:80,119` ; onde créée `game_state.gd:4546-4549`.
- **Constat** :
  ```gdscript
  var arene := main.get("arena") as Node
  if arene != null:
  	for noeud in arene.get_children():
  		if noeud.get_script() == OndeDeMort:
  			_suivre_onde(noeud as Node2D, vus)
  ```
  Douilles, taches de sang, éclats de mur et empreintes sont **enfants directs de l'arène**, avec leur copie J2 (`get_parent().add_child`) :
  plafonds 120 + 120 + 90, doublés par les copies = jusqu'à ~660 nœuds, et ils **persistent d'une manche à l'autre** contre le même
  adversaire (`GROUPES_DES_TRACES`, `game_state.gd:1330`). Le parcours copie le tableau d'enfants (`get_children()`) puis appelle `get_script()`
  sur chacun, 60 fois par seconde, pour un nœud qui n'existe que 0,4 s par manche.
- **Coût** : chaque image, croissant avec la manche. PROUVÉ : O(n), n ≤ ~700. ESTIMÉ 0,1-0,25 ms à saturation (≈ 0,25 µs par nœud + copie
  du tableau) ; non mesuré.
- **Proposition** : `KillShockwave` s'inscrit dans un groupe (ou `GameState` garde la référence de `shock`, créée à un seul endroit),
  `IsoVolumes` lit ce groupe / cette référence. `get_nodes_in_group("onde_de_mort")` ne coûte que la taille du groupe (0 ou 1).
- **Gain attendu** : 0,1-0,25 ms en fin de manche, ESTIMÉ.
- **Risque** : nul pour l'équité ; le `NOTIFICATION_PREDELETE` / `queue_free` de l'onde doit la sortir du groupe (c'est automatique) ;
  `test_iso_gadgets` pose l'onde.
- **Effort** : S.
- **Sévérité** : MINEUR.
- **Statut ROADMAP** : NOUVEAU.
- **Vérifier** : micro-banc `--script` : 700 `Node2D` enfants d'un nœud, chronométrer la boucle ; ou `Performance.TIME_PROCESS` en fin de
  manche chargée (tirs soutenus au pompe) avant / après.

### ISO-04 — ≈ 300 `set_shader_parameter` par image, dont les deux tiers sont des constantes ou des valeurs déjà posées, et un balayage de 126 Ko de texte

- **Où** : `presentation_3d.gd:799-800` (`style`), `:820-824` (`canevas_N_x/y/o`, `taille_N` ×5 matériaux), `:626-628` (`lumiere_N` posés
  une fois à l'allumage) ; `iso_volumes.gd:2119-2125` (`lumiere_N`, `canevas`, `taille`, `style` à chaque image sur chaque matériau de
  volume), `:2105-2110` (`contact_corps_*` : 2 `get` + 2 `set` par matériau, valeurs que `_poser_contact` vient de calculer ; puis, l'usure
  étant allumée, le test `shader.code.contains("#define USURE_ESSAI\n")` et la recopie de `usure_impacts` — un `PackedVector4Array` de 48
  éléments — à chaque image), `:861-862`
  (`fondu_air` constant 0,25, `longueur_air`), `:1923` (`masque`, `avec_masque` constants par lampe) ; `presentation_3d.gd:2098-2125`
  (`style` sur `_mat_pate_vue`, matériau jamais dessiné).
- **Constat** :
  ```gdscript
  for m in _materiaux():
  	m.set_shader_parameter("style", style_pate)                    # change seulement à une touche de débogage
  ...
  for m in _materiaux():
  	m.set_shader_parameter("canevas_%d_x" % n, canevas.x)          # 3 formats de nom + 1 pour taille, ×5 matériaux
  	m.set_shader_parameter("taille_%d" % n, taille)                 # constante tant que la fenêtre ne change pas
  ```
  Décompte (§ 1.2) : ≈ 47 dans `_suivre`, ≈ 148 dans le faisceau (deux torches), ≈ 32 éclats + lentilles, 16 capteurs, 64 zone morte.
  Constantes ou redondantes : `style` (5 + 8), `taille_N`, `lumiere_N` (textures, 8-12 matériaux), `fondu_air`, `masque`, `avec_masque`,
  `contact_corps_*`, `usure_impacts*` (qui ne change qu'à l'arrivée d'un éclat) : environ 200 sur 300. Et :
  ```gdscript
  if mur != null and (m as ShaderMaterial).shader.code.contains("#define USURE_ESSAI\n"):   # iso_volumes.gd:2108
  ```
  relit à chaque image le texte du shader (`volume_iso.gdshader` : 15,8 Ko avant ses `#include`) de chacun des 4 matériaux de chaque
  faisceau allumé — la réponse est fixée à la création du matériau.
- **Coût** : chaque image. PROUVÉ : le décompte. ESTIMÉ : 0,15-0,3 ms de script (0,4-0,8 µs par appel avec conversion de nom) et
  0,05-0,13 ms pour le balayage de texte (8 × 15,8 Ko à ~1 octet / ns) ; plus le
  côté moteur : à chaque appel le matériau est marqué à mettre à jour, et en fin d'image son tampon d'uniformes est réécrit (pas de test
  d'égalité de valeur à ma connaissance) — ≈ 25 matériaux touchés par image ; les paramètres **texture** (`lumiere_N`, `masque`) forcent en
  outre la résolution des échantillonneurs. Non vérifiable ici.
- **Proposition**, du plus simple au plus profond : (0) retenir à la création de chaque matériau de volume s'il porte `USURE_ESSAI`
  (`e["usure"]`) et ne recopier `usure_impacts*` que quand `Presentation3D._usure_empreinte` change ; (1) poser les constantes **à la
  création / au changement** (`style` dans un setter,
  `taille_N` dans `_poser_lightmap`, `lumiere_N` à la création du matériau, `fondu_air` à la naissance de la couche) ; (2) supprimer les
  poussées sur des matériaux jamais dessinés (`_mat_pate_vue`) ; (3) ne recopier `contact_corps_*` qu'une fois (depuis `_poser_contact`)
  vers la liste des matériaux de volume ; (4) option M : `iso_lightmap.gdshaderinc` (90 lignes, **le seul endroit** qui déclare
  `canevas_N_*`, `taille_N`, `lumiere_N`, inclus par 12 shaders) passerait ces `vec2` en `global uniform`, mis à jour une fois par vue et
  par image — à vérifier : support des `sampler2D` globaux en Compatibility (les `vec2` ne posent pas de doute).
- **Gain attendu** : 0,2-0,5 ms de fil principal, ESTIMÉ ; utile surtout au 1 % bas si le fil principal est le goulot (inconnu).
- **Risque** : gardes **textuelles** qui lisent `presentation_3d.gd` : `test_corps_mannequin.gd:156-157` compte exactement 2 occurrences de
  la boucle `for m in [_mat_corps[j], _mat_profondeur[j], (_mat_corps[j] as ShaderMaterial).next_pass]:` et `:375-376` des chaînes
  exactes ; `test_banc.gd:289-300` exige l'ordre `_lumieres.call("suivre"…)` < `_accorder_le_relief()` < `_accorder_la_led()`. Les
  tests `test_iso_gadgets.gd:381,395,1128` et `test_fumee_voxel.gd:548` lisent `canevas_1_x` sur les matériaux (l'option 4 les casse).
  Ne pas toucher à la valeur poussée : une constante posée une fois doit être reposée si le matériau est recréé (changement de classe,
  `_accorder_le_slug`), piège déjà payé (« Q39 (2) », `presentation_3d.gd:1321-1327`).
- **Effort** : S (1 à 3), M (4).
- **Sévérité** : MINEUR.
- **Statut ROADMAP** : NOUVEAU (seul `set_shader_parameter` sur un nom inconnu est consigné, l. 4036).
- **Vérifier** : compteur d'appels (envelopper `set_shader_parameter` dans un banc) puis `Time.get_ticks_usec()` autour de
  `Presentation3D._process` et `IsoVolumes.suivre` ; `Performance.TIME_PROCESS`.

### ISO-05 — La zone morte des murs bas est poussée pour une vue non regardée et pour des sprites qui ne sont pas dessinés

- **Où** : `game_state.gd:5979-6010` ; `murs_bas_rendu.gd:128-160, 176-187` ; `presentation_3d.gd:763-792`.
- **Constat** : la boucle `for pid in 2:` ne teste jamais si la vue de `pid` est regardée. En iso vue unique, la vue de l'autre joueur est
  `UPDATE_DISABLED` : `_viewport_du_monde(pid)` retombe sur sa `SubViewport` arrêtée, et `poser_sol` y pousse 2 matériaux (sol, décor)
  que personne ne dessine. De plus, `poser_corps(moi.visual.material…)` et `poser_corps(autre.visual_enemy.material…)` visent des sprites
  que la vue iso a sortis de toute lightmap (`APPUIS_JOUEUR`, `presentation_3d.gd:173-175`, couche 0) : **4 des 8 `poser_*`** sont du
  travail pour rien dans tous les cas, 6 de 8 en vue unique. Chaque `uniformes_de_vue` alloue un `PackedVector4Array` redimensionné à
  `MURS_MAX = 64` (`:149`) et un Dictionary de 10 clés ; `_pousser_zone_morte_capteurs` en refait un par capteur (2 à 4).
- **Coût** : chaque image sur les cartes à murs bas (sinon `_zone_morte_vide_poussee` coupe, `game_state.gd:5982-5985`). PROUVÉ : ≈ 48
  uniformes et 1 `uniformes_de_vue` sur 2 inutiles en vue unique ; 2 à 6 tableaux de 1 Ko alloués par image. ESTIMÉ < 0,1 ms.
- **Proposition** : sauter le `pid` dont `Presentation3D.parent_ecran(pid) == null` et dont le conteneur n'est pas visible ; ne pas pousser
  `poser_corps` sur `visual` / `visual_enemy` quand la vue iso tient (`Presentation3D.instance() != null`) ; mettre en cache
  `uniformes_de_vue` par transformation (recalculé seulement si `ecran * arene.global_transform` ou `murs_bas` change) ; poser les
  matériaux de capteur dans la même boucle.
- **Gain attendu** : ~50 appels et 3-4 allocations par image, ESTIMÉ < 0,1 ms.
- **Risque** : une vue qui se rallume (killcam, retour d'écran scindé) doit être repoussée avant son premier rendu — `frame_pre_draw` le
  fait déjà à chaque image tant que la vue est regardée ; `test_iso_murs_bas` lit peut-être les uniformes des sprites (à vérifier).
- **Effort** : S.
- **Sévérité** : MINEUR.
- **Statut ROADMAP** : NOUVEAU.
- **Vérifier** : `tools/test_iso_murs_bas.gd`, `banc_murs_bas.gd` ; compteur d'appels.

### ISO-06 — Capteurs 256² : 5,5 % des texels lus ; capteurs d'objets jamais arrêtés hors écran

- **Où** : `capteur_corps.gd:62-63,88-90,100` ; `corps_iso.gdshader:212-216` ; `miroirs_iso.gd:241-246` ; comparer `presentation_3d.gd:1197-1200`
  (les figurants s'arrêtent hors portée).
- **Constat** : `uv = 0.5 + decalage_px / monde_capteur_px` avec `decalage_px` plafonné à `rayon_lu_px` = 15 px et `monde_capteur_px` = 128 :
  le corps ne lit que `|uv − 0,5| ≤ 0,117`, soit 60×60 texels sur 256×256 (**5,5 %**) ; les objets lisent `≤ 15 px` aussi
  (`miroirs_iso.gd:220`). Le reste du tampon (rendu, effacé, échantillonné nulle part) est du remplissage pour rien. Aucune passe de
  capteur ne s'arrête : `UPDATE_ALWAYS` posé à la création, même pour un objet à 800 px du joueur, hors du rectangle de la vue.
- **Coût** : 2 à ~6 passes par image en vue unique, 4 à ~10 en écran scindé. Chaque passe = changement de cible (sur un GPU à tuiles,
  le vidage de tuiles est le coût que le chantier R a mesuré à +15 %, l. 17192-17198) + collecte des lumières et **mise à jour de la
  carte d'ombre de chaque torche qui touche la fenêtre** (le recensement de l'ombre « 64 sur 80 pour rien » ne pèse que ~0,14 ms,
  l. 28301-28308, tous viewports confondus). ESTIMÉ ≤ 0,3 ms ; non mesuré.
- **Proposition** : (a) `TAILLE = 128` et `MONDE_PX = 64` (même 2 texels / pixel de monde, fenêtre de ±32 px ≥ 15 px de lecture + 2 px
  de bilinéaire) : le remplissage tombe à ¼ ; les constantes sont dérivées partout (`monde_capteur_px` posé depuis `MONDE_PX`,
  `definir_capteur`, bancs `TAILLE / MONDE_PX`) ; (b) reprendre pour les objets la règle des figurants : `UPDATE_DISABLED` quand
  l'objet est à plus de la demi-diagonale de la vue + marge (≈ 1000 px), réarmé avant le premier rendu où il redevient visible ;
  (c) en option, un capteur d'objet statique sans lumière mobile à proximité peut se rendre une image sur deux.
- **Gain attendu** : ≤ 0,3 ms, ESTIMÉ ; surtout en écran scindé et avec gadgets.
- **Risque** : **équité de lecture de la lumière** (c'est la pièce qui fait « ce que l'écran montre est ce que l'hôte fait payer ») :
  `tools/banc_iso.gd --canaux`, `test_ombre_propre`, `test_iso_vues`, `test_iso_objets` à rejouer ; latence d'une image au
  réarmement. `test_habillage.gd:720` teste une texture 256² sans rapport (portrait).
- **Effort** : S (a), S-M (b).
- **Sévérité** : MINEUR.
- **Statut ROADMAP** : NOUVEAU ; le coût de « un capteur 256² par PNJ » est signalé non mesuré (l. 32771, 33729).
- **Vérifier** : banc canaux + `bench_framerate --iso --gadgets --temps-par-vue` (CPU par viewport : un capteur apparaît comme un viewport).

### ISO-07 — Sous les menus, les deux vues 2D rendent chacune l'arène (957×1080) derrière le hub

- **Où** : `game_state.gd:6464-6466` ; `main.tscn:34,48` (`render_target_update_mode = 4`) ; `presentation_3d.gd:556-563` ;
  `ui.gd:9001-9037` (`show_main_menu` ne touche pas aux vues).
- **Constat** : au retour au menu, `vp1.get_parent().show(); vp2.get_parent().show(); _accorder_rendu_aux_vues()` → deux conteneurs
  visibles → `vu = true` pour les deux → deux `SubViewport` en `UPDATE_ALWAYS` (au lancement du jeu, le défaut de la scène est identique). La
  vue iso est éteinte, l'arène (sol, murs, LED, joueurs) est rendue dans deux textures que le hub (fond shader indépendant,
  `menu_backdrop.gd`, aperçu propre `menu_arene.gd`) ne montre pas. Le commentaire de `:6440-6451` le sait : « le `Background` noir
  opaque recouvrait l'arène ; c'était juste par accident ».
- **Coût** : tant que le joueur est dans les menus. ESTIMÉ ~1,5 ms par vue d'après la décomposition d'août (1,52-1,60 ms pour la seconde
  vue 2D, l. 34099) ; **non isolé** : les 200 fps du banc `--menus` (l. 34280) incluent ces deux passes (le banc n'arrête pas les vues,
  `bench_framerate.gd:485-520`). Aucune incidence sur le duel ; énergie et chaleur sur ordinateur portable avec fps déplafonnés.
- **Proposition** : `UPDATE_DISABLED` sur `vp1`/`vp2` tant que `_is_main_menu`, rétabli par `_restore_viewports` / `_accorder_rendu_aux_vues`
  au départ de manche (le chemin existe déjà pour l'entraînement et l'en-ligne).
- **Gain attendu** : ~3 ms par image au menu, ESTIMÉ ; 0 en match.
- **Risque** : à vérifier que le hub est bien opaque dans tous ses écrans (galerie, fiche de classe, paramètres) ; la killcam, le
  `Background` et le départ de manche rappellent l'accord.
- **Effort** : S.
- **Sévérité** : MINEUR (menus).
- **Statut ROADMAP** : NOUVEAU.
- **Vérifier** : `bench_framerate.tscn -- --menus` avant / après (médiane, pas le 1 % bas : l. 34329-34341), `--temps-par-vue` en menu.

### ISO-08 — Peinture : toutes les traces recopiées à chaque manche, repeinte entière à chaque trace, non bornée sur les grandes cartes

- **Où** : `peinture_iso.gd:79-102, 156-159, 183-200, 228-232, 260-280` ; `presentation_3d.gd:516-518, 1059-1076`.
- **Constat** : à chaque `rebuild_arena` (`Presentation3D.accrocher` pose `_reconstruire`), `_poser_peinture()` crée une `PeintureIso` neuve dont
  `_ready` appelle `_examiner` sur **toutes** les traces vivantes (jusqu'à ~330 originaux) ; `_copier` fait `duplicate()` puis boucle
  `source.get_property_list()` (~80-100 dictionnaires) pour recopier les variables de script. Chaque nouvelle trace relance un
  `UPDATE_ONCE` qui redessine **toutes** les copies. La taille est plafonnée à 4096² (`COTE_MAX`, 16,8 Mpx, ~64 Mo) pour les cartes jusqu'à
  128×128 cases (`MapCodec.MAX_GRID`).
- **Coût** : (a) début de manche : PROUVÉ O(traces × propriétés) ; ESTIMÉ 10-20 ms de fil principal avec ~330 traces (série de plusieurs
  manches contre le même adversaire), moment où `GameState` reconstruit déjà l'arène (décompte) ; (b) par trace : MESURÉ négligeable sur
  les cartes livrées (1120² : « −0,37 à +1,1 ms, dans le bruit » et 0,6 rendu/s, l. 26756-26760) ; **non mesuré** sur une grande carte
  (13× plus de pixels par rendu). Le décor cuit `CuissonDecor` (`arena_decor.gd:186-206`, `get_image()` synchrone, jamais plafonné : 4550²
  pour une carte 128²) relève du même constat, côté carte.
- **Proposition** : (a) ne recopier au début de manche que les traces absentes (garder la peinture si la carte et la rencontre sont
  les mêmes : `_rencontre_des_traces`, `game_state.gd:1334`) ; (b) pour les grandes cartes, peindre incrémentalement
  (`render_target_clear_mode = CLEAR_MODE_NEVER`, ne dessiner que la copie neuve, repeindre tout seulement à l'éviction).
- **Gain attendu** : 10-20 ms de hoquet de début de manche, ESTIMÉ ; borne le pire cas des cartes énormes.
- **Risque** : la peinture périmée est un piège déjà payé (RAPPORT `peinture-perimee`, `presentation_3d.gd:509-515` : « les murs ET la
  peinture, toujours ensemble ») ; toute optimisation doit rester sous `banc_peinture_en_ligne` et `test_iso_peinture_carte`.
- **Effort** : M.
- **Sévérité** : MINEUR (cartes livrées) ; potentiellement plus sur les grandes cartes joueur.
- **Statut ROADMAP** : DÉJÀ-TRANCHÉ pour le rendu par trace sur les cartes livrées (l. 26756-26760) ; NOUVEAU pour la recopie par manche
  et les grandes cartes.
- **Vérifier** : la ligne « [iso] peinture retirée : N rendus en X s » (`peinture_iso.gd:168`) dans un journal de vraie partie ; un banc
  qui monte une carte 128×128 et tire.

### ISO-09 — Aucun shader ni variante iso n'est préchauffé par un dessin ; le banc ne peut pas le voir

- **Où** : `iso_volumes.gd:1741-1798, 1851-1861` (variantes créées à la première couche) ; `iso_materiaux.gd:118-129` (`Shader.new()` +
  `code =` à la volée, mis en cache) ; `miroirs_iso.gd:26-28` (`quad_iso_additif`, `capteur_objet`) ; `iso_nuage_voxel.gd:306-323`
  (`prechauffer` : charge le `Shader` et réduit des textures, ne dessine rien — son commentaire `:303-305` le dit : « le shader, lui, se
  COMPILE à son premier dessin, dans le pilote : ce coût-là n'est pas pris ici ») ; modèle de la bonne pratique : `fusee.gd:337-362`
  (« un quad invisible dessiné une image ») appelée par `game_state.gd:1565` ; `tools/bench_framerate.gd:88` (chauffe de 30 s),
  `:137-140,446-451,727-753` (`--chauffe-couverture` : couvre la seule lumière 3D, éteinte en jeu).
- **Constat** : la doctrine du dépôt est écrite (CLAUDE.md : « un `Shader.new()` à la volée compile au premier mort » ;
  `game_state.gd:1562-1565`), mais n'est appliquée qu'au voile de la fusée 2D (et, pour la fumée en voxels, aux textures et au chargement
  du `Shader`, pas à son dessin). En iso, la première torche allumée d'un processus crée en chaîne jusqu'à 8 objets `Shader` par
  `variante_definie` (`FUMEE_MASQUE`, `USURE_ESSAI` — allumée par défaut —, jusqu'à cinq `#define` de forme, `DEFINES_FORMES`
  `iso_volumes.gd:229-233`, puis `FAISCEAU_LUMINEUX`), chacun un `Shader.new()` + `code =` sur le code entier du shader de volume ; le
  dernier (et celui du juge) est seul dessiné, donc seul compilé par le pilote, au premier dessin. La torche est **tenue par une touche**
  (`player.gd:1814`), donc ce premier allumage tombe en pleine partie. Même chose, au premier événement : première balle
  (`quad_iso_additif`), premier éclat de bouche et première lentille (`halo_iso`), premier gadget (`capteur_objet`, voxels d'objets),
  première mort (`quad_iso` de l'onde). `preload` charge la ressource ; le programme GL se compile au premier dessin (Compatibility,
  synchrone — connaissance du moteur, non vérifiée ici).
  **Ce que la ROADMAP a déjà établi sur la même mécanique** (lumière 3D, éteinte en jeu) : l. 27616-27618, « les hoquets de 143 à 150 ms
  sont des COMPILATIONS au premier allumage d'une sorte de lampe » ; en écran scindé, « des hoquets de 132 à 138 ms à 28 et 46 s, loin de
  tout premier allumage — chaque vue a SES matériaux, et la chauffe ne couvre que ceux de la vue de J1 » ; l. 27519-27521, « il faudra
  préchauffer les variantes à la construction de l'arène (noté pour le plan des lots, pas fait ici) ». Le banc a reçu
  `--chauffe-couverture` pour cette seule lumière ; les matériaux de jeu n'ont rien d'équivalent.
- **Coût** : une fois par processus et par sorte, au moment de l'action. **PROUVÉ** (ROADMAP l. 27616-27618, Mac) : 143 à 150 ms par
  première sorte de lampe 3D. **Non mesuré** sur les matériaux de jeu : aucun outil ne les mesure (le banc chauffe 30 s avant de
  chronométrer, le 1 % bas imprimé est « hors transitoire » ; `premiers_allumages` ne couvre que les `Light3D`), et le commentaire de
  `iso_nuage_voxel.gd:303-305` avoue ne pas avoir pris ce coût pour la fumée. ESTIMÉ, par analogie seulement : le même ordre (la centaine
  de ms) si un programme de taille comparable se compile au premier dessin.
- **Proposition** : pendant le hub ou le décompte, dessiner une fois chaque matériau iso dans un `SubViewport` 1×1 `UPDATE_ONCE`
  (patron de `Fusee.prechauffer`) : faisceau (3 couches + juge), halo / halo mélange, quad / quad additif, capteur d'objet, volume de gadget,
  onde — pour LES DEUX vues en écran scindé (la ROADMAP a vu « chaque vue a SES matériaux », l. 27618). Et créer les variantes du
  faisceau dans `IsoVolumes._init` comme `IsoNuageVoxel.prechauffer()`.
- **Gain attendu** : supprime d'éventuels hoquets de premier usage ; non quantifiable avant mesure (la ROADMAP en a prouvé de 143 à
  150 ms sur la lumière 3D, qu'une chauffe par couverture a fait disparaître : « plus aucun hoquet au-dessus de 50 ms dans 19 relevés sur
  20 », l. 27639).
- **Risque** : faible (une image de plus au chargement) ; ne pas créer de nœud porteur de RPC ; vérifier que le dessin de chauffe
  active bien la même variante que le dessin réel (c'est le piège que le commentaire de `fusee.gd:337-342` écarte pour son voile).
- **Effort** : S à M.
- **Sévérité** : MAJEUR sous réserve de mesure — c'est le seul constat de ce rapport qui puisse produire une image de plus de 100 ms dans
  une partie par défaut, pile sur l'action décisive (le « piège du premier mort » de CLAUDE.md) ; mais l'ampleur sur les matériaux de jeu
  n'est pas mesurée (MINEUR si la mesure la trouve imperceptible).
- **Statut ROADMAP** : CONNU-OUVERT pour la lumière 3D (l. 27519-27521 « noté pour le plan des lots, pas fait ici » ; l. 27616-27618 la
  preuve ; éteinte en jeu) ; NOUVEAU pour les matériaux iso de jeu (faisceau, halos, quads, gadgets, onde) : la doctrine est CONNUE et
  DÉJÀ-TRANCHÉE ailleurs (CLAUDE.md, `fusee.gd:337`), son application à l'iso de jeu est inédite.
- **Vérifier** : processus neuf, aucune chauffe, `bench_framerate --iso --vue-unique --seuil-lent 20` en n'allumant la torche qu'à la
  seconde 5, ou journal d'une vraie partie avec une prise de temps par image autour du premier allumage / premier tir / première mort.

### ISO-10 — `Presentation3D._process` recompose le texte du panneau F3 à chaque image

- **Où** : `presentation_3d.gd:523` (`etat = _decrire(voulues)`), `:1827-1852` (`_decrire`) ; `iso_geometrie.gd:53-60` ; lecteurs : `ui.gd:1917`
  (F3, fenêtre de diagnostic), `tools/banc_iso.gd:857`, `bench_framerate.gd:1201`.
- **Constat** : `_decrire` formate 1 + 2 par vue chaînes multi-arguments, construit un `PackedStringArray`, un `join`, appelle
  `variante_lightmap()` (recherche de nœud `/root/GameSettings`), `texels_par_pixel`, `tuile_a_l_ecran`, et — par
  `str(IsoGeometrie.hauteur_mur_haut())` — `load("res://map_geometry.gd")` puis `get_script_constant_map()` (Dictionary de 16 constantes
  reconstruit à chaque appel). Seul F3 et les bancs lisent `etat`.
- **Coût** : chaque image. ESTIMÉ 10-30 µs ; non mesuré.
- **Proposition** : transformer `etat` en méthode paresseuse (`etat_texte()`), appelée par F3 et les bancs, ou recalculer à 2 Hz ; mettre
  `hauteur_mur_haut()` en cache statique.
- **Gain attendu** : 10-30 µs par image.
- **Risque** : trois lecteurs de `.etat` à adapter ; `test_banc` lit des chaînes de `presentation_3d.gd`.
- **Effort** : S.
- **Sévérité** : ANECDOTIQUE.
- **Statut ROADMAP** : NOUVEAU.
- **Vérifier** : F3 ouvert / fermé, `Time.get_ticks_usec()` autour de `_decrire`.

### ISO-11 — Propretés : ligne fusionnée en milieu de `_suivre`, registre `_couches` qui grossit

- **Où** : `presentation_3d.gd:911` ; `miroirs_iso.gd:366-367, 374-375, 433-439, 445-448`.
- **Constat** : la ligne 911 fusionne le commentaire de documentation de `variante_lightmap()` et le commentaire du bloc « ISO4 — les miroirs »
  (`…sinon le réglage du joueur.<TAB># ISO4 — les miroirs, après les corps…`, import du 2026-10-02). Les lignes 912-923 (`_miroirs.suivre`,
  `_lumieres.call("suivre")`, `_accorder_le_relief`, `_accorder_la_led`, `_accorder_la_pate_ecran`) sont **la fin de `_suivre()`**, posée
  sous l'en-tête de section « LES LIGHTMAPS » : elles fonctionnent (l'indentation des lignes de commentaire est ignorée) mais se lisent
  comme du code de niveau fichier. Par ailleurs `MiroirsIso._couches` gagne 2 entrées par balle tirée (`Core`, `Aura`), rendues
  seulement à `vider()` ; `oublier_les_disparus()` n'est appelée que sous l'essai des nappes.
- **Coût** : nul à l'exécution (quelques dizaines de Ko après un long match).
- **Proposition** : déplacer l'en-tête de section et la phrase de doc ; appeler `oublier_les_disparus()` à la mort d'une balle.
- **Gain attendu** : lisibilité, évite qu'une fusion future « range » ces lignes dans une fonction qui ne tourne pas à chaque image.
- **Risque** : **trois gardes textuelles** (`test_banc.gd:289-300` : ordre `suivre` < `relief` < `led`) ; ne déplacer que l'en-tête.
- **Effort** : S.
- **Sévérité** : ANECDOTIQUE.
- **Statut ROADMAP** : NOUVEAU. (Cf. CLAUDE.md : « une fusion sans conflit textuel n'est pas une fusion sans perte ».)
- **Vérifier** : `./tools/run_suites.sh` (tests iso et `test_banc`).

### ISO-12 — Cinq shaders « lumière 3D / pâte écran » préchargés au démarrage pour un chemin éteint en jeu

- **Où** : `presentation_3d.gd:107-109, 113-114`.
- **Constat** : `sol_iso_eclaire` (391 lignes), `mur_iso_eclaire` (418), `corps_iso_eclaire` (418), `pate_ecran_iso`, `pate_vue_iso` sont des
  `const … = preload(…)`, donc chargés et analysés au chargement du script, alors que `poser_lumiere_3d(true)` n'est appelée que par les bancs.
  `lumieres_iso.gd` (410 lignes) est chargé par `const LumieresIsoT`.
- **Coût** : démarrage uniquement ; ESTIMÉ quelques ms à quelques dizaines de ms ; mémoire des programmes non compilés négligeable.
- **Proposition** : `load()` à la demande dans `poser_lumiere_3d`. 
- **Gain attendu** : temps de démarrage.
- **Risque** : les suites `--script` qui nomment ces constantes ; le piège du `preload` avant autoloads (l. 8962).
- **Effort** : S.
- **Sévérité** : ANECDOTIQUE.
- **Statut ROADMAP** : NOUVEAU.
- **Vérifier** : journal de démarrage.

---

## 3. Ce qui est déjà bien fait (à ne pas casser)

1. **Aucune vue cachée ne rend en match.** Vue 2D non regardée en `UPDATE_DISABLED` (`game_state.gd:5918-5924`), `VueIso` arrêtées en vue
   unique (`presentation_3d.gd:1688-1694`), capteurs créés pour les seules vues regardées (`:1097`, `miroirs_iso.gd:227`), gel du kill
   propagé aux lightmaps, vues 3D et capteurs ensemble (`:803-815`). Le piège « cacher un conteneur ne suspend pas sa vue » est tenu.
2. **La peinture est rendue à la demande** (`UPDATE_ONCE`, empreintes de pas exclues pour ne pas la salir à chaque pas) et sa mesure est
   dans la ROADMAP (l. 26756-26760) ; la leçon de « l'arbre en pause » est appliquée aux preuves.
3. **Les maillages ne sont jamais régénérés par image** : murs construits à l'allumage / au changement de carte, boîtes partageant un
   `BoxMesh` et un matériau (`iso_geometrie.gd:117-138`) ; éventails du faisceau en cache statique par cookie et par cran
   (`iso_volumes.gd:812-888`) ; `if mi.mesh != maillages[0]` avant d'affecter.
4. **L'allègement de la 0.8.0 est exemplaire** : couches du rayon taillées à l'enveloppe du cookie, plages de dix secteurs (et non un
   triangle par degré), juge taillé, rayon à la longueur de l'ancienne torche, chacun avec preuve à l'image, garde (175-185 vérifications)
   et drapeau de retour en débogage ; Q76 ramène le coût à 1,007 de la 0.7.1 au cadrage du banc.
5. **Les figurants arrêtent leur capteur hors portée** (`presentation_3d.gd:1197-1200`) : le patron à étendre aux objets (ISO-06).
6. **Les formules sont pures et testables sans fenêtre** (`camera_iso.gd` statique, `portee_ecran.gd`, `taille_lightmap`, `Echelle`) ; F3
   imprime la taille de chaque lightmap, du rendu, des capteurs (`_decrire`) ; le banc **refuse** un chiffre pris vue éteinte.
7. **La vue iso s'éteint sous les menus** (`presentation_3d.gd:556-563`) et l'aller-retour des vues est prouvé (`test_iso_vues`).
8. **Les gardes de texte** (`test_banc`, `test_corps_mannequin`) empêchent les oublis de crochet qui seraient muets ; les `print` du
   cycle de vie (`[iso] vue isométrique allumée…`) sont aux transitions, jamais par image.

---

## 4. Questions ouvertes

1. **Qui borne l'image sur le M3 : le GPU ou le fil principal ?** Aucune mesure : `TIME_PROCESS` n'est lu nulle part, le temps GPU par
   viewport vaut 0,00 sous Metal. Les mesures d'ISO7 Gadgets disent « CPU et GPU se recouvrent » et que la fumée (remplissage) pèse sur
   l'image sans peser sur le CPU. Si le GPU borne, ISO-03/04/05/10 ne bougent pas la médiane (ils servent le 1 % bas) ; si le fil
   principal borne, ils comptent. À trancher par : `Performance.get_monitor(TIME_PROCESS)` ajouté au banc, un relevé Xcode / Metal HUD, ou
   `Time.get_ticks_usec()` autour de `Presentation3D._process`.
2. **Remesurer sur le Mac, en build exporté, à 1280×720, 1920×1080 et plein écran natif**, en vue unique **à ×1,5** (`--zoom=1.5`),
   scène fusée et scène torches seules. La dernière série Mac date du 2026-09-30 (avant l'allègement, Q75 et Q76). Les mesures existantes
   sont soit en build debug 2560×1440 sur le Mac, soit sous llvmpipe dans le cloud (relatif seulement).
3. **Quads de torche (hors de mon périmètre, pointeur pour l'audit des lumières)** : chaque `PointLight2D` rastérise son rectangle
   carré de `2 × 468 = 936` px de monde (1404 px logiques à ×1,5, ~1,5 Mpx une fois rogné par la vue, ~73 % de la lightmap) pour un cône de
   10°-60° : 86 % (Terrassier, ±30°) à 98 % (Braconnier, 10°) de ce carré est transparent (calcul : secteur / carré), mais il coûte
   l'application de la lumière à chaque élément dessous. Deux torches =
   ~3 Mpx de remplissage de lumière pour une lightmap de 2,07 Mpx. Une demi-texture décalée par `offset` (cookie rogné sur l'avant)
   diviserait cette surface par ~2 à ~4 sans changer la portée ; c'est la même idée que les « éventails » du rayon, appliquée à la
   lumière elle-même. Le carré est le plus gros poste de la passe lightmap, et il n'est pas dans mes fichiers.
4. **Faut-il encore deux torches rendues dans chaque lightmap en écran scindé ?** Le faisceau d'une torche éclaire le sol des deux vues
   (règle du jeu, l. 24419-24425) : chaque lightmap rend donc les deux carrés (≈ 2 Mpx de lumière par vue, ×2 vues). C'est inhérent à la
   règle ; à garder en tête pour la cible 60 en scindé (1 % bas 50 le 2026-09-23).
5. **ISO-02 touche au cadrage** (bornes de carte du regard) : Adrien doit dire si le champ montré près des murs est-ouest peut bouger de
   ~135 px. Si non, il faut découpler `RegardDuel` de la largeur de la lightmap avant de rogner.
6. **Comportements du moteur que je n'ai pas pu vérifier** : (a) `set_shader_parameter` re-marque-t-il le matériau sale à valeur égale ?
   (b) un conteneur de lightmap à `modulate.a = 0` est-il écarté par `_cull_canvas_item` (alpha < 0,007) ou dessine-t-il un quad plein
   écran transparent ? Le décompte des appels de dessin avec / sans `top_level` le dirait ; la ROADMAP n'a pas vu de surcoût (l. 25301). (c)
   les `global uniform sampler2D` en Compatibility. (d) la compilation GL au premier dessin et la persistance du cache sur macOS.
7. **Hoquet de premier usage (ISO-09)** : combien de ms au premier allumage de la torche, à la première balle, à la première mort, dans un
   processus neuf, **en vue unique puis dans la seconde vue de l'écran scindé** ? La ROADMAP l'a mesuré pour la lumière 3D (143 à 150 ms,
   l. 27616) mais jamais pour les matériaux de jeu. C'est la mesure à plus forte valeur pour les premières minutes d'une session.
8. **Cartes joueur de plus de 64×64 cases** : jouées en ligne (« un salon adopte la carte de l'hôte ») ? Si oui, plafonner la peinture
   (4096²) et le décor cuit (4550² non plafonné, `arena_decor.gd:188`) devient une question de jeu, pas seulement de cadence.
9. **`lumieres_iso.gd`, les trois shaders « éclairé » et la pâte écran** : code retenu au banc derrière un interrupteur éteint depuis le
   2026-09-23 (« clos sans suite », Q20). À garder ou à retirer du chemin de démarrage (ISO-12) ? Décision d'Adrien.
