## Fabrique le chapitre 8 de l'aventure, « Les grandes salles » — chantier SOLO, étape S8, lot 2.
##
## Dix salles dans `res://assets/solo/chapitre_08/` : le manifeste (`chapitre.json`, qui débloque l'Allumeur, slug `allumeur`) et `niveau_01.json` … `niveau_10.json`.
## **Des salles vraiment grandes** (Adrien, 2026-10-03 : « toute liberté sur la taille des cartes ») : de 54 × 46 à 100 × 80 cases, quand la plus grande carte de duel livrée en
## compte 32 × 32. On y mêle tout ce que les chapitres d'avant ont appris à lire — des postes, des rondes, des zones, des chasseurs libres — sous beaucoup de plafonniers, et
## on y apprend à choisir son chemin et son ordre : un PNJ n'est jamais seul, et la salle est trop vaste pour qu'on les aille tous voir. **À partir de 8.7, les PNJ qui bougent
## portent la classe du boss et sa mine au magnésium** (`"equipe": true`, S8) : le flash qui aveugle et révèle dans 460 px, poseur compris.
##
## La mine se pose « en enquête, sur une place qu'on n'a pas vue, à 250-450 px » (`EquipementBot.GADGETS`) : un PNJ équipé doit ENTENDRE. Tous les PNJ de ce chapitre voient et
## entendent (`*_voit_entend_normal`), sauf les deux postes sourds du bunker (`immobile_entend_normal`) ; la garde (`GADGET_EXIGE_CHASSEURS`) l'exige.
##
## **Les rondes d'une salle ont la même longueur ou ne se touchent jamais** (le défaut de 2.8, trouvé par la marche du vrai corps : deux tours de longueurs inégales finissent par
## se frôler). Ici chaque salle donne à ses rondes des tours de même dimension, disjoints de plusieurs cases.
##
## Le dessin et l'écriture sont ceux de `fabrique_commune.gd` ; ce fichier ne contient que les salles, et `tools/test_chapitre_08.gd` mesure sur leurs JSON ce que chacune
## ENSEIGNE. **Les JSON sont la vérité du jeu, ce script n'est que la façon dont on les a écrits.**
##
## Lancer : godot --headless --path . --script res://tools/fabrique_chapitre_08.gd
extends SceneTree

const Commune := preload("res://tools/fabrique_commune.gd")

const DOSSIER := "res://assets/solo/chapitre_08"
const CLASSE := "allumeur"


func _init() -> void:
	var salles: Array[Dictionary] = [
		_salle_01(), _salle_02(), _salle_03(), _salle_04(), _salle_05(),
		_salle_06(), _salle_07(), _salle_08(), _salle_09(), _salle_10(),
	]
	Commune.fabriquer(DOSSIER, 8, "Les grandes salles", CLASSE, "Les grandes salles", salles)
	quit()


func _lampe(x: int, y: int, rayon: float) -> Dictionary:
	return {"case": [x, y], "rayon": rayon, "intensite": 1.2}


## Un PNJ du chapitre ; équipé de la mine de l'Allumeur à partir de 8.7.
func _pnj(profil: String, equipe: bool = false) -> Dictionary:
	var p := {"profil": profil}
	if equipe:
		p["classe"] = CLASSE
		p["equipe"] = true
	return p


func _ronde(points: Array, equipe: bool = false) -> Dictionary:
	var p := _pnj("ronde_voit_entend_normal", equipe)
	p["ronde"] = points
	return p


func _zone(rect: Array, equipe: bool = false) -> Dictionary:
	var p := _pnj("zone_voit_entend_normal", equipe)
	p["zone"] = rect
	return p


## Un rectangle de colonnes de 2 × 2, posées en grille régulière (pas `pas_x`, `pas_y`) dans le rectangle `(x, y, w, h)` : de quoi meubler une grande salle sans y tracer chaque
## colonne à la main. Les cases de `epargne` (des rectangles `[x, y, w, h]`) restent libres.
func _colonnes(g: Commune.Grille, x: int, y: int, w: int, h: int, pas_x: int, pas_y: int, epargne: Array = []) -> void:
	var cy := y
	while cy + 2 <= y + h:
		var cx := x
		while cx + 2 <= x + w:
			var ok := true
			for r: Array in epargne:
				if cx < int(r[0]) + int(r[2]) and cx + 2 > int(r[0]) and cy < int(r[1]) + int(r[3]) and cy + 2 > int(r[1]):
					ok = false
			if ok:
				g.rect(cx, cy, 2, 2, "#")
			cx += pas_x
		cy += pas_y


# ---------------------------------------------------------------------------
# LES DIX SALLES
# ---------------------------------------------------------------------------

## 8.1 — La place : 60 × 48. Une place ouverte, un bassin bas au milieu, six lampes ; deux rondes qui en font le tour de chaque côté, deux postes à l'ombre de leurs lampes. Le
## centre de la place est un couloir d'ombre entre les deux tours.
func _salle_01() -> Dictionary:
	var g := Commune.Grille.new(60, 48)
	g.rect(26, 21, 8, 6, "~")
	for x in [10, 19, 40, 49]:
		g.rect(x, 12, 2, 2, "#")
		g.rect(x, 34, 2, 2, "#")
	g.poser(30, 45, "J")
	g.poser(21, 24, "1")
	g.poser(38, 24, "2")
	return {
		"titre": "La place",
		"intention": "Une place ouverte, des lampes tout autour. Il faut la traverser, et ils la regardent.",
		"g": g, "orientation": -90,
		"pnj": [
			_pnj("immobile_voit_entend_normal"), _pnj("immobile_voit_entend_normal"),
			_ronde([[6, 6], [24, 6], [24, 40], [6, 40]]),
			_ronde([[35, 6], [53, 6], [53, 40], [35, 40]]),
		],
		"lampes": [_lampe(15, 6, 5.0), _lampe(44, 6, 5.0), _lampe(24, 24, 5.0), _lampe(35, 24, 5.0), _lampe(15, 40, 5.0), _lampe(44, 40, 5.0)],
	}


## 8.2 — Les ailes : 64 × 44. Un bâtiment en H — deux ailes de 22 sur 40 cases reliées par un pont —, quatre lampes. Dans chaque aile, un garde qui erre au nord et une ronde
## au sud ; le joueur part dans le pont, dans le noir. Il faut choisir son aile.
func _salle_02() -> Dictionary:
	var g := Commune.Grille.new(64, 44)
	g.rect(1, 1, 62, 42, "#")
	g.rect(2, 2, 22, 40, ".")
	g.rect(40, 2, 22, 40, ".")
	g.rect(24, 16, 16, 12, ".")
	g.rect(10, 27, 4, 4, "#")
	g.rect(50, 27, 4, 4, "#")
	g.rect(8, 9, 2, 2, "#")
	g.rect(54, 9, 2, 2, "#")
	g.rect(15, 13, 2, 2, "#")
	g.rect(47, 13, 2, 2, "#")
	g.poser(31, 21, "J")
	g.poser(12, 6, "1")
	g.poser(51, 6, "2")
	return {
		"titre": "Les ailes",
		"intention": "Deux ailes, un pont entre elles. Un garde au nord de chacune, une ronde au sud.",
		"g": g, "orientation": 0,
		"pnj": [
			_zone([2, 2, 22, 18]), _zone([40, 2, 22, 18]),
			_ronde([[5, 25], [20, 25], [20, 39], [5, 39]]),
			_ronde([[43, 25], [58, 25], [58, 39], [43, 39]]),
		],
		"lampes": [_lampe(12, 10, 4.5), _lampe(51, 10, 4.5), _lampe(12, 25, 4.5), _lampe(51, 39, 4.5)],
	}


## 8.3 — La galerie des lampes : 90 × 22. Une galerie de 90 cases, sept lampes, trois rondes qui en tiennent chacune un tiers. Des flaques au nord et au sud de chaque tour, la
## bande du milieu dans l'ombre — sauf au centre, où une septième lampe la ferme.
func _salle_03() -> Dictionary:
	var g := Commune.Grille.new(90, 22)
	g.rect(17, 10, 2, 2, "#")
	g.rect(71, 10, 2, 2, "#")
	g.rect(36, 9, 2, 4, "#")
	g.rect(50, 9, 2, 4, "#")
	g.poser(2, 11, "J")
	return {
		"titre": "La galerie des lampes",
		"intention": "Une galerie interminable, des flaques de part et d'autre. Trois silhouettes la parcourent.",
		"g": g, "orientation": 0,
		"pnj": [
			_ronde([[8, 4], [28, 4], [28, 18], [8, 18]]),
			_ronde([[34, 4], [54, 4], [54, 18], [34, 18]]),
			_ronde([[62, 4], [82, 4], [82, 18], [62, 18]]),
		],
		"lampes": [_lampe(18, 4, 4.5), _lampe(18, 18, 4.5), _lampe(44, 4, 4.5), _lampe(44, 18, 4.5), _lampe(72, 4, 4.5), _lampe(72, 18, 4.5), _lampe(44, 11, 4.5)],
	}


## 8.4 — Le magnésium : 56 × 50. Trois chambres superposées, séparées par deux cloisons percées d'un goulet de quatre cases chacune — l'un à l'ouest, l'autre à l'est, de sorte
## qu'on traverse chaque chambre en diagonale. Une lampe au milieu de chaque goulet : on n'y passe pas sans être vu. Un garde dans chacune des deux chambres du haut, et un chasseur
## libre qui part de l'autre bout de la chambre du joueur.
func _salle_04() -> Dictionary:
	var g := Commune.Grille.new(56, 50)
	g.rect(1, 16, 54, 2, "#")
	g.rect(1, 33, 54, 2, "#")
	g.rect(10, 16, 4, 2, ".")
	g.rect(42, 33, 4, 2, ".")
	for p in [[22, 6], [34, 9], [8, 10], [46, 5], [18, 24], [30, 27], [44, 22], [10, 28], [20, 42], [32, 40], [44, 44], [8, 38]]:
		g.rect(p[0], p[1], 2, 2, "#")
	g.poser(3, 46, "J")
	g.poser(32, 7, "1")
	g.poser(28, 25, "2")
	g.poser(52, 40, "3")
	return {
		"titre": "Le magnésium",
		"intention": "Trois chambres, deux goulets, une lampe au milieu de chacun. Le passage s'illumine.",
		"g": g, "orientation": 0,
		"pnj": [_zone([1, 1, 54, 15]), _zone([1, 18, 54, 15]), _pnj("libre_voit_entend_normal")],
		"lampes": [_lampe(11, 16, 4.5), _lampe(43, 33, 4.5), _lampe(28, 8, 4.5)],
	}


## 8.5 — L'usine : 72 × 48. Un hangar à machines — cinq colonnes, quatre rangées de blocs de 8 × 4 —, des allées de six cases. Deux postes à l'extrémité nord de deux allées, sous
## leurs lampes, qui voient toute la longueur de l'allée ; trois rondes de même tour autour de trois machines, au sol. Cinq lampes.
func _salle_05() -> Dictionary:
	var g := Commune.Grille.new(72, 48)
	for j in 4:
		for i in 5:
			g.rect(5 + 14 * i, 7 + 10 * j, 8, 4, "#")
	g.poser(36, 45, "J")
	g.poser(16, 3, "1")
	g.poser(44, 3, "2")
	return {
		"titre": "L'usine",
		"intention": "Un hangar de machines. Des silhouettes en hauteur regardent les allées, d'autres font la ronde au sol.",
		"g": g, "orientation": -90,
		"pnj": [
			{"profil": "immobile_voit_entend_normal", "orientation": 90},
			{"profil": "immobile_voit_entend_normal", "orientation": 90},
			_ronde([[3, 14], [15, 14], [15, 24], [3, 24]]),
			_ronde([[31, 24], [43, 24], [43, 34], [31, 34]]),
			_ronde([[57, 14], [69, 14], [69, 24], [57, 24]]),
		],
		"lampes": [_lampe(16, 6, 5.0), _lampe(44, 6, 5.0), _lampe(15, 19, 4.5), _lampe(43, 29, 4.5), _lampe(57, 19, 4.5)],
	}


## 8.6 — Le cloître : 60 × 60. Une cour de 36 × 36 cernée d'arcades — des piliers de 2 × 2, des baies de quatre cases — et, tout autour, une galerie de dix cases de large. Quatre
## lampes éclairent la cour, la galerie reste noire. Un garde dans chaque galerie ouest et est, deux chasseurs libres ; le joueur part dans la galerie sud.
func _salle_06() -> Dictionary:
	var g := Commune.Grille.new(60, 60)
	for k in range(11, 48, 6):
		g.rect(11, k, 2, 2, "#")
		g.rect(47, k, 2, 2, "#")
		if k > 11 and k < 47:
			g.rect(k, 11, 2, 2, "#")
			g.rect(k, 47, 2, 2, "#")
	g.rect(26, 26, 8, 8, "~")
	g.poser(30, 56, "J")
	g.poser(5, 20, "1")
	g.poser(54, 40, "2")
	g.poser(30, 4, "3")
	g.poser(44, 16, "4")
	return {
		"titre": "Le cloître",
		"intention": "Une cour éclairée, des arcades, une galerie dans le noir tout autour. On peut tourner sans fin.",
		"g": g, "orientation": -90,
		"pnj": [_zone([1, 1, 10, 58]), _zone([49, 1, 10, 58]), _pnj("libre_voit_entend_normal"), _pnj("libre_voit_entend_normal")],
		"lampes": [_lampe(19, 19, 7.0), _lampe(40, 19, 7.0), _lampe(19, 40, 7.0), _lampe(40, 40, 7.0)],
	}


## 8.7 — Le bunker : 54 × 46. Six salles de 16 cases de large de part et d'autre d'un couloir de six, chacune ne s'ouvrant que sur lui par une porte de quatre cases ; deux lampes aux
## deux bouts du couloir et rien ailleurs. Trois gardes équipés dans trois salles, deux postes qui n'ont que leurs oreilles dans deux autres ; le joueur part dans la dernière.
func _salle_07() -> Dictionary:
	var g := Commune.Grille.new(54, 46)
	g.rect(17, 1, 2, 18, "#")
	g.rect(35, 1, 2, 18, "#")
	g.rect(17, 27, 2, 18, "#")
	g.rect(35, 27, 2, 18, "#")
	g.rect(1, 19, 52, 2, "#")
	g.rect(1, 27, 52, 2, "#")
	for x0 in [6, 24, 42]:
		g.rect(x0, 19, 4, 2, ".")
		g.rect(x0, 27, 4, 2, ".")
	for p in [[11, 5], [28, 11], [45, 6], [10, 34], [27, 37], [46, 33]]:
		g.rect(p[0], p[1], 2, 2, "#")
	g.poser(3, 42, "J")
	g.poser(6, 12, "1")
	g.poser(44, 12, "2")
	g.poser(26, 34, "3")
	g.poser(26, 6, "4")
	g.poser(48, 40, "5")
	return {
		"titre": "Le bunker",
		"intention": "Six salles, un couloir, deux lampes aux deux bouts. Trois gardes, deux qui n'ont que leurs oreilles.",
		"g": g, "orientation": 0,
		"pnj": [
			_zone([1, 1, 16, 18], true), _zone([37, 1, 16, 18], true), _zone([19, 29, 16, 16], true),
			{"profil": "immobile_entend_normal", "orientation": 90}, {"profil": "immobile_entend_normal", "orientation": 180},
		],
		"lampes": [_lampe(3, 23, 4.5), _lampe(50, 23, 4.5)],
	}


## 8.8 — Le quartier : 80 × 64. Une ville : seize blocs de 12 × 8 séparés de rues de six cases. Deux rondes de même tour, chacune autour d'un bloc, deux postes qui regardent une rue
## éclairée, deux chasseurs libres ; six lampes. Les rondes, les chasseurs : tout ce qui bouge porte la mine de l'Allumeur.
func _salle_08() -> Dictionary:
	var g := Commune.Grille.new(80, 64)
	for j in 4:
		for i in 4:
			g.rect(7 + 18 * i, 7 + 14 * j, 12, 8, "#")
	g.poser(4, 60, "J")
	g.poser(22, 47, "1")
	g.poser(58, 17, "2")
	g.poser(4, 4, "3")
	g.poser(76, 4, "4")
	return {
		"titre": "Le quartier",
		"intention": "Une ville, ses rues, ses carrefours éclairés. Des silhouettes l'arpentent, d'autres montent la garde.",
		"g": g, "orientation": -45,
		"pnj": [
			{"profil": "immobile_voit_entend_normal", "orientation": 90},
			{"profil": "immobile_voit_entend_normal", "orientation": 90},
			{"profil": "ronde_voit_entend_normal", "ronde": [[22, 18], [40, 18], [40, 32], [22, 32]], "classe": CLASSE, "equipe": true},
			{"profil": "ronde_voit_entend_normal", "ronde": [[58, 32], [76, 32], [76, 46], [58, 46]], "classe": CLASSE, "equipe": true},
			_pnj("libre_voit_entend_normal", true), _pnj("libre_voit_entend_normal", true),
		],
		"lampes": [_lampe(22, 44, 5.0), _lampe(58, 20, 5.0), _lampe(40, 25, 5.0), _lampe(58, 39, 5.0), _lampe(4, 32, 5.0), _lampe(76, 18, 5.0)],
	}


## 8.9 — La salle pleine : 100 × 80, la plus grande salle du jeu. Quatre halls de 48 × 38 que deux cloisons croisées séparent, chacune percée de deux portes de six cases ; deux
## lampes par hall. Au nord-ouest deux postes, au nord-est un garde, au sud-est deux rondes de même tour, au sud-ouest — où le joueur part — un garde ; et un chasseur libre de
## niveau DIFFICILE, qui part du coin nord-est. Tout ce qui bouge porte la mine.
func _salle_09() -> Dictionary:
	var g := Commune.Grille.new(100, 80)
	g.rect(49, 1, 2, 78, "#")
	g.rect(1, 39, 98, 2, "#")
	g.rect(49, 18, 2, 6, ".")
	g.rect(49, 56, 2, 6, ".")
	g.rect(22, 39, 6, 2, ".")
	g.rect(72, 39, 6, 2, ".")
	# Du mobilier dans chaque hall : des colonnes en quinconce, hors des tours et des portes.
	_colonnes(g, 4, 4, 40, 31, 10, 9, [[34, 2, 12, 34]])
	_colonnes(g, 54, 4, 42, 31, 10, 9, [[64, 14, 24, 14]])
	_colonnes(g, 4, 44, 42, 31, 10, 9, [[20, 36, 12, 8]])
	_colonnes(g, 54, 44, 42, 31, 14, 12, [[54, 42, 24, 22], [76, 52, 20, 24]])
	g.poser(3, 76, "J")
	g.poser(39, 8, "1")
	g.poser(39, 31, "2")
	g.poser(75, 24, "3")
	g.poser(34, 58, "4")
	g.poser(92, 6, "5")
	return {
		"titre": "La salle pleine",
		"intention": "La plus grande salle. Quatre halls, huit lampes, des postes, des rondes, des gardes — et quelqu'un qui cherche.",
		"g": g, "orientation": -90,
		"pnj": [
			{"profil": "immobile_voit_entend_normal", "orientation": 180},
			{"profil": "immobile_voit_entend_normal", "orientation": 180},
			_zone([52, 2, 46, 36], true),
			_zone([2, 42, 46, 36], true),
			{"profil": "ronde_voit_entend_normal", "ronde": [[56, 46], [74, 46], [74, 60], [56, 60]], "classe": CLASSE, "equipe": true},
			{"profil": "ronde_voit_entend_normal", "ronde": [[78, 56], [94, 56], [94, 72], [78, 72]], "classe": CLASSE, "equipe": true},
			_pnj("libre_voit_entend_difficile", true),
		],
		"lampes": [
			_lampe(36, 8, 5.0), _lampe(36, 31, 5.0), _lampe(70, 10, 5.0), _lampe(85, 30, 5.0),
			_lampe(65, 46, 5.0), _lampe(86, 72, 5.0), _lampe(22, 52, 5.0), _lampe(40, 70, 5.0),
		],
	}


## 8.10 — L'Allumeur : l'arène de 32 × 32, coupée en deux par une cloison percée d'un goulet de quatre cases en son milieu. Le joueur et le boss partent chacun d'un côté, dans le
## noir, sans se voir ; il faut passer par le goulet, et la mine y est redoutable. Symétrique d'est en ouest et du nord au sud ; les deux lampes se font face.
func _salle_10() -> Dictionary:
	var g := Commune.Grille.new(32, 32)
	g.rect(15, 1, 2, 30, "#")
	g.rect(15, 14, 2, 4, ".")
	g.rect_miroirs(6, 6, 2, 2, "#")
	g.rect_miroirs(9, 12, 2, 2, "~")
	g.poser(3, 8, "J")
	g.poser(28, 8, "1")
	return {
		"titre": "L'Allumeur",
		"intention": "Un duel dans une arène coupée en deux. Le seul passage est un goulet, et il y pose une mine.",
		"boss": true,
		"g": g, "orientation": 30,
		"pnj": [{"profil": "boss", "classe": CLASSE}],
		"lampes": [_lampe(9, 16, 4.5), _lampe(22, 16, 4.5)],
	}
