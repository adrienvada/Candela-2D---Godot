## Fabrique le chapitre 0 de l'aventure, « L'initiation » — chantier SOLO, étape S7.
##
## Dix salles dans `res://assets/solo/chapitre_00/` : le manifeste (`chapitre.json`) et `niveau_01.json` … `niveau_10.json`. C'est le
## CONTENU livré ; le moteur (S6) le lit tel quel. Le modèle est `fabrique_aventure_essai.gd`.
##
## ## Pourquoi un outil, et pas dix JSON écrits à la main
##
## Une carte est une suite de runs RLE (`"1,1,14;1,2,14;…"`), illisible : la corriger à la main, c'est la refaire. Ici une salle est un
## DESSIN — des rectangles de mur, de mur bas, de sol — plus ses PNJ et ses plafonniers en clair. Corriger une salle, c'est changer
## une ligne de ce fichier et relancer ; **les JSON sont la vérité du jeu, ce script n'est que la façon dont on les a écrits**. Rien
## n'y est tiré au hasard et rien n'y est daté : relancer ne change aucun octet tant que ce fichier ne change pas.
##
## ## Le dessin
##
## Une salle est une grille `largeur × hauteur` : `#` mur plein, `.` sol, `~` mur bas (posé sur du sol). `J` (la case du joueur) et les
## chiffres `1` à `9` (les PNJ, dans l'ordre de la liste `pnj`) sont des repères posés sur du sol. Les plafonniers se disent en clair
## (`lampes`), parce qu'un plafonnier peut tenir la même case qu'un PNJ. Le script imprime chaque salle, plafonniers en `*`, pour qu'on
## la relise avant d'ouvrir le jeu.
##
## ## Ce que le tracé doit à la garde
##
## `tools/test_chapitre_00.gd` mesure sur ces fichiers ce que chaque salle ENSEIGNE : un PNJ qu'on n'atteint pas à pied, une lampe qui
## éclaire le PNJ de 0.2, un chargeur qui suffit en 0.3, un PNJ de 0.5 à portée de torche… chacun fait rougir la garde. Changer un
## dessin ici, c'est donc le faire juger.
##
## Lancer : godot --headless --path . --script res://tools/fabrique_chapitre_00.gd
extends SceneTree

const DOSSIER := "res://assets/solo/chapitre_00"
const TUILE := 35
const CLASSE := "pistolet"


## La grille d'une salle : un tableau de lignes de caractères, avec de quoi dessiner dedans.
class Grille:
	var l := 0
	var h := 0
	var c: Array = []   # c[y][x] : un caractère

	func _init(largeur: int, hauteur: int) -> void:
		l = largeur
		h = hauteur
		for y in h:
			var ligne: Array = []
			for x in l:
				ligne.append("#" if x == 0 or y == 0 or x == l - 1 or y == h - 1 else ".")
			c.append(ligne)

	## Remplit un rectangle de cases (x, y, largeur, hauteur) du caractère donné.
	func rect(x: int, y: int, w: int, hh: int, ch: String) -> void:
		for yy in range(y, y + hh):
			for xx in range(x, x + w):
				c[yy][xx] = ch

	func poser(x: int, y: int, ch: String) -> void:
		c[y][x] = ch

	func lire(x: int, y: int) -> String:
		return c[y][x]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DOSSIER)
	var salles: Array[Dictionary] = [
		_salle_01(), _salle_02(), _salle_03(), _salle_04(), _salle_05(),
		_salle_06(), _salle_07(), _salle_08(), _salle_09(), _salle_10(),
	]
	var fichiers: Array[String] = []
	for i in salles.size():
		var nom := "niveau_%02d.json" % (i + 1)
		fichiers.append(nom)
		_ecrire(nom, _niveau(salles[i]))
		_apercu(i + 1, salles[i])
	_ecrire("chapitre.json", {
		"version": 1,
		"numero": 0,
		"titre": "L'initiation",
		"classe_debloquee": CLASSE,
		"classe_imposee": CLASSE,
		"niveaux": fichiers,
	})
	print("Chapitre 0 écrit dans ", DOSSIER)
	quit()


# ---------------------------------------------------------------------------
# LES DIX SALLES
# ---------------------------------------------------------------------------

## 0.1 — Le premier pas : un plafonnier au centre, rien d'autre. Le PNJ est sous la lampe, vu dès l'entrée.
func _salle_01() -> Dictionary:
	var g := Grille.new(16, 16)
	g.poser(2, 8, "J")
	g.poser(9, 8, "1")
	return {
		"titre": "Le premier pas",
		"intention": "Au milieu de la pièce, une silhouette sous la lampe.",
		"g": g, "orientation": 0,
		"pnj": [{"profil": "immobile_sourd_aveugle"}],
		"lampes": [{"case": [8, 8], "rayon": 4.0, "intensite": 1.2}],
	}


## 0.2 — La torche : un pilier, un PNJ dans le noir derrière lui. Une lampe d'entrée éclaire le départ, loin du PNJ.
func _salle_02() -> Dictionary:
	var g := Grille.new(18, 18)
	g.rect(9, 6, 2, 5, "#")
	g.poser(2, 9, "J")
	g.poser(12, 8, "1")
	return {
		"titre": "La torche",
		"intention": "Un pilier au milieu du noir. Quelqu'un se tient derrière.",
		"g": g, "orientation": 0,
		"pnj": [{"profil": "immobile_sourd_aveugle"}],
		"lampes": [{"case": [3, 9], "rayon": 2.5, "intensite": 1.2}],
	}


## 0.3 — Fouiller : trois recoins aux quatre coins d'une salle, une lampe au centre. Chacun garde un PNJ dans le noir.
func _salle_03() -> Dictionary:
	var g := Grille.new(20, 20)
	# Nord-ouest : un coin ouvert en son angle sud-est.
	g.rect(7, 1, 1, 4, "#")
	g.rect(1, 7, 4, 1, "#")
	# Nord-est.
	g.rect(12, 1, 1, 4, "#")
	g.rect(15, 7, 4, 1, "#")
	# Sud-ouest.
	g.rect(7, 15, 1, 4, "#")
	g.rect(1, 12, 4, 1, "#")
	g.poser(17, 17, "J")
	g.poser(2, 2, "1")
	g.poser(17, 2, "2")
	g.poser(2, 17, "3")
	return {
		"titre": "Fouiller",
		"intention": "Trois recoins, une seule lampe, du noir partout ailleurs. Six cartouches.",
		"g": g, "orientation": -135,
		"pnj": [{"profil": "immobile_sourd_aveugle"}, {"profil": "immobile_sourd_aveugle"}, {"profil": "immobile_sourd_aveugle"}],
		"lampes": [{"case": [10, 10], "rayon": 4.5, "intensite": 1.2}],
	}


## 0.4 — Les murs bas : trois rangées de murets en chicane, chacune ouverte à l'un de ses bouts. Un PNJ derrière la première, un derrière la deuxième.
func _salle_04() -> Dictionary:
	var g := Grille.new(20, 18)
	g.rect(6, 1, 1, 12, "~")
	g.rect(11, 5, 1, 12, "~")
	g.rect(15, 1, 1, 12, "~")
	g.poser(2, 8, "J")
	g.poser(9, 3, "1")
	g.poser(13, 14, "2")
	return {
		"titre": "Les murs bas",
		"intention": "Trois rangées de murets. Deux silhouettes derrière.",
		"g": g, "orientation": 0,
		"pnj": [{"profil": "immobile_sourd_aveugle"}, {"profil": "immobile_sourd_aveugle"}],
		"lampes": [{"case": [9, 9], "rayon": 3.5, "intensite": 1.2}],
	}


## 0.5 — La fusée : une grande salle sans lampe. Les trois PNJ tiennent un coin que la torche n'atteint pas depuis le chemin du centre ;
## une seule fusée lancée de ce chemin les éclaire tous les trois.
func _salle_05() -> Dictionary:
	var g := Grille.new(24, 24)
	g.rect(5, 14, 2, 2, "#")
	g.rect(14, 5, 2, 2, "#")
	g.rect(17, 10, 2, 2, "#")
	g.rect(10, 17, 2, 2, "#")
	g.poser(22, 22, "J")
	g.poser(1, 1, "1")
	g.poser(3, 1, "2")
	g.poser(1, 3, "3")
	return {
		"titre": "La fusée",
		"intention": "Une salle trop grande pour la torche. Ce qu'elle cache est loin.",
		"g": g, "orientation": -135,
		"pnj": [{"profil": "immobile_sourd_aveugle"}, {"profil": "immobile_sourd_aveugle"}, {"profil": "immobile_sourd_aveugle"}],
		"lampes": [],
	}


## 0.6 — Il regarde : un PNJ qui voit, sous une lampe, au bout d'une salle ; une autre lampe sur la ligne droite. Qui passe par la
## lumière est vu ; le contour par le nord ou le sud reste dans le noir.
func _salle_06() -> Dictionary:
	var g := Grille.new(20, 20)
	g.rect(12, 5, 2, 2, "#")
	g.rect(12, 14, 2, 2, "#")
	g.poser(2, 10, "J")
	g.poser(16, 10, "1")
	return {
		"titre": "Il regarde",
		"intention": "Sous la lampe, il regarde. Ce qui brille se fait voir.",
		"g": g, "orientation": 0,
		"pnj": [{"profil": "immobile_voit_tres_lent"}],
		"lampes": [{"case": [8, 10], "rayon": 3.0, "intensite": 1.2}, {"case": [15, 10], "rayon": 3.0, "intensite": 1.2}],
	}


## 0.7 — L'éclair : une salle en L. Trois PNJ qui voient, éclairés chacun par sa lampe ; un pilier dans chaque branche donne où se mettre à couvert.
func _salle_07() -> Dictionary:
	var g := Grille.new(20, 20)
	g.rect(1, 1, 12, 12, "#")
	g.rect(17, 5, 2, 2, "#")
	g.rect(10, 14, 2, 2, "#")
	g.poser(16, 2, "J")
	g.poser(15, 9, "1")
	g.poser(17, 15, "2")
	g.poser(6, 16, "3")
	return {
		"titre": "L'éclair",
		"intention": "Trois silhouettes dans un coude. Un tir se voit de loin.",
		"g": g, "orientation": 90,
		"pnj": [{"profil": "immobile_voit_lent"}, {"profil": "immobile_voit_lent"}, {"profil": "immobile_voit_lent"}],
		"lampes": [{"case": [15, 8], "rayon": 2.5, "intensite": 1.2}, {"case": [16, 15], "rayon": 2.5, "intensite": 1.2},
			{"case": [7, 16], "rayon": 2.5, "intensite": 1.2}],
	}


## 0.8 — Il écoute : le sol nu, aucune lampe. Deux PNJ qui n'ont que leurs oreilles, au fond d'une salle vide.
func _salle_08() -> Dictionary:
	var g := Grille.new(20, 20)
	g.poser(2, 10, "J")
	g.poser(16, 6, "1")
	g.poser(16, 14, "2")
	return {
		"titre": "Il écoute",
		"intention": "Pas une lampe. Deux silhouettes qui n'ont que leurs oreilles.",
		"g": g, "orientation": 0,
		"pnj": [{"profil": "immobile_entend_lent"}, {"profil": "immobile_entend_lent"}],
		"lampes": [],
	}


## 0.9 — La salle pleine : tout ce qui précède. Deux recoins noirs, trois lampes, des murets, un pilier ; six PNJ de quatre sortes.
func _salle_09() -> Dictionary:
	var g := Grille.new(24, 24)
	# Le recoin du nord-ouest.
	g.rect(7, 1, 1, 4, "#")
	g.rect(1, 7, 4, 1, "#")
	# Le recoin du sud-ouest.
	g.rect(7, 19, 1, 4, "#")
	g.rect(1, 16, 4, 1, "#")
	# Un pilier, et deux rangées de murets.
	g.rect(14, 7, 2, 2, "#")
	g.rect(9, 14, 8, 1, "~")
	g.rect(19, 5, 1, 8, "~")
	g.poser(21, 21, "J")
	g.poser(2, 2, "1")    # sourd et aveugle, dans le noir
	g.poser(12, 11, "2")  # sourd et aveugle, sous la lampe du centre
	g.poser(17, 18, "3")  # voit, sous la lampe du sud
	g.poser(16, 3, "4")   # voit, sous la lampe du nord
	g.poser(2, 21, "5")   # entend, au fond de son recoin
	g.poser(21, 9, "6")   # voit et entend, derrière les murets
	return {
		"titre": "La salle pleine",
		"intention": "Des lampes, des recoins, des murets. Tout est là, et eux aussi.",
		"g": g, "orientation": -135,
		"pnj": [
			{"profil": "immobile_sourd_aveugle"}, {"profil": "immobile_sourd_aveugle"},
			{"profil": "immobile_voit_lent"}, {"profil": "immobile_voit_lent"},
			{"profil": "immobile_entend_lent"},
			{"profil": "immobile_voit_entend_lent"},
		],
		"lampes": [{"case": [11, 11], "rayon": 4.0, "intensite": 1.2}, {"case": [16, 18], "rayon": 3.0, "intensite": 1.2},
			{"case": [17, 3], "rayon": 3.0, "intensite": 1.2}],
	}


## 0.10 — Le Parasite : une arène de duel, symétrique d'est en ouest et du nord au sud, deux plafonniers face à face. Un bot, la classe du chapitre.
func _salle_10() -> Dictionary:
	var g := Grille.new(32, 32)
	g.rect(7, 9, 2, 2, "#")
	g.rect(23, 9, 2, 2, "#")
	g.rect(7, 21, 2, 2, "#")
	g.rect(23, 21, 2, 2, "#")
	g.rect(15, 15, 2, 2, "#")
	g.rect(13, 10, 6, 1, "~")
	g.rect(13, 21, 6, 1, "~")
	g.poser(3, 16, "J")
	g.poser(28, 16, "1")
	return {
		"titre": "Le Parasite",
		"intention": "Un duel dans une arène. Il voit, il entend, il tire — comme vous.",
		"boss": true,
		"g": g, "orientation": 0,
		"pnj": [{"profil": "boss", "classe": CLASSE}],
		"lampes": [{"case": [10, 16], "rayon": 4.5, "intensite": 1.2}, {"case": [21, 16], "rayon": 4.5, "intensite": 1.2}],
	}


# ---------------------------------------------------------------------------
# DU DESSIN AU FICHIER
# ---------------------------------------------------------------------------

func _niveau(s: Dictionary) -> Dictionary:
	var g: Grille = s["g"]
	var sol: Array[Vector2i] = []
	var murs: Array[Vector2i] = []
	var bas: Array[Vector2i] = []
	var joueur := Vector2i(-1, -1)
	var reperes := {}
	for y in g.h:
		for x in g.l:
			var ch := g.lire(x, y)
			if ch == "#":
				murs.append(Vector2i(x, y))
				continue
			sol.append(Vector2i(x, y))
			if ch == "~":
				bas.append(Vector2i(x, y))
			elif ch == "J":
				joueur = Vector2i(x, y)
			elif ch.is_valid_int():
				reperes[int(ch)] = Vector2i(x, y)
	var pnj: Array = []
	var liste: Array = s["pnj"]
	for i in liste.size():
		var p: Dictionary = (liste[i] as Dictionary).duplicate()
		var case: Vector2i = reperes[i + 1]
		p["case"] = [case.x, case.y]
		# Le PNJ fait face à la porte : l'orientation s'arrondit à 15°, un chiffre qu'on relit.
		var vers := Vector2(joueur - case)
		p["orientation"] = int(roundf(rad_to_deg(vers.angle()) / 15.0)) * 15
		pnj.append(p)
	var niveau := {
		"version": 1,
		"titre": s["titre"],
		"intention": s["intention"],
		"boss": bool(s.get("boss", false)),
		"carte": {
			"version": 4,
			"name": "Initiation — %s" % s["titre"],
			"grid_size": {"x": g.l, "y": g.h},
			"tile_size": TUILE,
			"floor": MapCodec.encode_runs(sol),
			"walls": MapCodec.encode_runs(murs),
			"low_walls": MapCodec.encode_runs(bas),
		},
		"joueur": {"case": [joueur.x, joueur.y], "orientation": s["orientation"]},
		"pnj": pnj,
	}
	if not (s["lampes"] as Array).is_empty():
		niveau["plafonniers"] = s["lampes"]
	return niveau


func _apercu(numero: int, s: Dictionary) -> void:
	var g: Grille = s["g"]
	var lignes: Array = []
	for y in g.h:
		var ligne := ""
		for x in g.l:
			ligne += g.lire(x, y)
		lignes.append(ligne)
	for lampe: Dictionary in s["lampes"]:
		var c: Array = lampe["case"]
		var ligne: String = lignes[c[1]]
		lignes[c[1]] = ligne.substr(0, c[0]) + "*" + ligne.substr(c[0] + 1)
	print("\n0.%d — %s (%d × %d)" % [numero, s["titre"], g.l, g.h])
	for ligne in lignes:
		print("  ", ligne)


func _ecrire(nom: String, donnees: Dictionary) -> void:
	var f := FileAccess.open(DOSSIER.path_join(nom), FileAccess.WRITE)
	f.store_string(JSON.stringify(donnees, "  ") + "\n")
	f.close()
