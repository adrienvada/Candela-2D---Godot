extends RefCounted

## Table unique des torches, partagée par `fabrique_cookies.gd` et
## `apercu_torche.gd`.
##
## ⚠️ **Ces valeurs DIVERGENT volontairement de `game_state.gd`.** C'est ici
## qu'on essaie une portée ; c'est là-bas qu'on l'acte. Tant que l'intégration
## n'est pas faite, **le banc ne montre pas le jeu** — il montre ce que le jeu
## deviendrait. L'aperçu l'affiche en clair à l'écran pour que personne ne
## confonde les deux.
##
## ## Ce que chaque champ décide
##
## - `angle` est un **DEMI-angle** : la pompe à 60° ouvre un cône de 120°. Il est
##   cuit dans le cookie, donc **le changer oblige à recuire**.
## - `echelle` est le `torch_scale` du jeu. L'empreinte au sol vaut
##   `512 × echelle` unités de monde, et le faisceau porte la **moitié** de ça
##   vers l'avant. Il ne demande aucune recuisson.
## - `brillance` est le `torch_brightness`, cuit lui aussi.
##
## ## L'échelle se lit en demi-écrans, pas en unités
##
## Chaque joueur voit un viewport de **960 unités de large**, donc **480 vers
## l'avant**. Une portée supérieure à 480 éclaire hors champ : le joueur allume
## quelque chose qu'il ne voit pas, et qui le trahit. C'est un choix de
## conception, pas un défaut — mais il doit être choisi arme par arme.
##
## Décision d'Adrien du 2026-08-24 : **l'arbalète est la seule à porter au-delà
## de l'écran.** Elle est l'arme furtive et lointaine ; les autres rentrent dans
## le champ.
const DEMI_ECRAN := 480.0

## `origine` garde la valeur d'avant l'arbitrage : sans elle, on ne saurait plus
## dans six mois ce qui a été déplacé ni de combien.
const ARMES := [
	{
		"nom": "pistolet", "fichier": "pistolet",
		"angle": 35.0, "echelle": 1.6, "brillance": 1.0,
		"origine": "30° / 2.3 — élargi et raccourci le 2026-08-24",
	},
	{
		"nom": "fusil", "fichier": "fusil",
		"angle": 10.0, "echelle": 1.8, "brillance": 1.0,
		"origine": "10° / 3.5 — raccourci le 2026-08-24",
	},
	{
		"nom": "pompe", "fichier": "pompe",
		"angle": 60.0, "echelle": 1.0, "brillance": 1.0,
		"origine": "inchangée",
	},
	{
		"nom": "arbalète", "fichier": "arbalete",
		"angle": 5.0, "echelle": 3.5, "brillance": 0.3,
		"origine": "inchangée — la seule qui porte hors champ",
	},
]


## Portée vers l'avant, en unités de monde.
static func portee(arme: Dictionary) -> float:
	return 512.0 * float(arme["echelle"]) * 0.5


## La même, en fraction de la demi-largeur d'écran. Au-dessus de 1,0, la torche
## éclaire ce que son porteur ne voit pas.
static func portee_ecrans(arme: Dictionary) -> float:
	return portee(arme) / DEMI_ECRAN
