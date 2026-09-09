class_name GadgetBase
extends StaticBody2D

## Le socle commun des gadgets de classe — chantier CLASSES, étape 5.
##
## ## Ce n'est pas une invention, c'est `training_target.gd` généralisé
##
## La cible d'échauffement fait déjà exactement ça : un `StaticBody2D` posé dans
## le monde, une forme de collision, un `LightOccluder2D` pour ne pas être un
## trou de lumière, et un visuel éclairé comme le décor. Le patron est repris tel
## quel ; ce qui s'y ajoute est ce qu'un gadget a de plus — des points de vie,
## une durée de vie, un poseur, et un drapeau d'éblouissement.
##
## ## Le nom du nœud est EXPLICITE, et ce n'est pas du rangement
##
## `Gadget_P1` / `Gadget_P2`, jamais un nom auto-généré. Un RPC de scène se route
## par le chemin du nœud ; un `@StaticBody2D@412` dépend de tout ce qui a été
## instancié avant, diverge donc entre machines, et **les RPC sont alors jetés
## sans aucune erreur console**. Le dépôt a payé trois manches d'instrumentation
## pour trouver ce défaut une première fois ; la règle est dans `CLAUDE.md`.
##
## ## La couche physique, et pourquoi un gadget n'est pas un mur
##
## `MapGeometry.GADGET_LAYER`, jamais `WALL_LAYER`. Sur la couche des murs, un
## gadget bloquerait les joueurs autant que les balles — et le voile du Spectre,
## dont toute l'idée est « elle arrête la lumière, les balles la traversent »,
## serait devenu un mur ordinaire. Les joueurs traversent parce que leur masque
## ne contient pas cette couche ; ce qui arrête ou non une BALLE est un drapeau,
## `arrete_les_balles`, décidé gadget par gadget.

## Le joueur qui l'a posé — 0 ou 1. Sert à savoir qui subit quoi, et à la grâce
## du poseur si Adrien la demande un jour.
var poseur_id: int = -1

## Points de vie. Tout gadget est destructible à la balle : c'est le contrat
## commun, et c'est ce qui donne une réponse à « j'ai vu quelque chose bouger ».
var pv: float = 1.0

## Ce gadget arrête-t-il les balles, ou se contente-t-il d'encaisser ?
##
## ⚠️ **Les deux existent, et la distinction est de conception.** Une mine ou un
## projecteur sont des objets durs : la balle s'y arrête. Un voile est une bâche
## tendue : la balle la déchire et poursuit. Confondre les deux ferait du voile
## un mur, c'est-à-dire l'inverse de ce qu'il raconte.
var arrete_les_balles: bool = true

## Ce gadget peut-il éblouir ? Recopié du profil de classe à la construction —
## par INSTANCE, jamais par type (décision d'Adrien, 2026-09-09) : on doit
## pouvoir éteindre l'éblouissement d'un gadget sans toucher aux autres.
var eblouit: bool = false

## Secondes de vie, ou 0 pour « jusqu'à la fin de la manche ».
var duree_vie: float = 0.0

## Rayon de la forme de collision, en pixels. Les sous-classes le règlent avant
## `_ready()`.
var rayon: float = 12.0

## L'angle du gadget posé, RELATIF à la direction de visée du poseur.
##
## Un quart de tour par défaut : on plante l'objet **en travers** de son regard,
## pas dans son axe. C'est ce qui compte pour les deux gadgets de la famille A —
## une bâche dans l'axe du regard ne masque rien, et une plaque vue par la
## tranche ne projette pas de torse.
##
## ⚠️ **Une variable et non une constante** : les gadgets à symétrie de
## révolution qui viendront — mine, nappe de braises — la mettront à zéro, et
## une constante ne se surcharge pas.
var angle_pose: float = PI / 2.0

## À quelle distance du poseur le gadget se plante, en pixels.
##
## Devant, jamais sous les pieds : un objet posé à l'endroit exact où l'on se
## tient se confondrait avec le joueur pour toute la durée de la manche — y
## compris dans l'ombre qu'il découpe, qui est précisément l'information que ces
## deux gadgets fabriquent.
##
## ⚠️ **96 px, et la première valeur était 44.** Vérifié en capture, torche
## allumée : à 44 px le voile coupe le faisceau au ras du canon — le poseur
## s'aveugle lui-même et l'objet n'est plus un écran, c'est un mur qu'on se
## prend. À 96, soit une longueur et demie de corps, la bâche tombe hors du
## premier pas et masque ce qu'il y a DERRIÈRE elle, qui est ce qu'on lui
## demande. Le chiffre est une mesure, pas un goût.
const PORTEE_POSE := 96.0

var _age: float = 0.0

signal detruit(gadget: GadgetBase)


func _ready() -> void:
	add_to_group("gadgets")
	collision_layer = MapGeometry.GADGET_LAYER
	# ⚠️ Masque à ZÉRO : un gadget ne se déplace pas, il n'a personne à heurter.
	# Lui donner un masque le ferait participer aux résolutions de collision pour
	# rien, à chaque image, sur un corps statique.
	collision_mask = 0
	z_index = 4

	var forme := CollisionShape2D.new()
	forme.name = "Forme"
	var cercle := CircleShape2D.new()
	cercle.radius = rayon
	forme.shape = cercle
	add_child(forme)

	_monter_occluder()
	_monter_visuel()


## L'occluder, pour qu'un gadget ne soit pas un trou de lumière au milieu de
## l'arène. Même geste que `training_target.gd`.
##
## ⚠️ Les sous-classes qui veulent une autre FORME d'ombre — le voile est une
## bande, l'ombre habitée une découpe de torse — surchargent cette méthode. C'est
## le seul endroit où la forme de l'ombre se décide, pour qu'il n'y en ait pas
## deux.
func _monter_occluder() -> void:
	var occ := LightOccluder2D.new()
	occ.name = "Occluder"
	var poly := OccluderPolygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var ang := (i / 16.0) * TAU
		pts.append(Vector2(cos(ang), sin(ang)) * rayon)
	poly.polygon = pts
	poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
	occ.occluder = poly
	occ.occluder_light_mask = MapGeometry.WALL_LAYER
	add_child(occ)


## Le visuel. Vide dans le socle : un gadget sans sprite doit se VOIR absent,
## pas se faire remplacer par une forme plausible.
##
## ⚠️ **Aucun bouche-trou ici, et c'est délibéré.** Dessiner un disque de secours
## redonnerait un objet crédible, et un objet crédible se prend pour une
## intention — c'est la règle « câbler, taire, diagnostiquer » du dépôt, la même
## qui fait crier `WeaponData.get_torch_texture()` plutôt que fabriquer un
## dégradé.
##
## Chaque sous-classe décide donc de son visuel, et les deux façons sont
## légitimes tant que le choix est ÉCRIT : charger un sprite et crier s'il manque,
## ou dessiner l'objet quand sa forme finale est de l'ordre du trait — c'est le
## cas du voile et de l'ombre habitée, qui sont des lignes vues de dessus. Ce qui
## reste interdit est le troisième chemin : dessiner *en attendant* un sprite.
func _monter_visuel() -> void:
	pass


func _physics_process(delta: float) -> void:
	if duree_vie <= 0.0:
		return
	_age += delta
	if _age >= duree_vie:
		detruire()


## Encaisse des dégâts. Rend `true` si le gadget en meurt.
##
## L'hôte seul appelle ceci : la destruction est autoritaire, comme tout le
## reste. Le client la voit arriver par la réplication du nœud.
func encaisser(degats: float) -> bool:
	pv -= degats
	if pv > 0.0:
		return false
	detruire()
	return true


func detruire() -> void:
	detruit.emit(self)
	queue_free()


## L'âge du gadget, en secondes. Public parce que les sous-classes en dérivent
## leur apparence — et parce qu'un banc doit pouvoir le forcer.
func age() -> float:
	return _age
