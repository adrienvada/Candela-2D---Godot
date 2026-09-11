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
## ## Elle ne se tue pas à la balle
##
## Elle le pouvait jusqu'au 2026-09-11 — trois balles l'éteignaient. Adrien l'a
## renversé : un gadget diffus ne se détruit pas au tir. On la contourne, ou on
## attend qu'elle s'éteigne.

## Le rayon de la nappe, en pixels. Il sert à trois choses à la fois, et c'est
## voulu : la forme de collision, le dessin, et la zone qui brûle. Trois valeurs
## qui devraient être égales finiraient par ne plus l'être.
const RAYON := 68.0

## Ce que coûte une seconde passée dedans, en points de vie.
##
## ⚠️ **Calibré pour interdire, pas pour tuer.** Traverser la nappe en courant, par
## son diamètre, prend une demi-seconde (2 × 68 / 260) : deux tics, huit points —
## négligeable, et c'est le but, l'Incendiaire ne gagne pas parce qu'on a marché
## dessus. Y rester deux secondes en coûte trente-deux, ce qui n'est plus
## négligeable du tout. (Ce texte a dit « un quart de seconde, quatre points »
## jusqu'au 2026-09-11 : c'était déjà huit, le tic n'a rien changé au total.)
const DEGATS_PAR_SECONDE := 16.0

## Une brûlure se verse par TICS de quatre points : 16 PV/s font un tic toutes les
## 0,25 s (étape 28, 2026-09-11, décision d'Adrien — pas un dosage, donc pas de
## bascule de banc). Elle se versait par image RENDUE — un RPC fiable, une lumière
## d'impact à ombres, une vibration et un souffle à chaque image, fps déplafonnés :
## deux secondes dedans à 480 images/s faisaient un millier d'appels et des
## centaines de lumières vivantes, sur un plafond moteur de quinze par item.
## Le seul réglage du rythme : la période en dérive (PV_PAR_TIC / DEGATS_PAR_SECONDE).
const PV_PAR_TIC := 4.0

## ⚠️ **Une marge de flottant, pas un réglage.** Seize fois 1/480 ajouté image après
## image ne fait pas exactement quatre : 2,0 s pile laissent 3,99999999999996 dans
## la charge (3,999999999999994 à 60 images/s), et le huitième tic tombe une image
## plus tard (mesuré en doubles, ceux de GDScript). Rien ne se perd — la charge est
## gardée —, mais le tic quitterait la grille des 0,25 s. Un millionième de PV,
## soixante nanosecondes de feu.
##
## Pourquoi la marge suffit sur toute la vie de la nappe : ôter un tic n'ajoute
## AUCUNE erreur. `x − 4` est exact pour toute charge qui passe le seuil, quelle
## que soit la taille de l'image — au-dessus de 4, parce que 4 est un multiple de
## l'ulp de x ; juste sous 4 (la marge), par le lemme de Sterbenz. Seules les
## additions arrondissent, d'au plus 4,4e-16 PV à une image ordinaire (charge sous
## huit) : dix secondes à 480 images/s font au pire 2e-12 PV, près de cinq cent
## mille fois sous la marge (vérifié en doubles, mesuré 1e-13 à 1 000 images/s). (Ce
## texte a dit « la charge reste sous huit » : faux, une image d'une seconde la
## porte à seize — revue du lot A1, 2026-09-11.)
const TOLERANCE_TIC := 1e-6

## Jusqu'où les braises aveuglent, en pixels.
##
## Petit, et bien plus petit que la fusée (400) ou la mine (460) : c'est une
## lueur au sol, pas une source. Elle gêne qui la surplombe, elle n'aveugle
## personne à l'autre bout de la salle.
const RAYON_EBLOUISSEMENT := 200.0

const ENERGIE := 1.8

var _lumiere: PointLight2D
var _nappe: Sprite2D = null

## La brûlure due et pas encore versée, en PV, par identifiant d'instance du joueur.
## **Hôte seul** : `appliquer_effets()` n'est appelé que là. Rien sur le fil.
##
## ⚠️ **Tenue par NAPPE et par joueur**, pas par joueur seul (étape 28). Sous deux
## nappes superposées — deux Incendiaires, un gadget debout chacun —, deux
## accumulateurs versent chacun leur tic : huit par seconde, le même total que
## deux fois 16 PV/s d'avant. La décision reste dans le gadget, comme le veut la
## doctrine du socle (`GadgetBase.veut_s_allumer()`). Elle meurt avec la nappe —
## fin de vie, nouvelle pose, purge de manche : au plus un tic de perdu.
var _charge: Dictionary = {}


func _init() -> void:
	rayon = RAYON
	# Une balle passe au-dessus des charbons, sans rien en disperser : la nappe
	# ne se tue pas à la balle (Adrien, 2026-09-11).
	arrete_les_balles = false
	touche_par_les_balles = false
	eblouit = true
	eblouissement_dirige = false
	# ⚠️ **Écrit ici et nulle part ailleurs** depuis l'étape 28 : il rétrécissait
	# avec la lueur. Voir `energie_relative()`.
	rayon_eblouissement = RAYON_EBLOUISSEMENT
	# Une nappe répandue au sol n'a pas d'orientation qui compte.
	angle_pose = 0.0
	# Elle n'assombrit rien : voir la note de tête, et `GadgetMine` qui a payé la
	# même leçon une étape plus tôt.
	occulte_la_lumiere = false
	# Le repère du poseur (étape 28) : la zone qui BRÛLE. Dessiné sous la nappe, il
	# ne se voit que là où la peinture ne couvre pas (le garde n'exige que 90 %) ou
	# pâlit (35 % en fin de vie) — le bord qui manque. Voir `GadgetBase.Z_REPERE`.
	rayon_repere = RAYON


## Pas d'occluder : des charbons au sol ne portent pas d'ombre, et un occluder
## enfermerait la lueur dans elle-même.
func _monter_occluder() -> void:
	pass


func _ready() -> void:
	super()
	_monter_lueur()


## Les dégâts. **Hôte seul** — `GameState._maj_gadgets()` ne l'appelle pas
## ailleurs, et `take_damage()` refait le partage de son côté. Cette fonction ne
## fait QUE brûler : le fondu de la nappe vit dans `_physics_process()`, qui tourne
## chez les deux pairs.
##
## ⚠️ **Elle ne connaît pas son poseur, et brûle donc tout le monde.** C'est la
## règle des choses posées, déjà écrite pour la fusée et la mine : *« on ne la
## pose pas à ses pieds impunément »*. Un feu qui épargnerait celui qui l'a
## allumé serait la seule chose du jeu à savoir qui est qui.
##
## ⚠️ **Appelée à chaque image RENDUE** (`GameState._process()`), fps déplafonnés :
## le `delta` dépend de la machine. Elle ACCUMULE donc la brûlure et la verse par
## tics de `PV_PAR_TIC` — même nombre de tics à 60 qu'à 480 images/s. Le patron est
## celui du piétinement FU5, dans `GameState` : un `delta` de `_process` contre un
## seuil.
func appliquer_effets(joueurs: Array, delta: float) -> void:
	if is_queued_for_deletion():
		return
	for j in joueurs:
		if not is_instance_valid(j) or not (j is Node2D):
			continue
		if j.get("dead") or not j.visible:
			continue
		if j.global_position.distance_to(global_position) > RAYON:
			# ⚠️ **La charge est GARDÉE dehors**, et c'est ce qui rend la traversée
			# juste. Remise à zéro, des allers-retours plus courts qu'un tic ne
			# coûteraient RIEN — mesuré : 2,1 s cumulées dans le feu, zéro PV. Versée
			# à la sortie, elle ferait un tic de 0,3 PV qui n'en est pas un. Gardée,
			# la nappe a infligé à tout instant ⌊16·T/4⌋·4 : jamais plus qu'avant, au
			# plus un tic de moins. Elle meurt avec la nappe.
			continue
		var cle: int = j.get_instance_id()
		var charge: float = float(_charge.get(cle, 0.0)) + DEGATS_PAR_SECONDE * delta
		# `while` et non `if` : une image d'une seconde (hoquet, fenêtre en arrière-
		# plan) doit verser ses quatre tics.
		while charge >= PV_PAR_TIC - TOLERANCE_TIC:
			charge -= PV_PAR_TIC
			# `source_player` reste le poseur : c'est lui que le tableau de fin doit
			# créditer, et lui que la killcam doit nommer.
			j.take_damage(PV_PAR_TIC, _poseur())
			if j.get("dead"):
				# Mort pendant une rafale : plus rien à verser à un corps.
				charge = 0.0
				break
		_charge[cle] = maxf(0.0, charge)


## La lueur et la nappe pâlissent avec l'âge, CHEZ LES DEUX PAIRS (étape 28).
##
## ⚠️ **Elles pâlissaient dans `appliquer_effets()`, que seul l'hôte appelle, et
## seulement en manche** (`GameState._maj_gadgets()`) : chez l'invité, la nappe
## restait à pleine lueur dix secondes puis disparaissait d'un coup, pendant que
## l'éblouissement arbitré par l'hôte, lui, baissait — « l'aveuglement suit ce qui
## brûle » n'aurait été vrai que sur un écran. L'âge court chez les deux pairs
## (`GadgetBase._physics_process()`) : une formule, deux écrans. Effet de bord
## voulu : la nappe ne se fige plus chez l'hôte pendant la killcam.
## Une lumière qui s'éteindrait d'un coup se lirait comme une coupure de rendu.
func _physics_process(delta: float) -> void:
	super(delta)
	if is_queued_for_deletion():
		return
	var k := energie_relative()
	if _lumiere != null:
		_lumiere.energy = ENERGIE * k
	if _nappe != null:
		_nappe.modulate.a = k


## Ce que la nappe brûle encore, entre 0,35 et 1 — la courbe de sa lueur, une seule
## formule pour le rendu et l'éblouissement (étape 28, 2026-09-11, Adrien).
##
## ⚠️ Son rayon d'éblouissement ne bouge PLUS : le GAIN de
## `GameState._sources_eblouissantes()` porte la baisse, un rayon qui rétrécirait
## en plus l'atténuerait deux fois (mesuré à 68 px en fin de vie : 0,010 au lieu
## de 0,231).
func energie_relative() -> float:
	if duree_vie <= 0.0:
		return 1.0
	var reste := clampf(1.0 - age() / duree_vie, 0.0, 1.0)
	return 0.35 + 0.65 * reste


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
