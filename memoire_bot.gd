class_name MemoireBot
extends RefCounted

## La mémoire d'un bot : sa dernière position connue de la cible — chantier SOLO, étape S2.
##
## Une seule trace, jamais l'historique : ce que le bot sait de l'adversaire, c'est où il l'a vu ou entendu en dernier,
## quand, avec quelle précision. Ce qu'il en FAIT (aller y voir, s'y préparer) est l'affaire de S3.
##
## Pur, sans nœud ni autoload : le temps est un argument (`maintenant`, en secondes), jamais l'horloge du moteur — une
## suite le rejoue à la seconde près, et le jeu lui donne le temps de SA physique (le bot s'arrête avec elle).
##
## ## Vue ou ouïe
##
##   • **VUE** : la place du corps (précise : `rayon` nul) ; elle remplace toujours ce qu'on savait — le meilleur des
##     renseignements ;
##   • **OUÏE** : une zone (centre et rayon, voir `PerceptionBot.ecouter`) ; elle ne remplace la trace que si elle n'est
##     pas plus VAGUE que ce que la trace vaut maintenant. Un pas lointain (cent pixels de zone) n'efface pas un tir
##     qu'on vient de situer à vingt, et efface la trace de la veille.
##
## ## Elle s'efface
##
## La CONFIANCE décroît linéairement de 1 (à l'instant de la trace) à 0 (`delai_oubli` plus tard), puis la trace est
## oubliée. Le rayon de la zone, lui, GRANDIT avec l'âge de la trace (`CROISSANCE_PX_S`) : l'adversaire a pu bouger.

enum Source { AUCUNE, OUIE, VUE }

## De combien le rayon d'une trace grandit par seconde, en pixels : *départ*, de l'ordre du tiers de la vitesse de marche
## d'un joueur (260 px/s) — l'adversaire s'éloigne rarement en ligne droite. S4 le tranchera.
const CROISSANCE_PX_S := 60.0

var source: int = Source.AUCUNE
## Le centre de la dernière trace.
var position := Vector2.ZERO
## Le rayon de la trace à l'instant où elle a été prise : 0 pour une vue, la zone de l'oreille sinon.
var rayon := 0.0
## L'instant de la trace, en secondes ; `-INF` sans trace.
var instant := -INF
## La durée de l'oubli, en secondes : `ProfilBot.delai_oubli`.
var delai_oubli := 6.0


func _init(delai: float = 6.0) -> void:
	delai_oubli = maxf(delai, 0.01)


## Une vue : le centre du corps, précis. Remplace toujours la trace.
func noter_vue(pos: Vector2, maintenant: float) -> void:
	source = Source.VUE
	position = pos
	rayon = 0.0
	instant = maintenant


## Un son : une zone. Elle remplace la trace si elle est au plus aussi vague que la trace l'est à cet instant.
func noter_son(centre: Vector2, rayon_zone: float, maintenant: float) -> void:
	if source != Source.AUCUNE and confiance(maintenant) > 0.0 and rayon_zone > rayon_a(maintenant):
		return
	source = Source.OUIE
	position = centre
	rayon = rayon_zone
	instant = maintenant


## L'âge de la trace, en secondes ; `INF` sans trace.
func age(maintenant: float) -> float:
	if source == Source.AUCUNE:
		return INF
	return maxf(maintenant - instant, 0.0)


## La confiance dans la trace, de 1 (à l'instant) à 0 (oubliée) : linéaire sur `delai_oubli`.
func confiance(maintenant: float) -> float:
	if source == Source.AUCUNE:
		return 0.0
	return clampf(1.0 - age(maintenant) / delai_oubli, 0.0, 1.0)


## Le rayon de la trace à cet instant : celui du départ, plus ce que l'adversaire a pu parcourir depuis.
func rayon_a(maintenant: float) -> float:
	if source == Source.AUCUNE:
		return INF
	return rayon + CROISSANCE_PX_S * age(maintenant)


## Le bot se souvient-il encore de quelque chose ?
func connue(maintenant: float) -> bool:
	return confiance(maintenant) > 0.0


## Oublie tout — à la mort, à la réapparition, au changement de manche.
func oublier() -> void:
	source = Source.AUCUNE
	position = Vector2.ZERO
	rayon = 0.0
	instant = -INF
