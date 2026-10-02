class_name NavigationBot
extends RefCounted

## Les chemins d'un bot sur la grille de cases d'une carte — chantier SOLO, étape S1.
##
## Des fonctions pures : une carte entre (le dictionnaire de `map_codec.gd`), des cases et des
## chemins sortent. Aucun nœud, aucun autoload, aucune physique : une suite en `--script` le
## construit sur chaque carte livrée sans monter le jeu. C'est `bot_input_provider.gd` qui
## transforme un chemin en commandes.
##
## ## Les MÊMES cases que la collision
##
## La grille de solidité est `MapGeometry.build_solid_grid()` — celle dont `build_collisions()`
## tire les rectangles de collision et d'occlusion. Le bot ne relit donc pas la carte à sa
## façon : le vide hors sol est solide, les murs pleins aussi, **les murs bas aussi** (en S1 le
## bot ne les enjambe pas : il les contourne), et la ceinture ajoutée autour de la grille
## ferme la carte. Une carte qui change de règle de solidité change ici sans qu'on y touche.
##
## ## Praticable n'est pas libre : le corps du joueur fait 36 px, la tuile 35
##
## Le polygone de collision d'un joueur (`player.tscn`) est un disque de 18 px de rayon : plus
## large qu'une tuile. **Une case libre coincée entre deux solides opposés — un couloir d'une
## tuile — est donc infranchissable pour un corps**, joueur comme bot, même si la grille la dit
## libre. Un chemin qui y passerait coincerait le bot contre ses deux murs pour toujours : on
## les distingue.
##   • `est_libre(case)`       — ni mur, ni mur bas, ni fosse : la grille de `map_geometry.gd`.
##   • `est_praticable(case)`  — libre ET non étranglée : la seule que `chemin()` traverse.
## Les murs sont des cases entières, donc deux solides en vis-à-vis sur un axe (gauche/droite
## ou haut/bas) laissent exactement 35 px < 36 : la règle est exacte, pas une marge de prudence.
##
## ## Pas de diagonale qui rase un coin
##
## `AStarGrid2D` en `DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES` n'autorise une diagonale que si les deux
## cases orthogonales qu'elle côtoie sont praticables aussi : le trait entre deux centres ne
## passe alors jamais à moins d'une demi-tuile d'un coin de mur, là où un disque de 18 px
## accrocherait. Les cases voisines d'un mur coûtent un peu plus cher : à chemin presque égal, le
## bot préfère le milieu d'une salle au pied d'un mur, où le nez du joueur (28 px devant lui) et
## les arrondis de la physique l'accrochent.

const Geometrie := preload("res://map_geometry.gd")
const Codec := preload("res://map_codec.gd")
const Tuiles := preload("res://candela_tileset.gd")

## Le poids d'une case voisine d'un mur : l'écart minimal qui fait préférer le milieu d'une
## salle sans jamais allonger un trajet de plus du tiers environ. Un chiffre de départ, pas une
## mesure — le garde « jamais bloqué » du banc d'entraînement est ce qui l'éprouve.
const POIDS_PRES_D_UN_MUR := 1.6

## La taille de la grille de la carte, en cases (sans la ceinture).
var taille := Vector2i.ZERO

## La carte d'où viennent ces chemins (le dictionnaire de `map_codec.gd`), gardée telle quelle : la PERCEPTION du bot (S2,
## `PerceptionBot.monde_de_la_carte`) regarde les mêmes murs que ses chemins contournent, sans que personne relise la carte
## une seconde fois à sa façon.
var carte: Dictionary = {}

## `[ix][iy]` de `MapGeometry.build_solid_grid()` : décalé de `Geometrie.BORDER` sur chaque axe.
var _solide: Array = []
## Les cases praticables, mémorisées : `est_praticable` est appelée à chaque voisin de chaque
## nœud d'une recherche.
var _praticable := {}
## Les cases praticables, dans l'ordre des lignes puis des colonnes — l'ordre est ce qui rend un
## tirage à graine reproductible, un `Dictionary` n'ayant pas à garantir le sien.
var _cases: Array[Vector2i] = []
var _astar: AStarGrid2D = null
## Une grille par rectangle de zone déjà demandé : en construire une coûte une passe sur la carte.
var _astar_par_zone := {}
## Composantes connexes, calculées à la demande : case → numéro, et numéro → ses cases.
var _composante_de := {}
var _composantes: Array = []


## Construit les chemins d'une carte. `data` est un dictionnaire de `map_codec.gd`.
static func depuis_carte(data: Dictionary) -> NavigationBot:
	var nav := NavigationBot.new()
	nav._construire(data)
	return nav


func _construire(data: Dictionary) -> void:
	carte = data
	var grille := Codec.get_grid_size(data)
	taille = Vector2i(clampi(grille.x, 1, Codec.MAX_GRID), clampi(grille.y, 1, Codec.MAX_GRID))
	_solide = Geometrie.build_solid_grid(data)
	for cy in taille.y:
		for cx in taille.x:
			var c := Vector2i(cx, cy)
			if est_libre(c) and not _etranglee(c):
				_praticable[c] = true
				_cases.append(c)
	_astar = _fabriquer_astar(Rect2i())


## Vrai pour une case que ni un mur, ni un mur bas, ni le vide n'occupent — la grille de collision.
func est_libre(case: Vector2i) -> bool:
	if case.x < 0 or case.y < 0 or case.x >= taille.x or case.y >= taille.y:
		return false
	var b: int = Geometrie.BORDER
	return not _solide[case.x + b][case.y + b]


## Vrai pour une case où un corps de joueur passe : libre, et pas prise en étau entre deux
## solides opposés. Voir l'en-tête.
func est_praticable(case: Vector2i) -> bool:
	return _praticable.has(case)


func _etranglee(c: Vector2i) -> bool:
	return (not est_libre(c + Vector2i.LEFT) and not est_libre(c + Vector2i.RIGHT)) \
		or (not est_libre(c + Vector2i.UP) and not est_libre(c + Vector2i.DOWN))


## Toutes les cases praticables de la carte, en ordre de lecture (lignes, puis colonnes).
func cases_praticables() -> Array[Vector2i]:
	return _cases


## Les cases praticables d'un rectangle de cases, en ordre de lecture.
func cases_dans(rect: Rect2i) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	for c in _cases:
		if rect.has_point(c):
			sortie.append(c)
	return sortie


func _fabriquer_astar(limite: Rect2i) -> AStarGrid2D:
	var a := AStarGrid2D.new()
	a.region = Rect2i(Vector2i.ZERO, taille)
	a.cell_size = Vector2.ONE
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	a.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	a.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	a.update()
	var borne := limite.size != Vector2i.ZERO
	for cy in taille.y:
		for cx in taille.x:
			var c := Vector2i(cx, cy)
			if not est_praticable(c) or (borne and not limite.has_point(c)):
				a.set_point_solid(c, true)
			elif _pres_d_un_mur(c):
				a.set_point_weight_scale(c, POIDS_PRES_D_UN_MUR)
	return a


func _pres_d_un_mur(c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and not est_libre(c + Vector2i(dx, dy)):
				return true
	return false


## Le chemin le plus court de `depart` à `arrivee`, en cases, extrémités comprises ; vide si l'une
## n'est pas praticable ou si aucun chemin ne les relie.
##
## `limite` (cases) enferme le chemin dans un rectangle : aucune case hors de lui n'est traversée.
## Une taille nulle ne limite rien. C'est ce qui fait qu'un bot en `ZONE` ne sort pas de sa zone
## en contournant un mur par l'extérieur.
func chemin(depart: Vector2i, arrivee: Vector2i, limite: Rect2i = Rect2i()) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	if not est_praticable(depart) or not est_praticable(arrivee):
		return sortie
	var borne := limite.size != Vector2i.ZERO
	if borne and not (limite.has_point(depart) and limite.has_point(arrivee)):
		return sortie
	var a: AStarGrid2D = _astar
	if borne:
		if not _astar_par_zone.has(limite):
			_astar_par_zone[limite] = _fabriquer_astar(limite)
		a = _astar_par_zone[limite]
	for id in a.get_id_path(depart, arrivee):
		sortie.append(id)
	return sortie


## Les cases qu'on peut rejoindre depuis `case` en marchant — elle-même comprise. Vide si `case`
## n'est pas praticable. Les diagonales n'ajoutent aucune connexité (elles exigent deux cases
## orthogonales libres) : un remplissage en quatre voisins suffit, et il équivaut à `chemin()`.
func cases_atteignables(case: Vector2i) -> Array[Vector2i]:
	if not est_praticable(case):
		return []
	if _composantes.is_empty():
		_numeroter_les_composantes()
	return _composantes[_composante_de[case]]


func _numeroter_les_composantes() -> void:
	const VOISINS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	for depart in _cases:
		if _composante_de.has(depart):
			continue
		var numero := _composantes.size()
		var membres: Array[Vector2i] = []
		var pile: Array[Vector2i] = [depart]
		_composante_de[depart] = numero
		while not pile.is_empty():
			var c: Vector2i = pile.pop_back()
			membres.append(c)
			for d in VOISINS:
				var n := c + d
				if _praticable.has(n) and not _composante_de.has(n):
					_composante_de[n] = numero
					pile.append(n)
		# Ordre de lecture : un tirage à graine ne doit pas dépendre de l'ordre du remplissage.
		membres.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x))
		_composantes.append(membres)


## La case qui contient un point du monde, en pixels. La grille de la carte a son origine à (0, 0)
## et des tuiles de `CandelaTileSet.TILE_SIZE` : c'est le repère de `rects_monde` et des points
## d'apparition (`map_to_local`).
static func case_du_monde(position: Vector2) -> Vector2i:
	var t := Vector2(Tuiles.TILE_SIZE)
	return Vector2i(floori(position.x / t.x), floori(position.y / t.y))


## Le centre d'une case, en pixels du monde — là où le bot vise.
static func centre_de_la_case(case: Vector2i) -> Vector2:
	var t := Vector2(Tuiles.TILE_SIZE)
	return (Vector2(case) + Vector2(0.5, 0.5)) * t


## La case praticable la plus proche de `case` (au sens des anneaux de cases), ou `(-1, -1)` si la
## carte n'en a aucune. Sert à poser un bot sur du sol quand le point voulu n'en est pas.
func case_praticable_proche(case: Vector2i) -> Vector2i:
	if est_praticable(case):
		return case
	var rayon_max := maxi(taille.x, taille.y)
	for r in range(1, rayon_max + 1):
		var meilleure := Vector2i(-1, -1)
		var meilleure_d := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := case + Vector2i(dx, dy)
				if est_praticable(c) and Vector2(dx, dy).length() < meilleure_d:
					meilleure = c
					meilleure_d = Vector2(dx, dy).length()
		if meilleure.x >= 0:
			return meilleure
	return Vector2i(-1, -1)


## Une case de la composante de `ancre`, tirée parmi les plus éloignées de `position` (pixels) : les
## `fraction` les plus lointaines. C'est où l'on pose un bot « loin du joueur » — pas toujours au
## même endroit, pas jamais à côté, et toujours là où il peut ensuite marcher (une carte coupée par
## un gouffre ne le fait pas naître dans une poche d'où il ne sortirait pas). `(-1, -1)` sans case.
func case_loin_de(position: Vector2, ancre: Vector2i, rng: RandomNumberGenerator,
		fraction: float = 0.15) -> Vector2i:
	var candidates := cases_atteignables(ancre)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	var classees: Array = []
	for c in candidates:
		classees.append([centre_de_la_case(c).distance_squared_to(position), c])
	# Plus loin d'abord ; à égalité, l'ordre de lecture, déjà celui de `candidates` (le tri n'est pas
	# stable, d'où la clé de départage explicite).
	classees.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] > b[0]
		var ca: Vector2i = a[1]
		var cb: Vector2i = b[1]
		return ca.y < cb.y or (ca.y == cb.y and ca.x < cb.x))
	var n := maxi(1, int(ceil(classees.size() * clampf(fraction, 0.0, 1.0))))
	return classees[rng.randi_range(0, n - 1)][1]
