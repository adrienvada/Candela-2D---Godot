class_name IsoNuageVoxel
extends RefCounted

## Les nuages en voxels de la vue iso — chantier « Gadgets en volume » (GV1), À L'ESSAI (`--fumee-voxel-essai`).
##
## Adrien, 2026-09-30 : « J'aimerais également que tous les gadgets (je me souviens de la fumée occultante) soient
## davantage en 3D. Là on est pris entre le graphisme BD et la 3D voxel. Il faut quelque chose de plus uniforme avec le
## nouveau graphisme. » Premier chantier : la fumée occultante — la suie du Fumiste, la poussière du Terrassier, la fumée de
## la fusée. Aujourd'hui des couches horizontales qui recopient la lightmap (`volume_iso.gdshader`) ; à l'essai, un tas de
## cubes (`nuage_voxel_iso.gdshader`, où tout est expliqué : densité, noir absolu, ordre de dessin).
##
## Ce fichier ne fait que la GÉOMÉTRIE et les RÉGLAGES : la grille de cellules d'un nuage, rangée pour une caméra, et les
## uniformes lus sur le nuage 2D à chaque image. `IsoVolumes` décide quand un nuage est en voxels (le drapeau) et tient ses
## nœuds, comme ceux des couches ; le juge du masque est le sien.
##
## ## Une grille par TYPE de nuage, par taille de voxel et par côté de caméra — partagée
##
## Une grille est un `MultiMesh` : un appel de dessin, des milliers de cubes. Elle ne dépend que du rayon maximal du nuage, de
## sa hauteur, du côté du voxel et de l'ordre de la caméra : toutes les suies du monde partagent la même, et un nuage neuf ne
## coûte qu'un nœud. Son origine est calée sur la grille du monde (un multiple du voxel) : deux nuages voisins ont des cubes
## alignés, comme les dalles et les murs.
##
## ⚠️ **Aucun nom de classe du jeu** (`Fusee`, `GameState`, `Gadget*`) : ils nomment des autoloads, et une suite headless
## compile la présentation avant eux (piège d'ISO4). Tout se lit par propriété.

const TUILE := 35.0
## Les deux variantes à l'essai : des voxels d'un quart de tuile (8,75 px : la tête, le torse d'un corps) ou d'un huitième
## (4,4 px : un bras, une jambe). Le premier a été choisi comme défaut du drapeau — voir la ROADMAP, section GV.
const VARIANTES := {"gros": TUILE / 4.0, "fin": TUILE / 8.0}
const VARIANTE_PAR_DEFAUT := "gros"
## Par nuage : sa densité de voxels (× la densité lue), l'opacité d'un cube, et son rayon MAXIMAL en pixels de monde (la
## grille le couvre ; la densité fait le reste). La suie est « dense et petite », la poussière « large et mince » — mais
## pas à 0,5 : sous la torche, les côtés de ses marches, à moitié transparents sur un sol aussi clair, ne se voyaient plus
## (troisième passage du banc). Le rayon de la fusée : `FuseeModele.RAYON_FUMEE` × `FUMEE_GONFLE` (250 px), recopié —
## `fusee_modele.gd` compile sans autoload, mais le lire ici ferait dépendre la présentation du modèle ;
## `tools/test_fumee_voxel.gd` garde l'égalité.
const NUAGES := {
	"cartouche_suie": {"densite": 1.0, "alpha": 0.9, "rayon_max": 92.0},
	"poussiere": {"densite": 0.72, "alpha": 0.7, "rayon_max": 168.0},
	"fusee": {"densite": 1.0, "alpha": 0.82, "rayon_max": 250.0},
}
## Le modelé des faces et l'encre des arêtes (en valeur affichée) : le dessus porte la lumière lue ; les deux côtés vus
## l'assombrissent, à gauche et à droite de l'écran. L'encre est celle des corps (`IsoMateriaux.ENCRE_VOXEL_PX`), plus
## claire — un nuage n'est pas un objet dur — et ne borde que les CÔTÉS : encré, chaque dessus dessinait son carré, et le
## nuage devenait une grille (voir le shader).
const FACE_DESSUS := 1.0
const FACE_GAUCHE := 0.8
const FACE_DROITE := 0.62
const ENCRE_RESTE := 0.55
const SEUIL_TAILLE := 0.1
## La densité où un cube remplit sa case : au-delà, les cubes du corps du nuage sont pleins et jointifs (voir le shader).
const PLEIN_TAILLE := 0.45
## Le cœur plein du profil radial des cubes (celui des couches : 0,45) et le rayon de la lumière lissée (celui des couches :
## 0,18 × le rayon) — voir `nuage_voxel_iso.gdshader`. 1 : AUCUN profil, les cubes vont jusqu'au bord de l'image. La masse
## reste dessinée au sol (en aplat) : partout où son image a de l'alpha sans cube au-dessus, on la voyait déborder en liseré
## autour du tas (0,45 puis 0,7 aux deux premiers passages du banc).
const COEUR := 1.0
const LISSAGE := 0.18
## Le dôme : en haut du nuage, son rayon est resserré de 22 % (celui des couches, `IsoVolumes._poser_couches`, et du shader).
const RESSERRE := 0.22

const CHEMIN_SHADER := "res://nuage_voxel_iso.gdshader"
## Chargé au premier nuage en voxels, jamais avant : sans le drapeau, le jeu ne charge pas ce shader.
static var _shader: Shader = null
static var _shader_fusee: Shader = null
## Les grilles partagées : "clé" → MultiMesh ; et les maillages de trois faces par côté de caméra.
static var _grilles := {}
static var _mailles := {}


static func shader(fusee: bool) -> Shader:
	if _shader == null:
		_shader = load(CHEMIN_SHADER) as Shader
		_shader_fusee = IsoMateriaux.variante_definie(_shader, "NUAGE_FUSEE")
	return _shader_fusee if fusee else _shader


## L'APLAT d'une masse de nuage (suie, poussière), pendant l'essai : la même image — même taille, même alpha, donc même
## forme et même présence —, peinte de sa couleur moyenne (pondérée par l'alpha) au lieu du dessin encré.
##
## ⚠️ **Pourquoi la masse 2D change d'image sous l'essai, et rien d'autre.** Au premier passage du banc, les traits d'encre
## du dessin BD restaient visibles À TRAVERS les cubes : dans la lightmap, un trait est un pixel NOIR au sol, et le masque
## de la fumée interdit — à raison — d'allumer un pixel noir ; les cubes s'y taisaient donc, en rangées de trous. Aucun volume
## ne peut couvrir un dessin encré couché sous lui. L'aplat garde tout ce que le jeu lit de la masse (sa forme, sa lueur, son
## fondu, `occultation_pour` qui ne lit que la géométrie) et retire le dessin : sous les cubes, la lightmap ne porte plus que
## la LUMIÈRE du nuage. La vue de dessus (`--2d`) n'est pas touchée : `IsoVolumes` ne tourne qu'en iso, et rend l'image
## d'origine dès que l'essai s'éteint ou que le nuage part.
static var _aplats := {}


static func aplat(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var cle := tex.get_instance_id()
	if _aplats.has(cle):
		return _aplats[cle]
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	# La couleur moyenne, pondérée par l'alpha : l'image prémultipliée, réduite de moitié en moitié jusqu'à un pixel.
	var moy := img.duplicate() as Image
	moy.premultiply_alpha()
	while moy.get_width() > 1 or moy.get_height() > 1:
		moy.shrink_x2()
	var m := moy.get_pixel(0, 0)
	var couleur := Color(m.r / m.a, m.g / m.a, m.b / m.a) if m.a > 0.001 else Color.BLACK
	var d := img.get_data()
	var r := couleur.r8
	var g := couleur.g8
	var b := couleur.b8
	for i in range(0, d.size(), 4):
		d[i] = r
		d[i + 1] = g
		d[i + 2] = b
	var out := Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d)
	var t := ImageTexture.create_from_image(out)
	_aplats[cle] = t
	return t


## Sous le drapeau, au lancement : le shader, sa variante de la fusée et les deux aplats, pour qu'aucun ne se prépare au
## premier nuage (une masse de 336 px se repeint en ~0,1 s de GDScript : un à-coup pile au moment où l'on pose la fumée).
## Le shader, lui, se COMPILE à son premier dessin, dans le pilote : ce coût-là n'est pas pris ici, et ce qu'il vaut sur le
## pilote d'Apple, le cloud (llvmpipe) ne peut pas le dire.
static func prechauffer() -> void:
	shader(false)
	for nom in ["cartouche_suie", "poussiere"]:
		var chemin := "res://assets/sprites/gadget_%s.png" % nom
		if ResourceLoader.exists(chemin):
			aplat(load(chemin) as Texture2D)


## Le shader des voxels a-t-il été chargé dans ce processus ? Faux tant qu'aucun nuage en voxels n'a été posé : sans le
## drapeau, jamais (`tools/test_fumee_voxel.gd` le vérifie).
static func shader_charge() -> bool:
	return _shader != null


static func est_un_shader_de_nuage(s: Shader) -> bool:
	return s != null and _shader != null and (s == _shader or s == _shader_fusee)


static func cote_voxel(variante: String) -> float:
	return float(VARIANTES.get(variante, VARIANTES[VARIANTE_PAR_DEFAUT]))


## Le nombre de rangées de voxels d'un nuage de `hauteur_px` : au moins une, arrondi au plus proche.
static func rangees(hauteur_px: float, voxel: float) -> int:
	return maxi(1, roundi(hauteur_px / voxel))


## Le côté d'une caméra : le signe de sa direction de vue en x et en z (0 si elle regarde de profil, à moins de 3°).
static func cote_camera(avant: Vector3) -> Vector2i:
	return Vector2i(0 if absf(avant.x) < 0.05 else (1 if avant.x > 0.0 else -1),
		0 if absf(avant.z) < 0.05 else (1 if avant.z > 0.0 else -1))


## La direction de vue d'une caméra iso de lacet `lacet_deg` (tangage de `CameraIso`), pour une vue sans caméra à lire.
static func avant_de_lacet(lacet_deg: float, tangage_deg: float = CameraIso.TANGAGE_DEG) -> Vector3:
	return -Basis.from_euler(Vector3(deg_to_rad(-tangage_deg), deg_to_rad(lacet_deg), 0.0)).z


## Les cellules d'un nuage, relatives à l'origine de sa grille, rangées pour une caméra de côté `cote` : du plus loin au plus
## proche (chaque axe parcouru depuis son côté loin — la caméra regarde vers le bas : les cellules basses d'abord).
## `rayon` : le rayon maximal ; une cellule est gardée si son centre est à moins de `rayon` + une demi-diagonale du centre,
## pour une origine calée à au plus une demi-case du centre vrai.
##
## LE DÔME : à la hauteur d'une rangée (`f`, sa fraction de la hauteur du nuage), la densité ne vit que dans le rayon
## resserré du shader (× 1 − `RESSERRE` f, le dôme des couches) ; une case au-delà ne portera jamais de cube. Chaque rangée
## ne garde donc que son disque : un cinquième des cases en moins, et avec elles leurs douze sommets à chaque image, pour la
## même image.
static func cellules(rayon: float, rangs: int, voxel: float, cote: Vector2i) -> PackedVector3Array:
	var n := ceili(rayon / voxel) + 1
	var xs := range(-n, n) if cote.x <= 0 else range(n - 1, -n - 1, -1)
	var zs := range(-n, n) if cote.y <= 0 else range(n - 1, -n - 1, -1)
	var sortie := PackedVector3Array()
	for iy in rangs:
		var portee := rayon * (1.0 - RESSERRE * (float(iy) + 0.5) / float(rangs)) + voxel * 1.5
		for iz: int in zs:
			for ix: int in xs:
				var p := Vector3((float(ix) + 0.5) * voxel, (float(iy) + 0.5) * voxel, (float(iz) + 0.5) * voxel)
				if Vector2(p.x, p.z).length() <= portee:
					sortie.append(p)
	return sortie


## La grille partagée d'un type de nuage, pour une taille de voxel et un côté de caméra.
static func grille(type: String, hauteur_px: float, voxel: float, cote: Vector2i) -> MultiMesh:
	var rayon := float((NUAGES[type] as Dictionary)["rayon_max"])
	var rangs := rangees(hauteur_px, voxel)
	var cle := "%s:%.3f:%d:%d,%d" % [type, voxel, rangs, cote.x, cote.y]
	if _grilles.has(cle):
		return _grilles[cle]
	var cells := cellules(rayon, rangs, voxel, cote)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = maille(cote)
	mm.instance_count = cells.size()
	# Le tampon d'un coup (douze flottants par instance : la base en lignes, puis l'origine) plutôt qu'instance par instance.
	var tampon := PackedFloat32Array()
	tampon.resize(cells.size() * 12)
	for i in cells.size():
		var p := cells[i]
		var k := i * 12
		tampon[k] = voxel
		tampon[k + 3] = p.x
		tampon[k + 5] = voxel
		tampon[k + 7] = p.y
		tampon[k + 10] = voxel
		tampon[k + 11] = p.z
	mm.buffer = tampon
	_grilles[cle] = mm
	return mm


## Le cube de côté 1, réduit aux faces qu'une caméra de côté `cote` voit : le dessus, et un côté par axe où elle ne
## regarde pas de profil. Les faces vues de dos ne seraient jamais dessinées (`cull_back`) : autant ne pas les calculer.
static func maille(cote: Vector2i) -> ArrayMesh:
	var cle := "%d,%d" % [cote.x, cote.y]
	if _mailles.has(cle):
		return _mailles[cle]
	var faces: Array[Vector3] = [Vector3.UP]
	if cote.x != 0:
		faces.append(Vector3(-float(cote.x), 0.0, 0.0))
	if cote.y != 0:
		faces.append(Vector3(0.0, 0.0, -float(cote.y)))
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var indices := PackedInt32Array()
	for n: Vector3 in faces:
		# Deux axes du plan de la face, dans l'ordre qui la tourne vers l'extérieur (`cull_back` : sens des aiguilles vu de face).
		var u := Vector3(n.y, n.z, n.x)
		var v := n.cross(u)
		var base := sommets.size()
		for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			sommets.append(n * 0.5 + (u * s.x + v * s.y) * 0.5)
			normales.append(n)
		indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	var tableaux := []
	tableaux.resize(Mesh.ARRAY_MAX)
	tableaux[Mesh.ARRAY_VERTEX] = sommets
	tableaux[Mesh.ARRAY_NORMAL] = normales
	tableaux[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
	_mailles[cle] = m
	return m


## L'origine de la grille d'un nuage centré en `centre` : le coin de voxel le plus proche (calée sur le monde).
static func origine(centre: Vector2, voxel: float) -> Vector3:
	return Vector3(roundf(centre.x / voxel) * voxel, 0.0, roundf(centre.y / voxel) * voxel)


## Un matériau de nuage pour une vue : le shader (fusée ou gadget), la vue, les constantes du type.
static func materiau(type: String, vue_id: int, voxel: float, hauteur_px: float, priorite: int) -> ShaderMaterial:
	var spec: Dictionary = NUAGES[type]
	var mat := ShaderMaterial.new()
	mat.shader = shader(type == "fusee")
	mat.render_priority = priorite
	mat.set_shader_parameter("vue_deux", vue_id == 1)
	mat.set_shader_parameter("voxel_px", voxel)
	mat.set_shader_parameter("nuage_hauteur_px", float(rangees(hauteur_px, voxel)) * voxel)
	mat.set_shader_parameter("alpha_voxel", float(spec["alpha"]))
	mat.set_shader_parameter("seuil_taille", SEUIL_TAILLE)
	mat.set_shader_parameter("plein_taille", PLEIN_TAILLE)
	mat.set_shader_parameter("grille_portee", float(spec["rayon_max"]) + voxel * 1.5)
	mat.set_shader_parameter("nuage_coeur", COEUR)
	mat.set_shader_parameter("face_dessus", FACE_DESSUS)
	mat.set_shader_parameter("face_gauche", FACE_GAUCHE)
	mat.set_shader_parameter("face_droite", FACE_DROITE)
	mat.set_shader_parameter("encre_px", IsoMateriaux.ENCRE_VOXEL_PX if IsoMateriaux.beaute_active() else 0.0)
	mat.set_shader_parameter("encre_reste", ENCRE_RESTE)
	mat.set_shader_parameter("temperature", IsoMateriaux.TEMPERATURE if IsoMateriaux.beaute_active() else 0.0)
	return mat


## Les réglages d'un nuage de GADGET (suie, poussière), lus sur sa masse 2D : son image et son angle, son rayon, sa vie.
static func poser_gadget(mat: ShaderMaterial, type: String, centre: Vector2, rayon: float, masque: Texture2D, angle: float,
		vie: float, age: float) -> void:
	mat.set_shader_parameter("nuage_centre", centre)
	mat.set_shader_parameter("nuage_rayon", rayon)
	mat.set_shader_parameter("lissage_px", maxf(rayon * LISSAGE, float(mat.get_shader_parameter("voxel_px"))))
	mat.set_shader_parameter("masque", masque)
	mat.set_shader_parameter("avec_masque", masque != null)
	mat.set_shader_parameter("nuage_angle", angle)
	mat.set_shader_parameter("nuage_vie", clampf(vie, 0.0, 1.0) * float((NUAGES[type] as Dictionary)["densite"]))
	mat.set_shader_parameter("age", age)


## Les uniformes du voile de la fusée que le nuage recopie, sous le même nom que dans `fumee_fusee.gdshader` (sauf les trois
## que le préfixe `voile_` distingue de ceux du nuage).
const VOILE_MEME_NOM := ["nb_masses", "masses", "masse_rayon_uv", "masse_opacite", "nb_trous", "trous", "nb_tunnels",
	"tunnels_entree", "tunnels_sortie", "tunnel_force", "tunnel_sombre", "tunnel_largeur_uv"]
const VOILE_PREFIXE := {"alpha_globale": "voile_alpha_globale", "graine": "voile_graine", "age": "voile_age"}


## Les réglages de la fumée d'une FUSÉE, lus sur ce qu'elle peint en 2D à cette image : son voile (volutes, masses, trous,
## tunnels) et ses nappes (planche, rotation, taille, opacité). `voile` : son `Sprite2D` « Voile » ; `nappes` : les siens.
static func poser_fusee(mat: ShaderMaterial, centre: Vector2, rayon: float, voile: Sprite2D, nappes: Array,
		age: float) -> void:
	mat.set_shader_parameter("nuage_centre", centre)
	mat.set_shader_parameter("nuage_rayon", rayon)
	mat.set_shader_parameter("lissage_px", maxf(rayon * LISSAGE, float(mat.get_shader_parameter("voxel_px"))))
	mat.set_shader_parameter("nuage_vie", float((NUAGES["fusee"] as Dictionary)["densite"]))
	mat.set_shader_parameter("age", age)
	var mv := voile.material as ShaderMaterial if voile != null else null
	if mv != null and voile.is_visible_in_tree():
		for nom: String in VOILE_MEME_NOM:
			mat.set_shader_parameter(nom, mv.get_shader_parameter(nom))
		for nom: String in VOILE_PREFIXE:
			mat.set_shader_parameter(VOILE_PREFIXE[nom], mv.get_shader_parameter(nom))
		mat.set_shader_parameter("voile_diametre", float(voile.texture.get_width()) * absf(voile.global_scale.x)
			if voile.texture != null else rayon * 2.0)
	else:
		mat.set_shader_parameter("voile_alpha_globale", 0.0)
	var n := 0
	var reglages := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	for s in nappes:
		var nappe := s as Sprite2D
		if nappe == null or nappe.texture == null or not nappe.is_visible_in_tree() or n >= 3:
			continue
		mat.set_shader_parameter("nappe_%d" % (n + 1), nappe.texture)
		reglages[n] = Vector3(nappe.global_rotation, float(nappe.texture.get_width()) * absf(nappe.global_scale.x),
			Presentation3D.opacite_rendue(nappe))
		n += 1
	mat.set_shader_parameter("nb_nappes", n)
	mat.set_shader_parameter("nappes", PackedVector3Array(reglages))
