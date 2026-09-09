class_name GadgetGresillement
extends GadgetBase

## Le grésillement — gadget du Parasite, chantier CLASSES, étape 16.
##
## ## Il ne prend rien, il corrompt ce que l'autre reçoit
##
## *« Un grésillement qui fait douter d'une lumière qui marche encore. »* C'est
## une petite bobine posée au sol qui fait **sauter les lampes torches** autour
## d'elle : le faisceau papillote, faiblit, revient. On ne sait plus si l'arène
## est vide ou si la lampe lâche.
##
## ## Une perturbation de RENDU, jamais de simulation
##
## ⚠️ **Le grésillement ne touche que `flashlight.energy`, c'est-à-dire ce que
## l'écran MONTRE.** Il ne change rien à l'éblouissement — `_lumiere_recue()`
## échantillonne le pixel du COOKIE, pas l'énergie de la lampe —, rien aux
## trajectoires, rien aux dégâts. C'est la seule forme acceptable dans un jeu
## qui se veut « honnête en compétition », et c'est mot pour mot la règle que
## `brouillage.gd` s'est donnée : *« dégrader la lecture est un coût de
## perception, déplacer une hitbox serait un mensonge »*.
##
## Le coût est réel pour autant : un faisceau qui s'éteint à moitié éclaire à
## moitié. Ce qui est retiré, c'est de l'information — la seule monnaie du jeu.
##
## ## Il ne connaît personne, poseur compris
##
## Quatrième écriture de la règle des choses posées, après la fusée, la mine et
## les braises. Le Parasite qui traverse sa propre zone y perd sa lampe comme
## tout le monde.
##
## ## La forme d'onde vit ICI
##
## Trois sinusoïdes de fréquences incommensurables, plus un seuil : c'est ce qui
## donne un papillotement électrique plutôt qu'une pulsation régulière. Elle est
## **déterministe** — pas de tirage au sort — pour la raison habituelle : deux
## pairs qui grésilleraient différemment produiraient un défaut indébogable.
## `player.gd` ne fait que multiplier ; la signature de l'appareil est à lui.

## Le rayon d'action, en pixels. Large : c'est une zone qu'on rend inhospitalière,
## pas un piège de contact.
const RAYON := 240.0

## Ce qu'il reste de la lampe au cœur de la zone, au creux du grésillement.
##
## ⚠️ **Pas zéro.** Une lampe qui s'éteindrait franchement se lirait comme « ma
## torche est coupée » — une information nette, donc utilisable. Ce qu'on veut
## est le DOUTE : une lampe qui marche encore, mal.
const CREUX := 0.22

const DUREE_ONDE := 0.37


func _init() -> void:
	rayon = 9.0
	# Un boîtier dur : la balle s'y arrête, et c'est la façon de s'en débarrasser.
	arrete_les_balles = true
	pv = 1.0
	eblouit = false
	angle_pose = 0.0
	# Une bobine posée à plat n'assombrit rien — même raison que la mine, et même
	# conséquence : elle ne doit pas arrêter le rayon d'éblouissement.
	occulte_la_lumiere = false


## Un boîtier plat ne porte pas d'ombre.
func _monter_occluder() -> void:
	pass


## Ce par quoi multiplier l'énergie d'une lampe torche à cette position — 1 hors
## de portée, jusqu'à `CREUX` au creux du papillotement, au cœur de la zone.
func facteur_de_lampe(pos: Vector2) -> float:
	var d := pos.distance_to(global_position)
	if d >= RAYON:
		return 1.0
	# Décroissance douce vers le bord : une frontière franche apprendrait au
	# joueur où s'arrête la zone, ce qui la rendrait contournable au pixel.
	var force := 1.0 - smoothstep(0.45, 1.0, d / RAYON)
	if force <= 0.0:
		return 1.0
	return 1.0 - (1.0 - CREUX) * force * _onde()


## Le papillotement, entre 0 (lampe intacte) et 1 (creux). Trois sinusoïdes de
## périodes incommensurables : leur somme ne se répète pas à l'oreille de l'œil,
## là où une seule donnerait une pulsation de phare.
func _onde() -> float:
	var t := age() / DUREE_ONDE
	var s := 0.55 * sin(t * TAU) + 0.30 * sin(t * TAU * 2.7) + 0.15 * sin(t * TAU * 6.3)
	# Redressé puis durci : le faisceau passe l'essentiel du temps près de sa
	# valeur normale et s'effondre par à-coups, ce qui est le grain d'un mauvais
	# contact — et non celui d'un variateur.
	return pow(clampf(absf(s), 0.0, 1.0), 0.6)


## Une bobine et deux électrodes. Volontairement minuscule et sombre : ce qu'on
## doit remarquer est la panne, pas l'appareil.
func _monter_visuel() -> void:
	var bobine := Line2D.new()
	bobine.name = "Visuel"
	var pts := PackedVector2Array()
	for i in 13:
		var ang := (i / 12.0) * TAU
		pts.append(Vector2(cos(ang), sin(ang)) * rayon * (0.6 + 0.4 * (i % 2)))
	bobine.points = pts
	bobine.width = 1.6
	bobine.default_color = Charte.ACIER * 0.5
	bobine.light_mask = MapGeometry.WALL_LAYER
	add_child(bobine)
