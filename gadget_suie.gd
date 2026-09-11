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
## ⚠️ **Renversé le 2026-09-11 : elle cache aussi la présence.** Adrien : « il
## faudrait qu'on ne me voie pas dans la fumée, non ? Si j'éclaire dans la fumée,
## ça illumine toute la fumée. » Au cœur, l'adversaire ne voit plus ni le corps ni
## son ombre (`masque_le_corps`). Le nuage n'est plus éclairé point par point : il
## s'allume EN ENTIER selon la lumière qu'il reçoit, et une lampe tenue dedans y
## reste (`facteur_de_lampe`). La poussière, elle, garde son rôle : réduire la
## portée, sans rien cacher.
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
	# Presque opaque (0,88) jusqu'au 2026-09-11 : dedans, un corps n'était plus
	# qu'une masse.
	# Opaque au cœur depuis le 2026-09-11 (Adrien : « il faudrait qu'on ne me voie
	# pas dans la fumée ») : on n'y distingue plus personne.
	opacite = 1.0


## Son image : un nuage de suie peint, à sa taille — 184 px, deux fois `RAYON`.
##
## ⚠️ **La leçon du « noir franc » vaut pour l'image.** La masse dessinée avait
## d'abord été peinte à 0,03 de luminance : sur un fond noir absolu, elle était
## indiscernable d'une ombre, et l'on voyait le faisceau commencer plus loin —
## l'information d'un mur, pas celle d'un volume. L'image est peinte à 0,19 en
## moyenne : invisible sans lumière, de la matière sous une torche.
func piece_sprite() -> String:
	return "cartouche_suie"


## La suie masque le corps — voir la note de tête. Pas la poussière.
func masque_le_corps() -> bool:
	return true


## Une lampe tenue DANS la suie y reste : son faisceau n'en ressort pas, sa lumière
## se diffuse dans le nuage, qui s'allume en entier. Même accroche que le
## grésillement : le rendu (`player.gd`) et l'éblouissement (`facteur_de_lampe_a`)
## la suivent tous deux — une lampe étouffée n'éblouit plus personne.
func facteur_de_lampe(pos: Vector2) -> float:
	return 1.0 - occultation_pour(pos)
