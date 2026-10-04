## Fabrique le chapitre 1 de l'aventure, « Les rondes » — chantier SOLO, étape S8.
##
## Dix salles dans `res://assets/solo/chapitre_01/` : le manifeste (`chapitre.json`, qui débloque le Fumiste) et `niveau_01.json` … `niveau_10.json`.
## L'initiation n'avait aucune ronde (Adrien) : ce chapitre est le premier où les PNJ marchent. Ils suivent des trajets qui se répètent ; on apprend à
## les lire, puis à choisir son moment — d'abord contre des rondes qui ne perçoivent rien, ensuite contre des rondes qui voient. **À partir de 1.7, les
## rondes portent la classe du boss et se servent de sa suie** (`"equipe": true`, S8) : on apprend qu'une fumée bouche la vue avant de l'affronter.
##
## Le dessin et l'écriture sont ceux de `fabrique_commune.gd` (voir son en-tête) ; ce fichier ne contient que les salles. Il a la même règle que
## `fabrique_chapitre_00.gd` : **les JSON sont la vérité du jeu, ce script n'est que la façon dont on les a écrits**, et `tools/test_chapitre_01.gd`
## mesure sur eux ce que chaque salle ENSEIGNE.
##
## Lancer : godot --headless --path . --script res://tools/fabrique_chapitre_01.gd
extends SceneTree

const Commune := preload("res://tools/fabrique_commune.gd")

const DOSSIER := "res://assets/solo/chapitre_01"
const CLASSE := "fumiste"


func _init() -> void:
	var salles: Array[Dictionary] = [
		_salle_01(), _salle_02(), _salle_03(), _salle_04(), _salle_05(),
		_salle_06(), _salle_07(), _salle_08(), _salle_09(), _salle_10(),
	]
	Commune.fabriquer(DOSSIER, 1, "Les rondes", CLASSE, "Les rondes", salles)
	quit()


func _lampe(x: int, y: int, rayon: float) -> Dictionary:
	return {"case": [x, y], "rayon": rayon, "intensite": 1.2}


## Un PNJ de ronde du chapitre, équipé de la suie du Fumiste à partir de 1.7.
func _ronde(profil: String, points: Array, equipe: bool = false) -> Dictionary:
	var p := {"profil": profil, "ronde": points}
	if equipe:
		p["classe"] = CLASSE
		p["equipe"] = true
	return p


# ---------------------------------------------------------------------------
# LES DIX SALLES
# ---------------------------------------------------------------------------

## 1.1 — Une ronde : un bloc au milieu d'une pièce, un couloir qui en fait le tour, une lampe sur le trajet. La silhouette ne perçoit rien ; elle repasse
## sous la lampe à chaque tour, et c'est ainsi qu'on lit sa ronde.
func _salle_01() -> Dictionary:
	var g := Commune.Grille.new(22, 16)
	g.rect(6, 4, 10, 8, "#")
	g.poser(1, 8, "J")
	return {
		"titre": "Une ronde",
		"intention": "Une silhouette fait le tour du bloc, toujours par le même chemin. Elle repasse sous la lampe.",
		"g": g, "orientation": 0,
		"pnj": [_ronde("ronde_sourd_aveugle", [[3, 2], [18, 2], [18, 13], [3, 13]])],
		"lampes": [_lampe(10, 2, 4.0)],
	}


## 1.2 — Le croisement : une salle en croix, deux rondes en rectangle, l'une à l'horizontale et l'autre à la verticale. Elles se croisent en quatre
## cases, et deux lampes en éclairent deux.
func _salle_02() -> Dictionary:
	var g := Commune.Grille.new(24, 24)
	g.rect(1, 1, 5, 5, "#")
	g.rect(18, 1, 5, 5, "#")
	g.rect(1, 18, 5, 5, "#")
	g.rect(18, 18, 5, 5, "#")
	g.poser(11, 22, "J")
	return {
		"titre": "Le croisement",
		"intention": "Deux silhouettes, deux tours, un carrefour. Elles s'y croisent sous les lampes.",
		"g": g, "orientation": -90,
		"pnj": [
			_ronde("ronde_sourd_aveugle", [[3, 8], [20, 8], [20, 15], [3, 15]]),
			_ronde("ronde_sourd_aveugle", [[15, 3], [15, 20], [8, 20], [8, 3]]),
		],
		"lampes": [_lampe(8, 8, 3.5), _lampe(15, 15, 3.5)],
	}


## 1.3 — La ronde dans le noir : un grand tour de 76 cases, aucune lampe. Aucune case n'en montre plus d'une partie à la torche : on la suit, à l'oreille.
func _salle_03() -> Dictionary:
	var g := Commune.Grille.new(30, 20)
	g.rect(8, 5, 14, 10, "#")
	g.poser(1, 10, "J")
	return {
		"titre": "La ronde dans le noir",
		"intention": "Une silhouette marche dans le noir. On entend ses pas avant de la voir.",
		"g": g, "orientation": 0,
		"pnj": [_ronde("ronde_sourd_aveugle", [[3, 2], [26, 2], [26, 17], [3, 17]])],
		"lampes": [],
	}


## 1.4 — Le guetteur : une salle carrée, un pilier au milieu. Une ronde en fait le tour ; un guetteur qui voit se tient à l'est, sous une lampe, et regarde
## passer la ronde. Le pilier lui cache le reste du tour.
func _salle_04() -> Dictionary:
	var g := Commune.Grille.new(22, 22)
	g.rect(8, 8, 6, 6, "#")
	g.poser(1, 19, "J")
	g.poser(19, 10, "1")
	return {
		"titre": "Le guetteur",
		"intention": "Elle fait le tour du pilier. Lui ne bouge pas, et il regarde passer.",
		"g": g, "orientation": -45,
		"pnj": [
			_ronde("ronde_sourd_aveugle", [[4, 4], [17, 4], [17, 17], [4, 17]]),
			{"profil": "immobile_voit_lent", "orientation": 180},
		],
		"lampes": [_lampe(19, 10, 3.5)],
	}


## 1.5 — Elle regarde : deux couloirs parallèles, séparés par une cloison, qui se rejoignent à chaque bout. Une ronde qui voit en fait le tour ; une lampe
## éclaire le passage de l'est. Pour le traverser, il faut qu'elle soit de l'autre côté de la cloison.
func _salle_05() -> Dictionary:
	var g := Commune.Grille.new(32, 16)
	g.rect(5, 6, 22, 4, "#")
	g.poser(1, 8, "J")
	return {
		"titre": "Elle regarde",
		"intention": "Deux couloirs, une cloison entre eux. Elle regarde en marchant, et la lampe éclaire le passage.",
		"g": g, "orientation": 0,
		"pnj": [_ronde("ronde_voit_lent", [[3, 3], [28, 3], [28, 12], [3, 12]])],
		"lampes": [_lampe(29, 8, 4.0)],
	}


## 1.6 — Sous la lumière : un long hall, trois lampes en enfilade, deux rondes qui voient. Chacune traverse deux flaques ; les trois flaques sont sur une
## même ligne, et la flaque du milieu est commune aux deux rondes.
func _salle_06() -> Dictionary:
	var g := Commune.Grille.new(36, 15)
	g.rect(10, 6, 3, 3, "#")
	g.rect(22, 6, 3, 3, "#")
	g.poser(1, 13, "J")
	return {
		"titre": "Sous la lumière",
		"intention": "Trois lampes en enfilade. Deux silhouettes qui regardent y passent, chacune à son tour.",
		"g": g, "orientation": 0,
		"pnj": [
			_ronde("ronde_voit_lent", [[6, 2], [16, 2], [16, 12], [6, 12]]),
			_ronde("ronde_voit_lent", [[18, 2], [28, 2], [28, 12], [18, 12]]),
		],
		"lampes": [_lampe(6, 7, 3.5), _lampe(17, 7, 3.5), _lampe(28, 7, 3.5)],
	}


## 1.7 — La suie : une salle en U, un garde dans chaque bras. Ils portent le Fumiste : touché, l'un d'eux pose sa suie. Une lampe éclaire le fond du U.
func _salle_07() -> Dictionary:
	var g := Commune.Grille.new(26, 22)
	g.rect(8, 1, 10, 16, "#")
	g.poser(9, 20, "J")
	return {
		"titre": "La suie",
		"intention": "Deux gardes de part et d'autre du U, une lampe au fond. Quand l'un est touché, la fumée monte.",
		"g": g, "orientation": -90,
		"pnj": [
			_ronde("ronde_voit_lent", [[3, 3], [6, 3], [6, 18], [3, 18]], true),
			_ronde("ronde_voit_lent", [[19, 3], [22, 3], [22, 18], [19, 18]], true),
		],
		"lampes": [_lampe(12, 17, 3.5)],
	}


## 1.8 — La garde : une cour, trois piliers, des murets. Trois rondes tournent chacune autour d'un pilier ; un poste ne bouge pas au sud, sous une lampe.
func _salle_08() -> Dictionary:
	var g := Commune.Grille.new(30, 24)
	g.rect(6, 5, 3, 3, "#")
	g.rect(21, 5, 3, 3, "#")
	g.rect(13, 14, 3, 3, "#")
	g.rect(3, 11, 11, 1, "~")
	g.rect(18, 11, 9, 1, "~")
	g.rect(12, 20, 6, 1, "~")
	g.poser(2, 21, "J")
	g.poser(14, 9, "1")
	return {
		"titre": "La garde",
		"intention": "Une cour, des murets, trois rondes. Un poste ne bouge pas, tout au fond.",
		"g": g, "orientation": 0,
		"pnj": [
			_ronde("ronde_voit_lent", [[4, 3], [10, 3], [10, 9], [4, 9]], true),
			_ronde("ronde_voit_lent", [[19, 3], [25, 3], [25, 9], [19, 9]], true),
			_ronde("ronde_voit_lent", [[11, 13], [17, 13], [17, 19], [11, 19]], true),
			{"profil": "immobile_voit_lent", "orientation": 90},
		],
		"lampes": [_lampe(14, 8, 4.0), _lampe(14, 21, 3.5)],
	}


## 1.9 — La salle pleine : une grande salle à colonnes, trois rondes qui voient, deux silhouettes qui ne perçoivent rien dans le noir de l'est et du nord.
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
		"intention": "Des colonnes, des lampes, trois rondes. Deux silhouettes ne bougent pas, dans le noir.",
		"g": g, "orientation": -90,
		"pnj": [
			_ronde("ronde_voit_lent", [[5, 3], [15, 3], [15, 11], [5, 11]], true),
			_ronde("ronde_voit_lent", [[24, 3], [34, 3], [34, 11], [24, 11]], true),
			_ronde("ronde_voit_lent", [[4, 19], [35, 19], [35, 27], [4, 27]], true),
			{"profil": "immobile_sourd_aveugle"},
			{"profil": "immobile_sourd_aveugle"},
		],
		"lampes": [_lampe(10, 3, 3.5), _lampe(34, 7, 3.5), _lampe(19, 19, 4.0)],
	}


## 1.10 — Le Fumiste : l'arène du chapitre 0, variée — quatre piliers aux coins, un pilier au centre, des murets courts de part et d'autre de la voie du
## milieu. Symétrique d'est en ouest et du nord au sud ; les deux lampes se font face.
func _salle_10() -> Dictionary:
	var g := Commune.Grille.new(32, 32)
	g.rect_miroirs(6, 6, 2, 2, "#")
	g.rect(15, 15, 2, 2, "#")
	g.rect_miroirs(12, 11, 1, 4, "~")
	g.poser(3, 16, "J")
	g.poser(28, 16, "1")
	return {
		"titre": "Le Fumiste",
		"intention": "Un duel dans une arène. Il a de la suie, et il s'en sert.",
		"boss": true,
		"g": g, "orientation": 0,
		"pnj": [{"profil": "boss", "classe": CLASSE}],
		"lampes": [_lampe(10, 16, 4.5), _lampe(21, 16, 4.5)],
	}
