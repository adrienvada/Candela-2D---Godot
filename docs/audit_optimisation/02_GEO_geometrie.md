# GEO — Rendu isométrique : géométrie, voxels, matériaux, décor

Audit d'optimisation de Candela 2D, commit `52a29c1` (0.8.3 + SOLO S12), 2026-10-04. **Lecture seule** : aucun Godot lancé,
aucun fichier du dépôt touché.

## 0. Périmètre, méthode, limites

**Lus en entier** : `voxel_corps.gd`, `voxel_catalogue.gd`, `voxel_catalogue_objets.gd`, `voxel_objets.gd`, `iso_nuage_voxel.gd`,
`iso_materiaux.gd`, `iso_pate.gd`, `peinture_iso.gd`, `mannequin_iso.gd`, `murs_bas.gd`, `murs_bas_rendu.gd`, `mur_led.gd`,
`mur_encre.gd`, `plafonnier.gd`, `enseigne_qui_meurt.gd`, `arena_decor.gd`, `candela_tileset.gd`, `colonne_atelier.gd`.

**Lus pour connaître la fréquence d'appel ou la quantité (cités, pas audités)** : `presentation_3d.gd` (`_process`, `_suivre`,
`_construire_les_murs`, `_poser_peinture`, `_pousser_zone_morte_capteurs`), `iso_volumes.gd` (nuages, juge, `ImmediateMesh`),
`iso_geometrie.gd` + `map_geometry.gd` (murs en boîtes — hors liste mais nécessaires à la question 2), `miroirs_iso.gd`,
`game_state.gd` (`rebuild_arena`, `_do_start_round`, `_pousser_zone_morte`), `player.gd` (`_regler_enjambement`), `bullet.gd`,
`fusee.gd` (`prechauffer`), `capteur_corps.gd`, `arena.tscn`, `corps_iso*.gdshader`, `iso_corps_soi_sombre.gdshaderinc`.

**Chiffres de cartes** : calculés par un script Python qui reproduit `MapGeometry.build_grid` + `merge_rects` sur les six cartes
de `assets/maps/*.json` et les 100 niveaux de `assets/solo/` — c'est le même algorithme, pas une estimation.

**Étalons de vitesse pris dans le dépôt (aucune mesure de ma part)** :
- GDScript : `fusee.gd:338-340` — « 3 × 16 384 `set_pixel` — 8,5 ms mesurées à la revue », soit **≈ 0,17 µs par itération** d'une
  boucle à ~9 appels natifs ;
- cuisson du LED : « **83 ms** de cuisson pour la carte livrée (272² px) » (ROADMAP l. 22739), soit ≈ 1,1 µs par texel.
Toute durée ci-dessous marquée ESTIMÉ en dérive. **PROUVÉ** = établi par lecture du code (ce qui tourne, et à quel rythme).

**Verdict d'ensemble** : le domaine est sain. **Aucun maillage ni aucune texture n'est régénéré par image** dans les dix-huit
fichiers ; aucun `ImageTexture.update()`/`set_image()` ; tout ce qui est lourd est calculé au lancement, au départ de manche ou à
la première apparition, et le plus souvent mis en cache. **Aucun constat CRITIQUE ni MAJEUR.** Les écarts trouvés sont de petits
coûts par image (≤ 0,1 ms), un travail de départ de manche qui ne dépend que de la carte et qu'on refait, et un hoquet de
première apparition (compilation GPU) que la ROADMAP reconnaît ne pas avoir mesuré.

---

## 1. Réponses courtes aux cinq questions de la mission

**Q1 — Génération de maillages et de textures : quand, combien, en GDScript pur ? Par image ?**
- **Par image : rien.** `VoxelCorps.poser()` n'écrit que des transformations de `Node3D` ; les nuages ne changent que des
  uniformes ; la LED ne change que sa couleur ; la peinture ne se rend qu'à la demande (0,6 fois par seconde mesuré, ROADMAP
  l. 26759-26760). Aucun `SurfaceTool`, aucun `ImageTexture.update()`, aucun `set_image()` dans les 18 fichiers.
  (Voisins, hors liste : `ImmediateMesh` refait par image pour l'onde de mort et la toile du voile, `iso_volumes.gd:1280-1296,
  1328-1339`, pendant leur vie seulement ; voir §6.)
- **Au lancement** : `IsoNuageVoxel.prechauffer()` (`iso_nuage_voxel.gd:306-323`) — aplats, reliefs et planches réduites par
  boucles GDScript pixel à pixel, **0,2 à 0,4 s** (ROADMAP l. 31324-31325).
- **Au départ de chaque manche** (`_do_start_round` → `rebuild_arena`, `game_state.gd:1948`) : tileset 70×70 (≈ 4 900 `set_pixel`),
  `image_grille` ×4 (RGB8 case par case), `image_proximite_usure` (natif, lourd : GEO-02), décor cuit (`SubViewport` +
  `get_image()` : GEO-03), murs iso (`build_meshes`), peinture iso, texture LED (seulement si la carte est neuve).
- **À la première apparition** : grille `MultiMesh` d'un nuage (`cellules()`, GDScript), `VoxelObjet.construire`,
  `VoxelCorps.construire` (rebuild si la classe change, leurre).
- **Sommets / triangles** (PROUVÉ, calculés avec les formules du code) :

| Objet | Maillage | Sommets / triangles | Appels de dessin |
|---|---|---|---|
| Corps (défaut : tenue V3 sans détail) | 9 `BoxMesh` (10 avec la bouteille, 6 classes sur 10) | 216-240 sommets / 108-120 tri., dessinés **2 fois** (couleur + profondeur) | **18-20** |
| Détail fusionné (`--corps-detaille`, éteint) | ≤ 3 `ArrayMesh` par corps (Parasite : 12 pièces = 288 sommets) | 288 / 144 | +4 à +6 |
| Murs iso | 1 `MeshInstance3D` par rectangle fusionné, `BoxMesh` unique partagé | 24 / 12 par boîte | 4-11 (six cartes de duel), médiane 10, max 113 (100 niveaux solo) |
| Sol iso | 1 `PlaneMesh` par vue | 4 / 2 | 2 |
| Nuage de suie (gros voxels) | 1 124 cellules (`MultiMesh`) | **13 488 / 6 744** par vue | 1 (+1 juge) |
| Nuage de poussière | 2 176 cellules | **26 112 / 13 056** par vue | 1 (+1 juge) |
| Nuage de la fusée | 9 136 cellules | **109 632 / 54 816** par vue | 1 (+1 juge) |
| Fusée en variante « fin » (débogage) | 69 200 cellules | 830 400 / 415 200 | — |

  (Sommets des nuages : 3 faces × 4 sommets par cellule, caméra à 45°. Tampons : 54 Ko, 104 Ko, 439 Ko par grille.)

**Q2 — Nœuds de décor et appels de dessin : fusionnés ou un nœud par tuile ?**
- **Fusionné par rectangles (greedy meshing)**, jamais par tuile : la même liste de rectangles fait la collision, les occluders
  2D et les boîtes iso (`iso_geometrie.gd:100-138`). Six cartes de duel : 4 à 11 boîtes de mur ; les 4 rectangles de « fosses » ne
  portent pas de maillage. Un `BoxMesh` et **un seul** `ShaderMaterial` (`_mat_mur`) pour tous les murs.
- 2D, par manche : 3 calques `TileMapLayer` ×3 (original caché + copies P1/P2) = 9 nœuds (≈ 4 quadrants de 560 px chacun sur
  32×32), `ArenaDecor` ×3, `MurEncre` ×3, 1 `MurLed`, 1 `MapCollisions` (1 forme + 1 occluder par rectangle).
- **Matériaux** : partagés où les uniformes sont communs (murs : 1 ; boîtes d'un corps : 2 pour 9-10 boîtes) ; **dupliqués là
  où ils portent un état propre** (sols : 1 par vue ; corps : 2 par corps ; nuages : 1 par nuage et par vue, ≈ 35
  `set_shader_parameter` à la création ; calques de vue : `layer.material.duplicate()`, `game_state.gd:1580-1581`). Aucun
  matériau dupliqué sans raison.
- Les corps dominent le nombre d'appels : 36-40 (PROUVÉ) sur les 79 à 93 qu'un duel iso totalise dans la scène du banc
  (ROADMAP l. 28742), soit de l'ordre de 40 à 50 %.

**Q3 — Lumières posées par le décor.**
- **LED** : 1 `PointLight2D` pour toute la carte (`mur_led.gd:156-194`), `shadow_enabled = false`, texture ≤ 512², **animée par
  image** (`_process` → `regler()` : `energy` fixe, `color` dosée, `enabled`) ; allumée 84,6 % du temps (période 8,47 s,
  `PIC=1,2`, `SEUIL=0,004`). Coût mesuré : nul en vue unique, ≈ 4 % en écran scindé (ROADMAP l. 22618-22634).
- **Plafonniers** : **0 en duel** (posés par le seul solo, `aventure_partie.gd:161`) ; ≤ 8 par salle (`aventure_format.gd:103`) ;
  chacun une `PointLight2D` **à ombres** (`SHADOW_FILTER_NONE`), rayon 1,5-9 cases, énergie et rayon fixes, allumée/éteinte par
  proximité avec hystérésis. « Livré NON MESURÉ » (`plafonnier.gd:39-44`).
- **Enseigne** (`enseigne_qui_meurt.gd`) : **n'est pas une lumière** — un `self_modulate.a` sur l'image du menu, `set_process`
  coupé hors du menu (`ui.gd:6123-6124`).

**Q4 — Caches et mémoire.** Voir §2.6 (tableau). Total de ce qui tient en cache pour un duel : de l'ordre de 9 à 16 Mo
(peinture 3,2-5,4 Mo, décor cuit 3,2-5,4 Mo, proximité 0,8-1,6 Mo, LED ≈ 0,3 Mo, grilles de nuage < 1,2 Mo, images de nuage
≈ 2 Mo). Rien ne croît sans borne dans ces fichiers.

**Q5 — Moments décisifs.** Aucun travail lourd pendant l'action dans ces fichiers, **sauf la première fumée de la partie**
(compilation GPU des programmes de nuage, GEO-04). Le départ de manche porte 0,15-0,4 s de CPU estimé (GEO-02/03), qui tombent
PENDANT le décompte de 3 s (`game_state.gd:2028-2029`, décrémenté par le `delta` de l'image, `:2122`) : il en raccourcit d'autant
la machine touchée, jamais l'action.

---

## 2. Carte des chemins chauds

### 2.1 Par image de rendu (vue iso, défaut)

| Chemin | Fichier:ligne | Quantité (pire cas duel / solo) | Nature |
|---|---|---|---|
| `VoxelCorps.poser(etat)` | `voxel_corps.gd:623-692` ← `presentation_3d.gd:877,1204,1452` | 2 corps (+7 PNJ en solo) ; ≈ 30 écritures de propriétés `Node3D` + 1 `Basis.looking_at` chacun ; l'`etat` (Dictionnaire de 12 clés) vient de l'appelant, `presentation_3d.gd:1356-1409` | CPU GDScript, aucune allocation de maillage |
| `_accorder_la_classe` → `VoxelCatalogue.slugs()` | `presentation_3d.gd:876,1209,1340-1345` ← `voxel_catalogue.gd:222-226` | 1 `PackedStringArray` de 10 chaînes par corps | alloc (GEO-09) |
| **Q39 : `MannequinIso.lampes_du_jeu` + 2 `direction_dominante` + rayons** | `presentation_3d.gd:850-882` ← `mannequin_iso.gd:50-108` | 1 balayage des lampes + 1 à 6 rayons physiques | alloc + physique (GEO-01) |
| `VoxelObjet.poser` + `definir_capteur/style/opacite` (objets posés, leurre) | `voxel_objets.gd:194-245,287-310` ← `miroirs_iso.gd:264-296` | par objet posé (≤ ≈ 6) : 1 Dictionnaire, 3 petits tableaux, ≈ 11 `set_shader_parameter` ; chaque objet porte 2 `CapteurCorps` (autre agent) | CPU, uniformes |
| `VoxelCorps.pointe_torche()` (point lumineux de la lentille, Q46, par défaut) | `voxel_corps.gd:553-561` ← `iso_volumes.gd:1186-1210` | 2 corps : 1 Dictionnaire de 2 clés, `to_global`, `normalized`, `has_method` + `call` dynamiques | ≈ 3 µs par corps, négligeable |
| `MurLed._process` | `mur_led.gd:371-392` | 1 lumière : 3 propriétés | négligeable |
| `PeintureIso._process` | `peinture_iso.gd:183-200` | 2 `get()` + boucle sur les douilles en mouvement (0-5) | négligeable |
| `IsoNuageVoxel.poser_style` / `poser_gadget` / `poser_fusee` | `iso_nuage_voxel.gd:519-676` ← `iso_volumes.gd:1368,1579,1619-1620` | par nuage et par vue : 2 / 9 / 25-40 `set_shader_parameter` ; fusée : +15 `get_shader_parameter`, 1 `PackedVector3Array` | CPU, uniformes |
| `MursBasRendu.uniformes_de_vue` / `_poser` (via `frame_pre_draw`) | `murs_bas_rendu.gd:128-188` ← `presentation_3d.gd:763-792`, `game_state.gd:5979-6010` | 2-4 capteurs (+≤ 7 figurants) toujours ; 2 vues si des murets | GEO-08 |
| `Presentation3D._decrire` (texte F3) → `IsoGeometrie.hauteur_mur_haut()` | `presentation_3d.gd:523,1823-1851` ← `iso_geometrie.gd:53-61` | 1 chaîne de 3 à 5 lignes (3 à 5 formats `%` de 6 à 8 arguments + 2 `str()`) + `load()` + `get_script_constant_map()` par image, F3 fermé (GEO-12) | alloc |
| `EnseigneQuiMeurt._input` | `enseigne_qui_meurt.gd:177-187` | 6 `is` par événement d'entrée | négligeable (`_process` coupé hors menu) |

### 2.2 Par tick physique

| Chemin | Fichier:ligne | Quantité |
|---|---|---|
| `Plafonnier._physics_process` → `actualiser` | `plafonnier.gd:261-275` | ≤ 8 plafonniers (solo), 1 `get_nodes_in_group` chacun (GEO-05) |
| `MursBas.chevauche_cercle` ×2 par joueur | `player.gd:1560-1567` ← `murs_bas.gd:109-115` | O(N murets) ; N = 0 sur les six cartes de duel, ≤ 44 en solo |
| `MursBas.franchit_regle` (éblouissement, impact de balle) | `game_state.gd:2828`, `bullet.gd:388-391` ← `murs_bas.gd:160-163` | seulement si la lampe/la balle touche une cible ; réalloue N `Rect2` (`forme_de_lumiere`) |

### 2.3 Par événement

| Événement | Chemin | Coût |
|---|---|---|
| Trace posée (sang, éclat, douille) | `PeintureIso._copier` (`peinture_iso.gd:260-280` : `duplicate()` + `get_property_list()`) puis un rendu `UPDATE_ONCE` | 0,6 rendu/s mesuré en duel (ROADMAP l. 26759) |
| Nuage posé | `IsoNuageVoxel.materiau` (≈ 35 uniformes) ; 1re fois de son type/côté : `grille()` | GEO-04 |
| Objet debout posé / leurre | `VoxelObjet.construire`, `VoxelCorps.construire` (≈ 20-30 nœuds, 2 matériaux) | ≈ 1 ms ESTIMÉ |
| Changement de classe entre manches | `VoxelCorps.construire` (garde `voxel.slug() == slug`, `presentation_3d.gd:1290`) | ≈ 1 ms |

### 2.4 Début de manche (chaque `_do_start_round` → `rebuild_arena`, `game_state.gd:1948`)

`Presentation3D.accrocher` met `_reconstruire = true` à chaque appel (`presentation_3d.gd:372`) ; à l'image suivante
`_construire_les_murs()` + `_poser_peinture()` (`:516-518`). Enchaînement CPU, dans l'ordre :

| Étape | Fichier:ligne | Durée |
|---|---|---|
| `build_collisions`, `rects_monde` | `game_state.gd:1496-1497` | 4 `build_grid` |
| `MurLed.poser` (cuisson si carte neuve) | `game_state.gd:1503`, `mur_led.gd:156-213` | 4 `build_grid` ; cuisson **83 ms mesurés** sur 272² (cache par `hash`) |
| `create_tileset`, calques, copies | `game_state.gd:1462-1518` | ≈ 1-2 ms (tileset) |
| `ArenaDecor.build` → `_cuire` | `game_state.gd:1538`, `arena_decor.gd:176-215` | rendu + **relecture GPU** (GEO-03) |
| `MurEncre.build` | `game_state.gd:1558`, `mur_encre.gd:73-95` | 2 `build_grid` + `trace_contours` ≈ 1-2 ms |
| `IsoGeometrie.build_meshes` | `presentation_3d.gd:2194` | 2 `build_grid`, ≤ 11 nœuds |
| `accorder_grille` ×3 + `image_proximite_usure` | `presentation_3d.gd:2196-2203` | 4 `image_grille` ; **proximité : GEO-02** |
| `_poser_peinture` | `presentation_3d.gd:1059-1076` | `SubViewport` neuf (3,2-5,4 Mo) + 4 copies de calques |

Total `build_grid` : **≈ 20 appels** par départ de manche (3+1+4+2+2+4×2). ESTIMÉ du bloc entier : **0,15 à 0,4 s**, dominé
par la proximité. Il tombe pendant le décompte de 3 s (`game_state.gd:2028-2029,2122` : `countdown_left - delta`) ; en ligne il
n'est pas mesuré non plus (question ouverte).

### 2.5 Chargement / première fois

`IsoNuageVoxel.prechauffer()` (0,2-0,4 s, ROADMAP l. 31324) ; `Fusee.prechauffer` (textures de volutes 8,5 ms + un quad
invisible qui force la compilation du shader du voile, `fusee.gd:341-358`) ; variantes de shaders par `Shader.new()` mises en
cache dans `IsoMateriaux._variantes` (`iso_materiaux.gd:118-129`).

### 2.6 Caches et mémoire

| Cache | Clé | Durée de vie | Taille |
|---|---|---|---|
| `IsoNuageVoxel._aplats`, `_reliefs`, `_planches` | `Texture2D.get_instance_id()` | processus | suie 184² + poussière 336² RGBA8 ×2 (≈ 1 Mo) + 3 planches 256² (0,75 Mo) |
| `IsoNuageVoxel._grilles` / `_mailles` | `type:voxel:rangs:côté` | processus | ≤ 9 côtés × (54+104+439 Ko) ; en pratique 1-2 côtés < 1,2 Mo |
| `IsoMateriaux._variantes` | `id du shader : define` | processus | une douzaine de `Shader` |
| `MurLed._cache_texture` | `hash([murs, sol])` | jusqu'à la prochaine carte | ≤ 512² RGBA8 (≤ 1 Mo) |
| `ArenaDecor._cuit` | — (**aucun cache entre manches**) | une manche | (grille+2)×35² × 4 o : 3,2-5,4 Mo (duel) ; 39 Mo (100×80) ; 79 Mo (128×128) |
| `PeintureIso` (texture) | — (refaite à chaque manche) | une manche | idem, plafonnée à 4 096² (67 Mo) |
| `usure_proximite` (R8) | — (**aucun cache entre manches**) | une manche | 0,8-1,6 Mo (duel) ; 10,7 Mo (100×80) |
| `VoxelCatalogue._mannequin_ligne` etc. | drapeau | processus | — (mais `tenue()`, `teinte()`, `beaute_active()` ne sont PAS cachés : GEO-09) |

---

## 3. Constats

### GEO-01 — Le corps de soi sombre (Q39, allumé par défaut) relance chaque image le balayage de lampes du « mannequin », avec des rayons physiques, pour les deux corps

**Où** : `presentation_3d.gd:850-854` et `:881-882` (appelant) ; `mannequin_iso.gd:71-99` (`lampes_du_jeu`), `:50-67`
(`direction_dominante`), `:103-108` (`occultation`) ; `voxel_catalogue.gd:564-569` (`soi_sombre_actif()`).

**Constat** :
```gdscript
# presentation_3d.gd:852-854 — chaque image
var soi_sombre := corps_voxel and _main != null and VoxelCatalogue.soi_sombre_actif()      # vrai SANS drapeau (Q39 = A, 0.7.0)
var lampes_mannequin: Array = MannequinIso.lampes_du_jeu(_main) if mannequin else []
var lampes_soi: Array = lampes_mannequin if mannequin else (MannequinIso.lampes_du_jeu(_main) if soi_sombre else [])
# :881-882 — pour CHAQUE corps j de 0 à 1
if soi_sombre:
	_mat_corps[j].set_shader_parameter("soi_lumiere", direction_du_lisere(joueur as Node2D, lampes_soi))
# mannequin_iso.gd:89-98 — tous les enfants de bullet_container (balles, gadgets, fusées)
for noeud in conteneur.get_children():
	...
	for nom in [^"Halo", ^"Lueur", ^"Embrasement"]:
		_omni(out, noeud.get_node_or_null(nom) as Light2D)
	var faisceau := noeud.get_node_or_null(^"Faisceau") as Light2D
# mannequin_iso.gd:105-108 — un rayon par lampe de poids > 0, par corps
return func(de: Vector2, vers: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(de, vers, MapGeometry.WALL_LAYER)
	q.exclude = exclus
	return not espace.intersect_ray(q).is_empty()
```
`mannequin_iso.gd` se présente comme éteint par défaut (`--mannequin`, ROADMAP l. 28187) ; depuis Q39 (« le corps de soi sombre »,
ROADMAP l. 2487) le même module tourne **par défaut**. Le shader ne lit `soi_lumiere` que sous `if (s > 0.0)`
(`corps_iso.gdshader:312`), c.-à-d. pour le corps de **soi dans sa propre vue** (`iso_corps_soi_sombre.gdshaderinc:21-23`) :
en vue unique **en ligne** (les deux corps sont visibles, un seul est « soi ») **un des deux appels est inutile** ; à
l'entraînement J2 est masqué (`game_state.gd:1031-1040`) et la boucle l'ignore (`presentation_3d.gd:868-871`). Le balayage des lampes, lui, est refait même si
rien n'a bougé.

**Coût** : PROUVÉ — tourne à chaque image dès que la vue iso est active. ESTIMÉ — **0,03 à 0,08 ms par image** (≈ 25-50 appels
natifs pour les lampes, +4 `get_node_or_null` par balle en vol, 2 à 6 rayons de ≈ 3 µs, une `Callable` et un tableau neufs par
corps) : 0,2 à 0,5 % d'une image à 60 fps. Aucune mesure au dépôt : « prix de cadence de l'ensemble : à mesurer sur le Mac »
(ROADMAP l. 2487).

**Proposition** :
1. Ne calculer `direction_du_lisere` que pour le corps dont `silhouette_du_corps(...).a > 0` dans une vue regardée (1 corps en
   vue unique, 2 en écran scindé) ;
2. recalculer une image sur deux (30 Hz) et garder la dernière valeur — le liseré fait 1,5 px d'écran et suit une direction
   continue ;
3. dans `lampes_du_jeu`, ne pas fouiller les balles (elles ne portent plus de lumière depuis le 2026-09-15, ROADMAP l. 2508) :
   filtrer le conteneur par groupe ou par type ;
4. réutiliser un `PhysicsRayQueryParameters2D` par corps (champs `from`/`to` modifiés) au lieu de `create()` par rayon.

**Gain attendu** : ≈ 0,03-0,06 ms par image (ESTIMÉ) ; plus si les fusées/gadgets abondent.

**Risque** : visuel seulement (direction d'un liseré que l'adversaire ne voit jamais) ; aucune incidence réseau ni équité.
`tools/test_corps_mannequin.gd:137-139` lit le texte de `presentation_3d.gd` et compte exactement deux fois la boucle
`for m in [_mat_corps[j], _mat_profondeur[j], …next_pass]` : ne pas réécrire cette boucle sans mettre la garde à jour.

**Effort** : S. **Sévérité** : MINEUR.

**Statut ROADMAP** : NOUVEAU — le réemploi par défaut n'est chiffré nulle part (l. 28193 dit « pour chaque corps et à chaque
image » sans coût ; l. 2487 renvoie la cadence au Mac).

**Comment le vérifier** : chronométrer `lampes_du_jeu` + `direction_du_lisere` (`Time.get_ticks_usec()`, imprimé toutes les 120
images) en duel, vue unique et scindée ; A/B `bench_framerate.tscn -- --iso --vue-unique --seconds 30` avec et sans
`--sans-corps-soi-sombre` (drapeau existant) — mais le gain attendu est sous le bruit du banc (±1,5 %, ROADMAP l. 30511).

---

### GEO-02 — `image_proximite_usure` : huit `blend_rect` plein cadre, deux `resize`, un `convert`, refaits à CHAQUE manche alors que le résultat ne dépend que de la carte

**Où** : `iso_materiaux.gd:466-502` (+ `:507-509`) ← `presentation_3d.gd:2198-2203` ; déclenché à chaque `rebuild_arena`
(`presentation_3d.gd:372`, `:516-518`).

**Constat** :
```gdscript
# iso_materiaux.gd:487-497
var sortie := Image.create_empty(grande.x, grande.y, false, Image.FORMAT_RGBA8)
sortie.fill(Color(0, 0, 0, 1))
for d in [Vector2i(14, 0), Vector2i(-14, 0), Vector2i(0, 14), Vector2i(0, -14)]:
	_decaler_sur(sortie, moitie, d, grande)          # → cible.blend_rect(source, rect, …) sur presque toute l'image
for d in [Vector2i(5, 0), Vector2i(-5, 0), Vector2i(0, 5), Vector2i(0, -5)]:
	_decaler_sur(sortie, plein, d, grande)
sortie = sortie.get_region(Rect2i(bord * tuile, taille)); sortie.convert(Image.FORMAT_R8)
```
`grande = (cases + 2) × 35 px` : **0,96 à 1,59 Mpx** sur les six cartes de duel (image RGBA8 de 3,8 à 6,4 Mo, trois images +
`get_region` + `convert`), **10,7 Mpx** (42,8 Mo l'image, ≈ 130 Mo de transitoires) sur `chapitre_08/niveau_09` (100×80). En plus,
`_construire_les_murs` appelle `accorder_grille` 3 fois (un `image_grille` + un `ImageTexture` identiques par matériau :
`:2196,2202`). La ROADMAP dit « préparée une fois par carte » (l. 28423-28424) ; le code la prépare **à chaque construction des
murs**, donc à chaque manche et chaque rematch sur la même carte.

**Coût** : ESTIMÉ — `blend_rect` est natif mais pixel à pixel (lecture RGBA8, test d'alpha, mélange) : 8 × 1,0-1,6 Mpx ⇒
**0,1 à 0,25 s** de CPU au départ de chaque manche de duel (borne large 0,05-0,4 s) ; ≈ 1 s et ≈ 130 Mo de pic sur les salles
≥ 60×60. Jamais chronométré : la ROADMAP ne donne que la cadence par image (l. 28420-28445).

**Proposition** (cumulables) :
- **A.** Construire directement en `FORMAT_R8` par `Image.fill_rect` sur les rectangles fusionnés de la grille bordée
  (`MapGeometry.merge_rects` : 4 à 11 sur les cartes livrées, ≤ 113 en solo) : par rectangle R en pixels, remplir R décalé de
  ±14 px (en x puis en y) à 0,5 puis R décalé de ±5 px à 1,0. Une union de copies décalées d'une union de rectangles est l'union
  des copies décalées de chaque rectangle : **même image par construction**, sans trois images RGBA8, sans les huit mélanges,
  sans `resize` ni `convert`.
- **B.** À défaut, mémoriser l'image par `hash` de la carte (le patron existe : `mur_led.gd:128-132,208-213`) : le rematch ne
  paie plus rien.
- **C.** Un seul `image_grille` + un seul `ImageTexture` partagés par les trois matériaux.

**Gain attendu** : A ⇒ de ≈ 0,1-0,25 s à ≈ 5 ms par manche (ESTIMÉ) ; C ⇒ ≈ 5 ms.

**Risque** : aucun sur le jeu (gravats d'usure, rendu local). La preuve existe et suffit : `tools/test_iso_usure.gd:200-231`
compare la proximité à l'ancienne formule en 36 000 points sur six cartes et rougit à 8 px.

**Effort** : S (A : M). **Sévérité** : MINEUR en duel (pendant le décompte de 3 s, pas pendant l'action) ; à reclasser MAJEUR si le
départ de salle solo grand format est jugé trop long.

**Statut ROADMAP** : NOUVEAU (l'écart « une fois par carte » / code, et l'absence de chiffre).

**Comment le vérifier** : dans `test_iso_usure.gd:218`, entourer `IsoMateriaux.image_proximite_usure(d)` de
`Time.get_ticks_usec()` — la suite est headless, le coût est du CPU natif, donc valable sans fenêtre — sur les six cartes et
deux salles solo ; puis `bench_framerate.tscn -- --iso --seuil-lent 25` (date les images lentes) et `banc_pics.tscn` (signature
« pics groupés au début »).

---

### GEO-03 — Le reste du départ de manche : décor cuit sans cache ni plafond, tileset reconstruit, `build_grid` ×20

**Où** : `arena_decor.gd:169-215` ; `candela_tileset.gd:69-98` ← `game_state.gd:1462` ; `build_grid` : `game_state.gd:1496-1497`,
`mur_led.gd:166-167`, `mur_encre.gd:92-93`, `iso_geometrie.gd:106,123`, `iso_materiaux.gd:440-442` (×4).

**Constat** :
```gdscript
# arena_decor.gd:186-210 — à chaque ArenaDecor.build (donc à chaque manche)
var vue := SubViewport.new(); vue.size = Vector2i(_cadre.size)         # (grille+2)×35, aucun plafond
vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
...
await RenderingServer.frame_post_draw
var img: Image = vue.get_texture().get_image()                         # relecture GPU synchrone
_cuit = ImageTexture.create_from_image(img)                            # re-téléversement
```
L'en-tête dit « UNE texture par carte » (`:22`) ; la seule cuisson réellement mise en cache par carte est celle du LED
(`mur_led.gd:131-132`). `create_tileset()` régénère un `TileSet` constant (≈ 4 900 `set_pixel` + hachages). `build_grid`
redécode le RLE (≈ 700 + 350 `Vector2i`) et remplit deux dictionnaires à chaque appel ; ≈ 20 appels par départ de manche.
`PeintureIso` plafonne sa texture à 4 096² (`peinture_iso.gd:53`), pas `ArenaDecor`.

**Coût** : ESTIMÉ (0,17 µs/itération) — tileset ≈ 1-2 ms ; `build_grid` ≈ 0,5-0,8 ms × 20 ≈ 10-15 ms ; décor : rendu de
0,8-1,4 Mpx + relecture synchrone ≈ 5-15 ms (non mesuré). Cartes d'éditeur jusqu'à 128×128 (`map_codec.gd:27`) : 4 550² ⇒ 79 Mo
de cible + 79 Mo d'`Image` + 79 Mo de texture, ≈ 240 Mo transitoires.

**Proposition** : `static var` pour `_cuit` indexée par `hash(data)` (invalider dans `poser_pochoirs`) et plafonner la cuisson
comme la peinture ; `static var _tileset` ; un cache d'un tour pour `build_grid(data, kind)`.

**Gain attendu** : ≈ 20-40 ms par manche (ESTIMÉ) et la fin du pic mémoire sur les grandes cartes.

**Risque** : faible. `PeintureIso._process` (`:191-196`) suit déjà le changement de `_cuit`.

**Effort** : S. **Sévérité** : ANECDOTIQUE (MINEUR pour le pic mémoire des grandes cartes).

**Statut ROADMAP** : NOUVEAU (l. 22327 décrit la cuisson « par carte »).

**Comment le vérifier** : `Time.get_ticks_usec()` autour de `rebuild_arena` et de `_construire_les_murs`;
`Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)` avant/après sur `chapitre_08/niveau_09`.

---

### GEO-04 — Première fumée de la partie : grille du nuage bâtie en GDScript au premier nuage, programmes GPU compilés au premier dessin

**Où** : `iso_nuage_voxel.gd:306-323` (`prechauffer` : shader chargé, aplats, reliefs, planches — **pas les grilles**),
`:388-429` (`cellules`, `grille`) ← `iso_volumes.gd:1617-1626` (sentinelle `Vector2i(9, 9)` : construction au premier suivi) ;
`iso_volumes.gd:1657-1665,2016-2018` (variante du juge créée par `Shader.new()` au premier juge) ; `iso_materiaux.gd:118-129`.

**Constat** : `prechauffer()` ne force ni la construction des grilles ni la compilation d'un programme (son propre commentaire
`:301-305` le dit : « le shader, lui, se COMPILE à son premier dessin, dans le pilote »). Rien dans `IsoVolumes` ne dessine un
nuage « à blanc », contrairement à `Fusee.prechauffer` (`fusee.gd:341-358` : « un quad invisible dessiné une image »).
Au premier nuage de chaque type : `cellules()` = 1 728 / 3 528 / **14 400** itérations (suie / poussière / fusée) puis remplissage
du tampon (1 124 / 2 176 / 9 136 instances × 12 flottants).

**Coût** :
- CPU, ESTIMÉ : **1-2 ms** (suie, poussière), **5-8 ms** (fusée), une fois par (type, côté de caméra) et par processus —
  négligeable.
- GPU, PROUVÉ par lecture qu'il n'est pas préchauffé : `nuage_voxel_iso.gdshader` (730 lignes, 60 uniformes) et sa variante
  `NUAGE_FUSEE`, la variante de juge de `volume_iso`, et le `corps_iso_profondeur.gdshader` ordinaire (pré-passe des
  `VoxelObjet`, GEO-07) compilent au premier dessin, **en match**. La ROADMAP soupçonne déjà, sur le Mac, une compilation au premier usage d'une
  variante derrière des images de 135 à 143 ms (l. 27517-27521, hypothèse non tranchée). Taille du hoquet pour ce shader :
  **inconnue** — la ROADMAP l'écrit comme limite de la preuve (l. 31299-31302).

**Proposition** : dans `IsoVolumes` (là où `prechauffer()` est appelé, `iso_volumes.gd:343`), (1) bâtir les grilles utiles
(rangées : suie 28 px → 3, poussière 14 px → 2, fusée 35 px → 4) pour le ou les côtés de caméra des vues projetées ;
(2) comme `Fusee.prechauffer`, dessiner **une image** une instance de chaque variante (gadget, fusée), son juge et un
`VoxelObjet`, avec `nuage_vie = 0` / hors champ, puis les libérer.

**Gain attendu** : supprime un hoquet unique, au premier lancer de la partie ; durée non mesurée (ESTIMÉ 50-200 ms pour un
shader de cette taille sur le GL d'Apple).

**Risque** : noir absolu — le dessin de chauffe ne doit écrire aucun pixel (vie nulle ⇒ cubes de taille 0, ou plan hors caméra) ;
ne préchauffer que sous `fumee_voxel` (`tools/test_fumee_voxel.gd` garde « sans drapeau, le shader n'est jamais chargé »).

**Effort** : S-M. **Sévérité** : MINEUR (une fois par lancement ; à reclasser MAJEUR si la mesure dépasse ≈ 100 ms, car il tombe sur le
premier lancer de fusée ou de cartouche, en pleine action).

**Statut ROADMAP** : CONNU-OUVERT (l. 31299-31302 ; l. 27517-27521 « noté pour le plan des lots, pas fait »).

**Comment le vérifier** : les deux bancs absorbent ce hoquet dans leur chauffe (`bench_framerate.gd:88` : 30 s ;
`banc_pics.gd:41` : 2 s, « il porte justement les compilations », `:97`). Pour le dater, poser la première fusée APRÈS la chauffe,
en cours de mesure, avec `--seuil-lent 25` (date toute image au-dessus de 25 ms) ; ou `Time.get_ticks_usec()` autour du premier
`grille()` et de la première image dessinée.

---

### GEO-05 — Plafonniers (solo) : un `get_nodes_in_group` par plafonnier et par tick ; lumières à ombres livrées « non mesurées »

**Où** : `plafonnier.gd:261-275` ; plafond de nombre `aventure_format.gd:103` ; mention « NON MESURÉ » `plafonnier.gd:39-44`.

**Constat** :
```gdscript
func _physics_process(_delta: float) -> void:
	actualiser()
func actualiser() -> void:
	...
	var positions: Array = []
	for j in get_tree().get_nodes_in_group("players"):
		if j is Node2D and is_instance_valid(j) and not (j as Node).is_queued_for_deletion():
			positions.append((j as Node2D).global_position)
	var doit := doit_etre_allume(allume, global_position, rayon_px, positions)
```
Jusqu'à 8 plafonniers par salle ; 8 dans `chapitre_08/niveau_09` (100×80 cases, 7 PNJ) ; sur les 100 niveaux livrés : 218 plafonniers,
moyenne 2,2 par salle, 13 salles avec au moins 4, rayon moyen 4,2 cases (max 8) — soit, toutes allumées, ≤ 1 Mpx de rectangles de
lumière au pire (`chapitre_08/niveau_09`).

**Coût** : CPU, ESTIMÉ — 480 appels/s dans le pire cas, ≈ 5-8 µs chacun (deux tableaux neufs, ≤ 9 joueurs/PNJ) ⇒ ≈ 0,03 ms par
tick : négligeable. **L'enjeu est GPU et il n'est pas mesuré** : chaque plafonnier allumé est une `PointLight2D` à ombres
(`shadow_enabled = true`, `SHADOW_FILTER_NONE`), de 1,5 à 9 cases de rayon (jusqu'à 630 px de diamètre), qui s'ajoute aux
torches des PNJ ; la décision du chantier SOLO exclut les relevés de cadence (ROADMAP l. 2449) et le fichier le déclare livré
non mesuré.

**Proposition** : (1) un seul nœud (le conteneur « Plafonniers ») lit les positions une fois par tick et décide pour tous, ou
décider tous les 6 ticks (l'hystérésis de 120 px = 0,46 s de course à 260 px/s l'absorbe ; la perception du bot voit « moins que la
lumière, jamais plus », `perception_bot_noeud.gd:338-341`) ; (2) **mesurer** 8 plafonniers allumés (salle 8/9) avant de plafonner
le nombre de lumières à ombres simultanées.

**Gain attendu** : CPU ≈ 0,02-0,03 ms/tick ; GPU inconnu.

**Risque** : allumage retardé de ≤ 100 ms au pire ; aucun effet de jeu connu.

**Effort** : S. **Sévérité** : MINEUR (solo seulement ; rien en duel).

**Statut ROADMAP** : CONNU-OUVERT (`plafonnier.gd:39-44` ; l. 2449 ; l. 31801 « une lumière à ombres de plus par plafonnier »).

**Comment le vérifier** : `tools/test_plafonniers.gd` (garde, 152 vérifications) ; mesure GPU : F3 (lumières) + `bench_framerate`
sur la salle 8/9 avec et sans plafonniers (`Plafonnier.retirer(arena)`), image à image avec `--temps-par-vue`.

---

### GEO-06 — Budget d'appels de dessin des corps : 18-20 par corps, dont 9-10 de pré-passe de profondeur (option, non prioritaire)

**Où** : `voxel_corps.gd:899-917` (`_boite`), `:1242-1311` (`_construire_squelette`), `:924-945` (bouteille).

**Constat** : chaque boîte est un `MeshInstance3D` + un double `BoiteProfondeur` (même maillage, autre matériau,
`render_priority -1`) ; neuf boîtes, dix pour les six classes à bouteille. Sans détail (défaut : `--corps-detaille` est éteint,
`voxel_catalogue.gd:490-597`) : **18 ou 20 appels par corps, 36 à 40 pour le duel, +20 par PNJ du solo** (jusqu'à +140 sur
`chapitre_08/niveau_09`). ≈ 29-31 nœuds par corps.

**Coût** : PROUVÉ — 36-40 appels pour deux corps ; la ROADMAP relève 79 à 93 appels pour le duel iso complet dans la scène du banc
(l. 28742), d'où de l'ordre de 40 à 50 % du total (le total est celui du banc, pas recompté). ESTIMÉ — 0,2 à 0,6 ms de
CPU de soumission, non mesuré. **La décomposition du cloud désigne le REMPLISSAGE (le rayon dans l'air) pour l'écart de la
0.8.0, pas le nombre d'appels** (ROADMAP l. 30492-30514) : sans mesure préalable, ce poste n'est pas prioritaire.

**Proposition (options, à mesurer d'abord)** :
- **S** — cacher les `BoiteProfondeur` d'un corps tant que `a = 1 − (1−o)(1−s)` vaut 1 dans toutes les vues regardées (typiquement
  son propre corps) : la couleur écrit déjà la profondeur (`depth_draw_always`), et un corps opaque n'a pas besoin de la
  pré-passe qui sert à ne pas assombrir deux fois une surface translucide (`corps_iso_profondeur.gdshader:5-12`). −9/−10 appels
  par corps opaque.
- **L** — un seul maillage par corps animé par un tableau de 9 matrices (indice d'os dans `CUSTOM0`, comme la fusion Q33,
  `voxel_corps.gd:1082-1136`) : 18 → 2 appels. Casse `pointe_arme`, `pointe_torche`, `rayon_empreinte`, `poser()` ; gros chantier.

**Gain attendu** : S ≈ −9 appels/corps opaque (ESTIMÉ 0,1-0,3 ms) ; L ≈ −32 à −36 appels au duel.

**Risque** : S touche au piège de l'ordre 424 (couleur et pré-passe = même programme, ROADMAP l. 28909-28919) et au visuel : preuve
à l'image obligatoire (`banc_corps.tscn` dispose déjà de `--sans-profondeur`). L touche `corps_iso*.gdshader` (autre agent).

**Effort** : S (option S) / L (option L). **Sévérité** : MINEUR (option).

**Statut ROADMAP** : NOUVEAU (option). L'équipe est déjà dans cette direction : Q33 a fusionné les accessoires (22 → 6 appels pour
un Parasite, l. 28874-28880).

**Comment le vérifier** : `bench_framerate` imprime les appels de dessin (médiane) ; A/B avec les doubles cachés
(`--sans-profondeur` du banc des corps) ; `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`.

---

### GEO-07 — `VoxelObjet` : couleur en variante `CORPS_SOI_SOMBRE`, pré-passe restée sur l'ancien programme (le piège de l'ordre 424)

**Où** : `voxel_objets.gd:135-162` (aucun `set_meta(MATERIAU_PROFONDEUR, …)`) ; `miroirs_iso.gd:225` (`IsoMateriaux.accorder_corps`) ;
`iso_materiaux.gd:242-268,293-303`.

**Constat** : `VoxelCorps.construire` pose `_materiau.set_meta(IsoMateriaux.MATERIAU_PROFONDEUR, _materiau_profondeur)`
(`voxel_corps.gd:319`), ce qui permet à `accorder_passe_profondeur` de faire suivre à la pré-passe le programme de la couleur.
`VoxelObjet` (mine, torche fantôme, piquets du voile, plaque de l'ombre, bobine, fusée posée) ne le pose pas, alors que
`miroirs_iso._creer` lui applique le même `accorder_corps` :
```gdscript
# iso_materiaux.gd:293-296
static func accorder_passe_profondeur(materiau: ShaderMaterial) -> void:
	if not materiau.has_meta(MATERIAU_PROFONDEUR):
		return          # ← les VoxelObjet sortent ici
```
Par défaut `soi_sombre_actif()` est vrai ⇒ la couleur d'un objet passe à la variante `CORPS_SOI_SOMBRE`, sa pré-passe reste
`corps_iso_profondeur.gdshader` : **deux programmes pour une même pièce**, exactement le cas qui a fait disparaître des pièces
entières sous llvmpipe (ROADMAP l. 28897-28907, 28909-28919). `tools/test_passe_unique.gd` n'instancie que des `VoxelCorps`
(`:80-81`).

**Coût** : aucun en cadence ; défaut visuel latent (pièce d'objet qui perd le test de profondeur contre sa propre pré-passe sur
certains pilotes). Non observé ; la preuve Mac de la fusion (ROADMAP l. 28935-28937) ne porte que sur les corps.

**Proposition** : poser la méta dans `VoxelObjet.construire` (une ligne, comme `voxel_corps.gd:319`) et étendre
`test_passe_unique.gd` aux six objets.

**Gain attendu** : correction d'un risque d'artefact ; aucun gain de cadence.

**Risque** : nul tant que la garde passe (la pré-passe prend le programme de la couleur, `passe_profondeur = 1`).

**Effort** : S. **Sévérité** : MINEUR (correction, hors cadence).

**Statut ROADMAP** : NOUVEAU (l. 28909-28919 règle les corps seulement).

**Comment le vérifier** : `tools/test_passe_unique.gd` étendu ; photographe `banc_iso_gadgets.tscn` sous `--sans-profondeur`.

---

### GEO-08 — Zone morte : les capteurs sont poussés chaque image même sans muret ; parcours linéaires des murets

**Où** : `presentation_3d.gd:763-792` (branchement `frame_pre_draw` `:479-480`) ; `murs_bas_rendu.gd:128-188` ;
sortie anticipée de la version `GameState` : `game_state.gd:5979-5987` ; `murs_bas.gd:109-115,143-148` ; `player.gd:1560-1567`.

**Constat** : `GameState._pousser_zone_morte` sort dès que `murs_bas.is_empty()` après un premier passage
(`_zone_morte_vide_poussee`). `_pousser_zone_morte_capteurs` n'a pas cette sortie : à chaque image, par capteur (2 en vue
unique, 4 en écran scindé, + un par figurant), `uniformes_de_vue` alloue un dictionnaire de 10 clés et un `PackedVector4Array`
redimensionné à 64, puis `poser_corps` fait 8 `set_shader_parameter` dont `mb_murs` (1 Ko). Or **les six cartes de duel n'ont
aucun muret** (`map_002` : `"low_walls": ""`) et 18 niveaux solo sur 100 en ont (max 44 rectangles). Quand il y en a, chaque
appel boucle sur tous les murets (`grow`, deux transformations, `Rect2`, `intersects`) avant de filtrer ; `forme_de_lumiere`
réalloue N `Rect2` à chaque `franchit_regle`.

**Coût** : ESTIMÉ — 5-10 µs par capteur et par image sur les cartes de duel (20-60 µs au total) ; avec N = 44 murets, ≈ 0,3 µs ×
N × (2 vues + capteurs) ≈ 0,1-0,2 ms. Côté GPU, **déjà mesuré** : « 40 murets à l'écran ~+4 ms » (ROADMAP l. 30046-30048).

**Proposition** : reproduire la sortie anticipée de `GameState` dans `_pousser_zone_morte_capteurs` (les uniformes valent `nb=0`
tant qu'aucun muret ne vient) ; pour un capteur (256 px = 128 px de monde), rejeter les murets en espace monde (un
`Rect2.intersects`) avant de les transformer ; mettre en cache `forme_de_lumiere(murs_de_la_manche)` là où `GameState` pose
`murs_bas` (`game_state.gd:1497-1498`).

**Gain attendu** : ≈ 0,03-0,06 ms par image en duel ; ≤ 0,2 ms dans les deux salles à murets nombreux (ESTIMÉ).

**Risque** : aucun si les uniformes restent identiques (`tools/test_murs_bas_rendu.gd`, `banc_murs_bas.tscn`).

**Effort** : S. **Sévérité** : ANECDOTIQUE.

**Statut ROADMAP** : NOUVEAU pour le CPU ; DÉJÀ-MESURÉ pour le GPU (l. 30046-30048, l. 29782-29787).

**Comment le vérifier** : `Time.get_ticks_usec()` autour de `_pousser_zone_morte_capteurs` ; `test_murs_bas_rendu.gd`.

---

### GEO-09 — Micro-allocations par image : drapeaux relus, `slugs()` reconstruit

**Où** : `iso_nuage_voxel.gd:519-522` (`poser_style`) ← `iso_volumes.gd:1619-1620` ;
`iso_materiaux.gd:83-84` ← `drapeaux_de_lancement.gd:22-27` ; `voxel_catalogue.gd:222-226,290-296,638-641` ←
`presentation_3d.gd:1340-1345`.

**Constat** :
```gdscript
# iso_volumes.gd:1618-1620 — « à chaque image », par nuage et par vue
for m: ShaderMaterial in e["mats"]:
	IsoNuageVoxel.poser_style(m, encre_voxel, relief_voxel)
# iso_nuage_voxel.gd:520-521 → IsoMateriaux.beaute_active() → DrapeauxDeLancement.present() → arguments() :
#     OS.get_cmdline_user_args() + OS.get_cmdline_args()   (deux tableaux + une concaténation par appel)
# voxel_catalogue.gd:222-226 — appelé par slug_de_la_classe(), chaque image, pour chaque corps
static func slugs() -> PackedStringArray:  var out := PackedStringArray(); for c in CLASSES: out.append(c["slug"]) ...
```
`mannequin_actif()` est mis en cache avec le commentaire « rien ne doit tourner sans servir » (`voxel_catalogue.gd:625-628`) ;
`beaute_active()`, `tenue()`, `teinte()`, `usure_essai_active()` ne le sont pas, et `slugs()` n'est pas une constante.

**Coût** : ESTIMÉ — ≈ 1 µs par lecture de drapeau (× nuages × vues, ≤ 12) et ≈ 2 µs par `slugs()` (× corps) : < 0,03 ms par
image. ANECDOTIQUE mais gratuit à corriger.

**Proposition** : `static var _beaute := -1` (comme `_mannequin_ligne`) ; `const SLUGS := [...]` dérivée une fois ; poser le
style des nuages à la création et à la bascule des bancs plutôt qu'à chaque image.

**Gain attendu** : ≈ 0,01-0,03 ms par image. **Risque** : nul (drapeaux immuables en cours de processus). **Effort** : S.
**Sévérité** : ANECDOTIQUE. **Statut ROADMAP** : NOUVEAU (le patron est déjà connu de la base).

**Comment le vérifier** : `tools/test_drapeaux.gd` (ne relit pas la ligne de commande en dehors de `DrapeauxDeLancement`) ;
`test_fumee_voxel.gd`.

---

### GEO-10 — Coûts proportionnels à la surface de carte, sans plafond ni mesure hors duel (solo, cartes d'éditeur)

**Où** : `arena_decor.gd:188` (taille `_cadre`), `peinture_iso.gd:53,79-102`, `iso_materiaux.gd:466-502`, `mur_led.gd:72-74`.

**Constat** : les niveaux solo vont jusqu'à **100×80 cases** (`chapitre_08/niveau_09` : 3 570×2 870 px de cadre ; 9 niveaux sur 100
font au moins 54×46 cases) et l'éditeur permet 128×128. Ce qui croît avec la surface :

| | Duel (910-1 190 px) | 100×80 | 128×128 |
|---|---|---|---|
| Peinture iso (RGBA8, plafonnée 4 096²) | 3,2-5,4 Mo | 39 Mo | 67 Mo |
| Décor cuit (RGBA8, **non plafonné**) | 3,2-5,4 Mo | 39 Mo | 79 Mo |
| Proximité (3 images RGBA8 transitoires) | 11-19 Mo | **128 Mo** | > 250 Mo |
| Texture LED | ≤ 0,3 Mo | ≤ 1 Mo (5 texels/case) | ≤ 1 Mo (4 texels/case) |

Chaque trace (sang, éclat, douille) déclenche un rendu `UPDATE_ONCE` de toute la peinture (`peinture_iso.gd:197-200`) : 1,1-1,4
Mpx en duel — **mesuré dans le bruit** (« de −0,37 à +1,1 ms » même forcé à chaque image, ROADMAP l. 26756-26758) —, 10,2 Mpx sur
la grande salle (≈ 8 fois plus de pixels, non mesuré). Jusqu'à 330 traces peintes (120 sangs + 90 éclats + 120 douilles).

**Coût** : PROUVÉ par arithmétique pour les surfaces ; ESTIMÉ pour les temps (× 8 sur la peinture et la proximité).

**Proposition** : plafonner la cuisson du décor (`COTE_MAX`), cacher la proximité (GEO-02), et mesurer la peinture sur la salle
8/9 (fréquence des rendus × leur durée) avant de décider d'une peinture incrémentale (`CLEAR_MODE_NEVER`, ne dessiner que la
trace neuve ; éviction ⇒ rendu complet).

**Gain attendu** : borne les pics mémoire des grandes cartes ; le reste dépend de la mesure.

**Risque** : faible pour le plafond ; la peinture incrémentale touche l'équité des faces (`lire_lumiere`) : preuve à l'image
(`test_iso_peinture_carte.gd`, `banc_peinture_en_ligne.tscn`).

**Effort** : S (plafond, cache) / M (peinture incrémentale). **Sévérité** : MINEUR (solo, éditeur).

**Statut ROADMAP** : CONNU-OUVERT en partie (mémoire de la peinture l. 26744-26745) ; le reste NOUVEAU.

**Comment le vérifier** : `banc_peinture_en_ligne.tscn` sur la salle 8/9 ; ligne `[iso] peinture retirée : N rendus en X s`
(`peinture_iso.gd:165-169`).

---

### GEO-11 — Code mort ou froid : `ColonneAtelier`, `create_tileset`, `iso_pate.gd`, `EnseigneQuiMeurt`

**Où** : `colonne_atelier.gd:1-41` ← `arena.tscn:81-84` ; `iso_pate.gd` ; `enseigne_qui_meurt.gd:101-105,177-187`.

**Constat** : `ColonneAtelier` (nœud `Habillage`) vit sous `StaticGeometry/Obstacle1` de `arena.tscn`, que `rebuild_arena` masque et
désactive (`game_state.gd:1440-1445`) : jamais dessiné, mais instancié et `queue_redraw()` à chaque lancement. `iso_pate.gd` est
le miroir CPU de la pâte, appelé par les seules suites (aucune fonction n'est dans un chemin chaud ; le jeu n'y lit que des
constantes). `EnseigneQuiMeurt._process` est coupé hors du menu (`ui.gd:6123-6124`) ; seul `_input` reste, en 6 tests `is`.

**Coût** : négligeable. **Proposition** : retirer le nœud `Habillage` de `arena.tscn` (la scène « ne sert plus qu'à documenter le
format », `game_state.gd:1438`) ; rien d'autre. **Gain** : ≈ 0. **Risque** : `tools/test_arena_matter.gd:17` précharge le
script. **Effort** : S. **Sévérité** : ANECDOTIQUE. **Statut ROADMAP** : NOUVEAU.

---

### GEO-12 — Le texte F3 de la vue iso est reconstruit CHAQUE image, panneau fermé (et `hauteur_mur_haut()` recharge le script de la géométrie à chaque appel)

**Où** : `presentation_3d.gd:523` (`etat = _decrire(voulues)`, dernière ligne de `_process`) et `:1823-1851` (`_decrire`) ;
`iso_geometrie.gd:53-61` (`_constantes_map_geometry`, `hauteur_mur_haut`) ; lecteur : `ui.gd:1917` → `Presentation3D.texte_f3`
(`presentation_3d.gd:382-386`).

**Constat** :
```gdscript
# presentation_3d.gd:523 — chaque image, panneau F3 ouvert ou non
etat = _decrire(voulues)
# :1826-1851 — 1 ligne d'en-tête + 2 lignes par vue : 3 à 5 formats « % » de 6 à 8 arguments (flottants compris), 2 str(), un PackedStringArray, « \n ».join(...)
lignes.append("%s · %s° · murs %s t · pâte %s · lightmap %s · %d bascule(s)"
	% ["scindé" if _scinde else "unique", str(_camera.tangage_deg), str(IsoGeometrie.hauteur_mur_haut()), ...])
# iso_geometrie.gd:53-61 — à CHAQUE appel
static func _constantes_map_geometry() -> Dictionary:
	var script := load(_CHEMIN_MAP_GEOMETRY) as Script
	return script.get_script_constant_map() if script != null else {}
```
`etat` n'est lu que par le panneau F3 (`ui.gd:1917`) et par des bancs/tests (`tools/banc_iso.gd:857,2239`, `banc_murs_bas.gd:489`,
`bench_framerate.gd:1201,1391`, `test_iso_vues.gd:127,734`). `hauteur_mur_haut()` et `hauteur_mur_bas()` reconstruisent un
dictionnaire des constantes de `MapGeometry` (~35 entrées, dont l'énumération `Kind`) à chaque appel ; ils servent aussi à
`build_meshes` au départ de manche.

**Coût** : PROUVÉ — exécuté à chaque image tant que la vue iso est active. ESTIMÉ — **0,02 à 0,045 ms par image** (3 à 5 formats de
chaîne, une concaténation, `get_script_constant_map()` ≈ 2-4 µs, `get_node_or_null` + `get()` ×2, `DisplayServer.window_get_size()`,
`get_visible_rect()` par vue) : 0,1 à 0,3 % d'une image à 60 fps. Ce qui est fabriqué n'est lu que sur demande.

**Proposition** : rendre `etat` paresseux — une propriété à `get` qui appelle `_decrire(_vues_voulues_memorisees)` — pour que le
texte ne se construise qu'à la lecture (F3 ouvert, banc) sans changer l'API qu'utilisent les bancs ; mémoriser les constantes de
`MapGeometry` dans une `static var` de `IsoGeometrie` (elles ne changent pas en cours de processus).

**Gain attendu** : ≈ 0,02-0,04 ms par image (ESTIMÉ) ; supprime aussi une allocation de chaînes par image (pression sur le
ramasse-miettes de `String`, non mesurée).

**Risque** : nul pour le jeu ; les lecteurs de `etat` (7 appels dans `tools/`) doivent rester valides : une propriété à `get` les
garde. `_decrire` lit `_vues`, `_scinde`, `_camera`, `_capteurs` : à l'instant de la lecture, pas de l'image — sans importance pour
un affichage de diagnostic.

**Effort** : S. **Sévérité** : ANECDOTIQUE. **Statut ROADMAP** : NOUVEAU.

**Comment le vérifier** : `Time.get_ticks_usec()` autour de `_decrire` ; `tools/test_iso_vues.gd:127,734` (lit `p.etat`).

---

## 4. Ce qui est déjà bien fait

1. **Rien n'est régénéré par image.** `VoxelCorps.poser()` est une fonction pure qui n'écrit que des transformations ; les nuages
   ne changent que des uniformes ; aucune texture n'est re-téléversée. `construire()` est gardé par l'égalité du slug
   (`presentation_3d.gd:1290`) : un corps n'est rebâti qu'au changement de classe.
2. **Géométrie partagée et fusionnée.** Une seule liste de rectangles pour collision, occluders et boîtes iso ; un `BoxMesh` et un
   matériau pour tous les murs ; 4 à 11 boîtes sur les cartes de duel. La grille d'un nuage est un `MultiMesh` partagé par type et
   par côté de caméra, taillé en dôme (un cinquième de cellules en moins) et limité aux trois faces vues.
3. **Le travail CPU lourd est payé hors action et gardé.** `IsoNuageVoxel.prechauffer()` (images de nuage au lancement),
   `Fusee.prechauffer` (textures + un quad invisible qui force la compilation du shader du voile : la bonne doctrine, à étendre —
   GEO-04), cuisson du LED mise en cache par `hash` de la carte (83 ms mesurés), variantes de shaders en cache
   (`IsoMateriaux._variantes`), drapeaux de variantes lus une fois (`mannequin_actif`).
4. **Les mesures ont servi.** Le décor d'arène a été cuit en une texture (1 850 → 261 appels, ROADMAP l. 22327) ; les accessoires
   des corps sont fusionnés (22 → 6 appels, l. 28874) ; `MurEncre` a été mesuré et reconnu « pas un second coût » ; la peinture
   iso est à la demande (0,6 rendu/s) et son coût a été chiffré dans le bruit.
5. **Une lumière pour toute la carte** (LED) plutôt qu'une par mur — contrainte des 15 lumières par item respectée et expliquée —
   et plafonniers allumés seulement près des joueurs, avec hystérésis (l'évitement du clignotement est dans le code).
6. **Les capteurs des PNJ loin du joueur sont `UPDATE_DISABLED`** (`presentation_3d.gd:1196-1200`) : le coût des figurants est borné
   par la proximité.
7. **Les gardes tiennent les invariants** : `test_iso_usure` (36 000 points contre l'ancienne formule), `test_passe_unique`
   (huit combinaisons de variantes), `test_corps_mannequin`, `test_plafonniers`, `test_mur_led`, `test_fumee_voxel`.
8. **Le noir absolu et l'équité ne sont jamais sacrifiés** : toute optimisation proposée ci-dessus est choisie pour laisser
   l'image identique (preuve au pixel déjà outillée).

---

## 5. Questions ouvertes (mesure ou décision d'Adrien)

1. **Quelle est la durée réelle du départ de manche** (`_construire_les_murs` + `_poser_peinture` + `ArenaDecor._cuire`) sur le
   Mac, et se voit-elle ? Raccourcit-elle visiblement le décompte de 3 s (`countdown_left - delta`, `game_state.gd:2122`), ou retarde-t-elle le premier RPC
   de manche en ligne ? Un
   chronométrage de 10 lignes dans `test_iso_usure.gd` (headless) et un `bench_framerate --seuil-lent 25` répondent.
2. **Combien coûte la compilation du premier nuage** (`nuage_voxel_iso`, juge, `corps_iso_profondeur` ordinaire) sur le pilote
   d'Apple ? Seule la machine d'Adrien le dit (ROADMAP l. 31299-31302).
3. **Solo grand format** : 8 plafonniers à ombres + 7 corps de PNJ (≈ +140 appels de dessin, 7 capteurs 256²) + peinture de
   10 Mpx + 330 traces, sur `chapitre_08/niveau_09` : jamais relevé (décision l. 2449). Veut-on une salle témoin dans le banc ?
4. **Quinze lumières par item** (ROADMAP l. 5332-5388) : `ArenaDecor` et `MurEncre` sont **un seul `CanvasItem` couvrant toute la
   carte** (`arena_decor.gd:319-323`, `mur_encre.gd:126-132`), alors que le sol est découpé en quadrants de 560 px. Toutes les
   lumières de la carte sont donc candidates pour ces deux items, le plafond de 15 s'y joue sur la carte entière (« les plus
   récentes en premier » : ce sont les plus anciennes qui seraient écartées — torches de joueurs, LED ou plafonniers, selon l'ordre
   de création, à relever). Pas de preuve d'artefact visible ; à vérifier avec le recensement par item (méthode de la l. 5385-5388) en solo (torches de PNJ) et pendant une rafale
   d'étincelles. NON VÉRIFIÉ.
5. **Corps détaillés par défaut (Q33)** : si `--corps-detaille` devient le défaut, +4 à +6 appels par corps et 3,5-6 % mesurés
   au Parasite (ramenés à ≈ 2,4 %, ROADMAP l. 28965-28971) ; le choix des options GEO-06 se refait alors.
6. **GEO-01** : accepte-t-on que le liseré du corps de soi suive la lumière avec une image de retard (30 Hz) ?

## 6. Pointeurs hors périmètre (pour les agents voisins)

- `iso_volumes.gd:1280-1296`, `:1328-1339` : `ImmediateMesh.clear_surfaces()` + `surface_begin` refaits **chaque image** pendant la vie
  de l'onde de mort (`SEGMENTS+1` × 2 sommets) et de la toile du voile (2 × points de la `Line2D`).
- `iso_volumes.gd:1496-1538` : `PackedFloat32Array` neuf de `instance_count × 16` et `mm.buffer = tampon` chaque image tant que
  des traces de poudre existent — seulement sous `--nappes-voxels` (éteint par défaut).
- `presentation_3d.gd:896-900`, `:1210-1214` : `"opacite_%d" % (vue_id + 1)` (chaîne neuve ×4) et un tableau littéral de
  matériaux par corps et par image ; la boucle est comptée au texte par `test_corps_mannequin.gd:137-139`.
- `presentation_3d.gd:820-824` : `"canevas_%d_x" % n` (et `_y`, `_o`, `taille_%d`) reformatés pour CHAQUE matériau de `_materiaux()` (murs, 2 sols,
  tous les corps) et chaque vue, à chaque image : les quatre noms sont constants par vue — à hisser hors de la boucle.
- `presentation_3d.gd:2218-2221` : `get_tree().get_nodes_in_group("wall_impact")` chaque image (jusqu'à 90 nœuds) pour détecter un
  changement ; `_mat_sols` compte toujours 2 matériaux, même en vue unique (`:1890-1897`).
- `lumieres_iso.gd` (lumière 3D éteinte par défaut) relirait la même liste de lampes que `MannequinIso.lampes_du_jeu` : si la
  lumière 3D est un jour allumée, le balayage serait fait deux fois par image.
