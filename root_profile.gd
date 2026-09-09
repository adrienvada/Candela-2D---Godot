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
## La rampe vit **dans** la durée du root, pas après : un root de 0,10 s dure
## 0,10 s. Sans quoi les durées annoncées mentiraient toutes.
##
## ⚠️ **Et elle est PROPORTIONNELLE à cette durée, plafonnée à 80 ms.** Le
## premier jet la fixait à 80 ms pour tout le monde ; mesuré au banc sur le vrai
## joueur, le Parasite gardait alors **66 % de sa vitesse** après un tir : ses
## 100 ms de root étaient 20 ms d'arrêt et 80 ms de reprise. Adrien l'a dit d'un
## mot le 2026-09-09 — « quand on tire, on soit immobile, ça marche pas ».
##
## Une constante partagée entre des durées qui vont de 1 à 7,5 ne peut pas
## vouloir dire la même chose aux deux bouts : sur l'arbalète elle est un détail,
## sur le pistolet elle EST le root. La part, elle, dit la même chose partout —
## et elle a le bon effet de bord : la rampe pèse là où l'arrêt est long et
## visible, elle s'efface là où il est trop court pour qu'on voie quoi que ce
## soit.

## Durée totale de l'immobilisation, en secondes, rampe comprise.
@export var duree: float = 0.0

## L'immobilisation court-elle depuis la fin de la RAFALE au lieu de chaque coup ?
##
## Vrai pour l'Occulteur seul, dont la spécification dit « root durée rafale
## + 0,15 s » : son pistolet-mitrailleur ne peut pas s'immobiliser huit fois de
## suite, il s'immobilise une fois, à la fin.
@export var apres_rafale: bool = false

## Le PLAFOND de la rampe de reprise, en secondes. Non exportée : c'est une
## propriété du GESTE, la même pour toutes les classes. La rendre réglable
## inviterait à la doser par classe, et dix rampes différentes ne se
## distingueraient pas à l'œil tout en rendant chaque root incomparable.
##
## Ce n'est plus la rampe elle-même depuis le 2026-09-09, seulement sa borne
## haute : au-delà de 80 ms, une reprise cesse d'être un raccord et devient un
## ralenti qu'on lit comme une panne.
const RECUPERATION := 0.08

## La part de la durée du root passée à reprendre la vitesse.
##
## Un quart : il en reste trois pour l'arrêt franc, quelle que soit la classe.
## C'est ce rapport, et non une durée, qui fait qu'un root de 0,08 s et un root
## de 0,60 s **se sentent pareil** — l'un et l'autre immobilisent pendant les
## trois quarts de ce qu'ils annoncent.
const PART_RAMPE := 0.25


## La rampe effective, en secondes, pour un root de cette durée.
static func rampe_pour(duree_root: float) -> float:
	return minf(RECUPERATION, maxf(0.0, duree_root) * PART_RAMPE)

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
## Rend 0 pendant l'arrêt franc, puis remonte linéairement vers 1 sur la rampe.
## Hors root, rend 1 — donc l'appelant peut multiplier sans condition.
##
## ⚠️ **Il faut la durée TOTALE en plus du restant**, et c'est ce que la
## signature impose : la rampe se déduit de la première, le point où l'on en est
## de la seconde. Un appelant qui n'aurait que le compteur ne pourrait pas dire
## si 30 ms restants sont la fin d'un root de pistolet ou le milieu d'un root
## d'arbalète — deux facteurs différents.
##
## ⚠️ **Rend 1,0 pour un `restant` négatif ou nul**, jamais autre chose : un
## compteur qui a dépassé zéro ne doit pas se mettre à accélérer le joueur.
static func facteur(restant: float, duree_root: float) -> float:
	if restant <= 0.0:
		return 1.0
	var rampe := rampe_pour(duree_root)
	if restant >= rampe:
		return 0.0
	return 1.0 - restant / rampe


## Le seuil en dessous duquel l'écran ne peut rien montrer, à 60 Hz.
const DEUX_IMAGES := 2.0 / 60.0


## Le root est-il assez court pour être imperceptible ?
##
## ⚠️ **Le critère a changé de nature le 2026-09-09**, en même temps que la
## rampe. Il disait « le root tient entièrement dans la rampe », ce qui n'arrive
## plus jamais depuis qu'elle est proportionnelle : il reste toujours trois
## quarts d'arrêt franc. Il dit maintenant la seule chose qui vaille encore —
## **cet arrêt tient-il en moins de deux images ?** En dessous, l'écran ne peut
## rien montrer, quoi qu'annonce la fiche de classe.
func est_imperceptible() -> bool:
	return duree_arret_franc() <= DEUX_IMAGES


## La part de la durée passée à l'arrêt complet, en secondes.
func duree_arret_franc() -> float:
	return maxf(0.0, duree - rampe_pour(duree))
