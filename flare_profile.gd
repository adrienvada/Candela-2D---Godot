class_name FlareProfile
extends Resource

## La réserve de fusées éclairantes d'une classe — chantier CLASSES, étape 1.
##
## ## Sans dépendance, et surtout PAS vers `FuseeModele`
##
## Ce fichier ne nomme ni autoload ni `fusee_modele.gd`. La tentation serait
## d'hériter de `STOCK_PAR_MANCHE` pour « rester cohérent » ; ce serait remettre
## une dépendance dans le seul endroit qui n'en a pas, et `test_fusee` cesserait
## de compiler en `--script` (piège du 2026-09-01).
##
## **La division du travail est celle-ci** : `FuseeModele` dit ce qu'une fusée
## FAIT une fois lancée — vol, combustion, fumée, extinction. `FlareProfile` dit
## combien on en a et à quel rythme elles reviennent. Aucun des deux n'a besoin
## de l'autre.
##
## ⚠️ **Les valeurs de `FuseeModele` sont des décisions actées depuis le
## 2026-09-09** (FU6, tranchée par Adrien manette en main). Une variante de
## classe qui en dévierait n'est pas un réglage : c'est un écart à soumettre.
##
## ## La recharge est AUTORITAIRE, et ce n'est pas une précaution de style
##
## `rpc_spawn_fusee` est `call_local` : l'hôte exécute *aussi*, pas *en même
## temps* — le client reçoit le paquet un demi-RTT plus tard. Deux accumulateurs
## locaux dériveraient donc de RTT/2 **à chaque consommation**. Inoffensif tant
## que le stock vaut 1 et qu'on ne peut pas relancer ; mordant dès qu'il en vaut
## trois. Ce fichier ne calcule donc que de l'arithmétique pure : c'est l'hôte
## qui l'appelle, et lui seul.

## Nombre de fusées au début de la manche. Zéro est une valeur légitime — le
## Spectre n'éclaire jamais, c'est sa classe.
@export var stock: int = 1

## Secondes pour regagner une fusée. **Zéro veut dire « aucune recharge »**, ce
## qui est le comportement historique du jeu et reste celui de la plupart des
## classes. Ne jamais lire ce champ sans passer par `recharge_active()`.
@export var periode_recharge: float = 0.0

## Plafond de la réserve rechargée. Vaut `stock` par défaut : on ne dépasse pas
## ce avec quoi on est parti, sauf décision explicite.
@export var plafond: int = -1


## La recharge tourne-t-elle pour cette classe ?
func recharge_active() -> bool:
	return periode_recharge > 0.0 and plafond_effectif() > 0


## Le plafond réellement appliqué : `plafond` s'il est posé, `stock` sinon.
func plafond_effectif() -> int:
	return plafond if plafond >= 0 else stock


## Fait avancer la recharge de `delta` secondes.
##
## Rend `[nouveau_stock, nouvel_accumulateur]`. L'accumulateur est le temps déjà
## capitalisé vers la prochaine fusée ; il est **conservé** entre les recharges,
## sinon un joueur qui consomme au mauvais moment perdrait une fraction de
## progression sans comprendre pourquoi.
##
## ⚠️ **Rend le stock inchangé et l'accumulateur à zéro quand la réserve est
## pleine.** Laisser l'accumulateur courir à plein stock offrirait une fusée
## instantanée au premier tir suivant — une réserve cachée, invisible à l'écran,
## donc exactement le genre d'avantage que ce jeu refuse.
func avancer(stock_courant: int, accumulateur: float, delta: float) -> Array:
	if not recharge_active():
		return [stock_courant, 0.0]
	var plaf := plafond_effectif()
	if stock_courant >= plaf:
		return [stock_courant, 0.0]

	var acc := accumulateur + maxf(0.0, delta)
	var gagnees := int(floor(acc / periode_recharge))
	if gagnees <= 0:
		return [stock_courant, acc]

	var neuf: int = mini(plaf, stock_courant + gagnees)
	# Ce qui reste après les fusées effectivement gagnées. Si le plafond a
	# écrêté, on ne garde rien : capitaliser du temps contre un plafond serait
	# la même réserve cachée qu'au-dessus.
	if neuf >= plaf:
		return [neuf, 0.0]
	return [neuf, acc - float(gagnees) * periode_recharge]


## Secondes restantes avant la prochaine fusée, ou -1 s'il n'y en aura pas.
## Le HUD en a besoin pour dire au joueur ce qu'il attend.
func attente_restante(stock_courant: int, accumulateur: float) -> float:
	if not recharge_active() or stock_courant >= plafond_effectif():
		return -1.0
	return maxf(0.0, periode_recharge - accumulateur)
