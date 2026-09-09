class_name GadgetPoussiere
extends GadgetVolume

## La poussière — gadget du Terrassier, chantier CLASSES, étape 14.
##
## **Large et mince.** *« Il terrasse, et il lève la poussière : une zone où plus
## personne ne voit loin. »* C'est un volume de PORTÉE, pas d'identité : on
## distingue encore qui est là, mais seulement de près — et le Terrassier porte
## le faisceau le plus large du jeu, donc c'est lui que la portée réduite gêne le
## moins.
##
## ⚠️ **C'est la seule dissymétrie voulue du chantier** : un gadget qui pénalise
## les deux camps mais l'un moins que l'autre. Elle est acceptable parce qu'elle
## se LIT — le faisceau large est visible à l'écran, et l'adversaire sait donc à
## quoi il s'expose en entrant.

const RAYON := 168.0


func _init() -> void:
	# ⚠️ **`super()` explicite, et il n'est pas optionnel.** GDScript n'appelle le
	# constructeur parent automatiquement que si la sous-classe n'en déclare
	# aucun. Sans cette ligne, `arrete_les_balles` et `occulte_la_lumiere`
	# gardaient leur valeur du socle — vrai, vrai — et les deux nuages devenaient
	# des murs opaques. Attrapé par la suite, pas à la lecture.
	super()
	rayon = RAYON
	# Mince : on voit à travers, on ne voit pas loin.
	opacite = 0.55
	# Plus fragile que la suie : c'est un nuage minéral, une balle en disperse
	# beaucoup.
	pv = 1.0


## Le gris de béton de la charte : la poussière d'une arène en béton armé n'a pas
## d'autre couleur possible.
func couleur_masse() -> Color:
	return Color(Charte.SOL_B.r, Charte.SOL_B.g, Charte.SOL_B.b, 0.62)
