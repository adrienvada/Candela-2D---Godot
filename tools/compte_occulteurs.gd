## Combien d'occulteurs de lumière une carte produit-elle ? (ISO12, question des halos, 2026-09-23)
##
## Le coût des passes d'ombre 2D est `4 × N × lampes à ombre`, et N est le nombre d'occulteurs que le
## moteur retient. La carte du banc de cadence en a **huit**, ce qui rend le gâchis des halos
## négligeable (~0,14 ms) ; la question est de savoir si une vraie carte en a assez pour le rendre
## visible. Ce script répond sans fenêtre, sans cadence et sans banc : il charge la carte, fait tourner
## la vraie génération (`MapGeometry.build_collisions`) et compte.
##
## ⚠️ **Le total d'une carte est une BORNE HAUTE** (précision de la session cloud, 06:20) : le moteur
## trie les occulteurs contre le rectangle ENGLOBANT de toutes les lampes à ombre, qui ne couvre la
## carte entière que si les deux joueurs sont aux extrémités. On imprime donc aussi l'étendue des
## occulteurs, pour pouvoir estimer l'union réelle à un écart de joueurs donné.
##
## Étalonné sur la carte des murs bas, dont le banc dit 8 : si le script ne rend pas 8, c'est le
## script qu'il faut corriger avant de lire le Cloître.
extends SceneTree

const CARTES := [
	{"nom": "murs bas (étalon, le banc en compte 8)", "chemin": "res://tools/cartes/murs_bas_essai.json"},
	{"nom": "Cloître", "chemin": "res://assets/maps/map_001_le_cloitre.json"},
]
## Ce qu'une lampe à ombre coûte, mesuré le 2026-09-23 : la lampe de la fusée, à 8 occulteurs, valait
## 0,09 ms — dans le bruit de ses propres passes, donc c'est déjà une borne haute.
const MS_PAR_LAMPE_A_HUIT := 0.09
const SEUIL_MS := 0.3


func _init() -> void:
	print("=== OCCULTEURS PAR CARTE ===")
	for carte in CARTES:
		var json := JSON.new()
		var texte := FileAccess.get_file_as_string(String(carte["chemin"]))
		if texte == "" or json.parse(texte) != OK or not (json.data is Dictionary):
			printerr("✗ carte illisible : ", carte["chemin"])
			quit(1)
			return
		var data: Dictionary = MapCodec.validate(json.data as Dictionary)["data"]
		# ⚠️ Diagnostic : la première version rendait 9 pour les DEUX cartes, alors que le Cloître a 48
		# cases de mur intérieur (ses piliers) et la carte des murs bas aucune. On imprime donc chaque
		# étage de la chaîne — cases lues, rectangles fusionnés, occulteurs posés — pour voir lequel perd
		# les piliers, au lieu de deviner.
		var cases: Array = MapCodec.get_wall_cells(data)
		var grille: Array = MapGeometry.build_grid(data, MapGeometry.Kind.WALLS)
		var rects: Array = MapGeometry.merge_rects(grille)
		var parent := Node2D.new()
		MapGeometry.build_collisions(data, parent)
		var occulteurs := parent.find_children("*", "LightOccluder2D", true, false)
		var n := occulteurs.size()
		print("   [diagnostic] %d cases de mur lues, grille %d, %d rectangles fusionnés, %d occulteurs"
			% [cases.size(), grille.size(), rects.size(), n])
		var englobant := Rect2()
		for i in n:
			var o := occulteurs[i] as LightOccluder2D
			var r := Rect2(o.global_position, Vector2.ZERO)
			englobant = r if i == 0 else englobant.merge(r)
		# Le coût, proportionnel à N (les deux halos, dont la part inutile mesurée est de 80 %).
		var ms := MS_PAR_LAMPE_A_HUIT * float(n) / 8.0 * 2.0 * 0.8
		print("%-42s %4d occulteurs — étendue %.0f × %.0f px — gâchis des halos ≤ %.2f ms  %s"
			% [carte["nom"], n, englobant.size.x, englobant.size.y, ms,
			"(sous %.1f ms : question close)" % SEUIL_MS if ms < SEUIL_MS else "(AU-DESSUS : à rouvrir)"])
		parent.free()
	quit()
