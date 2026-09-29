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
##
## ## Chaque liseré suit son son (Adrien, 2026-09-29)
##
## Une trace porte sa `vie` (`SonVisible.animer`) : le niveau perçu à chaque instant,
## tiré de la forme d'onde du fichier joué puis de la traîne de la salle. À chaque image
## `SonVisible.etat` en tire l'opacité, l'épaisseur, la largeur et le bord ; la trace
## s'éteint quand son niveau repasse sous le seuil, pas au bout d'un temps fixe. Une
## source continue (la combustion) est plate, et son annonce REMPLACE la précédente de la
## même source. Sans enveloppe connue, la trace retombe sur la durée par sorte
## (`repli_compte` le dit : un repli doit se voir).
##
## ## Les liserés s'ADDITIONNENT (Q52, Adrien, 2026-09-29)
##
## > « Il faudrait que l'addition de bruits brouille, ou change la couleur : on additionne
## > les liserés en couleur pour qu'ils virent au blanc ? »
##
## La toile est en mélange ADDITIF : plusieurs sons au même endroit ajoutent leurs
## couleurs et tirent vers le blanc — le brouillage d'une fusillade devient visible, et
## on ne distingue plus les sortes quand tout se mélange. **Sur du noir, un liseré seul
## est inchangé** (`dessous + couleur × alpha`, avec un dessous nul) ; sur une zone
## éclairée il est PLUS CLAIR qu'en mélange normal (le mélange normal écrasait le
## dessous de `alpha`, l'addition le garde et lui ajoute).

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
## Chaque trace : angle (rad, à l'écran), et au pic largeur (deg), alpha, epaisseur,
## douceur ; duree (s), couleur, age, `vie` (l'animation, voir `SonVisible.animer`, ou `{}`
## pour le repli), `cle` et `source` (qui distinguent une source continue d'une autre).
var _traces: Array[Dictionary] = []
## Combien de liserés sont retombés sur la durée par sorte faute d'enveloppe connue. Un
## son du jeu n'y tombe jamais (`tools/test_enveloppes_sons.gd`) : ce compteur dit à qui
## l'ouvre qu'un son est arrivé qu'on ne sait pas animer.
var repli_compte := 0
## Combien de liserés cette vue a reçus depuis sa création (une source continue qui remplace
## sa propre annonce compte aussi). Lu par `tools/bench_framerate.gd` : une prise de cadence
## doit dire si le son visible dessinait pendant qu'elle mesurait, sans quoi « avec liserés »
## et « sans » ne se distinguent pas après coup (relevé par Gadgets, 2026-09-29).
var recus_compte := 0


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
	poser_melange(true)
	set_process(false)


## Le mélange de la toile : ADDITIF (Q52) ou le mélange normal d'avant. Le banc d'images
## s'en sert pour montrer une fusillade avant et après ; le jeu, jamais.
func poser_melange(additif: bool) -> void:
	if _toile == null:
		return
	if additif:
		var materiau := CanvasItemMaterial.new()
		materiau.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_toile.material = materiau
	else:
		_toile.material = null


func melange_additif() -> bool:
	if _toile == null:
		return false
	var materiau := _toile.material as CanvasItemMaterial
	return materiau != null and materiau.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD


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
	# La vie du liseré : la forme d'onde du fichier joué, puis la traîne de la salle. Vide si
	# on ne connaît pas ce son — la trace retombe alors sur la durée par sorte.
	var vie := SonVisible.animer(categorie, p, evenement, part_occultee)
	if vie.is_empty():
		repli_compte += 1
	var trace := {
		# Au pic : ce que `percevoir` a décidé, et ce que les suites lisent.
		"angle": angle,
		"largeur": float(p["largeur"]),
		"alpha": float(p["alpha"]),
		"epaisseur": float(p["epaisseur"]),
		"douceur": float(p["douceur"]),
		"couleur": SonVisible.couleur(categorie),
		"categorie": categorie,
		# Et sa vie : combien de temps, et comment.
		"duree": float(vie["duree"]) if not vie.is_empty() else float(p["duree"]),
		"vie": vie,
		"age": 0.0,
		"cle": String(evenement.get("cle", "")),
		"source": int(evenement.get("source", 0)),
	}
	# Une source continue REMPLACE sa propre annonce précédente : deux liserés plats l'un sur
	# l'autre, avec l'addition, feraient une bosse à chaque période.
	if bool(vie.get("continu", false)):
		for i in _traces.size():
			var autre: Dictionary = _traces[i]
			if bool(autre["vie"].get("continu", false)) \
					and autre["cle"] == trace["cle"] and autre["source"] == trace["source"]:
				_traces[i] = trace
				recus_compte += 1
				set_process(true)
				return trace
	if _traces.size() >= TRACES_MAX:
		_traces.remove_at(0)
	_traces.append(trace)
	recus_compte += 1
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
		# Ce que la trace montre À CET ÂGE : sa présence suit le son, sa largeur s'ouvre avec
		# la salle. Au pic, c'est exactement ce que `percevoir` avait rendu.
		var etat := SonVisible.etat(t, float(t["age"]))
		if etat.is_empty() or float(etat["alpha"]) <= 0.001:
			continue
		var b := SonVisible.bande(origine, float(t["angle"]), float(etat["largeur"]), cadre,
			float(etat["epaisseur"]) * echelle, float(etat["douceur"]))
		var bords: PackedVector2Array = b["bords"]
		var milieu: PackedVector2Array = b["milieu"]
		var dedans: PackedVector2Array = b["dedans"]
		var poids: PackedFloat32Array = b["poids"]
		var n := bords.size()
		if n < 2:
			continue
		var couleur: Color = t["couleur"]
		var alpha := float(etat["alpha"])
		# Deux rubans de quadrilatères : du bord au milieu la couleur reste pleine
		# (à peine adoucie), du milieu à l'intérieur elle fond au transparent. Un
		# seul appel par liseré, des triangles explicites — un polygone à
		# triangulation automatique relierait des sommets lointains d'un ruban aussi
		# fin.
		var points := PackedVector2Array()
		var couleurs := PackedColorArray()
		var indices := PackedInt32Array()
		for i in n:
			var a_i := alpha * poids[i]
			points.append(bords[i])
			couleurs.append(Color(couleur, a_i))
			points.append(milieu[i])
			couleurs.append(Color(couleur, a_i * 0.8))
			points.append(dedans[i])
			couleurs.append(Color(couleur, 0.0))
		for i in n - 1:
			var a := 3 * i
			var s := a + 3
			indices.append_array([a, a + 1, s, a + 1, s + 1, s,
				a + 1, a + 2, s + 1, a + 2, s + 2, s + 1])
		RenderingServer.canvas_item_add_triangle_array(toile_rid, indices, points, couleurs)
