## Fabrique le chapitre 7 de l'aventure, « Les chasseurs vifs » — chantier SOLO, étape S8, lot 2.
##
## Dix salles dans `res://assets/solo/chapitre_07/` : le manifeste (`chapitre.json`, qui débloque l'Occulteur, slug `occulteur`) et `niveau_01.json` … `niveau_10.json`.
## Plus de trajet ni de zone : les chasseurs sont LIBRES partout (`libre_voit_entend_normal`) — ils voient, ils entendent, ils réagissent comme le boss des premiers
## chapitres, et ils vont chercher le joueur. Chaque salle est une suite de petits duels. **À partir de 7.7, les chasseurs portent la classe du boss et son ombre
## habitée** (`"equipe": true`, S8) : la plaque d'acier qui coupe le faisceau d'une torche et rend l'ombre d'un homme absent.
##
## L'ombre habitée se pose « face à la torche de la cible, qu'il voit » (`EquipementBot.GADGETS`, état enquête, recherche ou combat) : un chasseur équipé doit donc VOIR.
## Le profil `libre_voit_entend_normal` voit et entend, la règle peut se déclencher ; la garde (`GADGET_EXIGE`) l'exige.
##
## Le dessin et l'écriture sont ceux de `fabrique_commune.gd` ; ce fichier ne contient que les salles, et `tools/test_chapitre_07.gd` mesure sur leurs JSON ce que chacune
## ENSEIGNE. **Les JSON sont la vérité du jeu, ce script n'est que la façon dont on les a écrits.**
##
## Lancer : godot --headless --path . --script res://tools/fabrique_chapitre_07.gd
extends SceneTree

const Commune := preload("res://tools/fabrique_commune.gd")
const Laby := preload("res://tools/fabrique_labyrinthe.gd")

const DOSSIER := "res://assets/solo/chapitre_07"
const CLASSE := "occulteur"
const CHASSEUR := "libre_voit_entend_normal"


func _init() -> void:
	var salles: Array[Dictionary] = [
		_salle_01(), _salle_02(), _salle_03(), _salle_04(), _salle_05(),
		_salle_06(), _salle_07(), _salle_08(), _salle_09(), _salle_10(),
	]
	Commune.fabriquer(DOSSIER, 7, "Les chasseurs vifs", CLASSE, "Les chasseurs vifs", salles)
	quit()


func _lampe(x: int, y: int, rayon: float) -> Dictionary:
	return {"case": [x, y], "rayon": rayon, "intensite": 1.2}


## Un chasseur libre ; équipé de l'ombre habitée de l'Occulteur à partir de 7.7.
func _chasseur(equipe: bool = false) -> Dictionary:
	var p := {"profil": CHASSEUR}
	if equipe:
		p["classe"] = CLASSE
		p["equipe"] = true
	return p


# ---------------------------------------------------------------------------
# LES DIX SALLES
# ---------------------------------------------------------------------------

## 7.1 — Le duelliste : une petite arène à colonnes, deux lampes qui ne se touchent pas, un chasseur seul à l'autre bout. Le premier duel contre un adversaire qui bouge.
func _salle_01() -> Dictionary:
	var g := Commune.Grille.new(22, 22)
	g.rect_miroirs(6, 6, 2, 2, "#")
	g.rect(10, 10, 2, 2, "#")
	g.poser(2, 11, "J")
	g.poser(19, 10, "1")
	return {
		"titre": "Le duelliste",
		"intention": "Une arène, deux colonnes de lumière, un chasseur. Il vous cherche.",
		"g": g, "orientation": 0,
		"pnj": [_chasseur()],
		"lampes": [_lampe(9, 4, 3.5), _lampe(12, 17, 3.5)],
	}


## 7.2 — Deux duels : deux chambres reliées par une porte de quatre cases. Un chasseur dans chacune ; le joueur part dans l'embrasure, dans le noir, entre les deux.
func _salle_02() -> Dictionary:
	var g := Commune.Grille.new(36, 20)
	g.rect(17, 1, 2, 18, "#")
	g.rect(17, 8, 2, 4, ".")
	g.rect(8, 5, 2, 2, "#")
	g.rect(8, 13, 2, 2, "#")
	g.rect(26, 5, 2, 2, "#")
	g.rect(26, 13, 2, 2, "#")
	g.poser(17, 10, "J")
	g.poser(4, 15, "1")
	g.poser(31, 4, "2")
	return {
		"titre": "Deux duels",
		"intention": "Deux chambres, une porte entre elles. Un chasseur dans chacune, et vous au milieu.",
		"g": g, "orientation": 0,
		"pnj": [_chasseur(), _chasseur()],
		"lampes": [_lampe(6, 9, 3.5), _lampe(29, 10, 3.5)],
	}


## 7.3 — Le noir complet : aucune lampe. Rien ne montre personne que la torche et le bruit ; des piliers pour s'y cacher.
func _salle_03() -> Dictionary:
	var g := Commune.Grille.new(30, 24)
	g.rect(7, 5, 2, 2, "#")
	g.rect(7, 17, 2, 2, "#")
	g.rect(14, 11, 2, 2, "#")
	g.rect(21, 5, 2, 2, "#")
	g.rect(21, 17, 2, 2, "#")
	g.rect(24, 11, 2, 2, "#")
	g.poser(2, 12, "J")
	g.poser(27, 3, "1")
	g.poser(27, 20, "2")
	return {
		"titre": "Le noir complet",
		"intention": "Pas une lampe. Deux chasseurs, et vos pas pour seule lumière.",
		"g": g, "orientation": 0,
		"pnj": [_chasseur(), _chasseur()],
		"lampes": [],
	}


## 7.4 — La lumière piège : cinq flaques en quinconce, du noir entre elles. Chaque flaque trahit celui qui la traverse, joueur ou chasseur.
func _salle_04() -> Dictionary:
	var g := Commune.Grille.new(30, 30)
	g.rect(11, 3, 2, 2, "#")
	g.rect(17, 25, 2, 2, "#")
	g.rect(3, 17, 2, 2, "#")
	g.rect(25, 11, 2, 2, "#")
	g.poser(2, 15, "J")
	g.poser(27, 15, "1")
	g.poser(15, 27, "2")
	return {
		"titre": "La lumière piège",
		"intention": "Cinq flaques de lumière, du noir entre elles. Qui en traverse une se montre.",
		"g": g, "orientation": 0,
		"pnj": [_chasseur(), _chasseur()],
		"lampes": [_lampe(7, 7, 3.5), _lampe(22, 7, 3.5), _lampe(15, 15, 3.5), _lampe(7, 22, 3.5), _lampe(22, 22, 3.5)],
	}


## 7.5 — Le poste et la meute : un hall à colonnes. Deux chasseurs libres devant, et au fond, dans une niche éclairée, un poste qui ne bouge pas et regarde le hall.
func _salle_05() -> Dictionary:
	var g := Commune.Grille.new(36, 22)
	g.rect(31, 1, 4, 8, "#")
	g.rect(31, 13, 4, 8, "#")
	g.rect(9, 5, 2, 2, "#")
	g.rect(9, 15, 2, 2, "#")
	g.rect(17, 9, 2, 4, "#")
	g.rect(24, 5, 2, 2, "#")
	g.rect(24, 15, 2, 2, "#")
	g.poser(2, 11, "J")
	g.poser(13, 3, "1")
	g.poser(13, 19, "2")
	g.poser(33, 11, "3")
	return {
		"titre": "Le poste et la meute",
		"intention": "Un hall à colonnes. Deux chasseurs vont et viennent, un troisième garde le fond.",
		"g": g, "orientation": 0,
		"pnj": [_chasseur(), _chasseur(), {"profil": "immobile_voit_entend_normal", "orientation": 180}],
		"lampes": [_lampe(12, 11, 4.0), _lampe(22, 11, 4.0), _lampe(30, 11, 5.0)],
	}


## 7.6 — L'ombre : une galerie, deux lampes cernées de colonnes. Chaque colonne jette derrière elle une ombre où l'on ne voit rien, ni d'un côté ni de l'autre.
func _salle_06() -> Dictionary:
	var g := Commune.Grille.new(34, 20)
	for lx in [12, 26]:
		g.rect(lx - 3, 6, 2, 2, "#")
		g.rect(lx + 2, 6, 2, 2, "#")
		g.rect(lx - 3, 12, 2, 2, "#")
		g.rect(lx + 2, 12, 2, 2, "#")
	g.poser(2, 10, "J")
	g.poser(31, 4, "1")
	g.poser(31, 15, "2")
	return {
		"titre": "L'ombre",
		"intention": "Une galerie, des colonnes autour de chaque lampe. Derrière chacune, une ombre qui cache.",
		"g": g, "orientation": 0,
		"pnj": [_chasseur(), _chasseur()],
		"lampes": [_lampe(12, 9, 8.0), _lampe(26, 9, 8.0)],
	}


## 7.7 — Trois chasseurs : une carte à îlots, des blocs de mur que l'on contourne, trois lampes. Trois chasseurs équipés ; on choisit où se battre.
func _salle_07() -> Dictionary:
	var g := Commune.Grille.new(40, 30)
	for b in [[6, 5, 4, 4], [14, 11, 5, 5], [7, 20, 4, 4], [22, 4, 4, 4], [22, 19, 5, 5], [31, 12, 4, 4], [32, 23, 4, 4], [15, 24, 3, 3]]:
		g.rect(b[0], b[1], b[2], b[3], "#")
	g.poser(2, 15, "J")
	g.poser(36, 5, "1")
	g.poser(37, 17, "2")
	g.poser(27, 27, "3")
	return {
		"titre": "Trois chasseurs",
		"intention": "Des îlots de pierre, trois lampes, trois chasseurs. À vous de choisir où l'on se bat.",
		"g": g, "orientation": 0,
		"pnj": [_chasseur(true), _chasseur(true), _chasseur(true)],
		"lampes": [_lampe(12, 17, 3.5), _lampe(28, 11, 3.5), _lampe(20, 28, 3.5)],
	}


## 7.8 — Le dédale : un labyrinthe de murets que l'on voit par-dessus et que l'on ne traverse pas (pas de 3 : des passages de deux cases ; aucun mur plein à l'intérieur,
## carrefours compris). Trois chasseurs équipés, deux lampes.
func _salle_08() -> Dictionary:
	var g := Commune.Grille.new(37, 28)
	Laby.dessiner(g, 12, 9, 48, 10, "~", "~")
	g.poser(1, 1, "J")
	g.poser(34, 25, "1")
	g.poser(34, 1, "2")
	g.poser(1, 25, "3")
	return {
		"titre": "Le dédale",
		"intention": "Un labyrinthe de murets. On voit par-dessus, on ne passe pas : il faut en faire le tour.",
		"g": g, "orientation": 45,
		"pnj": [_chasseur(true), _chasseur(true), _chasseur(true)],
		"lampes": [_lampe(16, 13, 4.0), _lampe(25, 13, 4.0)],
	}


## 7.9 — La salle pleine : une grande carte, des colonnes en quinconce, quatre lampes, quatre chasseurs équipés qui partent des quatre coins. La meute.
func _salle_09() -> Dictionary:
	var g := Commune.Grille.new(50, 36)
	for j in 4:
		for i in 5:
			var x := 8 + 8 * i + (4 if j % 2 == 1 else 0)
			var y := 5 + 8 * j
			if x + 2 < 49:
				g.rect(x, y, 2, 2, "#")
	g.poser(2, 18, "J")
	g.poser(46, 3, "1")
	g.poser(46, 32, "2")
	g.poser(20, 2, "3")
	g.poser(20, 33, "4")
	return {
		"titre": "La salle pleine",
		"intention": "Une grande salle à colonnes, quatre lampes. Quatre chasseurs, et pas un qui reste à sa place.",
		"g": g, "orientation": 0,
		"pnj": [_chasseur(true), _chasseur(true), _chasseur(true), _chasseur(true)],
		"lampes": [_lampe(14, 9, 4.0), _lampe(36, 9, 4.0), _lampe(14, 27, 4.0), _lampe(36, 27, 4.0)],
	}


## 7.10 — L'Occulteur : l'arène de 32 × 32, variée — des colonnes en carré autour du centre, un bloc au milieu, de courts murets sur la voie du centre. Symétrique d'est en
## ouest et du nord au sud ; les deux lampes se font face.
func _salle_10() -> Dictionary:
	var g := Commune.Grille.new(32, 32)
	g.rect_miroirs(7, 7, 2, 2, "#")
	g.rect_miroirs(12, 12, 2, 2, "#")
	g.rect_miroirs(14, 3, 4, 1, "#")
	g.rect_miroir_x(15, 14, 1, 4, "~")
	g.poser(3, 16, "J")
	g.poser(28, 16, "1")
	return {
		"titre": "L'Occulteur",
		"intention": "Un duel dans une arène. Il pose une plaque devant la lumière, et une ombre qui n'est personne.",
		"boss": true,
		"g": g, "orientation": 0,
		"pnj": [{"profil": "boss", "classe": CLASSE}],
		"lampes": [_lampe(10, 16, 4.5), _lampe(21, 16, 4.5)],
	}
