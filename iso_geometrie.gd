## IsoGeometrie — les murs d'une carte en boîtes, pour la vue isométrique (ISO1).
##
## **La troisième vue des mêmes rectangles.** `merge_rects(build_grid(data, Kind.WALLS))`
## produit déjà la collision ET l'occlusion 2D (`map_geometry.gd`) ; ce fichier en
## tire une boîte par rectangle, rien de plus. Une vue qui recalculerait ses propres
## murs finirait par dessiner un mur là où la balle passe.
##
## Et le calcul d'équité que la hauteur de ces boîtes impose : à 52° de tangage, un
## mur cache derrière lui une bande de sol de `h / tan θ` — voir `analyser_equite()`
## et le tableau de `tools/test_iso_geometrie.gd`.
##
## Repère : le monde 3D est en pixels du monde 2D, `x` → `x`, `y` → `z`, le sol à
## `y = 0` (patron du banc ISO0.b).
class_name IsoGeometrie
extends RefCounted

## ⚠️ **À DÉPLACER DANS `map_geometry.gd`** — la hauteur d'un mur haut, en tuiles.
##
## Contrat avec le chantier des murs bas : c'est lui qui posera `HAUTEUR_MUR_HAUT` et
## `HAUTEUR_MUR_BAS` (en tuiles) dans `map_geometry.gd`, et `Kind.LOW_WALLS`. Dès
## qu'elles existent, `hauteur_mur_haut()` les lit et cette constante ne sert plus ;
## ce fichier ne les pose pas lui-même, `map_geometry.gd` n'est pas à ISO1.
##
## **1,25 tuile — décision d'Adrien, 2026-09-14 au soir** (jalon H-ISO1), sur le tableau
## d'équité : « des murs hauts très lisibles, qui ne laissent rien passer ». C'est aussi la
## valeur que le chantier des murs bas pose dans `map_geometry.gd`.
##
## ⚠️ **Elle dépasse, en connaissance de cause, le critère de l'étude** : 34,2 px de sol
## cachés derrière un mur à 52°, un corps collé caché à 98 %, et La Croisée qui cache 4,6
## points de sol de plus dans la moitié de J2. Ce qui tient encore : **aucune case de sol
## n'est entièrement invisible** tant que le mur reste sous 1,28 tuile —
## `tools/test_iso_geometrie.gd` le vérifie sur les six cartes. C'est le SEUL endroit du
## dépôt où cette hauteur est écrite côté iso.
const H_HAUT := 1.25

## Le critère de l'étude (§ 5.2) : la bande de sol cachée derrière un mur reste sous
## le rayon d'un corps, pour qu'un joueur collé derrière montre encore son torse. **Dépassé
## par décision d'Adrien pour les murs hauts** (voir `H_HAUT`) ; il reste la référence du
## tableau d'équité, et celle des murs bas (0,4 tuile : 10,9 px).
const BANDE_MAX_PX := 18.0
const RAYON_CORPS_PX := 18.0

const _CHEMIN_MAP_GEOMETRY := "res://map_geometry.gd"


# ---------------------------------------------------------------------------
# LES HAUTEURS — le contrat avec le chantier des murs bas
# ---------------------------------------------------------------------------

## Lu dans le SCRIPT et non par `MapGeometry.HAUTEUR_MUR_HAUT` : nommer une constante
## qui n'existe pas encore est une erreur de compilation, et ce fichier doit compiler
## avant ET après la fusion des murs bas.
static func _constantes_map_geometry() -> Dictionary:
	var script := load(_CHEMIN_MAP_GEOMETRY) as Script
	return script.get_script_constant_map() if script != null else {}


static func hauteur_mur_haut() -> float:
	var c := _constantes_map_geometry()
	return float(c["HAUTEUR_MUR_HAUT"]) if c.has("HAUTEUR_MUR_HAUT") else H_HAUT


## Négatif tant que le chantier des murs bas n'a pas posé sa constante.
static func hauteur_mur_bas() -> float:
	var c := _constantes_map_geometry()
	return float(c["HAUTEUR_MUR_BAS"]) if c.has("HAUTEUR_MUR_BAS") else -1.0


## D'où vient la hauteur utilisée — imprimé par F3 et par la suite, pour qu'une
## fusion qui aurait perdu la constante se VOIE au lieu de retomber en silence sur
## la valeur locale (la leçon du garde `has_method()`, CLAUDE.md).
static func source_des_hauteurs() -> String:
	if _constantes_map_geometry().has("HAUTEUR_MUR_HAUT"):
		return "map_geometry.gd"
	return "H_HAUT locale, en attente de map_geometry.gd"


## Les sortes de murs à extruder : `[Kind, hauteur en tuiles, préfixe de nom]`.
##
## `Kind.LOW_WALLS` se lit dans l'énumération comme dans un dictionnaire, pour la même
## raison de compilation. S'il existe sans sa hauteur, ce n'est pas un repli : c'est
## une fusion à moitié faite, et elle crie.
static func sortes_de_murs() -> Array:
	var sortes: Array = [[MapGeometry.Kind.WALLS, hauteur_mur_haut(), "MurHaut"]]
	# Par un dictionnaire : `Kind["LOW_WALLS"]` écrit en dur est vérifié à la compilation.
	var kinds: Dictionary = MapGeometry.Kind
	if kinds.has("LOW_WALLS"):
		var bas := hauteur_mur_bas()
		if bas <= 0.0:
			push_error("IsoGeometrie : Kind.LOW_WALLS existe mais pas HAUTEUR_MUR_BAS — murs bas non extrudés")
		else:
			sortes.append([kinds["LOW_WALLS"], bas, "MurBas"])
	return sortes


# ---------------------------------------------------------------------------
# LES BOÎTES
# ---------------------------------------------------------------------------

## Les rectangles d'une sorte de murs, en pixels du monde 2D — exactement le repère
## de `MapGeometry._fill_body()`, bordure retirée.
static func rects_px(data: Dictionary, kind: int,
		tuile: Vector2 = Vector2(CandelaTileSet.TILE_SIZE)) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var bord := Vector2i(MapGeometry.BORDER, MapGeometry.BORDER)
	for r in MapGeometry.merge_rects(MapGeometry.build_grid(data, kind as MapGeometry.Kind)):
		out.append(Rect2(Vector2(r.position - bord) * tuile, Vector2(r.size) * tuile))
	return out


## Une boîte par rectangle de mur, un cube unitaire partagé mis à l'échelle, posé de
## `y = 0` à sa hauteur. Le sommet noir strict est l'affaire du matériau
## (`mur_iso.gdshader`), pas de la géométrie.
##
## Déterministe : mêmes données, mêmes noms, mêmes transformations, dans le même
## ordre — `merge_rects` balaie la grille dans un ordre fixe.
static func build_meshes(data: Dictionary, materiau: Material,
		tuile: Vector2 = Vector2(CandelaTileSet.TILE_SIZE)) -> Node3D:
	var murs := Node3D.new()
	murs.name = "Murs"
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	for sorte in sortes_de_murs():
		var hauteur_tuiles := float(sorte[1])
		var hauteur_px := hauteur_tuiles * tuile.y
		var rects := rects_px(data, int(sorte[0]), tuile)
		for i in rects.size():
			var r := rects[i]
			var boite := MeshInstance3D.new()
			boite.name = "%s%d" % [sorte[2], i]
			boite.mesh = cube
			boite.material_override = materiau
			boite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			boite.scale = Vector3(r.size.x, hauteur_px, r.size.y)
			boite.position = Vector3(r.get_center().x, hauteur_px * 0.5, r.get_center().y)
			boite.set_meta("hauteur_tuiles", hauteur_tuiles)
			murs.add_child(boite)
	return murs


# ---------------------------------------------------------------------------
# L'ÉQUITÉ GÉOMÉTRIQUE — calcul analytique
# ---------------------------------------------------------------------------

## La bande de sol cachée derrière un mur de `hauteur_px`, caméra orthographique
## inclinée de `tangage_deg` : le rayon qui rase le sommet du mur retombe au sol
## `h / tan θ` plus loin.
static func bande_masquee_px(hauteur_px: float, tangage_deg: float) -> float:
	return hauteur_px / tan(deg_to_rad(tangage_deg))


## La part du disque au sol d'un corps collé à la face cachée d'un mur (centre à un
## rayon de la face) qui tombe dans la bande : l'aire d'un segment de disque.
static func part_de_corps_colle_cachee(bande_px: float, rayon_px: float = RAYON_CORPS_PX) -> float:
	var h := clampf(bande_px, 0.0, 2.0 * rayon_px)
	var r := rayon_px
	var segment := r * r * acos((r - h) / r) - (r - h) * sqrt(maxf(0.0, 2.0 * r * h - h * h))
	return segment / (PI * r * r)


## Longueur (px) cachée d'une case de sol, colonne par colonne.
##
## **Lacet nul** (`CameraIso.LACET_DEG`) : la caméra est au sud et regarde le nord,
## ses rayons restent dans le plan de la colonne. Un point de sol est caché si un mur
## de la même colonne commence, au sud, à moins d'une bande de lui. Tous les murs ayant
## la même hauteur ici, seul le plus proche compte : la partie cachée d'une case est
## `bande − (k − 1) × tuile`, bornée à la case, pour un mur à `k` cases au sud.
static func longueur_cachee(case_sol: Vector2i, murs: Dictionary, bande_px: float,
		tuile_px: float) -> float:
	var portee := int(ceil(bande_px / tuile_px)) + 1
	for k in range(1, portee + 1):
		if murs.has(case_sol + Vector2i(0, k)):
			return clampf(bande_px - float(k - 1) * tuile_px, 0.0, tuile_px)
	return 0.0


## Le relevé d'équité d'une carte pour une hauteur de mur et un tangage.
##
## - `cases_touchees` : cases de sol dont une partie est cachée ;
## - `cases_invisibles` : cases de sol entièrement cachées depuis la caméra ;
## - `part_sol` : aire cachée / aire du sol ;
## - `part_j1`, `part_j2` : la même chose dans la moitié de chaque joueur — les cases
##   plus proches de son apparition ; une case à égale distance compte pour moitié
##   des deux côtés. **La caméra est la même pour les deux**, mais les murs ne sont
##   pas orientés pareil dans les deux moitiés d'une carte à symétrie centrale : c'est
##   là que l'équité se joue.
static func analyser_equite(data: Dictionary, hauteur_tuiles: float, tangage_deg: float) -> Dictionary:
	var tuile := float(CandelaTileSet.TILE_SIZE.y)
	var bande := bande_masquee_px(hauteur_tuiles * tuile, tangage_deg)
	var grille := MapCodec.get_grid_size(data)
	var murs := {}
	for c in MapCodec.get_wall_cells(data):
		murs[c] = true
	var s1 := Vector2(MapCodec.get_spawn(data, 0))
	var s2 := Vector2(MapCodec.get_spawn(data, 1))

	var cases_sol := 0
	var touchees := 0
	var invisibles := 0
	var cache_total := 0.0
	var sol_moitie := [0.0, 0.0]
	var cache_moitie := [0.0, 0.0]
	for cell in MapCodec.get_floor_cells(data):
		if murs.has(cell) or cell.x < 0 or cell.y < 0 or cell.x >= grille.x or cell.y >= grille.y:
			continue
		cases_sol += 1
		var cache := longueur_cachee(cell, murs, bande, tuile)
		if cache > 0.0:
			touchees += 1
		if cache >= tuile - 1e-6:
			invisibles += 1
		cache_total += cache
		var d1 := Vector2(cell).distance_squared_to(s1)
		var d2 := Vector2(cell).distance_squared_to(s2)
		var poids := [1.0, 0.0] if d1 < d2 else ([0.0, 1.0] if d2 < d1 else [0.5, 0.5])
		for j in 2:
			sol_moitie[j] += poids[j]
			cache_moitie[j] += poids[j] * cache
	var part := func(cache_px: float, cases: float) -> float:
		return cache_px / (cases * tuile) if cases > 0.0 else 0.0
	return {
		"bande_px": bande,
		"cases_sol": cases_sol,
		"cases_touchees": touchees,
		"cases_invisibles": invisibles,
		"part_sol": part.call(cache_total, float(cases_sol)),
		"part_j1": part.call(cache_moitie[0], sol_moitie[0]),
		"part_j2": part.call(cache_moitie[1], sol_moitie[1]),
	}
