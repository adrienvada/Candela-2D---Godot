## Prototype de vue isométrique 3D — Candela regardé comme Unrailed 2.
##
## ## Pourquoi ce fichier existe
##
## Adrien étudie l'idée de donner au jeu une vue 3D inclinée, « à la Unrailed 2 ».
## La question n'est pas « est-ce joli » mais **« la seule information du jeu —
## la lumière — survit-elle à une caméra inclinée ? »** Un mur vu de biais cache
## ce qui est derrière lui, une ombre portée s'allonge, un cône de torche se
## déforme sur les faces verticales. On ne peut pas en juger sur un croquis :
## il faut une vraie carte, une vraie torche à ombres, et regarder.
##
## Ce prototype reconstruit donc une **carte livrée** en boîtes, y pose deux
## joueurs, une torche à ombres portées et un halo sur chacun, et une caméra
## orthographique inclinée dont les préréglages couvrent les angles candidats.
##
## **Ce n'est pas le jeu, et rien du jeu n'en dépend.** Aucune scène de jeu ne
## charge ce fichier ; seuls `proto_iso.tscn` et `test_proto_iso.gd` le
## connaissent. Il lit les cartes par `MapCodec` et découpe murs et sol par
## `MapGeometry.build_grid()` + `merge_rects()` — **les mêmes rectangles que la
## physique et l'occlusion du jeu 2D**, donc la même carte, jamais une
## approximation redessinée pour l'occasion.
##
## ## Repère
##
## Une tuile = une unité. `x` de la carte → `x`, `y` de la carte → `z`, la
## hauteur est `y` (vers le haut). La case (cx, cy) occupe [cx, cx+1[ × [cy, cy+1[
## et son centre est (cx + 0,5 ; · ; cy + 0,5). Les rectangles rendus par
## `MapGeometry` sont en **indices de grille**, décalés de `BORDER` : la
## conversion est `rect_vers_monde()`, et nulle part ailleurs.
##
## ## Le sol : une dalle par rectangle, et RIEN dans les fosses
##
## L'autre option — un sol plein et des fosses en boîtes noires abaissées —
## aurait donné un sol qui capte la torche au fond du trou. Or dans le jeu 2D le
## vide est noir : la lumière le traverse sans rien révéler (`map_geometry.gd` :
## les fosses arrêtent le joueur, pas la lumière). Ne rien dessiner est la
## traduction exacte. La dalle a une épaisseur pour que ses flancs, éclairés,
## dessinent le bord du gouffre — c'est le seul indice qu'un trou est là, et il
## ne coûte rien de plus qu'un plan.
##
## ## Lancer
##
##   godot --path . res://tools/proto_iso.tscn -- --carte=default --preset=unrailed
##   godot --path . res://tools/proto_iso.tscn -- --carte=map_002_l_usine \
##       --capture=/chemin/usine.png --frames=4
##
## Sans `--capture`, la scène reste ouverte (utilisable depuis l'éditeur, les
## réglages sont des `@export`). Les arguments sont listés dans
## `_lire_arguments()`. **La capture exige une vraie fenêtre** : en headless rien
## n'est rastérisé et `frame_post_draw` n'est jamais émis (`RenduCommun`), donc
## l'outil refuse et sort en code 3 au lieu de pendre.
extends Node3D

const Charte := preload("res://charte.gd")

## Épaisseur de la dalle de sol, en tuiles : ses flancs éclairés dessinent le
## bord des fosses.
const EPAISSEUR_SOL := 0.25
## Le joueur 2D fait ~30 px de diamètre sur des tuiles de 35 : 0,43 tuile.
const HAUTEUR_JOUEUR := 1.0
const RAYON_JOUEUR := 0.4
## Hauteur de la torche sur le corps — à hauteur de poitrine, devant le corps
## pour que celui-ci ne la mette pas dans sa propre ombre.
const HAUTEUR_TORCHE := 0.6
## Portées, en tuiles. 12 = le pistolet du jeu (`tools/torches.gd` : l'empreinte
## vaut 512 × 1,6 unités et le faisceau porte la moitié, 410 px = 11,7 tuiles
## de 35 px).
const PORTEE_TORCHE := 12.0
const PORTEE_HALO := 2.0
const PORTEE_FLASH := 5.0
## Couches de rendu : le décor (sol, murs) sur la 1, les corps sur la 2 — voir
## le halo dans `_joueur()`.
const COUCHE_DECOR := 1
const COUCHE_CORPS := 2
## Marge du cadrage automatique autour de la carte, en fraction.
const MARGE_CADRAGE := 0.04
## Recul de la caméra le long de son axe. En orthographique il ne change pas
## l'image ; il doit seulement laisser toute la carte entre `near` et `far`.
const RECUL_CAMERA := 100.0

## La matière de tout ce qui est construit — et la raison du prototype.
##
## Une torche à hauteur de poitrine RASE le sol : à cinq tuiles, la lumière
## arrive à 7° au-dessus de l'horizontale, et un béton Lambert n'en reçoit que
## sin(7°) = 12 %. Le cône que le jeu 2D dessine plein sur le sol (un cookie,
## sans aucune notion d'incidence) disparaît donc dans une 3D « physique » —
## mesuré sur la première capture, avant ce shader. `lambert` dose l'incidence :
## 1 = béton physique, 0 = comme le cookie 2D (la lumière compte, pas l'angle),
## avec un garde qui laisse les faces tournant le dos à la lumière dans le
## noir. `ATTENUATION` porte déjà la portée, le cône et l'ombre portée.
const SHADER_MATIERE := """
shader_type spatial;
render_mode specular_disabled;
uniform vec3 teinte : source_color = vec3(0.5, 0.5, 0.5);
uniform float lambert : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	ALBEDO = teinte;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
void light() {
	float incidence = dot(NORMAL, LIGHT);
	float face = smoothstep(0.0, 0.02, incidence);
	float diffus = mix(face, clamp(incidence, 0.0, 1.0), lambert);
	DIFFUSE_LIGHT += diffus * ATTENUATION * LIGHT_COLOR / PI;
}
"""

## Préréglages de caméra : (pitch, yaw) en degrés. Le pitch est l'inclinaison
## sous l'horizontale (90 = à la verticale), le yaw la rotation autour de la
## verticale. `iso` est l'isométrie vraie (arctan(1/√2) = 35,264°) ; `unrailed`
## l'angle d'Unrailed 2, plus plongeant.
const PRESETS := {
	"unrailed": Vector2(52.0, 45.0),
	"iso": Vector2(35.264, 45.0),
	"dessus_incline": Vector2(70.0, 45.0),
	"dessus": Vector2(90.0, 0.0),
}

## Slug d'une carte livrée (`res://assets/maps/<slug>.json`).
@export var carte_slug := "default"
@export var preset := "unrailed"
## NAN = l'angle du préréglage.
@export var pitch_deg := NAN
@export var yaw_deg := NAN
## 1 = la carte entière tient dans l'image ; 2 = deux fois plus près.
@export var zoom := 1.0
## Hauteur des murs en tuiles (1 tuile = 35 px du jeu 2D).
@export var hauteur_mur := 1.0
## DEMI-angle du cône, comme `angle` dans `tools/torches.gd` (30 → cône de 60°).
## Le pistolet du jeu ouvre à 35.
@export var torche_demi_angle := 30.0
## Réglé sur les captures du 2026-09-13 (docs/iso/captures_godot) : à 12, la
## naissance du cône sature ; à 4, les faces de murs ne se détachent plus.
@export var torche_energie := 8.0
@export var halo_energie := 0.8
@export var flash_energie := 8.0
## Part d'incidence dans l'éclairage du sol et des murs — voir SHADER_MATIERE.
@export_range(0.0, 1.0) var lambert_sol := 0.0
@export_range(0.0, 1.0) var lambert_mur := 1.0
## Tuile visée par la torche de J1 ; (-1, -1) = la case de J2.
@export var cible_j1 := Vector2i(-1, -1)
## Cap de la torche de J2 en degrés, convention du jeu 2D (0 = +x, sens horaire
## vu de dessus) ; NAN = vers J1.
@export var yaw_torche_j2 := NAN
## Un flash de tir au bout du canon de J1.
@export var flash := false
## Exposition du tonemap (`Environment.tonemap_exposure`).
@export var exposition := 1.0
## `lineaire`, `filmic` ou `aces`.
@export var tonemap := "lineaire"

var _data: Dictionary = {}
var _rects: Dictionary = {}
var _boites_murs: Array[MeshInstance3D] = []
var _dalles_sol: Array[MeshInstance3D] = []
var _lumieres: Array[Light3D] = []
var _camera: Camera3D = null
## Un seul cube unitaire pour toutes les boîtes : chaque boîte n'est qu'une
## échelle posée sur le nœud. Une `BoxMesh` par rectangle aurait multiplié les
## ressources sans rien changer à l'image.
var _cube: BoxMesh = null
var _shader: Shader = null
var _matiere_sol: ShaderMaterial = null
var _matiere_mur: ShaderMaterial = null

var _capture := ""
var _frames := 4
var _taille := Vector2i(1920, 1080)

# ---------------------------------------------------------------------------
# CYCLE DE VIE
# ---------------------------------------------------------------------------

func _ready() -> void:
	_lire_arguments(OS.get_cmdline_user_args())
	var data := charger_carte_livree(carte_slug)
	if data.is_empty():
		push_error("proto_iso : carte livrée introuvable ou illisible « %s » (livrées : %s)"
			% [carte_slug, ", ".join(cartes_livrees())])
		if _capture != "":
			get_tree().quit(2)
		return
	construire(data)
	print(bilan())
	if _capture != "":
		_capturer_puis_quitter()

## Arguments après `--`, tous de la forme `--cle=valeur` sauf les drapeaux.
## Les drapeaux du JEU (`--no-eos`, posé par `run_suites.sh` à toute suite)
## passent sans bruit : ils ne sont pas les nôtres, mais ils arrivent ici.
func _lire_arguments(args: PackedStringArray) -> void:
	for a in args:
		if not a.begins_with("--"):
			continue
		var egal := a.find("=")
		var cle := a.substr(2, egal - 2) if egal >= 0 else a.substr(2)
		var val := a.substr(egal + 1) if egal >= 0 else ""
		match cle:
			"carte": carte_slug = val
			"preset": preset = val
			"pitch": pitch_deg = float(val)
			"yaw": yaw_deg = float(val)
			"zoom": zoom = maxf(0.05, float(val))
			"mur": hauteur_mur = maxf(0.05, float(val))
			"torche": torche_demi_angle = clampf(float(val), 1.0, 89.0)
			"energie": torche_energie = float(val)
			"halo": halo_energie = float(val)
			"lambert-sol": lambert_sol = clampf(float(val), 0.0, 1.0)
			"lambert-mur": lambert_mur = clampf(float(val), 0.0, 1.0)
			"expo": exposition = float(val)
			"tonemap": tonemap = val
			"cible":
				var parts := val.split(",")
				if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
					cible_j1 = Vector2i(int(parts[0]), int(parts[1]))
				else:
					push_warning("proto_iso : --cible attend x,y (reçu « %s »)" % val)
			"yaw2": yaw_torche_j2 = float(val)
			"flash": flash = true
			"capture": _capture = val
			"frames": _frames = maxi(1, int(val))
			"taille":
				var parts := val.to_lower().split("x")
				if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
					_taille = Vector2i(int(parts[0]), int(parts[1]))
				else:
					push_warning("proto_iso : --taille attend LxH (reçu « %s »)" % val)
			"no-eos", "sans-maj", "eos-ephemeral":
				pass
			_:
				push_warning("proto_iso : argument inconnu --%s" % cle)

# ---------------------------------------------------------------------------
# CARTES — lecture par le codec du jeu, jamais par une réimplémentation
# ---------------------------------------------------------------------------

## Slugs des cartes livrées, triés. Lus sur le disque et non par `MapData` :
## l'autoload n'existe pas en mode `--script`, où tourne la suite.
static func cartes_livrees() -> PackedStringArray:
	var slugs: PackedStringArray = []
	var dir := DirAccess.open("res://assets/maps")
	if dir == null:
		return slugs
	dir.list_dir_begin()
	var nom := dir.get_next()
	while nom != "":
		if nom.ends_with(".json"):
			slugs.append(nom.trim_suffix(".json"))
		nom = dir.get_next()
	dir.list_dir_end()
	slugs.sort()
	return slugs

## Une carte livrée, validée et normalisée par `MapCodec.validate()` — la même
## lecture que `MapData._read_map_file()`, qui est privée. Vide si introuvable
## ou illisible.
static func charger_carte_livree(slug: String) -> Dictionary:
	var chemin := "res://assets/maps/%s.json" % slug
	if not FileAccess.file_exists(chemin):
		return {}
	var fichier := FileAccess.open(chemin, FileAccess.READ)
	if fichier == null:
		return {}
	var json := JSON.new()
	var texte := fichier.get_as_text()
	fichier.close()
	if json.parse(texte) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var resultat := MapCodec.validate(json.data as Dictionary)
	return resultat["data"] if resultat["ok"] else {}

## Grille booléenne du SOL, aux dimensions de `MapGeometry.build_grid()` :
## est sol toute case qui n'est ni mur ni fosse. Dérivée des deux grilles du jeu
## et non recalculée à part, pour que murs, fosses et sol **partitionnent** la
## grille bordure comprise — c'est ce que la suite vérifie.
static func grille_de_sol(data: Dictionary) -> Array:
	var murs: Array = MapGeometry.build_grid(data, MapGeometry.Kind.WALLS)
	var fosses: Array = MapGeometry.build_grid(data, MapGeometry.Kind.PITS)
	var out: Array = []
	out.resize(murs.size())
	for ix in murs.size():
		var colonne: Array[bool] = []
		colonne.resize((murs[ix] as Array).size())
		for iy in colonne.size():
			colonne[iy] = not murs[ix][iy] and not fosses[ix][iy]
		out[ix] = colonne
	return out

## Les rectangles fusionnés d'une carte, en indices de grille (bordure comprise,
## voir `MapGeometry.BORDER`) : `murs`, `fosses`, `sol` (Array[Rect2i]) et
## `grille` (Vector2i, dimensions bordure comprise).
static func rectangles_de(data: Dictionary) -> Dictionary:
	var murs: Array = MapGeometry.build_grid(data, MapGeometry.Kind.WALLS)
	var largeur: int = murs.size()
	var hauteur: int = (murs[0] as Array).size() if largeur > 0 else 0
	return {
		"murs": MapGeometry.merge_rects(murs),
		"fosses": MapGeometry.merge_rects(MapGeometry.build_grid(data, MapGeometry.Kind.PITS)),
		"sol": MapGeometry.merge_rects(grille_de_sol(data)),
		"grille": Vector2i(largeur, hauteur),
	}

## Indices de grille → repère monde (x, z), la bordure retirée.
static func rect_vers_monde(rect: Rect2i) -> Rect2:
	var origine := rect.position - Vector2i(MapGeometry.BORDER, MapGeometry.BORDER)
	return Rect2(Vector2(origine), Vector2(rect.size))

## Centre d'une case de carte, à la hauteur donnée.
static func case_vers_monde(cell: Vector2i, hauteur: float) -> Vector3:
	return Vector3(cell.x + 0.5, hauteur, cell.y + 0.5)

# ---------------------------------------------------------------------------
# CONSTRUCTION
# ---------------------------------------------------------------------------

## Reconstruit toute la scène pour `data`. Idempotent : la construction
## précédente est retirée de l'arbre AVANT d'être libérée, sans quoi les noms
## seraient encore pris et Godot suffixerait les nouveaux (« @Node3D@12 »).
func construire(data: Dictionary) -> void:
	_vider()
	_data = data
	_rects = rectangles_de(data)
	_cube = BoxMesh.new()
	_cube.size = Vector3.ONE
	# Compilé ici, à la volée : c'est un prototype, pas une manche (le jeu, lui,
	# précharge ses shaders — voir CLAUDE.md). Un seul Shader, une matière par
	# usage.
	_shader = Shader.new()
	_shader.code = SHADER_MATIERE
	# Béton : mat, gris, un peu chaud. Le sol plus sombre que les murs, pour que
	# les faces verticales prises dans le faisceau se détachent du sol éclairé.
	_matiere_sol = _matiere(Color(0.40, 0.40, 0.38), lambert_sol)
	_matiere_mur = _matiere(Color(0.58, 0.57, 0.53), lambert_mur)

	var decor := Node3D.new()
	decor.name = "Decor"
	add_child(decor)
	_construire_sol(decor)
	_construire_murs(decor)
	_construire_joueurs(decor)
	_construire_environnement()
	_construire_camera()

func _vider() -> void:
	for enfant in get_children():
		remove_child(enfant)
		enfant.free()
	_boites_murs.clear()
	_dalles_sol.clear()
	_lumieres.clear()
	_camera = null

func _matiere(teinte: Color, lambert: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("teinte", Vector3(teinte.r, teinte.g, teinte.b))
	m.set_shader_parameter("lambert", lambert)
	return m

## Une boîte = le cube unitaire mis à l'échelle. `rect` en indices de grille ;
## la boîte va de `y0` à `y0 + hauteur`.
func _boite(rect: Rect2i, y0: float, hauteur: float, matiere: Material) -> MeshInstance3D:
	var monde := rect_vers_monde(rect)
	var boite := MeshInstance3D.new()
	boite.mesh = _cube
	boite.material_override = matiere
	boite.scale = Vector3(monde.size.x, hauteur, monde.size.y)
	boite.position = Vector3(monde.position.x + monde.size.x * 0.5, y0 + hauteur * 0.5,
		monde.position.y + monde.size.y * 0.5)
	return boite

func _construire_sol(parent: Node3D) -> void:
	var conteneur := Node3D.new()
	conteneur.name = "Sol"
	parent.add_child(conteneur)
	var rects: Array[Rect2i] = _rects["sol"]
	for i in rects.size():
		var dalle := _boite(rects[i], -EPAISSEUR_SOL, EPAISSEUR_SOL, _matiere_sol)
		dalle.name = "Dalle%d" % i
		dalle.add_to_group("proto_iso_sol")
		conteneur.add_child(dalle)
		_dalles_sol.append(dalle)

func _construire_murs(parent: Node3D) -> void:
	var conteneur := Node3D.new()
	conteneur.name = "Murs"
	parent.add_child(conteneur)
	var rects: Array[Rect2i] = _rects["murs"]
	for i in rects.size():
		var mur := _boite(rects[i], 0.0, hauteur_mur, _matiere_mur)
		mur.name = "Mur%d" % i
		mur.add_to_group("proto_iso_mur")
		conteneur.add_child(mur)
		_boites_murs.append(mur)

func _construire_joueurs(parent: Node3D) -> void:
	var conteneur := Node3D.new()
	conteneur.name = "Joueurs"
	parent.add_child(conteneur)
	var s1 := MapCodec.get_spawn(_data, 0)
	var s2 := MapCodec.get_spawn(_data, 1)
	var cible := cible_j1 if cible_j1.x >= 0 else s2
	# J1 regarde sa cible ; sa torche est inclinée pour que l'axe touche le sol
	# sous la cible, jamais au-dessus.
	var dir1 := _direction_vers(s1, cible)
	var dist1 := Vector2(cible - s1).length()
	conteneur.add_child(_joueur("J1", s1, dir1, dist1, Charte.BLEU, flash))
	var dir2: Vector3
	var dist2: float
	if is_nan(yaw_torche_j2):
		dir2 = _direction_vers(s2, s1)
		dist2 = Vector2(s1 - s2).length()
	else:
		dir2 = Vector3(cos(deg_to_rad(yaw_torche_j2)), 0.0, sin(deg_to_rad(yaw_torche_j2)))
		dist2 = PORTEE_TORCHE * 0.6
	conteneur.add_child(_joueur("J2", s2, dir2, dist2, Charte.ROUGE, false))

static func _direction_vers(depuis: Vector2i, vers: Vector2i) -> Vector3:
	var d := Vector3(vers.x - depuis.x, 0.0, vers.y - depuis.y)
	return d.normalized() if d.length_squared() > 0.0 else Vector3(1.0, 0.0, 0.0)

## Un joueur : cylindre + nez, torche à ombres et halo. Le nœud est posé AU SOL
## et tourné vers `direction` (le -Z du nœud, convention `looking_at`).
func _joueur(nom: String, cell: Vector2i, direction: Vector3, distance_cible: float,
		teinte: Color, avec_flash: bool) -> Node3D:
	var joueur := Node3D.new()
	joueur.name = nom
	joueur.position = case_vers_monde(cell, 0.0)
	joueur.basis = Basis.looking_at(direction, Vector3.UP)

	var corps := MeshInstance3D.new()
	corps.name = "Corps"
	var cylindre := CylinderMesh.new()
	cylindre.top_radius = RAYON_JOUEUR
	cylindre.bottom_radius = RAYON_JOUEUR
	cylindre.height = HAUTEUR_JOUEUR
	corps.mesh = cylindre
	corps.material_override = _matiere(teinte, 1.0)
	corps.position = Vector3(0.0, HAUTEUR_JOUEUR * 0.5, 0.0)
	# Les corps vivent sur la couche 2 : le halo ne prend d'ombre que de la
	# couche 1 (sol, murs), sinon le corps, juste sous lui, éteignait tout le
	# disque — mesuré : à 0,2 tuile au-dessus d'un cylindre de rayon 0,4, tout
	# le sol jusqu'à 2,4 tuiles est dans l'ombre du sommet. Les torches, elles,
	# gardent l'ombre des corps : c'est de l'information.
	corps.layers = COUCHE_CORPS
	joueur.add_child(corps)

	var nez := MeshInstance3D.new()
	nez.name = "Nez"
	var boite := BoxMesh.new()
	boite.size = Vector3(0.18, 0.18, 0.36)
	nez.mesh = boite
	nez.material_override = corps.material_override
	nez.position = Vector3(0.0, HAUTEUR_JOUEUR * 0.6, -(RAYON_JOUEUR + 0.14))
	nez.layers = COUCHE_CORPS
	joueur.add_child(nez)

	var torche := SpotLight3D.new()
	torche.name = "Torche"
	torche.position = Vector3(0.0, HAUTEUR_TORCHE, -(RAYON_JOUEUR + 0.05))
	torche.rotation.x = -atan2(HAUTEUR_TORCHE, maxf(distance_cible, 1.0))
	torche.spot_range = PORTEE_TORCHE
	torche.spot_angle = torche_demi_angle
	torche.light_energy = torche_energie
	torche.light_color = Charte.AMBRE
	torche.light_specular = 0.2
	torche.shadow_enabled = true
	torche.shadow_bias = 0.05
	joueur.add_child(torche)
	_lumieres.append(torche)

	# Le halo au-dessus de la tête : dans le corps, il serait avalé par l'ombre
	# que le corps porte lui-même.
	var halo := OmniLight3D.new()
	halo.name = "Halo"
	halo.position = Vector3(0.0, HAUTEUR_JOUEUR + 0.2, 0.0)
	halo.omni_range = PORTEE_HALO
	halo.light_energy = halo_energie
	halo.light_color = Charte.HALOGENE
	halo.light_specular = 0.1
	halo.shadow_enabled = true
	halo.shadow_caster_mask = COUCHE_DECOR
	joueur.add_child(halo)
	_lumieres.append(halo)

	# Le flash n'existe que demandé — une lumière cachée ou à énergie nulle est
	# encore une lumière pour le moteur (voir « Pièges connus » de la ROADMAP).
	if avec_flash:
		var eclair := OmniLight3D.new()
		eclair.name = "Flash"
		eclair.position = Vector3(0.0, HAUTEUR_JOUEUR * 0.6, -(RAYON_JOUEUR + 0.4))
		eclair.omni_range = PORTEE_FLASH
		eclair.light_energy = flash_energie
		eclair.light_color = Charte.HALOGENE
		eclair.shadow_enabled = true
		joueur.add_child(eclair)
		_lumieres.append(eclair)

	return joueur

func _construire_environnement() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Charte.NOIR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.01
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	match tonemap:
		"aces": env.tonemap_mode = Environment.TONE_MAPPER_ACES
		"filmic": env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		_: env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = exposition
	var monde := WorldEnvironment.new()
	monde.name = "Environnement"
	monde.environment = env
	add_child(monde)

## Caméra orthographique posée sur l'axe (pitch, yaw), reculée depuis le centre
## de la carte, et dimensionnée pour que la carte entière — bordure et murs
## compris — tienne dans l'image.
func _construire_camera() -> void:
	var angles := angles_camera()
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Ordre d'Euler YXZ de Node3D : on incline d'abord (X), on tourne ensuite
	# autour de la verticale (Y). Pas de `look_at` : à 90° de pitch le vecteur
	# « haut » serait parallèle à l'axe et la fonction ne saurait plus s'orienter.
	cam.rotation_degrees = Vector3(-angles.x, angles.y, 0.0)
	var bornes := bornes_monde()
	cam.position = bornes.get_center() - (-cam.basis.z) * RECUL_CAMERA
	cam.near = 0.1
	cam.far = RECUL_CAMERA * 4.0
	cam.size = taille_de_cadrage(cam.transform, bornes, aspect()) / zoom
	add_child(cam)
	cam.current = true
	_camera = cam

## Hauteur de vue orthographique (`Camera3D.size`, `KEEP_HEIGHT`) qui fait tenir
## `bornes` dans l'image : on projette les huit coins dans le repère de la
## caméra et on prend le plus contraignant des deux axes.
static func taille_de_cadrage(transform_camera: Transform3D, bornes: AABB, ratio: float) -> float:
	var inverse := transform_camera.affine_inverse()
	var mini_xy := Vector2(INF, INF)
	var maxi_xy := Vector2(-INF, -INF)
	for i in 8:
		var local := inverse * bornes.get_endpoint(i)
		mini_xy = mini_xy.min(Vector2(local.x, local.y))
		maxi_xy = maxi_xy.max(Vector2(local.x, local.y))
	var etendue := maxi_xy - mini_xy
	return maxf(etendue.y, etendue.x / ratio) * (1.0 + MARGE_CADRAGE)

## Rapport largeur/hauteur de la vue, 16:9 hors de l'arbre.
func aspect() -> float:
	if is_inside_tree():
		var vue := get_viewport()
		if vue != null:
			var taille := vue.get_visible_rect().size
			if taille.x > 0.0 and taille.y > 0.0:
				return taille.x / taille.y
	return 16.0 / 9.0

# ---------------------------------------------------------------------------
# CE QUE LA SUITE INTERROGE
# ---------------------------------------------------------------------------

func nombre_de_boites_murs() -> int:
	return _boites_murs.size()

func nombre_de_dalles_sol() -> int:
	return _dalles_sol.size()

func nombre_de_lumieres() -> int:
	return _lumieres.size()

## Tous les `MeshInstance3D` sous ce nœud, comptés en parcourant l'arbre.
func nombre_de_mesh_instances() -> int:
	return _compter(self, "MeshInstance3D")

func _compter(noeud: Node, classe: String) -> int:
	var n := 1 if noeud.is_class(classe) else 0
	for enfant in noeud.get_children():
		n += _compter(enfant, classe)
	return n

func lumieres() -> Array[Light3D]:
	return _lumieres.duplicate()

func camera() -> Camera3D:
	return _camera

func rectangles() -> Dictionary:
	return _rects

## Angles effectifs (pitch, yaw) : ceux du préréglage, recouverts par les
## valeurs libres quand elles sont données.
func angles_camera() -> Vector2:
	var base: Vector2 = PRESETS.get(preset, PRESETS["unrailed"])
	return Vector2(
		base.x if is_nan(pitch_deg) else pitch_deg,
		base.y if is_nan(yaw_deg) else yaw_deg)

## Boîte englobante de tout ce qui est construit : la grille bordure comprise,
## du dessous de la dalle au sommet des murs ou des joueurs.
func bornes_monde() -> AABB:
	var grille := MapCodec.get_grid_size(_data)
	var b := MapGeometry.BORDER
	var l: int = clampi(grille.x, 1, MapCodec.MAX_GRID) + 2 * b
	var h: int = clampi(grille.y, 1, MapCodec.MAX_GRID) + 2 * b
	var sommet := maxf(hauteur_mur, HAUTEUR_JOUEUR + 0.3)
	return AABB(Vector3(-b, -EPAISSEUR_SOL, -b), Vector3(l, EPAISSEUR_SOL + sommet, h))

func bilan() -> String:
	var angles := angles_camera()
	return ("PROTO_ISO carte=%s « %s » grille=%dx%d murs=%d fosses=%d sol=%d "
		+ "mesh=%d lumieres=%d preset=%s pitch=%.1f yaw=%.1f cam_size=%.1f "
		+ "mur=%.2f torche=%.0f° energie=%.1f lambert=%.2f/%.2f flash=%s") % [
		carte_slug, String(_data.get("name", "")), _rects["grille"].x, _rects["grille"].y,
		(_rects["murs"] as Array).size(), (_rects["fosses"] as Array).size(),
		(_rects["sol"] as Array).size(), nombre_de_mesh_instances(), _lumieres.size(),
		preset, angles.x, angles.y, _camera.size if _camera != null else 0.0,
		hauteur_mur, torche_demi_angle, torche_energie, lambert_sol, lambert_mur, str(flash)]

# ---------------------------------------------------------------------------
# CAPTURE
# ---------------------------------------------------------------------------

## Rend `_frames` images, lit la dernière et sort. Codes : 3 = headless,
## 4 = aucune image rendue dans le budget, 5 = écriture impossible.
func _capturer_puis_quitter() -> void:
	var refus := RenduCommun.refus_headless()
	if refus != "":
		push_error("proto_iso : capture impossible — %s" % refus)
		get_tree().quit(3)
		return
	# Posée ICI et non par `--resolution` : `GameSettings` reprend la fenêtre au
	# démarrage et écrase le drapeau du moteur (piège payé par le cinéaste).
	#
	# ⚠️ Par `Window.size`, PAS par `DisplayServer.window_set_size()`. Mesuré le
	# 2026-09-13 sous Xvfb, sans gestionnaire de fenêtres : le second fait dire
	# 1920×1080 à `window_get_size()` pendant que la vue et sa texture restent à
	# 1280×720 — la vue ne suit que l'événement X de redimensionnement, qui
	# n'arrive jamais sans gestionnaire. `Window.size` redimensionne la vue
	# lui-même, et l'image lue a la taille demandée.
	get_window().size = _taille
	await get_tree().process_frame
	var reelle: Vector2i = get_window().size
	if reelle != _taille:
		printerr("proto_iso : vue %dx%d au lieu de %dx%d" % [reelle.x, reelle.y, _taille.x, _taille.y])
	for i in _frames:
		await get_tree().process_frame
	# Budget large : sous un rendu logiciel, une image à 1080p avec quatre
	# lumières à ombres se compte en secondes.
	var image: Image = await RenduCommun.capturer(get_tree(), 60000)
	if image == null:
		push_error("proto_iso : aucune image rendue en 60 s")
		get_tree().quit(4)
		return
	var dossier := _capture.get_base_dir()
	if dossier != "":
		DirAccess.make_dir_recursive_absolute(dossier)
	var erreur := image.save_png(_capture)
	if erreur != OK:
		push_error("proto_iso : écriture impossible de %s (%s)" % [_capture, error_string(erreur)])
		get_tree().quit(5)
		return
	print("PROTO_ISO capture %s %dx%d" % [_capture, image.get_width(), image.get_height()])
	print("PROTO_ISO rendu %s | %s | lumières/objet max = %s" % [
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(),
		str(ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object", "?"))])
	get_tree().quit(0)
