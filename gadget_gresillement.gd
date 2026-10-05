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
##   • elle éteint les torches **jusqu'au noir absolu**, de façon aléatoire — et, depuis
##     OM3b (Q84, 2026-10-05), elle les tient éteintes le plus souvent : trois quarts du
##     temps au cœur de la zone, au lieu d'un tiers, avec des sursauts de lumière ;
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

## OMBRES, OM3b (Q84, Adrien, 2026-10-05 : « Augmenter l'effet du gadget grésillement pour qu'elle soit plus souvent éteinte,
## et clignote sporadiquement ») — le tirage de chaque créneau, le NOIR d'abord :
##   • NOIR (`PART_NOIR`) : la lampe est morte ;
##   • SURSAUT (`PART_SURSAUT`) : morte aussi, mais elle se rallume un instant (`SURSAUT_MIN` à `SURSAUT_MAX`) — le clignotement
##     sporadique. Seulement après un créneau noir, et il FINIT toujours au même point de son créneau (`_sursaut`) : deux
##     coupures franches sont donc toujours séparées d'un créneau au moins, et la borne pour les yeux tient, à la fenêtre près —
##     jamais plus de trois dans une seconde, quelle qu'elle soit ;
##   • MAUVAIS CONTACT (`PART_MAUVAIS_CONTACT`) : la lampe faiblit, de 45 à 85 % de noir ;
##   • NORMAL (le reste) : elle revient — rarement, mais il le faut, sans quoi on s'y habituerait.
## Avant OM3b : 34 % de noir, 36 % de mauvais contact, 30 % de retour — la lampe morte un tiers du temps.
const PART_NOIR := 0.64
const PART_SURSAUT := 0.18
const PART_MAUVAIS_CONTACT := 0.10
## La durée d'un sursaut, en secondes : assez pour se voir, trop peu pour éclairer une pièce.
const SURSAUT_MIN := 0.06
const SURSAUT_MAX := 0.14
## Le noir qui reste pendant un sursaut : de 0 (la lampe entière) à `SURSAUT_NOIR_MAX`.
const SURSAUT_NOIR_MAX := 0.35

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
	# Le repère du poseur (étape 28) : là où la lampe cesse d'être touchée. Le même
	# allumée ou éteinte — la zone ne bouge pas, seul l'effet s'arrête.
	rayon_repere = RAYON


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
	var t0 := maxf(t, 0.0)
	var k := int(floor(t0 / CRENEAU))
	var dans := t0 - float(k) * CRENEAU
	var courant := _niveau_du_creneau(k)
	var niveau := courant
	if k > 0 and dans < RAMPE:
		niveau = lerpf(_niveau_du_creneau(k - 1), courant, dans / RAMPE)
	# OM3b — le sursaut : la lampe revient un instant au milieu d'un créneau noir, avec ses rampes. Il tient tout entier dans
	# son créneau (`_sursaut` le pose après la rampe d'entrée, et finit une rampe avant le créneau suivant).
	var s := _sursaut(k)
	if s.is_empty():
		return niveau
	var debut: float = s["debut"]
	var fin: float = debut + float(s["duree"])
	var bas: float = s["noir"]
	if dans < debut - RAMPE or dans > fin + RAMPE:
		return niveau
	if dans < debut:
		return lerpf(niveau, bas, (dans - (debut - RAMPE)) / RAMPE)
	if dans <= fin:
		return bas
	return lerpf(bas, niveau, (dans - fin) / RAMPE)


## Le niveau de fond d'un créneau, tiré au sort : le noir (le NOIR et le SURSAUT, dont le fond est noir), le mauvais contact
## qui fait faiblir la lampe, et le retour à la normale — sans lequel on s'y habituerait. Voir `PART_NOIR`.
func _niveau_du_creneau(k: int) -> float:
	var r := _hasard(k, 0)
	if r < PART_NOIR + PART_SURSAUT:
		return 1.0
	if r < PART_NOIR + PART_SURSAUT + PART_MAUVAIS_CONTACT:
		return 0.45 + 0.40 * _hasard(k, 1)
	return 0.0


## OM3b — le sursaut du créneau `k` (`debut` et `duree` en secondes dans le créneau, `noir` pendant), ou rien. Seulement dans un
## créneau tiré SURSAUT qui suit un créneau au fond noir : sans coupure à son entrée, son retour et sa coupure sont la seule
## paire du créneau. Après un créneau éclairé, le tirage SURSAUT reste un créneau noir, sans sursaut.
##
## ⚠️ **Il finit toujours au même point du créneau** (`CRENEAU - 2 × RAMPE`) : seuls son DÉBUT et sa durée sont tirés. Une fin
## tirée au sort aussi laissait deux sursauts de créneaux voisins couper à 0,15 s l'un de l'autre — quatre coupures franches
## dans une même seconde au pire, au-delà de la borne pour les yeux (mesuré sur douze graines, dix minutes chacune, avant de
## l'écrire). Fin fixe : deux coupures sont toujours séparées d'un créneau au moins (0,34 s), donc jamais plus de trois dans une
## seconde, quelle que soit la seconde.
func _sursaut(k: int) -> Dictionary:
	var r := _hasard(k, 0)
	if r < PART_NOIR or r >= PART_NOIR + PART_SURSAUT:
		return {}
	if k <= 0 or _niveau_du_creneau(k - 1) < 1.0:
		return {}
	var duree := lerpf(SURSAUT_MIN, SURSAUT_MAX, _hasard(k, 2))
	var fin := CRENEAU - 2.0 * RAMPE
	return {"debut": fin - duree, "duree": duree, "noir": SURSAUT_NOIR_MAX * _hasard(k, 4)}


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
