class_name GadgetVolume
extends GadgetBase

## Le socle des VOLUMES — chantier CLASSES, étape 14.
##
## ## Ce qu'un volume fait, et ce qu'il ne fait pas
##
## Il **efface les sprites** qui sont dedans, et il pose une masse sombre sur le
## sol. Il n'arrête ni les balles, ni la lumière, ni l'éblouissement.
##
## ⚠️ **La suie fait exception depuis le 2026-09-11** (étape 27) : elle MASQUE le
## corps, sprite et ombre ; elle étouffe la lampe qu'on y tient, éblouissement
## compris ; et sa masse n'est plus éclairée point par point — elle s'allume en
## entier. Voir `GadgetSuie` et `_lumiere_entrante()`.
##
## ⚠️ **Ce n'est pas une simplification, c'est le mécanisme qui existe déjà.** La
## fumée de la fusée fait exactement cela depuis le chantier FUSÉE
## (`Fusee.occultation_pour`), et sa note dit pourquoi : *« dans la fumée, le
## sprite S'EFFACE : la masse sombre du voile porte seule la présence. La masse
## seule ne suffisait pas, le sprite restait lisible dessous »* — retour d'Adrien
## au premier essai. Un volume de gadget rejoint ce mécanisme au lieu d'en
## inventer un second.
##
## ## Pourquoi la lumière le TRAVERSE
##
## Un occluder 2D est binaire : il bloque ou il ne bloque pas. Un nuage qui
## bloquerait totalement serait un mur de plus — nous en avons déjà un, le voile
## du Spectre, et son intérêt tient précisément à ce qu'il est franc. Un nuage
## qui ne bloquerait rien du tout serait invisible à la mécanique. Ce que le
## moteur permet, entre les deux, c'est d'effacer ce qu'on VOIT dedans — et
## c'est exactement l'information que ces deux gadgets veulent retirer.
##
## ## Les deux volumes ne disent pas la même chose
##
## La suie du Fumiste est **dense et petite** : on n'y voit personne, et une
## lampe l'allume en entier (étape 27 — elle disait jusque-là « on voit qu'il y a
## quelqu'un, pas qui »). La poussière du Terrassier est **large et mince** : personne
## ne voit loin, mais tout le monde voit un peu. Ce sont les deux seules façons
## de retirer de la vue, et chaque classe en a une.

## L'opacité au cœur du volume, entre 0 et 1. Les sous-classes la posent.
var opacite: float = 0.7

var _masse: Sprite2D

## La lueur d'un volume qui masque le corps (la suie) : ce qu'il reçoit de lumière,
## lissé, et le pouls d'un tir parti de l'intérieur. Voir `_lumiere_entrante()`.
var _lueur := 0.0
var _pouls := 0.0
## ⚠️ Le nuage non éclairé montre son image telle que peinte, sombre : la lueur
## pleine la RELÈVE (au-delà de 1) pour qu'un nuage éclairé se lise comme éclairé.
const GAIN_LUEUR := 1.6
const LISSAGE_LUEUR := 10.0
const AMORTI_POULS := 5.0


func _init() -> void:
	# Rien n'arrête rien : ni les balles, ni la lumière. Voir la note de tête, et
	# `GadgetMine` qui a introduit le drapeau une étape plus tôt.
	arrete_les_balles = false
	occulte_la_lumiere = false
	eblouit = false
	# Un nuage ne se tue pas à la balle (Adrien, 2026-09-11) : elle ne le rencontre
	# même pas. Voir `GadgetBase.touche_par_les_balles`.
	touche_par_les_balles = false
	angle_pose = 0.0


## Pas d'occluder : un nuage ne porte pas d'ombre franche, et le socle en
## poserait un qui ferait de lui un obstacle de lumière.
func _monter_occluder() -> void:
	pass


## Combien ce volume efface, pour un point donné — 0 dehors, `opacite` au cœur.
##
## ⚠️ **La même courbe que `Fusee.occultation_pour()`**, délibérément : deux
## façons de s'effacer dans deux nuages différents se sentiraient comme un
## défaut, pas comme deux gadgets.
func occultation_pour(pos: Vector2) -> float:
	var courant := opacite * _fondu()
	if courant <= 0.0:
		return 0.0
	var d := pos.distance_to(global_position) / maxf(rayon, 1.0)
	if d >= 1.0:
		return 0.0
	return courant * (1.0 - smoothstep(0.55, 1.0, d))


## Le volume monte puis retombe : il ne naît pas à pleine densité et ne
## disparaît pas d'un coup. Sans ça, l'apparition se lirait comme un défaut de
## rendu — c'est la même raison qui fait rampe le retour du root.
func _fondu() -> float:
	if duree_vie <= 0.0:
		return 1.0
	var t := clampf(age() / duree_vie, 0.0, 1.0)
	const MONTEE := 0.12
	if t < MONTEE:
		return t / MONTEE
	return 1.0 - smoothstep(0.7, 1.0, t)


func _physics_process(delta: float) -> void:
	super(delta)
	if _masse == null or is_queued_for_deletion():
		return
	if not masque_le_corps():
		_masse.modulate.a = _fondu()
		return
	# La suie s'allume EN ENTIER selon ce qu'elle reçoit — jamais point par point.
	_lueur = lerpf(_lueur, _lumiere_entrante(), 1.0 - exp(-LISSAGE_LUEUR * delta))
	_pouls *= exp(-AMORTI_POULS * delta)
	var k := clampf(maxf(_lueur, _pouls), 0.0, 1.0) * GAIN_LUEUR
	_masse.modulate = Color(k, k, k, _fondu())


## La masse : l'image du nuage, posée sur le sol. C'est elle qui PORTE la présence
## du nuage, puisque les sprites qui s'y trouvent, eux, s'effacent.
func _monter_visuel() -> void:
	# ⚠️ Éclairée par le décor, contrairement aux braises : un nuage ne s'allume
	# pas tout seul, et une masse qui brillerait dans le noir absolu trahirait sa
	# position à qui n'a pas de torche. `_poser_sprite()` l'éclaire ainsi. Sauf la
	# suie, depuis l'étape 27 : voir juste en dessous.
	_masse = _poser_sprite("Visuel", piece_sprite())
	if _masse != null:
		_masse.z_index = 5
		if masque_le_corps():
			# ⚠️ La suie ne reçoit plus les lumières pixel par pixel : le cône, son
			# sommet et les ombres ne s'y dessinent plus, et elle cache le cône au sol.
			# Non éclairée, en MÉLANGE (un `light_mask` à zéro la laisserait noire sous
			# le `CanvasModulate`) ; sa clarté est un seul nombre, `_lueur`.
			_masse.material = GadgetBase.materiau_peint_lumineux()
			_masse.modulate = Color(0.0, 0.0, 0.0, 0.0)


## L'image de la masse — le nom de sa pièce, voir `GadgetProfile.chemin_sprite_de()`.
## Vide dans le socle des volumes : chaque nuage a la sienne, et un volume sans
## image CRIE au lieu de se rabattre sur un disque de secours.
func piece_sprite() -> String:
	return ""


## Un tir parti de l'intérieur : la suie pulse en entier, comme la fumée de fusée
## (FU3) — pour que l'éclat du canon ne dise pas où l'on est.
func diffuser_flash() -> void:
	if masque_le_corps():
		_pouls = 1.0


## Ce que le nuage reçoit de lumière, entre 0 et 1 : le plus fort de ce que verse
## chaque lampe allumée sur quelques points du disque (à mur près), et des fusées
## au sol, à leur feu. Une lampe allumée DANS le nuage l'allume en entier.
##
## ⚠️ **Les lampes, ce sont les torches des joueurs ET les fausses torches posées**
## (trouvé en revue, 2026-09-11). Une fausse torche que la suie ignorait se
## distinguait de la vraie : l'une allumait le nuage, l'autre y dessinait un disque
## noir. Même échantillonnage pour les deux — l'arme de la classe, lue depuis la
## position et l'axe de la lampe —, celui de l'éblouissement.
##
## ⚠️ **Local et purement visuel** : calculé chez chaque pair depuis un état déjà
## répliqué (positions, torches, fusées, gadgets). Aucune simulation ne le lit, et
## la lueur n'entre PAS dans les sources d'éblouissement — un réflecteur n'est pas
## une lampe.
func _lumiere_entrante() -> float:
	var gs := get_tree().get_first_node_in_group("game_state") if is_inside_tree() else null
	if gs == null:
		return 0.0
	var espace := get_world_2d().direct_space_state
	# [arme, axe, origine] de chaque lampe allumée.
	var lampes := []
	for j in [gs.p1, gs.p2]:
		if gs._en_jeu(j) and j.flashlight_on and j.current_weapon != null:
			lampes.append([j.current_weapon, j.global_transform.x, j.global_position])
	for g in get_tree().get_nodes_in_group("gadgets"):
		if is_instance_valid(g) and g.eblouissement_dirige and g.classe_du_poseur != null:
			lampes.append([g.classe_du_poseur, g.global_transform.x, g.global_position])
	var k := 0.0
	# ⚠️ **« À mur près », et les murs seulement.** Les joueurs sont sur la couche 1,
	# celle des murs — le défaut de Godot : ni `player.tscn` ni `player.gd` ne la
	# changent (`game_state` n'en retire J2 que lorsqu'il n'est pas en jeu). Sans
	# cette exclusion, un corps entre la lampe et le nuage (ou le
	# Fumiste DANS son nuage) éteignait les points qu'il masquait : une lampe
	# braquée sur le nuage à travers J1 rendait 0 au test (2026-09-11).
	var corps: Array[RID] = []
	for j in [gs.p1, gs.p2]:
		if is_instance_valid(j):
			corps.append(j.get_rid())
	for lampe in lampes:
		var origine: Vector2 = lampe[2]
		if occultation_pour(origine) > 0.3:
			# Tenue DANS le nuage : elle l'allume en entier — à ce que les AUTRES
			# gadgets lui laissent. Une lampe que le grésillement éteint n'allume
			# rien (trouvé en revue) ; celle que la suie étouffe, si : c'est en elle
			# qu'elle brûle.
			k = maxf(k, _lampe_hors_suie(origine))
			continue
		var arme: WeaponData = lampe[0]
		var avant: Vector2 = lampe[1]
		var facteur: float = gs.facteur_de_lampe_a(origine)
		for p in _points_de_lueur():
			var l: float = arme.lumiere_recue(avant, origine, p) * facteur
			if l <= k:
				continue
			var q := PhysicsRayQueryParameters2D.create(origine, p, MapGeometry.WALL_LAYER)
			q.exclude = corps
			if espace.intersect_ray(q).is_empty():
				k = l
	for f in get_tree().get_nodes_in_group("fusees"):
		if not is_instance_valid(f):
			continue
		var portee := rayon + 160.0
		var d: float = f.global_position.distance_to(global_position)
		if d < portee:
			k = maxf(k, f.energie_relative() * (1.0 - d / portee))
	return clampf(k * 1.5, 0.0, 1.0)


## Le facteur de lampe à `pos` sans les gadgets qui masquent le corps : ce que les
## bobines laissent à une lampe tenue dans la suie.
func _lampe_hors_suie(pos: Vector2) -> float:
	var f := 1.0
	for g in get_tree().get_nodes_in_group("gadgets"):
		if is_instance_valid(g) and not g.masque_le_corps():
			f = minf(f, g.facteur_de_lampe(pos))
	return f


## Le centre du disque et six points à mi-rayon : assez pour qu'un faisceau qui ne
## fait que frôler le nuage l'allume, sans échantillonner toute l'image.
func _points_de_lueur() -> Array:
	var pts := [global_position]
	for i in 6:
		pts.append(global_position + Vector2.RIGHT.rotated(TAU * i / 6.0) * rayon * 0.55)
	return pts
