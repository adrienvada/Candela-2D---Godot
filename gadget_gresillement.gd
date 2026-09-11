class_name GadgetGresillement
extends GadgetBase

## Le grésillement — gadget du Parasite, chantier CLASSES, étapes 16 et 24.
##
## ## Une bobine qu'on allume et qu'on éteint
##
## *« Un grésillement qui fait douter d'une lumière qui marche encore. »* Une petite
## bobine posée au sol, qui fait sauter les lampes torches autour d'elle.
##
## Depuis le 2026-09-10 — décisions d'Adrien, après un essai en entraînement :
##
##   • elle est **activable et désactivable** : la touche du gadget l'allume et
##     l'éteint où qu'elle soit, tant qu'elle tient debout ;
##   • elle tire sur une **batterie** qui appartient au JOUEUR, pas à la bobine.
##     Elle se vide en `DUREE_ACTIVE_MAX` secondes allumée, se remplit en
##     `RECHARGE_BATTERIE` éteinte, et se rallume dès qu'il reste
##     `SEUIL_RALLUMAGE`. C'est ce qui donne un sens à l'interrupteur : de courtes
##     rafales au moment où l'adversaire entre, plutôt qu'une zone allumée toute
##     la manche ;
##   • elle éteint les torches **jusqu'au noir absolu**, de façon aléatoire ;
##   • et une torche qu'elle a éteinte **n'éblouit plus**.
##
## ## Elle entre dans la SIMULATION, et c'est une décision
##
## ⚠️ **Jusqu'au 2026-09-10, le grésillement ne touchait que le rendu** : il baissait
## `flashlight.energy` sans rien changer à l'éblouissement, qui échantillonne le
## cookie. Tant que la lampe gardait 22 %, c'était défendable — elle éclairait
## encore, elle éblouissait encore. Dès qu'elle peut devenir NOIRE, l'ignorer
## ferait aveugler l'adversaire par une lampe qu'il voit éteinte, ce que ce jeu
## refuse partout ailleurs : on ne peut pas être aveuglé par ce qu'on ne voit pas.
##
## L'éblouissement est calculé chez l'hôte et répliqué (`net_dazzle`) : c'est donc
## `GameState._lumiere_recue()`, chez l'hôte, qui multiplie la lumière d'une torche
## par ce même facteur. Le client ne recalcule rien.
##
## ## L'aléa est une FONCTION, pas un tirage
##
## ⚠️ « Aléatoire » ne veut pas dire `randf()`. Deux pairs qui tireraient chacun
## leurs dés verraient deux pannes différentes, et l'hôte déciderait de
## l'éblouissement sur une panne que le client n'a jamais vue. La forme d'onde est
## une fonction pure de la GRAINE — tirée par l'hôte, portée par
## `rpc_spawn_gadget` — et du temps passé allumée : identique chez les deux pairs à
## un demi-aller-retour près, et indépendante de la cadence.
##
## ⚠️ **Et elle est bornée pour les yeux.** Une coupure franche au plus par créneau
## de `CRENEAU` secondes, soit moins de trois par seconde, en deçà de la bande que
## les recommandations d'accessibilité proscrivent pour les éclats. L'onde
## précédente redressait des sinusoïdes rapides : poussée jusqu'au noir, elle
## aurait coupé la lampe plus de cinq fois par seconde.
##
## ## Il ne connaît personne, poseur compris
##
## Le Parasite qui traverse sa propre zone allumée y perd sa lampe comme tout le
## monde — la règle des choses posées, écrite pour la fusée, la mine et les braises.

## Le rayon d'action, en pixels. Large : c'est une zone qu'on rend inhospitalière,
## pas un piège de contact.
const RAYON := 240.0

## La batterie se vide en 14 s allumée et se remplit en 60 s éteinte.
const DUREE_ACTIVE_MAX := 14.0
const RECHARGE_BATTERIE := 60.0

## Ce qu'il faut de batterie pour rallumer. Pas zéro : une bobine rallumée sur un
## fil de charge s'éteindrait à l'image suivante, un clignotement d'interface que
## personne n'a demandé.
const SEUIL_RALLUMAGE := 0.05

## La durée d'un créneau de l'onde, en secondes. Une coupure franche au plus par
## créneau : 1 / 0,34, soit 2,9 par seconde au maximum.
const CRENEAU := 0.34

## La rampe entre deux niveaux : un changement n'est jamais une marche d'escalier,
## ce qui adoucit l'éclat sans rien retirer au noir.
const RAMPE := 0.03

## Allumée ou éteinte. Posé par `GameState` chez les deux pairs, jamais d'ici.
var actif: bool = false

## La graine de l'onde, tirée par l'hôte.
var graine: int = 0

## Le temps passé allumée, cumulé d'un allumage à l'autre : l'onde reprend où elle
## s'était arrêtée, au lieu de rejouer la même panne à chaque rallumage.
var _temps_actif: float = 0.0


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


## La touche du gadget allume et éteint la bobine, tant qu'elle tient debout.
func est_basculable() -> bool:
	return true


func _physics_process(delta: float) -> void:
	super(delta)
	if actif:
		_temps_actif += delta


## Ce par quoi multiplier une lampe torche à cette position : 1 hors de portée ou
## bobine éteinte — exactement, pas « presque » —, jusqu'à 0 au cœur de la zone.
func facteur_de_lampe(pos: Vector2) -> float:
	if not actif:
		return 1.0
	var d := pos.distance_to(global_position)
	if d >= RAYON:
		return 1.0
	# Décroissance douce vers le bord : une frontière franche apprendrait au joueur
	# où s'arrête la zone, ce qui la rendrait contournable au pixel.
	var force := 1.0 - smoothstep(0.45, 1.0, d / RAYON)
	if force <= 0.0:
		return 1.0
	return 1.0 - force * niveau_noir(_temps_actif)


## Le niveau de panne, entre 0 (lampe intacte) et 1 (noir absolu) : une fonction
## pure de la graine et du temps, rien d'autre.
func niveau_noir(t: float) -> float:
	var k := int(floor(maxf(t, 0.0) / CRENEAU))
	var courant := _niveau_du_creneau(k)
	var dans := t - float(k) * CRENEAU
	if k <= 0 or dans >= RAMPE:
		return courant
	return lerpf(_niveau_du_creneau(k - 1), courant, dans / RAMPE)


## Trois états, tirés au sort par créneau : la coupure franche, le mauvais contact
## qui fait faiblir la lampe, et le retour à la normale — sans lequel on s'y
## habituerait en trois secondes.
func _niveau_du_creneau(k: int) -> float:
	var r := _hasard(k, 0)
	if r < 0.34:
		return 1.0
	if r < 0.70:
		return 0.45 + 0.40 * _hasard(k, 1)
	return 0.0


## Un nombre de [0, 1[ déterminé par la graine, le créneau et un sel.
##
## ⚠️ **Un mélange entier explicite, pas `hash()`.** `hash()` n'est pas garanti
## identique d'une version du moteur à l'autre, ni d'une plateforme à l'autre ; or
## les deux pairs peuvent tourner sur deux systèmes. Les masques à 32 bits gardent
## chaque produit sous 2^60 : aucun débordement, donc aucun comportement laissé au
## compilateur.
func _hasard(k: int, sel: int) -> float:
	var h := _melange((graine & 0xFFFFFFFF) ^ _melange(k * 4 + sel + 0x9E37))
	return float(h) / 4294967296.0


static func _melange(x: int) -> int:
	x = x & 0xFFFFFFFF
	x = x ^ (x >> 16)
	x = (x * 0x45D9F3B) & 0xFFFFFFFF
	x = x ^ (x >> 16)
	x = (x * 0x45D9F3B) & 0xFFFFFFFF
	x = x ^ (x >> 16)
	return x


## Une bobine et deux électrodes. Volontairement minuscule et sombre : ce qu'on
## doit remarquer est la panne, pas l'appareil. L'état allumé/éteint se lit au HUD
## de son poseur, jamais sur l'objet — l'adversaire n'a pas à savoir qu'elle est
## armée avant de l'éprouver.
func _monter_visuel() -> void:
	# Son image, éclairée par le décor : sous une torche seulement.
	_poser_sprite("Visuel", "gresillement")
