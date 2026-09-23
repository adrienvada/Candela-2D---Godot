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


## ISO13, lot B — L'ENCRE EN ESSAI (`--encre-essai`, éteint par défaut) : des hachures dans la pénombre du lavis
## (`pate_hachures`, voir `iso_pate.gdshaderinc`) sur le sol, les murs et les corps, et l'encre des arêtes des murs plus
## épaisse et plus noire. Le contour des personnages est celui du mannequin (`--mannequin`). Une planche d'essai, à côté de
## l'illustration de l'entraînement ; rien n'est allumé en jeu avant l'avis d'Adrien et la mesure de cadence.
const DRAPEAU_ENCRE_ESSAI := "--encre-essai"
const HACHURES_ESSAI := 0.7
const ENCRE_ARETE_PX_ESSAI := 2.4
const ENCRE_ARETE_RESTE_ESSAI := 0.12
## Le contour des personnages (`corps_iso_contour.gdshader`), en pixels du monde : l'épaisseur de l'essai, et la seconde
## essayée sur la planche (ordre de la session cloud, 00:56 : « à deux épaisseurs »).
const CONTOUR_PX_ESSAI := 1.0
const CONTOUR_PX_EPAIS := 2.0


static func encre_essai_active() -> bool:
	return OS.get_cmdline_user_args().has(DRAPEAU_ENCRE_ESSAI)


## Allume ou éteint l'encre d'essai sur un matériau iso (sol, mur ou corps) : les hachures partout, l'arête épaisse sur un
## mur. Les bancs y basculent dans la même partie, au même instant.
static func poser_encre_essai(materiau: ShaderMaterial, allumee: bool, mur := false) -> void:
	materiau.set_shader_parameter("pate_hachures", HACHURES_ESSAI if allumee else 0.0)
	if mur and beaute_active():
		materiau.set_shader_parameter("encre_arete_px", ENCRE_ARETE_PX_ESSAI if allumee else ENCRE_ARETE_PX)
		materiau.set_shader_parameter("encre_arete_reste", ENCRE_ARETE_RESTE_ESSAI if allumee else ENCRE_ARETE_RESTE)


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
	materiau.set_shader_parameter("temperature", (TEMPERATURE_GRADUEE if active else 0.0))
	materiau.set_shader_parameter("temperature_seuil_bas", TEMPERATURE_SEUIL_BAS)
	materiau.set_shader_parameter("temperature_seuil_haut", TEMPERATURE_SEUIL_HAUT if active else 0.0)
	materiau.set_shader_parameter("neutre_avant_pate", 1.0 if active else 0.0)
	materiau.set_shader_parameter("pied", PIED_FACE_PX)
	materiau.set_shader_parameter("lambert_plancher", LAMBERT_PLANCHER if active else 1.0)
	materiau.set_shader_parameter("lambert_pas_px", LAMBERT_PAS_PX)
	materiau.set_shader_parameter("contact_px", CONTACT_PX if active else 0.0)
	materiau.set_shader_parameter("contact_reste", CONTACT_RESTE)
	# Sans beauté, aucun muret : tous les dessus redeviennent noirs, comme avant ISO7.
	materiau.set_shader_parameter("seuil_muret_px", SEUIL_MURET_PX if active else 0.0)
	if encre_essai_active():
		poser_encre_essai(materiau, true, true)


## Pose l'encre des arêtes sur le matériau d'un corps voxel (`corps_iso.gdshader`, tenu par ISO Corps).
## Tant que le shader ne déclare pas `encre_arete`, Godot ignore le paramètre : ce crochet ne fait
## rien avant que la session ISO Corps n'ait branché `pate_encre_boite` (contrat du 2026-09-15).
static func accorder_corps(materiau: ShaderMaterial) -> void:
	var active := beaute_active()
	materiau.set_shader_parameter("encre_arete", ENCRE_VOXEL_PX if active else 0.0)
	materiau.set_shader_parameter("encre_reste", ENCRE_VOXEL_RESTE)
	# ISO7b — le modelé des corps : par la caméra, jamais par le gradient (voir `modele_du_corps`).
	materiau.set_shader_parameter("modele", 1.0 if active else 0.0)
	if encre_essai_active():
		poser_encre_essai(materiau, true)


## ISO10, 1f — la lumière d'une face lue SANS la peinture du sol (`mur_iso.gdshader`, `lire_lumiere`) : lightmap ×
## référence ÷ max(peinture, plancher), canal par canal. La référence est la couleur moyenne du sol dessiné
## (`CandelaTileSet.SOL_DESSIN_A` et `_B`, en linéaire : 0,019 et 0,027, l'albédo mesuré sur la bande de 1f valant 0,026) :
## sur un sol propre la face lit ce qu'elle lisait, sous une tache elle lit la même chose. Le plancher se donne en valeur
## AFFICHÉE (0,05, session cloud) : un plancher de 0,05 LINÉAIRE couvrait tout le sol (mesure du 2026-09-15, deuxième passage de `--plan=loupe-peinture`).
const PEINTURE_PLANCHER_AFFICHE := 0.05


static func peinture_reference() -> Vector3:
	var a := CandelaTileSet.SOL_DESSIN_A.srgb_to_linear()
	var b := CandelaTileSet.SOL_DESSIN_B.srgb_to_linear()
	return Vector3(a.r + b.r, a.g + b.g, a.b + b.b) * 0.5


static func peinture_plancher() -> float:
	return Color(PEINTURE_PLANCHER_AFFICHE, 0.0, 0.0).srgb_to_linear().r


## Miroir de `lire_lumiere` (`mur_iso.gdshader`) : la suite y vérifie l'équité — une face lit la même lumière avec ou sans
## tache — et le noir absolu.
static func lumiere_lue(lightmap: Vector3, peinture: Vector3) -> Vector3:
	var ref := peinture_reference()
	var plancher := peinture_plancher()
	return Vector3(minf(lightmap.x * ref.x / maxf(peinture.x, plancher), 1.0),
		minf(lightmap.y * ref.y / maxf(peinture.y, plancher), 1.0),
		minf(lightmap.z * ref.z / maxf(peinture.z, plancher), 1.0))


## Pose la peinture sur le matériau des murs. `texture` nulle (vue éteinte) ou sans beauté : la face relit la lightmap
## telle quelle, comme avant 1f. La référence et le plancher ne se posent PAS en valeur : ils sont peints dans la texture
## (`peinture_iso.gd`, étalons) et `mur_iso` les y lit à `etalon_px` et `plancher_px`, dans l'espace de couleur de la
## peinture elle-même. `peinture_reference()` et `peinture_plancher()` en restent le miroir en linéaire, pour la suite.
static func accorder_peinture(materiau: ShaderMaterial, texture: Texture2D, cadre: Rect2,
		etalon_px := Vector2.ZERO, plancher_px := Vector2.ZERO) -> void:
	materiau.set_shader_parameter("peinture", texture)
	materiau.set_shader_parameter("peinture_active", beaute_active() and texture != null and cadre.has_area())
	materiau.set_shader_parameter("peinture_origine_px", cadre.position)
	materiau.set_shader_parameter("peinture_taille_px", cadre.size if cadre.has_area() else Vector2.ONE)
	materiau.set_shader_parameter("peinture_etalon_px", etalon_px)
	materiau.set_shader_parameter("peinture_plancher_px", plancher_px)


## ISO7, étape 6 — la température de la lumière vue sur le sol et les murs (`pate_temperature`).
## Pourquoi il en faut une : la torche est déjà chaude en 2D (`Charte.HALOGENE`, 0,98 / 0,91 / 0,80),
## mais la pâte D désature de 35 % vers la luminance et la rend grise. 0,5 rend une partie de cette
## chaleur, luminance gardée : aucune bande ne bascule, et une lumière colorée garde sa teinte.
const TEMPERATURE := 0.5

## ISO7b — la température graduée par la luminance AFFICHÉE (`pate_temperature_graduee`) : braise sous
## `TEMPERATURE_SEUIL_BAS`, teinte chaude d'ISO7 au-dessus de `TEMPERATURE_SEUIL_HAUT`. La planche E1 est
## chaude au bord du bain (95/255, r/g 1,49) et plus neutre au centre (179/255, r/g 1,19) ; le jeu est bien
## plus sombre qu'elle, d'où des seuils plus bas que ses valeurs. Force relevée à 0,8 : c'est la couleur
## qui porte le bain d'E1.
const TEMPERATURE_GRADUEE := 0.8
const TEMPERATURE_SEUIL_BAS := 0.08
const TEMPERATURE_SEUIL_HAUT := 0.45

## ISO7b — la face prend la direction de la lumière (`mur_iso.gdshader`, gradient de la lightmap devant elle).
## Plancher 0,4 : une face de profil garde 40 % de la lumière qu'elle reçoit, pour rester lisible (brief :
## 0,35 à 0,45). Pas d'une tuile : le gradient se lit à l'échelle d'une tuile, pas du grain de la lightmap.
## ISO7b — où une face lit sa lumière : 12 px devant elle, au-delà de l'encre du pied de `MurEncre`. À 8 px
## (`Presentation3D.PIED_PX`), la face portait des rayures au pas des hachures. Reposé ici, après la présentation.
## ISO10, 1b — l'encre du pied est un lavis qui s'arrête à 10,5 px de la ligne du mur (trait + `LAVIS_PORTEE`) ; les
## hachures qu'il remplace allaient en fait jusqu'à 13,1 px (l'ancien compte, 9,6, oubliait le décalage du trait).
const PIED_FACE_PX := 12.0

## ⚠️ **1 : le Lambert des faces est ÉTEINT** (décision de la session cloud, 2026-09-15 14:21, sur la mesure du banc).
## Le gradient de la lightmap lit le BORD de la tache de lumière d'une torche, pas la direction de sa source : à 3 tuiles
## il posait 0,67 sur une face rasée et 0,70 sur une face visée de face, et à 1 tuile il s'inversait (0,83 contre 0,49).
## Une valeur de lumière par point ne dit pas d'où elle vient ; une direction fausse vaut moins qu'aucune. Le calcul reste
## dans `mur_iso.gdshader` (plancher < 1 le rallume), pour la lightmap de direction proposée après le test final.
const LAMBERT_PLANCHER := 1.0
const LAMBERT_PAS_PX := 35.0

## ISO7b — l'ombre de contact au pied des faces : 6 px de monde, 55 % gardés au ras du sol.
const CONTACT_PX := 6.0
const CONTACT_RESTE := 0.55

## ISO10, 1d — l'ombre de contact des corps au sol (`sol_iso.gdshader`, `contact_des_corps`) : un disque plein sous le
## pied, fondu jusqu'à son rayon. Premier essai à une demi-tuile et 0,55 (le reste du pied des murs) : le corps, large
## d'environ une tuile à l'écran, couvrait presque tout le disque, et l'écart ne se lisait qu'amplifié six fois. Trois
## quarts de tuile et 0,5 : plus bas, matière, joint des dalles et contact ensemble passeraient sous le plancher de 0,2
## que garde `test_iso_beaute` (0,72 × 0,6 × 0,5 = 0,215). À juger au tour 2 de loupe.
const CONTACT_CORPS_RAYON_TUILES := 0.75
const CONTACT_CORPS_RESTE := 0.5

## ISO7b — des dalles de deux tuiles au sol, joint fin ; la trame de 35 px de la lightmap neutralisée.
const DALLE_PX := 70.0
const JOINT_DALLE_PX := 1.2
const JOINT_DALLE_RESTE := 0.6
## L'exposant du rapport des deux tons du damier (voir `sol_iso.gdshader`). **0 : le damier est gardé.**
## ⚠️ Mesuré au banc (2026-09-15, 11:10, cadrage e1) : ramener la case claire au ton de la sombre AVANT la pâte
## (exposant 2,2) faisait passer sa luminance sous les seuils de bande de la pâte D — le halo d'une fusée
## descendait d'une bande entière (lumière éclairée moyenne 45,9 → 33,3) et le damier revenait à l'envers.
## Effacer le damier sans décaler les seuils de lumière du jeu n'est pas possible ici ; il reste la référence
## spatiale du joueur (décision d'Adrien, 2026-09-11). Seuls le joint de 35 px et les dalles changent.
const TON_EXPOSANT := 0.0


## Pose la matière du sol sur le matériau d'un sol (`sol_iso.gdshader`). Sans beauté, force et
## température à zéro : le sol d'ISO1, formule pour formule.
static func accorder_sol(materiau: ShaderMaterial) -> void:
	var active := beaute_active()
	materiau.set_shader_parameter("texture_sol", TEXTURE_SOL)
	materiau.set_shader_parameter("periode_sol_px", PERIODE_SOL_PX)
	materiau.set_shader_parameter("force_matiere", FORCE_MATIERE_SOL if active else 0.0)
	materiau.set_shader_parameter("temperature", TEMPERATURE_GRADUEE if active else 0.0)
	materiau.set_shader_parameter("temperature_seuil_bas", TEMPERATURE_SEUIL_BAS)
	materiau.set_shader_parameter("temperature_seuil_haut", TEMPERATURE_SEUIL_HAUT if active else 0.0)
	materiau.set_shader_parameter("neutre_avant_pate", 1.0 if active else 0.0)
	materiau.set_shader_parameter("dalles", 1.0 if active else 0.0)
	materiau.set_shader_parameter("tuile_px", float(CandelaTileSet.TILE_SIZE.x))
	materiau.set_shader_parameter("joint_2d_px", 1.0)
	materiau.set_shader_parameter("ton_a", CandelaTileSet.SOL_DESSIN_A.get_luminance())
	materiau.set_shader_parameter("ton_b", CandelaTileSet.SOL_DESSIN_B.get_luminance())
	# Linéarisée par `source_color` : le rapport des tons s'y lit à la puissance 2,2 (à trancher au banc).
	materiau.set_shader_parameter("ton_exposant", TON_EXPOSANT)
	materiau.set_shader_parameter("dalle_px", DALLE_PX)
	materiau.set_shader_parameter("joint_dalle_px", JOINT_DALLE_PX)
	materiau.set_shader_parameter("joint_dalle_reste", JOINT_DALLE_RESTE)
	# Sans beauté, aucune ombre de contact : le sol d'ISO1. Les pieds et leur force sont posés à chaque image par la présentation.
	materiau.set_shader_parameter("contact_corps_rayon_px",
		CONTACT_CORPS_RAYON_TUILES * float(CandelaTileSet.TILE_SIZE.x) if active else 0.0)
	materiau.set_shader_parameter("contact_corps_reste", CONTACT_CORPS_RESTE)
	if encre_essai_active():
		poser_encre_essai(materiau, true)


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


## ISO7b — miroir du facteur de Lambert de `mur_iso.gdshader`, depuis les quatre lectures de luminance :
## au pied (`l_0`), une tuile devant (`l_avant`), une tuile de chaque côté le long de la face (`l_t1`, `l_t2`).
static func lambert(l_0: float, l_avant: float, l_t1: float, l_t2: float, plancher: float = LAMBERT_PLANCHER) -> float:
	if plancher >= 1.0:
		return 1.0
	var g := Vector2(l_avant - l_0, 0.5 * (l_t1 - l_t2))
	var norme := g.length()
	var face_lampe := clampf(g.x / norme, 0.0, 1.0) if norme > 0.00001 else 1.0
	var certitude := smoothstep(0.05, 0.3, norme / maxf(maxf(l_0, l_avant), 0.02))
	return lerpf(1.0, maxf(plancher, face_lampe), certitude)


## ISO7b — les facteurs du modelé des corps, tenus par la CAMÉRA (lacet 0 : seuls le dessus et la face sud se voient).
const MODELE_DESSUS := 1.15
const MODELE_FACE_SUD := 0.9
const MODELE_AUTRES := 1.0


## ISO7b — miroir de `modele_du_corps` (`corps_iso.gdshader`) : le facteur de modelé d'une face de normale `n` (monde).
## ⚠️ **Aucune lecture du gradient** (décision de la session cloud, 2026-09-15 14:21) : le côté lampe à 1,25 et le dos au
## plancher venaient du gradient de la lightmap, qui lit le bord d'une tache de lumière et non sa source — un corps qui
## traverse un cône voyait son côté clair sauter. Restent le dessus plus clair que la face sud, qui tiennent à la caméra ;
## les autres faces valent 1, et la moyenne des faces vues reste la lumière du capteur.
static func modele_du_corps(n: Vector3) -> float:
	if n.y > 0.5:
		return MODELE_DESSUS
	if n.z > 0.5 and absf(n.y) <= 0.5:
		return MODELE_FACE_SUD
	return MODELE_AUTRES


## Les textures du catalogue, pour la suite : chemin → texture.
static func textures() -> Dictionary:
	return {TEXTURE_FACE_MUR.resource_path: TEXTURE_FACE_MUR, TEXTURE_SOL.resource_path: TEXTURE_SOL}
