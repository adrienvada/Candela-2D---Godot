extends Node

## Le liseré du son rendu visible, pour UNE vue qui rend un joueur.
##
## Chantier SON VISIBLE (0.8.0, décisions d'Adrien du 2026-09-29) : chaque son
## localisé qu'entend le joueur de cette vue dessine, au bord de SON écran, un arc
## coloré dans la direction du son — d'autant plus large que le son est faible,
## lointain, derrière un mur ou noyé dans la salle. Le modèle (sortes, couleurs,
## largeurs, géométrie) est dans `son_visible.gd` ; ici, seulement la vue.
##
## ## Même patron que l'appareil de brouillage, et pour la même raison
##
## Un appareil par vue EFFECTIVEMENT rendue, logé par `GameState` là où la vue se
## rend : sous-vue 2D, racine en vue unique, viewport 3D de la vue iso
## (`GameState._logement_de_vue`). À l'intérieur d'un viewport, la conversion
## monde → écran est celle de ce viewport — ou celle de sa caméra iso, par
## `projecteur`. **On ne peut plus poser le liseré de J2 avec la caméra de J1**,
## défaut qu'aucun test ne verrait sans deux joueurs et un œil (même argument que
## `brouillage_vue.gd`, option 3 d'Adrien du 2026-08-26).
##
## ## Ce qui ne dessine rien
##
## - un son que le joueur de cette vue émet lui-même (`emetteur`) ou qui naît
##   sur lui : il sait où il est, et ses propres pas noieraient ceux de l'autre ;
## - une sorte muette (la salle) ; un son au-delà de sa portée ;
## - tout ce qui arrive hors du jeu vivant — killcam, fin de manche, décompte :
##   c'est `GameState` qui ouvre et ferme (`ouvert`), et une fermeture EFFACE, pour
##   qu'aucun liseré d'avant ne traîne sur la killcam.

const SonVisible := preload("res://son_visible.gd")

## Monde 2D → écran quand ce n'est plus la transformation de canevas de la vue qui
## le dit (vue iso). Posé par `GameState` à chaque accord des vues.
var projecteur := Callable()
## Le `player_id` du joueur que cette vue rend.
var regardeur_id := -1
## La couche de visibilité de ce joueur (`GadgetBase.couche_de_vue`) : même règle
## que le voile de dégâts, pour qu'un canevas partagé ne montre pas le liseré de
## l'un dans la vue de l'autre.
var couche_vue := 1
## Rend `false` quand le jeu n'est pas vivant ; posé par `GameState`.
var ouvert := Callable()

## Au-dessus de la vignette de dégâts (1), sous le HUD et le voile d'éblouissement
## (10) : un éblouissement lave aussi les bords, comme il lave le reste.
const COUCHE := 5
## Plus de liserés vivants que ça et le plus ancien cède : « trop de sons
## perturbent l'écoute » (Adrien), mais sans budget sans fond.
const TRACES_MAX := 48
## Épaisseur de référence : les épaisseurs du modèle sont données pour une vue de
## 1080 unités de haut.
const HAUTEUR_REFERENCE := 1080.0

var _couche: CanvasLayer
var _toile: Control
var _regardeur: Node2D
## Chaque trace : angle (rad, à l'écran), largeur (deg), alpha, epaisseur,
## duree, douceur, couleur, age.
var _traces: Array[Dictionary] = []


func _ready() -> void:
	_couche = CanvasLayer.new()
	_couche.name = "CalqueSons"
	_couche.layer = COUCHE
	add_child(_couche)
	_toile = Control.new()
	_toile.name = "Liseres"
	_toile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toile.visibility_layer = couche_vue
	_toile.draw.connect(_dessiner)
	_couche.add_child(_toile)
	set_process(false)


## Combien de liserés sont vivants — pour les suites et le panneau F3.
func traces_vivantes() -> int:
	return _traces.size()


## Une copie des traces vivantes, pour les suites.
func traces() -> Array[Dictionary]:
	return _traces.duplicate(true)


func vider() -> void:
	_traces.clear()
	set_process(false)
	if _toile != null:
		_toile.queue_redraw()


## Un son est arrivé : le perçoit-on d'ici, et si oui, dans quelle direction ?
## `part_occultee` est calculée par l'appelant, pour CE joueur (trois rayons, la
## géométrie de l'audio). Rend la trace ajoutée, ou `{}`.
func recevoir(evenement: Dictionary, regardeur: Node2D, part_occultee: float) -> Dictionary:
	if regardeur == null or not is_instance_valid(regardeur):
		return {}
	var categorie := SonVisible.categorie_de(String(evenement.get("famille", "")))
	if categorie < 0:
		return {}
	if regardeur_id >= 0 and int(evenement.get("emetteur", -1)) == regardeur_id:
		return {}
	var source: Vector2 = evenement.get("pos", Vector2.INF)
	var distance := regardeur.global_position.distance_to(source)
	if distance < SonVisible.RAYON_SOI_PX:
		return {}
	var p := SonVisible.percevoir(categorie, float(evenement.get("niveau_db", 0.0)), distance,
		float(evenement.get("portee", 0.0)), part_occultee, float(evenement.get("fumee_db", 0.0)),
		float(evenement.get("wet", 0.0)), float(evenement.get("diagonale", 0.0)))
	if p.is_empty():
		return {}
	var angle := SonVisible.angle_a_l_ecran(_a_l_ecran(regardeur.global_position),
		_a_l_ecran(source))
	if is_nan(angle):
		return {}
	_regardeur = regardeur
	var trace := {
		"angle": angle,
		"largeur": float(p["largeur"]),
		"alpha": float(p["alpha"]),
		"epaisseur": float(p["epaisseur"]),
		"duree": float(p["duree"]),
		"douceur": float(p["douceur"]),
		"couleur": SonVisible.couleur(categorie),
		"categorie": categorie,
		"age": 0.0,
	}
	if _traces.size() >= TRACES_MAX:
		_traces.remove_at(0)
	_traces.append(trace)
	set_process(true)
	return trace


func _process(delta: float) -> void:
	if ouvert.is_valid() and not bool(ouvert.call()):
		vider()
		return
	for i in range(_traces.size() - 1, -1, -1):
		_traces[i]["age"] = float(_traces[i]["age"]) + delta
		if float(_traces[i]["age"]) >= float(_traces[i]["duree"]):
			_traces.remove_at(i)
	if _traces.is_empty():
		set_process(false)
	_toile.queue_redraw()


## Un point du monde à l'écran de cette vue : par le projecteur de la vue iso quand
## il est posé, par la transformation de canevas sinon.
func _a_l_ecran(point: Vector2) -> Vector2:
	if projecteur.is_valid():
		return projecteur.call(point)
	var vue := get_viewport()
	if vue == null:
		return point
	return vue.get_canvas_transform() * point


func _dessiner() -> void:
	if _traces.is_empty():
		return
	var cadre := Rect2(Vector2.ZERO, _toile.size)
	if cadre.size.x < 2.0 or cadre.size.y < 2.0:
		return
	# L'origine des rayons est le joueur À L'ÉCRAN, pas le centre : la caméra
	# avance vers la visée (`decalage_visee`), le joueur n'est donc presque jamais
	# au centre, et c'est depuis LUI que la direction a été mesurée.
	var origine := cadre.get_center()
	if _regardeur != null and is_instance_valid(_regardeur):
		origine = _a_l_ecran(_regardeur.global_position)
	var echelle := cadre.size.y / HAUTEUR_REFERENCE
	var toile_rid := _toile.get_canvas_item()
	for t in _traces:
		var enveloppe := SonVisible.enveloppe(float(t["age"]), float(t["duree"]))
		if enveloppe <= 0.001:
			continue
		var b := SonVisible.bande(origine, float(t["angle"]), float(t["largeur"]), cadre,
			float(t["epaisseur"]) * echelle, float(t["douceur"]))
		var bords: PackedVector2Array = b["bords"]
		var dedans: PackedVector2Array = b["dedans"]
		var poids: PackedFloat32Array = b["poids"]
		var n := bords.size()
		if n < 2:
			continue
		var couleur: Color = t["couleur"]
		var alpha := float(t["alpha"]) * enveloppe
		# Un ruban de quadrilatères : le bord porte la couleur, l'intérieur fond au
		# transparent. Un seul appel par liseré, des triangles explicites — un
		# polygone à triangulation automatique relierait des sommets lointains d'un
		# ruban aussi fin.
		var points := PackedVector2Array()
		var couleurs := PackedColorArray()
		var indices := PackedInt32Array()
		for i in n:
			points.append(bords[i])
			couleurs.append(Color(couleur, alpha * poids[i]))
			points.append(dedans[i])
			couleurs.append(Color(couleur, 0.0))
		for i in n - 1:
			var a := 2 * i
			indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
		RenderingServer.canvas_item_add_triangle_array(toile_rid, indices, points, couleurs)
