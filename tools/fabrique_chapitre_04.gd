## Fabrique le chapitre 4 de l'aventure, « Les zones écoutent » — chantier SOLO, étape S8 (lot 2).
##
## Dix salles dans `res://assets/solo/chapitre_04/` : le manifeste (`chapitre.json`, qui débloque le Terrassier, slug `pompe`) et `niveau_01.json` … `niveau_10.json`.
## Les gardiens du chapitre 3 VOYAIENT chez eux ; ceux-ci ENTENDENT. Un bruit les fait converger vers la frontière de leur zone : on apprend à s'approcher accroupi,
## à placer son bruit, à passer entre deux zones sans se faire entendre. **À partir de 4.7, les gardiens portent la classe du boss et sa poussière** (`"equipe": true`,
## S8) : on apprend ce qu'un nuage qui trouble la vue fait de la lumière avant de l'affronter.
##
## ⚠️ **Ce que la règle de la poussière demande** (`EquipementBot.GADGETS`) : elle se pose EN ENQUÊTE ou EN RECHERCHE, sur un son, à 200-380 px de la place visée, que le
## bot n'a PAS vue. Un gardien équipé doit donc ENTENDRE — tous ceux de 4.7 à 4.9 entendent, comme le plan les voulait. La salle 4.6 est ouverte parce que le nuage fait 336 px
## de large : il lui faut du sol.
##
## Le dessin et l'écriture sont ceux de `fabrique_commune.gd` ; ce fichier ne contient que les salles, et `tools/test_chapitre_04.gd` mesure sur leurs JSON ce que chacune
## ENSEIGNE. **Les JSON sont la vérité du jeu, ce script n'est que la façon dont on les a écrits.**
##
## Lancer : godot --headless --path . --script res://tools/fabrique_chapitre_04.gd
extends SceneTree

const Commune := preload("res://tools/fabrique_commune.gd")

const DOSSIER := "res://assets/solo/chapitre_04"
const CLASSE := "pompe"


func _init() -> void:
	var salles: Array[Dictionary] = [
		_salle_01(), _salle_02(), _salle_03(), _salle_04(), _salle_05(),
		_salle_06(), _salle_07(), _salle_08(), _salle_09(), _salle_10(),
	]
	Commune.fabriquer(DOSSIER, 4, "Les zones écoutent", CLASSE, "Les zones écoutent", salles)
	quit()


func _lampe(x: int, y: int, rayon: float) -> Dictionary:
	return {"case": [x, y], "rayon": rayon, "intensite": 1.2}


## Un gardien qui erre dans sa zone ; équipé de la poussière du Terrassier à partir de 4.7 (le gardien équipé entend : voir l'en-tête).
func _zone(profil: String, rect: Array, equipe: bool = false) -> Dictionary:
	var p := {"profil": profil, "zone": rect}
	if equipe:
		p["classe"] = CLASSE
		p["equipe"] = true
	return p


# ---------------------------------------------------------------------------
# LES DIX SALLES
# ---------------------------------------------------------------------------

## 4.1 — Une pièce qui écoute : un hall où l'on entre, une cloison, une porte, et derrière, la pièce du gardien — sa zone — sous une lampe. Il n'a pas d'yeux : il
## entend. Le hall est assez long pour qu'on s'y arrête, accroupi, à une portée où la pièce s'éclaire à la torche et où l'on n'est pas entendu.
func _salle_01() -> Dictionary:
	var g := Commune.Grille.new(30, 18)
	g.rect(12, 1, 2, 16, "#")
	g.rect(12, 7, 2, 4, ".")
	g.rect(19, 4, 2, 2, "#")
	g.rect(19, 12, 2, 2, "#")
	g.poser(3, 8, "J")
	g.poser(25, 8, "1")
	return {
		"titre": "Une pièce qui écoute",
		"intention": "Il n'a pas d'yeux, il écoute. Un pas debout s'entend de la porte, un pas accroupi à peine.",
		"g": g, "orientation": 0,
		"pnj": [_zone("zone_entend_facile", [14, 1, 15, 16])],
		"lampes": [_lampe(23, 8, 4.0)],
	}


## 4.2 — Le réveil : trois pièces en ligne, un couloir au sud qui les dessert toutes. Un gardien par pièce. Un pas n'est entendu que de la pièce d'à côté ; un tir, de
## toutes — et chacune se tient à une porte du couloir.
func _salle_02() -> Dictionary:
	var g := Commune.Grille.new(40, 16)
	g.rect(1, 11, 38, 1, "#")
	g.rect(13, 1, 1, 10, "#")
	g.rect(26, 1, 1, 10, "#")
	g.rect(13, 4, 1, 4, ".")
	g.rect(26, 4, 1, 4, ".")
	g.rect(5, 11, 4, 1, ".")
	g.rect(18, 11, 4, 1, ".")
	g.rect(31, 11, 4, 1, ".")
	g.poser(20, 13, "J")
	g.poser(6, 5, "1")
	g.poser(20, 5, "2")
	g.poser(33, 5, "3")
	return {
		"titre": "Le réveil",
		"intention": "Trois pièces en ligne, un couloir qui les dessert. Un coup de feu les réveille toutes.",
		"g": g, "orientation": -90,
		"pnj": [
			_zone("zone_entend_facile", [1, 1, 12, 10]),
			_zone("zone_entend_facile", [14, 1, 12, 10]),
			_zone("zone_entend_facile", [27, 1, 12, 10]),
		],
		"lampes": [_lampe(7, 6, 3.5), _lampe(32, 6, 3.5)],
	}


## 4.3 — Le chemin silencieux : un couloir entre deux longues pièces, un gardien dans chacune. Debout, on est entendu tout du long ; accroupi, on passe.
func _salle_03() -> Dictionary:
	var g := Commune.Grille.new(38, 19)
	g.rect(1, 6, 36, 1, "#")
	g.rect(1, 13, 36, 1, "#")
	g.rect(8, 6, 4, 1, ".")
	g.rect(26, 6, 4, 1, ".")
	g.rect(8, 13, 4, 1, ".")
	g.rect(26, 13, 4, 1, ".")
	g.poser(2, 10, "J")
	g.poser(30, 3, "1")
	g.poser(7, 16, "2")
	return {
		"titre": "Le chemin silencieux",
		"intention": "Un couloir entre deux pièces qui écoutent. On ne passe pas debout, on ne passe pas en courant.",
		"g": g, "orientation": 0,
		"pnj": [_zone("zone_entend_facile", [1, 1, 36, 5]), _zone("zone_entend_facile", [1, 14, 36, 4])],
		"lampes": [_lampe(27, 3, 4.0)],
	}


## 4.4 — Les deux sens : deux salles, un palier entre elles. Un gardien dans chacune, qui voit et entend ; la lampe de chaque salle n'en éclaire qu'une part. Dans la
## flaque, on est vu ; dans le noir, on n'est qu'entendu.
func _salle_04() -> Dictionary:
	var g := Commune.Grille.new(34, 18)
	g.rect(13, 1, 1, 16, "#")
	g.rect(20, 1, 1, 16, "#")
	g.rect(13, 6, 1, 6, ".")
	g.rect(20, 6, 1, 6, ".")
	g.rect(16, 3, 2, 2, "#")
	g.rect(16, 13, 2, 2, "#")
	g.poser(16, 9, "J")
	g.poser(6, 8, "1")
	g.poser(27, 8, "2")
	return {
		"titre": "Les deux sens",
		"intention": "Deux salles, un palier. Les gardiens y voient ce qui s'éclaire et y entendent le reste.",
		"g": g, "orientation": 180,
		"pnj": [_zone("zone_voit_entend_facile", [1, 1, 12, 16]), _zone("zone_voit_entend_facile", [21, 1, 12, 16])],
		"lampes": [_lampe(6, 8, 3.5), _lampe(27, 13, 3.5)],
	}


## 4.5 — L'appât : une salle en L. Un gardien dans le bras nord, un dans le bras est ; à l'angle, hors des deux zones, une silhouette qui ne bouge pas, sous une lampe.
## De l'angle, on voit la frontière de chaque zone.
func _salle_05() -> Dictionary:
	var g := Commune.Grille.new(32, 26)
	g.rect(14, 1, 17, 10, "#")
	g.poser(3, 22, "J")
	g.poser(6, 5, "1")
	g.poser(26, 18, "2")
	g.poser(8, 16, "3")
	return {
		"titre": "L'appât",
		"intention": "Une salle en L. Quelqu'un attend à l'angle, immobile, sous une lampe. Les gardiens sont chacun dans un bras.",
		"g": g, "orientation": -45,
		"pnj": [
			_zone("zone_voit_entend_facile", [1, 1, 13, 10]),
			_zone("zone_voit_entend_facile", [20, 11, 11, 14]),
			{"profil": "immobile_sourd_aveugle"},
		],
		"lampes": [_lampe(8, 17, 3.5), _lampe(26, 16, 3.5)],
	}


## 4.6 — La poussière : une carrière. Un grand sol ouvert, quelques éboulis, trois gardiens chacun sa zone. Le nuage de poussière, qui fait 336 px de large, tient
## sans toucher un mur.
func _salle_06() -> Dictionary:
	var g := Commune.Grille.new(44, 30)
	g.rect(6, 8, 3, 2, "#")
	g.rect(15, 20, 2, 3, "#")
	g.rect(28, 6, 2, 3, "#")
	g.rect(35, 18, 3, 2, "#")
	g.rect(20, 12, 2, 2, "#")
	g.rect(10, 24, 3, 2, "#")
	g.rect(38, 8, 2, 2, "#")
	g.poser(2, 28, "J")
	g.poser(8, 5, "1")
	g.poser(35, 5, "2")
	g.poser(22, 22, "3")
	return {
		"titre": "La poussière",
		"intention": "Une carrière, du sol à perte de vue. Les gardiens y entendent loin, et y voient ce qu'on éclaire.",
		"g": g, "orientation": -45,
		"pnj": [
			_zone("zone_voit_entend_facile", [1, 1, 20, 13]),
			_zone("zone_voit_entend_facile", [23, 1, 20, 13]),
			_zone("zone_voit_entend_facile", [14, 16, 16, 13]),
		],
		"lampes": [_lampe(22, 18, 5.0)],
	}


## 4.7 — Poste et zones : une cour intérieure. Un guetteur tient la cour sous sa lampe, trois gardiens tiennent les ailes — l'ouest, l'est, le nord — et portent le
## Terrassier et sa poussière. On entre par le sud.
func _salle_07() -> Dictionary:
	var g := Commune.Grille.new(40, 30)
	g.rect(11, 6, 1, 18, "#")
	g.rect(28, 6, 1, 18, "#")
	g.rect(11, 6, 18, 1, "#")
	g.rect(11, 12, 1, 4, ".")
	g.rect(28, 12, 1, 4, ".")
	g.rect(17, 6, 4, 1, ".")
	g.poser(19, 27, "J")
	g.poser(5, 14, "1")
	g.poser(34, 14, "2")
	g.poser(19, 3, "3")
	g.poser(19, 10, "4")
	return {
		"titre": "Poste et zones",
		"intention": "Une cour, trois ailes. Un guetteur tient la cour, les gardiens tiennent les ailes.",
		"g": g, "orientation": -90,
		"pnj": [
			_zone("zone_voit_entend_facile", [1, 1, 10, 28], true),
			_zone("zone_voit_entend_facile", [29, 1, 10, 28], true),
			_zone("zone_voit_entend_facile", [12, 1, 16, 5], true),
			{"profil": "immobile_voit_entend_facile", "orientation": 90},
		],
		"lampes": [_lampe(19, 12, 4.5), _lampe(5, 14, 3.5), _lampe(34, 14, 3.5)],
	}


## 4.8 — Le dédale : un labyrinthe de murets, une cloison pleine au milieu et une porte. Quatre gardiens, deux par côté, dont les zones s'emboîtent : celle du premier
## contient celle du second. Un muret se franchit, mais pas par eux : ils contournent.
func _salle_08() -> Dictionary:
	var g := Commune.Grille.new(40, 28)
	g.rect(19, 1, 2, 26, "#")
	g.rect(19, 10, 2, 3, ".")
	# Ouest : cinq rangées de murets, une ouverture alternée à chaque bout.
	g.rect(5, 5, 14, 1, "~")
	g.rect(1, 9, 14, 1, "~")
	g.rect(5, 13, 14, 1, "~")
	g.rect(1, 17, 14, 1, "~")
	g.rect(5, 21, 14, 1, "~")
	# Est : leur image dans un miroir.
	g.rect(21, 5, 14, 1, "~")
	g.rect(25, 9, 14, 1, "~")
	g.rect(21, 13, 14, 1, "~")
	g.rect(25, 17, 14, 1, "~")
	g.rect(21, 21, 14, 1, "~")
	g.poser(19, 11, "J")
	g.poser(15, 23, "1")
	g.poser(6, 7, "2")
	g.poser(25, 3, "3")
	g.poser(33, 19, "4")
	return {
		"titre": "Le dédale",
		"intention": "Des murets en lacets, deux côtés, quatre gardiens. Chacun garde un bout du chemin, et certains en gardent deux.",
		"g": g, "orientation": 0,
		"pnj": [
			_zone("zone_voit_entend_facile", [1, 1, 18, 26], true),
			_zone("zone_voit_entend_facile", [1, 1, 18, 12], true),
			_zone("zone_voit_entend_facile", [21, 1, 18, 26], true),
			_zone("zone_voit_entend_facile", [21, 14, 18, 13], true),
		],
		"lampes": [_lampe(8, 11, 3.5), _lampe(31, 19, 3.5)],
	}


## 4.9 — La salle pleine : une grande halle, quatre pièces aux angles, une place au milieu. Un gardien par pièce, une ronde qui longe la place d'un bout à l'autre ; tous
## portent la poussière.
func _salle_09() -> Dictionary:
	var g := Commune.Grille.new(44, 34)
	# Les quatre pièces d'angle, chacune ouverte sur la place par une porte de quatre cases.
	g.rect(15, 1, 1, 12, "#")
	g.rect(28, 1, 1, 12, "#")
	g.rect(15, 21, 1, 12, "#")
	g.rect(28, 21, 1, 12, "#")
	g.rect(1, 13, 15, 1, "#")
	g.rect(28, 13, 15, 1, "#")
	g.rect(1, 20, 15, 1, "#")
	g.rect(28, 20, 15, 1, "#")
	g.rect(15, 5, 1, 4, ".")
	g.rect(28, 5, 1, 4, ".")
	g.rect(15, 25, 1, 4, ".")
	g.rect(28, 25, 1, 4, ".")
	# Deux piliers sur la place.
	g.rect(20, 8, 2, 2, "#")
	g.rect(22, 24, 2, 2, "#")
	g.poser(21, 31, "J")
	g.poser(7, 6, "1")
	g.poser(36, 6, "2")
	g.poser(7, 27, "3")
	g.poser(36, 27, "4")
	return {
		"titre": "La salle pleine",
		"intention": "Une grande halle, quatre pièces, une place. Tout le quartier écoute.",
		"g": g, "orientation": -90,
		"pnj": [
			_zone("zone_voit_entend_facile", [1, 1, 15, 12], true),
			_zone("zone_voit_entend_facile", [28, 1, 15, 12], true),
			_zone("zone_voit_entend_facile", [1, 21, 15, 12], true),
			_zone("zone_voit_entend_facile", [28, 21, 15, 12], true),
			{"profil": "ronde_voit_entend_facile", "ronde": [[18, 3], [25, 3], [25, 30], [18, 30]], "classe": CLASSE, "equipe": true},
		],
		"lampes": [_lampe(8, 6, 3.5), _lampe(35, 27, 3.5), _lampe(21, 16, 5.0)],
	}


## 4.10 — Le Terrassier : l'arène du chapitre 0, variée — quatre éboulis de 3 × 3 aux coins du centre, deux longs pans de mur au nord et au sud, des murets en travers de
## la voie du milieu. Symétrique d'est en ouest et du nord au sud ; les deux lampes se font face.
func _salle_10() -> Dictionary:
	var g := Commune.Grille.new(32, 32)
	g.rect_miroirs(8, 8, 3, 3, "#")
	g.rect_miroirs(13, 3, 6, 1, "#")
	g.rect_miroirs(14, 14, 1, 1, "~")
	g.rect_miroir_x(12, 15, 2, 2, "~")
	g.poser(3, 16, "J")
	g.poser(28, 16, "1")
	return {
		"titre": "Le Terrassier",
		"intention": "Un duel dans une arène. Il lève la poussière, et il y voit mieux que vous.",
		"boss": true,
		"g": g, "orientation": 0,
		"pnj": [{"profil": "boss", "classe": CLASSE}],
		"lampes": [_lampe(10, 16, 4.5), _lampe(21, 16, 4.5)],
	}
