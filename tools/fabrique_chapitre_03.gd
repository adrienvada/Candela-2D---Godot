## Fabrique le chapitre 3 de l'aventure, « Les zones » — chantier SOLO, étape S8.
##
## Dix salles dans `res://assets/solo/chapitre_03/` : le manifeste (`chapitre.json`, qui débloque le Braconnier, slug `arbalete`) et `niveau_01.json` … `niveau_10.json`.
## Plus de trajet à lire : chaque PNJ erre librement dans une ZONE — un rectangle de cases, qui contient sa case de départ —, va voir d'où vient un bruit, poursuit
## jusqu'à la limite de sa zone et pas au-delà. On apprend à jouer avec ces frontières. **À partir de 3.7, les gardiens portent la classe du boss et sa torche
## fantôme** (`"equipe": true`, S8) : on apprend qu'une lumière n'est pas toujours quelqu'un.
##
## ⚠️ **Un écart au plan, et pourquoi.** Le plan écrivait des gardiens `zone_voit_facile` (qui VOIENT, sans entendre) pour tout le chapitre. La torche fantôme se pose
## EN ENQUÊTE sur un son (`EquipementBot.GADGETS`) : un gardien qui n'entend pas n'enquête jamais, et « equipe » serait resté sans effet. Les gardiens équipés de 3.7
## à 3.9 sont donc `zone_voit_entend_facile` — la garde le vérifie (`GADGET_EXIGE`). Les salles 3.1 à 3.6 gardent `zone_voit_facile`.
##
## Le dessin et l'écriture sont ceux de `fabrique_commune.gd` ; ce fichier ne contient que les salles, et `tools/test_chapitre_03.gd` mesure sur leurs JSON ce que chacune
## ENSEIGNE. **Les JSON sont la vérité du jeu, ce script n'est que la façon dont on les a écrits.**
##
## Lancer : godot --headless --path . --script res://tools/fabrique_chapitre_03.gd
extends SceneTree

const Commune := preload("res://tools/fabrique_commune.gd")

const DOSSIER := "res://assets/solo/chapitre_03"
const CLASSE := "arbalete"


func _init() -> void:
	var salles: Array[Dictionary] = [
		_salle_01(), _salle_02(), _salle_03(), _salle_04(), _salle_05(),
		_salle_06(), _salle_07(), _salle_08(), _salle_09(), _salle_10(),
	]
	Commune.fabriquer(DOSSIER, 3, "Les zones", CLASSE, "Les zones", salles)
	quit()


func _lampe(x: int, y: int, rayon: float) -> Dictionary:
	return {"case": [x, y], "rayon": rayon, "intensite": 1.2}


## Un gardien qui erre dans sa zone ; équipé de la torche fantôme du Braconnier à partir de 3.7 (le gardien équipé entend : voir l'en-tête).
func _zone(profil: String, rect: Array, equipe: bool = false) -> Dictionary:
	var p := {"profil": profil, "zone": rect}
	if equipe:
		p["classe"] = CLASSE
		p["equipe"] = true
	return p


# ---------------------------------------------------------------------------
# LES DIX SALLES
# ---------------------------------------------------------------------------

## 3.1 — Une pièce gardée : un hall où l'on entre, une cloison, une porte, et derrière, la pièce du gardien — sa zone — sous une lampe. Il y erre sans trajet.
func _salle_01() -> Dictionary:
	var g := Commune.Grille.new(30, 20)
	g.rect(12, 1, 2, 18, "#")
	g.rect(12, 8, 2, 4, ".")
	g.rect(18, 12, 2, 2, "#")
	g.poser(2, 9, "J")
	g.poser(21, 5, "1")
	return {
		"titre": "Une pièce gardée",
		"intention": "Une pièce, une porte. Quelqu'un y erre, sans trajet, et voit ce qui s'éclaire.",
		"g": g, "orientation": 0,
		"pnj": [_zone("zone_voit_facile", [14, 1, 15, 18])],
		"lampes": [_lampe(21, 9, 4.5)],
	}


## 3.2 — La frontière : deux pièces en enfilade, une porte entre elles. Le gardien erre dans la première, sa zone s'arrête au seuil ; le joueur part dans la seconde,
## hors de sa zone. Un chemin sort de la zone, le gardien n'y va pas.
func _salle_02() -> Dictionary:
	var g := Commune.Grille.new(34, 16)
	g.rect(16, 1, 2, 14, "#")
	g.rect(16, 6, 2, 4, ".")
	g.poser(28, 8, "J")
	g.poser(7, 8, "1")
	return {
		"titre": "La frontière",
		"intention": "Deux pièces en enfilade. Il va jusqu'à la porte, pas au-delà.",
		"g": g, "orientation": 180,
		"pnj": [_zone("zone_voit_facile", [1, 1, 15, 14])],
		"lampes": [_lampe(12, 8, 3.5)],
	}


## 3.3 — Deux pièces : un couloir entre deux salles, un gardien dans chacune. Les deux zones sont voisines, le couloir n'est dans aucune.
func _salle_03() -> Dictionary:
	var g := Commune.Grille.new(36, 16)
	g.rect(13, 1, 10, 5, "#")
	g.rect(13, 10, 10, 5, "#")
	g.poser(17, 7, "J")
	g.poser(6, 7, "1")
	g.poser(29, 8, "2")
	return {
		"titre": "Deux pièces",
		"intention": "Un couloir entre deux salles, un gardien dans chacune. Chacun garde la sienne.",
		"g": g, "orientation": 0,
		"pnj": [_zone("zone_voit_facile", [1, 1, 12, 14]), _zone("zone_voit_facile", [23, 1, 12, 14])],
		"lampes": [_lampe(5, 8, 3.5), _lampe(30, 8, 3.5)],
	}


## 3.4 — La zone sombre : un sous-sol à colonnes, aucune lampe. Deux gardiens qui voient, chacun dans sa zone : sans lumière, ils ne voient que ce qu'une torche leur montre.
func _salle_04() -> Dictionary:
	var g := Commune.Grille.new(30, 24)
	g.rect(8, 8, 2, 2, "#")
	g.rect(20, 8, 2, 2, "#")
	g.rect(8, 15, 2, 2, "#")
	g.rect(20, 15, 2, 2, "#")
	g.rect(14, 11, 2, 2, "#")
	g.poser(3, 20, "J")
	g.poser(5, 4, "1")
	g.poser(23, 18, "2")
	return {
		"titre": "La zone sombre",
		"intention": "Un sous-sol sans une lampe. Ils ne voient que ce qu'une torche leur montre.",
		"g": g, "orientation": -45,
		"pnj": [_zone("zone_voit_facile", [1, 1, 13, 10]), _zone("zone_voit_facile", [16, 13, 13, 10])],
		"lampes": [],
	}


## 3.5 — Zones et rondes : un atelier. Deux gardiens errent chacun dans une zone, une ronde fait le tour d'un bloc et passe dans les deux zones.
func _salle_05() -> Dictionary:
	var g := Commune.Grille.new(34, 24)
	g.rect(13, 8, 8, 8, "#")
	g.poser(2, 21, "J")
	g.poser(5, 4, "1")
	g.poser(28, 19, "2")
	return {
		"titre": "Zones et rondes",
		"intention": "Un atelier. Deux gardiens errent chez eux, une ronde passe de l'un à l'autre.",
		"g": g, "orientation": -45,
		"pnj": [
			_zone("zone_voit_facile", [2, 2, 14, 8]),
			_zone("zone_voit_facile", [18, 14, 14, 8]),
			{"profil": "ronde_voit_lent", "ronde": [[10, 5], [23, 5], [23, 18], [10, 18]]},
		],
		"lampes": [_lampe(13, 5, 3.5), _lampe(21, 18, 3.5)],
	}


## 3.6 — Le poste avancé : un hall à colonnes. Un poste ne bouge pas, devant les zones de deux gardiens, et regarde entre les colonnes ce qui s'y passe.
func _salle_06() -> Dictionary:
	var g := Commune.Grille.new(34, 22)
	g.rect(14, 3, 2, 2, "#")
	g.rect(14, 17, 2, 2, "#")
	g.rect(21, 6, 2, 2, "#")
	g.rect(21, 14, 2, 2, "#")
	g.rect(28, 3, 2, 2, "#")
	g.rect(28, 17, 2, 2, "#")
	g.rect(28, 10, 2, 2, "#")
	g.poser(2, 10, "J")
	g.poser(11, 10, "1")
	g.poser(25, 5, "2")
	g.poser(25, 16, "3")
	return {
		"titre": "Le poste avancé",
		"intention": "Un poste, devant les zones de deux gardiens. Il regarde entre les colonnes.",
		"g": g, "orientation": 0,
		"pnj": [
			{"profil": "immobile_voit_facile", "orientation": 0},
			_zone("zone_voit_facile", [17, 1, 16, 9]),
			_zone("zone_voit_facile", [17, 12, 16, 9]),
		],
		"lampes": [_lampe(11, 10, 3.5), _lampe(23, 10, 4.0)],
	}


## 3.7 — La lumière qui ment : un long hangar, une lampe tout au fond. Trois gardiens se partagent la longueur, chacun sa zone ; ils portent le Braconnier, dont la
## torche fantôme est une lampe sans personne dessous.
func _salle_07() -> Dictionary:
	var g := Commune.Grille.new(48, 16)
	g.rect(11, 3, 2, 2, "#")
	g.rect(11, 11, 2, 2, "#")
	g.rect(26, 3, 2, 2, "#")
	g.rect(26, 11, 2, 2, "#")
	g.poser(2, 8, "J")
	g.poser(9, 8, "1")
	g.poser(22, 8, "2")
	g.poser(38, 8, "3")
	return {
		"titre": "La lumière qui ment",
		"intention": "Un long hangar, une lampe tout au fond. Toute lumière n'est pas quelqu'un.",
		"g": g, "orientation": 0,
		"pnj": [
			_zone("zone_voit_entend_facile", [5, 1, 11, 14], true),
			_zone("zone_voit_entend_facile", [17, 1, 14, 14], true),
			_zone("zone_voit_entend_facile", [32, 1, 15, 14], true),
		],
		"lampes": [_lampe(44, 8, 4.5)],
	}


## 3.8 — Les quartiers : quatre pièces en damier, de part et d'autre d'une croix de cloisons percée de quatre portes. Un gardien par pièce ; deux lampes aux deux
## pièces opposées, les deux autres restent noires.
func _salle_08() -> Dictionary:
	var g := Commune.Grille.new(28, 24)
	g.rect(13, 1, 2, 22, "#")
	g.rect(1, 11, 26, 2, "#")
	g.rect(13, 4, 2, 3, ".")
	g.rect(13, 16, 2, 3, ".")
	g.rect(5, 11, 3, 2, ".")
	g.rect(19, 11, 3, 2, ".")
	g.poser(14, 17, "J")
	g.poser(6, 5, "1")
	g.poser(20, 5, "2")
	g.poser(6, 18, "3")
	g.poser(20, 18, "4")
	return {
		"titre": "Les quartiers",
		"intention": "Quatre pièces en damier, deux lampes. Chaque gardien reste chez lui.",
		"g": g, "orientation": 0,
		"pnj": [
			_zone("zone_voit_entend_facile", [1, 1, 12, 10], true),
			_zone("zone_voit_entend_facile", [15, 1, 12, 10], true),
			_zone("zone_voit_entend_facile", [1, 13, 12, 10], true),
			_zone("zone_voit_entend_facile", [15, 13, 12, 10], true),
		],
		"lampes": [_lampe(8, 6, 3.5), _lampe(20, 17, 3.5)],
	}


## 3.9 — La salle pleine : un grand entrepôt. Quatre gardiens, un par angle, chacun sa zone ; une ronde passe entre eux, dans la bande du milieu. Trois lampes.
func _salle_09() -> Dictionary:
	var g := Commune.Grille.new(44, 34)
	g.rect(9, 6, 2, 2, "#")
	g.rect(31, 6, 2, 2, "#")
	g.rect(9, 25, 2, 2, "#")
	g.rect(31, 25, 2, 2, "#")
	g.rect(18, 16, 8, 2, "#")
	g.poser(21, 31, "J")
	g.poser(7, 9, "1")
	g.poser(36, 9, "2")
	g.poser(7, 27, "3")
	g.poser(36, 27, "4")
	return {
		"titre": "La salle pleine",
		"intention": "Un grand entrepôt. Chaque gardien a sa zone, et une ronde passe entre elles.",
		"g": g, "orientation": -90,
		"pnj": [
			_zone("zone_voit_entend_facile", [2, 2, 18, 12], true),
			_zone("zone_voit_entend_facile", [24, 2, 18, 12], true),
			_zone("zone_voit_entend_facile", [2, 20, 18, 12], true),
			_zone("zone_voit_entend_facile", [24, 20, 18, 12], true),
			{"profil": "ronde_voit_entend_facile", "ronde": [[6, 15], [37, 15], [37, 18], [6, 18]], "classe": CLASSE, "equipe": true},
		],
		"lampes": [_lampe(11, 10, 3.5), _lampe(34, 25, 3.5), _lampe(21, 15, 4.0)],
	}


## 3.10 — Le Braconnier : l'arène du chapitre 0, variée — quatre piliers aux coins du centre, des cloisons courtes au nord et au sud, des murets en travers de la voie
## du milieu. Symétrique d'est en ouest et du nord au sud ; les deux lampes se font face.
func _salle_10() -> Dictionary:
	var g := Commune.Grille.new(32, 32)
	g.rect_miroirs(9, 9, 2, 2, "#")
	g.rect_miroirs(14, 5, 4, 1, "#")
	g.rect_miroir_x(14, 15, 1, 2, "~")
	g.poser(3, 16, "J")
	g.poser(28, 16, "1")
	return {
		"titre": "Le Braconnier",
		"intention": "Un duel dans une arène. Il laisse des lampes derrière lui.",
		"boss": true,
		"g": g, "orientation": 0,
		"pnj": [{"profil": "boss", "classe": CLASSE}],
		"lampes": [_lampe(10, 16, 4.5), _lampe(21, 16, 4.5)],
	}
