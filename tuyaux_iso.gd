## TuyauxIso — les tuyaux et les câbles des murs de la vue isométrique, EN ESSAI (`--tuyaux-essai`, éteint par défaut).
##
## ## Pourquoi
##
## Les illustrations des menus (`assets/ui/ill_entrainement.png`, `ill_accueil.png`…) portent sur leurs murs des conduites
## cerclées de colliers, des descentes jusqu'au sol et des câbles qui pendent d'un crochet à l'autre. Le jeu a déjà le béton,
## les fissures, les taches, les coulures et les impacts (l'usure) ; il lui manquait ce mobilier. Il s'ajoute EN ESSAI,
## derrière un drapeau, comme l'encre et l'usure avant lui : rien ne s'allume en jeu avant l'avis d'Adrien et la mesure de
## cadence au Mac (règle des 3 %).
##
## ## Les garde-fous, qui priment sur l'image (prouvés par `tools/test_iso_tuyaux.gd`)
##
## - **Le noir absolu, à l'ÉCRAN et pas seulement dans le monde.** Un tuyau n'a aucune lumière à lui. Chaque pixel de tuyau
##   relit la lumière du pixel de FACE qu'il recouvre à l'écran — le rayon de la caméra prolongé jusqu'au plan de la face —,
##   par les mêmes fonctions que `mur_iso.gdshader` (lightmap du joueur au pied de la face, moyennée le long d'elle, sans la
##   peinture du sol), puis la multiplie par un facteur ≤ 1 (`pate_matiere_et_encre`). Face noire à cet endroit de l'écran :
##   tuyau noir. ⚠️ Lire au point d'ATTACHE du tuyau (dans le monde) aurait suffi à 0° de lacet, pas à 45° : le tuyau y couvre
##   à l'écran un point de face décalé de sa saillie, et un bord d'ombre se serait allumé sur quelques pixels noirs — la leçon
##   de la parallaxe des volumes (ROADMAP, « Pièges connus », 2026-09-24).
## - **Rien qui cache un joueur.** Aucune collision, aucun `LightOccluder2D`, aucune ombre (`cast_shadow` éteint, `unshaded`).
##   Un tuyau ne se dessine que sur une face que la caméra qui dessine voit de face (`SEUIL_FACE`, écrasé au sommet sinon) :
##   tout ce qui est derrière lui à l'écran est derrière le mur. Aucun point au-dessus de `hauteur_max_px()`, sous l'arête
##   d'une saillie entière vue sous le tangage (défense en profondeur : même un tuyau de face cachée ne dépasserait pas du
##   sommet). Aucune saillie de plus de `SAILLIE_MAX` hors de l'emprise du mur, et `MARGE_BOUT` aux bouts de chaque face.
## - **L'équité.** Placement tiré des seules cases de la carte par un hachage entier (aucun `randf`, aucune graine) : le même
##   à chaque lancement, sur chaque machine. Un seul maillage dans le monde 3D commun (calque 1) : les deux joueurs voient les
##   mêmes tuyaux, chacun sur les faces que SA caméra voit — à 0° de lacet une face par mur, à 45° deux.
## - **Le coût.** Un seul maillage fusionné par carte, un seul matériau : un appel de dessin de plus par vue 3D, quelle que
##   soit la carte.
##
## Repère : celui d'`IsoGeometrie` — le monde 3D en pixels du monde 2D, `x` → `x`, `y` → `z`, le sol à `y = 0`.
class_name TuyauxIso
extends RefCounted

const DRAPEAU_TUYAUX_ESSAI := "--tuyaux-essai"
const SHADER := preload("res://tuyaux_iso.gdshader")
const NOM_NOEUD := "TuyauxIso"

## Les mesures, en pixels du monde. Une conduite fait 4 px de diamètre : ~6 px d'écran au zoom du duel, sur une face qui en
## montre ~40 de haut. Un câble, 1,6 px : un trait d'encre.
const RAYON_CONDUITE := 2.0
## Le jour entre la face et le tuyau : sans lui, le dos du tuyau se battrait avec la face dans le tampon de profondeur.
const JOUR := 0.5
const RAYON_COLLIER := 2.5
const LARGEUR_COLLIER := 2.0
const RAYON_CABLE := 0.8
## Ce qu'un tuyau avance au plus devant sa face : le collier, axe de la conduite (jour + rayon) plus son rayon. La garde en
## fait sa tolérance d'emprise.
const SAILLIE_MAX := JOUR + RAYON_CONDUITE + RAYON_COLLIER + 0.1
## Pas un sommet à moins de `MARGE_BOUT` du bout d'une face : vue à 60° de biais (le plus que `SEUIL_FACE` laisse dessiner),
## une saillie de `SAILLIE_MAX` se décale à l'écran de `SAILLIE_MAX × tan 60°` ≈ 8,8 px le long de la face.
const MARGE_BOUT := 10.0
## Un tuyau ne se dessine que pour une caméra qui voit sa face à moins de 60° de biais (cos 60° = 0,5). À 0° de lacet : les
## faces sud seules ; à 45° : deux faces par mur ; les faces vues de profil ou de dos ne portent rien.
const SEUIL_FACE := 0.5

const COTES_CONDUITE := 8
const COTES_CABLE := 4
## La longueur d'un tronçon de câble : la chaînette est une polyligne.
const PAS_CABLE := 5.0

## Les facteurs de la matière : jamais une lumière. Plafonnés par `matiere_max()`, la matière la plus sombre qu'une face
## puisse porter : un tuyau n'est donc JAMAIS plus clair que le pixel de face qu'il recouvre (la règle de l'usure, « rien
## n'est jamais plus clair qu'avant »). Le métal sombre des illustrations.
const ALBEDO_CONDUITE := 0.9
const ALBEDO_COLLIER := 1.0
const ALBEDO_CABLE := 0.9
## Le modelé du tuyau, par la CAMÉRA (le patron du modelé des corps) : le reflet le long de l'axe tourné vers la caméra garde
## la matière entière ; le corps prend `CORPS_SOMBRE` de l'encre, le contour toute. Un tuyau sombre au reflet clair, cerné
## d'encre. Aucune direction du monde n'est éclairée plus qu'une autre.
const CORPS_SOMBRE := 0.9
## Ce que l'encre garde de la lumière (corps et contour) — celle des arêtes des murs (`IsoMateriaux.ENCRE_ARETE_RESTE`) —,
## au-dessus du plancher d'encre des murs (16/255) : sous une lumière faible, l'encre n'éteint rien.
const ENCRE_RESTE := 0.25


static func essai_actif() -> bool:
	return OS.get_cmdline_user_args().has(DRAPEAU_TUYAUX_ESSAI)


static func hauteur_mur_px() -> float:
	return IsoGeometrie.hauteur_mur_haut() * float(CandelaTileSet.TILE_SIZE.y)


## Le plus haut qu'un sommet de tuyau puisse monter : l'arête, moins ce qu'une saillie entière laisse voir derrière un mur
## sous le tangage de la caméra. Même porté par une face que la caméra ne voit pas, un tuyau ne dépasse donc jamais du sommet.
static func hauteur_max_px() -> float:
	return hauteur_mur_px() - SAILLIE_MAX * tan(deg_to_rad(CameraIso.TANGAGE_DEG))


## Le plus bas qu'un tuyau descende : au-dessus, même vu à 60° de biais, il ne recouvre à l'écran que sa FACE, jamais la bande
## de sol à son pied (les hachures d'encre de `MurEncre` y sont noires : un tuyau lu à la lumière de la face les aurait
## allumées). Une descente entre donc dans le mur à hauteur de genou, sous un coude bouché.
static func hauteur_bas_px() -> float:
	return SAILLIE_MAX * tan(deg_to_rad(CameraIso.TANGAGE_DEG)) / SEUIL_FACE + 2.0


## La matière la plus sombre qu'une face de mur puisse porter (`mur_iso.gdshader` : `mix(1, texture, force)`, la texture
## jamais sous `IsoMateriaux.PLANCHER`) — le plafond de la matière des tuyaux. Sans beauté, la face est nue : 1.
static func matiere_max() -> float:
	if not IsoMateriaux.beaute_active():
		return 1.0
	return lerpf(1.0, IsoMateriaux.PLANCHER, IsoMateriaux.FORCE_MATIERE_MUR)


## La direction vers la caméra, pour un tangage et un lacet — la base de `CameraIso.transform_pour`, et
## `INV_VIEW_MATRIX[2].xyz` dans le shader.
static func vers_camera(lacet_deg: float, tangage_deg: float = CameraIso.TANGAGE_DEG) -> Vector3:
	return Basis.from_euler(Vector3(deg_to_rad(-tangage_deg), deg_to_rad(lacet_deg), 0.0), EULER_ORDER_YXZ).z


## Miroir processeur du tri du shader : la caméra de ce lacet dessine-t-elle les tuyaux de la face de normale `n` ?
static func face_dessinee(n: Vector2, lacet_deg: float, tangage_deg: float = CameraIso.TANGAGE_DEG) -> bool:
	var z := vers_camera(lacet_deg, tangage_deg)
	var h := Vector2(z.x, z.z)
	return h.length() > 0.0001 and n.dot(h.normalized()) >= SEUIL_FACE


# ---------------------------------------------------------------------------
# LES FACES — les longueurs continues de face exposée des murs hauts
# ---------------------------------------------------------------------------

## Les faces exposées des murs hauts, une entrée par longueur continue : `n` la normale sortante (x, y du monde 2D), `d` le
## plan (`n · p = d`), `s0`/`s1` l'étendue le long de la tangente `(−n.y, n.x)` (celle de `mur_iso.gdshader`), `cases` la
## longueur en tuiles, `cle` ce que le hachage lit. Une face se meuble si la case devant elle est du SOL : devant un muret,
## le bas de la face est caché et une descente y entrerait ; devant une fosse ou hors de la carte (la ceinture en est une),
## personne ne se tient pour la voir — le dos des murs d'enceinte ne porte rien.
static func faces(data: Dictionary) -> Array[Dictionary]:
	var sortie: Array[Dictionary] = []
	var hauts := MapGeometry.build_grid(data, MapGeometry.Kind.WALLS)
	var fosses := MapGeometry.build_grid(data, MapGeometry.Kind.PITS)
	var kinds: Dictionary = MapGeometry.Kind
	var bas: Array = MapGeometry.build_grid(data, kinds["LOW_WALLS"]) if kinds.has("LOW_WALLS") else []
	var largeur := hauts.size()
	if largeur == 0:
		return sortie
	var hauteur := (hauts[0] as Array).size()
	var tuile := float(CandelaTileSet.TILE_SIZE.x)
	# Quatre directions, dans un ordre fixe : sud, nord, est, ouest.
	var normales := [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]
	for sens in 4:
		var n: Vector2 = normales[sens]
		var le_long_x := sens < 2
		var lignes := hauteur if le_long_x else largeur
		var cases_par_ligne := largeur if le_long_x else hauteur
		for ligne in lignes:
			var debut := -1
			for k in cases_par_ligne + 1:
				var expose := false
				if k < cases_par_ligne:
					var x := k if le_long_x else ligne
					var y := ligne if le_long_x else k
					var dx := x + int(n.x)
					var dy := y + int(n.y)
					var devant_sol := dx >= 0 and dy >= 0 and dx < largeur and dy < hauteur \
						and not bool(hauts[dx][dy]) and not bool(fosses[dx][dy]) \
						and not (not bas.is_empty() and bool(bas[dx][dy]))
					expose = bool(hauts[x][y]) and devant_sol
				if expose and debut < 0:
					debut = k
				elif not expose and debut >= 0:
					sortie.append(_face(n, sens, ligne, debut, k, tuile))
					debut = -1
	return sortie


static func _face(n: Vector2, sens: int, ligne: int, debut: int, fin: int, tuile: float) -> Dictionary:
	var bord := MapGeometry.BORDER
	var t := Vector2(-n.y, n.x)
	# Le plan : la ligne de cases, décalée d'une case vers l'extérieur pour les faces sud et est.
	var cote := float(ligne - bord + (1 if n.x + n.y > 0.0 else 0)) * tuile
	var a := float(debut - bord) * tuile
	var b := float(fin - bord) * tuile
	var p_a := Vector2(a, cote) if absf(n.y) > 0.5 else Vector2(cote, a)
	var p_b := Vector2(b, cote) if absf(n.y) > 0.5 else Vector2(cote, b)
	var s_a := p_a.dot(t)
	var s_b := p_b.dot(t)
	return {"n": n, "d": p_a.dot(n), "s0": minf(s_a, s_b), "s1": maxf(s_a, s_b), "cases": fin - debut,
		"cle": [sens, ligne, debut]}


# ---------------------------------------------------------------------------
# LE HASARD SANS HASARD — un hachage entier des cases
# ---------------------------------------------------------------------------

## Un hachage entier sur 31 bits : tous les produits tiennent dans un entier de 64 bits, donc le même résultat sur chaque
## machine, sans `randf`, sans graine.
static func hacher(valeurs: Array) -> int:
	var h := 2166136261 & 0x7FFFFFFF
	for v in valeurs:
		h = ((h ^ (int(v) & 0x7FFFFFFF)) * 16777619) & 0x7FFFFFFF
		h ^= h >> 13
	return h


## Le `k`-ième tirage dans [0, 1) d'un hachage.
static func tirage(h: int, k: int) -> float:
	var x := (h ^ ((k + 1) * 374761393)) & 0x7FFFFFFF
	x = ((x ^ (x >> 15)) * 2246822519) & 0x7FFFFFFF
	x = ((x ^ (x >> 13)) * 3266489917) & 0x7FFFFFFF
	x ^= x >> 16
	return float(x & 0xFFFFFF) / 16777216.0


# ---------------------------------------------------------------------------
# LE PLACEMENT ET LE MAILLAGE
# ---------------------------------------------------------------------------

## Le chantier d'une carte : les tableaux du maillage en cours, remplis par les méthodes de l'objet lui-même (un tableau
## compact tiré d'un dictionnaire ou capturé par une lambda peut être une copie : ici, aucune ambiguïté).
class Chantier:
	extends RefCounted
	var faces: Array[Dictionary] = []
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var indices := PackedInt32Array()
	var face_de_sommet := PackedInt32Array()
	var compte := {"conduites": 0, "colliers": 0, "descentes": 0, "colonnes": 0, "cables": 0}

	func ajouter(i: int, p: Vector3, normale: Vector3, albedo: float) -> void:
		var f: Dictionary = faces[i]
		sommets.append(p)
		normales.append(normale)
		# UV : le plan de la face et la matière ; UV2 : la normale de la face. Le shader n'a besoin de rien d'autre.
		uv.append(Vector2(float(f["d"]), albedo))
		uv2.append(f["n"])
		face_de_sommet.append(i)

	## Un tube le long d'une polyligne `points` : un anneau de `cotes` sommets par point, normales lissées, orienté par la
	## normale de la face (perpendiculaire à tout axe couché dans la face). Enroulement horaire vu de dehors : la face avant
	## de Godot, que `cull_back` garde (la garde le compare à celui d'une `BoxMesh`). `bouche` : un disque à chaque bout.
	func tube(i: int, points: Array[Vector3], rayon: float, cotes: int, albedo: float, bouche: bool) -> void:
		var n2: Vector2 = faces[i]["n"]
		var u := Vector3(n2.x, 0.0, n2.y)
		var base := sommets.size()
		var reperes: Array[Vector3] = []
		for k in points.size():
			var direction := (points[mini(k + 1, points.size() - 1)] - points[maxi(k - 1, 0)]).normalized()
			var v := direction.cross(u).normalized()
			reperes.append(v)
			for j in cotes:
				var a := TAU * float(j) / float(cotes)
				var radiale := u * cos(a) + v * sin(a)
				ajouter(i, points[k] + radiale * rayon, radiale, albedo)
		for k in points.size() - 1:
			for j in cotes:
				var a0 := base + k * cotes + j
				var a1 := base + k * cotes + (j + 1) % cotes
				var b0 := a0 + cotes
				var b1 := a1 + cotes
				indices.append_array(PackedInt32Array([a0, b0, a1, a1, b0, b1]))
		if not bouche:
			return
		for bout in 2:
			var k := 0 if bout == 0 else points.size() - 1
			var dehors := (points[1] - points[0]).normalized() * (-1.0 if bout == 0 else 1.0)
			var centre := sommets.size()
			ajouter(i, points[k], dehors, albedo)
			for j in cotes:
				var a := TAU * float(j) / float(cotes)
				ajouter(i, points[k] + (u * cos(a) + reperes[k] * sin(a)) * rayon, dehors, albedo)
			for j in cotes:
				var a0 := centre + 1 + j
				var a1 := centre + 1 + (j + 1) % cotes
				indices.append_array(PackedInt32Array([centre, a0, a1] if bout == 0 else [centre, a1, a0]))

	## Un collier (ou un coude) : un anneau court autour d'un axe horizontal (le long de la face) ou vertical, bouché.
	func collier(i: int, s: float, y: float, vertical: bool, rayon := RAYON_COLLIER, largeur := LARGEUR_COLLIER) -> void:
		var f: Dictionary = faces[i]
		var n: Vector2 = f["n"]
		var centre := Chantier.point(f, s, y, JOUR + RAYON_CONDUITE)
		var demi := (Vector3(0.0, 1.0, 0.0) if vertical else Vector3(-n.y, 0.0, n.x)) * largeur * 0.5
		var bouts: Array[Vector3] = [centre - demi, centre + demi]
		tube(i, bouts, rayon, COTES_CONDUITE, ALBEDO_COLLIER, true)
		compte["colliers"] += 1

	## Le point à l'abscisse `s` le long de la face `f`, à la hauteur `y`, à `ecart` devant elle.
	static func point(f: Dictionary, s: float, y: float, ecart: float) -> Vector3:
		var n: Vector2 = f["n"]
		var p := n * (float(f["d"]) + ecart) + Vector2(-n.y, n.x) * s
		return Vector3(p.x, y, p.y)


## Le mobilier de la carte `data`, prêt à devenir un maillage : les tableaux de sommets, et pour la garde, la face de
## chaque sommet (`face_de_sommet`, indice dans `faces`) et le compte de chaque sorte de pièce.
static func construire(data: Dictionary) -> Dictionary:
	var c := Chantier.new()
	c.faces = faces(data)
	var h_mur := hauteur_mur_px()
	var h_max := hauteur_max_px()
	for i in c.faces.size():
		_meubler(c, i, h_mur, h_max)
	return {"faces": c.faces, "sommets": c.sommets, "normales": c.normales, "uv": c.uv, "uv2": c.uv2,
		"indices": c.indices, "face_de_sommet": c.face_de_sommet, "compte": c.compte}


## Le programme d'une face de deux cases et plus, tiré de sa clé : 0 une conduite, 1 une conduite et des câbles, 2 des câbles,
## 3 une conduite et sa descente (une conduite seule sous trois cases), 4 rien.
static func programme_de(f: Dictionary) -> int:
	return int(tirage(hacher(f["cle"]), 0) * 5.0)


## Le mobilier d'une face selon son programme. Une case seule (un pilier, un bout de mur) : parfois une colonne montante.
static func _meubler(c: Chantier, i: int, h_mur: float, h_max: float) -> void:
	var f: Dictionary = c.faces[i]
	var h := hacher(f["cle"])
	var s0: float = float(f["s0"]) + MARGE_BOUT
	var s1: float = float(f["s1"]) - MARGE_BOUT
	var cases: int = f["cases"]
	var tuile := float(CandelaTileSet.TILE_SIZE.x)
	var ecart := JOUR + RAYON_CONDUITE
	var bas := hauteur_bas_px()
	if cases < 2:
		if tirage(h, 0) < 0.35:
			var s := (s0 + s1) * 0.5
			var haut := h_max - RAYON_COLLIER - 0.4
			var axe: Array[Vector3] = [point(f, s, bas, ecart), point(f, s, haut, ecart)]
			c.tube(i, axe, RAYON_CONDUITE, COTES_CONDUITE, ALBEDO_CONDUITE, false)
			# Les colliers des deux bouts bouchent la colonne : vue d'en haut à 52°, un tube ouvert montrerait son creux.
			c.collier(i, s, bas + LARGEUR_COLLIER * 0.5, true)
			c.collier(i, s, haut - LARGEUR_COLLIER * 0.5, true)
			c.compte["colonnes"] += 1
		return
	var programme := programme_de(f)
	var conduite := programme in [0, 1, 3]
	var cables := programme in [1, 2]
	var descente := programme == 3 and cases >= 3
	# La conduite : basse quand des câbles pendent au-dessus d'elle, plus haute seule.
	var hc := h_mur * ((0.56 + 0.06 * tirage(h, 1)) if cables else (0.64 + 0.14 * tirage(h, 1)))
	hc = minf(hc, h_max - RAYON_COLLIER - 0.1)
	if conduite:
		var depart := s0
		var arrivee := s1
		var colliers: Array[float] = []
		if descente:
			# La descente : de la conduite jusqu'où elle entre dans le mur (`hauteur_bas_px`), à un bout ; un coude bouché la
			# joint à la conduite, un collier bouché la ferme en bas.
			var au_debut := tirage(h, 2) < 0.5
			var s_d := (s0 + RAYON_COLLIER) if au_debut else (s1 - RAYON_COLLIER)
			var axe: Array[Vector3] = [point(f, s_d, bas, ecart), point(f, s_d, hc, ecart)]
			c.tube(i, axe, RAYON_CONDUITE, COTES_CONDUITE, ALBEDO_CONDUITE, false)
			c.collier(i, s_d, hc, false, RAYON_CONDUITE + 0.3, 2.0 * RAYON_CONDUITE + 0.6)
			c.collier(i, s_d, bas + LARGEUR_COLLIER * 0.5, true)
			if hc - 6.0 > bas + 3.0 * LARGEUR_COLLIER:
				c.collier(i, s_d, hc - 6.0, true)
			if au_debut:
				depart = s_d
				colliers.append(s1 - LARGEUR_COLLIER * 0.5)
			else:
				arrivee = s_d
				colliers.append(s0 + LARGEUR_COLLIER * 0.5)
			c.compte["descentes"] += 1
		else:
			colliers.append(s0 + LARGEUR_COLLIER * 0.5)
			colliers.append(s1 - LARGEUR_COLLIER * 0.5)
		var ligne_conduite: Array[Vector3] = [point(f, depart, hc, ecart), point(f, arrivee, hc, ecart)]
		c.tube(i, ligne_conduite, RAYON_CONDUITE, COTES_CONDUITE, ALBEDO_CONDUITE, false)
		# Un collier par case, au milieu de la case, loin des bouts.
		var s_case: float = float(f["s0"]) + tuile * 0.5
		while s_case < s1 - 4.0:
			if s_case > s0 + 4.0:
				colliers.append(s_case)
			s_case += tuile
		for s in colliers:
			c.collier(i, s, hc, false)
		c.compte["conduites"] += 1
	if cables:
		# Un à trois câbles, accrochés sous l'arête tous les une ou deux cases, chacun sa flèche : un faisceau.
		var nombre := 1 + int(tirage(h, 3) * 3.0)
		var portee := tuile * (1.0 if tirage(h, 4) < 0.4 else 2.0)
		# Les crochets à un rayon de câble en deçà des bouts : l'anneau d'un câble en pente déborde le long de la face de
		# `rayon × sin(pente)`.
		var c0 := s0 + RAYON_CABLE
		var c1 := s1 - RAYON_CABLE
		var travees := maxi(1, roundi((c1 - c0) / portee))
		var pas := (c1 - c0) / float(travees)
		var plafond := h_max - RAYON_CABLE - 0.3
		var morceaux := maxi(2, ceili(pas / PAS_CABLE))
		for k in nombre:
			var accroche := plafond - 1.5 * float(k)
			var fleche := pas * (0.07 + 0.05 * tirage(h, 5 + k)) + 0.8 * float(k)
			if conduite:
				fleche = minf(fleche, accroche - hc - RAYON_COLLIER - 1.5)
			fleche = maxf(fleche, 0.0)
			var ecart_cable := JOUR + RAYON_CABLE + 0.35 * float(k % 2)
			var points: Array[Vector3] = []
			for t in travees:
				var a := c0 + pas * float(t)
				for m in morceaux + (1 if t == travees - 1 else 0):
					var u := float(m) / float(morceaux)
					# La chaînette approchée par une parabole : 0 aux crochets, la flèche au milieu.
					points.append(point(f, a + pas * u, accroche - 4.0 * fleche * u * (1.0 - u), ecart_cable))
			c.tube(i, points, RAYON_CABLE, COTES_CABLE, ALBEDO_CABLE, false)
			c.compte["cables"] += 1


static func point(f: Dictionary, s: float, y: float, ecart: float) -> Vector3:
	return Chantier.point(f, s, y, ecart)


## Le maillage fusionné d'une construction : UNE surface. `null` si la carte n'a aucune face à meubler.
static func maillage(c: Dictionary) -> ArrayMesh:
	if (c["sommets"] as PackedVector3Array).is_empty():
		return null
	var tableaux := []
	tableaux.resize(Mesh.ARRAY_MAX)
	tableaux[Mesh.ARRAY_VERTEX] = c["sommets"]
	tableaux[Mesh.ARRAY_NORMAL] = c["normales"]
	tableaux[Mesh.ARRAY_TEX_UV] = c["uv"]
	tableaux[Mesh.ARRAY_TEX_UV2] = c["uv2"]
	tableaux[Mesh.ARRAY_INDEX] = c["indices"]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
	return m


## Le nœud de la carte `data` : un `MeshInstance3D` sans ombre, sur le calque commun aux deux caméras. `null` si rien.
static func creer_noeud(data: Dictionary, materiau: Material) -> MeshInstance3D:
	var m := maillage(construire(data))
	if m == null:
		return null
	var noeud := MeshInstance3D.new()
	noeud.name = NOM_NOEUD
	noeud.mesh = m
	noeud.material_override = materiau
	noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	noeud.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	noeud.layers = 1
	return noeud


## Le matériau : la lecture de la face, réglée comme celle des murs (`IsoMateriaux.accorder_mur`) — même pied, même
## contact, même température, même plancher d'encre —, plus ce qui n'est qu'aux tuyaux. Sans beauté, comme un mur d'ISO1 :
## ni contact, ni température.
static func accorder(materiau: ShaderMaterial) -> void:
	var active := IsoMateriaux.beaute_active()
	materiau.set_shader_parameter("pied", IsoMateriaux.PIED_FACE_PX)
	materiau.set_shader_parameter("seuil_face", SEUIL_FACE)
	materiau.set_shader_parameter("corps_sombre", CORPS_SOMBRE)
	materiau.set_shader_parameter("encre_reste", ENCRE_RESTE)
	materiau.set_shader_parameter("matiere_max", matiere_max())
	materiau.set_shader_parameter("encre_plancher_affiche", IsoMateriaux.ENCRE_PLANCHER_AFFICHE)
	materiau.set_shader_parameter("contact_px", IsoMateriaux.CONTACT_PX if active else 0.0)
	materiau.set_shader_parameter("contact_reste", IsoMateriaux.CONTACT_RESTE)
	materiau.set_shader_parameter("temperature", IsoMateriaux.TEMPERATURE_GRADUEE if active else 0.0)
	materiau.set_shader_parameter("temperature_seuil_bas", IsoMateriaux.TEMPERATURE_SEUIL_BAS)
	materiau.set_shader_parameter("temperature_seuil_haut", IsoMateriaux.TEMPERATURE_SEUIL_HAUT if active else 0.0)
	materiau.set_shader_parameter("neutre_avant_pate", 1.0 if active else 0.0)
	# L'instrument de la planche (l'emprise des tuyaux en blanc) : jamais en jeu.
	materiau.set_shader_parameter("emprise_preuve", false)
