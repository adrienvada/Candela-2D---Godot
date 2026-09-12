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


## Son image : un nuage de suie peint, à sa taille — 184 px, deux fois `RAYON`.
##
## ⚠️ **La leçon du « noir franc » vaut pour l'image.** La masse dessinée avait
## d'abord été peinte à 0,03 de luminance : sur un fond noir absolu, elle était
## indiscernable d'une ombre, et l'on voyait le faisceau commencer plus loin —
## l'information d'un mur, pas celle d'un volume. L'image est peinte à 0,19 en
## moyenne : invisible sans lumière, de la matière sous une torche.
func piece_sprite() -> String:
	return "cartouche_suie"
