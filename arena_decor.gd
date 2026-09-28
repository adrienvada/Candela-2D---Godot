class_name ArenaDecor
extends Node2D

## ArenaDecor — les marques au sol de l'arène (Roman Graphique Brutaliste).
##
## Deux choses, et deux seulement :
## 1. Les bandes de danger en chevrons ambre aux abords du vide (fosses).
## 2. Les pochoirs de travée (« 01 », « 02 », « BAY-A ») près des départs.
##
## ## Ce qui a été RETIRÉ, et pourquoi (2026-09-11, décision d'Adrien)
##
## Ce nœud habillait aussi chaque case de mur en « mobilier lourd » — cerclages,
## rivets, cornières, un fût sur les piliers isolés — et posait une équerre à
## chaque coin de sol. Mesuré par la session « régression de cadence » (sonde à
## rendu forcé, vue unique) : **81 → 3 376 appels de dessin par image** au commit
## qui l'a introduit (`bad6083`, 2026-09-08), ~5 ms de rendu CPU, en trois
## copies dont deux rendues en écran scindé ; masquer ce seul nœud faisait
## remonter la médiane de 80 à 100 et le 1 % bas de 47 à 69. Et depuis les murs
## au trait (`mur_encre.gd`), ces rivets doublaient le contour d'encre sur la
## même surface — deux vocabulaires de mur. Adrien : retirer l'habillage.
##
## ## Ce qui reste est CUIT en une texture par carte
##
## Le reste — chevrons tous les 7 px sur chaque bord de fosse, pochoirs — est
## encore des centaines de primitives. Comme le bandeau LED (`mur_led.gd`), le
## dessin est rendu UNE fois dans un `SubViewport` à la taille de la carte, et
## chaque copie n'affiche plus qu'une texture : un appel de dessin par vue.
## Tant que la cuisson n'est pas finie (deux images), et toujours en headless
## (rien n'est rastérisé, les suites y passent), le dessin direct sert.
##
## Zéro vert dans l'arène : respect strict de charte.gd. Mélange normal (lot 4
## de la refonte) : des marques peintes, pas des sources.

const Charte := preload("res://charte.gd")

const CHEVRON_WIDTH := 6.0
const TILE_SIZE := 35.0

var _map_data: Dictionary = {}
var _danger_edges: Array[Dictionary] = [] # {"start": Vector2, "end": Vector2, "normal": Vector2}
var _stencils: Array[Dictionary] = []     # {"pos": Vector2, "type": String, "rot": float}
## Le rectangle de monde que couvre la cuisson : la carte, plus une case de
## marge de chaque côté (les chevrons d'un bord de carte débordent d'un pas).
var _cadre: Rect2 = Rect2()
## La texture cuite ; `null` tant qu'elle n'est pas prête, et pour toujours en
## headless — `_draw()` dessine alors en direct.
var _cuit: Texture2D = null
## Les deux copies par vue, pour leur pousser la texture une fois cuite.
var _copies: Array[Node2D] = []
var _est_copie := false

## ISO13 — LES POCHOIRS DE L'ILLUSTRATION (`--pochoirs-essai`, éteint par défaut ; ordre de la session cloud, 2026-09-25 08:49) :
## « ZONE n », « DEATHMATCH » peints au sol, comme sur les illustrations (« ARENA » en est retiré le 2026-09-25 : dans
## l'illustration c'est une enseigne murale, pas un pochoir — décision relayée par la session cloud). Posés à la main, carte par carte, sous une
## règle d'équité : chaque pochoir a son jumeau par la symétrie de la carte (miroir gauche-droite, ou demi-tour pour la Croisée),
## ou se pose sur son axe — les deux joueurs lisent le même décor à la même distance. Jamais à moins de trois cases d'un départ,
## toujours sur une plage de sol libre qui contient le mot. Cuits avec le reste du décor : rien de plus à dessiner par image.
## Une peinture SOMBRE : le sol assombri sous la lettre, jamais éclairci — noire dans le noir comme le sol, lisible dans la
## lumière. Une carte absente de la table (cartes des joueurs) n'en porte aucun.
const DRAPEAU_POCHOIRS := "--pochoirs-essai"
## [texte, centre (cases, x puis y ; x,5 = entre deux cases : l'axe d'une carte de largeur paire), rotation en degrés]. L'Usine n'a pas de symétrie exacte (son bloc central est décalé d'une
## case) : traitée en miroir gauche-droite.
const POCHOIRS_ESSAI := {
	"00000002": [["DEATHMATCH", Vector2(11.5, 4.5), 0.0], ["DEATHMATCH", Vector2(11.5, 19.5), 0.0],
		["ZONE 1", Vector2(4, 18), 0.0], ["ZONE 2", Vector2(19, 18), 0.0]],
	"00000001": [["DEATHMATCH", Vector2(15.5, 6), 0.0], ["DEATHMATCH", Vector2(15.5, 26), 0.0],
		["ZONE 1", Vector2(8, 23), 0.0], ["ZONE 2", Vector2(23, 23), 0.0]],
	"map_001": [["DEATHMATCH", Vector2(14.5, 5), 0.0], ["DEATHMATCH", Vector2(14.5, 24), 0.0],
		["ZONE 1", Vector2(8, 22), 0.0], ["ZONE 2", Vector2(21, 22), 0.0]],
	"map_002": [["DEATHMATCH", Vector2(15.5, 4), 0.0], ["DEATHMATCH", Vector2(15.5, 21), 0.0],
		["ZONE 1", Vector2(5, 20), 0.0], ["ZONE 2", Vector2(26, 20), 0.0]],
	"map_003": [["DEATHMATCH", Vector2(14, 4), 0.0], ["DEATHMATCH", Vector2(13, 23), 180.0],
		["ZONE 1", Vector2(5, 11), 0.0], ["ZONE 2", Vector2(22, 16), 180.0]],
	"map_004": [["DEATHMATCH", Vector2(12.5, 4), 0.0], ["DEATHMATCH", Vector2(12.5, 21), 0.0],
		["ZONE 1", Vector2(5, 20), 0.0], ["ZONE 2", Vector2(20, 20), 0.0]],
}
## La taille de fonte : des capitales d'environ 14 pixels du monde (0,4 case), à vérifier sur la planche ; et l'assombrissement
## de la peinture (le sol × 0,55 sous la lettre).
const POCHOIR_TAILLE_FONTE := 20
const POCHOIR_PEINTURE := Color(0.0, 0.0, 0.0, 0.45)
## Les pochoirs posés sur CETTE carte : [texte, centre en pixels du monde, rotation en radians].
var _pochoirs: Array = []


## ISO14 — LE SOL MARQUÉ DES ILLUSTRATIONS (`--sol-marque-essai`, éteint par défaut ; essai de la session cloud « sol
## marqué », 2026-09-28 — manque n° 5 de `docs/iso/cloud/ecart-illustrations/RAPPORT.md`). Il étend les pochoirs : treize
## illustrations montrent un sol jonché et marqué, le jeu un sol nu. Cinq familles, relevées dans les illustrations
## (`docs/iso/cloud/sol-marque/RAPPORT.md`) : des GRAVATS en tas allongé au pied des murs et des piliers, des ÉCLATS épars
## dans les salles, des CHAÎNES au sol, des CADRES et des BANDES de marquage, quelques LETTRES de secteur.
##
## Les règles, les mêmes que pour les pochoirs, et une de plus :
## - **une peinture NOIRE translucide, et rien d'autre** : sur le sol, un mélange normal ne peut qu'assombrir — jamais plus
##   clair que la surface qui la porte, et noire dans le noir. Les gravats des illustrations sont des éclats CLAIRS à ombre
##   noire : on n'en garde que l'ombre ;
## - **l'équité** : une table écrite à la main (la demi-table et son script, `docs/iso/cloud/sol-marque/table.py`) où
##   chaque marque a son jumeau par la symétrie de la carte — même motif (même graine), retourné (`miroir`) pour un miroir,
##   tourné pour un demi-tour. ⚠️ **Et son jumeau par le DEMI-TOUR, même sur une carte en miroir** : à 45° B, J2 regarde
##   depuis le côté opposé, donc ce que J1 voit en p, J2 le voit au demi-tour de p — pas au miroir. Un tas au pied sud
##   d'un pilier a pour jumeau-miroir un autre pied sud, caché derrière son pilier dans la vue de J2 (mesuré à l'écran
##   scindé : 713 pixels assombris dans le cône de J1, 27 dans celui de J2). Les cadres suivent les pochoirs qu'ils
##   encadrent (miroir seulement). Cadres, bandes et lettres sont symétriques par construction : posés sur un axe, ils
##   sont leur propre jumeau ;
## - **la place** : sur le sol libre, à trois cases au moins d'un départ, et à 12 px au moins de tout mur — la face d'un mur
##   iso lit sa lumière 12 px devant elle (`mur_iso.gdshader`, `lire_lumiere`) : une marque plus près changerait la
##   lumière lue par le mur. D'où des tas « au pied » des murs, mais à une demi-case d'eux ;
## - **la lisibilité du duel** : rien qui ressemble à un corps, à une arme, à un gadget posé ni à du sang (aucun rouge,
##   aucune tache ronde) ; ni douille (une douille au sol dit « on a tiré ici » : c'est une information du jeu), ni marquage
##   clair (le « ZONE 4 » blanc serait plus clair que le sol). Ni flèche : une flèche montrerait un chemin.
## Cuites avec le reste du décor : rien de plus à dessiner par image. Une carte absente de la table n'en porte aucune.
const DRAPEAU_SOL_MARQUE := "--sol-marque-essai"
## [famille, centre (cases), angle en degrés, paramètre, graine, miroir]. Le paramètre : la longueur en cases (gravats,
## chaîne, bande), le diamètre en cases (éclats), la taille en cases (cadre), le texte (lettres). `miroir` retourne le
## motif (x → −x, dans son repère) : c'est le jumeau par le miroir gauche-droite d'une marque dessinée au hasard.
const SOL_MARQUE_ESSAI := {
	"00000002": [
		["gravats", Vector2(7.0, 11.5), 90.0, 1.0, 11, false],
		["gravats", Vector2(16.0, 11.5), 270.0, 1.0, 11, true],
		["gravats", Vector2(7.0, 11.5), 90.0, 1.0, 11, true],
		["gravats", Vector2(16.0, 11.5), 270.0, 1.0, 11, false],
		["gravats", Vector2(8.0, 9.5), 90.0, 1.0, 12, false],
		["gravats", Vector2(15.0, 9.5), 270.0, 1.0, 12, true],
		["gravats", Vector2(8.0, 13.5), 90.0, 1.0, 12, true],
		["gravats", Vector2(15.0, 13.5), 270.0, 1.0, 12, false],
		["gravats", Vector2(6.0, 2.0), 0.0, 1.6, 13, false],
		["gravats", Vector2(17.0, 2.0), 0.0, 1.6, 13, true],
		["gravats", Vector2(6.0, 21.0), 180.0, 1.6, 13, true],
		["gravats", Vector2(17.0, 21.0), 180.0, 1.6, 13, false],
		["gravats", Vector2(2.0, 16.0), 90.0, 1.6, 14, false],
		["gravats", Vector2(21.0, 16.0), 270.0, 1.6, 14, true],
		["gravats", Vector2(2.0, 7.0), 90.0, 1.6, 14, true],
		["gravats", Vector2(21.0, 7.0), 270.0, 1.6, 14, false],
		["eclats", Vector2(5.0, 6.0), 0.0, 1.0, 15, false],
		["eclats", Vector2(18.0, 6.0), 0.0, 1.0, 15, true],
		["eclats", Vector2(5.0, 17.0), 180.0, 1.0, 15, true],
		["eclats", Vector2(18.0, 17.0), 180.0, 1.0, 15, false],
		["eclats", Vector2(7.5, 17.5), 0.0, 1.0, 16, false],
		["eclats", Vector2(15.5, 17.5), 0.0, 1.0, 16, true],
		["eclats", Vector2(7.5, 5.5), 180.0, 1.0, 16, true],
		["eclats", Vector2(15.5, 5.5), 180.0, 1.0, 16, false],
		["chaine", Vector2(6.5, 20.5), -8.0, 2.0, 17, false],
		["chaine", Vector2(16.5, 20.5), 8.0, 2.0, 17, true],
		["chaine", Vector2(6.5, 2.5), 188.0, 2.0, 17, true],
		["chaine", Vector2(16.5, 2.5), 172.0, 2.0, 17, false],
		["lettres", Vector2(6.0, 15.5), 0.0, "07", 0, false],
		["lettres", Vector2(17.0, 15.5), 0.0, "07", 0, false],
		["lettres", Vector2(6.0, 7.5), 180.0, "07", 0, false],
		["lettres", Vector2(17.0, 7.5), 180.0, "07", 0, false],
		["cadre", Vector2(11.5, 4.5), 0.0, Vector2(5.2, 1.4), 18, false],
		["cadre", Vector2(11.5, 19.5), 0.0, Vector2(5.2, 1.4), 19, false],
	],
	"00000001": [
		["gravats", Vector2(5.0, 3.0), 0.0, 1.8, 21, false],
		["gravats", Vector2(26.0, 3.0), 0.0, 1.8, 21, true],
		["gravats", Vector2(5.0, 28.0), 180.0, 1.8, 21, true],
		["gravats", Vector2(26.0, 28.0), 180.0, 1.8, 21, false],
		["gravats", Vector2(11.0, 3.0), 0.0, 1.2, 22, false],
		["gravats", Vector2(20.0, 3.0), 0.0, 1.2, 22, true],
		["gravats", Vector2(11.0, 28.0), 180.0, 1.2, 22, true],
		["gravats", Vector2(20.0, 28.0), 180.0, 1.2, 22, false],
		["gravats", Vector2(3.0, 8.0), 90.0, 2.0, 23, false],
		["gravats", Vector2(28.0, 8.0), 270.0, 2.0, 23, true],
		["gravats", Vector2(3.0, 23.0), 90.0, 2.0, 23, true],
		["gravats", Vector2(28.0, 23.0), 270.0, 2.0, 23, false],
		["gravats", Vector2(3.0, 24.0), 90.0, 1.6, 24, false],
		["gravats", Vector2(28.0, 24.0), 270.0, 1.6, 24, true],
		["gravats", Vector2(3.0, 7.0), 90.0, 1.6, 24, true],
		["gravats", Vector2(28.0, 7.0), 270.0, 1.6, 24, false],
		["gravats", Vector2(6.0, 28.0), 0.0, 2.0, 25, false],
		["gravats", Vector2(25.0, 28.0), 0.0, 2.0, 25, true],
		["gravats", Vector2(6.0, 3.0), 180.0, 2.0, 25, true],
		["gravats", Vector2(25.0, 3.0), 180.0, 2.0, 25, false],
		["eclats", Vector2(9.0, 11.0), 0.0, 1.2, 26, false],
		["eclats", Vector2(22.0, 11.0), 0.0, 1.2, 26, true],
		["eclats", Vector2(9.0, 20.0), 180.0, 1.2, 26, true],
		["eclats", Vector2(22.0, 20.0), 180.0, 1.2, 26, false],
		["eclats", Vector2(12.0, 19.0), 0.0, 1.0, 27, false],
		["eclats", Vector2(19.0, 19.0), 0.0, 1.0, 27, true],
		["eclats", Vector2(12.0, 12.0), 180.0, 1.0, 27, true],
		["eclats", Vector2(19.0, 12.0), 180.0, 1.0, 27, false],
		["eclats", Vector2(7.0, 6.0), 0.0, 1.0, 28, false],
		["eclats", Vector2(24.0, 6.0), 0.0, 1.0, 28, true],
		["eclats", Vector2(7.0, 25.0), 180.0, 1.0, 28, true],
		["eclats", Vector2(24.0, 25.0), 180.0, 1.0, 28, false],
		["chaine", Vector2(10.0, 26.0), 20.0, 2.4, 29, false],
		["chaine", Vector2(21.0, 26.0), 340.0, 2.4, 29, true],
		["chaine", Vector2(10.0, 5.0), 160.0, 2.4, 29, true],
		["chaine", Vector2(21.0, 5.0), 200.0, 2.4, 29, false],
		["chaine", Vector2(11.5, 8.5), -30.0, 1.8, 30, false],
		["chaine", Vector2(19.5, 8.5), 30.0, 1.8, 30, true],
		["chaine", Vector2(11.5, 22.5), 210.0, 1.8, 30, true],
		["chaine", Vector2(19.5, 22.5), 150.0, 1.8, 30, false],
		["lettres", Vector2(5.0, 11.0), 90.0, "07", 0, false],
		["lettres", Vector2(26.0, 11.0), 270.0, "07", 0, false],
		["lettres", Vector2(5.0, 20.0), 90.0, "07", 0, false],
		["lettres", Vector2(26.0, 20.0), 270.0, "07", 0, false],
		["cadre", Vector2(15.5, 6.0), 0.0, Vector2(5.2, 1.4), 31, false],
		["cadre", Vector2(15.5, 26.0), 0.0, Vector2(5.2, 1.4), 32, false],
		["bande", Vector2(15.5, 16.0), 90.0, 4.0, 33, false],
		["bande", Vector2(15.5, 15.0), 90.0, 4.0, 33, false],
	],
	"map_001": [
		["gravats", Vector2(10.0, 12.0), 0.0, 2.2, 41, false],
		["gravats", Vector2(19.0, 12.0), 0.0, 2.2, 41, true],
		["gravats", Vector2(10.0, 17.0), 180.0, 2.2, 41, true],
		["gravats", Vector2(19.0, 17.0), 180.0, 2.2, 41, false],
		["gravats", Vector2(8.0, 10.0), 90.0, 1.6, 42, false],
		["gravats", Vector2(21.0, 10.0), 270.0, 1.6, 42, true],
		["gravats", Vector2(8.0, 19.0), 90.0, 1.6, 42, true],
		["gravats", Vector2(21.0, 19.0), 270.0, 1.6, 42, false],
		["gravats", Vector2(6.0, 3.0), 0.0, 1.4, 43, false],
		["gravats", Vector2(23.0, 3.0), 0.0, 1.4, 43, true],
		["gravats", Vector2(6.0, 26.0), 180.0, 1.4, 43, true],
		["gravats", Vector2(23.0, 26.0), 180.0, 1.4, 43, false],
		["gravats", Vector2(3.0, 20.0), 90.0, 1.8, 44, false],
		["gravats", Vector2(26.0, 20.0), 270.0, 1.8, 44, true],
		["gravats", Vector2(3.0, 9.0), 90.0, 1.8, 44, true],
		["gravats", Vector2(26.0, 9.0), 270.0, 1.8, 44, false],
		["gravats", Vector2(13.0, 13.0), 90.0, 1.5, 45, false],
		["gravats", Vector2(16.0, 13.0), 270.0, 1.5, 45, true],
		["gravats", Vector2(13.0, 16.0), 90.0, 1.5, 45, true],
		["gravats", Vector2(16.0, 16.0), 270.0, 1.5, 45, false],
		["eclats", Vector2(5.5, 6.5), 0.0, 1.2, 46, false],
		["eclats", Vector2(23.5, 6.5), 0.0, 1.2, 46, true],
		["eclats", Vector2(5.5, 22.5), 180.0, 1.2, 46, true],
		["eclats", Vector2(23.5, 22.5), 180.0, 1.2, 46, false],
		["eclats", Vector2(12.0, 23.0), 0.0, 1.0, 47, false],
		["eclats", Vector2(17.0, 23.0), 0.0, 1.0, 47, true],
		["eclats", Vector2(12.0, 6.0), 180.0, 1.0, 47, true],
		["eclats", Vector2(17.0, 6.0), 180.0, 1.0, 47, false],
		["chaine", Vector2(5.5, 25.0), 15.0, 2.2, 48, false],
		["chaine", Vector2(23.5, 25.0), 345.0, 2.2, 48, true],
		["chaine", Vector2(5.5, 4.0), 165.0, 2.2, 48, true],
		["chaine", Vector2(23.5, 4.0), 195.0, 2.2, 48, false],
		["chaine", Vector2(7.0, 6.0), -20.0, 1.8, 49, false],
		["chaine", Vector2(22.0, 6.0), 20.0, 1.8, 49, true],
		["chaine", Vector2(7.0, 23.0), 200.0, 1.8, 49, true],
		["chaine", Vector2(22.0, 23.0), 160.0, 1.8, 49, false],
		["lettres", Vector2(4.5, 10.0), 90.0, "B-07", 0, false],
		["lettres", Vector2(24.5, 10.0), 270.0, "B-07", 0, false],
		["lettres", Vector2(4.5, 19.0), 90.0, "B-07", 0, false],
		["lettres", Vector2(24.5, 19.0), 270.0, "B-07", 0, false],
		["cadre", Vector2(14.5, 5.0), 0.0, Vector2(5.2, 1.4), 50, false],
		["cadre", Vector2(14.5, 24.0), 0.0, Vector2(5.2, 1.4), 51, false],
		["bande", Vector2(14.5, 8.0), 90.0, 2.0, 52, false],
		["bande", Vector2(14.5, 21.0), 90.0, 2.0, 52, false],
	],
	"map_002": [
		["gravats", Vector2(7.0, 7.5), 90.0, 1.6, 61, false],
		["gravats", Vector2(24.0, 7.5), 270.0, 1.6, 61, true],
		["gravats", Vector2(7.0, 17.5), 90.0, 1.6, 61, true],
		["gravats", Vector2(24.0, 17.5), 270.0, 1.6, 61, false],
		["gravats", Vector2(4.0, 3.0), 0.0, 1.6, 62, false],
		["gravats", Vector2(27.0, 3.0), 0.0, 1.6, 62, true],
		["gravats", Vector2(4.0, 22.0), 180.0, 1.6, 62, true],
		["gravats", Vector2(27.0, 22.0), 180.0, 1.6, 62, false],
		["gravats", Vector2(8.5, 10.0), 0.0, 1.0, 63, false],
		["gravats", Vector2(22.5, 10.0), 0.0, 1.0, 63, true],
		["gravats", Vector2(8.5, 15.0), 180.0, 1.0, 63, true],
		["gravats", Vector2(22.5, 15.0), 180.0, 1.0, 63, false],
		["gravats", Vector2(10.0, 17.5), 90.0, 1.6, 64, false],
		["gravats", Vector2(21.0, 17.5), 270.0, 1.6, 64, true],
		["gravats", Vector2(10.0, 7.5), 90.0, 1.6, 64, true],
		["gravats", Vector2(21.0, 7.5), 270.0, 1.6, 64, false],
		["gravats", Vector2(7.0, 22.0), 0.0, 1.6, 65, false],
		["gravats", Vector2(24.0, 22.0), 0.0, 1.6, 65, true],
		["gravats", Vector2(7.0, 3.0), 180.0, 1.6, 65, true],
		["gravats", Vector2(24.0, 3.0), 180.0, 1.6, 65, false],
		["gravats", Vector2(11.0, 12.5), 90.0, 1.0, 66, false],
		["gravats", Vector2(20.0, 12.5), 270.0, 1.0, 66, true],
		["gravats", Vector2(11.0, 12.5), 90.0, 1.0, 66, true],
		["gravats", Vector2(20.0, 12.5), 270.0, 1.0, 66, false],
		["eclats", Vector2(5.0, 7.0), 0.0, 1.0, 67, false],
		["eclats", Vector2(26.0, 7.0), 0.0, 1.0, 67, true],
		["eclats", Vector2(5.0, 18.0), 180.0, 1.0, 67, true],
		["eclats", Vector2(26.0, 18.0), 180.0, 1.0, 67, false],
		["eclats", Vector2(11.0, 21.0), 0.0, 1.0, 68, false],
		["eclats", Vector2(20.0, 21.0), 0.0, 1.0, 68, true],
		["eclats", Vector2(11.0, 4.0), 180.0, 1.0, 68, true],
		["eclats", Vector2(20.0, 4.0), 180.0, 1.0, 68, false],
		["chaine", Vector2(11.5, 5.0), 10.0, 2.0, 69, false],
		["chaine", Vector2(19.5, 5.0), 350.0, 2.0, 69, true],
		["chaine", Vector2(11.5, 20.0), 170.0, 2.0, 69, true],
		["chaine", Vector2(19.5, 20.0), 190.0, 2.0, 69, false],
		["chaine", Vector2(4.5, 17.0), 80.0, 1.8, 70, false],
		["chaine", Vector2(26.5, 17.0), 280.0, 1.8, 70, true],
		["chaine", Vector2(4.5, 8.0), 100.0, 1.8, 70, true],
		["chaine", Vector2(26.5, 8.0), 260.0, 1.8, 70, false],
		["lettres", Vector2(4.5, 8.5), 90.0, "C3", 0, false],
		["lettres", Vector2(26.5, 8.5), 270.0, "C3", 0, false],
		["lettres", Vector2(4.5, 16.5), 90.0, "C3", 0, false],
		["lettres", Vector2(26.5, 16.5), 270.0, "C3", 0, false],
		["cadre", Vector2(15.5, 4.0), 0.0, Vector2(5.2, 1.4), 71, false],
		["cadre", Vector2(15.5, 21.0), 0.0, Vector2(5.2, 1.4), 72, false],
	],
	"map_003": [
		["gravats", Vector2(8.5, 10.0), 0.0, 2.4, 81, false],
		["gravats", Vector2(18.5, 17.0), 180.0, 2.4, 81, false],
		["gravats", Vector2(18.5, 6.0), 0.0, 2.4, 82, false],
		["gravats", Vector2(8.5, 21.0), 180.0, 2.4, 82, false],
		["gravats", Vector2(10.0, 3.0), 0.0, 1.6, 83, false],
		["gravats", Vector2(17.0, 24.0), 180.0, 1.6, 83, false],
		["gravats", Vector2(3.0, 15.0), 90.0, 2.0, 84, false],
		["gravats", Vector2(24.0, 12.0), 270.0, 2.0, 84, false],
		["gravats", Vector2(11.0, 13.5), 90.0, 1.0, 85, false],
		["gravats", Vector2(16.0, 13.5), 270.0, 1.0, 85, false],
		["eclats", Vector2(13.5, 10.0), 0.0, 1.0, 86, false],
		["eclats", Vector2(13.5, 17.0), 180.0, 1.0, 86, false],
		["eclats", Vector2(5.0, 20.0), 0.0, 1.2, 87, false],
		["eclats", Vector2(22.0, 7.0), 180.0, 1.2, 87, false],
		["chaine", Vector2(21.5, 4.5), 170.0, 2.0, 88, false],
		["chaine", Vector2(5.5, 22.5), 350.0, 2.0, 88, false],
		["chaine", Vector2(4.0, 23.0), -15.0, 1.8, 89, false],
		["chaine", Vector2(23.0, 4.0), 165.0, 1.8, 89, false],
		["lettres", Vector2(4.0, 17.0), 90.0, "B-07", 0, false],
		["lettres", Vector2(23.0, 10.0), 270.0, "B-07", 0, false],
		["cadre", Vector2(14.0, 4.0), 0.0, Vector2(5.2, 1.4), 90, false],
		["cadre", Vector2(13.0, 23.0), 180.0, Vector2(5.2, 1.4), 90, false],
	],
	"map_004": [
		["gravats", Vector2(10.0, 7.0), 0.0, 2.0, 101, false],
		["gravats", Vector2(15.0, 7.0), 0.0, 2.0, 101, true],
		["gravats", Vector2(10.0, 18.0), 180.0, 2.0, 101, true],
		["gravats", Vector2(15.0, 18.0), 180.0, 2.0, 101, false],
		["gravats", Vector2(7.0, 8.8), 90.0, 1.0, 102, false],
		["gravats", Vector2(18.0, 8.8), 270.0, 1.0, 102, true],
		["gravats", Vector2(7.0, 16.2), 90.0, 1.0, 102, true],
		["gravats", Vector2(18.0, 16.2), 270.0, 1.0, 102, false],
		["gravats", Vector2(9.0, 10.0), 90.0, 1.4, 103, false],
		["gravats", Vector2(16.0, 10.0), 270.0, 1.4, 103, true],
		["gravats", Vector2(9.0, 15.0), 90.0, 1.4, 103, true],
		["gravats", Vector2(16.0, 15.0), 270.0, 1.4, 103, false],
		["gravats", Vector2(11.0, 12.5), 90.0, 1.0, 104, false],
		["gravats", Vector2(14.0, 12.5), 270.0, 1.0, 104, true],
		["gravats", Vector2(11.0, 12.5), 90.0, 1.0, 104, true],
		["gravats", Vector2(14.0, 12.5), 270.0, 1.0, 104, false],
		["gravats", Vector2(6.0, 22.0), 0.0, 1.8, 105, false],
		["gravats", Vector2(19.0, 22.0), 0.0, 1.8, 105, true],
		["gravats", Vector2(6.0, 3.0), 180.0, 1.8, 105, true],
		["gravats", Vector2(19.0, 3.0), 180.0, 1.8, 105, false],
		["eclats", Vector2(5.0, 6.0), 0.0, 1.0, 106, false],
		["eclats", Vector2(20.0, 6.0), 0.0, 1.0, 106, true],
		["eclats", Vector2(5.0, 19.0), 180.0, 1.0, 106, true],
		["eclats", Vector2(20.0, 19.0), 180.0, 1.0, 106, false],
		["eclats", Vector2(10.5, 15.0), 0.0, 1.0, 107, false],
		["eclats", Vector2(14.5, 15.0), 0.0, 1.0, 107, true],
		["eclats", Vector2(10.5, 10.0), 180.0, 1.0, 107, true],
		["eclats", Vector2(14.5, 10.0), 180.0, 1.0, 107, false],
		["chaine", Vector2(8.0, 5.0), 10.0, 2.0, 108, false],
		["chaine", Vector2(17.0, 5.0), 350.0, 2.0, 108, true],
		["chaine", Vector2(8.0, 20.0), 170.0, 2.0, 108, true],
		["chaine", Vector2(17.0, 20.0), 190.0, 2.0, 108, false],
		["lettres", Vector2(4.0, 16.0), 90.0, "C3", 0, false],
		["lettres", Vector2(21.0, 16.0), 270.0, "C3", 0, false],
		["lettres", Vector2(4.0, 9.0), 90.0, "C3", 0, false],
		["lettres", Vector2(21.0, 9.0), 270.0, "C3", 0, false],
		["cadre", Vector2(12.5, 4.0), 0.0, Vector2(5.2, 1.4), 109, false],
		["cadre", Vector2(12.5, 21.0), 0.0, Vector2(5.2, 1.4), 110, false],
	],
}
## Les familles symétriques par construction (leur usure est tirée sur un quart et reportée) : sur l'axe, leur propre jumeau.
const SOL_MARQUE_SYMETRIQUES := ["cadre", "bande", "lettres"]
## Les peintures : toutes NOIRES, seule l'opacité change. Un gravat entre 0,38 et 0,6 (le tas est plus dense au cœur).
const MARQUE_GRAVATS_ALPHA := Vector2(0.38, 0.6)
const MARQUE_ECLATS_ALPHA := Vector2(0.32, 0.5)
const MARQUE_CHAINE := Color(0.0, 0.0, 0.0, 0.6)
const MARQUE_BANDE := Color(0.0, 0.0, 0.0, 0.3)
const MARQUE_LETTRES := Color(0.0, 0.0, 0.0, 0.4)
const MARQUE_LETTRES_FONTE := 14
## La largeur d'une bande peinte, en pixels du monde (le dixième d'une dalle, comme sur « créer local »).
const MARQUE_BANDE_LARGEUR := 3.5
## Les marques posées sur CETTE carte : [famille, centre en pixels du monde, rotation en radians, paramètre, graine, miroir].
var _marques: Array = []


static func pochoirs_actifs() -> bool:
	return OS.get_cmdline_user_args().has(DRAPEAU_POCHOIRS)


## Les pochoirs de la table pour CETTE carte, en pixels du monde (le tableau est partagé avec les copies par vue).
func _lister_pochoirs() -> void:
	for p in POCHOIRS_ESSAI.get(String(_map_data.get("id", "")), []):
		_pochoirs.append([String(p[0]), (Vector2(p[1]) + Vector2(0.5, 0.5)) * TILE_SIZE, deg_to_rad(float(p[2]))])


## Pour les bancs : pose ou retire les pochoirs de l'essai et recuit le décor, sur la même carte, dans la même partie — la planche
## compare ainsi avec et sans au même instant (deux lancements ne rendent jamais la même scène). Les copies par vue partagent le
## tableau et reçoivent la texture recuite ; la peinture de la carte la reprend d'elle-même (`PeintureIso._process`).
func poser_pochoirs(avec: bool) -> void:
	_pochoirs.clear()
	if avec:
		_lister_pochoirs()
	await _cuire()


static func sol_marque_actif() -> bool:
	return OS.get_cmdline_user_args().has(DRAPEAU_SOL_MARQUE)


## Les marques de la table pour CETTE carte, en pixels du monde (le tableau est partagé avec les copies par vue).
func _lister_marques() -> void:
	for m in SOL_MARQUE_ESSAI.get(String(_map_data.get("id", "")), []):
		_marques.append([String(m[0]), (Vector2(m[1]) + Vector2(0.5, 0.5)) * TILE_SIZE, deg_to_rad(float(m[2])), m[3],
			int(m[4]), bool(m[5])])


## Pour les bancs, comme `poser_pochoirs` : pose ou retire les marques de l'essai et recuit le décor, au même instant.
func poser_marques(avec: bool) -> void:
	_marques.clear()
	if avec:
		_lister_marques()
	await _cuire()


## Le peintre de la cuisson : un nœud jetable dans le SubViewport, qui dessine
## le décor une fois, décalé pour que le cadre commence en (0, 0).
class _Peintre extends Node2D:
	var decor: Node2D
	func _draw() -> void:
		decor._dessiner_direct(self)


## Construit et ajoute les décors d'arène dans le nœud arena.
static func build(data: Dictionary, parent: Node2D) -> ArenaDecor:
	# Purge préalable si existant
	for old_name in ["ArenaDecor", "ArenaDecor_P1", "ArenaDecor_P2"]:
		var old := parent.get_node_or_null(old_name)
		if old:
			parent.remove_child(old)
			old.queue_free()

	var decor: Node2D = (preload("res://arena_decor.gd") as GDScript).new()
	decor.name = "ArenaDecor"
	decor.setup(data)
	parent.add_child(decor)

	# Duplications pour l'écran scindé (P1 et P2)
	decor._duplicate_for_player(parent, 1, 2, 1 | 16)
	decor._duplicate_for_player(parent, 2, 4, 1 | 32)

	return decor


func setup(data: Dictionary) -> void:
	_map_data = data
	z_index = 0
	# Calque original : visible par défaut
	visibility_layer = 1
	light_mask = 1
	# Refonte roman graphique, lot 4 (2026-09-11, Adrien : « corrige les deux
	# éléments à corriger ») : plus de matériau additif. Chevrons, équerres,
	# pochoirs et rivets sont des marques PEINTES au sol, pas des sources : en
	# addition elles ne pouvaient jamais porter de noir et s'éclaircissaient deux
	# fois sous la torche. Mélange normal, éclairé comme le sol — les LUMIÈRES,
	# elles, s'additionnent toujours (c'est le principe du jeu, et il vit dans
	# les Light2D, pas ici).

	_analyser_carte()
	queue_redraw()


func _duplicate_for_player(parent: Node2D, player_idx: int, vis_mask: int, lt_mask: int) -> void:
	var copy := duplicate() as Node2D
	copy.name = "ArenaDecor_P%d" % player_idx
	copy.visibility_layer = vis_mask
	copy.light_mask = lt_mask
	# `duplicate()` ne recopie pas les variables de script (piège du 2026-08-25).
	copy._danger_edges = _danger_edges
	copy._stencils = _stencils
	copy._pochoirs = _pochoirs
	copy._marques = _marques
	copy._cadre = _cadre
	copy._cuit = _cuit
	copy._est_copie = true
	copy.queue_redraw()
	parent.add_child(copy)
	_copies.append(copy)


func _ready() -> void:
	if not _est_copie:
		_cuire()


## Rend le décor UNE fois dans un SubViewport à la taille du cadre, puis
## remplace le dessin direct par cette texture — ici et dans les copies.
func _cuire() -> void:
	if DisplayServer.get_name() == "headless" or _cadre.size.x <= 0.0:
		return
	# ⚠️ D'abord une image d'attente : `build()` DUPLIQUE ce nœud juste après
	# l'avoir ajouté, enfants compris — un SubViewport déjà posé partirait dans
	# les copies avec un peintre sans décor (vu à la première capture : six
	# « _dessiner_direct in base Nil »). Créé à l'image suivante, il n'est qu'ici.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var vue := SubViewport.new()
	vue.name = "CuissonDecor"
	vue.size = Vector2i(_cadre.size)
	vue.transparent_bg = true
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vue.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	# Le viewport entre dans l'arbre AVANT de recevoir son peintre, pour que le
	# peintre trouve son World2D dès son entrée. (L'erreur « !is_inside_tree() …
	# Returning Ref<World2D>() » qu'imprime le photographe à sa FERMETURE sur un
	# plan seul n'est pas d'ici : vérifiée présente avec l'ancien décor.)
	add_child(vue)
	var peintre := _Peintre.new()
	peintre.decor = self
	peintre.position = -_cadre.position
	vue.add_child(peintre)
	# Une image pour rendre : la texture n'est lisible qu'après.
	await RenderingServer.frame_post_draw
	# L'arène a pu être reconstruite pendant l'attente : ce nœud n'y est plus.
	if not is_inside_tree():
		return
	var img: Image = vue.get_texture().get_image()
	vue.queue_free()
	if img == null:
		return
	_cuit = ImageTexture.create_from_image(img)
	queue_redraw()
	for copy in _copies:
		if is_instance_valid(copy):
			copy._cuit = _cuit
			copy.queue_redraw()


func _analyser_carte() -> void:
	_danger_edges.clear()
	_stencils.clear()
	_pochoirs.clear()
	if pochoirs_actifs():
		_lister_pochoirs()
	_marques.clear()
	if sol_marque_actif():
		_lister_marques()

	var grid := MapCodec.get_grid_size(_map_data)
	_cadre = Rect2(Vector2(-TILE_SIZE, -TILE_SIZE), (Vector2(grid) + Vector2(2, 2)) * TILE_SIZE)
	var floor_cells := MapCodec.get_floor_cells(_map_data)
	var wall_cells := MapCodec.get_wall_cells(_map_data)

	var floor_set := {}
	for c in floor_cells:
		floor_set[c] = true

	var wall_set := {}
	for c in wall_cells:
		wall_set[c] = true

	var p1_spawn := MapCodec.get_spawn(_map_data, 0)
	var p2_spawn := MapCodec.get_spawn(_map_data, 1)

	# 1. Détection des zones de danger pour bandes chevrons noir/ambre :
	# Bords de fosses/gouffres (sol bordé de vide), et délimitations de zones d'accès clés.
	for cell in floor_cells:
		var pos := Vector2(cell) * TILE_SIZE
		# Voisin Nord (fosse)
		var north := cell + Vector2i(0, -1)
		if not floor_set.has(north) and not wall_set.has(north):
			_danger_edges.append({
				"start": pos,
				"end": pos + Vector2(TILE_SIZE, 0),
				"dir": Vector2(1, 0),
				"normal": Vector2(0, 1)
			})
		# Voisin Sud (fosse)
		var south := cell + Vector2i(0, 1)
		if not floor_set.has(south) and not wall_set.has(south):
			_danger_edges.append({
				"start": pos + Vector2(TILE_SIZE, TILE_SIZE),
				"end": pos + Vector2(0, TILE_SIZE),
				"dir": Vector2(-1, 0),
				"normal": Vector2(0, -1)
			})
		# Voisin Ouest (fosse)
		var west := cell + Vector2i(-1, 0)
		if not floor_set.has(west) and not wall_set.has(west):
			_danger_edges.append({
				"start": pos + Vector2(0, TILE_SIZE),
				"end": pos,
				"dir": Vector2(0, -1),
				"normal": Vector2(1, 0)
			})
		# Voisin Est (fosse)
		var east := cell + Vector2i(1, 0)
		if not floor_set.has(east) and not wall_set.has(east):
			_danger_edges.append({
				"start": pos + Vector2(TILE_SIZE, 0),
				"end": pos + Vector2(TILE_SIZE, TILE_SIZE),
				"dir": Vector2(0, 1),
				"normal": Vector2(-1, 0)
			})

	# Si la carte n'a pas de gouffre intérieur (ex: carte fermée), on pose des chevrons de danger
	# aux seuils des zones de spawn pour délimiter les zones de départ / combat
	if _danger_edges.is_empty():
		for sp in [p1_spawn, p2_spawn]:
			if sp.x >= 0:
				var sp_pos := Vector2(sp) * TILE_SIZE
				_danger_edges.append({
					"start": sp_pos + Vector2(0, TILE_SIZE),
					"end": sp_pos + Vector2(TILE_SIZE, TILE_SIZE),
					"dir": Vector2(1, 0),
					"normal": Vector2(0, -1)
				})

	# 3. Marquages pochoir de travées aux abords des spawns P1 et P2
	if p1_spawn.x >= 0:
		_stencils.append({
			"pos": Vector2(p1_spawn) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5),
			"text": "01",
			"type": "spawn"
		})
	if p2_spawn.x >= 0:
		_stencils.append({
			"pos": Vector2(p2_spawn) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5),
			"text": "02",
			"type": "spawn"
		})

	# Pochoir de travée centrale si disponible
	var centre_cell := Vector2i(grid.x / 2, grid.y / 2)
	if floor_set.has(centre_cell) and not wall_set.has(centre_cell):
		_stencils.append({
			"pos": Vector2(centre_cell) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5),
			"text": "BAY-A",
			"type": "bay"
		})


func _draw() -> void:
	if _cuit != null:
		draw_texture(_cuit, _cadre.position)
		return
	_dessiner_direct(self)


## Le dessin lui-même, sur n'importe quel CanvasItem : le nœud (avant cuisson
## et en headless) ou le peintre de la cuisson.
func _dessiner_direct(sur: CanvasItem) -> void:
	_dessiner_bandes_danger(sur)
	_dessiner_pochoirs(sur)
	_dessiner_sol_marque(sur)
	_dessiner_pochoirs_essai(sur)


## ISO13 — les pochoirs de l'illustration, à la fonte d'enseigne (condensée), centrés sur leur point, tournés de leur angle.
func _dessiner_pochoirs_essai(sur: CanvasItem) -> void:
	if _pochoirs.is_empty():
		return
	var fonte: Font = Charte.police_display(Charte.POIDS_ENSEIGNE)
	if fonte == null:
		fonte = ThemeDB.fallback_font
	for p in _pochoirs:
		var texte: String = p[0]
		var taille := fonte.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, POCHOIR_TAILLE_FONTE)
		sur.draw_set_transform(p[1], p[2])
		# La ligne de base sous le centre : le mot centré sur son point, dans les deux sens.
		sur.draw_string(fonte, Vector2(-taille.x * 0.5, fonte.get_ascent(POCHOIR_TAILLE_FONTE) * 0.5), texte,
			HORIZONTAL_ALIGNMENT_LEFT, -1, POCHOIR_TAILLE_FONTE, POCHOIR_PEINTURE)
		sur.draw_set_transform(Vector2.ZERO, 0.0)


## ISO14 — le sol marqué : chaque marque dans son repère (centre, angle, retournée si `miroir`), tirée de SA graine — le
## jumeau d'une marque en est donc l'image exacte, au pixel du monde près.
func _dessiner_sol_marque(sur: CanvasItem) -> void:
	if _marques.is_empty():
		return
	for m in _marques:
		sur.draw_set_transform(m[1], m[2], Vector2(-1.0 if m[5] else 1.0, 1.0))
		var rng := RandomNumberGenerator.new()
		rng.seed = int(m[4])
		match String(m[0]):
			"gravats":
				_dessiner_gravats(sur, float(m[3]) * TILE_SIZE, rng)
			"eclats":
				_dessiner_eclats(sur, float(m[3]) * TILE_SIZE, rng)
			"chaine":
				_dessiner_chaine(sur, float(m[3]) * TILE_SIZE, rng)
			"cadre":
				var t: Vector2 = Vector2(m[3]) * TILE_SIZE
				_dessiner_cadre(sur, t, rng)
			"bande":
				_dessiner_bande(sur, Vector2.ZERO, float(m[3]) * TILE_SIZE * 0.5, false, rng)
			"lettres":
				_dessiner_lettres(sur, String(m[3]))
	sur.draw_set_transform(Vector2.ZERO, 0.0)


## Un éclat : un polygone de 3 à 5 sommets, de rayon `r`, tourné au hasard.
func _eclat(sur: CanvasItem, centre: Vector2, r: float, alpha: float, rng: RandomNumberGenerator) -> void:
	var n := rng.randi_range(3, 5)
	var a0 := rng.randf() * TAU
	var pts := PackedVector2Array()
	for k in n:
		var a := a0 + TAU * float(k) / float(n) + rng.randf_range(-0.35, 0.35)
		pts.append(centre + Vector2.from_angle(a) * r * rng.randf_range(0.6, 1.0))
	sur.draw_colored_polygon(pts, Color(0.0, 0.0, 0.0, alpha))


## Un tas allongé le long de l'axe x, de longueur `l` : plus dense et plus gros au cœur, effilé aux bouts, jamais à plus
## de 5 px de son axe (2,2 + 2,6) (la place en travers, que la garde vérifie).
func _dessiner_gravats(sur: CanvasItem, l: float, rng: RandomNumberGenerator) -> void:
	var n := int(l / TILE_SIZE * 8.0) + rng.randi_range(1, 3)
	for i in n:
		var x := rng.randf_range(-0.5, 0.5) * l
		var coeur := 1.0 - pow(2.0 * x / l, 2.0)
		var y := clampf(rng.randfn(0.0, 1.1) * coeur, -2.2, 2.2)
		# Des éclats de 0,8 à 2,6 px : plus gros, ils se soudaient en une tache (vu à la première planche).
		var r := lerpf(0.8, 2.6, coeur * rng.randf())
		_eclat(sur, Vector2(x, y), r, lerpf(MARQUE_GRAVATS_ALPHA.x, MARQUE_GRAVATS_ALPHA.y, rng.randf()), rng)
	# La poussière de gravats : des grains d'un pixel, dans la même bande.
	for i in n:
		var p := Vector2(rng.randf_range(-0.5, 0.5) * l, rng.randf_range(-4.0, 4.0))
		sur.draw_rect(Rect2(p, Vector2.ONE), Color(0.0, 0.0, 0.0, MARQUE_ECLATS_ALPHA.x))


## Quelques débris épars sur un disque de diamètre `d`.
func _dessiner_eclats(sur: CanvasItem, d: float, rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(6, 9):
		var p := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * d * 0.5
		_eclat(sur, p, rng.randf_range(0.8, 2.4), lerpf(MARQUE_ECLATS_ALPHA.x, MARQUE_ECLATS_ALPHA.y, rng.randf()), rng)


## Une chaîne de longueur `l`, posée en arc lâche : un maillon à plat (un anneau), un maillon de chant (un trait), en
## alternance, tous les 4,2 px. Moins de 9 px de son axe.
func _dessiner_chaine(sur: CanvasItem, l: float, rng: RandomNumberGenerator) -> void:
	var fleche := rng.randf_range(-5.0, 5.0)
	var onde := rng.randf_range(0.6, 1.2)
	var phase := rng.randf() * TAU
	var courbe := func(t: float) -> Vector2:
		return Vector2((t - 0.5) * l, fleche * sin(PI * t) + onde * sin(TAU * 2.0 * t + phase))
	var n := int(l / 4.2)
	for i in n + 1:
		var t := float(i) / float(n)
		var p: Vector2 = courbe.call(t)
		var dir: Vector2 = (courbe.call(minf(t + 0.01, 1.0)) - courbe.call(maxf(t - 0.01, 0.0))).normalized()
		if i % 2 == 0:
			var anneau := PackedVector2Array()
			for k in 11:
				var a := TAU * float(k) / 10.0
				anneau.append(p + dir * cos(a) * 3.2 + dir.orthogonal() * sin(a) * 1.8)
			sur.draw_polyline(anneau, MARQUE_CHAINE, 1.1)
		else:
			sur.draw_line(p - dir * 2.5, p + dir * 2.5, MARQUE_CHAINE, 1.3)


## Une bande peinte de demi-longueur `demi`, centrée sur `centre`, horizontale (ou verticale), usée : des lacunes tirées sur
## une moitié et reportées sur l'autre — la bande est symétrique par construction.
func _dessiner_bande(sur: CanvasItem, centre: Vector2, demi: float, verticale: bool, rng: RandomNumberGenerator) -> void:
	var coupes: Array = []
	for i in rng.randi_range(1, 3):
		var a := rng.randf_range(0.1, 0.95) * demi
		coupes.append(Vector2(a, a + rng.randf_range(2.0, 7.0)))
	coupes.sort_custom(func(u: Vector2, v: Vector2) -> bool: return u.x < v.x)
	# Les morceaux peints de [0, demi], puis leur reflet sur [−demi, 0].
	var morceaux: Array = []
	var debut := 0.0
	for c in coupes:
		if c.x > debut:
			morceaux.append(Vector2(debut, c.x))
		debut = maxf(debut, c.y)
	if debut < demi:
		morceaux.append(Vector2(debut, demi))
	var w := MARQUE_BANDE_LARGEUR
	for mo in morceaux:
		for s in [1.0, -1.0]:
			var a: float = mo.x * s
			var b: float = mo.y * s
			var r := Rect2(minf(a, b), -w * 0.5, absf(b - a), w)
			if verticale:
				r = Rect2(-w * 0.5, r.position.x, w, r.size.x)
			sur.draw_rect(Rect2(centre + r.position, r.size), MARQUE_BANDE)


## Un cadre de bandes de taille `t` (pixels) : les deux longs côtés pleine longueur, les deux petits entre eux (aucun
## recouvrement aux coins). Le même tirage d'usure pour les côtés opposés : symétrique par les deux axes.
func _dessiner_cadre(sur: CanvasItem, t: Vector2, rng: RandomNumberGenerator) -> void:
	var w := MARQUE_BANDE_LARGEUR
	var graine_h := rng.randi()
	var graine_v := rng.randi()
	for s in [-1.0, 1.0]:
		rng.seed = graine_h
		_dessiner_bande(sur, Vector2(0.0, s * (t.y * 0.5)), t.x * 0.5 + w * 0.5, false, rng)
		rng.seed = graine_v
		_dessiner_bande(sur, Vector2(s * (t.x * 0.5), 0.0), t.y * 0.5 - w * 0.5, true, rng)


## Des lettres de secteur, sombres, à la fonte des pochoirs mais plus petites, centrées sur leur point.
func _dessiner_lettres(sur: CanvasItem, texte: String) -> void:
	var fonte: Font = Charte.police_display(Charte.POIDS_ENSEIGNE)
	if fonte == null:
		fonte = ThemeDB.fallback_font
	var taille := fonte.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, MARQUE_LETTRES_FONTE)
	sur.draw_string(fonte, Vector2(-taille.x * 0.5, fonte.get_ascent(MARQUE_LETTRES_FONTE) * 0.5), texte,
		HORIZONTAL_ALIGNMENT_LEFT, -1, MARQUE_LETTRES_FONTE, MARQUE_LETTRES)


## Bandes de sécurité en chevrons noir / ambre d'atelier le long des gouffres
func _dessiner_bandes_danger(sur: CanvasItem) -> void:
	var chevron_step := 7.0
	for edge in _danger_edges:
		var p1: Vector2 = edge["start"]
		var p2: Vector2 = edge["end"]
		var normal: Vector2 = edge["normal"] # vers l'intérieur du sol
		var tangent: Vector2 = edge["dir"]

		var length := p1.distance_to(p2)
		var num_chevrons := int(length / chevron_step)

		for i in range(num_chevrons):
			var t := float(i) * chevron_step
			var pt := p1 + tangent * t
			var pt_next := p1 + tangent * minf(t + chevron_step * 0.5, length)

			# Alternance chevrons ambre et noir
			var poly := PackedVector2Array([
				pt,
				pt_next,
				pt_next + normal * CHEVRON_WIDTH + tangent * (chevron_step * 0.4),
				pt + normal * CHEVRON_WIDTH + tangent * (chevron_step * 0.4)
			])
			sur.draw_colored_polygon(poly, Charte.AMBRE * 0.85)

		# Liseré de délimitation ambre franc en bordure de bande
		sur.draw_line(p1 + normal * CHEVRON_WIDTH, p2 + normal * CHEVRON_WIDTH,
			Charte.AMBRE * 0.5, 1.0)


## Pochoirs de travée et numérotation d'atelier
func _dessiner_pochoirs(sur: CanvasItem) -> void:
	for st in _stencils:
		var pos: Vector2 = st["pos"]
		var txt: String = st["text"]
		var col := Charte.AMBRE * 0.75 if st["type"] == "spawn" else Charte.HALOGENE * 0.45

		# Cadre pochoir discontinu
		var half := 12.0
		# 4 coins en équerre
		sur.draw_line(pos + Vector2(-half, -half), pos + Vector2(-half + 5, -half), col, 1.0)
		sur.draw_line(pos + Vector2(-half, -half), pos + Vector2(-half, -half + 5), col, 1.0)

		sur.draw_line(pos + Vector2(half, -half), pos + Vector2(half - 5, -half), col, 1.0)
		sur.draw_line(pos + Vector2(half, -half), pos + Vector2(half, -half + 5), col, 1.0)

		sur.draw_line(pos + Vector2(-half, half), pos + Vector2(-half + 5, half), col, 1.0)
		sur.draw_line(pos + Vector2(-half, half), pos + Vector2(-half, half - 5), col, 1.0)

		sur.draw_line(pos + Vector2(half, half), pos + Vector2(half - 5, half), col, 1.0)
		sur.draw_line(pos + Vector2(half, half), pos + Vector2(half, half - 5), col, 1.0)

		# Dessin vectoriel du chiffre ou symbole pochoir
		_dessiner_glyphe_pochoir(sur, pos, txt, col)


func _dessiner_glyphe_pochoir(sur: CanvasItem, pos: Vector2, txt: String, col: Color) -> void:
	match txt:
		"01":
			# Chiffre 01 stylisé au pochoir brutaliste
			# 0 : rectangle avec découpe centrale
			sur.draw_rect(Rect2(pos.x - 7, pos.y - 5, 5, 10), col, false, 1.0)
			# 1 : trait vertical franc
			sur.draw_line(Vector2(pos.x + 3, pos.y - 5), Vector2(pos.x + 3, pos.y + 5), col, 1.5)
			sur.draw_line(Vector2(pos.x + 1, pos.y - 3), Vector2(pos.x + 3, pos.y - 5), col, 1.2)
		"02":
			# Chiffre 02 stylisé au pochoir
			sur.draw_rect(Rect2(pos.x - 7, pos.y - 5, 5, 10), col, false, 1.0)
			# 2 en traits brisés
			sur.draw_line(Vector2(pos.x + 1, pos.y - 5), Vector2(pos.x + 6, pos.y - 5), col, 1.2)
			sur.draw_line(Vector2(pos.x + 6, pos.y - 5), Vector2(pos.x + 6, pos.y), col, 1.2)
			sur.draw_line(Vector2(pos.x + 6, pos.y), Vector2(pos.x + 1, pos.y + 5), col, 1.2)
			sur.draw_line(Vector2(pos.x + 1, pos.y + 5), Vector2(pos.x + 6, pos.y + 5), col, 1.2)
		_:
			# Symbole de baie industrielle (losange barré)
			sur.draw_line(pos - Vector2(5, 0), pos + Vector2(5, 0), col, 1.0)
			sur.draw_line(pos - Vector2(0, 5), pos + Vector2(0, 5), col, 1.0)
			sur.draw_rect(Rect2(pos - Vector2(3, 3), Vector2(6, 6)), col, false, 1.0)
