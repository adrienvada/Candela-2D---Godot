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
## ## Des traces qui LUISENT, puis s'éteignent (2026-09-11)
##
## ⚠️ **Elles ne se lisaient que sous une lumière jusqu'au 2026-09-11** : il
## fallait revenir, éclairer, et lire. Adrien trouvait le gadget « trop inutile ».
## Elles luisent désormais d'elles-mêmes, vert phosphore, dans le noir — pour les
## DEUX joueurs, sur sa décision : l'intrus voit ses pas et sait qu'il est repéré.
## Et elles s'éteignent en quelques secondes : c'est une mémoire courte, pas un
## relevé de la manche. La NAPPE, elle, reste éclairée par le décor : invisible dans
## le noir, on ne contourne pas une poudre qu'on ne voit pas.
##
## ⚠️ **Des pieds qui s'essuient.** En sortant de la nappe, un joueur emporte une
## charge de poudre : ses traces continuent trois ou quatre pas en pâlissant, puis
## s'arrêtent. Revenir dans la nappe recharge les pieds. Et la Sentinelle ne marque
## pas sa propre poudre : elle se trahirait dans le noir.
##
## Il ne dit pas QUI est passé, et n'a pas à le dire : la Sentinelle ne marque pas
## sa propre poudre, donc dans un duel toute trace est celle de l'intrus.
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

## La charge de poudre qu'un joueur emporte : combien de traces il pose encore en
## sortant de la nappe, en pâlissant. Six traces de 26 px font 156 px, soit trois
## pas et demi du jeu — les « trois quatre pas » d'Adrien.
##
## ⚠️ **Comptée en TRACES, jamais en secondes ni en distance cumulée.** Le client
## voit l'adversaire 100 ms en retard : une charge au temps donnerait deux pistes
## différentes, et une distance sommée intégrerait le bruit de l'interpolation. La
## règle de la corde de 26 px, elle, pose le même NOMBRE de traces des deux côtés ;
## leurs positions diffèrent de quelques pixels (chaque pair échantillonne le
## trajet à sa cadence), ce qui est sans conséquence : une trace ne décide de rien.
const CHARGE_MAX := 6

## La lueur d'une trace : sa couleur (un vert phosphore froid, distinct de
## l'halogène des torches et de l'ambre des braises), son éclat de départ, et le
## temps qu'elle met à s'éteindre.
const COULEUR_LUEUR := Color(0.55, 1.0, 0.72)
## ⚠️ Éclat modéré, et c'est une leçon payée deux fois : additive sur une poudre
## éclairée, une trace trop vive sature au blanc et ne se lit plus.
const LUEUR_MAX := 0.5
const DUREE_LUEUR := 8.0

## La profondeur ABSOLUE de la nappe peinte : celle du sol (`floor_layer`, −1 dans
## l'arène). À égalité, l'ordre de l'arbre tranche — le nœud des gadgets vient
## après l'arène —, donc la nappe passe au-dessus du sol, et sous les murs (0), le
## sang et les marques de pas (1). À 0, elle aurait recouvert le pied des murs.
const Z_NAPPE := -1

## L'assombrissement de l'image peinte, et c'est une MESURE (2026-09-10).
##
## Sous la torche, la poudre claire et les marques claires saturaient toutes deux à
## 230/255 : écart nul, les traces illisibles — contre un contraste de Weber de
## +2,0 pour les mêmes marques sur le sol nu. Adrien a tranché : assombrir la
## poudre. Mesuré par captures avant/après, faisceau en plein, à six niveaux :
## traces sur la poudre à 0,00 / 0,03 / 0,11 / 0,20 / 0,34 / 0,53 fois leur
## contraste sur le sol pour 1,00 / 0,70 / 0,55 / 0,45 / 0,35 / 0,25. Retenu :
## 0,25, le plus clair des niveaux où elles ressortent au moins moitié autant que
## sur le sol — critère posé AVANT la mesure. La poudre y vaut encore 109 de
## luminance, plus claire que le sol éclairé : elle se lit toujours comme de la
## poudre. ⚠️ L'éclaircir, c'est rendre les traces illisibles : remesurer d'abord.
const ASSOMBRISSEMENT := 0.25

var _marques: Array[Node2D] = []
## Dernier point marqué, par joueur. `INF` = pas encore entré dans la nappe.
var _dernier: Array[Vector2] = [Vector2.INF, Vector2.INF]
## La charge de poudre de chaque joueur — voir `CHARGE_MAX`.
var _charge: Array[int] = [0, 0]


func _init() -> void:
	rayon = RAYON
	# De la poudre répandue : une balle passe au-dessus, la lumière aussi — et elle
	# ne la disperse pas (Adrien, 2026-09-11 : un gadget diffus ne se tue pas).
	arrete_les_balles = false
	touche_par_les_balles = false
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
	#
	# ⚠️ **Mais le bac à sable compte, et c'est une correction du 2026-09-11.** Le
	# garde ne lisait que `round_active` — or l'ENTRAÎNEMENT lance la manche puis le
	# remet à faux (`sandbox_mode` vrai) : la poudre n'y a JAMAIS posé une trace,
	# depuis l'étape 17, là même où Adrien essaie les classes. Même règle que la pose
	# d'un gadget (`_do_spawn_gadget`) : en jeu, ou en bac à sable.
	if not gs.round_active and not gs.sandbox_mode:
		return
	for id in 2:
		# La Sentinelle ne marque pas sa propre poudre (Adrien, 2026-09-11).
		if id == poseur_id:
			continue
		var j: Node2D = gs.p1 if id == 0 else gs.p2
		if not is_instance_valid(j) or not j.visible or j.get("dead"):
			continue
		var pos := j.global_position
		if pos.distance_to(global_position) <= RAYON:
			# Dans la nappe : les pieds se chargent, et chaque trace luit pleinement.
			_charge[id] = CHARGE_MAX
			if _dernier[id] == Vector2.INF:
				_poser_marque(pos, j.global_transform.x)
				_dernier[id] = pos
			elif _dernier[id].distance_to(pos) >= PAS_ENTRE_MARQUES:
				_poser_marque(pos, (pos - _dernier[id]).normalized())
				_dernier[id] = pos
		elif _charge[id] > 0:
			# Hors de la nappe, des pieds encore poudrés : la même règle de la corde,
			# des traces qui pâlissent — jamais tout à fait nulles —, puis plus rien.
			if _dernier[id] == Vector2.INF:
				_dernier[id] = pos
			elif _dernier[id].distance_to(pos) >= PAS_ENTRE_MARQUES:
				_poser_marque(pos, (pos - _dernier[id]).normalized(),
					float(_charge[id]) / float(CHARGE_MAX + 1))
				_charge[id] -= 1
				_dernier[id] = pos if _charge[id] > 0 else Vector2.INF
		else:
			# Pieds propres : rentrer ailleurs doit marquer tout de suite, pas
			# attendre d'avoir « rattrapé » le pas.
			_dernier[id] = Vector2.INF


## Une trace : un petit trait qui luit, orienté dans le sens de la marche.
##
## ⚠️ **Enfant de l'ARÈNE, pas du gadget.** La piste doit survivre à la nappe : une
## nappe remplacée ou purgée n'efface pas ce qu'elle a déjà écrit — la trace
## s'éteint d'elle-même, par son fondu. (Tirer dessus ne la niait plus depuis que
## la poudre ne se tue plus à la balle, le 2026-09-11.) C'est la leçon que `bullet.gd`
## a écrite pour ses éclats — *« le parent d'une balle est le nœud des balles, qui
## ne survit pas à la manche »*.
func _poser_marque(pos: Vector2, sens: Vector2, intensite: float = 1.0) -> void:
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
	m.color = COULEUR_LUEUR
	# ⚠️ **Elle LUIT : non éclairée et additive**, depuis le 2026-09-11. Un
	# `light_mask` à zéro ne suffirait pas — le `CanvasModulate` de l'arène éteint
	# tout ce qui passe (voir `GadgetBase.materiau_incandescent()`). Additive, elle
	# vaut sa propre couleur dans le noir et s'AJOUTE à la poudre éclairée.
	m.material = GadgetBase.materiau_incandescent()
	m.modulate.a = LUEUR_MAX * clampf(intensite, 0.0, 1.0)
	m.z_index = 1
	# Reconnue par son GROUPE, jamais par son nom : Godot renomme les homonymes
	# en « @Polygon2D@N », et seule la première trace s'appelle « Trace ».
	m.add_to_group("traces_de_poudre")
	gs.arena.add_child(m)
	# ⚠️ **Le fondu appartient à la TRACE**, jamais au gadget : la nappe remplacée
	# ou purgée ne doit pas figer les traces à leur éclat du moment. Décroissance
	# rapide puis traînante, comme un phosphore. Et c'est aussi ce qui les empêche
	# de se reporter sur la manche suivante : l'arène ne se purge pas par manche.
	var fondu := m.create_tween()
	# DA4.13 — une lueur qui retombe à zéro : `EXTINCTION`, la courbe de ce qui
	# s'éteint. `test_charte` refuse les courbes de Godot (`TRANS_*`).
	Charte.animer(fondu, m, "modulate:a", m.modulate.a, 0.0, DUREE_LUEUR,
		Charte.Courbe.EXTINCTION)
	fondu.tween_callback(m.queue_free)

	# Les traces éteintes se sont libérées seules : on ne compte que les vivantes.
	_marques = _marques.filter(func(n): return is_instance_valid(n))
	_marques.append(m)
	if _marques.size() > MARQUES_MAX:
		var vieille: Node2D = _marques.pop_front()
		if is_instance_valid(vieille):
			vieille.queue_free()


## La nappe elle-même : son image, à sa taille — 220 px, deux fois `RAYON` —,
## éclairée comme le sol : dans le noir, elle n'existe pas. Adrien a préféré
## l'image au semis de grains le 2026-09-10, dans une version aux empreintes très
## légères peinte à sa demande.
##
## ⚠️ **Posée SOUS les marques de pas, et c'est une profondeur ABSOLUE.** Les
## empreintes peintes sont un décor ; les marques sont les vraies traces, celles
## qui disent que quelqu'un est passé. Si les premières couvraient les secondes, la
## poudre mentirait sur la seule chose qu'elle sait.
##
## Les marques vivent dans l'ARÈNE (profondeur 1, voir `_poser_marque`), la nappe
## dans le gadget, que le socle pose à 4 : une profondeur RELATIVE de 0 la mettait
## donc à 4, par-dessus toutes les traces. Vu à la capture — six marques posées sur
## la nappe, aucune visible — et un premier contrôle l'avait laissé passer en
## comparant deux profondeurs relatives à des parents différents.
func _monter_visuel() -> void:
	var nappe := _poser_sprite("Visuel", "poudre_contact")
	if nappe != null:
		nappe.z_as_relative = false
		nappe.z_index = Z_NAPPE
		nappe.modulate = Color(ASSOMBRISSEMENT, ASSOMBRISSEMENT, ASSOMBRISSEMENT)
