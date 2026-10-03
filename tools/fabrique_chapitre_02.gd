## Fabrique le chapitre 2 de l'aventure, « Les rondes écoutent » — chantier SOLO, étape S8.
##
## Dix salles dans `res://assets/solo/chapitre_02/` : le manifeste (`chapitre.json`, qui débloque l'Illusionniste, slug `fusil`) et `niveau_01.json` …
## `niveau_10.json`. Les rondes du chapitre 1 ne percevaient que ce qu'elles voyaient ; celles-ci ENTENDENT : marcher, tirer, recharger devient un risque, et
## on apprend à se faire oublier — rester immobile, s'accroupir —, puis à faire diversion. **À partir de 2.7, les rondes portent la classe du boss et son
## leurre** (`"equipe": true`, S8) : on apprend à ne pas tirer sur ce qui ne bouge pas avant de l'affronter.
##
## Le dessin et l'écriture sont ceux de `fabrique_commune.gd` ; ce fichier ne contient que les salles, et `tools/test_chapitre_02.gd` mesure sur leurs
## JSON ce que chacune ENSEIGNE. **Les JSON sont la vérité du jeu, ce script n'est que la façon dont on les a écrits.**
##
## Lancer : godot --headless --path . --script res://tools/fabrique_chapitre_02.gd
extends SceneTree

const Commune := preload("res://tools/fabrique_commune.gd")

const DOSSIER := "res://assets/solo/chapitre_02"
const CLASSE := "fusil"


func _init() -> void:
	var salles: Array[Dictionary] = [
		_salle_01(), _salle_02(), _salle_03(), _salle_04(), _salle_05(),
		_salle_06(), _salle_07(), _salle_08(), _salle_09(), _salle_10(),
	]
	Commune.fabriquer(DOSSIER, 2, "Les rondes écoutent", CLASSE, "Les rondes écoutent", salles)
	quit()


func _lampe(x: int, y: int, rayon: float) -> Dictionary:
	return {"case": [x, y], "rayon": rayon, "intensite": 1.2}


## Un PNJ de ronde du chapitre, équipé du leurre de l'Illusionniste à partir de 2.7.
func _ronde(profil: String, points: Array, equipe: bool = false) -> Dictionary:
	var p := {"profil": profil, "ronde": points}
	if equipe:
		p["classe"] = CLASSE
		p["equipe"] = true
	return p


# ---------------------------------------------------------------------------
# LES DIX SALLES
# ---------------------------------------------------------------------------

## 2.1 — Une ronde qui écoute : un grand tour autour d'un bloc, aux couloirs si larges que le bord extérieur est loin du trajet. Un pas debout s'entend
## de partout dans la salle ; un pas accroupi seulement tout près — et le bord extérieur est assez loin pour qu'on y passe sans être entendu.
func _salle_01() -> Dictionary:
	var g := Commune.Grille.new(28, 22)
	g.rect(9, 7, 10, 8, "#")
	g.poser(2, 19, "J")
	return {
		"titre": "Une ronde qui écoute",
		"intention": "Elle n'a pas d'yeux, elle écoute. Dans cette salle, un pas debout s'entend de partout.",
		"g": g, "orientation": 0,
		"pnj": [_ronde("ronde_entend_lent", [[6, 4], [21, 4], [21, 17], [6, 17]])],
		"lampes": [_lampe(13, 4, 4.0)],
	}


## 2.2 — Le pas de trop : une salle nue, sans lampe ni mur, que deux rondes se partagent, l'une au nord, l'autre au sud. Rien n'étouffe un pas, et un tir
## s'entend net dans toute la salle.
func _salle_02() -> Dictionary:
	var g := Commune.Grille.new(26, 20)
	g.poser(1, 10, "J")
	return {
		"titre": "Le pas de trop",
		"intention": "Une salle nue, deux oreilles qui font le tour. Un pas, une douille, et elles se retournent.",
		"g": g, "orientation": 0,
		"pnj": [
			_ronde("ronde_entend_lent", [[4, 4], [21, 4], [21, 7], [4, 7]]),
			_ronde("ronde_entend_lent", [[21, 15], [4, 15], [4, 18], [21, 18]]),
		],
		"lampes": [],
	}


## 2.3 — Attendre : deux rondes, l'une au nord, l'autre au sud ; entre elles, un hall, et de chaque côté un long recoin noir, ouvert sur le hall, que les murs
## isolent du trajet. Qui ne bouge pas ne fait aucun bruit.
func _salle_03() -> Dictionary:
	var g := Commune.Grille.new(30, 22)
	g.rect(1, 9, 10, 1, "#")
	g.rect(1, 13, 10, 1, "#")
	g.rect(19, 9, 10, 1, "#")
	g.rect(19, 13, 10, 1, "#")
	g.poser(12, 12, "J")
	return {
		"titre": "Attendre",
		"intention": "Deux rondes qui écoutent, deux recoins noirs. Tant qu'on ne bouge pas, on ne s'entend pas.",
		"g": g, "orientation": 0,
		"pnj": [
			_ronde("ronde_entend_lent", [[4, 3], [25, 3], [25, 7], [4, 7]]),
			_ronde("ronde_entend_lent", [[25, 15], [4, 15], [4, 19], [25, 19]]),
		],
		"lampes": [_lampe(15, 11, 4.0)],
	}


## 2.4 — Le bruit et la lumière : deux salles reliées par une porte. À gauche, sous deux lampes, une ronde qui voit ; à droite, dans le noir, une ronde qui
## entend. Chacune fait le tour d'un bloc de sa salle.
func _salle_04() -> Dictionary:
	var g := Commune.Grille.new(34, 18)
	g.rect(16, 1, 2, 6, "#")
	g.rect(16, 11, 2, 6, "#")
	g.rect(6, 6, 6, 6, "#")
	g.rect(22, 6, 6, 6, "#")
	g.poser(16, 8, "J")
	return {
		"titre": "Le bruit et la lumière",
		"intention": "Deux salles, une porte. À gauche, une ronde qui voit sous les lampes. À droite, une qui écoute.",
		"g": g, "orientation": 180,
		"pnj": [
			_ronde("ronde_voit_lent", [[3, 3], [14, 3], [14, 14], [3, 14]]),
			_ronde("ronde_entend_lent", [[19, 3], [30, 3], [30, 14], [19, 14]]),
		],
		"lampes": [_lampe(8, 3, 3.5), _lampe(3, 9, 3.5)],
	}


## 2.5 — Les deux sens : une salle en T, un pilier au croisement, une ronde qui voit et entend. Elle fait le tour du pilier, de la barre à la queue du T ; une lampe
## éclaire la queue. Les ailes de la barre sont noires.
func _salle_05() -> Dictionary:
	var g := Commune.Grille.new(30, 18)
	g.rect(1, 8, 10, 9, "#")
	g.rect(19, 8, 10, 9, "#")
	g.rect(13, 4, 4, 6, "#")
	g.poser(2, 3, "J")
	return {
		"titre": "Les deux sens",
		"intention": "Une salle en T. Elle voit et elle entend : le noir ne suffit plus.",
		"g": g, "orientation": 0,
		"pnj": [_ronde("ronde_voit_entend_lent", [[11, 3], [18, 3], [18, 12], [11, 12]])],
		"lampes": [_lampe(14, 13, 4.0)],
	}


## 2.6 — La diversion : une longue galerie à murets, et au fond, dans une chambre, une silhouette qui ne perçoit rien, gardée par deux rondes qui voient et
## entendent. Un tir s'entend net dans toute la galerie comme dans la chambre : tiré de loin, il appelle les rondes.
func _salle_06() -> Dictionary:
	var g := Commune.Grille.new(36, 18)
	g.rect(23, 1, 2, 4, "#")
	g.rect(23, 13, 2, 4, "#")
	g.rect(5, 4, 8, 1, "~")
	g.rect(5, 13, 8, 1, "~")
	g.rect(15, 7, 1, 5, "~")
	g.poser(2, 9, "J")
	g.poser(31, 9, "1")
	return {
		"titre": "La diversion",
		"intention": "Une galerie, des murets. Au fond, une silhouette immobile que deux rondes ne quittent pas.",
		"g": g, "orientation": 0,
		"pnj": [
			_ronde("ronde_voit_entend_lent", [[26, 2], [33, 2], [33, 7], [26, 7]]),
			_ronde("ronde_voit_entend_lent", [[26, 16], [33, 16], [33, 11], [26, 11]]),
			{"profil": "immobile_sourd_aveugle", "orientation": 180},
		],
		"lampes": [_lampe(31, 9, 4.0)],
	}


## 2.7 — Le leurre : une salle à piliers, deux rondes qui voient et entendent, au palier FACILE. Elles portent l'Illusionniste : leur leurre se pose juste après
## une rafale, une silhouette de plus dans la lumière. Deux lampes éclairent la voie du milieu.
func _salle_07() -> Dictionary:
	var g := Commune.Grille.new(30, 22)
	g.rect(7, 6, 2, 2, "#")
	g.rect(7, 14, 2, 2, "#")
	g.rect(14, 10, 2, 2, "#")
	g.rect(21, 6, 2, 2, "#")
	g.rect(21, 14, 2, 2, "#")
	g.poser(14, 20, "J")
	return {
		"titre": "Le leurre",
		"intention": "Des piliers, deux lampes, deux rondes. Une silhouette qui ne bouge pas n'est peut-être personne.",
		"g": g, "orientation": -90,
		"pnj": [
			_ronde("ronde_voit_entend_facile", [[4, 3], [11, 3], [11, 18], [4, 18]], true),
			_ronde("ronde_voit_entend_facile", [[18, 3], [25, 3], [25, 18], [18, 18]], true),
		],
		"lampes": [_lampe(11, 10, 3.5), _lampe(18, 10, 3.5)],
	}


## 2.8 — Le quartier : quatre bras en croix, une ronde par bras. Chaque tour déborde au carrefour sur ceux de ses deux voisines : les quatre se recouvrent.
func _salle_08() -> Dictionary:
	var g := Commune.Grille.new(28, 28)
	g.rect(1, 1, 8, 8, "#")
	g.rect(19, 1, 8, 8, "#")
	g.rect(1, 19, 8, 8, "#")
	g.rect(19, 19, 8, 8, "#")
	g.poser(13, 26, "J")
	return {
		"titre": "Le quartier",
		"intention": "Quatre rondes, quatre bras. Leurs tours se recouvrent au carrefour.",
		"g": g, "orientation": -90,
		"pnj": [
			_ronde("ronde_voit_entend_lent", [[10, 3], [17, 3], [17, 11], [10, 11]], true),
			_ronde("ronde_voit_entend_lent", [[24, 10], [16, 10], [16, 17], [24, 17]], true),
			_ronde("ronde_voit_entend_lent", [[17, 23], [10, 23], [10, 16], [17, 16]], true),
			_ronde("ronde_voit_entend_lent", [[3, 17], [3, 10], [11, 10], [11, 17]], true),
		],
		"lampes": [_lampe(13, 13, 4.0), _lampe(14, 20, 3.5)],
	}


## 2.9 — La salle pleine : une grande salle, trois rondes qui voient et entendent (palier FACILE, le leurre), deux postes qui n'entendent que.
func _salle_09() -> Dictionary:
	var g := Commune.Grille.new(40, 30)
	g.rect(9, 6, 2, 2, "#")
	g.rect(29, 6, 2, 2, "#")
	g.rect(19, 13, 2, 2, "#")
	g.rect(14, 22, 2, 2, "#")
	g.rect(24, 22, 2, 2, "#")
	g.poser(19, 23, "J")
	g.poser(19, 4, "1")
	g.poser(37, 15, "2")
	return {
		"titre": "La salle pleine",
		"intention": "Une grande salle. Les rondes écoutent, et les postes aussi.",
		"g": g, "orientation": -90,
		"pnj": [
			_ronde("ronde_voit_entend_facile", [[5, 3], [15, 3], [15, 11], [5, 11]], true),
			_ronde("ronde_voit_entend_facile", [[24, 3], [34, 3], [34, 11], [24, 11]], true),
			_ronde("ronde_voit_entend_facile", [[4, 19], [35, 19], [35, 27], [4, 27]], true),
			{"profil": "immobile_entend_lent"},
			{"profil": "immobile_entend_lent"},
		],
		"lampes": [_lampe(10, 3, 3.5), _lampe(34, 7, 3.5), _lampe(19, 19, 4.0)],
	}


## 2.10 — L'Illusionniste : l'arène du chapitre 0, variée — des piliers en carré autour du centre, de longs murets en travers. Symétrique d'est en ouest et du nord
## au sud ; les deux lampes se font face.
func _salle_10() -> Dictionary:
	var g := Commune.Grille.new(32, 32)
	g.rect_miroirs(11, 11, 3, 3, "#")
	g.rect_miroirs(5, 14, 1, 4, "#")
	g.rect_miroirs(8, 5, 6, 1, "~")
	g.poser(3, 16, "J")
	g.poser(28, 16, "1")
	return {
		"titre": "L'Illusionniste",
		"intention": "Un duel dans une arène. Son double est tout près, et ne bouge pas.",
		"boss": true,
		"g": g, "orientation": 0,
		"pnj": [{"profil": "boss", "classe": CLASSE}],
		"lampes": [_lampe(10, 16, 4.5), _lampe(21, 16, 4.5)],
	}
