class_name GadgetMine
extends GadgetBase

## La mine au magnésium — gadget de l'Allumeur, chantier CLASSES, étape 12.
##
## ## Elle n'explose pas, elle ALLUME
##
## C'est le point de conception, et il vient de la classe : l'Allumeur est celui
## qui fait de la lumière — *« la mine, les cartouches vives, les deux fusées. La
## lumière maximale, celle qui ne laisse aucune ombre où se mettre. »* Lui donner
## des dégâts en ferait un piégeur ordinaire, jouable dans n'importe quel jeu de
## tir ; en faire un **flash** la rend jouable seulement dans celui-ci, où être vu
## est déjà être mort.
##
## Elle ne blesse donc personne. Elle prend les yeux, et elle révèle — ce qui,
## dans le noir absolu, coûte plus cher qu'un quart de barre de vie.
##
## ## Elle ne distingue pas son poseur, et c'est la règle du jeu
##
## Une source POSÉE éblouit tout le monde pareil, poseur compris : c'est ce que
## `game_state._sources_eblouissantes()` écrit pour la fusée depuis l'arbitrage
## d'Adrien — *« on ne la lance pas à ses pieds impunément »*. Le déclenchement
## suit la même règle, et il en fait le prix de la classe : une mine posée est un
## endroit où l'on ne repasse pas.
##
## ## L'armement n'est pas un délai de confort
##
## Sans lui, le poseur se déclenche sa propre mine à l'instant où il la pose : il
## se tient à `GadgetBase.PORTEE_POSE` du point, soit 96 px, et il faudrait donc
## un rayon de déclenchement inférieur à ça pour l'épargner — c'est-à-dire une
## mine qu'on enjambe. L'armement permet un rayon large ET un poseur qui s'en va.
##
## ## L'autorité est chez l'hôte, la DÉCISION vit ici
##
## `veut_s_allumer()` est appelé par `GameState` sur l'hôte seul ; c'est lui qui
## envoie l'ordre. Ce fichier porte le rayon et l'armement, parce que c'est là
## qu'ils se lisent avec ce qu'ils signifient ; `GameState` porte l'autorité,
## parce qu'elle appartient au réseau et à rien d'autre.

## Le rayon de déclenchement, en pixels.
const RAYON_DECLENCHEMENT := 72.0

## Le délai avant qu'elle soit sensible, en secondes.
const ARMEMENT := 1.2

## Combien de temps le magnésium brûle, en secondes.
##
## Court, et bien plus court qu'une fusée (~20 s) : ce n'est pas un éclairage,
## c'est un flash. Une mine qui éclairerait longtemps ferait le travail de la
## fusée en mieux, et la fusée n'aurait plus de raison d'exister.
const DUREE_EMBRASEMENT := 1.6

## Jusqu'où elle aveugle une fois allumée, en pixels.
##
## Plus loin que la fusée (400 px), parce qu'elle brûle plus fort et bien moins
## longtemps. Le prix d'un flash est dans sa violence, celui d'une fusée dans sa
## durée : deux façons de payer, pas la même.
const RAYON_EBLOUISSEMENT := 460.0

const ENERGIE := 6.0

var _allumee: bool = false
## Elle a pris une balle. Une mine abattue ne s'éteint pas — elle part.
var _touchee: bool = false
var _lumiere: PointLight2D


func _init() -> void:
	rayon = 8.0
	# Un boîtier métallique posé au sol : la balle s'y arrête. C'est ce qui rend
	# la mine réfutable — mais la désamorcer coûte d'être assez loin pour ne pas
	# la prendre dans les yeux, voir `encaisser()`.
	arrete_les_balles = true
	pv = 1.0
	eblouit = true
	# Elle crache dans toutes les directions : pas d'axe, régime de proximité.
	eblouissement_dirige = false
	# ⚠️ **Zéro tant qu'elle n'a pas pris feu**, et c'est la seule chose qui
	# l'empêche d'aveugler en dormant. `Eblouissement.intensite_proximite()` rend
	# 0 pour un rayon nul, donc il n'y a aucun cas particulier à écrire ailleurs.
	rayon_eblouissement = 0.0
	# Un boîtier posé n'a pas d'orientation qui compte.
	angle_pose = 0.0
	# ⚠️ **Elle n'arrête pas la lumière, et ce n'est pas un raccourci.** Un boîtier
	# posé à plat sur le sol, vu de dessus, n'a rien à masquer — c'est la seule
	# différence entre lui et une bâche tendue. Le drapeau tient
	# `game_state._ligne_de_vue_depuis()` d'accord avec la réalité : sans lui, la
	# mine arrêterait l'aveuglement sans arrêter le faisceau.
	occulte_la_lumiere = false


## Pas d'occluder, et c'est CE QUI RÉPARE SON PROPRE FLASH.
##
## ⚠️ Le socle en pose un pour tout le monde ; le garder ici mettait la flamme
## **à l'intérieur de son propre occluder**, ce qui « ne produit ni ombre ni
## lumière mais du hasard » — la phrase est de `player.gd`, qui a payé la même
## leçon sur `body_light` le 2026-08-26. Constaté à la capture : ombres activées,
## le flash rendait un voile gris plat au lieu d'un disque net ; occluder retiré,
## le disque revient, murs compris.
func _monter_occluder() -> void:
	pass


## Demande-t-elle à s'allumer ? **Hôte seul** — voir `GameState._maj_gadgets()`.
func veut_s_allumer(joueurs: Array) -> bool:
	if _allumee:
		return false
	if _touchee:
		return true
	if age() < ARMEMENT:
		return false
	for j in joueurs:
		if not is_instance_valid(j) or not (j is Node2D):
			continue
		# Un mort ne déclenche rien : son corps reste sur le terrain, et une mine
		# qui s'allumerait dessus brûlerait toute seule après la manche.
		if j.get("dead"):
			continue
		if not j.visible:
			continue
		if j.global_position.distance_to(global_position) <= RAYON_DECLENCHEMENT:
			return true
	return false


## L'ordre d'allumage, venu de l'hôte et rejoué chez les deux pairs.
func allumer() -> void:
	if _allumee:
		return
	_allumee = true
	rayon_eblouissement = RAYON_EBLOUISSEMENT
	# ⚠️ La fin se règle par la durée de vie du socle plutôt que par un second
	# compteur : `GadgetBase` compare déjà `age()` à `duree_vie`, et deux
	# horloges pour une même mort finiraient par se contredire.
	duree_vie = age() + DUREE_EMBRASEMENT
	_monter_flamme()


## Une mine abattue ne s'éteint pas, elle PART.
##
## ⚠️ Elle ne meurt donc pas ici, contrairement à tous les autres gadgets : elle
## demande à s'allumer, et c'est son embrasement qui la tue. Sans ça, l'abattre
## serait un désamorçage gratuit, et une mine qu'on désamorce d'une balle à
## distance ne menace personne.
func encaisser(degats: float) -> bool:
	if _allumee:
		return false
	pv -= degats
	if pv > 0.0:
		return false
	_touchee = true
	return true


func _physics_process(delta: float) -> void:
	super(delta)
	if not _allumee or _lumiere == null or is_queued_for_deletion():
		return
	# La combustion s'éteint sur la fin : un flash qui disparaîtrait d'un coup se
	# lirait comme une coupure de rendu, pas comme une fin de combustion.
	var reste := maxf(0.0, duree_vie - age()) / DUREE_EMBRASEMENT
	_lumiere.energy = ENERGIE * reste * reste
	rayon_eblouissement = RAYON_EBLOUISSEMENT * reste


func _monter_flamme() -> void:
	_lumiere = PointLight2D.new()
	_lumiere.name = "Embrasement"
	LightTextures.poser(_lumiere, LightTextures.RETRODIFFUSION, 520.0)
	# ⚠️ HALOGENE et non un blanc franc, malgré le magnésium. À cette énergie la
	# teinte sature de toute façon vers le blanc ; poser un blanc pur ferait
	# entrer dans l'arène la seule lumière du jeu qui ne vienne ni d'un feu ni
	# d'un filament — la remarque est déjà écrite deux fois dans `player.gd`.
	_lumiere.color = Charte.HALOGENE
	_lumiere.energy = ENERGIE
	# Les murs l'arrêtent : une lumière qui les traverserait mentirait sur la
	# carte, et la carte est le seul repère stable du joueur.
	_lumiere.shadow_enabled = true
	_lumiere.shadow_item_cull_mask = 1
	_lumiere.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	_lumiere.range_item_cull_mask = 1 | 2 | 4
	add_child(_lumiere)


## Le boîtier : son image, et rien de plus. Le point clair peint en son centre
## n'ÉMET pas — éclairé par le décor comme le reste, il ne se voit que sous une
## torche, ce qui laisse intacte la règle ci-dessous.
##
## ⚠️ **Aucune veilleuse, aucun témoin lumineux.** Une diode qui clignoterait la
## rendrait repérable dans le noir — c'est-à-dire inutile. Ce qu'on doit voir
## d'une mine, c'est le moment où il est trop tard.
func _monter_visuel() -> void:
	_poser_sprite("Visuel", "mine_magnesium")
