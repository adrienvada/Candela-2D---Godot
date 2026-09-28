## Les murs meublés, EN ESSAI (`--murs-meubles-essai`, `murs_meubles_iso.gd`) — la garde, sans fenêtre.
##
## Ce qu'elle prouve, sur les six cartes livrées :
## - **le drapeau** : éteint par défaut ; la présentation ne construit alors ni matériau, ni maillage, ni nœud. Allumé (forcé
##   ici), un nœud par famille présente, sur le calque commun, sans ombre, sans enfant (ni collision ni occluder), un
##   maillage d'UNE surface chacun, le shader des enseignes ou des tuyaux ; l'éteindre les retire.
## - **l'équité** : aucune entrée de la table refusée ; l'ensemble des objets de chaque carte est invariant par tout son groupe
##   (chaque objet a ses jumeaux, même famille, même variante) ; à 0° et à 45° en option B, J1 et J2 ont sous les yeux autant
##   d'objets de chaque famille ; les atlas sont symétriques gauche-droite (l'image miroir d'une porte est la même porte).
## - **les bornes** : chaque sommet sous l'arête moins la saillie vue sous le tangage, au-dessus de la bande de sol, devant SA
##   face de sa saillie au plus, à la marge des bouts ; aucun objet sur un autre ni sur une enseigne.
## - **jamais plus clair** : chaque texel de l'atlas ≤ 0,70 ; chaque matière de volume ≤ 1 ; les matériaux portent les
##   shaders des enseignes et des tuyaux, dont les gardes prouvent la lecture de la face et le plafond `matiere_max`, posé ici
##   comme là ; l'instrument de banc éteint.
## - **déterministe** : deux constructions identiques, deux atlas identiques ; aucun tirage non semé.
##
## Ce qu'elle ne prouve pas : l'image. `tools/photo_murs_meubles.gd` (vraie fenêtre) compte le noir et la clarté au pixel.
##
## Lancer : godot --headless --path . --script res://tools/test_iso_murs_meubles.gd
extends SceneTree

const MursMeublesIsoT := preload("res://murs_meubles_iso.gd")
const EnseignesIsoT := preload("res://enseignes_iso.gd")
const TuyauxIsoT := preload("res://tuyaux_iso.gd")
const DemiTour := preload("res://tools/demi_tour.gd")
const PLANCHER := 150
const EPS := 0.01
const PAIRES := [["B 0°", 0.0, 180.0], ["B 45°", 45.0, 225.0]]

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
	print("=== LES MURS MEUBLÉS, EN ESSAI ===")
	await process_frame
	for f in DirAccess.get_files_at("res://assets/maps"):
		if f.ends_with(".json"):
			_cartes[f] = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/" + f))
	_check("les six cartes livrées sont là (%d)" % _cartes.size(), _cartes.size() >= 6)
	await _le_drapeau()
	_l_atlas()
	_les_constructions()
	_les_materiaux()
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	print("%d vérifications, %d échec(s)" % [_verifications, _echecs])
	quit(1 if _echecs > 0 else 0)


# ---------------------------------------------------------------------------
# LE DRAPEAU
# ---------------------------------------------------------------------------

func _le_drapeau() -> void:
	print("— le drapeau : éteint par défaut, rien de construit")
	_check("--murs-meubles-essai n'est pas sur la ligne de commande de la suite", not MursMeublesIsoT.essai_actif())
	var texte := FileAccess.get_file_as_string("res://presentation_3d.gd")
	_check("la présentation lit le drapeau une fois",
		texte.contains("var _murs_meubles := MursMeublesIsoT.essai_actif()")
		and texte.count("MursMeublesIsoT.essai_actif()") == 1)
	_check("éteint, `_construire_les_murs_meubles` sort avant tout matériau et tout nœud",
		texte.contains("\tif not _murs_meubles:\n\t\treturn\n\tif _mats_murs_meubles.is_empty():"))
	_check("les murs appellent les murs meublés à chaque construction, après les enseignes",
		texte.contains("\t_construire_les_enseignes(data)\n\t_construire_les_murs_meubles(data)\n"))
	var Pres: GDScript = load("res://presentation_3d.gd")
	var p: Node = Pres.new()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(p)
	await process_frame
	var avant: Array = p.call("_materiaux")
	p.call("_construire_les_murs")
	var scene: Node3D = p.get("_scene")
	var noms := func() -> int:
		var n := 0
		for enfant in scene.get_children():
			if String(enfant.name).begins_with(MursMeublesIsoT.PREFIXE_NOEUD):
				n += 1
		return n
	_check("drapeau éteint : aucun nœud de murs meublés dans la scène iso",
		noms.call() == 0 and (p.get("_noeuds_murs_meubles") as Array).is_empty())
	_check("drapeau éteint : aucun matériau de murs meublés, les matériaux d'avant",
		(p.get("_mats_murs_meubles") as Dictionary).is_empty() and (p.call("_materiaux") as Array).size() == avant.size())
	p.set("_murs_meubles", true)
	p.call("_construire_les_murs")
	var noeuds: Array = p.get("_noeuds_murs_meubles")
	var commun: int = Pres.get_script_constant_map()["CALQUE_COMMUN"]
	_check("drapeau allumé : un nœud par famille présente sur la carte (%d)" % noeuds.size(),
		noeuds.size() >= 1 and noeuds.size() <= MursMeublesIsoT.FAMILLES.size() and noms.call() == noeuds.size())
	_check("un matériau par famille, suivis par la présentation (lightmaps, pâte, peinture)",
		(p.get("_mats_murs_meubles") as Dictionary).size() == MursMeublesIsoT.FAMILLES.size()
		and (p.call("_materiaux") as Array).size() == avant.size() + MursMeublesIsoT.FAMILLES.size())
	for noeud in noeuds:
		var mi := noeud as MeshInstance3D
		var famille := String(mi.name).trim_prefix(MursMeublesIsoT.PREFIXE_NOEUD)
		_check("%s : dans la scène iso, hors de `_murs`, sur le calque commun" % famille,
			mi.get_parent() == scene and mi.layers == commun
			and (p.get("_murs") as Node).get_node_or_null(NodePath(mi.name)) == null)
		_check("%s : aucune ombre, aucun enfant (ni collision, ni occluder)" % famille,
			mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and mi.gi_mode == GeometryInstance3D.GI_MODE_DISABLED and mi.get_child_count() == 0)
		_check("%s : un maillage d'UNE surface — un appel de dessin par vue" % famille,
			mi.mesh != null and mi.mesh.get_surface_count() == 1)
		var mat := mi.material_override as ShaderMaterial
		_check("%s : le shader de sa famille (%s), et le matériau de la présentation" % [famille,
			MursMeublesIsoT.shader_de(famille).resource_path],
			mat != null and mat.shader == MursMeublesIsoT.shader_de(famille)
			and (p.call("_materiaux") as Array).has(mat))
		if MursMeublesIsoT.est_plate(famille):
			_check("%s : l'atlas est posé" % famille, mat != null and mat.get_shader_parameter("atlas") is Texture2D)
	p.set("_murs_meubles", false)
	p.call("_construire_les_murs")
	await process_frame
	_check("éteint de nouveau : les nœuds sont retirés", noms.call() == 0
		and (p.get("_noeuds_murs_meubles") as Array).is_empty())
	p.queue_free()
	await process_frame
	var script := FileAccess.get_file_as_string("res://murs_meubles_iso.gd")
	var construit := false
	for classe in ["StaticBody", "CharacterBody", "RigidBody", "Area2D", "Area3D", "CollisionShape", "CollisionPolygon",
			"LightOccluder2D", "OccluderInstance3D", "Light2D", "Light3D", "OmniLight", "SpotLight"]:
		if script.contains(classe):
			construit = true
	_check("le script ne construit ni collision, ni occluder, ni lumière", not construit)
	_check("aucun tirage non semé dans le script (randf, randi, RandomNumberGenerator)",
		not script.contains("randf(") and not script.contains("randi(") and not script.contains("RandomNumberGenerator"))
	_check("aucun shader nouveau : les familles lisent la face par les shaders des enseignes et des tuyaux",
		MursMeublesIsoT.SHADER_PLAT.resource_path == "res://enseignes_iso.gdshader"
		and MursMeublesIsoT.SHADER_VOLUME.resource_path == "res://tuyaux_iso.gdshader")


# ---------------------------------------------------------------------------
# L'ATLAS — jamais une lumière, symétrique gauche-droite
# ---------------------------------------------------------------------------

func _l_atlas() -> void:
	print("— l'atlas des portes et des grilles")
	var a := MursMeublesIsoT.atlas_image()
	var b := MursMeublesIsoT.atlas_image()
	_check("deux atlas identiques (aucun hasard)", a.get_data() == b.get_data())
	_check("l'atlas a la taille déclarée", a.get_size() == MursMeublesIsoT.TAILLE_ATLAS)
	var max_r := 0.0
	for y in a.get_height():
		for x in a.get_width():
			var c := a.get_pixel(x, y)
			if c.a > 0.5:
				max_r = maxf(max_r, c.r)
	_check("chaque texel posé ≤ 0,70 : un facteur, jamais une lumière (max %.3f)" % max_r, max_r <= 0.70 + 0.002)
	for motif in MursMeublesIsoT.MOTIFS:
		var r := MursMeublesIsoT.rect_atlas(motif)
		var pleins := 0
		var asym := 0
		var sombres := 0
		for y in r.size.y:
			for x in r.size.x:
				var c := a.get_pixelv(r.position + Vector2i(x, y))
				var m := a.get_pixelv(r.position + Vector2i(r.size.x - 1 - x, y))
				if c.a > 0.5:
					pleins += 1
				if not is_equal_approx(c.r, m.r) or not is_equal_approx(c.a, m.a):
					asym += 1
				if c.r <= MursMeublesIsoT.RIVET_F + 0.001:
					sombres += 1
		_check("%s : plein sur tout son rectangle (%d texels)" % [motif, pleins], pleins == r.size.x * r.size.y)
		_check("%s : symétrique gauche-droite, au texel (%d écarts)" % [motif, asym], asym == 0)
		_check("%s : porte ses rivets ou ses fonds sombres (%d texels)" % [motif, sombres], sombres > 4)
	var hors := 0
	for y in a.get_height():
		for x in a.get_width():
			var dedans := false
			for motif in MursMeublesIsoT.MOTIFS:
				if MursMeublesIsoT.rect_atlas(motif).has_point(Vector2i(x, y)):
					dedans = true
			if not dedans and a.get_pixel(x, y).a > 0.0:
				hors += 1
	_check("hors des motifs, l'atlas est transparent (le mur seul) : %d texels" % hors, hors == 0)
	_check("les motifs ne se chevauchent pas", not MursMeublesIsoT.rect_atlas("porte0").intersects(
		MursMeublesIsoT.rect_atlas("porte1")) and not MursMeublesIsoT.rect_atlas("porte1").intersects(
		MursMeublesIsoT.rect_atlas("grille0")) and not MursMeublesIsoT.rect_atlas("porte0").intersects(
		MursMeublesIsoT.rect_atlas("grille0")))


# ---------------------------------------------------------------------------
# LES CONSTRUCTIONS — carte par carte
# ---------------------------------------------------------------------------

func _cle(o: Dictionary) -> String:
	var n: Vector2 = o["n"]
	return "%s|%d|%d,%d|%d|%d" % [o["famille"], int(o["variante"]), roundi(n.x), roundi(n.y), roundi(float(o["d"]) * 4.0),
		roundi(float(o["s"]) * 4.0)]


func _les_constructions() -> void:
	var ids := {}
	for nom in _cartes:
		var data: Dictionary = _cartes[nom]
		ids[String(data.get("id", ""))] = nom
		print("— %s" % nom)
		var c := MursMeublesIsoT.construire(data)
		var c2 := MursMeublesIsoT.construire(data)
		_check("%s : aucune entrée de la table refusée" % nom, (c["refus"] as Array).is_empty(), str(c["refus"]))
		var objets: Array = c["objets"]
		_check("%s : deux constructions identiques" % nom, str(objets) == str(c2["objets"]))
		var par := {}
		for o in objets:
			par[o["famille"]] = int(par.get(o["famille"], 0)) + 1
		for famille in MursMeublesIsoT.FAMILLES:
			_check("%s : des %s (%d)" % [nom, famille, int(par.get(famille, 0))], int(par.get(famille, 0)) >= 2)
		# L'équité : l'ensemble est invariant par le groupe.
		var ensemble := {}
		for o in objets:
			ensemble[_cle(o)] = true
		_check("%s : aucun objet en double" % nom, ensemble.size() == objets.size())
		var dim: Vector2 = c["taille_px"]
		var manquants := 0
		for g in c["groupe"]:
			for o in objets:
				var n: Vector2 = o["n"]
				var t := Vector2(-n.y, n.x)
				var pt := n * float(o["d"]) + t * float(o["s"])
				var ni := EnseignesIsoT.normale_image(n, g)
				var pi := EnseignesIsoT.point_image(pt, g, dim)
				var image := {"famille": o["famille"], "variante": o["variante"], "n": ni, "d": pi.dot(ni),
					"s": pi.dot(Vector2(-ni.y, ni.x))}
				if not ensemble.has(_cle(image)):
					manquants += 1
		_check("%s : chaque objet a ses jumeaux par tout le groupe %s (%d manquants)" % [nom, str(c["groupe"]),
			manquants], manquants == 0)
		# La règle commune des décors (`tools/demi_tour.gd`), indépendante du groupe que la construction se donne ; et elle
		# rougit sur une construction privée des objets des faces nord (celles que J2 voit à 180° et 225°).
		_check("%s : chaque objet a son jumeau par le demi-tour (règle commune des décors)" % nom,
			DemiTour.orphelins_murs_meubles(data, c).is_empty(), str(DemiTour.orphelins_murs_meubles(data, c).slice(0, 4)))
		var sans_nord := c.duplicate()
		sans_nord["objets"] = objets.filter(func(o: Dictionary) -> bool: return (o["n"] as Vector2) != Vector2(0, -1))
		_check("%s : la garde rougit sans les objets des faces nord" % nom,
			not DemiTour.orphelins_murs_meubles(data, sans_nord).is_empty())
		for paire in PAIRES:
			for famille in MursMeublesIsoT.FAMILLES:
				var vus := [0, 0]
				for o in objets:
					if o["famille"] != famille:
						continue
					for j in 2:
						if TuyauxIsoT.face_dessinee(o["n"], float(paire[1 + j])):
							vus[j] += 1
				_check("%s, %s : J1 et J2 voient autant de %s (%d, %d)" % [nom, paire[0], famille, vus[0], vus[1]],
					vus[0] == vus[1] and (paire[0] != "B 45°" or vus[0] > 0))
		# Les bornes, sommet par sommet, famille par famille.
		var faces: Array[Dictionary] = c["faces"]
		for famille in MursMeublesIsoT.FAMILLES:
			var m := MursMeublesIsoT.maillage(c, famille)
			if m == null:
				continue
			_bornes(nom, famille, m.surface_get_arrays(0), faces)
	_check("une table pour chacune des six cartes livrées, et pour elles seules",
		MursMeublesIsoT.TABLE.size() == 6 and ids.size() >= 6
		and MursMeublesIsoT.TABLE.keys().all(func(k: String) -> bool: return ids.has(k)))
	var vide := MursMeublesIsoT.construire({"id": "carte_de_joueur", "width": 10, "height": 10})
	_check("une carte hors de la table ne porte rien", (vide["objets"] as Array).is_empty())


func _bornes(nom: String, famille: String, t: Array, faces: Array[Dictionary]) -> void:
	var sommets: PackedVector3Array = t[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = t[Mesh.ARRAY_TEX_UV2]
	var plat := MursMeublesIsoT.est_plate(famille)
	var plans := PackedFloat32Array()
	if plat:
		plans = t[Mesh.ARRAY_CUSTOM0]
	var uv: PackedVector2Array = t[Mesh.ARRAY_TEX_UV]
	var h_max := MursMeublesIsoT.hauteur_max_px(famille)
	var h_bas := MursMeublesIsoT.hauteur_bas_px(famille)
	var saillie: float = MursMeublesIsoT.SAILLIES[famille]
	var marge := MursMeublesIsoT.marge_bout(famille)
	var haut := 0
	var bas := 0
	var devant := 0
	var bouts := 0
	var matiere := 0
	for k in sommets.size():
		var p := sommets[k]
		var n := uv2[k]
		var d := plans[k * 4] if plat else uv[k].x
		if p.y > h_max + EPS:
			haut += 1
		if p.y < h_bas - EPS:
			bas += 1
		var ecart := Vector2(p.x, p.z).dot(n) - d
		if ecart < -EPS or ecart > saillie + EPS:
			devant += 1
		var s := Vector2(p.x, p.z).dot(Vector2(-n.y, n.x))
		var dans := false
		for f in faces:
			if (f["n"] as Vector2) == n and absf(float(f["d"]) - d) < EPS \
					and s >= float(f["s0"]) + marge - EPS and s <= float(f["s1"]) - marge + EPS:
				dans = true
				break
		if not dans:
			bouts += 1
		if not plat and (uv[k].y > 1.0 or uv[k].y <= 0.0):
			matiere += 1
	_check("%s, %s : sous l'arête moins la saillie vue sous le tangage (%d au-dessus)" % [nom, famille, haut], haut == 0)
	_check("%s, %s : au-dessus de la bande de sol (%d dessous)" % [nom, famille, bas], bas == 0)
	_check("%s, %s : devant sa face, de %.2f px au plus (%d hors)" % [nom, famille, saillie, devant], devant == 0)
	_check("%s, %s : sur une face exposée, à %.1f px de ses bouts (%d hors)" % [nom, famille, marge, bouts], bouts == 0)
	if not plat:
		_check("%s, %s : chaque matière dans ]0, 1] (%d hors)" % [nom, famille, matiere], matiere == 0)
	# L'enroulement : la convention du moteur lue sur une `BoxMesh`, comme les gardes des tuyaux et des enseignes.
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
	_check("%s, %s : chaque triangle a sa face avant vers le dehors (convention d'une BoxMesh)" % [nom, famille],
		retournes == 0 and signe != 0.0, "%d triangles retournés sur %d" % [retournes, indices.size() / 3])


# ---------------------------------------------------------------------------
# LES MATÉRIAUX — le plafond de la matière, l'instrument éteint
# ---------------------------------------------------------------------------

func _les_materiaux() -> void:
	print("— les matériaux")
	for famille in MursMeublesIsoT.FAMILLES:
		var m := ShaderMaterial.new()
		m.shader = MursMeublesIsoT.shader_de(famille)
		MursMeublesIsoT.accorder(m, famille)
		_check("%s : le plafond de la matière est celui des murs (`matiere_max`, %.3f)" % [famille,
			TuyauxIsoT.matiere_max()],
			is_equal_approx(float(m.get_shader_parameter("matiere_max")), TuyauxIsoT.matiere_max()))
		_check("%s : l'instrument de banc est éteint" % famille, m.get_shader_parameter("emprise_preuve") == false)
		_check("%s : lu au pied de la face comme les murs" % famille,
			is_equal_approx(float(m.get_shader_parameter("pied")), IsoMateriaux.PIED_FACE_PX))
		if not MursMeublesIsoT.est_plate(famille):
			var corps := float(m.get_shader_parameter("corps_sombre"))
			_check("%s : le modelé est une encre dans [0, 1] (%.2f)" % [famille, corps], corps >= 0.0 and corps <= 1.0)
	var code := FileAccess.get_file_as_string("res://enseignes_iso.gdshader")
	_check("le shader plat multiplie la lumière de la face par l'atlas plafonné par `matiere_max`",
		code.contains("min(texel.r, 1.0) * matiere_max * contact") and code.contains("render_mode unshaded"))
	var code_v := FileAccess.get_file_as_string("res://tuyaux_iso.gdshader")
	_check("le shader en volume plafonne la matière par `matiere_max`",
		code_v.contains("min(albedo, matiere_max) * contact") and code_v.contains("render_mode unshaded"))
