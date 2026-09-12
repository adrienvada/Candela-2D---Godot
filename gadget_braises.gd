class_name GadgetBraises
extends GadgetBase

## La nappe de braises — gadget de l'Incendiaire, chantier CLASSES, étape 13.
##
## ## Ce qu'elle est : un sol qu'on ne traverse plus
##
## Une flaque de charbons répandus, qui éclaire faiblement et **brûle qui reste
## dessus**. C'est le seul gadget du chantier qui fasse des dégâts, et la
## différence avec la mine est de nature : la mine punit un instant — on l'a
## déclenchée, c'est fini —, la nappe punit une DURÉE. Elle ne tue personne qui
## la traverse ; elle interdit d'y rester, ce qui n'est pas la même chose et vaut
## bien plus cher dans un couloir.
##
## ## Elle ne bloque ni les balles ni la lumière, et les deux sont vrais
##
## Des charbons répandus au sol, vus de dessus, n'arrêtent rien : une balle
## passe au-dessus, un faisceau aussi. D'où `arrete_les_balles = false` **et**
## `occulte_la_lumiere = false` — le second réglage tenant
## `game_state._ligne_de_vue_depuis()` d'accord avec le premier. La mine a payé
## cette leçon une étape plus tôt : une chose qui n'assombrit pas ne doit pas
## arrêter l'aveuglement.
##
## ⚠️ **Pas d'occluder non plus, et c'est ce qui répare sa propre lueur.** Le
## socle en monte un pour tout gadget ; sa lumière se serait retrouvée à
## l'intérieur, « ni ombre ni lumière mais du hasard ».
##
## ## Elle reste destructible, comme tous les autres
##
## Le contrat du socle est que **toute chose posée puisse être abattue** : c'est
## ce qui donne une réponse à « j'ai vu quelque chose ». Une balle disperse assez
## de charbons pour ouvrir un passage — trois balles l'éteignent.

## Le rayon de la nappe, en pixels. Il sert à trois choses à la fois, et c'est
## voulu : la forme de collision, le dessin, et la zone qui brûle. Trois valeurs
## qui devraient être égales finiraient par ne plus l'être.
const RAYON := 68.0

## Ce que coûte une seconde passée dedans, en points de vie.
##
## ⚠️ **Calibré pour interdire, pas pour tuer.** Traverser la nappe en courant
## coûte environ un quart de seconde, soit quatre points : négligeable, et c'est
## le but — l'Incendiaire ne gagne pas parce qu'on a marché dessus. Y rester
## deux secondes en coûte trente-deux, ce qui n'est plus négligeable du tout.
const DEGATS_PAR_SECONDE := 16.0

## Jusqu'où les braises aveuglent, en pixels.
##
## Petit, et bien plus petit que la fusée (400) ou la mine (460) : c'est une
## lueur au sol, pas une source. Elle gêne qui la surplombe, elle n'aveugle
## personne à l'autre bout de la salle.
const RAYON_EBLOUISSEMENT := 200.0

const ENERGIE := 1.8

var _lumiere: PointLight2D
var _nappe: Sprite2D = null


func _init() -> void:
	rayon = RAYON
	# Une balle passe au-dessus des charbons. Elle en disperse quand même assez
	# pour compter — voir les points de vie.
	arrete_les_balles = false
	pv = 3.0
	eblouit = true
	eblouissement_dirige = false
	rayon_eblouissement = RAYON_EBLOUISSEMENT
	# Une nappe répandue au sol n'a pas d'orientation qui compte.
	angle_pose = 0.0
	# Elle n'assombrit rien : voir la note de tête, et `GadgetMine` qui a payé la
	# même leçon une étape plus tôt.
	occulte_la_lumiere = false


## Pas d'occluder : des charbons au sol ne portent pas d'ombre, et un occluder
## enfermerait la lueur dans elle-même.
func _monter_occluder() -> void:
	pass


func _ready() -> void:
	super()
	_monter_lueur()


## Les dégâts. **Hôte seul** — `GameState._maj_gadgets()` ne l'appelle pas
## ailleurs, et `take_damage()` refait le partage de son côté.
##
## ⚠️ **Elle ne connaît pas son poseur, et brûle donc tout le monde.** C'est la
## règle des choses posées, déjà écrite pour la fusée et la mine : *« on ne la
## pose pas à ses pieds impunément »*. Un feu qui épargnerait celui qui l'a
## allumé serait la seule chose du jeu à savoir qui est qui.
func appliquer_effets(joueurs: Array, delta: float) -> void:
	if is_queued_for_deletion():
		return
	for j in joueurs:
		if not is_instance_valid(j) or not (j is Node2D):
			continue
		if j.get("dead") or not j.visible:
			continue
		if j.global_position.distance_to(global_position) > RAYON:
			continue
		# `source_player` reste le poseur : c'est lui que le tableau de fin doit
		# créditer, et lui que la killcam doit nommer.
		j.take_damage(DEGATS_PAR_SECONDE * delta, _poseur())
	# La lueur baisse avec la nappe, et l'éblouissement avec elle. Une lumière
	# qui s'éteindrait d'un coup se lirait comme une coupure de rendu.
	if duree_vie > 0.0:
		var reste := clampf(1.0 - age() / duree_vie, 0.0, 1.0)
		if _lumiere != null:
			_lumiere.energy = ENERGIE * (0.35 + 0.65 * reste)
		rayon_eblouissement = RAYON_EBLOUISSEMENT * (0.35 + 0.65 * reste)
		if _nappe != null:
			_nappe.modulate.a = 0.35 + 0.65 * reste


## Le joueur qui l'a posée, ou `null`. Lu à la demande plutôt que retenu : le
## nœud du joueur peut disparaître d'une manche à l'autre.
func _poseur() -> Node2D:
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs == null or poseur_id < 0:
		return null
	return gs.p1 if poseur_id == 0 else gs.p2


func _monter_lueur() -> void:
	_lumiere = PointLight2D.new()
	_lumiere.name = "Lueur"
	LightTextures.poser(_lumiere, LightTextures.RETRODIFFUSION, RAYON * 5.0)
	# L'ambre du dépôt, la couleur du feu qui couve. Pas de rouge franc : la
	# charte ne le porte que pour l'état de faute, et une nappe au sol n'est pas
	# une alarme.
	_lumiere.color = Charte.AMBRE
	_lumiere.energy = ENERGIE
	_lumiere.shadow_enabled = true
	_lumiere.shadow_item_cull_mask = 1
	_lumiere.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	_lumiere.range_item_cull_mask = 1 | 2 | 4
	add_child(_lumiere)


## La nappe : son image, peinte lumineuse, qui remplace les quinze charbons
## dessinés (2026-09-10). La même image chez les deux pairs : le déterminisme que
## la spirale d'or garantissait est acquis par construction.
##
## Refonte roman graphique, lot 6 (2026-09-11) : la lueur au centre de la planche
## était un dégradé radial aérographe ; sa luminance est ramenée à QUATRE paliers
## (pierre, braise sombre, braise, cœur), teinte conservée. Source intacte dans
## `assets/sources/encre/gadget_nappe_braises_source.png`. La poudre de contact,
## elle, est déjà une trame de points : intacte.
func _monter_visuel() -> void:
	_nappe = _poser_sprite("Visuel", "nappe_braises")
	if _nappe == null:
		return
	# ⚠️ **Non éclairée par le décor, mais PAS additive.** Un `light_mask` à zéro
	# ne suffit pas : le `CanvasModulate` de l'arène éteint tout ce qui passe, et
	# les charbons dessinés sortaient NOIRS (voir `materiau_incandescent()`). Mais
	# l'image porte déjà sa lueur : additionnée à la lumière de la nappe, elle
	# virait à la boule blanche. Voir `GadgetBase.materiau_peint_lumineux()`.
	_nappe.material = GadgetBase.materiau_peint_lumineux()
	_nappe.z_index = 3
