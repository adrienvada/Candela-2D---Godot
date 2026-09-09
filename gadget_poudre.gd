class_name GadgetPoudre
extends GadgetBase

## La poudre de contact — gadget de la Sentinelle, chantier CLASSES, étape 17.
##
## ## Un sol qui ÉCRIT
##
## *« Elle ne cherche pas : elle veille. Une poudre qui écrit les pas de qui
## passe. »* Une nappe de poudre claire répandue au sol. Qui la traverse y laisse
## une piste — et la piste **reste après lui**.
##
## ## Ce qui en fait le gadget de la Sentinelle, et pas un radar
##
## ⚠️ **Les traces ne sont visibles QUE sous une lumière.** Elles portent
## `light_mask = WALL_LAYER` comme le sol : dans le noir, elles n'existent pas. Il
## faut revenir, éclairer, et lire. C'est exactement le geste de la classe — on
## ne surveille pas en direct, on relève après coup — et c'est ce qui distingue ce
## gadget d'une alarme : il ne dit rien pendant qu'on passe, il dit tout quand on
## revient.
##
## Il ne dit pas non plus QUI est passé — seulement quelqu'un, et par où. Dans un
## duel, ça suffit : il n'y a que deux personnes, et l'une des deux sait ce
## qu'elle a fait.
##
## ## Les traces se posent CHEZ TOUS LES PAIRS, sans rien répliquer
##
## ⚠️ C'est possible pour une raison précise, et elle vaut d'être écrite : la
## marque se déclenche à la **DISTANCE parcourue**, jamais au temps. Le client
## voit l'adversaire interpolé, avec 100 ms de retard et un lissage — donc à des
## instants différents de l'hôte, mais **sur le même chemin**. Une marque tous les
## 26 px de trajet donne donc la même piste des deux côtés, aux quelques pixels
## de l'interpolation près. Une règle au temps aurait produit deux pistes
## différentes, et il aurait fallu répliquer chaque pas.
##
## C'est le patron des taches de sang : `bullet.gd` les pose localement chez
## chaque pair, depuis un événement déjà partagé.

## Le rayon de la nappe, en pixels.
const RAYON := 110.0

## La distance entre deux marques, en pixels de monde. **C'est elle qui rend la
## piste identique chez les deux pairs** — voir la note de tête.
const PAS_ENTRE_MARQUES := 26.0

## Combien de marques une nappe garde au plus. Au-delà, la plus ancienne s'efface.
##
## ⚠️ Un plafond, parce qu'un joueur qui ferait les cent pas dedans en poserait
## sans fin — et une nappe qui coûterait de plus en plus cher au fil de la manche
## serait un défaut de cadence que personne ne verrait venir.
const MARQUES_MAX := 72

var _marques: Array[Node2D] = []
## Dernier point marqué, par joueur. `INF` = pas encore entré dans la nappe.
var _dernier: Array[Vector2] = [Vector2.INF, Vector2.INF]


func _init() -> void:
	rayon = RAYON
	# De la poudre répandue : une balle passe au-dessus, la lumière aussi.
	arrete_les_balles = false
	pv = 2.0
	eblouit = false
	angle_pose = 0.0
	occulte_la_lumiere = false


## Pas d'occluder : de la poudre au sol ne porte pas d'ombre — et le socle en
## poserait un qui ferait d'elle un obstacle de lumière.
func _monter_occluder() -> void:
	pass


func _physics_process(delta: float) -> void:
	super(delta)
	if is_queued_for_deletion():
		return
	_relever_les_pas()


## Pose une marque quand un joueur a parcouru `PAS_ENTRE_MARQUES` dans la nappe.
##
## ⚠️ **Tourne chez TOUS les pairs**, contrairement aux dégâts des braises ou au
## déclenchement de la mine. Rien ici n'est de l'autorité : une trace ne blesse
## personne et ne décide de rien, elle informe. La faire arbitrer par l'hôte
## obligerait à répliquer chaque pas pour un résultat identique.
func _relever_les_pas() -> void:
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs == null or gs.arena == null:
		return
	# ⚠️ Pendant la killcam, la manche est finie et les fantômes rejouent le
	# passé : marquer là écrirait une piste que personne n'a parcourue.
	if not gs.round_active:
		return
	for id in 2:
		var j: Node2D = gs.p1 if id == 0 else gs.p2
		if not is_instance_valid(j) or not j.visible or j.get("dead"):
			continue
		var pos := j.global_position
		if pos.distance_to(global_position) > RAYON:
			# Sortir de la nappe efface la mémoire : rentrer ailleurs doit
			# remarquer tout de suite, pas attendre d'avoir « rattrapé » le pas.
			_dernier[id] = Vector2.INF
			continue
		if _dernier[id] == Vector2.INF:
			_poser_marque(pos, j.global_transform.x)
			_dernier[id] = pos
			continue
		if _dernier[id].distance_to(pos) >= PAS_ENTRE_MARQUES:
			_poser_marque(pos, (pos - _dernier[id]).normalized())
			_dernier[id] = pos


## Une trace : un petit trait clair, orienté dans le sens de la marche.
##
## ⚠️ **Enfant de l'ARÈNE, pas du gadget.** La piste doit survivre à la nappe :
## abattre la poudre ne doit pas effacer ce qu'elle a déjà écrit, sans quoi il
## suffirait de tirer dessus pour nier son passage. C'est la leçon que `bullet.gd`
## a écrite pour ses éclats — *« le parent d'une balle est le nœud des balles, qui
## ne survit pas à la manche »*.
func _poser_marque(pos: Vector2, sens: Vector2) -> void:
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs == null or gs.arena == null:
		return
	var m := Polygon2D.new()
	m.name = "Trace"
	m.polygon = PackedVector2Array([
		Vector2(-6.0, -1.6), Vector2(6.0, -1.0),
		Vector2(6.0, 1.0), Vector2(-6.0, 1.6)])
	m.global_position = pos
	m.rotation = sens.angle()
	m.color = Charte.HALOGENE
	# ⚠️ **Éclairée par le décor, donc INVISIBLE dans le noir.** C'est tout le
	# gadget : il faut revenir et éclairer pour lire. Une trace lumineuse par
	# elle-même en ferait une alarme, ce qui est le métier d'une autre classe.
	m.light_mask = MapGeometry.WALL_LAYER
	m.z_index = 1
	gs.arena.add_child(m)

	_marques.append(m)
	if _marques.size() > MARQUES_MAX:
		var vieille: Node2D = _marques.pop_front()
		if is_instance_valid(vieille):
			vieille.queue_free()


## La nappe elle-même : un semis de grains clairs, déterministe comme celui des
## braises — un tirage local donnerait deux nappes différentes chez les deux
## pairs, ce qui est la raison pour laquelle les particules sont exclues du
## modèle d'éblouissement.
func _monter_visuel() -> void:
	const NOMBRE := 26
	const ANGLE_OR := 2.39996323
	for i in NOMBRE:
		var t := float(i) / float(NOMBRE)
		var grain := Polygon2D.new()
		grain.name = "Grain%d" % i
		var cote := 1.4 + 1.4 * (1.0 - t)
		grain.polygon = PackedVector2Array([
			Vector2(-cote, -cote), Vector2(cote, -cote),
			Vector2(cote, cote), Vector2(-cote, cote)])
		grain.position = Vector2(cos(ANGLE_OR * i), sin(ANGLE_OR * i)) * RAYON * 0.92 * sqrt(t)
		grain.color = Charte.HALOGENE
		grain.light_mask = MapGeometry.WALL_LAYER
		grain.z_index = 2
		add_child(grain)
