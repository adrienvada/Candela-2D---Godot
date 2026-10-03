## Ce que partagent les fabriques des chapitres 1 et suivants — chantier SOLO, étape S8.
##
## `fabrique_chapitre_00.gd` porte son dessin et son écriture dans le même fichier (le chapitre 0 n'a ni ronde, ni zone, ni classe). Les chapitres 1 à
## 3 en ont tous, et trois copies de la grille et de l'écriture auraient dérivé : elles vivent donc ici, une fois. Chaque `fabrique_chapitre_0N.gd`
## ne contient plus que SES salles — des dessins.
##
## ## Le dessin
##
## Une salle est une grille `largeur × hauteur` : `#` mur plein, `.` sol, `~` mur bas (posé sur du sol). `J` (le joueur) et les chiffres `1` à `9`
## sont des repères posés sur du sol : le `k`-ième PNJ de la liste `pnj` QUI N'EST PAS DE RONDE se tient sur le repère `k` ; un PNJ de ronde naît sur le
## PREMIER point de sa ronde (« la ronde part d'où le PNJ est » : le bot saute ce point et va au suivant). Les plafonniers se disent en clair (`lampes`).
##
## ## Un PNJ
##
## `{ "profil": "ronde_voit_lent", "ronde": [[x, y], …], "classe": "fumiste", "equipe": true }` — ou `"zone": [x, y, largeur, hauteur]`. L'orientation
## est celle du premier pas pour une ronde (vers son deuxième point), celle du joueur sinon, sauf si `"orientation"` (en degrés) est donnée ; elle
## s'arrondit à 15°, un chiffre qu'on relit.
##
## Rien n'y est tiré au hasard et rien n'y est daté : relancer une fabrique ne change aucun octet tant que son dessin ne change pas.

const TUILE := 35


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

	## Le même rectangle et son image dans un miroir d'est en ouest (x → l-1-x) : une arène symétrique se dessine d'un côté.
	func rect_miroir_x(x: int, y: int, w: int, hh: int, ch: String) -> void:
		rect(x, y, w, hh, ch)
		rect(l - x - w, y, w, hh, ch)

	## Un rectangle et ses trois images (miroir d'est en ouest et du nord au sud) : l'arène symétrique dans les deux sens.
	func rect_miroirs(x: int, y: int, w: int, hh: int, ch: String) -> void:
		rect_miroir_x(x, y, w, hh, ch)
		rect_miroir_x(x, h - y - hh, w, hh, ch)

	func poser(x: int, y: int, ch: String) -> void:
		c[y][x] = ch

	func lire(x: int, y: int) -> String:
		return c[y][x]


## Écrit un chapitre : son manifeste et ses salles. `salles` : les dessins (voir l'en-tête) ; `nom_carte` : le préfixe du nom de leurs cartes.
static func fabriquer(dossier: String, numero: int, titre: String, classe: String, nom_carte: String, salles: Array[Dictionary]) -> void:
	DirAccess.make_dir_recursive_absolute(dossier)
	var fichiers: Array[String] = []
	for i in salles.size():
		var nom := "niveau_%02d.json" % (i + 1)
		fichiers.append(nom)
		ecrire(dossier, nom, niveau(salles[i], nom_carte))
		apercu("%d.%d" % [numero, i + 1], salles[i])
	ecrire(dossier, "chapitre.json", {
		"version": 1,
		"numero": numero,
		"titre": titre,
		"classe_debloquee": classe,
		"niveaux": fichiers,
	})
	print("Chapitre %d écrit dans %s" % [numero, dossier])


## Du dessin au fichier de niveau.
static func niveau(s: Dictionary, nom_carte: String) -> Dictionary:
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
	var posés := 0   # les PNJ qui ne sont pas de ronde, dans l'ordre : le k-ième tient le repère k
	for i in liste.size():
		var p: Dictionary = (liste[i] as Dictionary).duplicate(true)
		var case: Vector2i
		var vers: Vector2
		if p.has("ronde"):
			var pts: Array = p["ronde"]
			case = Vector2i(int(pts[0][0]), int(pts[0][1]))
			vers = Vector2(int(pts[1][0]) - case.x, int(pts[1][1]) - case.y)
		else:
			posés += 1
			case = reperes[posés]
			vers = Vector2(joueur - case)
		p["case"] = [case.x, case.y]
		if not p.has("orientation"):
			p["orientation"] = int(roundf(rad_to_deg(vers.angle()) / 15.0)) * 15
		pnj.append(p)
	var n := {
		"version": 1,
		"titre": s["titre"],
		"intention": s["intention"],
		"boss": bool(s.get("boss", false)),
		"carte": {
			"version": 4,
			"name": "%s — %s" % [nom_carte, s["titre"]],
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
		n["plafonniers"] = s["lampes"]
	return n


## La salle imprimée, pour qu'on la relise avant d'ouvrir le jeu : plafonniers `*`, points de ronde `o`, et chaque zone nommée dessous.
static func apercu(numero: String, s: Dictionary) -> void:
	var g: Grille = s["g"]
	var lignes: Array = []
	for y in g.h:
		var ligne := ""
		for x in g.l:
			ligne += g.lire(x, y)
		lignes.append(ligne)
	var pose := func(c: Array, ch: String) -> void:
		var ligne: String = lignes[c[1]]
		lignes[c[1]] = ligne.substr(0, c[0]) + ch + ligne.substr(c[0] + 1)
	for p: Dictionary in s["pnj"]:
		for c in p.get("ronde", []):
			pose.call(c, "o")
	for lampe: Dictionary in s["lampes"]:
		pose.call(lampe["case"], "*")
	print("\n%s — %s (%d × %d)" % [numero, s["titre"], g.l, g.h])
	for ligne in lignes:
		print("  ", ligne)
	for i in (s["pnj"] as Array).size():
		var p: Dictionary = s["pnj"][i]
		if p.has("zone"):
			print("  PNJ %d : zone %s" % [i + 1, str(p["zone"])])


static func ecrire(dossier: String, nom: String, donnees: Dictionary) -> void:
	var f := FileAccess.open(dossier.path_join(nom), FileAccess.WRITE)
	f.store_string(JSON.stringify(donnees, "  ") + "\n")
	f.close()
