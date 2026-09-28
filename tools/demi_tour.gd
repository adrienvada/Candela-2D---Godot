## Le JUMEAU PAR LE DEMI-TOUR — la règle d'équité des décors à 45° B, commune à tous les essais (session cloud
## « décor demi-tour », 2026-09-28).
##
## À l'option B (le défaut depuis Q28), J2 regarde depuis le côté opposé : son lacet est celui de J1 plus 180°. Ce que J1
## voit au point p, J2 le voit donc au DEMI-TOUR de p — (x, y) → (L − x, H − y) —, pas à son miroir. Et une face de mur de
## normale n que voit J1 a pour jumelle la face de normale −n que voit J2. Un décor fermé par le seul miroir de la carte
## peut être visible pour J1 et caché pour J2 (mesuré par la session « sol marqué » : 713 pixels contre 27).
##
## Ce fichier ne dessine rien : il dit, pour chaque décor à l'essai, quels objets n'ont PAS leur jumeau par le demi-tour —
## les « orphelins ». Les gardes (`test_pochoirs`, `test_sol_marque`, `test_iso_tuyaux`, `test_iso_enseignes`,
## `test_iso_murs_meubles`) exigent zéro orphelin ; `tools/audit_demi_tour.gd` imprime le tableau décor × carte.
extends RefCounted

const TuyauxIsoT := preload("res://tuyaux_iso.gd")
const EnseignesIsoT := preload("res://enseignes_iso.gd")
const MursMeublesIsoT := preload("res://murs_meubles_iso.gd")
const ArenaDecorT := preload("res://arena_decor.gd")


## Les cartes livrées, par `id`.
static func cartes() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at("res://assets/maps"):
		if f.ends_with(".json"):
			var d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/" + f))
			if d is Dictionary:
				out[String(d.get("id", f))] = d
	return out


static func _angle_egal(a: float, b: float, periode: float) -> bool:
	var d := fposmod(a - b, periode)
	return d < 0.001 or d > periode - 0.001


## Le mot jumeau d'un pochoir : « ZONE 1 » près de J1 a pour jumeau « ZONE 2 » près de J2.
static func mot_jumeau(texte: String) -> String:
	return "ZONE 2" if texte == "ZONE 1" else ("ZONE 1" if texte == "ZONE 2" else texte)


## LES POCHOIRS — [texte, centre (cases), angle]. Le jumeau : le mot jumeau, au demi-tour du centre (en cases : W−1−x,
## H−1−y), tourné de 180° EXACTEMENT : J2 le lit dans le même sens que J1 lit l'original (des lettres à l'envers pour
## l'un et à l'endroit pour l'autre ne sont pas équitables).
static func orphelins_pochoirs(table: Array, g: Vector2i) -> Array:
	var sortie := []
	for p in table:
		var c: Vector2 = p[1]
		var image := Vector2(g.x - 1 - c.x, g.y - 1 - c.y)
		var trouve := false
		for q in table:
			if String(q[0]) == mot_jumeau(String(p[0])) and Vector2(q[1]).is_equal_approx(image) \
					and _angle_egal(float(q[2]), float(p[2]) + 180.0, 360.0):
				trouve = true
		if not trouve:
			sortie.append("%s %s %d°" % [p[0], p[1], int(p[2])])
	return sortie


## LE SOL MARQUÉ — [famille, centre, angle, paramètre, graine, miroir]. La règle de `test_sol_marque.gd`, CADRES COMPRIS
## (la garde de la session « sol marqué » les exemptait : ils suivaient les pochoirs, qui n'étaient pas fermés).
static func orphelins_sol_marque(table: Array, g: Vector2i) -> Array:
	var sortie := []
	for p in table:
		var c: Vector2 = p[1]
		var image := Vector2(g.x - 1 - c.x, g.y - 1 - c.y)
		var angle := float(p[2]) + 180.0
		var symetrique := ArenaDecorT.SOL_MARQUE_SYMETRIQUES.has(String(p[0]))
		var trouve := false
		for q in table:
			if String(q[0]) != String(p[0]) or q[3] != p[3] or int(q[4]) != int(p[4]):
				continue
			if not Vector2(q[1]).is_equal_approx(image):
				continue
			if symetrique:
				trouve = trouve or (_angle_egal(float(q[2]), angle, 180.0) and not bool(q[5]))
			else:
				trouve = trouve or (_angle_egal(float(q[2]), angle, 360.0) and bool(q[5]) == bool(p[5]))
		if not trouve:
			sortie.append("%s %s" % [p[0], p[1]])
	return sortie


## Le demi-tour d'un point du monde (px, sans ceinture) : `dim` la taille de la carte en pixels.
static func point_demi_tour(p: Vector2, dim: Vector2) -> Vector2:
	return dim - p


static func dim_px(data: Dictionary) -> Vector2:
	return Vector2(EnseignesIsoT.cases_carte(data)) * float(CandelaTileSet.TILE_SIZE.x)


## Une face des murs (celles de `TuyauxIso.faces`) nommée pour un rapport : sa normale et sa première case.
static func nom_face(f: Dictionary) -> String:
	var n: Vector2 = f["n"]
	var sens := "S" if n == Vector2(0, 1) else ("N" if n == Vector2(0, -1) else ("E" if n == Vector2(1, 0) else "O"))
	var t := Vector2(-n.y, n.x)
	var tuile := float(CandelaTileSet.TILE_SIZE.x)
	var a := n * float(f["d"]) + t * float(f["s0"])
	var b := n * float(f["d"]) + t * float(f["s1"])
	var m := (a + b) * 0.5 - n * tuile * 0.5
	return "%s(%d,%d)×%d" % [sens, floori(m.x / tuile), floori(m.y / tuile), int(f["cases"])]


## Les sommets d'une construction arrondis au dixième de pixel, en clés.
static func _cle_sommet(v: Vector3) -> Vector3i:
	return Vector3i(roundi(v.x * 10.0), roundi(v.y * 10.0), roundi(v.z * 10.0))


## LES TUYAUX — la construction entière, sommet par sommet : l'image par le demi-tour de chaque sommet (x → L − x,
## z → H − z, la hauteur gardée) doit être un sommet. Les orphelins : les faces qui portent un sommet sans image.
static func orphelins_tuyaux(data: Dictionary, c: Dictionary = {}) -> Array:
	if c.is_empty():
		c = TuyauxIsoT.construire(data)
	var dim := dim_px(data)
	var sommets: PackedVector3Array = c["sommets"]
	var ensemble := {}
	for v in sommets:
		ensemble[_cle_sommet(v)] = true
	var faces_orphelines := {}
	var face_de: PackedInt32Array = c["face_de_sommet"]
	for k in sommets.size():
		var v := sommets[k]
		if not ensemble.has(_cle_sommet(Vector3(dim.x - v.x, v.y, dim.y - v.z))):
			faces_orphelines[face_de[k]] = true
	var sortie := []
	for i in faces_orphelines:
		sortie.append(nom_face(c["faces"][i]))
	sortie.sort()
	return sortie


## LES ENSEIGNES — {sorte, face, s, y} : l'image par le demi-tour (face de normale −n, même hauteur, centre au demi-tour),
## « ZONE 1 » et « ZONE 2 » échangés.
static func orphelins_enseignes(data: Dictionary, c: Dictionary = {}) -> Array:
	if c.is_empty():
		c = EnseignesIsoT.construire(data)
	var dim := dim_px(data)
	var faces: Array = c["faces"]
	var sortie := []
	for e in c["enseignes"]:
		var f: Dictionary = faces[int(e["face"])]
		var n: Vector2 = f["n"]
		var p := n * float(f["d"]) + Vector2(-n.y, n.x) * float(e["s"])
		var pi := dim - p
		var trouve := false
		for q in c["enseignes"]:
			var g: Dictionary = faces[int(q["face"])]
			var m: Vector2 = g["n"]
			var pq := m * float(g["d"]) + Vector2(-m.y, m.x) * float(q["s"])
			if m == -n and pq.is_equal_approx(pi) and is_equal_approx(float(q["y"]), float(e["y"])) \
					and String(q["sorte"]) == mot_jumeau(String(e["sorte"])):
				trouve = true
		if not trouve:
			sortie.append("%s sur %s" % [e["sorte"], nom_face(f)])
	return sortie


## LES MURS MEUBLÉS — {famille, variante, face, s, n, d} : l'image par le demi-tour, même famille, même variante.
static func orphelins_murs_meubles(data: Dictionary, c: Dictionary = {}) -> Array:
	if c.is_empty():
		c = MursMeublesIsoT.construire(data)
	var dim := dim_px(data)
	var sortie := []
	for o in c["objets"]:
		var n: Vector2 = o["n"]
		var p := n * float(o["d"]) + Vector2(-n.y, n.x) * float(o["s"])
		var pi := dim - p
		var trouve := false
		for q in c["objets"]:
			var m: Vector2 = q["n"]
			var pq := m * float(q["d"]) + Vector2(-m.y, m.x) * float(q["s"])
			if m == -n and pq.is_equal_approx(pi) and String(q["famille"]) == String(o["famille"]) \
					and int(q["variante"]) == int(o["variante"]):
				trouve = true
		if not trouve:
			sortie.append("%s %d sur %s" % [o["famille"], int(o["variante"]), nom_face(c["faces"][int(o["face"])])])
	return sortie
