class_name GadgetVolume
extends GadgetBase

## Le socle des VOLUMES — chantier CLASSES, étape 14.
##
## ## Ce qu'un volume fait, et ce qu'il ne fait pas
##
## Il **efface les sprites** qui sont dedans, et il pose une masse sombre sur le
## sol. Il n'arrête ni les balles, ni la lumière, ni l'éblouissement.
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
## La suie du Fumiste est **dense et petite** : on voit qu'il y a quelqu'un, on
## ne voit pas qui. La poussière du Terrassier est **large et mince** : personne
## ne voit loin, mais tout le monde voit un peu. Ce sont les deux seules façons
## de retirer de la vue, et chaque classe en a une.

## L'opacité au cœur du volume, entre 0 et 1. Les sous-classes la posent.
var opacite: float = 0.7

var _masse: Sprite2D


func _init() -> void:
	# Rien n'arrête rien : ni les balles, ni la lumière. Voir la note de tête, et
	# `GadgetMine` qui a introduit le drapeau une étape plus tôt.
	arrete_les_balles = false
	occulte_la_lumiere = false
	eblouit = false
	pv = 2.0
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
	if _masse != null and not is_queued_for_deletion():
		_masse.modulate.a = _fondu()


## La masse : l'image du nuage, posée sur le sol. C'est elle qui PORTE la présence
## du nuage, puisque les sprites qui s'y trouvent, eux, s'effacent.
func _monter_visuel() -> void:
	# ⚠️ Éclairée par le décor, contrairement aux braises : un nuage ne s'allume
	# pas tout seul, et une masse qui brillerait dans le noir absolu trahirait sa
	# position à qui n'a pas de torche. `_poser_sprite()` l'éclaire ainsi.
	_masse = _poser_sprite("Visuel", piece_sprite())
	if _masse != null:
		_masse.z_index = 5


## L'image de la masse — le nom de sa pièce, voir `GadgetProfile.chemin_sprite_de()`.
## Vide dans le socle des volumes : chaque nuage a la sienne, et un volume sans
## image CRIE au lieu de se rabattre sur un disque de secours.
func piece_sprite() -> String:
	return ""
