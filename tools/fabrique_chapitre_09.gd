## Fabrique le chapitre 9 de l'aventure, « L'élite » — chantier SOLO, étape S8, lot 2.
##
## Dix salles dans `res://assets/solo/chapitre_09/` : le manifeste (`chapitre.json`, qui débloque le Spectre, slug `spectre`) et `niveau_01.json` … `niveau_10.json`.
## Peu d'ennemis, mais les meilleurs : des chasseurs libres de niveau DIFFICILE (`libre_voit_entend_difficile`), seuls ou par deux ou trois, dans des salles qui sont chacune
## un duel difficile ou deux. On sort de ce chapitre prêt pour le classé. **À partir de 9.7, tout ce qui bouge porte la classe du boss et son voile** (`"equipe": true`, S8) :
## la bâche tendue qui arrête la lumière et laisse passer les balles. Un PNJ DIFFICILE équipé a, en plus du gadget, tout ce que S9 donne à son palier : torche tactique, repli,
## posture accroupie, fusée.
##
## Le voile se pose « face à la torche de la cible, qu'on VOIT » (`EquipementBot.GADGETS`, états recherche et combat) : un PNJ équipé doit VOIR. Tous voient et entendent ; la
## garde (`GADGET_EXIGE_CHASSEURS`) l'exige. Les postes et les gardes de zone (9.5, 9.6) ne bougent pas assez pour que la bâche serve : les postes ne sont pas équipés — comme aux
## chapitres d'avant (« seuls les PNJ qui bougent sont équipés ») —, les gardes de zone le sont à partir de 9.7.
##
## Le dessin et l'écriture sont ceux de `fabrique_commune.gd` ; ce fichier ne contient que les salles, et `tools/test_chapitre_09.gd` mesure sur leurs JSON ce que chacune
## ENSEIGNE. **Les JSON sont la vérité du jeu, ce script n'est que la façon dont on les a écrits.**
##
## Lancer : godot --headless --path . --script res://tools/fabrique_chapitre_09.gd
extends SceneTree

const Commune := preload("res://tools/fabrique_commune.gd")
const Laby := preload("res://tools/fabrique_labyrinthe.gd")

const DOSSIER := "res://assets/solo/chapitre_09"
const CLASSE := "spectre"
const ELITE := "libre_voit_entend_difficile"


func _init() -> void:
	var salles: Array[Dictionary] = [
		_salle_01(), _salle_02(), _salle_03(), _salle_04(), _salle_05(),
		_salle_06(), _salle_07(), _salle_08(), _salle_09(), _salle_10(),
	]
	Commune.fabriquer(DOSSIER, 9, "L'élite", CLASSE, "L'élite", salles)
	quit()


func _lampe(x: int, y: int, rayon: float) -> Dictionary:
	return {"case": [x, y], "rayon": rayon, "intensite": 1.2}


func _equiper(p: Dictionary, equipe: bool) -> Dictionary:
	if equipe:
		p["classe"] = CLASSE
		p["equipe"] = true
	return p


## Une élite : un chasseur libre de niveau DIFFICILE ; équipée du voile du Spectre à partir de 9.7.
func _elite(equipe: bool = false) -> Dictionary:
	return _equiper({"profil": ELITE}, equipe)


func _zone(rect: Array, equipe: bool = false) -> Dictionary:
	return _equiper({"profil": "zone_voit_entend_normal", "zone": rect}, equipe)


# ---------------------------------------------------------------------------
# LES DIX SALLES
# ---------------------------------------------------------------------------

## 9.1 — L'élite : une arène de 24 × 24, quatre blocs de 3 × 3 autour du centre, deux lampes. Un adversaire seul, de niveau difficile.
func _salle_01() -> Dictionary:
	var g := Commune.Grille.new(24, 24)
	g.rect_miroirs(7, 7, 3, 3, "#")
	g.poser(2, 12, "J")
	g.poser(21, 11, "1")
	return {
		"titre": "L'élite",
		"intention": "Une arène, deux lampes, un seul adversaire. Il ne laisse rien au hasard.",
		"g": g, "orientation": 0,
		"pnj": [_elite()],
		"lampes": [_lampe(11, 3, 4.0), _lampe(12, 20, 4.0)],
	}


## 9.2 — Le noir : 28 × 28, aucune lampe, des piliers. Un duel difficile où rien ne se voit que ce qu'on allume, et où tout s'entend.
func _salle_02() -> Dictionary:
	var g := Commune.Grille.new(28, 28)
	g.rect_miroirs(8, 8, 2, 2, "#")
	g.rect(13, 13, 2, 2, "#")
	g.poser(2, 14, "J")
	g.poser(25, 13, "1")
	return {
		"titre": "Le noir",
		"intention": "Pas une lampe. Un seul adversaire, et il écoute chacun de vos pas.",
		"g": g, "orientation": 0,
		"pnj": [_elite()],
		"lampes": [],
	}


## 9.3 — La flaque : 26 × 26, une seule lampe au centre, quatre colonnes aux coins. La ligne droite traverse la flaque ; le noir tourne autour.
func _salle_03() -> Dictionary:
	var g := Commune.Grille.new(26, 26)
	g.rect_miroirs(5, 5, 2, 2, "#")
	g.poser(2, 13, "J")
	g.poser(23, 12, "1")
	return {
		"titre": "La flaque",
		"intention": "Une flaque de lumière au centre de l'arène, du noir tout autour. Il la contourne comme vous.",
		"g": g, "orientation": 0,
		"pnj": [_elite()],
		"lampes": [_lampe(13, 13, 6.0)],
	}


## 9.4 — Le binôme d'élite : 36 × 28, une carte à îlots, deux lampes. Deux adversaires de niveau difficile, qui partent ensemble du fond.
func _salle_04() -> Dictionary:
	var g := Commune.Grille.new(36, 28)
	for b in [[8, 5, 4, 4], [14, 12, 4, 4], [8, 19, 4, 4], [22, 6, 4, 4], [22, 18, 4, 4], [29, 12, 3, 3]]:
		g.rect(b[0], b[1], b[2], b[3], "#")
	g.poser(2, 14, "J")
	g.poser(33, 5, "1")
	g.poser(33, 22, "2")
	return {
		"titre": "Le binôme d'élite",
		"intention": "Des îlots de pierre, deux lampes. Ils sont deux, et ils chassent ensemble.",
		"g": g, "orientation": 0,
		"pnj": [_elite(), _elite()],
		"lampes": [_lampe(18, 8, 4.0), _lampe(18, 24, 4.0)],
	}


## 9.5 — Le voile : 34 × 26. Trois voiles de mur mince — des bâches tendues — que la lumière ne traverse pas, deux lampes à côté d'eux. Une élite libre, et un garde qui erre dans
## le coin que les voiles ferment.
func _salle_05() -> Dictionary:
	var g := Commune.Grille.new(34, 26)
	g.rect(9, 3, 1, 9, "#")
	g.rect(16, 14, 1, 9, "#")
	g.rect(23, 3, 1, 9, "#")
	g.poser(2, 13, "J")
	g.poser(31, 21, "1")
	g.poser(29, 5, "2")
	return {
		"titre": "Le voile",
		"intention": "Des voiles tendus coupent la lumière des lampes. Derrière eux, de l'ombre, et quelqu'un.",
		"g": g, "orientation": 0,
		"pnj": [_elite(), _zone([25, 1, 8, 10])],
		"lampes": [_lampe(11, 8, 8.0), _lampe(18, 18, 8.0)],
	}


## 9.6 — La garde d'élite : 38 × 24, un hall. Au fond, dans une niche éclairée, un poste de niveau difficile qui regarde le hall ; devant lui, de part et d'autre de l'axe, deux
## gardes de niveau normal, chacun sa zone. Trois lampes.
func _salle_06() -> Dictionary:
	var g := Commune.Grille.new(38, 24)
	g.rect(34, 1, 3, 9, "#")
	g.rect(34, 14, 3, 9, "#")
	g.rect(11, 5, 2, 2, "#")
	g.rect(11, 17, 2, 2, "#")
	g.rect(24, 9, 2, 2, "#")
	g.rect(24, 13, 2, 2, "#")
	g.poser(2, 12, "J")
	g.poser(35, 11, "1")
	g.poser(18, 5, "2")
	g.poser(18, 18, "3")
	return {
		"titre": "La garde d'élite",
		"intention": "Un hall, deux gardes en avant, un poste au fond dans sa niche. Le poste regarde tout le hall.",
		"g": g, "orientation": 0,
		"pnj": [{"profil": "immobile_voit_entend_difficile", "orientation": 180}, _zone([14, 1, 18, 9]), _zone([14, 14, 18, 9])],
		"lampes": [_lampe(32, 11, 5.0), _lampe(20, 6, 4.0), _lampe(20, 17, 4.0)],
	}


## 9.7 — Le dédale : 40 × 31, un labyrinthe de cloisons pleines percées de fenêtres basses (pas de 3 : des passages de deux cases). Deux élites équipées du Spectre, deux lampes.
func _salle_07() -> Dictionary:
	var g := Commune.Grille.new(40, 31)
	Laby.dessiner(g, 13, 10, SEED_DEDALE, 12, "#", "#", 0.35)
	g.poser(1, 1, "J")
	g.poser(37, 28, "1")
	g.poser(1, 28, "2")
	return {
		"titre": "Le dédale",
		"intention": "Un labyrinthe de cloisons percées de fenêtres basses. Deux élites y chassent.",
		"g": g, "orientation": 45,
		"pnj": [_elite(true), _elite(true)],
		"lampes": [_lampe(19, 13, 4.0), _lampe(19, 19, 4.0)],
	}


## 9.8 — La meute d'élite : 56 × 40, une grande carte : neuf blocs de 5 × 4 sur une trame régulière, quatre lampes. Trois élites équipées, parties de trois côtés.
func _salle_08() -> Dictionary:
	var g := Commune.Grille.new(56, 40)
	for j in 3:
		for i in 3:
			g.rect(10 + 15 * i, 6 + 12 * j, 5, 4, "#")
	g.poser(2, 20, "J")
	g.poser(52, 5, "1")
	g.poser(52, 34, "2")
	g.poser(26, 37, "3")
	return {
		"titre": "La meute d'élite",
		"intention": "Une grande carte, quatre lampes. Trois élites, et pas une qui renonce.",
		"g": g, "orientation": 0,
		"pnj": [_elite(true), _elite(true), _elite(true)],
		"lampes": [_lampe(19, 17, 4.5), _lampe(34, 11, 4.5), _lampe(34, 29, 4.5), _lampe(48, 20, 4.5)],
	}


## 9.9 — La salle pleine : 64 × 48. La dernière avant le Spectre : douze blocs sur une trame, deux gardes dans deux coins opposés, un poste de niveau difficile au nord, deux élites
## libres, cinq lampes. Tout ce qui bouge porte le voile.
func _salle_09() -> Dictionary:
	var g := Commune.Grille.new(64, 48)
	for j in 3:
		for i in 4:
			g.rect(14 + 14 * i, 12 + 11 * j, 5, 4, "#")
	g.poser(2, 24, "J")
	g.poser(32, 4, "1")
	g.poser(8, 6, "2")
	g.poser(55, 41, "3")
	g.poser(58, 6, "4")
	g.poser(6, 42, "5")
	return {
		"titre": "La salle pleine",
		"intention": "La dernière salle avant le Spectre. Des élites, des gardes, un poste, et une carte immense.",
		"g": g, "orientation": 0,
		"pnj": [
			{"profil": "immobile_voit_entend_difficile", "orientation": 90},
			_zone([1, 1, 20, 14], true), _zone([43, 33, 20, 14], true),
			_elite(true), _elite(true),
		],
		"lampes": [_lampe(32, 7, 5.0), _lampe(10, 9, 5.0), _lampe(53, 40, 5.0), _lampe(36, 26, 5.0), _lampe(48, 17, 5.0)],
	}


## 9.10 — Le Spectre : l'arène de 32 × 32, avec quatre voiles — des murs minces de sept cases — qui laissent un passage de deux cases sur l'axe. Chacune des deux lampes se tient à
## deux cases d'un voile, qui lui coupe sa propre flaque. Les murs sont symétriques d'est en ouest et du nord au sud ; les lampes se font face d'est en ouest, côté nord.
func _salle_10() -> Dictionary:
	var g := Commune.Grille.new(32, 32)
	g.rect_miroirs(10, 8, 1, 7, "#")
	g.rect_miroirs(5, 5, 2, 2, "#")
	g.rect_miroir_x(15, 3, 2, 2, "#")
	g.rect_miroir_x(15, 27, 2, 2, "#")
	g.poser(2, 16, "J")
	g.poser(29, 16, "1")
	return {
		"titre": "Le Spectre",
		"intention": "Un duel dans une arène. Il tend une bâche : la lumière s'arrête, les balles passent.",
		"boss": true,
		"g": g, "orientation": 0,
		"pnj": [{"profil": "boss", "classe": CLASSE}],
		"lampes": [_lampe(8, 10, 7.0), _lampe(23, 10, 7.0)],
	}


## La graine du labyrinthe de 9.7 : choisie parmi soixante pour que le chemin du joueur à chacune des deux élites fasse au moins deux fois et demie la ligne droite.
const SEED_DEDALE := 35
