extends Node2D
class_name Bullet

const Charte := preload("res://charte.gd")

var weapon: WeaponData
var bounces_left: int = 0
var is_replay: bool = false
## Cette balle est-elle le tir fatal du rejeu ?
##
## ⚠️ **Seule elle laisse sa traînée pointillée en killcam.** Une killcam rejoue
## TOUT ce qui a été tiré dans sa fenêtre : les tirs manqués laissaient chacun
## leur trait, et l'écran montrait plusieurs lignes presque parallèles dont une
## seule était la bonne. Relevé par Adrien à l'écran le 2026-08-27 — *« la balle
## ne suit pas la trajectoire tracée par les pointillés »* : elle la suivait,
## mais ce n'était pas SA trajectoire qu'on lui comparait.
##
## **Deux traits qui se ressemblent sont pires qu'un seul faux** : on ne se
## demande pas lequel lire, on croit lire le bon.
var est_le_tir_fatal: bool = false

var source_player: Node2D
var direction: Vector2 = Vector2.ZERO
var distance_traveled: float = 0.0
var radius: float = 4.0

# Compensation de latence : quand `lag_target` est renseigné (tirs du client,
# arbitrés par l'hôte), ce joueur est testé contre `lag_center` — la position
# que le tireur voyait — et retiré du ShapeCast, qui ne connaît que le présent.
const PLAYER_BODY_RADIUS := 18.0

## Combien de gadgets traversants une balle peut percer dans le MÊME pas de
## physique. Deux suffisent : au-delà, on rend la main plutôt que de dérouler une
## boucle dont personne n'a mesuré le pire cas.
const TRAVERSES_MAX := 2
var _traverses: int = 0
var lag_target: Player
var lag_center: Vector2 = Vector2.ZERO

var shape_cast: ShapeCast2D
var light: PointLight2D
var spawn_pos: Vector2

# FU3 — le tunnel que cette balle creuse dans une fumée de fusée, s'il y en a
# une sur son chemin. Purement local et éphémère : jamais répliqué (dérivé
# d'un tir déjà arbitré ailleurs), jamais en killcam (`is_replay` le tait).
var _fumee_traversee: Fusee = null
var _fumee_entree: Vector2 = Vector2.ZERO

# Matériau additif non éclairé, identique pour toutes les balles.
static var _shared_additive: CanvasItemMaterial

static func _additive_material() -> CanvasItemMaterial:
	if _shared_additive == null:
		_shared_additive = CanvasItemMaterial.new()
		_shared_additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_shared_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _shared_additive

func _ready():
	z_index = 10
	# Add a dynamic point light to the bullet itself
	light = PointLight2D.new()
	light.name = "TrailLight"
	light.color = Charte.AMBRE
	light.energy = 50.0
	# DA2.12 — le halo peint de la traînée. Texture partagée et mise en cache :
	# chaque balle en allouait une identique de 128×128, soit cinq par volée de
	# pompe. `poser()` tient l'empreinte au sol quelle que soit la résolution du
	# fichier — recuire en 256² ne devra rien déplacer.
	LightTextures.poser(light, LightTextures.TRAINEE, LightTextures.EMPREINTE_TRAINEE)
	var grad_tex := light.texture
	light.shadow_enabled = true
	light.shadow_item_cull_mask = 1 | 4 # Casts shadows from walls(1) and players(4)
	light.range_item_cull_mask = 1 | 2 | 4 # Trail light illuminates players (2)
	add_child(light)
	
	var core = Line2D.new()
	core.name = "Core"
	core.width = 5.0
	# Métal en fusion : la teinte du feu, poussée hors du cube [0, 1] par le
	# matériau additif — voir `Charte.AMBRE_INCANDESCENT`.
	core.default_color = Color(Charte.AMBRE_INCANDESCENT, 1.0)
	# DA2.12 — la traçante cesse d'être un trait plein.
	#
	# ⚠️ **Le sens de la texture n'est pas anodin.** Les points vont de
	# `Vector2.ZERO` — la balle — vers `Vector2(-longueur, 0)`, la queue. En mode
	# étiré, le bord GAUCHE de la texture tombe donc sur la balle. La planche a
	# été cuite retournée (`--miroir oui`) pour que le dense soit sur le
	# projectile et l'extinction derrière : une traînée s'éteint dans son sillage,
	# elle ne s'y allume pas.
	var trace := LightTextures.masque("res://assets/decals/tracante.png")
	if trace != null:
		core.texture = trace
		core.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	var mat := _additive_material()
	core.material = mat
	add_child(core)
	
	# Add a glowing aura Sprite2D so the glow is visible even over the darkened killcam overlay
	var aura = Sprite2D.new()
	aura.name = "Aura"
	aura.texture = grad_tex # Reuse the gradient texture from the light
	aura.modulate = Color(Charte.AMBRE, 0.6) # Même teinte que la balle, atténuée
	aura.material = mat # Reuse the unshaded, additive material (mat is already BLEND_MODE_ADD)
	aura.scale = Vector2(1.5, 1.5) # Reduced scale to make it less thick
	add_child(aura)
	
	if weapon:
		bounces_left = weapon.max_bounces
		
		# Apply custom visual parameters
		core.default_color = weapon.bullet_color
		core.width = weapon.bullet_width
		
		if not weapon.emits_light:
			light.enabled = false
			aura.visible = false
			core.material = null # Use default shaded material
		else:
			light.energy = weapon.bullet_light_energy
	
	# ShapeCast for accurate collision
	shape_cast = ShapeCast2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	shape_cast.shape = circle
	shape_cast.target_position = Vector2.ZERO
	shape_cast.max_results = 1
	# ⚠️ **Le masque était laissé au défaut (la seule couche 1) et il est
	# désormais EXPLICITE.** Les gadgets posés vivent sur leur propre couche,
	# hors du masque des joueurs, précisément pour que ceux-ci les traversent.
	# Sans cette ligne une balle passerait au travers d'une mine sans la voir.
	shape_cast.collision_mask = MapGeometry.BULLET_MASK
	add_child(shape_cast)
	if source_player:
		shape_cast.add_exception(source_player)
	if lag_target:
		shape_cast.add_exception(lag_target)

	set_as_top_level(true)
	spawn_pos = global_position

	# V6.2 — le tracé killcam se dessine sur le nœud racine : matériau additif
	# non éclairé, sinon le CanvasModulate noir l'avale. Les enfants ont leurs
	# propres matériaux, celui-ci ne s'applique qu'au _draw() de la racine.
	if is_replay:
		material = _additive_material()

func _physics_process(delta):
	if not weapon:
		queue_free()
		return
		
	var step = direction * weapon.bullet_speed * delta
	var travel_step = step.length()
	
	distance_traveled += travel_step
	if distance_traveled >= weapon.bullet_max_distance:
		_fade_and_destroy(global_position)
		return
		
	# Update shape cast for this frame's movement. target_position is in local space!
	shape_cast.target_position = Vector2(travel_step, 0)
	shape_cast.force_shapecast_update()

	# Cible compensée : test manuel segment/cercle, le ShapeCast ne la voit plus.
	# Un mur touché plus tôt sur le pas l'emporte toujours.
	if lag_target and is_instance_valid(lag_target) and (lag_target.hp > 0 or is_replay):
		var lag_dist := _circle_entry_distance(global_position, direction, travel_step,
			lag_center, PLAYER_BODY_RADIUS + radius)
		if lag_dist >= 0.0:
			# ⚠️ **Renommé de `wall_first` le 2026-09-09, et ce n'est pas
			# cosmétique.** Depuis que le masque contient les gadgets, le premier
			# collider rendu n'est plus forcément un mur : un gadget posé devant
			# un joueur compensé absorbe le tir. Le nom disait « mur » et
			# décidait « obstacle » — un identifiant qui ment sur ce qu'il teste
			# est ce qui rend un défaut indébogable.
			var obstacle_avant := shape_cast.is_colliding() \
				and global_position.distance_to(shape_cast.get_collision_point(0)) < lag_dist
			if not obstacle_avant:
				_hit_player(lag_target, lag_center, global_position + direction * lag_dist)
				return

	if shape_cast.is_colliding():
		var collider = shape_cast.get_collider(0)
		var hit_point = shape_cast.get_collision_point(0)

		if collider is Player and (collider.hp > 0 or is_replay):
			_hit_player(collider, collider.global_position, hit_point)
			return
		elif collider is TrainingTarget:
			_hit_training_target(collider, hit_point)
			return
		elif collider is GadgetBase:
			# ⚠️ **Deux comportements, et la distinction est de conception.** Un
			# objet dur — mine, projecteur — arrête la balle. Une bâche tendue
			# l'encaisse et la laisse passer : c'est ce qui fait du voile « un mur
			# qui n'en est pas un » plutôt qu'un mur.
			var gadget: GadgetBase = collider
			# ⚠️ **Le client n'encaisse plus rien, depuis le 2026-09-10.** Il simulait
			# ses propres balles et détruisait donc ses gadgets de son côté, à des
			# instants que la prédiction décalait. Chez lui la balle s'arrête
			# toujours sur un objet dur, sans le blesser : c'est l'ordre
			# `rpc_detruire_gadget` de l'hôte qui le retire.
			if not is_replay and NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_CLIENT:
				gadget.encaisser(weapon.damage_center)
			if gadget.arrete_les_balles:
				_spawn_wall_effects(hit_point, true)
				_fade_and_destroy(hit_point)
				return
			# La toile bat au passage — chez TOUS les pairs, puisque chacun voit
			# passer ses balles : c'est de l'image, jamais de la simulation.
			gadget.secouer()
			# Traversant : on l'exclut et on rejoue le pas. La boucle est BORNÉE —
			# un gadget qui se réinsérerait dans le cast ferait autrement tourner
			# cette image à l'infini, et une image qui ne rend pas la main est
			# pire qu'une balle qui s'arrête.
			shape_cast.add_exception(gadget)
			shape_cast.force_shapecast_update()
			_traverses += 1
			if _traverses < TRAVERSES_MAX and shape_cast.is_colliding():
				collider = shape_cast.get_collider(0)
				hit_point = shape_cast.get_collision_point(0)
			else:
				return
		if collider is Player and (collider.hp > 0 or is_replay):
			_hit_player(collider, collider.global_position, hit_point)
			return
		elif collider is TrainingTarget:
			_hit_training_target(collider, hit_point)
			return
		elif collider is GadgetBase:
			# Second gadget traversé dans le même pas : on s'arrête là plutôt que
			# de dérouler une récursion. Le cas est rare et le coût d'y insister
			# n'est pas justifié.
			return
		else:
			# V4.3 — **le mur ne sonne pas quand la balle va REPARTIR.** Les
			# etincelles et l'eclat restent : ce qui se voit est le meme choc,
			# c'est ce qui s'ENTEND qui doit trancher. Le drapeau existait deja
			# pour la cible d'echauffement, qui gardait les etincelles du mur
			# sans en prendre le bruit — meme geste, meme raison.
			_spawn_wall_effects(hit_point, bounces_left <= 0)
			
			if bounces_left > 0:
				# V4.3 — **le rebond REMPLACE l'impact, il ne s'y ajoute pas.**
				# Decision d'Adrien, 2026-08-28 : « on peut distinguer le rebond
				# de l'impact au son ».
				#
				# ⚠️ **La superposition, essayee d'abord, mourait avec la
				# distance.** Empiles, les deux evenements ne different que par
				# la PRESENCE d'une couche de plus ; or cette couche s'attenue
				# et s'occulte comme le reste, si bien qu'au loin — ou dans une
				# autre piece — un rebond et une balle finie redeviennent
				# identiques. C'est-a-dire que la distinction disparaissait
				# exactement la ou elle sert : loin, dans le noir, quand on ne
				# voit pas la balle. Remplaces, les deux sons ont chacun leur
				# niveau et leur portee, et restent distincts jusqu'au bout.
				#
				# Ce que ca dit au joueur : le fusil est la seule arme qui
				# rebondit, et **sa balle peut tuer son propre tireur**. « Elle
				# vit encore » est donc une information sur laquelle on agit
				# dans la seconde, parfois contre soi-meme.
				AudioManager.play_ricochet(hit_point)
				bounces_left -= 1
				var normal = shape_cast.get_collision_normal(0)
				direction = direction.bounce(normal)
				rotation = direction.angle()
				global_position = hit_point + normal * (radius + 2.0)
				spawn_pos = global_position # Reset trail origin

				# FU3 — un rebond casse le tunnel en cours au point d'impact et en
				# rouvre un neuf si l'angle rebondi reste dans la même fumée : sinon
				# un tunnel kinké se dessinerait comme UN trait droit à travers le
				# coin, au lieu de suivre le trajet réellement plié.
				_rompre_tunnel(hit_point)

				# Allow damaging the shooter after a bounce
				if weapon.damages_shooter:
					shape_cast.clear_exceptions()
					# La cible compensée reste testée à la main, rebond compris.
					if lag_target:
						shape_cast.add_exception(lag_target)
					
				return
			else:
				_fade_and_destroy(hit_point)
				return
		
	# FU5 — une balle éteint une fusée POSÉE (pas en vol) qu'elle croise. Testé
	# ICI, après tous les tests d'impact ci-dessus (mur, joueur direct, joueur
	# compensé) : une fusée est un objet secondaire, jamais prioritaire sur le
	# combat. Elle consomme la balle, comme un mur.
	if not is_replay:
		var f := _fusee_touchee_ce_pas(travel_step)
		if f != null:
			var point := global_position + direction * maxf(0.0, travel_step)
			var gs := get_tree().get_first_node_in_group("game_state")
			if gs and gs.has_method("demander_extinction_fusee"):
				gs.demander_extinction_fusee(f.graine)
			_maj_tunnel(point) # ferme le tunnel en cours, s'il y en avait un
			_spawn_wall_effects(point, true)
			_fade_and_destroy(point)
			return

	# V4.10 — le frolement se guette APRES les tests d'impact : un carreau qui
	# touche ne frole pas, et les branches ci-dessus rendent la main avant
	# d'arriver ici.
	_guetter_le_frolement(travel_step)

	global_position += step

	# FU3 — appartenance à une fumée réévaluée APRÈS le mouvement : c'est la
	# position d'arrivée du pas qui décide si un tunnel s'ouvre ou se referme.
	_maj_tunnel(global_position)

	if is_replay:
		queue_redraw()

	# Stretch the light and core to form a long laser trail
	var dist_from_spawn = global_position.distance_to(spawn_pos)
	var trail_length = min(dist_from_spawn, 800.0)
	light.rotation = 0.0
	light.scale = Vector2(max(1.0, trail_length / 128.0), 0.15)
	light.position = -Vector2(trail_length / 2.0, 0)
	
	if has_node("Core"):
		get_node("Core").points = PackedVector2Array([Vector2.ZERO, Vector2(-trail_length, 0)])

## V6.2 — Trajectoire au trait (killcam) : pendant le rejeu, la balle laisse
## derrière elle, en pointillé, le segment déjà parcouru. Le tracé est en espace
## local (-X = derrière, la rotation suit `direction`) et repart de zéro à chaque
## rebond, puisque `spawn_pos` est réarmé — fidèle au trajet.
## En manche réelle (`is_replay` faux) : rien, aucune information gratuite.
##
## ⚠️ **Le relevé coté de DA4.6 n'est PAS ici, et il ne peut pas y être.** Il se
## trace AVANT que l'action reprenne, comme l'analyse d'une action de football —
## or **une balle ne sait pas où elle va**. Elle connaît son départ et sa
## direction, jamais son impact : seul le rejeu le sait. Le relevé vit donc dans
## `releve_balistique.gd`, un objet qui existe avant la balle et reste après elle.
##
## Ce qui suit est la traînée qui SUIT — celle qui constate. Elle n'a jamais
## prétendu annoncer quoi que ce soit, et c'est pour ça qu'elle reste sur toutes
## les balles rejouées, pas seulement sur le tir fatal.
const TRACE_COLOR := Color(Charte.HALOGENE, 0.35)

func _draw() -> void:
	if not is_replay or not est_le_tir_fatal:
		return
	var back := global_position.distance_to(spawn_pos)
	if back < 8.0:
		return
	draw_dashed_line(Vector2(-back, 0.0), Vector2.ZERO, TRACE_COLOR, 2.0, 12.0)

## Impact joueur. `center` est le point de référence pour l'atténuation : la
## position réelle du joueur, ou celle remontée dans le temps quand le tir est
## compensé.
func _hit_player(target: Player, center: Vector2, hit_point: Vector2) -> void:
	# Damage falloff based on the perpendicular distance from the bullet's path to the player's center
	var player_radius := 15.0 # 15.0 * 1.0 (scale)
	var to_player := center - global_position
	var dist_to_axis: float = abs(to_player.cross(direction))
	var normalized_dist := clampf(dist_to_axis / player_radius, 0.0, 1.0)

	# Linear falloff based on weapon damage
	var opp_hit_damage := floorf(lerpf(weapon.damage_center, weapon.damage_edge, normalized_dist))

	# Kill probable, jugé sur les HP visibles localement : exact chez l'hôte,
	# prédictif chez le client — purement cosmétique dans les deux cas.
	var lethal := not is_replay and (target.hp - opp_hit_damage) <= 0.0
	if not is_replay:
		# V2.9 — distance à l'axe du DERNIER impact simulé ici : c'est celui
		# qui tue dans le cas courant, et chaque nouvel impact écrase le
		# précédent — un kill prédit puis démenti par l'hôte ne peut pas
		# laisser traîner une valeur périmée (constat de revue).
		target.last_fatal_perp = dist_to_axis
	if lethal:
		_flare_trail()

	if not is_replay:
		target.take_damage(opp_hit_damage, source_player)

	_spawn_hit_effects(hit_point, normalized_dist, dist_to_axis)
	if not is_replay:
		_spawn_damage_number(hit_point, int(opp_hit_damage))
	_fade_and_destroy(hit_point)

## Impact sur la cible d'échauffement : effets visuels d'un mur, chiffre de
## dégâts calculé comme sur un joueur, et **son de coup au but**.
##
## ⚠️ **Le son ne dit plus « mur », il dit « touché » — corrigé le 2026-08-25 sur
## demande d'Adrien.** La cible partageait tous les effets du mur, son compris :
## à l'oreille, **atteindre la cible et rater à côté produisaient exactement le
## même bruit.** Dans le seul mode dont le sujet est de viser, c'était effacer
## la seule information qui compte.
##
## `flesh_impact` et non un échantillon neuf : la cible **tient lieu de corps**
## — ses dégâts sont déjà calculés comme sur un joueur, centre et bord compris.
## Lui donner le son du corps rend l'entraînement cohérent avec le match, où
## c'est ce claquement-là qui confirme un coup au but. Aucun asset à commander,
## et rien à recâbler le jour où la cible aura sa matière propre.
func _hit_training_target(target: TrainingTarget, hit_point: Vector2) -> void:
	var to_target := target.global_position - global_position
	var dist_to_axis: float = abs(to_target.cross(direction))
	var normalized_dist := clampf(dist_to_axis / TrainingTarget.RADIUS, 0.0, 1.0)
	var dmg := int(floorf(lerpf(weapon.damage_center, weapon.damage_edge, normalized_dist)))

	if not is_replay:
		target.register_training_hit(dmg)
	# Les étincelles et l'éclat restent ceux d'un mur : la cible est en dur, elle
	# ne saigne pas. C'est le SON qui change de camp, parce que c'est lui qui
	# porte l'information dans un mode où l'on ne regarde pas le décor.
	_spawn_wall_effects(hit_point, false)
	# V4.2 — la cible entend le centre et le bord comme un corps. Elle calcule
	# deja ses degats avec `damage_center`/`damage_edge` : le son suit le meme
	# nombre. C'est le seul mode dont le sujet EST de viser, donc celui ou la
	# difference compte le plus.
	AudioManager.play_hit(hit_point, normalized_dist)
	if not is_replay:
		_spawn_damage_number(hit_point, dmg)
	_fade_and_destroy(hit_point)

## Distance parcourue le long du pas avant d'entrer dans le cercle, -1 s'il
## n'est pas atteint pendant ce pas.
## ============================================================================
## V4.10 — LE FROLEMENT DU CARREAU
## ============================================================================
##
## **« Une info de TIR, pas de position »** (Adrien, 2026-08-28). C'est la phrase
## qui decide de tout ce qui suit, et elle merite d'etre relue avant d'y toucher.
##
## L'arbalete ne se trahit presque pas : pas de lueur de bouche, pas de lumiere
## sur le projectile, et elle tue en un coup au centre comme au bord. Jusqu'ici,
## se faire manquer de dix pixels par un carreau ne s'apprenait JAMAIS. Ce son le
## dit — et il ajoute du suspens sans rien donner, parce que :
##
## ⚠️ **il sonne au point le plus proche de CELUI QUI EST FROLE, jamais au
## canon.** Une source ponctuelle posee a cote de la victime ne dit rien de l'ou
## vient le tir : elle dit qu'il y en a eu un. Le jouer au canon — ce qu'une
## premiere version faisait — l'aurait rendu inutile (confondu avec le coup) ; le
## jouer le long de la trajectoire en aurait fait une fleche vers le tireur.
##
## Le tireur l'entend aussi, de loin et faiblement : « j'ai failli toucher ».
## C'est du retour, pas du renseignement.
##
## ⚠️ Reserve a l'arbalete. Les autres armes ont une lueur de bouche qui les
## trahit deja ; leur ajouter un frolement doublerait une information qui existe.
const FROLEMENT_RAYON := 90.0

## Un seul frolement par carreau. Sans ce verrou, un carreau rasant emettrait a
## chaque pas de simulation — un crepitement, la ou il faut un evenement.
var _frolement_joue: bool = false

func _guetter_le_frolement(longueur_pas: float) -> void:
	if _frolement_joue or is_replay or weapon == null:
		return
	if weapon.slug() != "arbalete":
		return
	for n in get_tree().get_nodes_in_group("players"):
		if n == source_player or not is_instance_valid(n):
			continue
		var cible := n as Node2D
		if cible == null:
			continue
		var vers := cible.global_position - global_position
		var proj := vers.dot(direction)
		# Le point le plus proche doit tomber SUR ce pas : sinon le carreau
		# n'est pas encore arrive a sa hauteur, ou l'a deja depassee lors d'un
		# pas precedent — ou il aurait deja sonne.
		if proj < 0.0 or proj > longueur_pas:
			continue
		var perp := sqrt(maxf(0.0, vers.length_squared() - proj * proj))
		if perp > FROLEMENT_RAYON:
			continue
		_frolement_joue = true
		AudioManager.play_bolt_flight(global_position + direction * proj)
		return

## ============================================================================
## FU3 — LES TUNNELS DE BALLE DANS LA FUMÉE
## ============================================================================
##
## Une balle qui traverse le nuage d'une fusée y creuse une trace : incandes-
## cente pour une arme qui émet de la lumière (elle accuse le tireur), SOMBRE
## pour l'arbalète (la seule trace au monde de l'arme sans lumière). Purement
## local à cette balle et à la fusée qu'elle traverse : aucun RPC, aucune
## trace en killcam — un effet cosmétique dérivé d'un tir déjà arbitré ailleurs.

## La fusée dont le nuage contient `pos`, ou `null`. Une seule à la fois compte
## (les nuages de deux fusées ne se recouvrent presque jamais en pratique, et
## rien dans le jeu n'interdit d'en ignorer une seconde superposée).
func _fumee_sous(pos: Vector2) -> Fusee:
	for f in get_tree().get_nodes_in_group("fusees"):
		if f is Fusee and f.occultation_pour(pos) > 0.0:
			return f
	return null

## Compare l'appartenance à une fumée à `pos` contre celle du pas précédent :
## sur un changement, ferme le tunnel en cours (s'il y en avait un) et en
## ouvre un nouveau si `pos` entre dans une fumée.
func _maj_tunnel(pos: Vector2) -> void:
	var courante := _fumee_sous(pos)
	if courante == _fumee_traversee:
		return
	if _fumee_traversee != null and is_instance_valid(_fumee_traversee):
		_fumee_traversee.ajouter_tunnel(_fumee_entree, pos,
			weapon != null and not weapon.emits_light)
	_fumee_traversee = courante
	if courante != null:
		_fumee_entree = pos

## Version « rebond » : ferme et rouvre INCONDITIONNELLEMENT à `pos`, même si
## la fusée traversée est la même avant et après — un rebond plie la
## trajectoire, et un tunnel droit d'un bout à l'autre mentirait sur sa forme.
func _rompre_tunnel(pos: Vector2) -> void:
	if _fumee_traversee != null and is_instance_valid(_fumee_traversee):
		_fumee_traversee.ajouter_tunnel(_fumee_entree, pos,
			weapon != null and not weapon.emits_light)
	_fumee_traversee = _fumee_sous(pos)
	if _fumee_traversee != null:
		_fumee_entree = pos

## ============================================================================
## FU5 — LA BALLE QUI ÉTEINT UNE FUSÉE POSÉE
## ============================================================================

## La fusée POSÉE (pas en vol) la plus proche que ce pas croise, ou `null`.
## Même patron que `_circle_entry_distance`, déjà utilisé pour la cible
## compensée : ni collision physique (une fusée n'a pas de forme), ni
## priorité sur un mur ou un joueur — appelé seulement quand ni l'un ni
## l'autre n'a répondu ce pas (voir le site d'appel).
func _fusee_touchee_ce_pas(travel_step: float) -> Fusee:
	var meilleure: Fusee = null
	var meilleure_dist := travel_step + 1.0
	for f in get_tree().get_nodes_in_group("fusees"):
		if not (f is Fusee) or not f.est_allumee_au_sol():
			continue
		var d := _circle_entry_distance(global_position, direction, travel_step,
			f.global_position, FuseeModele.EXTINCTION_RAYON_BALLE + radius)
		if d >= 0.0 and d < meilleure_dist:
			meilleure = f
			meilleure_dist = d
	return meilleure

static func _circle_entry_distance(origin: Vector2, dir: Vector2, length: float,
		center: Vector2, r: float) -> float:
	var to_center := center - origin
	var proj := to_center.dot(dir)
	var perp_sq := to_center.length_squared() - proj * proj
	var r_sq := r * r
	if perp_sq > r_sq:
		return -1.0
	var half := sqrt(r_sq - perp_sq)
	var entry := proj - half
	if entry < 0.0:
		# Déjà dans le cercle au départ du pas : impact immédiat, sauf si le
		# cercle est entièrement derrière.
		if proj + half < 0.0:
			return -1.0
		entry = 0.0
	if entry > length:
		return -1.0
	return entry

## V2.6 — Le trait du tir fatal sur-expose : largeur et énergie triplées,
## fondu ralenti pour que le gel de l'instant fatal (V2.1) fige une image
## incandescente. L'arbalète, sans lumière par design, ne gagne que la largeur.
const LETHAL_FADE_DURATION := 0.35
var _fade_duration := 0.08

func _flare_trail() -> void:
	_fade_duration = LETHAL_FADE_DURATION
	if light.enabled:
		light.energy *= 3.0
	if has_node("Core"):
		var core: Line2D = get_node("Core")
		core.width *= 3.0
	if has_node("Aura") and get_node("Aura").visible:
		get_node("Aura").modulate.a = 1.0

func _fade_and_destroy(hit_point: Vector2):
	# FU3 — ferme tout tunnel en cours au point de mort EXACT, quelle que soit
	# la cause (mur, joueur, cible, fusée, portée max) : les quatre sites
	# d'appel de cette fonction couvrent toutes les morts d'une balle.
	if not is_replay:
		_maj_tunnel(hit_point)
	set_physics_process(false)
	var final_step = hit_point - global_position
	var dist = final_step.length()
	
	# Keep the trail length that was built up, properly bounded
	var dist_from_spawn = hit_point.distance_to(spawn_pos)
	var trail_length = min(dist_from_spawn, 800.0)
	global_position = hit_point
	light.rotation = 0.0
	light.scale = Vector2(max(1.0, trail_length / 128.0), 0.15)
	light.position = -Vector2(trail_length / 2.0, 0)
	
	if has_node("Core"):
		get_node("Core").points = PackedVector2Array([Vector2.ZERO, Vector2(-trail_length, 0)])
	
	# DA4.13 — la balle s'éteint : EXTINCTION, et surtout PAS `SORTIE`.
	#
	# ⚠️ **`SORTIE` veut dire « un élément quitte l'interface » — il part quelque
	# part.** Une lumière ne part pas, elle décroît, et une décroissance est
	# franche puis traîne : l'inverse exact de `SORTIE`, qui s'attarde puis file.
	# Mesuré : 0,87 d'écart entre les deux courbes. La lumière serait restée
	# pleine puis aurait disparu d'un coup. Distinction due à la session DA3.
	#
	# ⚠️ **Le départ est figé à l'appel, pas lu au démarrage du tweener.**
	# `Charte.animer()` prend la valeur de départ en paramètre ; `tween_property`
	# la lisait au moment où le tweener démarre. Ici les trois partent ensemble et
	# rien ne repeint entre-temps, donc les deux se valent — mais la différence a
	# déjà éteint un effet en silence le 2026-08-26, et elle mérite d'être lue.
	var tween = create_tween().set_parallel(true)
	Charte.animer(tween, light, "energy", light.energy, 0.0, _fade_duration,
		Charte.Courbe.EXTINCTION)
	if has_node("Core"):
		var noyau := get_node("Core") as CanvasItem
		Charte.animer(tween, noyau, "modulate:a", noyau.modulate.a, 0.0,
			_fade_duration, Charte.Courbe.EXTINCTION)
	if has_node("Aura"):
		var aura := get_node("Aura") as CanvasItem
		Charte.animer(tween, aura, "modulate:a", aura.modulate.a, 0.0,
			_fade_duration, Charte.Courbe.EXTINCTION)
	tween.chain().tween_callback(queue_free)

## Le pool est créé par GameState ; sans lui (tests headless isolés) les impacts
## restent silencieux plutôt que de retomber sur l'ancien chemin allouant.
func _particle_pool() -> ParticlePool:
	return get_tree().get_first_node_in_group("particle_pool") as ParticlePool

func _spawn_blood_particles(pos: Vector2, color: Color, amount: int, speed_min: float, speed_max: float, base_dir: Vector2, spread_deg: float):
	var pool := _particle_pool()
	if pool == null: return
	pool.emit(ParticlePool.Kind.BLOOD, pos, color, amount, speed_min, speed_max, base_dir, spread_deg)

func _spawn_spark_particles(pos: Vector2, color: Color, amount: int, speed_min: float, speed_max: float, base_dir: Vector2, spread_deg: float):
	var pool := _particle_pool()
	if pool == null: return
	pool.emit(ParticlePool.Kind.SPARK, pos, color, amount, speed_min, speed_max, base_dir, spread_deg)

## `proximite_bord` : 0 au centre du corps, 1 au bord — **le nombre meme qui
## calcule les degats**, jamais une seconde mesure. V4.2 rend audible un modele
## qui existait, muet, depuis toujours : le tireur entend s'il a bien centre son
## coup, ce qui est la seule facon de progresser au tir dans le noir.
##
## ⚠️ Le derive du MEME `normalized_dist` que `opp_hit_damage`. Un second calcul
## « equivalent » finirait par diverger — ce depot a paye trois fois cette
## lecon le 2026-08-24 sur l'echelle de la torche.
##
## `distance_axe_centre` (2026-09-09) : le MEME `dist_to_axis`, avant sa
## division par `player_radius` — pas une troisieme mesure, l'etape d'avant
## dans le meme calcul. `blood_stain.gd` s'en sert pour choisir entre la tache
## en etoile centree et les taches directionnelles (regle d'Adrien : l'etoile
## seulement a 0-2 px du centre reel).
func _spawn_hit_effects(pos: Vector2, proximite_bord: float = 0.0,
		distance_axe_centre: float = INF):
	AudioManager.play_hit(pos, proximite_bord)
	# Pure blood red
	var blood_color = Charte.CARMIN
	# Exit wound: large splatter forward
	_spawn_blood_particles(pos, blood_color, 15, 200.0, 800.0, direction, 60.0)
	# Entry wound: smaller splatter backward (bouncing off the shooter or walls behind)
	_spawn_blood_particles(pos, blood_color, 10, 100.0, 400.0, -direction, 90.0)
	
	# Permanent floor stain
	var gs = get_tree().get_first_node_in_group("game_state")
	if gs and gs.arena:
		var arena = gs.arena
		var stain = Node2D.new()
		stain.set_script(preload("res://blood_stain.gd"))
		arena.add_child(stain)
		stain.setup(pos, direction, distance_axe_centre)

## `avec_son` permet à la cible d'échauffement de garder les étincelles du mur
## sans en prendre le bruit. Un drapeau plutôt qu'une copie de la fonction : les
## effets visuels d'un impact ont déjà trois lieux de vérité (particules, éclat,
## arène), et un quatrième finirait par diverger.
func _spawn_wall_effects(pos: Vector2, avec_son: bool = true):
	if avec_son:
		AudioManager.play_wall_impact(pos)
	# Sparks bounce BACKWARDS from the wall
	_spawn_spark_particles(pos, Charte.AMBRE, 12, 100.0, 450.0, -direction, 120.0)
	# DA2.9 — l'éclat reste. Les étincelles disent l'instant, la marque dit que
	# quelqu'un a tiré ici : c'est la seule trace qu'un tir MANQUÉ laisse au
	# monde, et elle raconte le match autant que le sang.
	# ⚠️ L'arène se prend par `game_state.arena`, PAS par `get_parent()` : le
	# parent d'une balle est le nœud des balles, qui ne survit pas à la manche.
	# Un éclat qui y naîtrait disparaîtrait au changement de manche alors que
	# les taches de sang, elles, racontent le match entier.
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs and gs.arena:
		var eclat := Node2D.new()
		eclat.set_script(preload("res://wall_impact.gd"))
		# `setup()` AVANT `add_child()` : il rend `false` si aucun éclat n'est
		# chargeable, et on renonce alors sans avoir rien ajouté à l'arbre.
		if eclat.setup(pos):
			gs.arena.add_child(eclat)
		else:
			eclat.free()


func _spawn_damage_number(pos: Vector2, amount: int):
	var lbl = Label.new()
	lbl.text = str(amount)
	
	var settings = LabelSettings.new()
	settings.font = Charte.police_display(Charte.POIDS_ENSEIGNE)
	# V4.5 — le poids du chiffre EST l'information : taille proportionnelle aux
	# dégâts. Les deux bornes sont des crans de l'échelle et non des nombres
	# choisis ici — un effleurement se lit comme une valeur du HUD, un carreau
	# d'arbalète comme un verdict.
	settings.font_size = int(lerpf(Charte.T_APPUI, Charte.T_VERDICT,
		clampf(amount / 80.0, 0.0, 1.0)))
	# Trois paliers, et ils empruntent la triade d'état à l'envers : ce qui est
	# bon pour celui qui frappe est mauvais pour celui qui encaisse. Le gros coup
	# monte en ambre — 50, un demi-joueur —, le coup moyen en rouge, le reste
	# reste chaud sans crier.
	if amount >= 50:
		settings.font_color = Charte.AMBRE
	elif amount >= 40:
		settings.font_color = Charte.ROUGE
	else:
		settings.font_color = Charte.HALOGENE
	# DA4.3 — **le contour cesse d'être un nombre et devient un rapport.**
	#
	# Il valait 8 px, fixe, pour une taille de police qui va de `T_APPUI` (19) à
	# `T_VERDICT` (42). Un effleurement recevait donc un halo de **42 % de sa
	# propre taille** et un carreau d'arbalète de 19 % : **les petits chiffres
	# étaient noyés dans leur propre contour, les gros non.** Or c'est précisément
	# l'inverse de ce que V4.5 cherche à faire — le poids du chiffre EST
	# l'information, et un halo qui l'épaissit d'autant plus qu'il est petit
	# écrase la différence qu'on venait d'établir.
	#
	# C'est la même famille que le coefficient de case du code de salon et que la
	# portée de lumière en dur : **une valeur absolue là où il fallait un
	# rapport**, juste pour un seul cas et fausse pour tous les autres.
	#
	# DA5.7 — cette formule est désormais celle de `Charte.contourer_settings()`,
	# généralisée aux sept autres sites du dépôt qui portaient chacun un nombre
	# fixe posé pour leur propre taille. Ce site reste la référence historique ;
	# l'ombre suit le même ratio, pour la même raison — c'est ce que porte le
	# `true` ci-dessous.
	Charte.contourer_settings(settings, settings.font_size, true)

	lbl.label_settings = settings
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	lbl.custom_minimum_size = Vector2(200, 100)
	lbl.position = pos - Vector2(100, 50)
	lbl.pivot_offset = Vector2(100, 50)
	lbl.z_index = 100
	
	var mat = CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	lbl.material = mat
	
	get_parent().add_child(lbl)
	
	# DA4.13 — quatre gestes, et chacune de leurs courbes dit ce qu'elle fait.
	var tw = lbl.create_tween().set_parallel(true)
	lbl.scale = Vector2.ZERO
	# Le surgissement : REBOND, avec son dépassement. C'était déjà `BACK_OUT`,
	# la conversion ne change rien à l'œil.
	Charte.animer(tw, lbl, "scale", Vector2.ZERO, Vector2(1.5, 1.5),
		Charte.D_MOYEN, Charte.Courbe.REBOND)
	# Le retour au calme : le chiffre s'installe. ENTREE.
	Charte.animer(tw, lbl, "scale", Vector2(1.5, 1.5), Vector2.ONE,
		Charte.D_MOYEN, Charte.Courbe.ENTREE).set_delay(Charte.D_MOYEN)

	var float_offset = Vector2(randf_range(-30, 30), -70 - randf_range(0, 30))
	# La dérive vers le haut : elle arrive et se pose. ENTREE.
	Charte.animer(tw, lbl, "position", lbl.position, lbl.position + float_offset,
		0.7, Charte.Courbe.ENTREE)

	# L'effacement du libellé : SORTIE. Lui part VRAIMENT — c'était déjà un
	# `EASE_IN`, donc forme et sens coïncident.
	Charte.animer(tw, lbl, "modulate:a", 1.0, 0.0, Charte.D_LONG,
		Charte.Courbe.SORTIE).set_delay(0.4)
	tw.chain().tween_callback(lbl.queue_free)
