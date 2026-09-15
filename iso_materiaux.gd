## IsoMateriaux — le catalogue des matériaux de la vue isométrique (chantier ISO7 Beauté).
##
## ## Ce qu'il est
##
## L'endroit UNIQUE où la vue iso apprend quelle matière porte quelle surface : textures
## (préchargées), périodes de répétition en pixels de monde, forces d'encre. `Presentation3D`
## crée ses matériaux et les passe ici (`accorder_mur`, `accorder_sol`) ; elle ne connaît aucun
## chemin d'image.
##
## ## La règle que tout ce qui est ici respecte
##
## **Une matière est un FACTEUR de la lumière, jamais une lumière.** Chaque texture est un
## niveau de gris dans [`PLANCHER`, 1] (fabriqué par `tools/fabrique_textures_iso.py`) que le
## shader MULTIPLIE par la lumière reçue — lue dans la lightmap du joueur, la seule vérité de
## lumière du jeu. D'où les deux propriétés que la suite `tools/test_iso_beaute.gd` prouve :
## - **noir absolu** : 0 × facteur = 0, aucune matière ne se voit sans lumière ;
## - **pas d'information de plus** : le facteur est borné par le bas, donc un point éclairé
##   reste éclairé ; et il ne dépend que du LIEU (coordonnées du monde), identique pour les deux
##   joueurs et les deux machines.
class_name IsoMateriaux
extends RefCounted

## Le miroir processeur de la pâte : l'encre des arêtes y vit, une seule formule pour tous.
const IsoPateMiroir := preload("res://iso_pate.gd")

## La face des murs hauts et des murets : grandes pierres appareillées (source : `face_mur_01_plat.jpg`,
## ISO Assets `5f1f046`, réduite, tuilée et mise en facteur par `tools/fabrique_textures_iso.py`).
const TEXTURE_FACE_MUR := preload("res://assets/iso/face_mur.png")

## Le sol : béton, lavis et taches, SANS joint — le damier de 35 px vient de la lightmap et reste la
## seule grille (source : `sol_01_plat.jpg`, ISO Assets `5f1f046`, réduite et mise en facteur).
const TEXTURE_SOL := preload("res://assets/iso/sol.png")

## Le facteur le plus bas qu'une texture de matière peut porter (110/255, `--plancher` de la
## fabrique) : la tache la plus sombre garde 43 % de la lumière.
const PLANCHER := 110.0 / 255.0

## Une répétition du sol tous les quatre pas de tuile : les taches de la source tombent à ~30 px de
## monde, et la répétition ne s'aligne sur aucun motif du damier (période 140 contre 35 : une tache
## revient sur la même case une fois sur quatre, jamais sur la voisine).
const PERIODE_SOL_PX := 140.0
## Le sol porte déjà ses dalles d'encre depuis la lightmap : sa matière est plus discrète que celle
## des murs, qui n'ont rien d'autre.
const FORCE_MATIERE_SOL := 0.5

## Une répétition de la face de mur tous les deux pas de tuile : les grands coups de lavis de
## la source tombent alors à ~20 px de monde, lisibles comme matière et non comme objets.
const PERIODE_FACE_MUR_PX := 70.0
## La force de la matière sur une face : 0, face nue (ISO1) ; 1, la texture entière.
const FORCE_MATIERE_MUR := 0.8

## L'encre des arêtes : la largeur du trait en pixels de monde, et ce qu'il garde de la lumière
## (0 : noir d'encre). « Un mur n'est pas une surface, c'est une masse cernée d'un filament »
## (Adrien, 2026-08-25) : en iso, le filament est l'arête.
const ENCRE_ARETE_PX := 1.6
const ENCRE_ARETE_RESTE := 0.25
## Le plancher de l'encre, en valeur affichée (16/255) : sous lui, une arête n'est pas encrée. Au banc, une
## face à 21/255 tombait à 1/255 sous l'encre — une lumière réelle effacée (`pate_matiere_et_encre`).
const ENCRE_PLANCHER_AFFICHE := 16.0 / 255.0

## L'encre des arêtes des voxels (corps, objets, leurre) : plus fine que celle des murs — un corps
## fait 20 px de large, un trait de mur l'aurait noyé —, et plus claire, pour que la lumière du
## capteur lise encore le modelé. Passée au shader des corps par `accorder_corps` (contrat avec
## ISO Corps : uniforms `encre_arete` et `encre_reste`, défaut 0 = aucun effet).
const ENCRE_VOXEL_PX := 0.9
const ENCRE_VOXEL_RESTE := 0.35

## Le liseré du sommet d'un mur haut : largeur en pixels de monde. Le sommet reste une masse
## noire ; seul son bord prend la lumière de la face qu'il couronne.
const LISERE_SOMMET_PX := 2.4

## Sous cette hauteur (en pixels de monde), une boîte est un MURET : son dessus lit la lightmap à
## sa propre case — les hachures que la vue de dessus y dessine sous la lumière (jalon H-MB0).
## Entre le muret (0,40 tuile, 14 px) et le mur haut (1,25 tuile, 43,75 px).
const SEUIL_MURET_PX := 26.0


## `--sans-beaute` : les matériaux d'ISO1 à ISO5, pour l'« avant » des bancs et des planches. Lu à
## l'exécution, jamais écrit dans un réglage : ce n'est pas un choix du joueur.
const DRAPEAU_SANS_BEAUTE := "--sans-beaute"


static func beaute_active() -> bool:
	return not OS.get_cmdline_user_args().has(DRAPEAU_SANS_BEAUTE)


## Pose la matière des murs sur le matériau commun des boîtes (`mur_iso.gdshader`). Sans beauté,
## force, encre et liseré à zéro : le mur d'ISO1, formule pour formule.
static func accorder_mur(materiau: ShaderMaterial) -> void:
	var active := beaute_active()
	materiau.set_shader_parameter("texture_face", TEXTURE_FACE_MUR)
	materiau.set_shader_parameter("periode_face_px", PERIODE_FACE_MUR_PX)
	materiau.set_shader_parameter("force_matiere", FORCE_MATIERE_MUR if active else 0.0)
	materiau.set_shader_parameter("encre_arete_px", ENCRE_ARETE_PX if active else 0.0)
	materiau.set_shader_parameter("encre_arete_reste", ENCRE_ARETE_RESTE)
	materiau.set_shader_parameter("encre_plancher_affiche", ENCRE_PLANCHER_AFFICHE)
	materiau.set_shader_parameter("lisere_sommet_px", LISERE_SOMMET_PX if active else 0.0)
	materiau.set_shader_parameter("temperature", TEMPERATURE if active else 0.0)
	# Sans beauté, aucun muret : tous les dessus redeviennent noirs, comme avant ISO7.
	materiau.set_shader_parameter("seuil_muret_px", SEUIL_MURET_PX if active else 0.0)


## Pose l'encre des arêtes sur le matériau d'un corps voxel (`corps_iso.gdshader`, tenu par ISO Corps).
## Tant que le shader ne déclare pas `encre_arete`, Godot ignore le paramètre : ce crochet ne fait
## rien avant que la session ISO Corps n'ait branché `pate_encre_boite` (contrat du 2026-09-15).
static func accorder_corps(materiau: ShaderMaterial) -> void:
	var active := beaute_active()
	materiau.set_shader_parameter("encre_arete", ENCRE_VOXEL_PX if active else 0.0)
	materiau.set_shader_parameter("encre_reste", ENCRE_VOXEL_RESTE)


## ISO7, étape 6 — la température de la lumière vue sur le sol et les murs (`pate_temperature`).
## Pourquoi il en faut une : la torche est déjà chaude en 2D (`Charte.HALOGENE`, 0,98 / 0,91 / 0,80),
## mais la pâte D désature de 35 % vers la luminance et la rend grise. 0,5 rend une partie de cette
## chaleur, luminance gardée : aucune bande ne bascule, et une lumière colorée garde sa teinte.
const TEMPERATURE := 0.5


## Pose la matière du sol sur le matériau d'un sol (`sol_iso.gdshader`). Sans beauté, force et
## température à zéro : le sol d'ISO1, formule pour formule.
static func accorder_sol(materiau: ShaderMaterial) -> void:
	var active := beaute_active()
	materiau.set_shader_parameter("texture_sol", TEXTURE_SOL)
	materiau.set_shader_parameter("periode_sol_px", PERIODE_SOL_PX)
	materiau.set_shader_parameter("force_matiere", FORCE_MATIERE_SOL if active else 0.0)
	materiau.set_shader_parameter("temperature", TEMPERATURE if active else 0.0)


## La grille des murs d'une carte, pour que l'encre et le liseré ne tombent que sur les VRAIS
## bords de la masse (voir l'en-tête de `mur_iso.gdshader`) : une case par tuile, bordure de
## `MapGeometry.BORDER` comprise, R = mur haut, G = muret. Même source que les boîtes
## (`MapGeometry.build_grid`), donc la même masse que la collision et les occluders.
static func image_grille(data: Dictionary) -> Image:
	var hauts := MapGeometry.build_grid(data, MapGeometry.Kind.WALLS)
	var kinds: Dictionary = MapGeometry.Kind
	var bas: Array = MapGeometry.build_grid(data, kinds["LOW_WALLS"]) if kinds.has("LOW_WALLS") else []
	var largeur := hauts.size()
	var hauteur := (hauts[0] as Array).size() if largeur > 0 else 0
	var image := Image.create_empty(maxi(1, largeur), maxi(1, hauteur), false, Image.FORMAT_RGB8)
	for x in largeur:
		for y in hauteur:
			var h := 1.0 if hauts[x][y] else 0.0
			var b := 1.0 if not bas.is_empty() and bas[x][y] else 0.0
			image.set_pixel(x, y, Color(h, b, 0.0))
	return image


## Pose la grille des murs de la carte `data` sur le matériau des murs.
static func accorder_grille(materiau: ShaderMaterial, data: Dictionary) -> void:
	var image := image_grille(data)
	var tuile := float(CandelaTileSet.TILE_SIZE.x)
	materiau.set_shader_parameter("grille_murs", ImageTexture.create_from_image(image))
	materiau.set_shader_parameter("grille_active", true)
	materiau.set_shader_parameter("grille_origine_px", -Vector2.ONE * float(MapGeometry.BORDER) * tuile)
	materiau.set_shader_parameter("grille_cases", Vector2(image.get_size()))
	materiau.set_shader_parameter("tuile_px", tuile)


# ---------------------------------------------------------------------------
# MIROIR PROCESSEUR de `mur_iso.gdshader` — formule pour formule, pour la suite
# ---------------------------------------------------------------------------
# ⚠️ Toute retouche du shader se fait AUSSI ici (même règle que `iso_pate.gd`). La suite
# `tools/test_iso_beaute.gd` y balaie l'invariant du noir absolu ; le GPU se vérifie au pixel
# au banc `tools/banc_iso_beaute.gd`.

## 1 sur le trait (à moins de `largeur` du bord), 0 au-delà — `pate_trait_de_bord` de la pâte, dont
## le miroir vit dans `iso_pate.gd` : une seule formule.
static func trait_de_bord(distance: float, largeur: float, aa: float) -> float:
	return IsoPateMiroir.trait_de_bord(distance, largeur, aa)


## La face verticale : la lumière pâteuse lue au pied, fois la matière (texture brute
## `matiere_brute` mêlée par `force`), fois l'encre de l'arête (`encre` ∈ [0, 1], 1 sur le trait).
static func face(lumiere_pateuse: Vector3, matiere_brute: float, force: float, encre: float,
		reste: float = ENCRE_ARETE_RESTE) -> Vector3:
	var matiere := lerpf(1.0, matiere_brute, force)
	return IsoPateMiroir.matiere_et_encre(lumiere_pateuse, matiere, reste, clampf(encre, 0.0, 1.0), ENCRE_PLANCHER_AFFICHE)


## Le sommet d'un mur haut : noir, sauf le liseré (`lisere` ∈ [0, 1]) qui prend la lumière de la face.
static func sommet(lumiere_de_la_face: Vector3, lisere: float) -> Vector3:
	return IsoPateMiroir.facteur(lumiere_de_la_face, clampf(lisere, 0.0, 1.0)) if lisere > 0.0 else Vector3.ZERO


## Le dessus d'un muret : la lumière à sa case, fois l'encre de son bord.
static func dessus_muret(lumiere_de_la_case: Vector3, encre: float, reste: float = ENCRE_ARETE_RESTE) -> Vector3:
	return IsoPateMiroir.matiere_et_encre(lumiere_de_la_case, 1.0, reste, clampf(encre, 0.0, 1.0), ENCRE_PLANCHER_AFFICHE)


## Le sol (`sol_iso.gdshader`) : la lumière pâteuse au point, fois la matière.
static func sol(lumiere_pateuse: Vector3, matiere_brute: float, force: float) -> Vector3:
	return IsoPateMiroir.facteur(lumiere_pateuse, lerpf(1.0, matiere_brute, force))


## Les textures du catalogue, pour la suite : chemin → texture.
static func textures() -> Dictionary:
	return {TEXTURE_FACE_MUR.resource_path: TEXTURE_FACE_MUR, TEXTURE_SOL.resource_path: TEXTURE_SOL}
