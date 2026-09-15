class_name LocalInputProvider
extends InputProvider

## p1_torch/p2_torch est une gâchette analogique (L2), pas un bouton — voir
## `input_setup.gd`. Un vrai bouton mécanique à deux crans monnaie cette
## profondeur : un appui léger n'éclaire que tenu, un appui À FOND clique et
## reste enclenché jusqu'au clic suivant. En dessous, seule la zone morte de
## l'Input Map (0.2, posée par `input_setup.gd`) filtre — c'est le premier
## cran. Une manette qui n'a que des boutons (rebind au clavier exclu, voir
## `_test_chaque_bloc_n_accepte_que_son_appareil`) ne connaît que 0 ou 1 : elle
## saute donc directement au second cran, ce qui est le comportement voulu
## d'un bouton qui n'a pas de course.
const TORCH_CRAN_FOND := 0.9

## Vrai tant que le cran plein reste enclenché : la torche reste allumée
## gâchette relâchée, jusqu'au prochain appui à fond qui la débascule.
var _torch_enclenchee := false
## Profondeur à l'image précédente, pour ne détecter que le FRONT montant du
## cran plein — sans lui, un appui tenu à fond re-basculerait à chaque image.
var _torch_etait_a_fond := false

@export var device_id: int = 0 :
	set(val):
		device_id = val
		_setup_inputs()

var action_up := ""
var action_down := ""
var action_left := ""
var action_right := ""
var action_aim_up := ""
var action_aim_down := ""
var action_aim_left := ""
var action_aim_right := ""
var action_shoot := ""
var action_torch := ""
var action_flare := ""
var action_reload := ""
var action_gadget: String = ""
var action_crouch: String = ""
var action_climb: String = ""

## La bascule d'accroupissement (MB2) : vraie après un appui, fausse après le
## suivant. `_accroupir_tenu` garde l'état de la touche à l'appel précédent, pour
## ne basculer que sur le FRONT montant — une touche tenue ne clignote pas.
var _accroupi_voulu := false
var _accroupir_tenu := false

func _ready() -> void:
	_setup_inputs()

func _setup_inputs() -> void:
	var prefix = "p1_" if device_id == 0 else "p2_"
	action_up = prefix + "move_up"
	action_down = prefix + "move_down"
	action_left = prefix + "move_left"
	action_right = prefix + "move_right"
	
	action_aim_up = prefix + "aim_up"
	action_aim_down = prefix + "aim_down"
	action_aim_left = prefix + "aim_left"
	action_aim_right = prefix + "aim_right"
	
	action_shoot = prefix + "shoot"
	action_torch = prefix + "torch"
	action_flare = prefix + "lance_fusee"
	action_reload = prefix + "reload"
	action_gadget = prefix + "gadget"
	action_crouch = prefix + "accroupir"
	action_climb = prefix + "enjamber"

func get_movement_vector() -> Vector2:
	return Input.get_vector(action_left, action_right, action_up, action_down)

func get_aim_direction(player_global_pos: Vector2) -> Vector2:
	var aim_dir := Input.get_vector(action_aim_left, action_aim_right, action_aim_up, action_aim_down)
	# Fallback to mouse aiming for P1 if no gamepad stick input is detected
	if aim_dir.length() < 0.1 and device_id == 0:
		var cible = cible_de_la_souris(get_tree().root.get_mouse_position())
		if cible is Vector2:
			aim_dir = player_global_pos.direction_to(cible)
	else:
		# ISO5 — le stick tourné du lacet de la caméra iso (0° acté : sans effet).
		var iso := Presentation3D.instance()
		if iso != null:
			aim_dir = iso.stick_au_sol(get_parent(), aim_dir)
	return aim_dir

## Le point du monde sous le curseur. ISO5 — en vue iso, le rayon de la caméra de SON joueur coupé par le
## sol (`Presentation3D.point_au_sol`, `souris_racine` en unités logiques de la fenêtre) ; sinon, la vue
## de dessus, comme avant. La commande qui part sur le fil est la même direction du monde dans les deux
## cas : rien de la vue ne voyage.
func cible_de_la_souris(souris_racine: Vector2) -> Variant:
	var iso := Presentation3D.instance()
	if iso != null:
		var sol = iso.point_au_sol(get_parent(), souris_racine)
		if sol is Vector2:
			return sol
	var viewport = get_viewport()
	if viewport:
		return viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()
	return null

## La course brute sous laquelle une détente TENUE redevient relâchée.
##
## Plus basse que le seuil d'appui, qui est la zone morte de l'action, lue dans
## l'`InputMap` et jamais recopiée ici — elle vaut 0,5 dans `project.godot`, et
## non 0,2 comme l'ont longtemps dit les commentaires du dépôt : recopier un
## nombre, c'est hériter de son erreur. Entre les deux seuils l'état ne change
## pas, si bien qu'une gâchette qui tremble autour du seuil ne peut plus
## redéclencher un tir.
##
## ⚠️ **Nécessaire depuis que le tir est semi-automatique** (2026-09-10). Tant
## que la détente tenue tirait en boucle, un tremblement ne coûtait rien ; dès
## qu'un appui vaut un tir, chaque oscillation autour du seuil en vaudrait un.
## Sans effet sur un clic ou une touche, qui ne valent que 0 ou 1.
const TIR_REARME := 0.25
var _tir_tenu := false

func is_shoot_pressed() -> bool:
	if not InputMap.has_action(action_shoot):
		return false
	# `raw` et non `get_action_strength` : ce dernier rend 0 sous la zone morte,
	# et ne verrait donc pas la plage qui sépare les deux seuils.
	var course := Input.get_action_raw_strength(action_shoot)
	# Plancher à 0,05 : une zone morte nulle ferait passer toute course, même
	# nulle, pour un appui — la détente serait réputée tenue en permanence.
	var seuil := maxf(InputMap.action_get_deadzone(action_shoot), 0.05)
	_tir_tenu = course >= (minf(TIR_REARME, seuil) if _tir_tenu else seuil)
	return _tir_tenu

func is_flashlight_pressed() -> bool:
	var profondeur := Input.get_action_strength(action_torch)
	var a_fond := profondeur >= TORCH_CRAN_FOND
	if a_fond and not _torch_etait_a_fond:
		_torch_enclenchee = not _torch_enclenchee
	_torch_etait_a_fond = a_fond
	# `profondeur > 0.0` : la zone morte de l'action est déjà passée par
	# `get_action_strength`, donc équivalent à l'ancien `is_action_pressed` —
	# c'est le premier cran, qui n'ajoute rien au clic tant qu'il dure.
	return _torch_enclenchee or profondeur > 0.0

## Appelé à chaque nouvelle manche (voir `Player.reset_flashlight_latch()`) :
## un clic laissé enclenché avant la mort ne doit pas rallumer la torche tout
## seul au spawn suivant, sans qu'aucune gâchette n'ait bougé cette manche-là.
func reset_flashlight_state() -> void:
	_torch_enclenchee = false
	_torch_etait_a_fond = false

## Rien ne distinguait « j'éclaire en tenant » de « j'ai verrouillé, je peux
## lâcher » (relevé par Adrien, 2026-09-10) : lâcher la gâchette en croyant
## éteindre, dans ce jeu, c'est se trahir. Voir `InputProvider`.
func is_flashlight_locked() -> bool:
	return _torch_enclenchee

func is_flare_pressed() -> bool:
	return Input.is_action_pressed(action_flare)

func is_reload_pressed() -> bool:
	return Input.is_action_pressed(action_reload)

func is_gadget_pressed() -> bool:
	return Input.is_action_pressed(action_gadget)

## En bascule (choix d'Adrien, 2026-09-14). ⚠️ Appelé PLUSIEURS fois par image
## (émission des commandes, puis simulation) : le front ne se compte qu'une fois,
## parce que le second appel voit la touche déjà tenue.
func is_crouch_pressed() -> bool:
	if action_crouch == "" or not InputMap.has_action(action_crouch):
		return false
	var tenu := Input.is_action_pressed(action_crouch)
	if tenu and not _accroupir_tenu:
		_accroupi_voulu = not _accroupi_voulu
	_accroupir_tenu = tenu
	return _accroupi_voulu

## À chaque manche : on réapparaît debout, quelle que soit la posture à la mort.
func reset_crouch_state() -> void:
	_accroupi_voulu = false
	_accroupir_tenu = false

## Tenu, pas en bascule (MB3b, choix d'Adrien).
func is_climb_pressed() -> bool:
	return action_climb != "" and InputMap.has_action(action_climb) \
		and Input.is_action_pressed(action_climb)
