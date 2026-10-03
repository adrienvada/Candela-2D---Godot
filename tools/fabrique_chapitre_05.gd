## Fabrique le chapitre 5 de l'aventure, « Les groupes » — chantier SOLO, étape S8 (lot 2).
##
## Dix salles dans `res://assets/solo/chapitre_05/` : le manifeste (`chapitre.json`, qui débloque l'Incendiaire, slug `incendiaire`) et `niveau_01.json` … `niveau_10.json`.
## Les PNJ ne sont plus seuls : rondes et zones se couvrent les unes les autres, et un coup de feu les appelle ensemble. On apprend à défaire un groupe un à un, sans réveiller
## les autres : choisir qui tomber d'abord, en attirer un seul hors du groupe, passer là où un sol interdit ferme le chemin. **À partir de 5.7, les PNJ mobiles portent la
## classe du boss et sa nappe de braises** (`"equipe": true`, S8) : on apprend ce qu'un sol qui brûle fait d'un chemin avant de l'affronter.
##
## ⚠️ **Ce que la règle de la nappe demande** (`EquipementBot.GADGETS`) : elle se pose EN COMBAT, sur une cible VUE, à 150-420 px, entre le PNJ et elle. Un PNJ équipé doit donc
## VOIR : tous ceux de 5.7 à 5.9 voient (et entendent). Seuls les PNJ qui bougent sont équipés (comme aux chapitres 1 à 4) ; le poste immobile de 5.8 garde le Parasite.
## La nappe fait 136 px de large (`GadgetBraises.RAYON` 68) : un passage de trois cases (105 px) s'en trouve fermé d'un mur à l'autre — c'est la salle 5.6.
##
## Le dessin et l'écriture sont ceux de `fabrique_commune.gd` ; ce fichier ne contient que les salles, et `tools/test_chapitre_05.gd` mesure sur leurs JSON ce que chacune
## ENSEIGNE. **Les JSON sont la vérité du jeu, ce script n'est que la façon dont on les a écrits.**
##
## Lancer : godot --headless --path . --script res://tools/fabrique_chapitre_05.gd
extends SceneTree

const Commune := preload("res://tools/fabrique_commune.gd")

const DOSSIER := "res://assets/solo/chapitre_05"
const CLASSE := "incendiaire"


func _init() -> void:
	var salles: Array[Dictionary] = [
		_salle_01(), _salle_02(), _salle_03(), _salle_04(), _salle_05(),
		_salle_06(), _salle_07(), _salle_08(), _salle_09(), _salle_10(),
	]
	Commune.fabriquer(DOSSIER, 5, "Les groupes", CLASSE, "Les groupes", salles)
	quit()


func _lampe(x: int, y: int, rayon: float) -> Dictionary:
	return {"case": [x, y], "rayon": rayon, "intensite": 1.2}


## Un PNJ qui erre dans sa zone ; équipé de la nappe de braises de l'Incendiaire à partir de 5.7.
func _zone(profil: String, rect: Array, equipe: bool = false) -> Dictionary:
	var p := {"profil": profil, "zone": rect}
	if equipe:
		p["classe"] = CLASSE
		p["equipe"] = true
	return p


## Un PNJ de ronde, équipé de même.
func _ronde(profil: String, points: Array, equipe: bool = false) -> Dictionary:
	var p := {"profil": profil, "ronde": points}
	if equipe:
		p["classe"] = CLASSE
		p["equipe"] = true
	return p


# ---------------------------------------------------------------------------
# LES DIX SALLES
# ---------------------------------------------------------------------------

## 5.1 — Le binôme : une pièce double, deux moitiés qu'une cloison sépare à peine — une large ouverture, sous une lampe. Un gardien dans chaque moitié, deux zones qui se
## recouvrent au milieu : ils se voient, et ce que l'un voit dans l'ouverture, l'autre le voit aussi.
func _salle_01() -> Dictionary:
	var g := Commune.Grille.new(30, 18)
	g.rect(14, 1, 2, 16, "#")
	g.rect(14, 5, 2, 8, ".")
	g.poser(2, 16, "J")
	g.poser(5, 8, "1")
	g.poser(24, 8, "2")
	return {
		"titre": "Le binôme",
		"intention": "Une pièce double, deux gardiens qui se voient d'un bout à l'autre. Ce que l'un surveille, l'autre le couvre.",
		"g": g, "orientation": -45,
		"pnj": [_zone("zone_voit_entend_facile", [1, 1, 17, 16]), _zone("zone_voit_entend_facile", [12, 1, 17, 16])],
		"lampes": [_lampe(14, 8, 4.5)],
	}


## 5.2 — Ronde et escorte : un couloir en boucle autour d'un bloc. Une ronde en fait le tour ; un gardien tient l'angle nord-est, là où elle passe. On part d'une niche creusée dans
## le bloc, côté ouest.
func _salle_02() -> Dictionary:
	var g := Commune.Grille.new(28, 20)
	g.rect(7, 5, 14, 10, "#")
	g.rect(7, 9, 3, 3, ".")
	g.poser(8, 10, "J")
	g.poser(23, 6, "1")
	return {
		"titre": "Ronde et escorte",
		"intention": "Un couloir en boucle, une ronde qui en fait le tour. Un gardien tient l'angle où elle passe.",
		"g": g, "orientation": 0,
		"pnj": [
			_zone("zone_voit_entend_facile", [14, 1, 13, 10]),
			_ronde("ronde_voit_entend_facile", [[3, 3], [24, 3], [24, 17], [3, 17]]),
		],
		"lampes": [_lampe(22, 3, 3.5), _lampe(3, 15, 3.5)],
	}


## 5.3 — Le premier tir : une salle ouverte, trois piliers, trois gardiens en triangle. L'un est sous une lampe, un autre aussi, le troisième dans le noir : on choisit.
func _salle_03() -> Dictionary:
	var g := Commune.Grille.new(36, 26)
	g.rect(9, 13, 2, 2, "#")
	g.rect(26, 13, 2, 2, "#")
	g.rect(17, 14, 2, 2, "#")
	g.poser(2, 22, "J")
	g.poser(6, 4, "1")
	g.poser(29, 4, "2")
	g.poser(17, 19, "3")
	return {
		"titre": "Le premier tir",
		"intention": "Une salle ouverte, trois gardiens en triangle. Le premier coup de feu les réveille tous : par qui commencer ?",
		"g": g, "orientation": -45,
		"pnj": [
			_zone("zone_voit_entend_facile", [1, 1, 20, 12]),
			_zone("zone_voit_entend_facile", [15, 1, 20, 12]),
			_zone("zone_voit_entend_facile", [8, 14, 20, 11]),
		],
		"lampes": [_lampe(8, 5, 3.5), _lampe(17, 21, 4.0)],
	}


## 5.4 — La couverture : une galerie, deux blocs, une ronde autour de chacun. Au bout, un poste immobile tient la galerie sous sa lampe ; il couvre une ronde mieux que l'autre.
func _salle_04() -> Dictionary:
	var g := Commune.Grille.new(40, 16)
	g.rect(8, 5, 6, 6, "#")
	g.rect(21, 5, 6, 6, "#")
	g.poser(2, 8, "J")
	g.poser(37, 8, "1")
	return {
		"titre": "La couverture",
		"intention": "Une galerie, deux rondes, et au bout un poste qui regarde. Il couvre l'une mieux que l'autre.",
		"g": g, "orientation": 0,
		"pnj": [
			_ronde("ronde_voit_entend_facile", [[6, 3], [15, 3], [15, 12], [6, 12]]),
			_ronde("ronde_voit_entend_facile", [[19, 3], [28, 3], [28, 12], [19, 12]]),
			{"profil": "immobile_voit_normal", "orientation": 180},
		],
		"lampes": [_lampe(36, 8, 4.5), _lampe(17, 8, 4.0)],
	}


## 5.5 — Séparer : deux salles reliées par une porte. Dans la grande, deux gardiens dont les zones se recouvrent ; dans la petite, au bout, un troisième, dont la zone mord sur la
## grande par la porte. Un bruit au fond de la petite salle n'appelle que lui.
func _salle_05() -> Dictionary:
	var g := Commune.Grille.new(40, 20)
	g.rect(24, 1, 2, 18, "#")
	g.rect(24, 8, 2, 4, ".")
	g.poser(2, 17, "J")
	g.poser(5, 6, "1")
	g.poser(17, 12, "2")
	g.poser(33, 15, "3")
	return {
		"titre": "Séparer",
		"intention": "Deux salles. Dans la grande, deux gardiens qui se couvrent ; dans la petite, un troisième, tout seul.",
		"g": g, "orientation": -45,
		"pnj": [
			_zone("zone_voit_entend_facile", [1, 1, 14, 18]),
			_zone("zone_voit_entend_facile", [10, 1, 14, 18]),
			_zone("zone_voit_entend_facile", [18, 1, 21, 18]),
		],
		"lampes": [_lampe(6, 6, 3.5), _lampe(16, 11, 3.5)],
	}


## 5.6 — Le passage brûlant : une forge. Deux halls, un seul passage de trois cases de large, quinze de long, sous une lampe. Un gardien par hall, une ronde qui traverse le passage
## dans un sens puis dans l'autre. Une nappe de braises (136 px) le ferme d'un mur à l'autre.
func _salle_06() -> Dictionary:
	var g := Commune.Grille.new(44, 18)
	g.rect(15, 1, 15, 16, "#")
	g.rect(15, 8, 15, 3, ".")
	g.poser(2, 16, "J")
	g.poser(8, 5, "1")
	g.poser(37, 12, "2")
	return {
		"titre": "Le passage brûlant",
		"intention": "Une forge, deux halls, un seul passage. Ce qu'on y jette le ferme d'un mur à l'autre.",
		"g": g, "orientation": 0,
		"pnj": [
			_zone("zone_voit_entend_facile", [1, 1, 14, 11]),
			_zone("zone_voit_entend_facile", [30, 1, 13, 16]),
			_ronde("ronde_voit_entend_facile", [[5, 3], [39, 3], [39, 13], [5, 13]]),
		],
		"lampes": [_lampe(8, 5, 3.5), _lampe(22, 9, 3.5), _lampe(36, 11, 3.5)],
	}


## 5.7 — Le groupe vif : une salle à colonnes. Deux gardiens aux réflexes NORMAUX, deux zones qui se recouvrent au milieu, deux lampes. Ils portent l'Incendiaire et sa nappe de braises.
func _salle_07() -> Dictionary:
	var g := Commune.Grille.new(36, 22)
	for x in [6, 13, 22, 29]:
		g.rect(x, 4, 2, 2, "#")
		g.rect(x, 15, 2, 2, "#")
	g.rect(17, 9, 2, 3, "#")
	g.poser(17, 20, "J")
	g.poser(9, 10, "1")
	g.poser(26, 10, "2")
	return {
		"titre": "Le groupe vif",
		"intention": "Une salle à colonnes. Deux gardiens, un seul groupe : ils tirent plus vite, et ce qu'ils sèment brûle.",
		"g": g, "orientation": -90,
		"pnj": [
			_zone("zone_voit_entend_normal", [1, 1, 20, 18], true),
			_zone("zone_voit_entend_normal", [15, 1, 20, 18], true),
		],
		"lampes": [_lampe(14, 10, 4.5), _lampe(21, 10, 4.5)],
	}


## 5.8 — Le carrefour : une croix. Une ronde dans le bras ouest, une dans le bras est, un gardien dans le bras nord, un dans le sud ; au centre, un poste qui voit les quatre bras.
## Les deux rondes ont le même tour, en miroir, et ne se rencontrent jamais.
func _salle_08() -> Dictionary:
	var g := Commune.Grille.new(32, 32)
	g.rect(1, 1, 11, 11, "#")
	g.rect(20, 1, 11, 11, "#")
	g.rect(1, 20, 11, 11, "#")
	g.rect(20, 20, 11, 11, "#")
	g.poser(15, 30, "J")
	g.poser(15, 5, "1")
	g.poser(16, 24, "2")
	g.poser(15, 15, "3")
	return {
		"titre": "Le carrefour",
		"intention": "Une croix, quatre bras, un groupe dans chacun. Au centre, un poste voit les quatre.",
		"g": g, "orientation": -90,
		"pnj": [
			_zone("zone_voit_entend_facile", [12, 1, 8, 10], true),
			_zone("zone_voit_entend_facile", [12, 21, 8, 8], true),
			{"profil": "immobile_voit_entend_normal", "orientation": 90},
			_ronde("ronde_voit_entend_facile", [[2, 13], [11, 13], [11, 18], [2, 18]], true),
			_ronde("ronde_voit_entend_facile", [[29, 13], [20, 13], [20, 18], [29, 18]], true),
		],
		"lampes": [_lampe(15, 16, 4.5), _lampe(6, 15, 3.5), _lampe(25, 16, 3.5)],
	}


## 5.9 — La salle pleine : une grande halle, trois groupes. Au nord-ouest et au nord-est, un gardien et une ronde qui lui passe dessus ; au sud, un gardien seul. Tous portent l'Incendiaire.
func _salle_09() -> Dictionary:
	var g := Commune.Grille.new(44, 34)
	g.rect(20, 9, 4, 2, "#")
	g.rect(9, 27, 3, 2, "#")
	g.rect(32, 27, 3, 2, "#")
	g.rect(8, 8, 2, 2, "#")
	g.rect(34, 8, 2, 2, "#")
	g.poser(3, 30, "J")
	g.poser(6, 6, "1")
	g.poser(37, 6, "2")
	g.poser(22, 27, "3")
	return {
		"titre": "La salle pleine",
		"intention": "Une grande halle, trois groupes. Deux gardiens avec leur ronde, un seul sans. Toucher l'un réveille ses voisins.",
		"g": g, "orientation": -45,
		"pnj": [
			_zone("zone_voit_entend_facile", [1, 1, 16, 14], true),
			_zone("zone_voit_entend_facile", [27, 1, 16, 14], true),
			_zone("zone_voit_entend_facile", [14, 22, 16, 11], true),
			_ronde("ronde_voit_entend_normal", [[3, 4], [15, 4], [15, 16], [3, 16]], true),
			_ronde("ronde_voit_entend_normal", [[40, 4], [28, 4], [28, 16], [40, 16]], true),
		],
		"lampes": [_lampe(6, 6, 3.5), _lampe(37, 6, 3.5), _lampe(22, 27, 4.0), _lampe(21, 15, 4.0)],
	}


## 5.10 — L'Incendiaire : l'arène du chapitre 0, variée — quatre piliers verticaux de 2 × 5 aux quatre coins, des murets en rangée au nord et au sud du centre, deux murets
## de chaque côté. Symétrique d'est en ouest et du nord au sud ; les deux lampes se font face.
func _salle_10() -> Dictionary:
	var g := Commune.Grille.new(32, 32)
	g.rect_miroirs(7, 5, 2, 5, "#")
	g.rect_miroirs(13, 10, 6, 1, "~")
	g.rect_miroir_x(11, 14, 1, 4, "~")
	g.poser(3, 16, "J")
	g.poser(28, 16, "1")
	return {
		"titre": "L'Incendiaire",
		"intention": "Un duel dans une arène. Entre vous, des braises : on ne s'y attarde pas.",
		"boss": true,
		"g": g, "orientation": 0,
		"pnj": [{"profil": "boss", "classe": CLASSE}],
		"lampes": [_lampe(10, 16, 4.5), _lampe(21, 16, 4.5)],
	}
