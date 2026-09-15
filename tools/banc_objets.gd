extends Node3D

## Le banc des OBJETS DEBOUT voxel — chantier ISO, étape ISO3, vague 3 (iso-corps).
##
## Les six objets du catalogue (`voxel_catalogue_objets.gd`) en rang, un corps
## debout à côté pour l'échelle (le brief le demande explicitement), et le
## leurre (un `VoxelCorps` de la classe « spectre », immobile, arme baissée)
## posé à part pour sa propre démonstration d'effacement. Même discipline que
## `banc_corps.gd` : une lumière SIMULÉE (`definir_lumiere()`, jamais une
## `Light3D`), une capture qui exige une vraie fenêtre (`RenduCommun`), le
## même examen « valeur maximale des pixels à lumière 0 ».
##
## ## Lancer
##
##   godot --path . tools/banc_objets.tscn
##   godot --path . tools/banc_objets.tscn -- --lumiere=0 --capture=/chemin/noir.png
##   godot --path . tools/banc_objets.tscn -- --lumiere=0.8 --etat=allumee --capture=/chemin/allumes.png
##   godot --path . tools/banc_objets.tscn -- --lumiere=0.8 --opacite=0.5 --capture=/chemin/leurre_efface.png
##   godot --path . tools/banc_objets.tscn -- --objet=mine --lumiere=0.8 --capture=/chemin/mine.png
##
## `--objet=slug` cadre SERRÉ sur un seul objet (plus son corps d'échelle) —
## la lisibilité du brief (« se reconnaître d'un coup d'œil ») se juge à cette
## échelle-là, jamais sur la rangée complète, trop zoomée pour distinguer une
## forme. Sans `--capture`, la fenêtre reste ouverte : TAB choisit l'objet
## suivi par le libellé du bandeau, ESPACE bascule son état (allumé/éteint),
## HAUT/BAS règlent la lumière.

const VoxelObjetT := preload("res://voxel_objets.gd")
const VoxelCorpsT := preload("res://voxel_corps.gd")
const VoxelCatalogueObjetsT := preload("res://voxel_catalogue_objets.gd")
const Charte := preload("res://charte.gd")

const ESPACEMENT_TUILES := 1.6
const CLASSE_ECHELLE := "pistolet"     # un corps debout, pour juger la taille des objets à l'œil
const CLASSE_LEURRE := "spectre"

var _capture := ""
var _objet_filtre := ""
var _lumiere := 0.6
var _etat_allumee := false
var _opacite_leurre := -1.0            # -1 = pas d'effacement forcé (1.0 par défaut au shader)
var _taille := Vector2i(1920, 1080)
var _frames := 3
var _index_suivi := 0

var _objets: Array = []                # [{ "slug": String, "noeud": VoxelObjet }]
var _corps_echelle: Node3D
var _leurre: Node3D

var _bandeau: Label
var _releve: Label
var _sol_mat: ShaderMaterial
var _couche_bandeau: CanvasLayer


func _ready() -> void:
	_lire_arguments(OS.get_cmdline_user_args())
	_construire_scene()
	_imprimer_rapport_boites()
	if _capture != "":
		_capturer_puis_quitter()


func _lire_arguments(args: PackedStringArray) -> void:
	for a in args:
		if not a.begins_with("--"):
			continue
		var egal := a.find("=")
		var cle := a.substr(2, egal - 2) if egal >= 0 else a.substr(2)
		var val := a.substr(egal + 1) if egal >= 0 else ""
		match cle:
			"capture": _capture = val
			"objet": _objet_filtre = val
			"lumiere": _lumiere = clampf(float(val), 0.0, 1.0)
			"etat":
				if val == "allumee":
					_etat_allumee = true
				elif val == "eteinte":
					_etat_allumee = false
				else:
					push_warning("banc_objets : --etat attend allumee|eteinte (reçu « %s »)" % val)
			"opacite": _opacite_leurre = clampf(float(val), 0.0, 1.0)
			"frames": _frames = maxi(1, int(val))
			"taille":
				var parts := val.to_lower().split("x")
				if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
					_taille = Vector2i(int(parts[0]), int(parts[1]))
				else:
					push_warning("banc_objets : --taille attend LxH (reçu « %s »)" % val)
			"no-eos", "sans-maj", "eos-ephemeral":
				pass
			_:
				push_warning("banc_objets : argument inconnu --%s" % cle)


# ---------------------------------------------------------------------------
# CONSTRUCTION
# ---------------------------------------------------------------------------

func _construire_scene() -> void:
	_construire_environnement()
	_construire_sol()

	# `--objet` cadre serré sur UN objet (plus son corps d'échelle) — la
	# lisibilité se juge à cette échelle, jamais sur la rangée complète (voir
	# l'en-tête). « leurre » est un filtre à part : aucun objet du catalogue,
	# seulement le leurre et son corps d'échelle.
	var slugs: PackedStringArray = VoxelCatalogueObjetsT.slugs()
	var cadrage_serre := _objet_filtre != ""
	if _objet_filtre != "" and _objet_filtre != "leurre":
		if not slugs.has(_objet_filtre):
			push_error("banc_objets : objet inconnu « %s » (connus : %s, leurre)"
				% [_objet_filtre, ", ".join(slugs)])
			slugs = PackedStringArray()
		else:
			slugs = PackedStringArray([_objet_filtre])
	elif _objet_filtre == "leurre":
		slugs = PackedStringArray()

	var n := slugs.size()
	var espacement := ESPACEMENT_TUILES if n > 1 else 0.0
	for i in n:
		var slug: String = slugs[i]
		var noeud: Node3D = VoxelObjetT.new()
		noeud.name = "Objet_%s" % slug
		add_child(noeud)
		if not noeud.construire(slug):
			continue
		noeud.definir_lumiere(_lumiere)
		var x := (float(i) - float(n - 1) * 0.5) * espacement
		noeud.poser({"position": Vector2(x, 0.0) * float(CandelaTileSet.TILE_SIZE.x),
			"orientation": Vector2.DOWN, "allumee": _etat_allumee, "eteinte": not _etat_allumee})
		_objets.append({"slug": slug, "noeud": noeud})

	# Un corps debout, à part (une rangée derrière), pour juger l'échelle des
	# objets d'un coup d'œil — le brief le demande explicitement. Absent du
	# cadrage « leurre » : le leurre EST un corps, il n'a pas besoin d'un
	# second à côté pour s'y comparer.
	if _objet_filtre != "leurre":
		_corps_echelle = VoxelCorpsT.new()
		_corps_echelle.name = "CorpsEchelle"
		add_child(_corps_echelle)
		if _corps_echelle.construire(CLASSE_ECHELLE):
			_corps_echelle.definir_lumiere(_lumiere)
			_corps_echelle.poser({
				"position": Vector2(0.0, -ESPACEMENT_TUILES * 1.4) * float(CandelaTileSet.TILE_SIZE.x),
				"visee": Vector2.DOWN, "vitesse": Vector2.ZERO, "torche": true, "arme": CLASSE_ECHELLE,
				"tir": false, "touche": false, "mort": false, "t": 0.0,
			})

	# Le leurre — un VoxelCorps à part, sa propre démonstration d'effacement
	# (voir l'en-tête de `voxel_objets.gd`). Construit sauf quand le cadrage
	# ne montre qu'un seul AUTRE objet (inutile de l'y mêler).
	if _objet_filtre == "" or _objet_filtre == "leurre":
		_leurre = VoxelCorpsT.new()
		_leurre.name = "Leurre"
		add_child(_leurre)
		if _leurre.construire(CLASSE_LEURRE):
			_leurre.definir_lumiere(_lumiere)
			_leurre.poser({
				"position": Vector2(0.0, ESPACEMENT_TUILES * 1.6) * float(CandelaTileSet.TILE_SIZE.x),
				"visee": Vector2.DOWN, "vitesse": Vector2.ZERO, "torche": false, "arme": CLASSE_LEURRE,
				"tir": false, "touche": false, "mort": false, "arme_baissee": true, "t": 0.0,
			})
			if _opacite_leurre >= 0.0:
				_leurre.definir_opacite(_opacite_leurre)

	var largeur: float
	var profondeur: float
	if cadrage_serre:
		largeur = ESPACEMENT_TUILES * 2.2
		profondeur = ESPACEMENT_TUILES * 2.6
	else:
		largeur = float(n) * ESPACEMENT_TUILES + 2.0
		profondeur = ESPACEMENT_TUILES * 4.0 + 2.0
	_construire_camera(largeur, profondeur)
	_construire_bandeau()


func _construire_environnement() -> void:
	var monde := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.fog_enabled = false
	monde.environment = env
	add_child(monde)


## Même formule que `banc_corps._construire_sol()` : toujours plus sombre que
## le gris le plus bas du catalogue, pour que rien ne s'y fonde.
func _construire_sol() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(ESPACEMENT_TUILES * 8.0, ESPACEMENT_TUILES * 6.0)
	var inst := MeshInstance3D.new()
	inst.name = "Sol"
	inst.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://corps_iso.gdshader")
	mat.set_shader_parameter("couleur_fiche", Color(0.11, 0.115, 0.125))
	mat.set_shader_parameter("lumiere_recue", _lumiere)
	inst.material_override = mat
	add_child(inst)
	_sol_mat = mat


func _construire_camera(largeur_tuiles: float, profondeur_tuiles: float) -> void:
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var aspect := float(_taille.x) / float(_taille.y)
	# 52°, pas le 58° hérité de `banc_corps.gd` (antérieur à H15) : c'est le
	# tangage RÉELLEMENT tranché par Adrien pour le jeu (ROADMAP, « H15
	# tranché »), et le brief juge la lisibilité « dans la vue à 52° ».
	var pitch := deg_to_rad(52.0)
	var depuis_largeur := largeur_tuiles / aspect
	var depuis_profondeur := profondeur_tuiles * sin(pitch) + 1.0
	cam.size = maxf(depuis_largeur, depuis_profondeur) * 1.1
	cam.near = 0.05
	cam.far = 100.0
	var recul := (largeur_tuiles + profondeur_tuiles) * 1.5
	cam.position = Vector3(0.0, sin(pitch) * recul, cos(pitch) * recul)
	add_child(cam)
	cam.look_at(Vector3(0.0, 0.2, 0.0), Vector3.UP)
	cam.current = true


func _construire_bandeau() -> void:
	var couche := CanvasLayer.new()
	couche.name = "Bandeau"
	add_child(couche)
	_couche_bandeau = couche

	_bandeau = Label.new()
	_bandeau.position = Vector2(18, 14)
	_bandeau.add_theme_font_size_override("font_size", 13)
	_bandeau.add_theme_color_override("font_color", Charte.DIM)
	_bandeau.text = ("TAB objet suivi   ESPACE bascule son état   "
		+ "HAUT/BAS lumière ±0,05   ÉCHAP quitter")
	couche.add_child(_bandeau)

	_releve = Label.new()
	_releve.position = Vector2(18, 38)
	_releve.add_theme_font_size_override("font_size", 14)
	_releve.add_theme_color_override("font_color", Charte.HALOGENE)
	couche.add_child(_releve)
	_rafraichir_releve()


func _imprimer_rapport_boites() -> void:
	print("BANC_OBJETS — boîtes par objet :")
	for o in _objets:
		var noeud: Node3D = o["noeud"]
		print("  %-16s %d boîtes  hauteur=%.4f  empreinte=%.4f"
			% [o["slug"], noeud.nombre_de_boites(), noeud.hauteur_totale(), noeud.rayon_empreinte()])


func _rafraichir_releve() -> void:
	if _releve == null or _objets.is_empty():
		return
	var slug: String = _objets[_index_suivi]["slug"]
	_releve.text = ("objet=%s (%d/%d)  lumière=%.2f  état=%s"
		% [slug, _index_suivi + 1, _objets.size(), _lumiere,
			"allumé" if _etat_allumee else "éteint"])


# ---------------------------------------------------------------------------
# LA BOUCLE (mode interactif seulement)
# ---------------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var e: InputEventKey = event
	match e.keycode:
		KEY_ESCAPE:
			get_tree().quit()
		KEY_TAB:
			if not _objets.is_empty():
				_index_suivi = (_index_suivi + 1) % _objets.size()
			_rafraichir_releve()
		KEY_SPACE:
			_etat_allumee = not _etat_allumee
			_rafraichir_poses()
		KEY_UP:
			_lumiere = clampf(_lumiere + 0.05, 0.0, 1.0)
			_rafraichir_poses()
		KEY_DOWN:
			_lumiere = clampf(_lumiere - 0.05, 0.0, 1.0)
			_rafraichir_poses()


func _rafraichir_poses() -> void:
	for o in _objets:
		var noeud: Node3D = o["noeud"]
		noeud.definir_lumiere(_lumiere)
		var pos: Vector3 = noeud.position
		noeud.poser({"position": Vector2(pos.x, pos.z) * float(CandelaTileSet.TILE_SIZE.x),
			"orientation": Vector2.DOWN, "allumee": _etat_allumee, "eteinte": not _etat_allumee})
	if _corps_echelle != null:
		_corps_echelle.definir_lumiere(_lumiere)
	if _leurre != null:
		_leurre.definir_lumiere(_lumiere)
	if _sol_mat != null:
		_sol_mat.set_shader_parameter("lumiere_recue", _lumiere)
	_rafraichir_releve()


# ---------------------------------------------------------------------------
# LA CAPTURE
# ---------------------------------------------------------------------------

func _capturer_puis_quitter() -> void:
	var refus := RenduCommun.refus_headless()
	if refus != "":
		push_error("banc_objets : capture impossible — %s" % refus)
		get_tree().quit(3)
		return
	if _couche_bandeau != null:
		_couche_bandeau.visible = false
	get_window().size = _taille
	await get_tree().process_frame
	for i in _frames:
		await get_tree().process_frame
	var image: Image = await RenduCommun.capturer(get_tree(), 60000)
	if image == null:
		push_error("banc_objets : aucune image rendue en 60 s")
		get_tree().quit(4)
		return
	var dossier := _capture.get_base_dir()
	if dossier != "":
		DirAccess.make_dir_recursive_absolute(dossier)
	var erreur := image.save_png(_capture)
	if erreur != OK:
		push_error("banc_objets : écriture impossible de %s (%s)" % [_capture, error_string(erreur)])
		get_tree().quit(5)
		return
	print("BANC_OBJETS capture %s %dx%d (lumière=%.2f, état=%s, opacité leurre=%.2f)"
		% [_capture, image.get_width(), image.get_height(), _lumiere,
			"allumé" if _etat_allumee else "éteint", _opacite_leurre])
	if _lumiere == 0.0:
		var maxi := _valeur_max(image)
		print("BANC_OBJETS valeur maximale des pixels à lumière 0 : %.6f (doit être 0)" % maxi)
	get_tree().quit(0)


func _valeur_max(img: Image) -> float:
	var maxi := 0.0
	var largeur := img.get_width()
	var hauteur := img.get_height()
	for y in hauteur:
		for x in largeur:
			var c := img.get_pixel(x, y)
			maxi = maxf(maxi, maxf(c.r, maxf(c.g, c.b)))
	return maxi
