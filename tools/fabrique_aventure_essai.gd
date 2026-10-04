## Fabrique le chapitre D'ESSAI de l'aventure — chantier SOLO, étape S6.
##
## Trois salles minuscules qui exercent ce que le moteur sait faire : un PNJ immobile sous un plafonnier (niveau 1), une ronde et
## une zone, sans plafonnier (niveau 2), un boss dans une arène à deux plafonniers (niveau 3). Les fichiers vont dans
## `res://tools/aventure_essai/chapitre_00/` — JAMAIS dans `res://assets/solo/`, qui est le contenu livré (S7, S8).
##
## Les cartes sont des cartes de `map_codec.gd`, écrites ici en code pour que les salles se relisent et se refont : le fichier
## JSON est la vérité du jeu, ce script n'est que la façon dont on l'a écrit. Relancer ne change rien tant que ce fichier ne change
## pas (aucun tirage, aucune date).
##
## Lancer : godot --headless --path . --script res://tools/fabrique_aventure_essai.gd
extends SceneTree

const DOSSIER := "res://tools/aventure_essai/chapitre_00"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DOSSIER)
	_ecrire("chapitre.json", {
		"version": 1,
		"numero": 0,
		"titre": "L'initiation (essai)",
		"classe_debloquee": "pistolet",
		"classe_imposee": "pistolet",
		"niveaux": ["niveau_01.json", "niveau_02.json", "niveau_03.json"],
	})
	_ecrire("niveau_01.json", {
		"version": 1,
		"titre": "Sous la lampe",
		"intention": "Une silhouette immobile sous un plafonnier. Avance, vise, tire.",
		"boss": false,
		"carte": _salle(16, 16, []),
		"joueur": {"case": [3, 8], "orientation": 0},
		"plafonniers": [{"case": [12, 8], "rayon": 4.0, "intensite": 1.2}],
		"pnj": [{"case": [12, 8], "orientation": 180, "profil": "immobile_sourd_aveugle"}],
	})
	_ecrire("niveau_02.json", {
		"version": 1,
		"titre": "La ronde",
		"intention": "Une ronde autour d'un pilier, et un autre qui ne quitte pas sa zone. Aucune lumière : la torche.",
		"boss": false,
		"carte": _salle(18, 14, [Rect2i(8, 6, 2, 2)]),
		"joueur": {"case": [2, 7], "orientation": 0},
		"pnj": [
			{"case": [14, 3], "orientation": 90, "profil": "ronde_sourd_aveugle", "ronde": [[14, 3], [14, 10], [5, 10], [5, 3]]},
			{"case": [12, 9], "orientation": 180, "profil": "zone_sourd_aveugle", "zone": [10, 8, 6, 4]},
		],
	})
	_ecrire("niveau_03.json", {
		"version": 1,
		"titre": "Le Parasite",
		"intention": "Un duel dans une arène. Il voit, il entend, il tire — comme vous.",
		"boss": true,
		"carte": _salle(20, 20, [Rect2i(9, 5, 2, 3), Rect2i(9, 13, 2, 3)]),
		"joueur": {"case": [3, 10], "orientation": 0},
		"plafonniers": [{"case": [6, 10], "rayon": 3.5}, {"case": [14, 10], "rayon": 3.5, "intensite": 1.5}],
		"pnj": [{"case": [16, 10], "orientation": 180, "profil": "boss", "classe": "pistolet"}],
	})
	print("Chapitre d'essai écrit dans ", DOSSIER)
	quit()


## Une salle `largeur × hauteur` : le sol à l'intérieur, une ceinture de murs, et des piliers (rectangles de cases) de mur plein.
func _salle(largeur: int, hauteur: int, piliers: Array) -> Dictionary:
	var sol: Array[Vector2i] = []
	var murs: Array[Vector2i] = []
	for y in range(hauteur):
		for x in range(largeur):
			var bord := x == 0 or y == 0 or x == largeur - 1 or y == hauteur - 1
			var pilier := false
			for r: Rect2i in piliers:
				pilier = pilier or r.has_point(Vector2i(x, y))
			if bord or pilier:
				murs.append(Vector2i(x, y))
			if not bord:
				sol.append(Vector2i(x, y))
	return {
		"version": 4,
		"name": "Essai — salle %d × %d" % [largeur, hauteur],
		"grid_size": {"x": largeur, "y": hauteur},
		"tile_size": 35,
		"floor": MapCodec.encode_runs(sol),
		"walls": MapCodec.encode_runs(murs),
		"low_walls": "",
	}


func _ecrire(nom: String, donnees: Dictionary) -> void:
	var f := FileAccess.open(DOSSIER.path_join(nom), FileAccess.WRITE)
	f.store_string(JSON.stringify(donnees, "  ") + "\n")
	f.close()
