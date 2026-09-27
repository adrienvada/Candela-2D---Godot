## Les tuyaux et les câbles des murs, EN ESSAI (`--tuyaux-essai`, `tuyaux_iso.gd`) — la garde, sans fenêtre.
##
## Ce qu'elle prouve, sur les six cartes livrées :
## - **le drapeau** : éteint par défaut ; la présentation ne construit alors ni matériau, ni maillage, ni nœud, et ses
##   matériaux restent ceux d'avant. Allumé (forcé ici), un seul nœud, sur le calque commun, sans ombre, un maillage d'UNE
##   surface (un appel de dessin par vue) ; l'éteindre le retire.
## - **rien au-dessus de l'arête** : aucun sommet au-dessus de `hauteur_max_px()` — l'arête, moins une saillie entière vue
##   sous le tangage : même un tuyau de face cachée ne dépasserait pas du sommet —, ni sous `hauteur_bas_px()`.
## - **rien hors de l'emprise** : chaque sommet à `SAILLIE_MAX` au plus de l'emprise des murs hauts, DEVANT sa face, à
##   `MARGE_BOUT` au moins de ses bouts, et chaque face meublée a du sol devant elle.
## - **à l'écran, à 0° comme à 45°** (et à sept autres lacets) : une caméra ne dessine que les tuyaux des faces qu'elle voit
##   de face (le miroir du shader, contre la base réelle de `CameraIso.transform_pour`) — à 0°, les faces sud seules ; à 45°,
##   deux faces par mur. Et le rayon de la caméra prolongé derrière chacun de leurs sommets tombe SUR la face : sous l'arête,
##   au-dessus du sol, entre ses bouts. Un tuyau ne cache donc que son mur — jamais un joueur, jamais le sol.
## - **l'équité** : la même construction deux fois de suite, au bit près (aucun tirage non semé) ; l'empreinte du placement de
##   chaque carte, figée (le même à chaque lancement, sur chaque machine : ni trigonométrie ni flottant dans l'empreinte) ;
##   aucun `randf`/`randi`/`RandomNumberGenerator` dans le script.
## - **l'enroulement** : chaque triangle a sa face avant du côté de ses normales, selon la convention d'une `BoxMesh` du moteur
##   (`cull_back` garde le dehors du tube).
## - **le shader** : la lecture de la face copiée mot pour mot de `mur_iso.gdshader`, `unshaded`, aucune lumière ni émission,
##   la couleur ne sortant que de facteurs de la lumière lue, plafonnés par la matière la plus sombre d'une face (le tuyau
##   n'est jamais plus clair que la face qu'il recouvre) ; l'instrument de la planche éteint.
##
## Ce qu'elle ne prouve pas : l'image. La planche (`tools/photo_tuyaux.gd`, vraie fenêtre) compte le noir au pixel, à 0° et
## à 45°, torche allumée et torches éteintes, dans un même lancement.
##
## Lancer : godot --headless --path . --script res://tools/test_iso_tuyaux.gd
extends SceneTree

const TuyauxIsoT := preload("res://tuyaux_iso.gd")
const PLANCHER := 60
## L'empreinte du placement de chaque carte livrée (`_empreinte`). Un changement VOULU du placement la change : la recopier
## depuis la sortie de la suite, en le disant dans le commit. Un changement non voulu (un tirage glissé, un ordre de parcours
## qui dépend d'autre chose que la carte) la change aussi — c'est pour lui qu'elle est là.
const EMPREINTES := {
	"arene_circulaire.json": 3023601092,
	"default.json": 3162301926,
	"map_001_le_cloitre.json": 406132178,
	"map_002_l_usine.json": 3601754003,
	"map_003_la_croisee.json": 3954334292,
	"map_004_le_bunker.json": 2374969690,
}
const LACETS := [0.0, 45.0, -45.0, 30.0, 60.0, 90.0, 135.0, 180.0, -120.0]
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
	print("=== LES TUYAUX ET LES CÂBLES DES MURS, EN ESSAI ===")
	await process_frame
	for f in DirAccess.get_files_at("res://assets/maps"):
		if f.ends_with(".json"):
			_cartes[f] = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/" + f))
	_check("les cartes livrées sont là (%d)" % _cartes.size(), _cartes.size() >= 6)
	await _le_drapeau()
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
	_check("--tuyaux-essai n'est pas sur la ligne de commande de la suite", not TuyauxIsoT.essai_actif())
	var texte := FileAccess.get_file_as_string("res://presentation_3d.gd")
	_check("la présentation lit le drapeau une fois", texte.contains("var _tuyaux := TuyauxIsoT.essai_actif()"))
	_check("éteint, `_construire_les_tuyaux` sort avant tout matériau et tout nœud",
		texte.contains("\tif not _tuyaux:\n\t\treturn\n\tif _mat_tuyaux == null:"))
	_check("les murs appellent les tuyaux à chaque construction (une carte neuve, des tuyaux neufs)",
		texte.contains("\t_scene.add_child(_murs)\n\t_construire_les_tuyaux(data)\n"))
	var Pres: GDScript = load("res://presentation_3d.gd")
	var p: Node = Pres.new()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(p)
	await process_frame
	var avant: Array = p.call("_materiaux")
	p.call("_construire_les_murs")
	var scene: Node3D = p.get("_scene")
	_check("drapeau éteint : aucun nœud de tuyaux dans la scène iso",
		scene.get_node_or_null(TuyauxIsoT.NOM_NOEUD) == null and p.get("_noeud_tuyaux") == null)
	_check("drapeau éteint : aucun matériau de tuyaux, les matériaux d'avant",
		p.get("_mat_tuyaux") == null and (p.call("_materiaux") as Array).size() == avant.size())
	# Allumé à la main, comme le ferait `--tuyaux-essai` lu au démarrage.
	p.set("_tuyaux", true)
	p.call("_construire_les_murs")
	var noeud: MeshInstance3D = p.get("_noeud_tuyaux")
	_check("drapeau allumé : un nœud nommé dans la scène iso",
		noeud != null and noeud.get_parent() == scene and noeud.name == TuyauxIsoT.NOM_NOEUD)
	if noeud != null:
		var commun: int = Pres.get_script_constant_map()["CALQUE_COMMUN"]
		_check("sur le calque commun, que les caméras des DEUX joueurs rendent",
			noeud.layers == commun and (commun | Pres._calque_de(0)) & noeud.layers != 0
			and (commun | Pres._calque_de(1)) & noeud.layers != 0)
		_check("aucune ombre, ni portée ni reçue d'une lumière 3D",
			noeud.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and noeud.gi_mode == GeometryInstance3D.GI_MODE_DISABLED)
		_check("un seul maillage d'UNE surface : un appel de dessin par vue",
			noeud.mesh != null and noeud.mesh.get_surface_count() == 1)
		var mat := noeud.material_override as ShaderMaterial
		_check("son matériau porte le shader des tuyaux et suit la présentation (lightmaps, pâte, canevas)",
			mat != null and mat.shader == TuyauxIsoT.SHADER and (p.call("_materiaux") as Array).has(mat))
		_check("rien sous `_murs` : les boîtes y prennent les ombres de la lumière 3D, un tuyau jamais",
			(p.get("_murs") as Node).get_node_or_null(TuyauxIsoT.NOM_NOEUD) == null)
	p.set("_tuyaux", false)
	p.call("_construire_les_murs")
	await process_frame
	_check("éteint de nouveau : le nœud est retiré", p.get("_noeud_tuyaux") == null
		and scene.get_node_or_null(TuyauxIsoT.NOM_NOEUD) == null)
	p.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# LES CONSTRUCTIONS — carte par carte
# ---------------------------------------------------------------------------

func _les_constructions() -> void:
	print("— la construction, carte par carte")
	var script := FileAccess.get_file_as_string("res://tuyaux_iso.gd")
	_check("aucun tirage non semé dans le script (randf, randi, RandomNumberGenerator)",
		not script.contains("randf(") and not script.contains("randi(") and not script.contains("_range(") and not script.contains("RandomNumberGenerator"))
	var h_mur := TuyauxIsoT.hauteur_mur_px()
	var h_max := TuyauxIsoT.hauteur_max_px()
	var h_bas := TuyauxIsoT.hauteur_bas_px()
	var tan_t := tan(deg_to_rad(CameraIso.TANGAGE_DEG))
	_check("la hauteur permise reste sous l'arête d'une saillie vue sous le tangage (%.2f ≤ %.2f − %.2f × %.3f)" % [
		h_max, h_mur, TuyauxIsoT.SAILLIE_MAX, tan_t], h_max <= h_mur - TuyauxIsoT.SAILLIE_MAX * tan_t + EPS and h_max > h_bas)
	_check("la marge aux bouts couvre le décalage d'une saillie vue à 60° de biais",
		TuyauxIsoT.MARGE_BOUT >= TuyauxIsoT.SAILLIE_MAX * tan(acos(TuyauxIsoT.SEUIL_FACE)))
	var tres_dessinees := {}
	var total_sommets := 0
	for nom in _cartes:
		var data: Dictionary = _cartes[nom]
		var c := TuyauxIsoT.construire(data)
		var c2 := TuyauxIsoT.construire(data)
		var sommets: PackedVector3Array = c["sommets"]
		total_sommets += sommets.size()
		_check("%s : la même construction deux fois, au bit près" % nom,
			sommets == c2["sommets"] and c["indices"] == c2["indices"] and c["uv"] == c2["uv"] and c["uv2"] == c2["uv2"])
		var empreinte := _empreinte(c)
		print("    empreinte %s = %d  (%s, %d sommets, %d triangles)" % [nom, empreinte, str(c["compte"]), sommets.size(),
			(c["indices"] as PackedInt32Array).size() / 3])
		if EMPREINTES.has(nom):
			_check("%s : l'empreinte du placement est celle figée" % nom, int(EMPREINTES[nom]) == empreinte,
				"%d au lieu de %d" % [empreinte, int(EMPREINTES[nom])])
		_une_carte(nom, data, c, h_mur, h_max, h_bas, tres_dessinees)
	_check("les cartes livrées portent des tuyaux (%d sommets)" % total_sommets, total_sommets > 1000)
	_check("à 0° de lacet, la caméra ne dessine que les tuyaux des faces SUD",
		tres_dessinees.get(0.0, []) == [Vector2(0, 1)], str(tres_dessinees.get(0.0, [])))
	var a45: Array = tres_dessinees.get(45.0, [])
	_check("à 45°, ceux de DEUX faces par mur (sud et est)", a45.size() == 2 and a45.has(Vector2(0, 1))
		and a45.has(Vector2(1, 0)), str(a45))
	_check("à 180° (l'option B de J2), ceux des faces NORD seules", tres_dessinees.get(180.0, []) == [Vector2(0, -1)],
		str(tres_dessinees.get(180.0, [])))


## L'empreinte du PLACEMENT : la clé, le programme et le nombre de sommets de chaque face meublée, en texte — ni trigonométrie
## ni flottant, donc la même sur chaque machine.
func _empreinte(c: Dictionary) -> int:
	var par_face := {}
	for i in (c["face_de_sommet"] as PackedInt32Array):
		par_face[i] = int(par_face.get(i, 0)) + 1
	var texte := ""
	var faces: Array = c["faces"]
	for i in faces.size():
		var f: Dictionary = faces[i]
		texte += "%s:%d:%d;" % [str(f["cle"]), TuyauxIsoT.programme_de(f), int(par_face.get(i, 0))]
	return texte.hash()


func _une_carte(nom: String, data: Dictionary, c: Dictionary, h_mur: float, h_max: float, h_bas: float,
		tres_dessinees: Dictionary) -> void:
	var sommets: PackedVector3Array = c["sommets"]
	var normales: PackedVector3Array = c["normales"]
	var indices: PackedInt32Array = c["indices"]
	var faces: Array = c["faces"]
	var face_de: PackedInt32Array = c["face_de_sommet"]
	var uv: PackedVector2Array = c["uv"]
	var uv2: PackedVector2Array = c["uv2"]
	var rects := IsoGeometrie.rects_px(data, MapGeometry.Kind.WALLS)
	# Le sol devant chaque face meublée : ni mur haut, ni muret, ni fosse (ni la ceinture, qui en est une).
	var hauts := MapGeometry.build_grid(data, MapGeometry.Kind.WALLS)
	var fosses := MapGeometry.build_grid(data, MapGeometry.Kind.PITS)
	var bas := MapGeometry.build_grid(data, MapGeometry.Kind.LOW_WALLS)
	var tuile := float(CandelaTileSet.TILE_SIZE.x)
	var sol_devant := true
	for f in faces:
		var n: Vector2 = f["n"]
		var t := Vector2(-n.y, n.x)
		var s := (float(f["s0"]) + float(f["s1"])) * 0.5
		var devant := n * (float(f["d"]) + tuile * 0.5) + t * s
		var cellule := Vector2i((devant / tuile).floor()) + Vector2i(MapGeometry.BORDER, MapGeometry.BORDER)
		if bool(hauts[cellule.x][cellule.y]) or bool(fosses[cellule.x][cellule.y]) or bool(bas[cellule.x][cellule.y]):
			sol_devant = false
	_check("%s : chaque face meublée a du sol devant elle" % nom, sol_devant)
	var trop_haut := 0
	var trop_bas := 0
	var hors_emprise := 0
	var hors_face := 0
	var premier_hors_face := ""
	var donnees := 0
	var y_max := -INF
	for k in sommets.size():
		var p := sommets[k]
		var f: Dictionary = faces[face_de[k]]
		var n: Vector2 = f["n"]
		var t := Vector2(-n.y, n.x)
		y_max = maxf(y_max, p.y)
		if p.y > h_max + EPS:
			trop_haut += 1
		if p.y < h_bas - EPS:
			trop_bas += 1
		var xz := Vector2(p.x, p.z)
		var ecart := xz.dot(n) - float(f["d"])
		var s := xz.dot(t)
		if ecart < -EPS or ecart > TuyauxIsoT.SAILLIE_MAX + EPS \
				or s < float(f["s0"]) + TuyauxIsoT.MARGE_BOUT - EPS or s > float(f["s1"]) - TuyauxIsoT.MARGE_BOUT + EPS:
			hors_face += 1
			if premier_hors_face == "":
				premier_hors_face = "%s : écart %.3f, s %.3f dans [%.3f, %.3f]" % [str(p), ecart, s,
					float(f["s0"]) + TuyauxIsoT.MARGE_BOUT, float(f["s1"]) - TuyauxIsoT.MARGE_BOUT]
		var proche := INF
		for r in rects:
			var d := (xz - r.get_center()).abs() - r.size * 0.5
			proche = minf(proche, Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length())
		if proche > TuyauxIsoT.SAILLIE_MAX + EPS:
			hors_emprise += 1
		if uv2[k] != n or not is_equal_approx(uv[k].x, float(f["d"])) or uv[k].y <= 0.0 or uv[k].y > 1.0:
			donnees += 1
	_check("%s : aucun sommet au-dessus de %.2f px (arête à %.2f ; le plus haut : %.2f)" % [nom, h_max, h_mur, y_max],
		trop_haut == 0, "%d sommets" % trop_haut)
	_check("%s : aucun sommet sous %.2f px (la bande de sol au pied)" % [nom, h_bas], trop_bas == 0, "%d sommets" % trop_bas)
	_check("%s : chaque sommet devant SA face, à %.1f px au plus, à %.0f px au moins de ses bouts" % [nom,
		TuyauxIsoT.SAILLIE_MAX, TuyauxIsoT.MARGE_BOUT], hors_face == 0, "%d sommets ; %s" % [hors_face, premier_hors_face])
	_check("%s : chaque sommet dans l'emprise des murs hauts, à %.1f px près" % [nom, TuyauxIsoT.SAILLIE_MAX],
		hors_emprise == 0, "%d sommets" % hors_emprise)
	_check("%s : chaque sommet porte le plan et la normale de sa face, et une matière dans ]0, 1]" % nom, donnees == 0,
		"%d sommets" % donnees)
	# L'enroulement : la convention du moteur lue sur une `BoxMesh`, puis chaque triangle des tubes comparé à elle.
	var boite := BoxMesh.new().get_mesh_arrays()
	var bv: PackedVector3Array = boite[Mesh.ARRAY_VERTEX]
	var bn: PackedVector3Array = boite[Mesh.ARRAY_NORMAL]
	var bi: PackedInt32Array = boite[Mesh.ARRAY_INDEX]
	var signe := signf((bv[bi[1]] - bv[bi[0]]).cross(bv[bi[2]] - bv[bi[0]]).dot(bn[bi[0]]))
	var retournes := 0
	for k in range(0, indices.size(), 3):
		var a := sommets[indices[k]]
		var geo := (sommets[indices[k + 1]] - a).cross(sommets[indices[k + 2]] - a)
		if geo.length() < 1e-9:
			continue
		var moyenne := normales[indices[k]] + normales[indices[k + 1]] + normales[indices[k + 2]]
		if signf(geo.dot(moyenne)) != signe:
			retournes += 1
	_check("%s : chaque triangle a sa face avant du côté de ses normales (convention d'une BoxMesh)" % nom,
		retournes == 0 and signe != 0.0, "%d triangles retournés" % retournes)
	# À l'écran : le tri du shader, puis le rayon prolongé derrière chaque sommet dessiné.
	for lacet in LACETS:
		var z := CameraIso.transform_pour(Transform2D.IDENTITY, Vector2(1920, 1080), CameraIso.TANGAGE_DEG, lacet).basis.z
		var h := Vector2(z.x, z.z).normalized()
		var dessinees: Array = []
		var desaccords := 0
		var hors := 0
		var pire := ""
		for i in faces.size():
			var n: Vector2 = faces[i]["n"]
			var voit := n.dot(h) >= TuyauxIsoT.SEUIL_FACE
			if voit != TuyauxIsoT.face_dessinee(n, lacet):
				desaccords += 1
			if voit and not dessinees.has(n):
				dessinees.append(n)
		for k in sommets.size():
			var f: Dictionary = faces[face_de[k]]
			var n: Vector2 = f["n"]
			if not TuyauxIsoT.face_dessinee(n, lacet):
				continue
			var p := sommets[k]
			var approche := Vector2(z.x, z.z).dot(n)
			var q := p - z * ((Vector2(p.x, p.z).dot(n) - float(f["d"])) / approche)
			var s := Vector2(q.x, q.z).dot(Vector2(-n.y, n.x))
			if q.y > h_mur - EPS or q.y < 0.0 or s < float(f["s0"]) - EPS or s > float(f["s1"]) + EPS:
				hors += 1
				if pire == "":
					pire = "sommet %s → face (s %.2f dans [%.2f, %.2f], y %.2f)" % [str(p), s, float(f["s0"]), float(f["s1"]), q.y]
		_check("%s, lacet %s° : le tri du shader et la base réelle de la caméra disent les mêmes faces" % [nom, str(lacet)],
			desaccords == 0)
		_check("%s, lacet %s° : derrière chaque sommet dessiné, SA face — sous l'arête, au-dessus du sol, entre ses bouts" % [
			nom, str(lacet)], hors == 0, "%d sommets ; %s" % [hors, pire])
		if not tres_dessinees.has(lacet):
			tres_dessinees[lacet] = []
		for n in dessinees:
			if not (tres_dessinees[lacet] as Array).has(n):
				(tres_dessinees[lacet] as Array).append(n)


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
	var code := (TuyauxIsoT.SHADER as Shader).code
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
	_check("la matière plafonnée par la plus sombre d'une face", corps.contains("min(albedo, matiere_max)"))
	var sommet := _fonction(code, "void vertex() {")
	_check("une face vue de profil ou de dos : ses tuyaux écrasés en un point",
		sommet.contains("if (vue < seuil_face) {") and sommet.contains("VERTEX = vec3(0.0);"))
	var m := ShaderMaterial.new()
	m.shader = TuyauxIsoT.SHADER
	TuyauxIsoT.accorder(m)
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
		is_equal_approx(float(m.get_shader_parameter("seuil_face")), TuyauxIsoT.SEUIL_FACE)
		and m.get_shader_parameter("emprise_preuve") == false)
	var plus_sombre := lerpf(1.0, IsoMateriaux.PLANCHER, float(mur_mat.get_shader_parameter("force_matiere")))
	_check("accordé : la matière plafonnée à %.3f, la plus sombre qu'une face porte" % plus_sombre,
		absf(float(m.get_shader_parameter("matiere_max")) - plus_sombre) < 0.0005)
	# Les tuyaux ne suivent pas le lambert des faces (éteint, plancher 1) : s'il s'allume, une face de profil s'assombrirait
	# sous des tuyaux qui, eux, ne s'assombriraient pas — plus clairs que leur face. Les rebrancher avant de l'allumer.
	_check("le lambert des faces est éteint (plancher 1) : les tuyaux n'ont pas à le suivre",
		is_equal_approx(IsoMateriaux.LAMBERT_PLANCHER, 1.0))
