extends Node3D

## Le banc des CORPS VOXEL — chantier ISO, étape ISO3 (vague 0 : les dix corps
## et leurs mouvements ; vague 1 : accroupi et enjambement).
##
## Dix corps sur une grille, une lumière SIMULÉE (pas une `Light3D` — voir plus
## bas), des touches pour déclencher marche, tir, touché, mort, accroupi,
## enjambement. C'est le seul endroit où l'on voit les dix classes ensemble
## avant qu'ISO2 ne pose de vrais capteurs.
##
## ## Pourquoi la lumière est simulée, et pas une vraie `Light3D`
##
## Cette étape ne pose aucun capteur (c'est ISO2) : `lumiere_recue` est un
## simple uniform que quelqu'un règle de l'extérieur. Ici, c'est le curseur du
## banc — `definir_lumiere()` sur chaque corps, directement, sans lumière
## traversant une scène. Le cône dessiné dans la scène est un REPÈRE VISUEL
## (où une torche pointerait), pas une source qui participerait au calcul :
## bouger le cône ne change rien à ce que les corps reçoivent. Une vraie
## `Light3D` ici referait exactement l'erreur qu'ISO0 a écartée (§ 5.3 de
## `docs/ETUDE_ISO.md`) — une deuxième vérité d'ombre, à côté de celle que la
## lightmap 2D décidera plus tard.
##
## ## Lancer
##
##   godot --path . tools/banc_corps.tscn
##   godot --path . tools/banc_corps.tscn -- --lumiere=0 --capture=/chemin/noir.png
##   godot --path . tools/banc_corps.tscn -- --classe=spectre --lumiere=0.8 --capture=/chemin/spectre.png
##   godot --path . tools/banc_corps.tscn -- --pose=accroupi --lumiere=0.8 --capture=/chemin/accroupi.png
##   godot --path . tools/banc_corps.tscn -- --pose=enjambe --lumiere=0.8 --capture=/chemin/enjambe.png
##
## Sans `--capture`, la fenêtre reste ouverte et interactive. Comme
## `tools/proto_iso.gd`, la capture exige une vraie fenêtre (`RenduCommun`) et
## refuse en headless plutôt que d'y pendre.
##
## ## Le rapport
##
## Toujours : le nombre de boîtes par corps (neuf attendues, voir
## `tools/test_voxel_corps.gd`). À `--lumiere=0` ET `--capture`, en plus : la
## valeur maximale des pixels de l'image rendue — elle doit être exactement 0,
## et c'est un examen réel du rendu, pas une lecture d'uniform (voir la suite
## headless, qui elle ne peut que lire les nombres).

const VoxelCorpsT := preload("res://voxel_corps.gd")
const VoxelCatalogueT := preload("res://voxel_catalogue.gd")
const Charte := preload("res://charte.gd")

const COLONNES := 5
const ESPACEMENT_TUILES := 2.4
const VITESSE_MARCHE_PX := 220.0     # px/s — cohérent avec l'ordre de grandeur du jeu, sans le recopier
const VITESSE_MARCHE_ACCROUPI_PX := 55.0  # px/s — ordre de grandeur du ×0,25 du jeu (MB2), pas recopié
const DUREE_TIR := 0.12
const DUREE_TOUCHE := 0.5
const DUREE_ENJAMBE_BANC := 0.5      # « ton banc le simule sur une demi-seconde » (brief ISO3 vague 1)

var _capture := ""
var _classe_filtre := ""
var _pose_forcee := ""               # "" | "accroupi" | "enjambe" — --pose, pour la planche
var _lumiere := 0.6
var _taille := Vector2i(1920, 1080)
var _frames := 3

var _corps: Array = []     # [{ "slug": String, "noeud": VoxelCorps, "pos_px": Vector2 }]
var _temps := 0.0
var _marche := false
var _tir_t0 := -1.0
var _touche_t0 := -1.0
var _mort_t0 := -1.0
var _accroupi := false
var _accroupi_t0 := 0.0
var _enjambe_t0 := -1.0

var _bandeau: Label
var _releve: Label
var _sol_mat: ShaderMaterial
var _couche_bandeau: CanvasLayer
var _cone_repere: MeshInstance3D


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
			"classe": _classe_filtre = val
			"lumiere": _lumiere = clampf(float(val), 0.0, 1.0)
			"frames": _frames = maxi(1, int(val))
			"pose":
				if val == "accroupi" or val == "enjambe":
					_pose_forcee = val
				else:
					push_warning("banc_corps : --pose attend accroupi|enjambe (reçu « %s »)" % val)
			"taille":
				var parts := val.to_lower().split("x")
				if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
					_taille = Vector2i(int(parts[0]), int(parts[1]))
				else:
					push_warning("banc_corps : --taille attend LxH (reçu « %s »)" % val)
			"no-eos", "sans-maj", "eos-ephemeral":
				pass
			_:
				push_warning("banc_corps : argument inconnu --%s" % cle)


# ---------------------------------------------------------------------------
# CONSTRUCTION
# ---------------------------------------------------------------------------

func _construire_scene() -> void:
	_construire_environnement()
	_construire_sol()
	_construire_cone_repere()

	var slugs: PackedStringArray = VoxelCatalogueT.slugs()
	if _classe_filtre != "":
		if not slugs.has(_classe_filtre):
			push_error("banc_corps : classe inconnue « %s » (connues : %s)"
				% [_classe_filtre, ", ".join(slugs)])
			slugs = PackedStringArray()
		else:
			slugs = PackedStringArray([_classe_filtre])

	var n := slugs.size()
	var colonnes := 1 if n == 1 else COLONNES
	var tuile := float(CandelaTileSet.TILE_SIZE.x)
	for i in n:
		var slug: String = slugs[i]
		var col := i % colonnes
		var ligne := i / colonnes
		var demi_largeur := float(colonnes - 1) * 0.5
		var demi_hauteur := float((n - 1) / colonnes) * 0.5
		var x_tuiles := (float(col) - demi_largeur) * ESPACEMENT_TUILES
		var z_tuiles := (float(ligne) - demi_hauteur) * ESPACEMENT_TUILES

		var noeud: Node3D = VoxelCorpsT.new()
		noeud.name = "Corps_%s" % slug
		add_child(noeud)
		if not noeud.construire(slug):
			continue
		noeud.definir_lumiere(_lumiere)
		_corps.append({
			"slug": slug, "noeud": noeud,
			"pos_px": Vector2(x_tuiles, z_tuiles) * tuile,
		})

	var lignes: int = (n + colonnes - 1) / colonnes if n > 0 else 1
	var largeur: float = float(maxi(colonnes - 1, 0)) * ESPACEMENT_TUILES + 2.0
	var profondeur: float = float(maxi(lignes - 1, 0)) * ESPACEMENT_TUILES + 2.0
	_construire_camera(largeur, profondeur)
	_construire_bandeau()
	_rafraichir_poses()


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


## Un plan sombre, juste assez visible pour situer les pieds — jamais assez
## clair pour fausser le relevé « valeur maximale à lumière 0 » : sa propre
## teinte est nulle à `_lumiere == 0`, par la même formule que les corps.
## Toujours plus sombre que le gris le plus bas du catalogue (55 % du plafond,
## `VoxelCatalogue._facteur_gris`) : sans cette marge, l'Occulteur — le plus
## sombre des dix — se fond dans le sol au lieu de s'en détacher.
func _construire_sol() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(ESPACEMENT_TUILES * (COLONNES + 1), ESPACEMENT_TUILES * 4.0)
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


## Repère purement visuel — voir l'en-tête du fichier.
func _construire_cone_repere() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.35
	mesh.height = 1.4
	var inst := MeshInstance3D.new()
	inst.name = "ConeRepere"
	inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(Charte.AMBRE, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inst.material_override = mat
	inst.position = Vector3(-ESPACEMENT_TUILES * 2.4, 2.2, -1.2)
	inst.rotation_degrees = Vector3(-55.0, 20.0, 0.0)
	add_child(inst)
	_cone_repere = inst


## `size` est le DEMI-côté vertical en mode `KEEP_HEIGHT` (le défaut de
## `Camera3D`) : la largeur visible vaut `size * aspect`. La scène est large
## (cinq colonnes) et peu profonde (deux rangées) — c'est presque toujours la
## largeur qui commande, jamais la profondeur brute (le tangage la raccourcit
## encore par `sin(tangage)`).
func _construire_camera(largeur_tuiles: float, profondeur_tuiles: float) -> void:
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var aspect := float(_taille.x) / float(_taille.y)
	var pitch := deg_to_rad(58.0)
	var depuis_largeur := largeur_tuiles / aspect
	var depuis_profondeur := profondeur_tuiles * sin(pitch) + 1.0
	cam.size = maxf(depuis_largeur, depuis_profondeur) * 1.1
	cam.near = 0.05
	cam.far = 100.0
	var recul := (largeur_tuiles + profondeur_tuiles) * 1.5
	cam.position = Vector3(0.0, sin(pitch) * recul, cos(pitch) * recul)
	add_child(cam)
	cam.look_at(Vector3(0.0, 0.4, 0.0), Vector3.UP)
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
	_bandeau.text = ("ESPACE marche   T tir   H touché   M mort   R reviens   "
		+ "A accroupi   E enjamber   HAUT/BAS lumière ±0,05   ÉCHAP quitter")
	couche.add_child(_bandeau)

	_releve = Label.new()
	_releve.position = Vector2(18, 38)
	_releve.add_theme_font_size_override("font_size", 14)
	_releve.add_theme_color_override("font_color", Charte.HALOGENE)
	couche.add_child(_releve)


# ---------------------------------------------------------------------------
# LE RAPPORT
# ---------------------------------------------------------------------------

func _imprimer_rapport_boites() -> void:
	print("BANC_CORPS — boîtes par corps :")
	for c in _corps:
		var noeud: Node3D = c["noeud"]
		print("  %-12s %d boîtes" % [c["slug"], noeud.nombre_de_boites()])


# ---------------------------------------------------------------------------
# LA BOUCLE
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_temps += delta

	if _tir_t0 >= 0.0 and _temps - _tir_t0 > DUREE_TIR:
		_tir_t0 = -1.0
	if _touche_t0 >= 0.0 and _temps - _touche_t0 > DUREE_TOUCHE:
		_touche_t0 = -1.0

	_rafraichir_poses()
	_rafraichir_releve()


## Voir l'en-tête « pourquoi `t` change de sens » dans `voxel_corps.gd` : hors
## d'un déclencheur transitoire, `t` est l'horloge continue du banc (la marche
## et la respiration en ont besoin) ; pendant un tir, un touché ou le passage
## à accroupi, `t` redevient le temps ÉCOULÉ DEPUIS LE DÉCLENCHEMENT, sans quoi
## l'enveloppe de recul, la secousse ou la bascule accroupie — calées sur une
## fenêtre de quelques centaines de ms — liraient un `t` déjà grand et
## resteraient à leur valeur de repos. `enjambe`, lui, n'a pas besoin de ce
## traitement : c'est l'appelant qui fournit directement la progression 0..1,
## voir l'en-tête de `voxel_corps.gd`.
func _rafraichir_poses() -> void:
	var tir := _tir_t0 >= 0.0
	var touche := _touche_t0 >= 0.0
	var mort := _mort_t0 >= 0.0

	var t := _temps
	if mort:
		t = _temps - _mort_t0
	elif tir or touche:
		var debut := _temps
		if tir:
			debut = minf(debut, _tir_t0)
		if touche:
			debut = minf(debut, _touche_t0)
		t = _temps - debut
	elif _accroupi:
		t = _temps - _accroupi_t0

	var enjambe := 0.0
	if _enjambe_t0 >= 0.0:
		var progres := (_temps - _enjambe_t0) / DUREE_ENJAMBE_BANC
		if progres >= 1.0:
			_enjambe_t0 = -1.0
		else:
			enjambe = progres

	# La vitesse suit la posture : ×0,25 accroupi, comme MB2 (grandeur du jeu,
	# jamais recopiée — voir la constante).
	var vitesse_base := VITESSE_MARCHE_ACCROUPI_PX if _accroupi else VITESSE_MARCHE_PX
	var vitesse := Vector2(vitesse_base, 0.0) if (_marche and not mort) else Vector2.ZERO

	var accroupi_effectif := _accroupi
	if _pose_forcee == "accroupi":
		accroupi_effectif = true
		t = 1.0  # bien au-delà de DUREE_TRANSITION_ACCROUPI : posture stabilisée
	elif _pose_forcee == "enjambe":
		enjambe = 0.5  # le milieu du geste — le plus lisible sur une planche figée

	for c in _corps:
		var noeud: Node3D = c["noeud"]
		noeud.poser({
			"position": c["pos_px"], "visee": Vector2(0.0, 1.0), "vitesse": vitesse,
			"torche": true, "arme": c["slug"], "tir": tir, "touche": touche,
			"mort": mort, "accroupi": accroupi_effectif, "enjambe": enjambe, "t": t,
		})

	if _sol_mat != null:
		_sol_mat.set_shader_parameter("lumiere_recue", _lumiere)


func _rafraichir_releve() -> void:
	if _releve == null:
		return
	_releve.text = ("lumière %.2f · %s%s%s%s%s%s · %d corps"
		% [_lumiere,
			"marche" if _marche else "repos",
			" · TIR" if _tir_t0 >= 0.0 else "",
			" · TOUCHÉ" if _touche_t0 >= 0.0 else "",
			" · MORT" if _mort_t0 >= 0.0 else "",
			" · ACCROUPI" if _accroupi else "",
			" · ENJAMBE" if _enjambe_t0 >= 0.0 else "",
			_corps.size()])


# ---------------------------------------------------------------------------
# LES COMMANDES
# ---------------------------------------------------------------------------

func _unhandled_input(evt: InputEvent) -> void:
	if not (evt is InputEventKey) or not evt.pressed or evt.echo:
		return
	var kc := (evt as InputEventKey).keycode
	match kc:
		KEY_ESCAPE:
			get_tree().quit()
		KEY_SPACE:
			_marche = not _marche
		KEY_T:
			_tir_t0 = _temps
		KEY_H:
			_touche_t0 = _temps
		KEY_M:
			_mort_t0 = _temps
		KEY_R:
			_mort_t0 = -1.0
			_tir_t0 = -1.0
			_touche_t0 = -1.0
		KEY_A:
			_accroupi = not _accroupi
			if _accroupi:
				_accroupi_t0 = _temps
		KEY_E:
			_enjambe_t0 = _temps
		KEY_UP:
			_lumiere = clampf(_lumiere + 0.05, 0.0, 1.0)
			for c in _corps:
				(c["noeud"] as Node3D).definir_lumiere(_lumiere)
		KEY_DOWN:
			_lumiere = clampf(_lumiere - 0.05, 0.0, 1.0)
			for c in _corps:
				(c["noeud"] as Node3D).definir_lumiere(_lumiere)


# ---------------------------------------------------------------------------
# CAPTURE
# ---------------------------------------------------------------------------

func _capturer_puis_quitter() -> void:
	var refus := RenduCommun.refus_headless()
	if refus != "":
		push_error("banc_corps : capture impossible — %s" % refus)
		get_tree().quit(3)
		return
	# Ni le bandeau (texte clair, hors sujet) ni le cône repère (couleur fixe,
	# indifférente au curseur de lumière) ne doivent entrer dans une capture :
	# le premier fausserait toute lecture, le second romprait à lui seul la
	# preuve du noir absolu à lumière 0.
	if _couche_bandeau != null:
		_couche_bandeau.visible = false
	if _cone_repere != null:
		_cone_repere.visible = false
	get_window().size = _taille
	await get_tree().process_frame
	for i in _frames:
		await get_tree().process_frame
	var image: Image = await RenduCommun.capturer(get_tree(), 60000)
	if image == null:
		push_error("banc_corps : aucune image rendue en 60 s")
		get_tree().quit(4)
		return
	var dossier := _capture.get_base_dir()
	if dossier != "":
		DirAccess.make_dir_recursive_absolute(dossier)
	var erreur := image.save_png(_capture)
	if erreur != OK:
		push_error("banc_corps : écriture impossible de %s (%s)" % [_capture, error_string(erreur)])
		get_tree().quit(5)
		return
	print("BANC_CORPS capture %s %dx%d (lumière=%.2f)" % [_capture, image.get_width(), image.get_height(), _lumiere])
	if _lumiere == 0.0:
		var maxi := _valeur_max(image)
		print("BANC_CORPS valeur maximale des pixels à lumière 0 : %.6f (doit être 0)" % maxi)
	get_tree().quit(0)


## Balayage complet (pas un échantillon) : à lumière nulle, la revendication
## est « aucun pixel », et un pixel manqué par un pas d'échantillonnage serait
## exactement le genre de défaut que ce banc existe pour attraper.
func _valeur_max(img: Image) -> float:
	var maxi := 0.0
	var largeur := img.get_width()
	var hauteur := img.get_height()
	for y in hauteur:
		for x in largeur:
			var c := img.get_pixel(x, y)
			maxi = maxf(maxi, maxf(c.r, maxf(c.g, c.b)))
	return maxi
