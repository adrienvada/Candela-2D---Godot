## EnseignesIso — les enseignes et les panneaux muraux de la vue isométrique, EN ESSAI (`--enseignes-essai`, éteint par
## défaut).
##
## ## Pourquoi
##
## Les illustrations des menus portent au mur des mots : « ARENA » sur une plaque de tôle rouillée (`ill_accueil`,
## `ill_intro_seuil`), « ZONE 4 » peint au pochoir sur un pilier, le mot sur une ligne et le chiffre dessous (`ill_amical`).
## Le relevé complet est dans `docs/iso/cloud/enseignes/RAPPORT.md`. C'était le dernier manque de la famille « Murs ». Il
## s'ajoute EN ESSAI, derrière un drapeau, comme les tuyaux (`tuyaux_iso.gd`, dont il reprend les faces, le hachage et la
## lecture de la lumière) : rien ne s'allume en jeu avant l'avis d'Adrien.
##
## ## Deux sortes d'enseignes
##
## - **La plaque** « ARENA » : un rectangle de tôle SOMBRE, bord et rivets plus sombres, rouille aux bords, lettres pochoir
##   plus sombres encore. L'illustration la peint en tôle claire : la règle des pochoirs l'emporte (jamais plus clair que la
##   surface qui porte), le contraste lettre/plaque reste.
## - **La peinture** « ZONE n » : le mot sur une ligne, le chiffre dessous, peints sombre sur le béton, usés par endroits ;
##   hors des lettres, le mur. `n` est le côté du joueur : « ZONE 1 » du côté du départ de J1, « ZONE 2 » de celui de J2.
##
## ## Les garde-fous, qui priment sur l'image (prouvés par `tools/test_iso_enseignes.gd`)
##
## - **Le noir absolu.** Une enseigne n'a aucune lumière à elle : son shader relit la lumière du pixel de FACE qu'elle
##   recouvre, par les fonctions de `mur_iso.gdshader` (celles des tuyaux), et la multiplie par un facteur ≤ la matière la plus
##   sombre d'une face (`TuyauxIso.matiere_max`). Face noire : enseigne noire. Jamais plus claire que la face.
## - **Rien qui cache un joueur.** Aucune collision, aucun `LightOccluder2D`, aucune ombre. Un quadrilatère plat collé à sa
##   face (`SAILLIE_MAX` = 0,3 px devant elle), qui ne se dessine que pour une caméra qui voit la face de face (le seuil des
##   tuyaux). Rien au-dessus de l'arête, rien à moins de `MARGE_BOUT` des bouts de la face.
## - **Jamais lu à l'envers.** L'axe du texte suit la normale de la face : vers la droite de quiconque la regarde de face,
##   quel que soit le lacet — un quadrilatère vu de face n'est jamais en miroir, et les faces vues de dos ne dessinent rien.
## - **L'équité.** Placement tiré des seules cases de la carte, sans tirage ni graine. Chaque enseigne a ses jumelles par le
##   groupe de la carte (`groupe`) : la symétrie qui échange les deux départs (`sigma`) et le demi-tour (celui de l'option B,
##   le défaut en ligne : J2 regarde de l'autre côté) ; une face n'est retenue que si TOUTES ses images sont des faces
##   exposées de la carte. « ZONE 1 » et « ZONE 2 » s'échangent par `sigma`. Là où les murs sont équitables pour une paire de
##   caméras, les enseignes le sont aussi.
## - **Le coût.** Un maillage fusionné par carte (quatre sommets par enseigne, huit enseignes au plus), un matériau, un atlas
##   de 256 × 128 : un appel de dessin de plus par vue 3D.
##
## Repère : celui d'`IsoGeometrie` (et des tuyaux) — le monde 3D en pixels du monde 2D, `x` → `x`, `y` → `z`, sol à `y = 0`.
class_name EnseignesIso
extends RefCounted

const DRAPEAU_ENSEIGNES_ESSAI := "--enseignes-essai"
const SHADER := preload("res://enseignes_iso.gdshader")
const TuyauxIsoT := preload("res://tuyaux_iso.gd")
const NOM_NOEUD := "EnseignesIso"

## Ce qu'une enseigne avance devant sa face : la plaque, puis la peinture un peu en retrait. Sous le jour des tuyaux
## (`TuyauxIso.JOUR`, 0,5) : un tuyau passe toujours DEVANT une enseigne, jamais au travers.
const ECART_PLAQUE := 0.3
const ECART_PEINTURE := 0.2
const SAILLIE_MAX := 0.3
## Pas un sommet à moins de `MARGE_BOUT` du bout d'une face : l'encre des arêtes verticales du mur y fait jusqu'à 2,4 px
## (`IsoMateriaux.ENCRE_ARETE_PX_ESSAI`) plus son adoucissement, et l'enseigne, qui ne la relit pas, y serait plus claire que
## le trait ; vue à 60° de biais, une saillie de 0,3 px glisse encore de 0,52 px.
const MARGE_BOUT := 3.5
const SEUIL_FACE := 0.5

## La fonte : 5 × 7 cellules par lettre, une cellule d'espace entre deux lettres. La taille d'une cellule, en pixels du monde :
## ~1,4 px, soit des lettres de ~10 px de haut sur une face de 43,75 (~9 px d'écran au zoom du duel, tangage compris).
const CELLULE_PLAQUE := 1.4
const CELLULE_PEINTURE := 1.2
const TEXELS_PAR_CELLULE := 4
## La marge de la plaque autour du mot, en cellules.
const MARGE_PLAQUE := 2
## Le centre vertical, en fraction de la hauteur du mur : la plaque au-dessus du regard (le linteau de `ill_intro_seuil`),
## la peinture à hauteur d'homme (`ill_amical`).
const HAUTEUR_PLAQUE := 0.64
const HAUTEUR_PEINTURE := 0.52

## Les facteurs de la matière, TOUS ≤ 1 : multipliés par la lumière de la face et par `matiere_max`. Jamais une lumière.
const FOND_PLAQUE := 0.55
const BORD_PLAQUE := 0.40
const ROUILLE := 0.78
const RIVET := 0.25
const LETTRE_PLAQUE := 0.14
## La peinture : le béton × 0,45 sous la lettre (les pochoirs du sol en gardent 0,55) ; une lettre usée garde 0,70.
const PEINTURE := 0.45
const PEINTURE_USEE := 0.70
const USURE := 0.12

## Les enseignes se tiennent loin des départs (la règle des pochoirs du sol) et, pour « ZONE n », franchement d'un côté.
const DISTANCE_DEPART_CASES := 3.0
const ECART_COTE_CASES := 2.0

## Les éléments du groupe de Klein d'une carte rectangulaire : identité, miroir gauche-droite, miroir haut-bas, demi-tour.
enum Sym { ID, MX, MY, R }

## Les lettres, pochoir : les boucles coupées d'un pont (O, A, R). Seules celles des mots de l'essai.
const GLYPHES := {
	"A": [".###.", "#...#", "#...#", "##.##", "#...#", "#...#", "#...#"],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"N": ["#...#", "##..#", "#.#.#", "#.#.#", "#..##", "#...#", "#...#"],
	"O": ["##.##", "#...#", "#...#", "#...#", "#...#", "#...#", "##.##"],
	"R": ["####.", "#...#", "#...#", "##.#.", "#..#.", "#...#", "#...#"],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"1": ["..#..", ".##..", "#.#..", "..#..", "..#..", "..#..", "#####"],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
}

## Les sortes, et leur place dans l'atlas (en texels) : [texte en lignes, plaque ?, origine dans l'atlas].
const SORTES := {
	"ARENA": [["ARENA"], true, Vector2i(0, 0)],
	"ZONE 1": [["ZONE", "1"], false, Vector2i(0, 56)],
	"ZONE 2": [["ZONE", "2"], false, Vector2i(104, 56)],
}
const TAILLE_ATLAS := Vector2i(256, 128)


static func essai_actif() -> bool:
	return OS.get_cmdline_user_args().has(DRAPEAU_ENSEIGNES_ESSAI)


static func hauteur_max_px() -> float:
	return TuyauxIsoT.hauteur_mur_px() - SAILLIE_MAX * tan(deg_to_rad(CameraIso.TANGAGE_DEG))


## Au-dessus, même vue à 60° de biais, une enseigne ne recouvre à l'écran que sa face, jamais le sol à son pied.
static func hauteur_bas_px() -> float:
	return SAILLIE_MAX * tan(deg_to_rad(CameraIso.TANGAGE_DEG)) / SEUIL_FACE + 2.0


# ---------------------------------------------------------------------------
# LES MESURES D'UNE SORTE — en cellules de fonte, puis en pixels du monde
# ---------------------------------------------------------------------------

static func largeur_ligne(ligne: String) -> int:
	return ligne.length() * 6 - 1


## La taille d'une sorte en cellules : le mot le plus long, les lignes séparées de deux cellules, la marge de la plaque.
static func cellules(sorte: String) -> Vector2i:
	var lignes: Array = SORTES[sorte][0]
	var l := 0
	for ligne in lignes:
		l = maxi(l, largeur_ligne(ligne))
	var h := lignes.size() * 7 + (lignes.size() - 1) * 2
	var marge := MARGE_PLAQUE if SORTES[sorte][1] else 0
	return Vector2i(l + 2 * marge, h + 2 * marge)


static func taille_px(sorte: String) -> Vector2:
	var cellule := CELLULE_PLAQUE if SORTES[sorte][1] else CELLULE_PEINTURE
	return Vector2(cellules(sorte)) * cellule


static func rect_atlas(sorte: String) -> Rect2i:
	return Rect2i(SORTES[sorte][2], cellules(sorte) * TEXELS_PAR_CELLULE)


# ---------------------------------------------------------------------------
# L'ATLAS — les lettres et la tôle, dessinées ici : R le facteur (≤ 1), A la présence (0 : le mur seul)
# ---------------------------------------------------------------------------

static func atlas_image() -> Image:
	var img := Image.create(TAILLE_ATLAS.x, TAILLE_ATLAS.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for sorte in SORTES:
		_dessiner_sorte(img, sorte)
	return img


static func _dessiner_sorte(img: Image, sorte: String) -> void:
	var rect := rect_atlas(sorte)
	var plaque: bool = SORTES[sorte][1]
	var t := TEXELS_PAR_CELLULE
	var h := TuyauxIsoT.hacher([sorte.hash() & 0x7FFFFFFF])
	if plaque:
		for y in rect.size.y:
			for x in rect.size.x:
				var bord := x == 0 or y == 0 or x == rect.size.x - 1 or y == rect.size.y - 1
				# Les coins arrondis d'un texel : la tôle découpée.
				var coin := (x == 0 or x == rect.size.x - 1) and (y == 0 or y == rect.size.y - 1)
				if coin:
					continue
				var f := BORD_PLAQUE if bord else FOND_PLAQUE * (0.92 + 0.08 * TuyauxIsoT.tirage(h, x * 997 + y))
				# La rouille : des taches aux bords, tirées par blocs de 4 texels.
				var d_bord := mini(mini(x, y), mini(rect.size.x - 1 - x, rect.size.y - 1 - y))
				var bloc := TuyauxIsoT.tirage(h, 100000 + (x / 4) * 131 + (y / 4))
				if d_bord < 6 and bloc < 0.45 - 0.06 * float(d_bord):
					f *= ROUILLE
				_poser(img, rect.position + Vector2i(x, y), f)
		# Les rivets, aux quatre coins, à une cellule du bord.
		for cx in [t, rect.size.x - t - 2]:
			for cy in [t, rect.size.y - t - 2]:
				for k in 4:
					_poser(img, rect.position + Vector2i(cx + k % 2, cy + k / 2), RIVET)
	var lignes: Array = SORTES[sorte][0]
	var marge := MARGE_PLAQUE if plaque else 0
	var largeur := cellules(sorte).x - 2 * marge
	for i in lignes.size():
		var ligne: String = lignes[i]
		# Chaque ligne centrée sur la plus longue.
		var x0 := marge + (largeur - largeur_ligne(ligne)) / 2
		var y0 := marge + i * 9
		for j in ligne.length():
			var glyphe: Array = GLYPHES.get(ligne[j], [])
			for gy in glyphe.size():
				var rangee: String = glyphe[gy]
				for gx in rangee.length():
					if rangee[gx] != "#":
						continue
					for k in t * t:
						var p := Vector2i((x0 + j * 6 + gx) * t + k % t, (y0 + gy) * t + k / t)
						var f := LETTRE_PLAQUE
						if not plaque:
							f = PEINTURE_USEE if TuyauxIsoT.tirage(h, 200000 + p.x * 389 + p.y) < USURE else PEINTURE
						_poser(img, rect.position + p, f)


static func _poser(img: Image, p: Vector2i, facteur: float) -> void:
	img.set_pixelv(p, Color(clampf(facteur, 0.0, 1.0), 0.0, 0.0, 1.0))


static func atlas_texture() -> ImageTexture:
	var img := atlas_image()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------------------
# LE GROUPE DE LA CARTE — les symétries des murs, et celle qui échange les départs
# ---------------------------------------------------------------------------

## Les dimensions de la carte sans sa ceinture, en cases.
static func cases_carte(data: Dictionary) -> Vector2i:
	var hauts := MapGeometry.build_grid(data, MapGeometry.Kind.WALLS)
	if hauts.is_empty():
		return Vector2i.ZERO
	return Vector2i(hauts.size() - 2 * MapGeometry.BORDER, (hauts[0] as Array).size() - 2 * MapGeometry.BORDER)


## L'image d'une case (sans ceinture) par un élément du groupe.
static func case_image(c: Vector2i, s: int, taille: Vector2i) -> Vector2i:
	var x := taille.x - 1 - c.x if s == Sym.MX or s == Sym.R else c.x
	var y := taille.y - 1 - c.y if s == Sym.MY or s == Sym.R else c.y
	return Vector2i(x, y)


static func depart(data: Dictionary, cle: String) -> Vector2i:
	var d: Variant = data.get(cle, {})
	if d is Dictionary and (d as Dictionary).has("x"):
		return Vector2i(int(d["x"]), int(d["y"]))
	return Vector2i(-1, -1)


## Les symétries exactes des murs, des fosses et des murets de la carte.
static func symetries_des_murs(data: Dictionary) -> Array[int]:
	var grilles: Array = [MapGeometry.build_grid(data, MapGeometry.Kind.WALLS),
		MapGeometry.build_grid(data, MapGeometry.Kind.PITS)]
	var kinds: Dictionary = MapGeometry.Kind
	if kinds.has("LOW_WALLS"):
		grilles.append(MapGeometry.build_grid(data, kinds["LOW_WALLS"]))
	var sortie: Array[int] = [Sym.ID]
	for s in [Sym.MX, Sym.MY, Sym.R]:
		var ok := true
		for g in grilles:
			var w: int = (g as Array).size()
			var h: int = (g[0] as Array).size() if w > 0 else 0
			for x in w:
				for y in h:
					var i := case_image(Vector2i(x, y), s, Vector2i(w, h))
					if bool(g[x][y]) != bool(g[i.x][i.y]):
						ok = false
						break
				if not ok:
					break
			if not ok:
				break
		if ok:
			sortie.append(s)
	return sortie


## La symétrie qui porte le départ de J1 sur celui de J2 (miroir gauche-droite d'abord, puis demi-tour, puis haut-bas) ;
## `Sym.ID` si aucune.
static func sigma(data: Dictionary) -> int:
	var taille := cases_carte(data)
	var d1 := depart(data, "spawn_p1")
	var d2 := depart(data, "spawn_p2")
	for s in [Sym.MX, Sym.R, Sym.MY]:
		if case_image(d1, s, taille) == d2:
			return s
	return Sym.ID


static func composer(a: int, b: int) -> int:
	# Le groupe de Klein : chaque élément est son propre inverse, et le produit de deux éléments distincts non neutres
	# est le troisième.
	if a == Sym.ID:
		return b
	if b == Sym.ID:
		return a
	if a == b:
		return Sym.ID
	return 6 - a - b


## Le groupe engendré par `sigma` et le demi-tour : les jumelles qu'exige l'équité, au lacet 0 (option A, J2 au même
## lacet : `sigma` y est le miroir des cartes livrées) comme à l'option B (J2 à + 180° : le demi-tour).
static func groupe(data: Dictionary) -> Array[int]:
	var g: Array[int] = [Sym.ID]
	for generateur in [sigma(data), Sym.R]:
		for e in g.duplicate():
			var p := composer(e, generateur)
			if not g.has(p):
				g.append(p)
	g.sort()
	return g


## L'image d'un point du monde (px, sans ceinture) et d'une normale par un élément du groupe.
static func point_image(p: Vector2, s: int, dim: Vector2) -> Vector2:
	return Vector2(dim.x - p.x if s == Sym.MX or s == Sym.R else p.x,
		dim.y - p.y if s == Sym.MY or s == Sym.R else p.y)


static func normale_image(n: Vector2, s: int) -> Vector2:
	return Vector2(-n.x if s == Sym.MX or s == Sym.R else n.x, -n.y if s == Sym.MY or s == Sym.R else n.y)


# ---------------------------------------------------------------------------
# LE PLACEMENT
# ---------------------------------------------------------------------------

static func _bouts(f: Dictionary) -> Array[Vector2]:
	var n: Vector2 = f["n"]
	var t := Vector2(-n.y, n.x)
	return [n * float(f["d"]) + t * float(f["s0"]), n * float(f["d"]) + t * float(f["s1"])]


## La clé d'une face : sa normale et ses deux bouts, en pixels entiers (des multiples de la tuile : exacts).
static func cle_face(n: Vector2, a: Vector2, b: Vector2) -> String:
	var p := a if a.x < b.x or (a.x == b.x and a.y < b.y) else b
	var q := b if p == a else a
	return "%d,%d|%d,%d|%d,%d" % [roundi(n.x), roundi(n.y), roundi(p.x), roundi(p.y), roundi(q.x), roundi(q.y)]


static func milieu(f: Dictionary) -> Vector2:
	var b := _bouts(f)
	return (b[0] + b[1]) * 0.5


static func _centre_depart(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * float(CandelaTileSet.TILE_SIZE.x)


## Les enseignes de la carte : une liste de `{sorte, face (indice dans faces), s, y}` et les faces, le groupe, sigma.
## Une orbite (une face et toutes ses images par le groupe, toutes exposées, dont une face sud) pour « ARENA », la plus proche
## du centre ; une pour « ZONE n », la plus proche des départs, chaque face franchement d'un côté. Aucune carte n'en porte plus.
static func construire(data: Dictionary) -> Dictionary:
	var faces := TuyauxIsoT.faces(data)
	var taille := cases_carte(data)
	var tuile := float(CandelaTileSet.TILE_SIZE.x)
	var dim_px := Vector2(taille) * tuile
	var grp := groupe(data)
	var index := {}
	for i in faces.size():
		var b := _bouts(faces[i])
		index[cle_face(faces[i]["n"], b[0], b[1])] = i
	# Les orbites complètes, dans l'ordre des faces.
	var orbites: Array = []
	var vues := {}
	for i in faces.size():
		if vues.has(i):
			continue
		var orbite: Array[int] = []
		var complete := true
		for s in grp:
			var b := _bouts(faces[i])
			var cle := cle_face(normale_image(faces[i]["n"], s), point_image(b[0], s, dim_px),
				point_image(b[1], s, dim_px))
			if not index.has(cle):
				complete = false
				break
			var j: int = index[cle]
			if not orbite.has(j):
				orbite.append(j)
		if not complete:
			continue
		for j in orbite:
			vues[j] = true
		orbites.append(orbite)
	var d1 := _centre_depart(depart(data, "spawn_p1"))
	var d2 := _centre_depart(depart(data, "spawn_p2"))
	var centre := dim_px * 0.5
	var loin := DISTANCE_DEPART_CASES * tuile
	var h_mur := TuyauxIsoT.hauteur_mur_px()
	var enseignes: Array[Dictionary] = []
	var prises := {}
	# « ARENA », puis « ZONE n ».
	for sorte in ["ARENA", "ZONE"]:
		var largeur := taille_px("ARENA" if sorte == "ARENA" else "ZONE 1").x + 2.0 * MARGE_BOUT
		var meilleure: Array = []
		var meilleur_score := INF
		for orbite in orbites:
			# Lisible au lacet 0 : l'orbite porte une face SUD (que voit J1 à 0° et à 45°) — donc, par le demi-tour, une face
			# NORD (que voit J2 à 180° et à 225°, l'option B). Pour « ZONE », cette face sud est du côté de J1 : son image
			# par le demi-tour, du côté de J2, et chacun lit la sienne près de lui.
			var ok := false
			for i in orbite:
				var m_sud := milieu(faces[i])
				if (faces[i]["n"] as Vector2) == Vector2(0, 1) \
						and (sorte == "ARENA" or m_sud.distance_to(d1) < m_sud.distance_to(d2)):
					ok = true
			var score := INF
			for i in orbite:
				var f: Dictionary = faces[i]
				var m := milieu(f)
				var e1 := m.distance_to(d1)
				var e2 := m.distance_to(d2)
				if prises.has(i) or float(f["s1"]) - float(f["s0"]) < largeur or minf(e1, e2) < loin:
					ok = false
				elif sorte == "ZONE" and absf(e1 - e2) < ECART_COTE_CASES * tuile:
					ok = false
				score = minf(score, m.distance_to(centre) if sorte == "ARENA" else minf(e1, e2))
			if ok and score < meilleur_score - 0.001:
				meilleur_score = score
				meilleure = orbite
		for i in meilleure:
			prises[i] = true
			var f: Dictionary = faces[i]
			var m := milieu(f)
			var nom := "ARENA"
			if sorte == "ZONE":
				nom = "ZONE 1" if m.distance_to(d1) < m.distance_to(d2) else "ZONE 2"
			enseignes.append({"sorte": nom, "face": i, "s": (float(f["s0"]) + float(f["s1"])) * 0.5,
				"y": h_mur * (HAUTEUR_PLAQUE if sorte == "ARENA" else HAUTEUR_PEINTURE)})
	return {"faces": faces, "enseignes": enseignes, "groupe": grp, "sigma": sigma(data), "taille_px": dim_px}


# ---------------------------------------------------------------------------
# LE MAILLAGE — un quadrilatère par enseigne
# ---------------------------------------------------------------------------

## L'axe de lecture d'une face de normale `n` (x, y du monde 2D) : la droite de qui la regarde de face, `(n.y, −n.x)`
## — le produit vectoriel du haut du monde par la normale.
static func axe_lecture(n: Vector2) -> Vector2:
	return Vector2(n.y, -n.x)


## Les quatre coins d'une enseigne, haut-gauche, haut-droit, bas-droit, bas-gauche, vus de face.
static func coins(f: Dictionary, e: Dictionary) -> Array[Vector3]:
	var n: Vector2 = f["n"]
	var sorte: String = e["sorte"]
	var taille := taille_px(sorte)
	var ecart := ECART_PLAQUE if SORTES[sorte][1] else ECART_PEINTURE
	var centre := n * (float(f["d"]) + ecart) + Vector2(-n.y, n.x) * float(e["s"])
	var droite := axe_lecture(n) * taille.x * 0.5
	var y: float = e["y"]
	var haut := y + taille.y * 0.5
	var bas := y - taille.y * 0.5
	var g := centre - droite
	var d := centre + droite
	return [Vector3(g.x, haut, g.y), Vector3(d.x, haut, d.y), Vector3(d.x, bas, d.y), Vector3(g.x, bas, g.y)]


static func tableaux(c: Dictionary) -> Array:
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var plan := PackedFloat32Array()
	var indices := PackedInt32Array()
	var faces: Array = c["faces"]
	for e in c["enseignes"]:
		var f: Dictionary = faces[int(e["face"])]
		var n: Vector2 = f["n"]
		var r := rect_atlas(e["sorte"])
		var u0 := Vector2(r.position) / Vector2(TAILLE_ATLAS)
		var u1 := Vector2(r.end) / Vector2(TAILLE_ATLAS)
		var base := sommets.size()
		var coins_uv: Array[Vector2] = [u0, Vector2(u1.x, u0.y), u1, Vector2(u0.x, u1.y)]
		var q := coins(f, e)
		for k in 4:
			sommets.append(q[k])
			normales.append(Vector3(n.x, 0.0, n.y))
			uv.append(coins_uv[k])
			uv2.append(n)
			plan.append_array(PackedFloat32Array([float(f["d"]), 0.0, 0.0, 0.0]))
		# Horaire vu de face : la face avant de Godot (celle des tuyaux, comparée par leur garde à une `BoxMesh`).
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	var t := []
	t.resize(Mesh.ARRAY_MAX)
	t[Mesh.ARRAY_VERTEX] = sommets
	t[Mesh.ARRAY_NORMAL] = normales
	t[Mesh.ARRAY_TEX_UV] = uv
	t[Mesh.ARRAY_TEX_UV2] = uv2
	t[Mesh.ARRAY_CUSTOM0] = plan
	t[Mesh.ARRAY_INDEX] = indices
	return t


static func maillage(c: Dictionary) -> ArrayMesh:
	if (c["enseignes"] as Array).is_empty():
		return null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux(c), [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return m


## Le nœud de la carte : un `MeshInstance3D` sans ombre, sur le calque commun ; son atlas posé sur le matériau. `null` si
## la carte ne porte aucune enseigne.
static func creer_noeud(data: Dictionary, materiau: ShaderMaterial) -> MeshInstance3D:
	var m := maillage(construire(data))
	# La preuve pour la série de cadence des essais, même forme que « [tuyaux] allumés ».
	print(TuyauxIsoT.ligne_etat("[enseignes] allumées", [m], data))
	if m == null:
		return null
	if materiau.get_shader_parameter("atlas") == null:
		materiau.set_shader_parameter("atlas", atlas_texture())
	var noeud := MeshInstance3D.new()
	noeud.name = NOM_NOEUD
	noeud.mesh = m
	noeud.material_override = materiau
	noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	noeud.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	noeud.layers = 1
	return noeud


## Le matériau : la lecture de la face réglée comme celle des tuyaux (donc des murs).
static func accorder(materiau: ShaderMaterial) -> void:
	var active := IsoMateriaux.beaute_active()
	materiau.set_shader_parameter("pied", IsoMateriaux.PIED_FACE_PX)
	materiau.set_shader_parameter("seuil_face", SEUIL_FACE)
	materiau.set_shader_parameter("matiere_max", TuyauxIsoT.matiere_max())
	materiau.set_shader_parameter("contact_px", IsoMateriaux.CONTACT_PX if active else 0.0)
	materiau.set_shader_parameter("contact_reste", IsoMateriaux.CONTACT_RESTE)
	materiau.set_shader_parameter("temperature", IsoMateriaux.TEMPERATURE_GRADUEE if active else 0.0)
	materiau.set_shader_parameter("temperature_seuil_bas", IsoMateriaux.TEMPERATURE_SEUIL_BAS)
	materiau.set_shader_parameter("temperature_seuil_haut", IsoMateriaux.TEMPERATURE_SEUIL_HAUT if active else 0.0)
	materiau.set_shader_parameter("neutre_avant_pate", 1.0 if active else 0.0)
	materiau.set_shader_parameter("emprise_preuve", false)
