## Banc d'observation de la fusée éclairante — chantier FUSÉE, FU1-FU2.
##
## Lancer : godot --path . res://tools/banc_fusee.tscn
## (fenêtré : il montre de la lumière, de la fumée et des ombres — un lanceur
## headless n'y verrait rien, il refuse donc de démarrer sans écran.)
##
## Ce banc OBSERVE : clic gauche lance une fusée vers le curseur, les touches
## sautent d'acte en acte, un mannequin suit la souris (bouton droit tenu) pour
## juger la silhouette et le sillage. Les MOLETTES de dosage arriveront avec
## l'étape FU6 — elles demandent de paramétrer le modèle, et un dosage se fait
## en séance avec Adrien, pas en éditant une constante à l'aveugle.
##
## Touches : clic gauche = lancer · clic droit tenu = déplacer le mannequin
## mobile · 1/2/3/4 = sauter au plein feu / à la braise / à l'agonie / au résidu ·
## Espace = figer l'âge · R = tout relancer · A = lumière d'inspection ·
## Échap = quitter.
extends Node2D

const RenduCommun := preload("res://tools/rendu_commun.gd")

var _fusee: Fusee
var _fige: bool = false
var _mannequin_fixe: Sprite2D
var _mannequin_mobile: Sprite2D
var _inspection: PointLight2D
var _panneau: Label


func _ready() -> void:
	var refus := RenduCommun.refus_headless()
	if refus != "":
		push_error(refus)
		get_tree().quit(1)
		return

	# Le décor minimal : un sol lit la lumière, deux murs l'occluent — la
	# découpe des ombres dans la fumée est précisément ce qu'on vient juger.
	_poser_sol()
	_poser_mur(Rect2(Vector2(340.0, 120.0), Vector2(40.0, 260.0)))
	_poser_mur(Rect2(Vector2(700.0, 420.0), Vector2(260.0, 40.0)))

	_mannequin_fixe = _poser_mannequin(Vector2(760.0, 300.0), Color(0.85, 0.35, 0.30))
	_mannequin_mobile = _poser_mannequin(Vector2(300.0, 500.0), Color(0.35, 0.55, 0.90))

	_inspection = PointLight2D.new()
	_inspection.texture = LightTextures.radial(256)
	_inspection.texture_scale = 8.0
	_inspection.energy = 0.5
	_inspection.color = Color(0.5, 0.5, 0.55)
	_inspection.enabled = false
	_inspection.position = Vector2(640.0, 360.0)
	add_child(_inspection)

	var couche := CanvasLayer.new()
	add_child(couche)
	_panneau = Label.new()
	_panneau.position = Vector2(12.0, 10.0)
	_panneau.add_theme_color_override("font_color", Color(0.92, 0.90, 0.85))
	_panneau.add_theme_color_override("font_outline_color", Color.BLACK)
	_panneau.add_theme_constant_override("outline_size", 6)
	couche.add_child(_panneau)


func _poser_sol() -> void:
	var sol := Polygon2D.new()
	sol.polygon = PackedVector2Array([Vector2.ZERO, Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)])
	sol.color = Color(0.16, 0.155, 0.15)
	add_child(sol)


## Un mur du banc porte TOUJOURS ses deux moitiés — collision et occlusion —
## comme `map_geometry.gd` : sans occluder, la fumée ne serait jamais découpée
## et le banc jugerait un rendu qui n'existe pas en jeu.
func _poser_mur(r: Rect2) -> void:
	var visuel := Polygon2D.new()
	visuel.polygon = PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0.0),
		r.end, r.position + Vector2(0.0, r.size.y)])
	visuel.color = Color(0.34, 0.33, 0.32)
	add_child(visuel)

	var corps := StaticBody2D.new()
	corps.position = r.get_center()
	var forme := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	forme.shape = rect
	corps.add_child(forme)
	add_child(corps)

	var occluder := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.polygon = visuel.polygon
	occluder.occluder = poly
	add_child(occluder)


func _poser_mannequin(pos: Vector2, teinte: Color) -> Sprite2D:
	var m := Sprite2D.new()
	m.texture = LightTextures.radial(32)
	m.scale = Vector2.ONE * 1.6
	m.modulate = teinte
	m.position = pos
	# Couche « sprite ennemi » : la fusée éclaire 1|2|4, les torches 2 aussi.
	m.light_mask = 2
	add_child(m)
	return m


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_lancer(get_global_mouse_position())
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				get_tree().quit()
			KEY_SPACE:
				_fige = not _fige
			KEY_R:
				_lancer(Vector2(640.0, 360.0))
			KEY_A:
				_inspection.enabled = not _inspection.enabled
			KEY_1:
				_sauter(0.1)
			KEY_2:
				_sauter(FuseeModele.DUREE_PLEIN_FEU + FuseeModele.RACCORD_PLEIN_FEU_BRAISE + 0.1)
			KEY_3:
				_sauter(FuseeModele.DUREE_PLEIN_FEU + FuseeModele.DUREE_BRAISE + 0.1)
			KEY_4:
				_sauter(FuseeModele.DUREE_PLEIN_FEU + FuseeModele.DUREE_BRAISE
					+ FuseeModele.DUREE_AGONIE + 0.1)


func _lancer(cible: Vector2) -> void:
	if is_instance_valid(_fusee):
		_fusee.queue_free()
	_fusee = Fusee.new()
	# VIVANTE depuis FU2.1 : le vol rebondit sur les murs du banc — c'est
	# précisément ce qu'on vient juger. L'audio reste muet (fichiers absents).
	_fusee.depart = Vector2(80.0, 660.0)
	_fusee.direction = (cible - _fusee.depart).normalized()
	_fusee.graine = randi()
	_fusee.joueurs = [_mannequin_fixe, _mannequin_mobile]
	_fusee.name = "FuseeBanc"
	add_child(_fusee)
	_fige = false


## Saute à un âge de COMBUSTION donné : la fusée se pose là où elle est.
func _sauter(age_combustion: float) -> void:
	if not is_instance_valid(_fusee):
		_lancer(Vector2(640.0, 360.0))
	_fusee.forcer_age(age_combustion)


func _process(_delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_mannequin_mobile.global_position = get_global_mouse_position()

	if is_instance_valid(_fusee):
		# Figer = suspendre la physique de la fusée, l'horloge est la sienne.
		_fusee.set_physics_process(not _fige)

	_maj_panneau()


func _maj_panneau() -> void:
	var etat := "aucune fusée — clic gauche pour lancer"
	if is_instance_valid(_fusee):
		var age_combustion: float = _fusee.age_combustion()
		var noms := {
			FuseeModele.Acte.VOL: "VOL", FuseeModele.Acte.PLEIN_FEU: "PLEIN FEU",
			FuseeModele.Acte.BRAISE: "BRAISE", FuseeModele.Acte.AGONIE: "AGONIE",
			FuseeModele.Acte.RESIDU: "RÉSIDU", FuseeModele.Acte.MORTE: "MORTE",
		}
		etat = "acte %s · âge %.1f s%s" % [noms[FuseeModele.acte_a(age_combustion)],
			maxf(age_combustion, 0.0), " · FIGÉ" if _fige else ""]
	_panneau.text = "BANC FUSÉE — %s\n%d img/s · clic G lancer · clic D mannequin · 1-4 actes · Espace figer · R relancer · A inspection · Échap quitter" \
		% [etat, Engine.get_frames_per_second()]
