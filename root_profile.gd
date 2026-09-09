class_name RootProfile
extends Resource

## L'immobilisation qui suit un tir — chantier CLASSES, étape 1.
##
## ## Ce fichier est SANS DÉPENDANCE, et c'est une contrainte, pas un style
##
## Ni autoload, ni nœud, ni `preload` d'un fichier qui en nomme un. C'est la
## condition pour qu'une suite le charge en `--script` : le jour où
## `fusee_modele.gd` a nommé un autoload, `test_fusee` a cessé de compiler
## (piège du 2026-09-01). Les trois profils de classe suivent la même règle.
##
## ## Ce que le root est, et ce qu'il n'est pas
##
## Le joueur qui tire **cesse d'avancer**, pendant une durée qui dépend de son
## arme. Ce n'est pas un recul (rien ne le pousse), ce n'est pas un
## ralentissement (il ne va pas plus lentement, il ne va pas) : c'est une
## fenêtre pendant laquelle tirer coûte sa mobilité.
##
## ⚠️ **L'orientation et la torche ne sont PAS touchées.** `rotation` dit où le
## joueur vise, et c'est l'information la plus chère du jeu ; l'immobiliser
## reviendrait à le rendre aveugle en plus d'immobile, ce que personne n'a
## demandé. Le root coupe la vélocité, rien d'autre.
##
## ## Pourquoi le retour est une rampe et non une marche
##
## `player.gd` a déjà payé cette leçon sur le roulis de marche : « revenir au
## statique dès l'immobilisation ferait un saut visible ». Un root qui rendrait
## la vitesse d'un coup produirait la même secousse, à l'instant précis où le
## joueur reprend la main — c'est-à-dire là où elle se sent le plus.
##
## La rampe est courte (80 ms) et vit **dans** la durée du root, pas après :
## un root de 0,10 s est donc 20 ms d'arrêt franc puis 80 ms de reprise, et non
## 180 ms au total. Sans quoi les durées annoncées mentiraient toutes.

## Durée totale de l'immobilisation, en secondes, rampe comprise.
@export var duree: float = 0.0

## L'immobilisation court-elle depuis la fin de la RAFALE au lieu de chaque coup ?
##
## Vrai pour l'Occulteur seul, dont la spécification dit « root durée rafale
## + 0,15 s » : son pistolet-mitrailleur ne peut pas s'immobiliser huit fois de
## suite, il s'immobilise une fois, à la fin.
@export var apres_rafale: bool = false

## La rampe de reprise, en secondes. Constante et non exportée : c'est une
## propriété du GESTE, la même pour toutes les classes. La rendre réglable
## inviterait à la doser par classe, et dix rampes différentes ne se
## distingueraient pas à l'œil tout en rendant chaque root incomparable.
const RECUPERATION := 0.08

## Le PLAFOND de l'échelle des roots, en secondes — décision d'Adrien du
## 2026-09-09 : « on garde 0,6 sec pour l'arbalète comme limite haute de temps
## entre deux tirs ».
##
## ⚠️ **C'est une borne de conception, pas un réglage.** Le Braconnier est
## l'extrême haut de la grille et il y reste ; aucune classe ne doit le dépasser,
## sous peine de rendre une arme injouable pour une raison que le joueur ne peut
## pas lire à l'écran. `tools/test_classes.gd` le vérifie sur les dix.
const PLAFOND := 0.60


## Le facteur à appliquer à la vitesse, selon ce qu'il reste de root.
##
## Rend 0 pendant l'arrêt franc, puis remonte linéairement vers 1 sur les
## dernières `RECUPERATION` secondes. Hors root, rend 1 — donc l'appelant peut
## multiplier sans condition.
##
## ⚠️ **Rend 1,0 pour un `restant` négatif ou nul**, jamais autre chose : un
## compteur qui a dépassé zéro ne doit pas se mettre à accélérer le joueur.
static func facteur(restant: float) -> float:
	if restant <= 0.0:
		return 1.0
	if restant >= RECUPERATION:
		return 0.0
	return 1.0 - restant / RECUPERATION


## Le root est-il assez court pour être imperceptible ?
##
## Sert au banc et aux contrôles : en dessous de la rampe, il n'y a pas d'arrêt
## franc du tout, seulement une reprise. Le Spectre (0,08 s) est exactement à
## cette limite, et c'est délibéré — sa classe ne doit pas *sentir* le root.
func est_imperceptible() -> bool:
	return duree <= RECUPERATION


## La part de la durée passée à l'arrêt complet, en secondes.
func duree_arret_franc() -> float:
	return maxf(0.0, duree - RECUPERATION)
