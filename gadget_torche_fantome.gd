class_name GadgetTorcheFantome
extends GadgetBase

## La torche fantôme — gadget du Braconnier, chantier CLASSES, étape 11.
##
## ## Ce qu'elle est
##
## Une lampe posée sur trépied qui **balaie comme un joueur qui cherche**, avec
## le cookie de la classe qui l'a posée. Vue d'en face, elle est indiscernable
## d'un adversaire qui fouille la pièce : même faisceau, même température, même
## découpe des corps dans la lumière.
##
## ## Pourquoi elle ÉBLOUIT, et pourquoi ce n'est pas une question de puissance
##
## La feuille de route l'écrit depuis l'ouverture du chantier : *« si elle
## n'éblouit pas, il suffit à l'adversaire de la regarder en face pour savoir que
## c'est un faux. Le mensonge n'est complet que si elle aveugle comme une
## vraie. »* Un leurre qu'on peut démasquer par une propriété physique n'est pas
## un leurre, c'est un décor.
##
## C'est ce gadget, et non l'équilibrage, qui justifie l'éblouissement généralisé
## de l'étape 6a : il fallait qu'une source POSÉE puisse aveugler.
##
## ## Elle lit son faisceau, elle ne le recalcule pas
##
## L'éblouissement passe par le même échantillonnage que celui d'un joueur —
## `WeaponData.lumiere_recue()`, qui lit le pixel du cookie. Reproduire un cône
## analytique ici aurait donné une deuxième définition du même faisceau, et
## `game_state.gd` porte déjà la liste des trois fois où cette copie a divergé en
## une seule journée.
##
## ## Un balayage HUMAIN, et identique chez les deux pairs
##
## Il balayait en sinus pur jusqu'au 2026-09-11 : régulier, jamais arrêté — un
## phare. Adrien : « moins régulière, plus aléatoire, plus humaine ». Il enchaîne
## désormais des GESTES — coups d'œil, retours sur un recoin, balayages lents,
## hésitations —, séparés de pauses, chacun porté par une courbe de poignet
## (accélération puis freinage) et un léger tremblement.
##
## ⚠️ **Le hasard vient de la GRAINE de l'hôte**, portée par `rpc_spawn_gadget`
## avec la pose : les deux pairs déroulent le même plan de gestes, fonction pure
## de (graine, âge). Seul l'instant de départ diffère (une latence aller simple) :
## quelques degrés pendant un geste, rien pendant une pause. L'éblouissement reste
## calculé par l'hôte seul et répliqué.

## L'amplitude du balayage, en radians, de part et d'autre de l'axe de pose.
##
## ⚠️ Un balayage LARGE trahirait le leurre : un joueur qui cherche tourne peu et
## souvent, il ne fait pas des moulinets. 36° de part et d'autre couvrent un
## couloir sans jamais ressembler à un phare.
const AMPLITUDE := 0.63

## Les gestes, et leur part : coup d'œil, retour sur la fixation d'avant, balayage
## lent vers l'autre bord ; le reste en hésitations. Tirés par la graine.
const PART_COUP_D_OEIL := 0.45
const PART_RETOUR := 0.20
const PART_BALAYAGE := 0.20
## Vitesse du balayage lent, en rad/s : celle de l'ancien sinus à mi-course.
const VITESSE_BALAYAGE := 1.0
## Le tremblement du poignet : deux sinus faibles (rad), déphasés par la graine.
const TREMBLEMENT := [0.012, 0.009]
const FREQ_TREMBLEMENT := [3.1, 5.3]

## L'énergie du faisceau : celle d'une torche de joueur, 2,5, AVEC son souffle de
## ±3 % (`player.gd`, `TORCH_BREATH_AMP`). ⚠️ Cette note disait jusqu'au 2026-09-11
## que la torche réelle ne respirait pas : c'était faux, et la fausse était la
## seule des deux à ne pas respirer. Un leurre se trahit par ce qu'il a EN MOINS
## autant que par ce qu'il a en plus.
##
## La « puissance » doublée par Adrien le 2026-09-11 n'est PAS ici : elle est dans
## l'alpha du cookie de l'arbalète, qu'elle emprunte (`torch_brightness` 0,6).
## Doubler `energy` en aurait fait la seule lampe plus forte que le vrai Braconnier.
const ENERGIE := 2.5
const SOUFFLE := 0.03

## La graine de l'hôte, posée par `GameState._do_spawn_gadget` avant l'entrée dans
## l'arbre. ⚠️ **Sans cette variable, la graine serait jetée sans un bruit** : le
## spawn ne la pose que `if "graine" in g`, et toutes les torches déroulaient
## alors le même plan.
var graine: int = 0

## Le plan de gestes : une suite de `[début, fin du mouvement, fin de la pause,
## angle de départ, angle d'arrivée]`, construite paresseusement — les suites
## créent la torche sans `_ready()`.
var _plan: Array = []
var _hasard: RandomNumberGenerator = null

var _angle_depart: float = 0.0
var _lumiere: PointLight2D
## Le trépied, qui ne balaie pas : voir `_physics_process()`.
var _pied: Sprite2D = null


func _init() -> void:
	rayon = 9.0
	# Une lampe sur trépied est un objet dur : la balle s'y arrête. C'est aussi
	# ce qui rend le leurre réfutable — on peut le tuer, ça coûte des balles et
	# ça révèle qu'on a tiré.
	arrete_les_balles = true
	pv = 2.0
	eblouit = true
	# Elle pointe LÀ OÙ ON VISAIT, contrairement au voile qu'on plante en
	# travers : une lampe posée de biais dirait tout de suite qu'elle a été posée.
	angle_pose = 0.0
	# Le faisceau se lit, il ne se déduit pas d'une distance.
	eblouissement_dirige = true


func _ready() -> void:
	super()
	_angle_depart = rotation
	_monter_lumiere()


## Le faisceau, monté d'après la classe du poseur.
##
## ⚠️ **Aucun repli si la classe manque.** Une torche fantôme sans cookie serait
## une lampe éteinte que le joueur aurait quand même payée — et rien à l'écran ne
## dirait pourquoi. `get_torch_texture()` crie déjà de son côté quand le fichier
## est absent ; ici on crie quand personne n'a dit de quelle classe il s'agit.
func _monter_lumiere() -> void:
	if classe_du_poseur == null:
		push_error("GadgetTorcheFantome : aucune classe posée, pas de faisceau")
		return
	var tex := classe_du_poseur.get_torch_texture()
	if tex == null:
		return

	_lumiere = PointLight2D.new()
	_lumiere.name = "Faisceau"
	_lumiere.texture = tex
	_lumiere.texture_scale = classe_du_poseur.echelle_torche()
	_lumiere.energy = ENERGIE
	_lumiere.color = Charte.HALOGENE
	# Décalée comme celle d'un joueur : le faisceau part de la lentille, pas du
	# centre de l'objet. Sans ce décalage le cône naîtrait DANS le trépied et son
	# propre occluder le mangerait.
	_lumiere.position = Vector2(14.0, 0.0)
	_lumiere.shadow_enabled = true
	_lumiere.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	# ⚠️ **Les DEUX corps la bouchent, là où une torche de joueur ne voit que
	# celui d'en face.** Elle n'appartient à personne : si le poseur ne découpait
	# pas d'ombre dedans, se tenir dans son propre leurre serait un abri parfait,
	# et le leurre deviendrait une couverture au lieu d'un mensonge.
	_lumiere.shadow_item_cull_mask = 1 | 2 | 4 | 8
	# 1 = décor, 2 = sprites adverses, 4 = sprite du joueur local. Une lumière
	# neutre, comme la fusée : elle éclaire tout le monde dans les deux vues.
	_lumiere.range_item_cull_mask = 1 | 2 | 4
	add_child(_lumiere)

	# ── Le halo de rétrodiffusion, et il n'est PAS décoratif ────────────────
	#
	# Une torche de joueur en produit un : `body_light`, la lumière qui revient
	# de la lentille et baigne le porteur. Vue de loin, c'est même la SEULE chose
	# qu'on distingue d'un adversaire qui éclaire — le halo, pas le corps.
	#
	# ⚠️ Sans lui, le leurre se démasque à distance : un faisceau sans halo à sa
	# racine ne ressemble à aucune torche du jeu, et l'adversaire apprend en une
	# manche à faire la différence. Constaté en capture avant d'être écrit.
	#
	# Il est en revanche plus PAUVRE que celui d'un joueur, et c'est juste : il
	# ne porte pas d'occluder de torse, parce qu'il n'y a pas de torse. Ce qu'il
	# imite est la lumière, pas l'homme.
	var halo := PointLight2D.new()
	halo.name = "Halo"
	halo.color = Charte.HALOGENE
	LightTextures.poser(halo, LightTextures.RETRODIFFUSION,
		LightTextures.EMPREINTE_RETRODIFFUSION)
	halo.energy = 0.6 * classe_du_poseur.backlight_multiplier
	halo.position = Vector2(6.0, 0.0)
	halo.shadow_enabled = true
	halo.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	halo.shadow_item_cull_mask = 1
	halo.range_item_cull_mask = 1 | 2 | 4
	add_child(halo)


func _physics_process(delta: float) -> void:
	super(delta)
	if is_queued_for_deletion():
		return
	# Le balayage : le plan de gestes tiré de la graine, lu à l'âge. `age()` court
	# depuis la pose, donc les deux pairs décrivent la même courbe — au déphasage
	# de leur instant de départ près.
	rotation = _angle_depart + angle_relatif(age())
	if _lumiere != null:
		# La même règle qu'une vraie lampe (étape 27, trouvé en revue) : la suie
		# l'étouffe, le grésillement la fait sauter. Une fausse torche qui brillerait
		# là où la vraie s'éteint se trahirait ; son éblouissement suit le même
		# facteur, chez l'hôte (`GameState._lumiere_recue`).
		var gs = get_tree().get_first_node_in_group("game_state")
		var lampe: float = gs.facteur_de_lampe_a(global_position) if gs != null else 1.0
		_lumiere.energy = ENERGIE * lampe * (1.0 + SOUFFLE * sin(age() * 1.7 + float(graine % 97)))
	# Le trépied est posé au sol : il ne balaie pas. Sa rotation compense celle du
	# nœud, qui porte la tête et le faisceau.
	if _pied != null:
		_pied.rotation = _angle_depart - rotation


## Le trépied et la tête, deux images (2026-09-10). Le pied reste posé ; la tête,
## couchée, faisceau vers +x, tourne avec le nœud — donc avec le faisceau.
##
## ⚠️ **Volontairement sombre et petit.** Ce qu'on doit voir d'elle est son
## FAISCEAU ; l'objet lui-même trop lisible dirait « ceci est un gadget » à qui
## l'aperçoit, ce qui est exactement le contraire du but.
func _monter_visuel() -> void:
	_pied = _poser_sprite("Visuel", "torche_fantome_pied")
	_poser_sprite("Tete", "torche_fantome_tete")

	# La lentille : le seul point clair, et il n'est clair que parce qu'il est la
	# source — posée sur le verre de la tête peinte, au bout du fût.
	var lentille := Polygon2D.new()
	lentille.name = "Lentille"
	var pts := PackedVector2Array()
	for i in 8:
		var ang := (i / 8.0) * TAU
		pts.append(Vector2(cos(ang), sin(ang)) * 2.5 + Vector2(10.0, 0.0))
	lentille.polygon = pts
	lentille.color = Charte.HALOGENE
	# Même correction que les braises : `light_mask = 0` ôte les lumières mais pas
	# le `CanvasModulate` de l'arène, qui éteignait la lentille avec le reste. Ce
	# qui émet doit être incandescent.
	lentille.material = GadgetBase.materiau_incandescent()
	lentille.z_index = 6
	add_child(lentille)


## L'angle du faisceau par rapport à l'axe de pose, à l'instant `t` : fonction PURE
## de (graine, t), bornée par `AMPLITUDE`.
func angle_relatif(t: float) -> float:
	_etendre_le_plan(t)
	var a := 0.0
	for g in _plan:
		if t < g[0]:
			break
		if t <= g[1]:
			var x := (t - float(g[0])) / maxf(0.001, float(g[1]) - float(g[0]))
			# La courbe à secousse minimale : un poignet accélère, puis freine.
			var s := x * x * x * (10.0 - 15.0 * x + 6.0 * x * x)
			a = lerpf(g[3], g[4], s)
			break
		a = g[4]
	var phase := float(graine % 1000) * 0.0063
	a += TREMBLEMENT[0] * sin(TAU * FREQ_TREMBLEMENT[0] * t + phase) \
		+ TREMBLEMENT[1] * sin(TAU * FREQ_TREMBLEMENT[1] * t + phase * 1.7)
	return clampf(a, -AMPLITUDE, AMPLITUDE)


## Construit le plan jusqu'à couvrir `t` (et une seconde au-delà). Déterministe :
## le générateur n'est semé qu'une fois, par la graine, et consommé dans l'ordre.
func _etendre_le_plan(t: float) -> void:
	if _hasard == null:
		_hasard = RandomNumberGenerator.new()
		_hasard.seed = graine
		_plan.clear()
	var fin := 0.0 if _plan.is_empty() else float(_plan[_plan.size() - 1][2])
	var courant := 0.0 if _plan.is_empty() else float(_plan[_plan.size() - 1][4])
	var avant := 0.0 if _plan.size() < 2 else float(_plan[_plan.size() - 2][4])
	while fin <= t + 1.0:
		var r := _hasard.randf()
		var cible := courant
		var pause := 0.25 + 0.9 * pow(_hasard.randf(), 2.0)
		var balayage := false
		if r < PART_COUP_D_OEIL:
			# Un regard qui revient surtout vers le couloir visé : loi triangulaire
			# centrée sur l'axe, à distance franche de l'angle courant.
			for essai in 6:
				cible = (_hasard.randf() + _hasard.randf() - 1.0) * AMPLITUDE
				if absf(cible - courant) >= 0.22:
					break
		elif r < PART_COUP_D_OEIL + PART_RETOUR:
			cible = avant + (_hasard.randf() - 0.5) * 0.07
		elif r < PART_COUP_D_OEIL + PART_RETOUR + PART_BALAYAGE:
			var cote := -1.0 if courant > 0.0 else 1.0
			cible = cote * AMPLITUDE * (0.6 + 0.4 * _hasard.randf())
			pause = 0.1 + 0.3 * _hasard.randf()
			balayage = true
		else:
			cible = courant + (_hasard.randf() - 0.5) * 0.24
		cible = clampf(cible, -AMPLITUDE, AMPLITUDE)
		var ecart := absf(cible - courant)
		var mouvement := maxf(0.2, ecart / VITESSE_BALAYAGE) if balayage else 0.16 + 0.30 * ecart
		_plan.append([fin, fin + mouvement, fin + mouvement + pause, courant, cible])
		avant = courant
		courant = cible
		fin += mouvement + pause
