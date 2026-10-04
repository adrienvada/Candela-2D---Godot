## Un labyrinthe pour les fabriques de chapitres — chantier SOLO, étape S8 (chapitres 7 et 9).
##
## Une grille de PAS 3 : la cellule `(i, j)` est le carré de 2 × 2 cases `(3i+1 … 3i+2, 3j+1 … 3j+2)`, et une ligne de 1 case de mur sépare deux cellules voisines. Un
## passage fait donc DEUX cases de large (70 px pour un corps de 36 : jamais un couloir d'une tuile). La grille d'une salle doit mesurer `3 × cols + 1` sur `3 × rows + 1`.
##
## Les poteaux (les carrefours de lignes de mur) sont des murs pleins, les segments entre eux ce qu'on demande : `#` pour un labyrinthe qui coupe la vue, `~` pour des murets
## qu'on voit par-dessus et qu'on ne traverse pas. L'arbre couvrant est tiré d'un DFS à graine fixe — le même dessin à chaque lancement — puis on rouvre `boucles` murs pour que
## le labyrinthe ait des CHOIX (un arbre pur n'a qu'un chemin d'un point à un autre : une chasse sans détour).
##
## Les JSON restent la vérité du jeu : ce fichier n'est que la façon dont on a dessiné le labyrinthe.

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## Dessine le labyrinthe dans `g` (la ceinture de murs est déjà posée par `Grille.new`). `segment` : le caractère des murs entre les poteaux ; `poteau` : celui des
## carrefours ; `bas_aussi` : une part (0 à 1) des segments restants passe en `~` quand `segment` est `#` — des cloisons percées de fenêtres basses.
static func dessiner(g, cols: int, rows: int, graine: int, boucles: int, segment: String, poteau: String = "#", bas_aussi: float = 0.0) -> void:
	assert(g.l == 3 * cols + 1 and g.h == 3 * rows + 1)
	# Tous les murs en place : poteaux et segments.
	for j in rows + 1:
		for i in cols + 1:
			g.poser(3 * i, 3 * j, poteau if (i > 0 and j > 0 and i < cols and j < rows) else "#")
	for j in rows:
		for i in range(1, cols):
			g.rect(3 * i, 3 * j + 1, 1, 2, segment)
	for j in range(1, rows):
		for i in cols:
			g.rect(3 * i + 1, 3 * j, 2, 1, segment)
	# L'arbre couvrant : DFS depuis la cellule (0, 0), un tirage par pas.
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var vu := {Vector2i(0, 0): true}
	var pile: Array[Vector2i] = [Vector2i(0, 0)]
	while not pile.is_empty():
		var c: Vector2i = pile.back()
		var voisins: Array[Vector2i] = []
		for d in DIRS:
			var n := c + d
			if n.x >= 0 and n.y >= 0 and n.x < cols and n.y < rows and not vu.has(n):
				voisins.append(n)
		if voisins.is_empty():
			pile.pop_back()
			continue
		var n: Vector2i = voisins[rng.randi_range(0, voisins.size() - 1)]
		_ouvrir(g, c, n)
		vu[n] = true
		pile.append(n)
	# Les boucles : des murs de plus qu'on ouvre, entre deux cellules qui ne communiquent pas encore directement.
	var essais := 0
	var faites := 0
	while faites < boucles and essais < 2000:
		essais += 1
		var c := Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
		var d: Vector2i = DIRS[rng.randi_range(0, 3)]
		var n := c + d
		if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows or _est_ouvert(g, c, n):
			continue
		_ouvrir(g, c, n)
		faites += 1
	# Des fenêtres basses dans les cloisons pleines.
	if bas_aussi > 0.0 and segment == "#":
		for j in rows:
			for i in range(1, cols):
				if g.lire(3 * i, 3 * j + 1) == "#" and rng.randf() < bas_aussi:
					g.rect(3 * i, 3 * j + 1, 1, 2, "~")
		for j in range(1, rows):
			for i in cols:
				if g.lire(3 * i + 1, 3 * j) == "#" and rng.randf() < bas_aussi:
					g.rect(3 * i + 1, 3 * j, 2, 1, "~")


## Le centre (case du coin haut-gauche) de la cellule `(i, j)`.
static func cellule(i: int, j: int) -> Vector2i:
	return Vector2i(3 * i + 1, 3 * j + 1)


static func _ouvrir(g, a: Vector2i, b: Vector2i) -> void:
	var d := b - a
	if d.x != 0:
		var x := 3 * maxi(a.x, b.x)
		g.rect(x, 3 * a.y + 1, 1, 2, ".")
	else:
		var y := 3 * maxi(a.y, b.y)
		g.rect(3 * a.x + 1, y, 2, 1, ".")


static func _est_ouvert(g, a: Vector2i, b: Vector2i) -> bool:
	var d := b - a
	if d.x != 0:
		return g.lire(3 * maxi(a.x, b.x), 3 * a.y + 1) == "."
	return g.lire(3 * a.x + 1, 3 * maxi(a.y, b.y)) == "."
