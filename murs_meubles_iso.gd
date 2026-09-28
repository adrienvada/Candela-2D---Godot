## MursMeublesIso — les murs meublés de la vue isométrique, EN ESSAI (`--murs-meubles-essai`, éteint par défaut).
##
## ## Pourquoi
##
## Onze illustrations des menus montrent des murs bien plus meublés que le jeu : portes d'acier rivetées (`ill_intro_seuil`,
## `ill_quitter`), boîtiers et tableaux électriques (`ill_amical`, `ill_competitif`), grilles (`ill_accueil`,
## `ill_amical_ligne`), faisceaux de câbles serrés tenus par des étriers (`ill_rejoindre_ligne`, `ill_creer_ligne`). C'est le
## manque n° 4 de l'évaluation de l'écart aux illustrations ; le relevé complet, illustration par illustration, est dans
## `docs/iso/cloud/murs-meubles/RAPPORT.md`. Il s'ajoute EN ESSAI, derrière un drapeau, sur le modèle des enseignes : rien ne
## s'allume en jeu avant l'avis d'Adrien et la mesure de cadence au Mac.
##
## ## Quatre familles, quatre maillages, quatre matériaux — et aucun shader nouveau
##
## - **les portes** et **les grilles** : des quadrilatères plats collés à la face (0,25 px), texturés par un atlas dessiné
##   ici, lus par le shader des enseignes (`enseignes_iso.gdshader`, tel quel) ;
## - **les boîtiers** (interrupteur, coffret, tableau) et **les faisceaux** de câbles : des volumes (boîtes, tubes, étriers),
##   lus par le shader des tuyaux (`tuyaux_iso.gdshader`, tel quel).
## Un maillage fusionné par carte et par famille, un matériau par famille : un appel de dessin de plus par vue et par famille
## au plus. Les deux shaders ont déjà leurs preuves (`tools/test_iso_enseignes.gd`, `tools/test_iso_tuyaux.gd`) : chaque
## fragment relit la lumière du pixel de FACE qu'il recouvre à l'écran et ne fait que la MULTIPLIER par un facteur plafonné
## par la matière la plus sombre qu'une face puisse porter (`TuyauxIso.matiere_max`). D'où, par construction : noir hors de la
## lumière, jamais plus clair que la face qui porte l'objet (la règle des pochoirs).
##
## ## Les garde-fous (prouvés par `tools/test_iso_murs_meubles.gd`)
##
## - **L'équité.** Une TABLE ÉCRITE À LA MAIN par carte livrée (`TABLE`, comme `ArenaDecor.POCHOIRS_ESSAI`) : un
##   représentant par orbite. Ses jumeaux sont ses images par le groupe de la carte (`EnseignesIso.groupe` : la symétrie qui
##   échange les départs, et le demi-tour de l'option B, où J2 regarde de l'autre côté). Un objet dont une image ne tombe pas
##   sur une face exposée est REFUSÉ tout entier, avec ses jumeaux (`refus`), et la garde exige zéro refus : aucun objet
##   n'existe sans son jumeau. Les atlas sont symétriques gauche-droite : l'image miroir d'une porte EST la même porte.
## - **Rien qui cache un joueur.** Aucune collision, aucun occluder, aucune ombre. Rien au-dessus de l'arête (moins la
##   saillie vue sous le tangage), rien sur la bande de sol, rien à moins de la marge des bouts d'une face ; un objet ne se
##   dessine que pour une caméra qui voit sa face de face (le tri des deux shaders). Aucun objet n'en chevauche un autre ni
##   une enseigne sur la même face.
## - **Le hasard sans hasard.** Aucun tirage : les atlas sont tirés d'un hachage entier (`TuyauxIso.hacher`).
##
## Repère : celui d'`IsoGeometrie` (et des tuyaux) — le monde 3D en pixels du monde 2D, `x` → `x`, `y` → `z`, sol à `y = 0`.
class_name MursMeublesIso
extends RefCounted

const DRAPEAU_MURS_MEUBLES_ESSAI := "--murs-meubles-essai"
const TuyauxIsoT := preload("res://tuyaux_iso.gd")
const EnseignesIsoT := preload("res://enseignes_iso.gd")
const SHADER_PLAT := preload("res://enseignes_iso.gdshader")
const SHADER_VOLUME := preload("res://tuyaux_iso.gdshader")
const PREFIXE_NOEUD := "MursMeubles_"

## Les familles, dans l'ordre des nœuds. Plates : lues par le shader des enseignes ; en volume : par celui des tuyaux.
const FAMILLES: Array[String] = ["portes", "grilles", "boitiers", "faisceaux"]
const PLATES: Array[String] = ["portes", "grilles"]

## LA TABLE, écrite à la main à partir des faces exposées de chaque carte livrée (clé : l'`id` de la carte). Une entrée :
## [famille, face, x, y, décalage, variante] — `(x, y)` la case de MUR (sans la ceinture) qui porte l'objet, `face` le côté
## exposé (« S », « N », « E », « O »), `décalage` le centre de l'objet à partir du centre de la case, en cases, le long de
## l'axe du monde (x pour une face S/N, y pour une face E/O : un décalage de 0,5 pose l'objet à cheval sur deux cases, là
## où son jumeau miroir tombe souvent sur lui-même). Variante : porte 0 pleine rivetée, 1 à barreaux ; grille 0 à lames ;
## boîtier 0 interrupteur, 1 coffret, 2 tableau à deux portes ; faisceau : sa longueur en cases.
## Un représentant par orbite : ses jumeaux sont calculés (`objets`). Choisis loin des enseignes, des bouts de face et les uns
## des autres ; la garde vérifie chaque image.
const TABLE := {
	# La carte par défaut : les quatre murs d'enceinte, seules faces de la carte (26 cases). « ARENA » au milieu de S et N.
	"00000001": [
		["porte", "S", 9, 2, 0.0, 0],
		["faisceau", "S", 6, 2, 0.0, 4],
		["grille", "S", 12, 2, 0.0, 0],
		["boitier", "S", 13, 2, 0.5, 1],
		["boitier", "E", 2, 15, 0.5, 2],
		["faisceau", "E", 2, 6, 0.5, 6],
		["porte", "E", 2, 11, 0.0, 1],
		["boitier", "E", 2, 13, 0.0, 0],
	],
	# Le Cloître : enceinte, blocs 3 × 3 aux quatre coins du centre, le long bloc central (6 cases).
	"map_001": [
		["porte", "S", 14, 2, 0.5, 0],
		["faisceau", "S", 6, 2, 0.5, 6],
		["grille", "S", 11, 2, 0.0, 0],
		["boitier", "S", 10, 20, 0.0, 1],
		["boitier", "E", 15, 14, 0.5, 2],
		["faisceau", "E", 2, 7, 0.5, 6],
		["porte", "E", 2, 14, 0.5, 1],
		["boitier", "E", 11, 10, 0.0, 0],
	],
	# L'Usine : ses murs ne sont symétriques que haut-bas ; seules les faces dont l'image gauche-droite est aussi exposée
	# portent quelque chose (l'enceinte, les blocs latéraux).
	"map_002": [
		["porte", "S", 15, 2, 0.5, 0],
		["faisceau", "S", 6, 2, 0.5, 6],
		["grille", "S", 11, 2, 0.0, 0],
		["boitier", "E", 9, 7, 0.5, 1],
		["faisceau", "E", 2, 6, 0.5, 6],
		["boitier", "E", 2, 12, 0.5, 2],
		["boitier", "S", 8, 19, 0.5, 0],
	],
	# La Croisée : son groupe n'a que le demi-tour (il échange les départs, en diagonale).
	"map_003": [
		["porte", "S", 10, 2, 0.0, 0],
		["porte", "S", 17, 2, 0.0, 1],
		["faisceau", "S", 6, 2, 0.0, 5],
		["grille", "S", 13, 2, 0.0, 0],
		["faisceau", "E", 2, 8, 0.5, 6],
		["boitier", "E", 2, 16, 0.0, 1],
		["boitier", "S", 8, 20, 0.5, 2],
		["boitier", "E", 15, 13, 0.5, 0],
		["grille", "N", 8, 18, 0.5, 0],
	],
	# Le Bunker : enceinte, les deux longs murs du centre (8 et 10 cases), les blocs latéraux.
	"map_004": [
		["faisceau", "S", 12, 8, 0.5, 6],
		["porte", "S", 9, 17, 0.0, 0],
		["boitier", "S", 12, 17, 0.5, 2],
		["porte", "S", 6, 2, 0.0, 1],
		["faisceau", "S", 12, 2, 0.5, 6],
		["grille", "S", 8, 2, 0.0, 0],
		["boitier", "E", 2, 9, 0.0, 1],
		["boitier", "E", 17, 9, 0.0, 0],
		["faisceau", "E", 2, 12, 0.5, 6],
	],
	# L'Arène circulaire : l'enceinte (20 cases) et le petit bloc du centre.
	"00000002": [
		["porte", "S", 6, 1, 0.0, 0],
		["faisceau", "S", 11, 1, 0.5, 6],
		["grille", "S", 4, 1, 0.0, 0],
		["boitier", "E", 1, 8, 0.0, 1],
		["boitier", "E", 1, 11, 0.5, 2],
		["faisceau", "E", 1, 4, 0.5, 4],
		["boitier", "S", 11, 15, 0.5, 0],
	],
}

const NORMALES := {"S": Vector2(0, 1), "N": Vector2(0, -1), "E": Vector2(1, 0), "O": Vector2(-1, 0)}

## Les mesures, en pixels du monde (la tuile fait 35 px, le mur 43,75 de haut ; le mannequin à peu près la hauteur du mur).
## Les objets plats : collés à 0,25 px, sous le jour des tuyaux (0,5) et au ras des enseignes (0,2-0,3).
const ECART_PLAT := 0.25
## La porte : les deux tiers d'une case de large, les quatre cinquièmes du mur de haut, posée sur la bande de sol.
const PORTE := Vector2(21.0, 33.0)
## La grille : un petit rectangle haut placé, sous l'arête.
const GRILLE := Vector2(16.0, 10.0)
const HAUTEUR_GRILLE := 0.70
## Les boîtiers, par variante : largeur, hauteur, épaisseur, et le centre en fraction de la hauteur du mur.
const BOITIERS := [
	[5.0, 7.0, 1.5, 0.52],
	[9.0, 12.0, 2.5, 0.55],
	[20.0, 22.0, 3.0, 0.56],
]
## Le jour entre la face et un volume (celui des tuyaux : sans lui, le dos se battrait avec la face dans la profondeur).
const JOUR := TuyauxIsoT.JOUR
## Le faisceau : sept câbles jointifs, un étrier par case et un à chaque bout, une flèche d'un pixel et demi entre deux.
const CABLES := 7
const RAYON_CABLE := 0.55
const PAS_CABLES := 1.2
const HAUTEUR_FAISCEAU := 0.80
const FLECHE := 1.5
const LARGEUR_ETRIER := 1.4
const COTES_CABLE := 4
const MORCEAUX_TRAVEE := 3
## Le conduit qui descend d'un boîtier jusqu'au bas de la face.
const RAYON_CONDUIT := 0.7

## La saillie la plus forte de chaque famille devant sa face (px) : les bornes (arête, sol, bouts) s'en déduisent.
const SAILLIES := {"portes": ECART_PLAT, "grilles": ECART_PLAT, "boitiers": JOUR + 3.0 + 0.4,
	"faisceaux": JOUR + 2.0 * RAYON_CABLE + 0.35 + 0.6}
## Les facteurs de matière des volumes (≤ 1, et plafonnés par `matiere_max` dans le shader) : la tôle, les poignées, le
## caoutchouc, le fer des étriers.
const ALBEDO_BOITIER := 1.0
const ALBEDO_DETAIL := 0.6
const ALBEDO_CABLE := 0.6
const ALBEDO_ETRIER := 0.5
## Le modelé des boîtiers : leurs faces planes ne se tournent jamais pleinement vers la caméra (le reflet des tuyaux ne s'y
## allume pas) ; un corps moins encré qu'un tuyau garde la façade lisible, le contour des côtés reste. Celui des faisceaux
## est celui des tuyaux (des tubes).
const CORPS_SOMBRE_BOITIERS := 0.35

## L'atlas des objets plats : R le facteur (≤ 1), A la présence (0 : le mur seul). Deux texels par pixel du monde.
const TEXELS_PAR_PX := 2
const TAILLE_ATLAS := Vector2i(128, 128)
## [taille en px du monde, origine dans l'atlas] de chaque motif.
const MOTIFS := {
	"porte0": [PORTE, Vector2i(0, 0)],
	"porte1": [PORTE, Vector2i(46, 0)],
	"grille0": [GRILLE, Vector2i(0, 70)],
}
## Les facteurs de l'atlas, TOUS ≤ 0,70.
const TOLE := 0.62
const CHAMBRANLE := 0.42
const BANDE := 0.50
const RIVET_F := 0.24
const JOINT := 0.30
const ROUILLE_F := 0.80
const BARREAU := 0.58
const FOND_GRILLE := 0.12
const LAME := 0.60


static func essai_actif() -> bool:
	return OS.get_cmdline_user_args().has(DRAPEAU_MURS_MEUBLES_ESSAI)


static func est_plate(famille: String) -> bool:
	return PLATES.has(famille)


## La famille d'une entrée de la table (« porte » → « portes »).
static func famille_de(sorte: String) -> String:
	return {"porte": "portes", "grille": "grilles", "boitier": "boitiers", "faisceau": "faisceaux"}[sorte]


# ---------------------------------------------------------------------------
# LES BORNES — par famille
# ---------------------------------------------------------------------------

static func hauteur_mur_px() -> float:
	return TuyauxIsoT.hauteur_mur_px()


## Le plus haut qu'un sommet monte : l'arête, moins ce que la saillie laisse voir derrière le mur sous le tangage.
static func hauteur_max_px(famille: String) -> float:
	return hauteur_mur_px() - float(SAILLIES[famille]) * tan(deg_to_rad(CameraIso.TANGAGE_DEG))


## Le plus bas : au-dessus, même vu à 60° de biais, l'objet ne recouvre à l'écran que sa face, jamais le sol à son pied
## (la règle des tuyaux et des enseignes).
static func hauteur_bas_px(famille: String) -> float:
	return float(SAILLIES[famille]) * tan(deg_to_rad(CameraIso.TANGAGE_DEG)) / TuyauxIsoT.SEUIL_FACE + 2.0


## La marge aux bouts d'une face : ce que la saillie glisse à 60° de biais, plus l'encre des arêtes verticales (la marge
## des enseignes).
static func marge_bout(famille: String) -> float:
	return float(SAILLIES[famille]) * tan(deg_to_rad(60.0)) + EnseignesIsoT.MARGE_BOUT


## L'emprise d'un objet sur sa face : [demi-largeur le long de la face, bas, haut], en px.
static func emprise(famille: String, variante: int) -> Array[float]:
	var h_mur := hauteur_mur_px()
	match famille:
		"portes":
			var bas := hauteur_bas_px(famille)
			return [PORTE.x * 0.5, bas, bas + PORTE.y]
		"grilles":
			var c := h_mur * HAUTEUR_GRILLE
			return [GRILLE.x * 0.5, c - GRILLE.y * 0.5, c + GRILLE.y * 0.5]
		"boitiers":
			var b: Array = BOITIERS[variante]
			var cb := h_mur * float(b[3])
			# Le conduit descend du boîtier jusqu'au bas permis.
			return [float(b[0]) * 0.5, hauteur_bas_px(famille), cb + float(b[1]) * 0.5]
		_:
			var cf := h_mur * HAUTEUR_FAISCEAU
			var demi := (float(CABLES - 1) * PAS_CABLES) * 0.5 + RAYON_CABLE + 1.0
			var tuile := float(CandelaTileSet.TILE_SIZE.x)
			return [float(variante) * tuile * 0.5 - marge_bout(famille), cf - demi - FLECHE, cf + demi]


# ---------------------------------------------------------------------------
# LE PLACEMENT — la table, et ses images par le groupe
# ---------------------------------------------------------------------------

## Les objets de la carte `data` : `{famille, variante, face, s, n, d, orbite}` pour chacun, jumeaux compris ; les entrées
## refusées (une image hors d'une face exposée, trop près d'un bout, ou sur un autre objet) dans `refus`, avec la raison.
static func construire(data: Dictionary) -> Dictionary:
	var faces := TuyauxIsoT.faces(data)
	var taille := EnseignesIsoT.cases_carte(data)
	var tuile := float(CandelaTileSet.TILE_SIZE.x)
	var dim := Vector2(taille) * tuile
	var grp := EnseignesIsoT.groupe(data)
	var objets: Array[Dictionary] = []
	var refus: Array[String] = []
	var entrees: Array = TABLE.get(String(data.get("id", "")), [])
	# Les rectangles déjà pris, par face : les enseignes d'abord (quand la carte en porte), puis chaque objet posé.
	var pris := {}
	var ens: Dictionary = EnseignesIsoT.construire(data)
	for e in ens["enseignes"]:
		var t := EnseignesIsoT.taille_px(e["sorte"])
		_prendre(pris, int(e["face"]), [float(e["s"]) - t.x * 0.5, float(e["y"]) - t.y * 0.5,
			float(e["s"]) + t.x * 0.5, float(e["y"]) + t.y * 0.5])
	for k in entrees.size():
		var entree: Array = entrees[k]
		var famille := famille_de(String(entree[0]))
		var variante := int(entree[5])
		var n: Vector2 = NORMALES[String(entree[1])]
		var axe := Vector2(1, 0) if absf(n.y) > 0.5 else Vector2(0, 1)
		var centre := (Vector2(float(entree[2]), float(entree[3])) + Vector2(0.5, 0.5)) * tuile
		var p := centre + n * tuile * 0.5 + axe * float(entree[4]) * tuile
		var em := emprise(famille, variante)
		var marge := marge_bout(famille)
		var poses: Array[Dictionary] = []
		var vus := {}
		var raison := ""
		for s in grp:
			var ni := EnseignesIsoT.normale_image(n, s)
			var pi := EnseignesIsoT.point_image(p, s, dim)
			var cle := "%d,%d|%d,%d" % [roundi(ni.x), roundi(ni.y), roundi(pi.x * 4.0), roundi(pi.y * 4.0)]
			if vus.has(cle):
				continue
			vus[cle] = true
			var i := _face_de(faces, ni, pi)
			if i < 0:
				raison = "image %d hors d'une face exposée" % s
				break
			var f: Dictionary = faces[i]
			var sc := pi.dot(Vector2(-ni.y, ni.x))
			if sc - em[0] < float(f["s0"]) + marge - 0.001 or sc + em[0] > float(f["s1"]) - marge + 0.001:
				raison = "image %d trop près d'un bout de sa face" % s
				break
			poses.append({"famille": famille, "variante": variante, "face": i, "s": sc, "n": ni, "d": float(f["d"]),
				"orbite": k})
		if raison == "":
			for o in poses:
				var r := [float(o["s"]) - em[0], em[1], float(o["s"]) + em[0], em[2]]
				if _chevauche(pris, int(o["face"]), r):
					raison = "image sur un objet ou une enseigne déjà posés"
					break
		if raison != "":
			refus.append("%s : %s" % [str(entree), raison])
			continue
		for o in poses:
			_prendre(pris, int(o["face"]), [float(o["s"]) - em[0], em[1], float(o["s"]) + em[0], em[2]])
			objets.append(o)
	return {"faces": faces, "objets": objets, "refus": refus, "groupe": grp, "taille_px": dim}


static func _face_de(faces: Array[Dictionary], n: Vector2, p: Vector2) -> int:
	var t := Vector2(-n.y, n.x)
	for i in faces.size():
		var f: Dictionary = faces[i]
		if (f["n"] as Vector2) != n or absf(p.dot(n) - float(f["d"])) > 0.01:
			continue
		var s := p.dot(t)
		if s >= float(f["s0"]) and s <= float(f["s1"]):
			return i
	return -1


static func _prendre(pris: Dictionary, face: int, r: Array) -> void:
	if not pris.has(face):
		pris[face] = []
	(pris[face] as Array).append(r)


static func _chevauche(pris: Dictionary, face: int, r: Array) -> bool:
	for q in pris.get(face, []):
		if r[0] < q[2] and q[0] < r[2] and r[1] < q[3] and q[1] < r[3]:
			return true
	return false


# ---------------------------------------------------------------------------
# L'ATLAS DES OBJETS PLATS — symétrique gauche-droite : l'image miroir d'une porte est la même porte
# ---------------------------------------------------------------------------

static func rect_atlas(motif: String) -> Rect2i:
	var m: Array = MOTIFS[motif]
	return Rect2i(m[1], Vector2i((m[0] as Vector2) * float(TEXELS_PAR_PX)))


static func atlas_image() -> Image:
	var img := Image.create(TAILLE_ATLAS.x, TAILLE_ATLAS.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	_dessiner_porte(img, rect_atlas("porte0"), false)
	_dessiner_porte(img, rect_atlas("porte1"), true)
	_dessiner_grille(img, rect_atlas("grille0"))
	return img


## Un hachage symétrique : même valeur en `x` et en son miroir `w − 1 − x`.
static func _tache(w: int, x: int, y: int, graine: int) -> float:
	var xs := mini(x, w - 1 - x)
	return TuyauxIsoT.tirage(TuyauxIsoT.hacher([graine, xs / 3, y / 3]), 0)


static func _dessiner_porte(img: Image, r: Rect2i, barreaux: bool) -> void:
	var w := r.size.x
	var h := r.size.y
	for y in h:
		for x in w:
			var xs := mini(x, w - 1 - x)
			var ys := y
			var f := TOLE
			var chambranle := xs < 3 or ys < 3
			if chambranle:
				f = CHAMBRANLE
			elif barreaux:
				# Des barreaux verticaux tous les cinq texels, une traverse au milieu : entre eux, le noir de derrière.
				var dans_traverse := absi(ys - h / 2) <= 1 or ys >= h - 4
				f = BARREAU if dans_traverse or (xs - 3) % 5 < 2 else FOND_GRILLE
			else:
				# Le joint des deux battants, deux bandes rivetées, la tôle.
				if xs == (w - 1) / 2:
					f = JOINT
				var bande := absi(ys - h / 3) <= 1 or absi(ys - 2 * h / 3) <= 1
				if bande:
					f = BANDE
				if (absi(ys - h / 3) == 0 or absi(ys - 2 * h / 3) == 0) and (xs - 5) % 6 == 0:
					f = RIVET_F
			# Les rivets du chambranle, tous les six texels.
			if chambranle and xs == 1 and ys % 6 == 3:
				f = RIVET_F
			if chambranle and ys == 1 and xs % 6 == 3:
				f = RIVET_F
			# La rouille : en taches, plus dense en bas et aux bords.
			var pres := float(ys) / float(h)
			if _tache(w, x, y, 17 if barreaux else 11) < 0.10 + 0.25 * pres * pres:
				f *= ROUILLE_F
			_poser(img, r.position + Vector2i(x, y), f)


static func _dessiner_grille(img: Image, r: Rect2i) -> void:
	var w := r.size.x
	var h := r.size.y
	for y in h:
		for x in w:
			var xs := mini(x, w - 1 - x)
			var ys := mini(y, h - 1 - y)
			var f := LAME if (y - 2) % 4 < 2 else FOND_GRILLE
			if xs < 2 or ys < 2:
				f = CHAMBRANLE
			if xs == 1 and ys == 1:
				f = RIVET_F
			if _tache(w, x, y, 23) < 0.12:
				f *= ROUILLE_F
			_poser(img, r.position + Vector2i(x, y), f)


static func _poser(img: Image, p: Vector2i, facteur: float) -> void:
	img.set_pixelv(p, Color(clampf(facteur, 0.0, 1.0), 0.0, 0.0, 1.0))


static func atlas_texture() -> ImageTexture:
	var img := atlas_image()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------------------
# LES MAILLAGES — un par famille
# ---------------------------------------------------------------------------

## Le point à l'abscisse `s` le long de la face (plan `d`, normale `n`), à la hauteur `y`, à `ecart` devant elle.
static func point(n: Vector2, d: float, s: float, y: float, ecart: float) -> Vector3:
	var p := n * (d + ecart) + Vector2(-n.y, n.x) * s
	return Vector3(p.x, y, p.y)


## Les tableaux d'une famille plate (le format des enseignes : UV l'atlas, UV2 la normale, CUSTOM0.x le plan).
static func tableaux_plats(c: Dictionary, famille: String) -> Array:
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var plan := PackedFloat32Array()
	var indices := PackedInt32Array()
	for o in c["objets"]:
		if o["famille"] != famille:
			continue
		var n: Vector2 = o["n"]
		var d: float = o["d"]
		var em := emprise(famille, int(o["variante"]))
		var motif := ("porte%d" % int(o["variante"])) if famille == "portes" else "grille0"
		var r := rect_atlas(motif)
		var u0 := Vector2(r.position) / Vector2(TAILLE_ATLAS)
		var u1 := Vector2(r.end) / Vector2(TAILLE_ATLAS)
		var centre := n * (d + ECART_PLAT) + Vector2(-n.y, n.x) * float(o["s"])
		var droite := EnseignesIsoT.axe_lecture(n) * em[0]
		var g := centre - droite
		var dr := centre + droite
		var q: Array[Vector3] = [Vector3(g.x, em[2], g.y), Vector3(dr.x, em[2], dr.y), Vector3(dr.x, em[1], dr.y),
			Vector3(g.x, em[1], g.y)]
		var coins_uv: Array[Vector2] = [u0, Vector2(u1.x, u0.y), u1, Vector2(u0.x, u1.y)]
		var base := sommets.size()
		for k in 4:
			sommets.append(q[k])
			normales.append(Vector3(n.x, 0.0, n.y))
			uv.append(coins_uv[k])
			uv2.append(n)
			plan.append_array(PackedFloat32Array([d, 0.0, 0.0, 0.0]))
		# Horaire vu de face : l'enroulement des enseignes.
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


## Un volume en chantier : les tableaux du format des tuyaux (UV.x le plan, UV.y la matière, UV2 la normale de la face).
class Volume:
	extends RefCounted
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var indices := PackedInt32Array()

	func ajouter(n: Vector2, d: float, p: Vector3, normale: Vector3, albedo: float) -> void:
		sommets.append(p)
		normales.append(normale)
		uv.append(Vector2(d, albedo))
		uv2.append(n)

	## Un quadrilatère plan a-b-c-d de normale sortante `normale`, orienté comme les faces d'une `BoxMesh` (horaire vu de
	## dehors : le produit (b − a) × (c − a) opposé à la normale).
	func quad(n: Vector2, d: float, q: Array[Vector3], normale: Vector3, albedo: float) -> void:
		var base := sommets.size()
		for p in q:
			ajouter(n, d, p, normale, albedo)
		if (q[1] - q[0]).cross(q[2] - q[0]).dot(normale) > 0.0:
			indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))
		else:
			indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))

	## Une boîte posée contre la face : centrée en `s` le long d'elle, de `bas` à `haut`, de `e0` à `e1` devant elle. Cinq
	## faces (le dos, contre le mur, ne se voit jamais).
	func boite(n: Vector2, d: float, s: float, demi: float, bas: float, haut: float, e0: float, e1: float,
			albedo: float) -> void:
		var t3 := Vector3(-n.y, 0.0, n.x)
		var n3 := Vector3(n.x, 0.0, n.y)
		var up := Vector3.UP
		var p := func(ds: float, y: float, e: float) -> Vector3:
			var q := n * (d + e) + Vector2(-n.y, n.x) * (s + ds)
			return Vector3(q.x, y, q.y)
		quad(n, d, [p.call(-demi, bas, e1), p.call(demi, bas, e1), p.call(demi, haut, e1), p.call(-demi, haut, e1)],
			n3, albedo)
		quad(n, d, [p.call(-demi, haut, e0), p.call(demi, haut, e0), p.call(demi, haut, e1), p.call(-demi, haut, e1)],
			up, albedo)
		quad(n, d, [p.call(-demi, bas, e0), p.call(demi, bas, e0), p.call(demi, bas, e1), p.call(-demi, bas, e1)],
			-up, albedo)
		quad(n, d, [p.call(demi, bas, e0), p.call(demi, haut, e0), p.call(demi, haut, e1), p.call(demi, bas, e1)],
			t3, albedo)
		quad(n, d, [p.call(-demi, bas, e0), p.call(-demi, haut, e0), p.call(-demi, haut, e1), p.call(-demi, bas, e1)],
			-t3, albedo)

	## Un tube le long d'une polyligne, à `cotes` côtés, orienté par la normale de la face (le tube des tuyaux).
	func tube(n: Vector2, d: float, points: Array[Vector3], rayon: float, cotes: int, albedo: float) -> void:
		var u := Vector3(n.x, 0.0, n.y)
		var base := sommets.size()
		for k in points.size():
			var direction := (points[mini(k + 1, points.size() - 1)] - points[maxi(k - 1, 0)]).normalized()
			var v := direction.cross(u).normalized()
			for j in cotes:
				var a := TAU * float(j) / float(cotes)
				var radiale := u * cos(a) + v * sin(a)
				ajouter(n, d, points[k] + radiale * rayon, radiale, albedo)
		for k in points.size() - 1:
			for j in cotes:
				var a0 := base + k * cotes + j
				var a1 := base + k * cotes + (j + 1) % cotes
				var b0 := a0 + cotes
				var b1 := a1 + cotes
				indices.append_array(PackedInt32Array([a0, b0, a1, a1, b0, b1]))


## Les tableaux d'une famille en volume.
static func tableaux_volume(c: Dictionary, famille: String) -> Array:
	var v := Volume.new()
	var h_mur := hauteur_mur_px()
	for o in c["objets"]:
		if o["famille"] != famille:
			continue
		var n: Vector2 = o["n"]
		var d: float = o["d"]
		var s: float = o["s"]
		var variante: int = o["variante"]
		if famille == "boitiers":
			_boitier(v, n, d, s, variante, h_mur)
		else:
			_faisceau(v, n, d, s, variante, h_mur)
	var t := []
	t.resize(Mesh.ARRAY_MAX)
	t[Mesh.ARRAY_VERTEX] = v.sommets
	t[Mesh.ARRAY_NORMAL] = v.normales
	t[Mesh.ARRAY_TEX_UV] = v.uv
	t[Mesh.ARRAY_TEX_UV2] = v.uv2
	t[Mesh.ARRAY_INDEX] = v.indices
	return t


## Un boîtier : la boîte, un détail en façade (un levier, une poignée, le joint et les poignées des deux portes du tableau),
## et un conduit qui descend jusqu'au bas de la face.
static func _boitier(v: Volume, n: Vector2, d: float, s: float, variante: int, h_mur: float) -> void:
	var b: Array = BOITIERS[variante]
	var demi := float(b[0]) * 0.5
	var c := h_mur * float(b[3])
	var bas := c - float(b[1]) * 0.5
	var haut := c + float(b[1]) * 0.5
	var e1 := JOUR + float(b[2])
	v.boite(n, d, s, demi, bas, haut, JOUR, e1, ALBEDO_BOITIER)
	match variante:
		0:
			# Le levier de l'interrupteur.
			v.boite(n, d, s, 0.6, c - 0.4, c + 1.6, e1, e1 + 0.4, ALBEDO_DETAIL)
		1:
			# La poignée du coffret : une barre en haut de la porte, d'un bord à l'autre (un coffret symétrique).
			v.boite(n, d, s, demi - 1.0, haut - 1.6, haut - 1.0, e1, e1 + 0.3, ALBEDO_DETAIL)
		2:
			# Le joint des deux portes, et leurs deux poignées.
			v.boite(n, d, s, 0.35, bas + 1.0, haut - 1.0, e1, e1 + 0.3, ALBEDO_DETAIL)
			v.boite(n, d, s - 2.0, 0.4, c - 2.0, c + 2.0, e1, e1 + 0.4, ALBEDO_DETAIL)
			v.boite(n, d, s + 2.0, 0.4, c - 2.0, c + 2.0, e1, e1 + 0.4, ALBEDO_DETAIL)
	# Le conduit : du dessous du boîtier jusqu'au bas permis (deux pour le tableau), une gaine dans le mur.
	var pied := hauteur_bas_px("boitiers")
	var decalages: Array[float] = [0.0]
	if variante == 2:
		decalages = [-demi * 0.5, demi * 0.5]
	for ds in decalages:
		var axe: Array[Vector3] = [point(n, d, s + ds, pied, JOUR + RAYON_CONDUIT),
			point(n, d, s + ds, bas, JOUR + RAYON_CONDUIT)]
		v.tube(n, d, axe, RAYON_CONDUIT, 4, ALBEDO_CABLE)


## Un faisceau : `CABLES` câbles jointifs en nappe horizontale, d'une longueur de `cases` cases moins les marges ; un étrier
## à chaque bout et un par case ; entre deux étriers, la nappe fléchit de `FLECHE`.
static func _faisceau(v: Volume, n: Vector2, d: float, s: float, cases: int, h_mur: float) -> void:
	var em := emprise("faisceaux", cases)
	var s0 := s - em[0]
	var s1 := s + em[0]
	var cf := h_mur * HAUTEUR_FAISCEAU
	var tuile := float(CandelaTileSet.TILE_SIZE.x)
	var travees := maxi(1, roundi((s1 - s0) / tuile))
	var pas := (s1 - s0) / float(travees)
	var demi_nappe := float(CABLES - 1) * PAS_CABLES * 0.5
	for k in CABLES:
		var y0 := cf + demi_nappe - float(k) * PAS_CABLES
		# Un câble sur deux un peu plus avant : la nappe a du relief sans épaisseur.
		var e := JOUR + RAYON_CABLE + 0.35 * float(k % 2)
		var points: Array[Vector3] = []
		for t in travees:
			for m in MORCEAUX_TRAVEE + (1 if t == travees - 1 else 0):
				var u := float(m) / float(MORCEAUX_TRAVEE)
				points.append(point(n, d, s0 + pas * (float(t) + u), y0 - 4.0 * FLECHE * u * (1.0 - u), e))
		v.tube(n, d, points, RAYON_CABLE, COTES_CABLE, ALBEDO_CABLE)
	# Les étriers : un plat de fer vertical par-dessus la nappe, aux bouts (ils cachent le bout ouvert des câbles) et à chaque
	# case.
	var e_fer := JOUR + 2.0 * RAYON_CABLE + 0.35
	for t in travees + 1:
		var se := s0 + pas * float(t)
		var ds := LARGEUR_ETRIER * 0.5
		se = clampf(se, s0 + ds, s1 - ds)
		v.boite(n, d, se, ds, cf - demi_nappe - RAYON_CABLE - 1.0, cf + demi_nappe + RAYON_CABLE + 1.0, JOUR, e_fer + 0.6,
			ALBEDO_ETRIER)


## Le maillage d'une famille : UNE surface, `null` si la carte n'en porte aucun objet.
static func maillage(c: Dictionary, famille: String) -> ArrayMesh:
	var t := tableaux_plats(c, famille) if est_plate(famille) else tableaux_volume(c, famille)
	if (t[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
		return null
	var m := ArrayMesh.new()
	if est_plate(famille):
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, t, [], {},
			Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	else:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, t)
	return m


## Les nœuds de la carte, un par famille qui y porte un objet : des `MeshInstance3D` sans ombre, nommés
## `MursMeubles_<famille>`, sur le calque 1 (la présentation pose le calque commun). `materiaux` : famille → matériau.
static func creer_noeuds(data: Dictionary, materiaux: Dictionary) -> Array[MeshInstance3D]:
	var c := construire(data)
	var sortie: Array[MeshInstance3D] = []
	for famille in FAMILLES:
		var m := maillage(c, famille)
		if m == null:
			continue
		var noeud := MeshInstance3D.new()
		noeud.name = PREFIXE_NOEUD + famille
		noeud.mesh = m
		noeud.material_override = materiaux[famille]
		noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		noeud.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		noeud.layers = 1
		sortie.append(noeud)
	return sortie


static func shader_de(famille: String) -> Shader:
	return SHADER_PLAT if est_plate(famille) else SHADER_VOLUME


## Le matériau d'une famille : la lecture de la face réglée comme celle des enseignes ou des tuyaux (donc des murs), plus
## l'atlas des objets plats ou le modelé des boîtiers.
static func accorder(materiau: ShaderMaterial, famille: String) -> void:
	if est_plate(famille):
		EnseignesIsoT.accorder(materiau)
		materiau.set_shader_parameter("atlas", atlas_texture())
	else:
		TuyauxIsoT.accorder(materiau)
		if famille == "boitiers":
			materiau.set_shader_parameter("corps_sombre", CORPS_SOMBRE_BOITIERS)
