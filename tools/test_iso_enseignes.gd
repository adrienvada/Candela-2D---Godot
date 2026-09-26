## Les enseignes et les panneaux muraux, EN ESSAI (`--enseignes-essai`, `enseignes_iso.gd`) — la garde, sans fenêtre.
##
## Ce qu'elle prouve, sur les six cartes livrées :
## - **le drapeau** : éteint par défaut ; la présentation ne construit alors ni matériau, ni maillage, ni nœud. Allumé (forcé
##   ici), un seul nœud sur le calque commun, sans ombre, sans enfant (ni collision ni occluder), un maillage d'UNE surface,
##   l'atlas posé ; l'éteindre le retire.
## - **les bornes** : chaque coin sous l'arête (moins une saillie vue sous le tangage) et au-dessus de la bande de sol, devant
##   SA face à `SAILLIE_MAX` au plus, à `MARGE_BOUT` au moins de ses bouts ; une enseigne par face au plus.
## - **la symétrie** : chaque enseigne a ses jumelles par tout le groupe de la carte ; « ZONE 1 » et « ZONE 2 » s'échangent par
##   la symétrie des départs ; et pour chaque paire de caméras (options A, B, C, à 0° et à 45°) dont les MURS sont équitables,
##   ce que dessine la caméra de J2 est l'image exacte de ce que dessine celle de J1.
## - **lisible** : à 0° comme à 45° (option B, le défaut), chaque joueur a au moins une « ARENA » et une « ZONE » de son côté
##   sous les yeux ; et aucun texte n'est lu à l'envers ni la tête en bas, pour aucune caméra qui le dessine, dont 45° B.
## - **jamais plus clair** : chaque texel de l'atlas ≤ le fond de la plaque < 1 ; le shader relit la lumière de la face par les
##   fonctions de `mur_iso.gdshader` copiées mot pour mot, n'émet rien, et ne la change que par des facteurs de la pâte
##   plafonnés par la matière la plus sombre d'une face.
## - **déterministe** : deux constructions, deux atlas identiques ; l'empreinte du placement figée ; aucun tirage non semé.
##
## Ce qu'elle ne prouve pas : l'image. La planche (`tools/photo_enseignes.gd`, vraie fenêtre) compte le noir au pixel.
##
## Lancer : godot --headless --path . --script res://tools/test_iso_enseignes.gd
extends SceneTree

const EnseignesIsoT := preload("res://enseignes_iso.gd")
const TuyauxIsoT := preload("res://tuyaux_iso.gd")
const PLANCHER := 120
## L'empreinte du placement de chaque carte livrée (`_empreinte`, du texte : ni trigonométrie ni flottant). Un changement
## VOULU du placement la change : la recopier depuis la sortie de la suite, en le disant dans le commit.
const EMPREINTES := {
	"arene_circulaire.json": 3074460225,
	"default.json": 767752485,
	"map_001_le_cloitre.json": 4105631550,
	"map_002_l_usine.json": 1621623254,
	"map_003_la_croisee.json": 1128177929,
	"map_004_le_bunker.json": 1567564866,
}
const LACETS := [0.0, 45.0, -45.0, 30.0, 60.0, 90.0, 135.0, 180.0, 225.0, -120.0]
## Les paires de caméras (J1, J2) des trois options du jeu (`GameSettings.lacet_du_joueur`), à 0° et à 45°.
const PAIRES := [["A 0°", 0.0, 0.0], ["B 0°", 0.0, 180.0], ["A 45°", 45.0, 45.0], ["B 45°", 45.0, 225.0],
	["C 45°", 45.0, -45.0]]
const EPS := 0.01

var _echecs := 0
var _verifications := 0
var _cartes: Dictionary = {}


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if ok:
		print("  ✓ %s" % label)
	else:
		_echecs += 1
		printerr("  ✗ %s%s" % [label, ("  → " + detail) if detail != "" else ""])


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== LES ENSEIGNES ET LES PANNEAUX MURAUX, EN ESSAI ===")
	await process_frame
	for f in DirAccess.get_files_at("res://assets/maps"):
		if f.ends_with(".json"):
			_cartes[f] = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/" + f))
	_check("les cartes livrées sont là (%d)" % _cartes.size(), _cartes.size() >= 6)
	await _le_drapeau()
	_l_atlas()
	_les_constructions()
	_le_shader()
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	print("%d vérifications, %d échec(s)" % [_verifications, _echecs])
	quit(1 if _echecs > 0 else 0)


# ---------------------------------------------------------------------------
# LE DRAPEAU — éteint, rien ; allumé, un nœud sur le calque commun
# ---------------------------------------------------------------------------

func _le_drapeau() -> void:
	print("— le drapeau : éteint par défaut, rien de construit")
	_check("--enseignes-essai n'est pas sur la ligne de commande de la suite", not EnseignesIsoT.essai_actif())
	var texte := FileAccess.get_file_as_string("res://presentation_3d.gd")
	_check("la présentation lit le drapeau une fois", texte.contains("var _enseignes := EnseignesIsoT.essai_actif()")
		and texte.count("EnseignesIsoT.essai_actif()") == 1)
	_check("éteint, `_construire_les_enseignes` sort avant tout matériau et tout nœud",
		texte.contains("\tif not _enseignes:\n\t\treturn\n\tif _mat_enseignes == null:"))
	_check("les murs appellent les enseignes à chaque construction (une carte neuve, des enseignes neuves)",
		texte.contains("\t_construire_les_tuyaux(data)\n\t_construire_les_enseignes(data)\n"))
	var Pres: GDScript = load("res://presentation_3d.gd")
	var p: Node = Pres.new()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(p)
	await process_frame
	var avant: Array = p.call("_materiaux")
	p.call("_construire_les_murs")
	var scene: Node3D = p.get("_scene")
	_check("drapeau éteint : aucun nœud d'enseignes dans la scène iso",
		scene.get_node_or_null(EnseignesIsoT.NOM_NOEUD) == null and p.get("_noeud_enseignes") == null)
	_check("drapeau éteint : aucun matériau d'enseignes, les matériaux d'avant",
		p.get("_mat_enseignes") == null and (p.call("_materiaux") as Array).size() == avant.size())
	p.set("_enseignes", true)
	p.call("_construire_les_murs")
	var noeud: MeshInstance3D = p.get("_noeud_enseignes")
	_check("drapeau allumé : un nœud nommé dans la scène iso",
		noeud != null and noeud.get_parent() == scene and noeud.name == EnseignesIsoT.NOM_NOEUD)
	if noeud != null:
		var commun: int = Pres.get_script_constant_map()["CALQUE_COMMUN"]
		_check("sur le calque commun, que les caméras des DEUX joueurs rendent", noeud.layers == commun)
		_check("aucune ombre, ni portée ni reçue d'une lumière 3D",
			noeud.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and noeud.gi_mode == GeometryInstance3D.GI_MODE_DISABLED)
		_check("aucun enfant : ni collision, ni occluder, rien que le maillage", noeud.get_child_count() == 0)
		_check("un seul maillage d'UNE surface : un appel de dessin par vue",
			noeud.mesh != null and noeud.mesh.get_surface_count() == 1)
		var mat := noeud.material_override as ShaderMaterial
		_check("son matériau porte le shader des enseignes et suit la présentation (lightmaps, pâte, canevas)",
			mat != null and mat.shader == EnseignesIsoT.SHADER and (p.call("_materiaux") as Array).has(mat))
		_check("l'atlas est posé sur le matériau", mat != null and mat.get_shader_parameter("atlas") is Texture2D)
		_check("rien sous `_murs` : les boîtes y prennent les ombres de la lumière 3D, une enseigne jamais",
			(p.get("_murs") as Node).get_node_or_null(EnseignesIsoT.NOM_NOEUD) == null)
	p.set("_enseignes", false)
	p.call("_construire_les_murs")
	await process_frame
	_check("éteint de nouveau : le nœud est retiré", p.get("_noeud_enseignes") == null
		and scene.get_node_or_null(EnseignesIsoT.NOM_NOEUD) == null)
	p.queue_free()
	await process_frame
	var script := FileAccess.get_file_as_string("res://enseignes_iso.gd")
	var construit := false
	for classe in ["StaticBody", "CharacterBody", "RigidBody", "Area2D", "Area3D", "CollisionShape", "CollisionPolygon",
			"LightOccluder2D.new", "OccluderInstance3D", "Light2D.new", "Light3D.new", "OmniLight", "SpotLight"]:
		if script.contains(classe):
			construit = true
	_check("le script ne construit ni collision, ni occluder, ni lumière", not construit)
	_check("aucun tirage non semé dans le script (randf, randi, RandomNumberGenerator)",
		not script.contains("randf(") and not script.contains("randi(") and not script.contains("RandomNumberGenerator"))


# ---------------------------------------------------------------------------
# L'ATLAS — jamais une lumière
# ---------------------------------------------------------------------------

func _l_atlas() -> void:
	print("— l'atlas : des facteurs sombres, des lettres, rien d'autre")
	var img := EnseignesIsoT.atlas_image()
	_check("deux atlas identiques, au bit près", img.get_data() == EnseignesIsoT.atlas_image().get_data())
	var plus_clair := 0.0
	var hors_rect := 0
	var rects: Array[Rect2i] = []
	for sorte in EnseignesIsoT.SORTES:
		rects.append(EnseignesIsoT.rect_atlas(sorte))
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				plus_clair = maxf(plus_clair, c.r)
				if not rects.any(func(r: Rect2i) -> bool: return r.has_point(Vector2i(x, y))):
					hors_rect += 1
	var plafond := maxf(EnseignesIsoT.FOND_PLAQUE, EnseignesIsoT.PEINTURE_USEE)
	_check("chaque texel présent ≤ %.2f < 1 (la tôle, la peinture usée) : plus sombre que le mur, toujours (le plus clair : %.3f)" % [
		plafond, plus_clair], plus_clair <= plafond + 0.003 and plafond < 1.0)
	_check("rien hors des rectangles des sortes", hors_rect == 0, "%d texels" % hors_rect)
	var chevauchent := false
	for i in rects.size():
		_check("le rectangle de « %s » tient dans l'atlas" % EnseignesIsoT.SORTES.keys()[i],
			Rect2i(Vector2i.ZERO, EnseignesIsoT.TAILLE_ATLAS).encloses(rects[i]))
		for j in range(i + 1, rects.size()):
			if rects[i].grow(4).intersects(rects[j]):
				chevauchent = true
	_check("les rectangles ne se touchent pas (4 texels d'écart : le filtrage n'y mêle rien)", not chevauchent)
	for sorte in EnseignesIsoT.SORTES:
		var r := EnseignesIsoT.rect_atlas(sorte)
		var plaque: bool = EnseignesIsoT.SORTES[sorte][1]
		var lettres := 0
		var fond := 0
		var fond_max := 0.0
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := img.get_pixel(x, y)
				if c.a == 0.0:
					fond += 1
				elif c.r <= EnseignesIsoT.PEINTURE_USEE + 0.003 and (not plaque or c.r <= EnseignesIsoT.LETTRE_PLAQUE + 0.003):
					lettres += 1
				else:
					fond_max = maxf(fond_max, c.r)
		var aire := r.size.x * r.size.y
		if plaque:
			_check("« %s » : une plaque pleine (%d texels vides : ses quatre coins), des lettres (%d texels)" % [
				sorte, fond, lettres], fond == 4 and lettres > aire / 10)
		else:
			_check("« %s » : des lettres peintes (%d texels), le mur partout ailleurs (%d texels transparents)" % [
				sorte, lettres, fond], lettres > aire / 10 and lettres + fond == aire)
	var arena := EnseignesIsoT.rect_atlas("ARENA")
	var centre_lettre := img.get_pixelv(arena.position + Vector2i(EnseignesIsoT.MARGE_PLAQUE * 4 + 1 * 4 + 1, EnseignesIsoT.MARGE_PLAQUE * 4 + 1))
	_check("le contraste lettre/plaque : la lettre (%.2f) plus sombre que la tôle (%.2f)" % [EnseignesIsoT.LETTRE_PLAQUE,
		EnseignesIsoT.FOND_PLAQUE], EnseignesIsoT.LETTRE_PLAQUE < EnseignesIsoT.BORD_PLAQUE
		and EnseignesIsoT.BORD_PLAQUE < EnseignesIsoT.FOND_PLAQUE and centre_lettre.r <= EnseignesIsoT.LETTRE_PLAQUE + 0.003,
		str(centre_lettre))
	for lettre in "ARENZO12":
		var g: Array = EnseignesIsoT.GLYPHES.get(lettre, [])
		_check("la lettre « %s » : 7 rangées de 5" % lettre, g.size() == 7 and g.all(func(r: String) -> bool: return r.length() == 5))


# ---------------------------------------------------------------------------
# LES CONSTRUCTIONS — carte par carte
# ---------------------------------------------------------------------------

func _les_constructions() -> void:
	print("— la construction, carte par carte")
	var h_mur := TuyauxIsoT.hauteur_mur_px()
	var h_max := EnseignesIsoT.hauteur_max_px()
	var h_bas := EnseignesIsoT.hauteur_bas_px()
	_check("la hauteur permise reste sous l'arête d'une saillie vue sous le tangage (%.2f < %.2f)" % [h_max, h_mur],
		h_max <= h_mur - EnseignesIsoT.SAILLIE_MAX * tan(deg_to_rad(CameraIso.TANGAGE_DEG)) + EPS)
	_check("les enseignes sous le jour des tuyaux : un tuyau passe devant, jamais au travers",
		EnseignesIsoT.SAILLIE_MAX < TuyauxIsoT.JOUR and EnseignesIsoT.ECART_PLAQUE <= EnseignesIsoT.SAILLIE_MAX
		and EnseignesIsoT.ECART_PEINTURE > 0.0 and EnseignesIsoT.ECART_PEINTURE <= EnseignesIsoT.ECART_PLAQUE)
	_check("la marge aux bouts couvre l'encre des arêtes et le glissement d'une saillie vue à 60°",
		EnseignesIsoT.MARGE_BOUT >= IsoMateriaux.ENCRE_ARETE_PX_ESSAI + 1.0
		and EnseignesIsoT.MARGE_BOUT >= EnseignesIsoT.SAILLIE_MAX * tan(acos(EnseignesIsoT.SEUIL_FACE)))
	var avec_zone := 0
	var total := 0
	for nom in _cartes:
		var data: Dictionary = _cartes[nom]
		var c := EnseignesIsoT.construire(data)
		var c2 := EnseignesIsoT.construire(data)
		_check("%s : la même construction deux fois" % nom, str(c["enseignes"]) == str(c2["enseignes"])
			and EnseignesIsoT.tableaux(c) == EnseignesIsoT.tableaux(c2))
		var empreinte := _empreinte(c)
		print("    empreinte %s = %d  (groupe %s, sigma %d, %d enseignes)" % [nom, empreinte, str(c["groupe"]),
			int(c["sigma"]), (c["enseignes"] as Array).size()])
		if EMPREINTES.has(nom):
			_check("%s : l'empreinte du placement est celle figée" % nom, int(EMPREINTES[nom]) == empreinte,
				"%d au lieu de %d" % [empreinte, int(EMPREINTES[nom])])
		total += (c["enseignes"] as Array).size()
		if (c["enseignes"] as Array).any(func(e: Dictionary) -> bool: return String(e["sorte"]).begins_with("ZONE")):
			avec_zone += 1
		_bornes(nom, c, h_max, h_bas)
		_symetrie(nom, data, c)
		_lisible(nom, c)
	_check("les cartes livrées portent des enseignes (%d), « ZONE n » sur cinq d'entre elles au moins (%d)" % [total,
		avec_zone], total >= 12 and avec_zone >= 5)


## L'empreinte du PLACEMENT : la sorte, la clé de la face et l'abscisse de chaque enseigne, en texte entier.
func _empreinte(c: Dictionary) -> int:
	var texte := ""
	for e in c["enseignes"]:
		var f: Dictionary = c["faces"][int(e["face"])]
		texte += "%s:%s:%d;" % [e["sorte"], str(f["cle"]), roundi(float(e["s"]) * 2.0)]
	return texte.hash()


func _bornes(nom: String, c: Dictionary, h_max: float, h_bas: float) -> void:
	var faces: Array = c["faces"]
	var hors := 0
	var pire := ""
	var par_face := {}
	for e in c["enseignes"]:
		var f: Dictionary = faces[int(e["face"])]
		par_face[int(e["face"])] = int(par_face.get(int(e["face"]), 0)) + 1
		var n: Vector2 = f["n"]
		var t := Vector2(-n.y, n.x)
		for q in EnseignesIsoT.coins(f, e):
			var xz := Vector2(q.x, q.z)
			var ecart := xz.dot(n) - float(f["d"])
			var s := xz.dot(t)
			if q.y > h_max + EPS or q.y < h_bas - EPS or ecart <= 0.0 or ecart > EnseignesIsoT.SAILLIE_MAX + EPS \
					or s < float(f["s0"]) + EnseignesIsoT.MARGE_BOUT - EPS or s > float(f["s1"]) - EnseignesIsoT.MARGE_BOUT + EPS:
				hors += 1
				if pire == "":
					pire = "%s : coin %s, y %.2f dans [%.2f, %.2f], écart %.2f, s %.2f dans [%.2f, %.2f]" % [e["sorte"], str(q),
						q.y, h_bas, h_max, ecart, s, float(f["s0"]) + EnseignesIsoT.MARGE_BOUT,
						float(f["s1"]) - EnseignesIsoT.MARGE_BOUT]
	_check("%s : chaque coin sous l'arête, au-dessus du sol, devant SA face, loin de ses bouts" % nom, hors == 0,
		"%d coins ; %s" % [hors, pire])
	_check("%s : une enseigne par face au plus" % nom, par_face.values().all(func(v: int) -> bool: return v == 1))


## L'image d'une enseigne par un élément du groupe : sa clé de face et sa sorte (« ZONE » échangée par `sigma`, et par tout
## élément qui échange les côtés des deux départs).
func _cle_enseigne(c: Dictionary, e: Dictionary, s: int) -> String:
	var f: Dictionary = c["faces"][int(e["face"])]
	var n: Vector2 = f["n"]
	var t := Vector2(-n.y, n.x)
	var a := n * float(f["d"]) + t * float(f["s0"])
	var b := n * float(f["d"]) + t * float(f["s1"])
	var dim: Vector2 = c["taille_px"]
	return EnseignesIsoT.cle_face(EnseignesIsoT.normale_image(n, s), EnseignesIsoT.point_image(a, s, dim),
		EnseignesIsoT.point_image(b, s, dim))


func _index(c: Dictionary) -> Dictionary:
	var index := {}
	for e in c["enseignes"]:
		index[_cle_enseigne(c, e, EnseignesIsoT.Sym.ID)] = String(e["sorte"])
	return index


static func _echange(sorte: String) -> String:
	return {"ZONE 1": "ZONE 2", "ZONE 2": "ZONE 1"}.get(sorte, sorte)


func _symetrie(nom: String, data: Dictionary, c: Dictionary) -> void:
	var index := _index(c)
	var sigma: int = c["sigma"]
	var grp: Array = c["groupe"]
	_check("%s : le groupe contient la symétrie des départs (%d) et le demi-tour" % [nom, sigma],
		sigma != EnseignesIsoT.Sym.ID and grp.has(sigma) and grp.has(EnseignesIsoT.Sym.R))
	var manquantes := 0
	var mal_nommees := 0
	var detail := ""
	for e in c["enseignes"]:
		for s in grp:
			var cle := _cle_enseigne(c, e, s)
			if not index.has(cle):
				manquantes += 1
				if detail == "":
					detail = "%s par %d : aucune enseigne en %s" % [e["sorte"], s, cle]
			elif s == sigma and index[cle] != _echange(String(e["sorte"])):
				mal_nommees += 1
	_check("%s : chaque enseigne a ses jumelles par tout le groupe %s" % [nom, str(grp)], manquantes == 0,
		"%d ; %s" % [manquantes, detail])
	_check("%s : par la symétrie des départs, « ARENA » reste, « ZONE 1 » et « ZONE 2 » s'échangent" % nom,
		mal_nommees == 0, "%d" % mal_nommees)
	# Chaque « ZONE n » du côté du départ de Jn.
	var d1 := (Vector2(EnseignesIsoT.depart(data, "spawn_p1")) + Vector2(0.5, 0.5)) * float(CandelaTileSet.TILE_SIZE.x)
	var d2 := (Vector2(EnseignesIsoT.depart(data, "spawn_p2")) + Vector2(0.5, 0.5)) * float(CandelaTileSet.TILE_SIZE.x)
	var cote_faux := 0
	for e in c["enseignes"]:
		var m := EnseignesIsoT.milieu(c["faces"][int(e["face"])])
		if e["sorte"] == "ZONE 1" and not m.distance_to(d1) < m.distance_to(d2):
			cote_faux += 1
		if e["sorte"] == "ZONE 2" and not m.distance_to(d2) < m.distance_to(d1):
			cote_faux += 1
	_check("%s : chaque « ZONE n » du côté du départ de Jn" % nom, cote_faux == 0)
	# Les paires de caméras : là où les MURS sont équitables (une symétrie de la carte porte J1 sur J2 ET la direction de sa
	# caméra sur celle de J2), ce que dessine J2 est l'image de ce que dessine J1, zones échangées.
	var symetries := EnseignesIsoT.symetries_des_murs(data)
	var taille := EnseignesIsoT.cases_carte(data)
	var equitables := []
	for paire in PAIRES:
		var h1 := _horizontale(float(paire[1]))
		var h2 := _horizontale(float(paire[2]))
		var pi := -1
		for s in symetries:
			# Les départs des cartes livrées ne sont pas toujours exactement symétriques (« Le Cloître » : rangée 16 des deux côtés,
			# le demi-tour la porte en 15) : une case d'écart au plus.
			var image_j1 := Vector2(EnseignesIsoT.case_image(EnseignesIsoT.depart(data, "spawn_p1"), s, taille))
			if image_j1.distance_to(Vector2(EnseignesIsoT.depart(data, "spawn_p2"))) <= 1.0 \
					and EnseignesIsoT.normale_image(h1, s).distance_to(h2) < 0.001:
				pi = s
		if pi < 0:
			continue
		equitables.append(paire[0])
		var vues_j1 := {}
		var vues_j2 := {}
		for e in c["enseignes"]:
			var n: Vector2 = c["faces"][int(e["face"])]["n"]
			if TuyauxIsoT.face_dessinee(n, float(paire[1])):
				vues_j1[_cle_enseigne(c, e, pi)] = _echange(String(e["sorte"]))
			if TuyauxIsoT.face_dessinee(n, float(paire[2])):
				vues_j2[_cle_enseigne(c, e, EnseignesIsoT.Sym.ID)] = String(e["sorte"])
		_check("%s, paire %s : J2 dessine l'image exacte de ce que dessine J1 (%d enseignes chacun)" % [nom, paire[0],
			vues_j1.size()], vues_j1 == vues_j2 and not vues_j1.is_empty(), "%s contre %s" % [str(vues_j1), str(vues_j2)])
	print("    %s : paires de caméras équitables pour les murs : %s" % [nom, str(equitables)])
	_check("%s : l'option B (le défaut en ligne) est équitable pour les murs, à 0° comme à 45°" % nom,
		equitables.has("B 0°") and equitables.has("B 45°") or nom == "map_002_l_usine.json")


func _horizontale(lacet: float) -> Vector2:
	var z := TuyauxIsoT.vers_camera(lacet)
	return Vector2(z.x, z.z).normalized()


func _lisible(nom: String, c: Dictionary) -> void:
	var faces: Array = c["faces"]
	# À 0° et à 45°, option B : ce que chaque joueur a sous les yeux, de SON côté.
	var a_zone: bool = (c["enseignes"] as Array).any(func(e: Dictionary) -> bool: return String(e["sorte"]).begins_with("ZONE"))
	for paire in [["0°", 0.0, 180.0], ["45°", 45.0, 225.0]]:
		for j in 2:
			var lacet: float = paire[1 + j]
			var sortes := {}
			for e in c["enseignes"]:
				if TuyauxIsoT.face_dessinee(faces[int(e["face"])]["n"], lacet):
					sortes[String(e["sorte"])] = true
			var sa_zone := "ZONE %d" % (j + 1)
			_check("%s, %s option B : J%d a sous les yeux « ARENA »%s" % [nom, paire[0], j + 1,
				(" et « %s »" % sa_zone) if a_zone else ""], sortes.has("ARENA") and (not a_zone or sortes.has(sa_zone)),
				str(sortes.keys()))
	# Jamais à l'envers : pour chaque caméra qui dessine une enseigne, son axe de lecture va vers la droite de l'écran et
	# son haut vers le haut ; l'atlas se lit de gauche à droite et de haut en bas le long de ces axes.
	var envers := 0
	var detail := ""
	var t := EnseignesIsoT.tableaux(c)
	var uv: PackedVector2Array = t[Mesh.ARRAY_TEX_UV]
	var sommets: PackedVector3Array = t[Mesh.ARRAY_VERTEX]
	for k in (c["enseignes"] as Array).size():
		var e: Dictionary = c["enseignes"][k]
		var n: Vector2 = faces[int(e["face"])]["n"]
		var q := EnseignesIsoT.coins(faces[int(e["face"])], e)
		var droite := q[1] - q[0]
		var haut := q[0] - q[3]
		if uv[4 * k + 1].x <= uv[4 * k].x or uv[4 * k + 3].y <= uv[4 * k].y or sommets[4 * k] != q[0]:
			envers += 1
			detail = "%s : l'atlas n'est pas posé de gauche à droite, de haut en bas" % e["sorte"]
		for lacet in LACETS:
			if not TuyauxIsoT.face_dessinee(n, lacet):
				continue
			var base := CameraIso.transform_pour(Transform2D.IDENTITY, Vector2(1920, 1080), CameraIso.TANGAGE_DEG, lacet).basis
			# Vers la droite de l'écran, franchement (≥ cos 60°) ; le haut de l'enseigne vers le haut de l'écran.
			if droite.normalized().dot(base.x) < 0.5 or haut.normalized().dot(base.y) <= 0.0:
				envers += 1
				if detail == "":
					detail = "%s, lacet %s° : droite·x %.2f, haut·y %.2f" % [e["sorte"], str(lacet),
						droite.normalized().dot(base.x), haut.normalized().dot(base.y)]
	_check("%s : aucun texte lu à l'envers ni la tête en bas, à aucun des lacets %s (45° B = 225°)" % [nom, str(LACETS)],
		envers == 0, detail)
	# L'enroulement : la convention du moteur lue sur une `BoxMesh`, comme la garde des tuyaux.
	var boite := BoxMesh.new().get_mesh_arrays()
	var bv: PackedVector3Array = boite[Mesh.ARRAY_VERTEX]
	var bn: PackedVector3Array = boite[Mesh.ARRAY_NORMAL]
	var bi: PackedInt32Array = boite[Mesh.ARRAY_INDEX]
	var signe := signf((bv[bi[1]] - bv[bi[0]]).cross(bv[bi[2]] - bv[bi[0]]).dot(bn[bi[0]]))
	var indices: PackedInt32Array = t[Mesh.ARRAY_INDEX]
	var normales: PackedVector3Array = t[Mesh.ARRAY_NORMAL]
	var retournes := 0
	for k in range(0, indices.size(), 3):
		var a := sommets[indices[k]]
		var geo := (sommets[indices[k + 1]] - a).cross(sommets[indices[k + 2]] - a)
		if signf(geo.dot(normales[indices[k]])) != signe:
			retournes += 1
	_check("%s : chaque triangle a sa face avant vers le dehors du mur (convention d'une BoxMesh)" % nom,
		retournes == 0 and signe != 0.0, "%d triangles retournés" % retournes)


# ---------------------------------------------------------------------------
# LE SHADER — la lecture de la face, des facteurs, rien d'autre
# ---------------------------------------------------------------------------

func _fonction(code: String, signature: String) -> String:
	var debut := code.find(signature)
	if debut < 0:
		return ""
	var fin := code.find("\n}\n", debut)
	return code.substr(debut, fin + 3 - debut) if fin > 0 else ""


func _le_shader() -> void:
	print("— le shader : la lecture de la face, des facteurs, aucune lumière")
	var code := (EnseignesIsoT.SHADER as Shader).code
	var mur := (load("res://mur_iso.gdshader") as Shader).code
	for signature in ["vec3 lire_etalon(", "vec3 lire_lumiere(", "vec3 lire_lumiere_moyenne(", "vec3 lightmap_pateuse_lue("]:
		var a := _fonction(code, signature)
		_check("« %s » copiée mot pour mot de mur_iso.gdshader" % signature.trim_suffix("("),
			a != "" and a == _fonction(mur, signature))
	_check("unshaded, cull_back, sans ombre", code.contains("render_mode unshaded, cull_back, fog_disabled, shadows_disabled;"))
	_check("aucune lumière ni émission : ni light(), ni LIGHT, ni EMISSION",
		not code.contains("void light(") and not code.contains("LIGHT") and not code.contains("EMISSION"))
	var corps := _fonction(code, "void fragment() {")
	var sorties := []
	var couleurs := []
	for ligne in corps.split("\n"):
		var l := ligne.strip_edges()
		if l.begins_with("ALBEDO"):
			sorties.append(l)
		if l.begins_with("c = "):
			couleurs.append(l.substr(0, l.find("(")))
	_check("la couleur sort par ALBEDO = c, et l'instrument de la planche seul en blanc",
		sorties == ["ALBEDO = c;", "ALBEDO = vec3(1.0);"] and corps.contains("if (emprise_preuve) {\n\t\tALBEDO = vec3(1.0);"),
		str(sorties))
	_check("c ne naît que de la lumière lue, et ne change que par des facteurs de la pâte",
		not couleurs.is_empty() and couleurs.all(func(x: String) -> bool: return x in ["c = lightmap_pateuse_lue",
			"c = pate_matiere_et_encre", "c = pate_temperature", "c = pate_temperature_graduee_neutre",
			"c = pate_temperature_graduee"]), str(couleurs))
	_check("la lumière est lue au point de face couvert à l'écran, au pied, le long de la face",
		corps.contains("lire_lumiere_moyenne(couvert.xz + n * pied, tangente, deux, peinture_ref, peinture_min)"))
	_check("le facteur de l'atlas plafonné par la plus sombre d'une face, sans encre",
		corps.contains("pate_matiere_et_encre(c, min(texel.r, 1.0) * matiere_max * contact, 1.0, 0.0, 0.0)"))
	_check("hors des lettres peintes, le fragment est jeté : le mur se voit",
		corps.contains("if (texel.a < 0.5) {") and corps.contains("discard;"))
	var sommet := _fonction(code, "void vertex() {")
	_check("une face vue de profil ou de dos : son enseigne écrasée en un point (jamais vue en miroir)",
		sommet.contains("if (vue < seuil_face) {") and sommet.contains("VERTEX = vec3(0.0);"))
	_check("le tri et la lecture du point couvert sont ceux des tuyaux",
		sommet.contains("float vue = horizontale > 0.0001 ? dot(n, vers_camera.xz / horizontale) : 0.0;")
		and _fonction((TuyauxIsoT.SHADER as Shader).code, "void vertex() {").contains(
			"float vue = horizontale > 0.0001 ? dot(n, vers_camera.xz / horizontale) : 0.0;")
		and sommet.contains("couvert = monde - vers_camera * (ecart / approche);"))
	var m := ShaderMaterial.new()
	m.shader = EnseignesIsoT.SHADER
	EnseignesIsoT.accorder(m)
	var mur_mat := ShaderMaterial.new()
	mur_mat.shader = load("res://mur_iso.gdshader")
	IsoMateriaux.accorder_mur(mur_mat)
	_check("accordé : le même pied que les faces des murs", is_equal_approx(float(m.get_shader_parameter("pied")),
		float(mur_mat.get_shader_parameter("pied"))))
	_check("accordé : le même contact et la même température que les murs",
		is_equal_approx(float(m.get_shader_parameter("contact_px")), float(mur_mat.get_shader_parameter("contact_px")))
		and is_equal_approx(float(m.get_shader_parameter("temperature")), float(mur_mat.get_shader_parameter("temperature")))
		and is_equal_approx(float(m.get_shader_parameter("temperature_seuil_haut")),
			float(mur_mat.get_shader_parameter("temperature_seuil_haut"))))
	_check("accordé : le tri à cos 60°, l'instrument éteint",
		is_equal_approx(float(m.get_shader_parameter("seuil_face")), EnseignesIsoT.SEUIL_FACE)
		and m.get_shader_parameter("emprise_preuve") == false)
	var plus_sombre := lerpf(1.0, IsoMateriaux.PLANCHER, float(mur_mat.get_shader_parameter("force_matiere")))
	_check("accordé : la matière plafonnée à %.3f, la plus sombre qu'une face porte" % plus_sombre,
		absf(float(m.get_shader_parameter("matiere_max")) - plus_sombre) < 0.0005)
	_check("le lambert des faces est éteint (plancher 1) : les enseignes n'ont pas à le suivre",
		is_equal_approx(IsoMateriaux.LAMBERT_PLANCHER, 1.0))
