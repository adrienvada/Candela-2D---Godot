## Échelle — combien de mètres fait ce que le jeu mesure en pixels.
##
## **Le jeu n'avait aucune échelle, et il en affichait une.** DA4.7 montre
## « EFFLEURÉ — 13 PX » en fin de match, DA4.6 cotait la trajectoire fatale en
## pixels : deux nombres exacts, et **aucun joueur ne sait ce que vaut un
## pixel**. « Il m'a eu à 340 px » ne se raconte pas, ne se compare pas d'une
## partie à l'autre, et ne veut rien dire hors de l'écran où il s'affiche.
##
## ## L'ancre est le joueur, décidée par Adrien le 2026-08-27
##
## *« L'échelle qu'on a c'est la taille du sprite d'un joueur. »* C'est la seule
## chose du jeu dont on connaisse la taille réelle : un adulte vu de dessus.
##
## `player.gd` pose son rayon à **18 px** — le chiffre est écrit noir sur blanc
## dans sa silhouette (« 18.0 is exactly the player radius »). Le joueur fait
## donc **36 px** de large, et un adulte debout vu du dessus occupe la largeur de
## ses épaules, **un demi-mètre**.
##
## ⚠️ **C'est un jugé, et il est assumé comme tel.** Aucune mesure ne peut sortir
## d'un dessin ; ce qu'on choisit ici, c'est une convention. Ce qui compte n'est
## pas qu'elle soit vraie au centimètre mais qu'elle soit **unique** — deux
## conversions différentes dans deux écrans donneraient deux distances pour le
## même tir, et c'est ça qui serait faux.
##
## ## Ce que la convention rend, en vérification
##
## Une tuile fait 35 px, soit **48 cm** : une case de sol est donc large comme un
## joueur, ce qui est exactement ce qu'on lit à l'écran. Une carte de 32×32 fait
## **15,5 m de côté** — une grande salle, l'ordre de grandeur d'un duel au
## pistolet dans le noir. Et la portée du pompe (180 px) tombe à **2,5 m** :
## très court, mais c'est un choix de jeu délibéré et non un artefact de
## l'échelle — il faut être sur l'adversaire pour que le pompe tue.
##
## Ces trois nombres n'ont pas servi à CHOISIR l'échelle, ils servent à la
## réfuter : une convention qui aurait rendu une carte de 3 m ou une portée de
## 60 m aurait été rejetée. Aucun ne l'a été.

class_name Echelle
extends RefCounted

## Le rayon du joueur, en pixels. Repris de `player.gd`, où il est écrit deux
## fois — dans la silhouette et dans le test d'impact de `bullet.gd`.
const JOUEUR_RAYON_PX := 18.0

## La largeur d'épaules d'un adulte, en mètres. Le seul nombre de ce fichier qui
## vienne du monde réel.
const EPAULES_M := 0.5

## ⚠️ **Dérivée, jamais posée.** Écrire `72.0` ici marcherait et perdrait le
## raisonnement : personne ne pourrait plus dire d'où vient l'échelle, ni la
## corriger en changeant le seul nombre qui se discute (`EPAULES_M`).
const PX_PAR_METRE := (JOUEUR_RAYON_PX * 2.0) / EPAULES_M


## Une distance en pixels, rendue en mètres.
static func metres(px: float) -> float:
	return px / PX_PAR_METRE


## Une distance en pixels, écrite pour un joueur.
##
## ⚠️ **Une décimale sous dix mètres, aucune au-delà**, et ce n'est pas une
## coquetterie : « 3,4 M » et « 12 M » portent la même information utile, mais
## « 12,4 M » demande de lire un chiffre de plus pour une précision dont personne
## ne fait rien. La règle vaut aussi pour la cote de killcam, qui est lue en un
## quart de seconde au milieu d'un ralenti.
##
## Sous le mètre on passe au centimètre : « 0,3 M » se lit mal, « 30 CM » se lit.
## C'est le cas de l'effleurement de DA4.7, qui vaut quelques dizaines de pixels.
static func ecrire(px: float) -> String:
	var m := metres(px)
	if m < 1.0:
		return "%d CM" % int(roundf(m * 100.0))
	if m < 10.0:
		# La virgule, pas le point : le jeu est en français.
		return ("%.1f M" % m).replace(".", ",")
	return "%d M" % int(roundf(m))
