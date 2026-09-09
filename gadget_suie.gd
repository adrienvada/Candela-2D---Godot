class_name GadgetSuie
extends GadgetVolume

## La cartouche de suie — gadget du Fumiste, chantier CLASSES, étape 14.
##
## **Dense et petite.** *« Un rideau de suie où l'on voit qu'il y a quelqu'un
## sans voir qui. »* C'est un volume d'identité : il ne cache pas la présence — la
## masse est bien visible — il cache **de qui il s'agit**, ce qui dans un duel où
## les deux silhouettes se ressemblent est déjà beaucoup, et le sera davantage
## quand les dix classes auront des sprites distincts.
##
## Le Fumiste est aussi un imposteur : c'est la classe dont l'arme est lourde et
## le chargeur court. La suie lui rend le temps que son arme lui coûte.

const RAYON := 92.0


func _init() -> void:
	# ⚠️ **`super()` explicite, et il n'est pas optionnel.** GDScript n'appelle le
	# constructeur parent automatiquement que si la sous-classe n'en déclare
	# aucun. Sans cette ligne, `arrete_les_balles` et `occulte_la_lumiere`
	# gardaient leur valeur du socle — vrai, vrai — et les deux nuages devenaient
	# des murs opaques. Attrapé par la suite, pas à la lecture.
	super()
	rayon = RAYON
	# Presque opaque : dedans, un corps n'est plus qu'une masse.
	opacite = 0.88
	pv = 2.0


## Du noir de carbone chaud — mais **pas du noir franc**, et c'est une correction.
##
## ⚠️ Le premier jet était à 0,03 de luminance : dans un jeu dont le fond est le
## noir absolu, une masse noire est **indiscernable d'une ombre**. On ne voyait
## pas un nuage, on voyait le faisceau commencer plus loin — ce qui est
## l'information d'un mur, pas celle d'un volume. Constaté en capture, et
## diagnostiqué en peignant la masse en rouge : elle était bien là, elle ne
## disait rien.
##
## Relevée à 0,09, elle reste invisible dans le noir — on ne voit pas de la suie
## sans lumière, et c'est juste — mais **sous une torche elle devient de la
## matière** : un disque gris chaud, distinct d'une ombre portée.
func couleur_masse() -> Color:
	return Color(0.09, 0.085, 0.08, 0.86)
