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
## ## Le balayage n'est PAS répliqué, et c'est le patron de la fusée
##
## Chaque pair fait osciller sa propre copie depuis l'instant de la pose. Les
## deux horloges ne démarrent pas exactement au même tick, donc les faisceaux
## peuvent se déphaser de quelques dizaines de millisecondes. C'est sans
## conséquence : **l'éblouissement est calculé par l'hôte seul et répliqué**, et
## ce que le client voit est un décor. Répliquer l'angle coûterait un flottant
## par tick pour corriger un écart que personne ne peut mesurer.

## L'amplitude du balayage, en radians, de part et d'autre de l'axe de pose.
##
## ⚠️ Un balayage LARGE trahirait le leurre : un joueur qui cherche tourne peu et
## souvent, il ne fait pas des moulinets. 36° de part et d'autre couvrent un
## couloir sans jamais ressembler à un phare.
const AMPLITUDE := 0.63

## La durée d'un aller-retour complet, en secondes.
const PERIODE := 3.6

## L'énergie du faisceau. Celle d'une torche de joueur au repos — et **pas de
## souffle ni de scintillement ici**, délibérément : la torche réelle n'en a pas
## dans son état ordinaire, et en ajouter un ferait de la fausse la seule des
## deux qui respire. Un leurre se trahit par ce qu'il a EN PLUS.
const ENERGIE := 2.5

var _angle_depart: float = 0.0
var _lumiere: PointLight2D


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
	# Le balayage. `age()` court depuis la pose, donc les deux pairs décrivent la
	# même courbe — au déphasage de leur instant de départ près.
	rotation = _angle_depart + sin(TAU * age() / PERIODE) * AMPLITUDE


## Le trépied. Dessiné, comme le voile et l'ombre habitée : vu de dessus, une
## lampe posée est un point et trois pattes.
##
## ⚠️ **Volontairement sombre et petit.** Ce qu'on doit voir d'elle est son
## FAISCEAU ; l'objet lui-même trop lisible dirait « ceci est un gadget » à qui
## l'aperçoit, ce qui est exactement le contraire du but.
func _monter_visuel() -> void:
	var pieds := Line2D.new()
	pieds.name = "Visuel"
	pieds.points = PackedVector2Array([
		Vector2(-rayon, -rayon * 0.7), Vector2.ZERO, Vector2(-rayon, rayon * 0.7)])
	pieds.width = 2.0
	pieds.default_color = Charte.SOL_B
	pieds.light_mask = MapGeometry.WALL_LAYER
	add_child(pieds)

	# La lentille : le seul point clair, et il n'est clair que parce qu'il est la
	# source. Non éclairé par le décor (`light_mask = 0`) — une lampe allumée ne
	# dépend pas de ce qui l'éclaire.
	var lentille := Polygon2D.new()
	lentille.name = "Lentille"
	var pts := PackedVector2Array()
	for i in 8:
		var ang := (i / 8.0) * TAU
		pts.append(Vector2(cos(ang), sin(ang)) * 3.0 + Vector2(6.0, 0.0))
	lentille.polygon = pts
	lentille.color = Charte.HALOGENE
	lentille.light_mask = 0
	lentille.z_index = 6
	add_child(lentille)
