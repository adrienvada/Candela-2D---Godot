## Fabrique le chapitre 6 de l'aventure, « Les chasseurs » — chantier SOLO, étape S8 (lot 2).
##
## Dix salles dans `res://assets/solo/chapitre_06/` : le manifeste (`chapitre.json`, qui débloque la Sentinelle, slug `sentinelle`) et `niveau_01.json` … `niveau_10.json`.
## Les PNJ ne gardent plus rien : ce sont des chasseurs (`libre_…`), qui errent sur toute la carte, vous cherchent et se souviennent de l'endroit où ils vous ont vu. On apprend à
## rompre une poursuite — disparaître de leur mémoire —, à les attendre à un seuil, à ne pas faire de bruit, à ne pas s'engager dans un passage qu'une poudre trahit. **À partir de 6.7,
## les chasseurs portent la classe du boss et sa poudre de contact** (`"equipe": true`, S8) : on apprend ce que la poudre fait d'un couloir avant de l'affronter.
##
## ⚠️ **Ce que la règle de la poudre demande** (`EquipementBot.GADGETS`) : elle se pose EN ENQUÊTE sur un son, à 200-450 px de la place visée, que le bot n'a PAS vue. Un chasseur
## équipé doit donc ENTENDRE : tous ceux de 6.7 à 6.9 entendent (et voient). Les chasseurs « voit seulement » de 6.1 à 6.4 et de 6.8 ne sont jamais équipés — ils n'enquêtent pas. La poudre
## fait 220 px de large (`GadgetPoudre.RAYON` 110) : un couloir de quatre cases (140 px) s'en trouve rempli d'un mur à l'autre — c'est la salle 6.6.
##
## Le dessin et l'écriture sont ceux de `fabrique_commune.gd` ; ce fichier ne contient que les salles, et `tools/test_chapitre_06.gd` mesure sur leurs JSON ce que chacune
## ENSEIGNE. **Les JSON sont la vérité du jeu, ce script n'est que la façon dont on les a écrits.**
##
## Lancer : godot --headless --path . --script res://tools/fabrique_chapitre_06.gd
extends SceneTree

const Commune := preload("res://tools/fabrique_commune.gd")

const DOSSIER := "res://assets/solo/chapitre_06"
const CLASSE := "sentinelle"


func _init() -> void:
	var salles: Array[Dictionary] = [
		_salle_01(), _salle_02(), _salle_03(), _salle_04(), _salle_05(),
		_salle_06(), _salle_07(), _salle_08(), _salle_09(), _salle_10(),
	]
	Commune.fabriquer(DOSSIER, 6, "Les chasseurs", CLASSE, "Les chasseurs", salles)
	quit()


func _lampe(x: int, y: int, rayon: float) -> Dictionary:
	return {"case": [x, y], "rayon": rayon, "intensite": 1.2}


## Un chasseur : il erre sur toute la carte ; équipé de la poudre de contact de la Sentinelle à partir de 6.7.
func _chasseur(profil: String, equipe: bool = false) -> Dictionary:
	var p := {"profil": profil}
	if equipe:
		p["classe"] = CLASSE
		p["equipe"] = true
	return p


## Un gardien de zone, équipé de même.
func _zone(profil: String, rect: Array, equipe: bool = false) -> Dictionary:
	var p := {"profil": profil, "zone": rect}
	if equipe:
		p["classe"] = CLASSE
		p["equipe"] = true
	return p


# ---------------------------------------------------------------------------
# LES DIX SALLES
# ---------------------------------------------------------------------------

## 6.1 — Le chasseur : une petite carte en boucle — un bloc au milieu, un couloir qui en fait le tour. Un chasseur qui voit, une lampe ; il vous cherche, et la boucle n'a pas de fond.
func _salle_01() -> Dictionary:
	var g := Commune.Grille.new(24, 18)
	g.rect(7, 5, 10, 8, "#")
	g.poser(3, 15, "J")
	g.poser(20, 3, "1")
	return {
		"titre": "Le chasseur",
		"intention": "Une petite carte en boucle. Quelqu'un vous cherche, et il n'a pas de poste.",
		"g": g, "orientation": -90,
		"pnj": [_chasseur("libre_voit_facile")],
		"lampes": [_lampe(4, 3, 3.5)],
	}


## 6.2 — Rompre : deux boucles reliées par une porte. La première, à l'ouest, est éclairée ; la seconde, à l'est, est noire. Un chasseur qui voit ne voit pas dans le noir : on s'y
## cache, et au bout de quelques secondes il vous a oublié.
func _salle_02() -> Dictionary:
	var g := Commune.Grille.new(40, 18)
	g.rect(19, 1, 2, 16, "#")
	g.rect(19, 7, 2, 4, ".")
	g.rect(5, 5, 8, 8, "#")
	g.rect(27, 5, 8, 8, "#")
	g.poser(3, 15, "J")
	g.poser(16, 3, "1")
	return {
		"titre": "Rompre",
		"intention": "Deux boucles reliées par une porte. L'une est claire, l'autre noire.",
		"g": g, "orientation": -90,
		"pnj": [_chasseur("libre_voit_facile")],
		"lampes": [_lampe(3, 3, 3.5)],
	}


## 6.3 — La meute : une carte à îlots. Huit blocs posés au hasard, des couloirs partout entre eux, deux chasseurs qui naissent aux deux bouts, deux lampes.
func _salle_03() -> Dictionary:
	var g := Commune.Grille.new(40, 28)
	g.rect(6, 5, 4, 3, "#")
	g.rect(14, 8, 5, 4, "#")
	g.rect(24, 4, 4, 4, "#")
	g.rect(32, 9, 4, 3, "#")
	g.rect(8, 15, 4, 4, "#")
	g.rect(18, 19, 5, 3, "#")
	g.rect(28, 16, 4, 5, "#")
	g.rect(34, 22, 3, 3, "#")
	g.poser(3, 24, "J")
	g.poser(36, 3, "1")
	g.poser(30, 25, "2")
	return {
		"titre": "La meute",
		"intention": "Des îlots, des couloirs, deux chasseurs qui viennent de deux côtés.",
		"g": g, "orientation": -45,
		"pnj": [_chasseur("libre_voit_facile"), _chasseur("libre_voit_facile")],
		"lampes": [_lampe(21, 14, 4.0), _lampe(12, 6, 3.5)],
	}


## 6.4 — L'embuscade : une salle à trois entrées, au milieu d'un couloir qui en fait le tour. Deux chasseurs rôdent dehors. Chaque seuil est éclairé — on les voit entrer, ils ne vous voient pas.
func _salle_04() -> Dictionary:
	var g := Commune.Grille.new(34, 22)
	g.rect(8, 5, 18, 12, "#")
	g.rect(9, 6, 16, 10, ".")
	g.rect(20, 5, 4, 1, ".")
	g.rect(25, 6, 1, 4, ".")
	g.rect(8, 11, 1, 4, ".")
	g.rect(13, 8, 2, 2, "#")
	g.rect(19, 12, 2, 2, "#")
	g.poser(16, 10, "J")
	g.poser(3, 3, "1")
	g.poser(30, 19, "2")
	return {
		"titre": "L'embuscade",
		"intention": "Une salle à trois entrées. Les seuils sont éclairés, le reste est noir. On les attend.",
		"g": g, "orientation": 0,
		"pnj": [_chasseur("libre_voit_facile"), _chasseur("libre_voit_facile")],
		"lampes": [_lampe(23, 7, 4.5), _lampe(10, 13, 4.0)],
	}


## 6.5 — Le chasseur qui écoute : un sol nu, rien pour s'abriter, une lampe. Un chasseur qui voit et entend. Debout, on s'entend de partout ; accroupi, à peine.
func _salle_05() -> Dictionary:
	var g := Commune.Grille.new(18, 14)
	g.poser(2, 12, "J")
	g.poser(15, 3, "1")
	return {
		"titre": "Le chasseur qui écoute",
		"intention": "Un sol nu, rien pour s'abriter. Il vous suit à vos pas.",
		"g": g, "orientation": -45,
		"pnj": [_chasseur("libre_voit_entend_facile")],
		"lampes": [_lampe(9, 7, 4.0)],
	}


## 6.6 — La poudre : des couloirs croisés. Quatre couloirs de quatre cases, deux horizontaux, deux verticaux, qui se coupent en quatre carrefours ; le reste est plein. Deux chasseurs qui voient
## et entendent. Aucun endroit où une poudre de 220 px tienne sans toucher les deux murs.
func _salle_06() -> Dictionary:
	var g := Commune.Grille.new(36, 28)
	g.rect(1, 1, 34, 26, "#")
	g.rect(1, 5, 34, 4, ".")
	g.rect(1, 19, 34, 4, ".")
	g.rect(5, 1, 4, 26, ".")
	g.rect(27, 1, 4, 26, ".")
	g.poser(6, 2, "J")
	g.poser(30, 2, "1")
	g.poser(2, 21, "2")
	return {
		"titre": "La poudre",
		"intention": "Des couloirs croisés. Quatre cases de large : ce qu'on y répand les remplit.",
		"g": g, "orientation": 90,
		"pnj": [_chasseur("libre_voit_entend_facile"), _chasseur("libre_voit_entend_facile")],
		"lampes": [_lampe(28, 20, 3.5), _lampe(6, 20, 3.5)],
	}


## 6.7 — Gardes et chasseurs : une cour et des corridors. Un anneau de couloirs, quatre branches qui mènent à la cour, deux petites salles — l'une au nord-ouest, l'autre au sud-est — où deux gardiens
## tiennent leur zone. Deux chasseurs rôdent sur l'anneau. Tous portent la Sentinelle et sa poudre.
func _salle_07() -> Dictionary:
	var g := Commune.Grille.new(40, 30)
	g.rect(1, 1, 38, 28, "#")
	g.rect(1, 1, 38, 4, ".")
	g.rect(1, 25, 38, 4, ".")
	g.rect(1, 1, 4, 28, ".")
	g.rect(35, 1, 4, 28, ".")
	g.rect(14, 10, 12, 10, ".")
	g.rect(18, 5, 4, 5, ".")
	g.rect(18, 20, 4, 5, ".")
	g.rect(5, 13, 9, 4, ".")
	g.rect(26, 13, 9, 4, ".")
	g.rect(6, 6, 7, 6, ".")
	g.rect(9, 12, 4, 1, ".")
	g.rect(27, 18, 7, 6, ".")
	g.rect(27, 17, 4, 1, ".")
	g.poser(23, 19, "J")
	g.poser(9, 8, "1")
	g.poser(30, 20, "2")
	g.poser(2, 2, "3")
	g.poser(37, 27, "4")
	return {
		"titre": "Gardes et chasseurs",
		"intention": "Une cour, des corridors, deux postes. Les chasseurs vous poussent vers eux.",
		"g": g, "orientation": 180,
		"pnj": [
			_zone("zone_voit_entend_facile", [6, 6, 7, 7], true),
			_zone("zone_voit_entend_facile", [27, 17, 7, 7], true),
			_chasseur("libre_voit_entend_facile", true),
			_chasseur("libre_voit_entend_facile", true),
		],
		"lampes": [_lampe(9, 8, 3.5), _lampe(30, 20, 3.5), _lampe(19, 7, 3.5)],
	}


## 6.8 — La traque : une carte ouverte, quelques éboulis. Un chasseur aux réflexes NORMAUX, qui voit et entend et porte la poudre, et un second, plus lent, qui voit seulement.
func _salle_08() -> Dictionary:
	var g := Commune.Grille.new(40, 28)
	g.rect(8, 6, 2, 2, "#")
	g.rect(30, 5, 2, 3, "#")
	g.rect(18, 12, 3, 2, "#")
	g.rect(10, 19, 2, 3, "#")
	g.rect(32, 18, 3, 2, "#")
	g.rect(24, 22, 2, 2, "#")
	g.rect(4, 13, 2, 2, "#")
	g.poser(3, 25, "J")
	g.poser(34, 3, "1")
	g.poser(37, 25, "2")
	return {
		"titre": "La traque",
		"intention": "Une carte ouverte. L'un vous suit de près et ne se trompe pas ; l'autre est plus lent.",
		"g": g, "orientation": -45,
		"pnj": [_chasseur("libre_voit_entend_normal", true), _chasseur("libre_voit_facile")],
		"lampes": [_lampe(20, 14, 5.0), _lampe(8, 22, 4.0)],
	}


## 6.9 — La salle pleine : une grande carte, douze îlots, quatre chasseurs — trois aux réflexes faciles, un aux réflexes normaux. Tous portent la Sentinelle.
func _salle_09() -> Dictionary:
	var g := Commune.Grille.new(44, 34)
	g.rect(6, 5, 4, 3, "#")
	g.rect(14, 3, 3, 5, "#")
	g.rect(22, 6, 5, 3, "#")
	g.rect(32, 4, 4, 4, "#")
	g.rect(38, 12, 3, 4, "#")
	g.rect(8, 13, 5, 4, "#")
	g.rect(18, 15, 4, 4, "#")
	g.rect(27, 13, 4, 5, "#")
	g.rect(12, 24, 5, 3, "#")
	g.rect(23, 22, 4, 4, "#")
	g.rect(33, 23, 5, 3, "#")
	g.rect(6, 28, 3, 3, "#")
	g.poser(3, 31, "J")
	g.poser(40, 3, "1")
	g.poser(3, 3, "2")
	g.poser(40, 30, "3")
	g.poser(24, 19, "4")
	return {
		"titre": "La salle pleine",
		"intention": "Une grande carte, des îlots, toute une meute. L'un d'eux est plus vif que les autres.",
		"g": g, "orientation": -45,
		"pnj": [
			_chasseur("libre_voit_entend_facile", true),
			_chasseur("libre_voit_entend_facile", true),
			_chasseur("libre_voit_entend_facile", true),
			_chasseur("libre_voit_entend_normal", true),
		],
		"lampes": [_lampe(12, 9, 3.5), _lampe(33, 10, 3.5), _lampe(12, 21, 3.5), _lampe(31, 26, 3.5)],
	}


## 6.10 — La Sentinelle : l'arène du chapitre 0, variée — deux piliers de 2 × 3 de chaque côté du centre, des pans de mur étroits au nord et au sud, quatre murets au centre. Symétrique d'est en ouest
## et du nord au sud ; les deux lampes se font face.
func _salle_10() -> Dictionary:
	var g := Commune.Grille.new(32, 32)
	g.rect_miroirs(9, 12, 2, 3, "#")
	g.rect_miroirs(14, 6, 1, 4, "#")
	g.rect_miroir_x(13, 15, 2, 2, "~")
	g.poser(3, 16, "J")
	g.poser(28, 16, "1")
	return {
		"titre": "La Sentinelle",
		"intention": "Un duel dans une arène. Elle veille : chaque pas qu'on fait y reste écrit.",
		"boss": true,
		"g": g, "orientation": 0,
		"pnj": [{"profil": "boss", "classe": CLASSE}],
		"lampes": [_lampe(10, 16, 4.5), _lampe(21, 16, 4.5)],
	}
