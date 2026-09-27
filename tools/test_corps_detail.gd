## ISO13 — le personnage détaillé à l'essai (`--corps-detaille` ; le pistolet le 2026-09-24, les six classes à bouteille le
## 2026-09-25 (Q29), les dix classes depuis Q33, 2026-09-26 ; chantier d'ISO7 Beauté).
##
## Ce que la suite prouve, sans fenêtre :
## - **le drapeau** : éteint par défaut ; sans lui, le pistolet garde ses dix boîtes et le shader d'origine, qui ne déclare
##   rien du détail ;
## - **les accessoires** : le kit de chacune des dix classes (Q33), d'une boîte (le Terrassier, sa plaque) à onze (le Parasite) ; des demi-tailles distinctes entre elles et de
##   celles du corps (le shader les reconnaît à leur taille) ; le compte d'appels de dessin et de triangles ajoutés ;
## - **la bandoulière dans le torse** (Q29, le défaut de l'essai) : largeur comprise, dans le rectangle de la face du torse,
##   pour chaque classe — et la garde VUE ROUGIR sur la longueur de l'essai du 24/09 ;
## - **la silhouette** : pour chaque classe détaillée, le corps seul, accessoires compris, dans le couloir de 17,5 px (sous la
##   zone de touche de 18 px), debout et accroupi, à seize visées — et la garde VUE ROUGIR : une boîte posée hors du couloir est bien refusée ;
## - **la visibilité** : les couleurs des accessoires, à un rapport ≤ 1 du gris de la classe ; la matière peinte ne fait
##   qu'assombrir (pores et marbrage < 1) ; albédo seul, ni `light()` ni émission ; `Protocol.VERSION` 18.
##
## Ce qu'elle ne prouve pas : l'image. La planche du pistolet (banc des lumières et banc des corps) la mesure.
##
## Lancer : godot --headless --path . --script res://tools/test_corps_detail.gd
extends SceneTree

const PLANCHER := 44
const TUILE_PX := 35.0
const COULOIR_PX := 17.5
const TOUCHE_PX := 18.0
## Q29 — le kit de chaque classe détaillée (voir `VoxelCatalogue.KIT_DETAIL`).
const KIT := {"pistolet": 11, "occulteur": 10, "spectre": 10, "sentinelle": 9, "incendiaire": 9, "allumeur": 9,
	"fusil": 5, "pompe": 1, "arbalete": 4, "fumiste": 6}

var _echecs := 0
var _verifications := 0


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
	print("=== ISO13 — LE PERSONNAGE DÉTAILLÉ À L'ESSAI ===")
	await process_frame
	var racine := Node3D.new()
	root.add_child(racine)
	_le_drapeau(racine)
	_les_accessoires(racine)
	_la_fusion(racine)
	_la_pre_passe(racine)
	_la_bandouliere(racine)
	_la_silhouette(racine)
	_la_visibilite()
	VoxelCatalogue.forcer_detail = -1
	VoxelCatalogue.forcer_tenue = "-"
	racine.queue_free()
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	print("%d vérifications, %d échec(s)" % [_verifications, _echecs])
	quit(1 if _echecs > 0 else 0)


func _corps(racine: Node3D, slug: String, detail: bool) -> VoxelCorps:
	VoxelCatalogue.forcer_tenue = "sombre3"
	VoxelCatalogue.forcer_detail = 1 if detail else 0
	var c := VoxelCorps.new()
	racine.add_child(c)
	c.construire(slug)
	return c


func _noms(sh: Shader) -> Array:
	var noms := []
	for u in sh.get_shader_uniform_list():
		noms.append(String(u["name"]))
	return noms


func _le_drapeau(racine: Node3D) -> void:
	print("— le drapeau : éteint par défaut")
	VoxelCatalogue.forcer_detail = -1
	_check("--corps-detaille n'est pas sur la ligne de commande de la suite", not VoxelCatalogue.detail_actif())
	var sans := _corps(racine, "pistolet", false)
	_check("sans drapeau : le pistolet garde ses dix boîtes (%d)" % sans.nombre_de_boites(), sans.nombre_de_boites() == 10
		and sans.details().is_empty())
	_check("sans drapeau : le shader d'origine, qui ne déclare rien du détail",
		sans.materiau().shader == load("res://corps_iso.gdshader") and not _noms(sans.materiau().shader).has("detail"))
	for chemin in ["res://corps_iso.gdshader", "res://corps_iso_eclaire.gdshader"]:
		var v := IsoMateriaux.variante_definie(load(chemin), "CORPS_DETAIL")
		var noms := _noms(v)
		_check("%s : la variante CORPS_DETAIL compile et déclare le détail" % chemin.get_file(),
			noms.has("detail") and noms.has("detail_demi") and noms.has("detail_matiere"))
	var m := ShaderMaterial.new()
	m.shader = load("res://corps_iso_eclaire.gdshader")
	VoxelCatalogue.forcer_detail = 1
	IsoMateriaux.accorder_corps(m)
	_check("accorder_corps garde la variante après un changement de shader (la lumière 3D)", m.shader.code.contains("#define CORPS_DETAIL\n"))
	VoxelCatalogue.forcer_detail = 0
	var m2 := ShaderMaterial.new()
	m2.shader = load("res://corps_iso.gdshader")
	IsoMateriaux.accorder_corps(m2)
	_check("drapeau éteint : accorder_corps laisse le shader d'origine", m2.shader == load("res://corps_iso.gdshader"))


func _les_accessoires(racine: Node3D) -> void:
	print("— les accessoires modelés")
	_check("les dix classes sont détaillées (Q33), et chacune a son kit",
		VoxelCatalogue.CLASSES_DETAILLEES.size() == 10 and VoxelCatalogue.slugs().size() == 10
		and KIT.keys().all(func(k): return VoxelCatalogue.CLASSES_DETAILLEES.has(k) and VoxelCatalogue.KIT_DETAIL.has(k)))
	for slug in KIT:
		_le_kit(racine, slug, int(KIT[slug]))


func _le_kit(racine: Node3D, slug: String, attendus: int) -> void:
	var avec := _corps(racine, slug, true)
	var sans := _corps(racine, slug, false)
	var n_sans := sans.nombre_de_boites()
	var pieces := avec.pieces_detail()
	var porteurs := {}
	for p in pieces:
		porteurs[p["parent"]] = true
	# Q33 : fusionnés, les accessoires sont un maillage par pièce qui les porte, et aucune boîte de plus.
	_check("%s détaillé : %d accessoires, en %d maillages fusionnés (un par pièce porteuse), aucune boîte de plus (%d)"
		% [slug, pieces.size(), avec.details().size(), avec.nombre_de_boites()],
		pieces.size() == attendus and avec.details().size() == porteurs.size() and avec.nombre_de_boites() == n_sans)
	# Les demi-tailles : celles des accessoires, et celles des boîtes du corps sans eux.
	var du_corps := []
	for b in sans.boites():
		du_corps.append(((b as MeshInstance3D).mesh as BoxMesh).size * 0.5)
	var confondues := []
	var tailles := {}
	for p in pieces:
		var d: Vector3 = (p["taille"] as Vector3) * 0.5
		for r in du_corps:
			if d.distance_to(r) < 0.001:
				confondues.append(String(p["nom"]))
		tailles[String(p["nom"]).rstrip("0123456789")] = p["taille"]
	var distinctes := {}
	for k in tailles:
		distinctes[str(tailles[k])] = true
	var n_shader := int(avec.materiau().get_shader_parameter("detail_n"))
	# Le coût : chaque maillage fusionné, un appel de couleur et un de profondeur.
	var mi_avec := avec.find_children("*", "MeshInstance3D", true, false).size()
	var mi_sans := sans.find_children("*", "MeshInstance3D", true, false).size()
	print("  %s : %d sortes, detail_n = %d ; COÛT %d appels de dessin de plus par corps (%d séparés)"
		% [slug, tailles.size(), n_shader, mi_avec - mi_sans, 2 * attendus])
	_check("%s : aucune taille confondue avec le corps, une par sorte, toutes connues du shader (%d ≤ 10), %d appels de plus (≤ 6)"
		% [slug, n_shader, mi_avec - mi_sans],
		confondues.is_empty() and tailles.size() == distinctes.size() and n_shader == distinctes.size() and n_shader <= 10
		and mi_avec - mi_sans == 2 * porteurs.size() and mi_avec - mi_sans <= 6, str(confondues))
	_check("%s : chaque maillage et chaque accessoire suivent une pièce animée (torse, bouteille, arme)" % slug,
		avec.details().all(func(b): return ["Torse", "Bouteille", "Arme"].has(String((b as Node).get_parent().name)))
		and pieces.all(func(p): return ["Torse", "Bouteille", "Arme"].has(String((p["parent"] as Node).name))))


## Q33 — les deux façons de dessiner le même kit : séparées (une boîte, deux appels chacune) et fusionnées. Même description,
## même coût annoncé ; le maillage fusionné porte la boîte d'origine de chaque sommet (CUSTOM0, w = 2 ; CUSTOM1).
func _la_fusion(racine: Node3D) -> void:
	print("— la fusion des accessoires")
	VoxelCatalogue.forcer_fusion = 0
	var separe := _corps(racine, "pistolet", true)
	VoxelCatalogue.forcer_fusion = -1
	var fusionne := _corps(racine, "pistolet", true)
	var sans := _corps(racine, "pistolet", false)
	var mi := func(c): return c.find_children("*", "MeshInstance3D", true, false).size()
	var ps: Array = separe.pieces_detail()
	var pf: Array = fusionne.pieces_detail()
	var memes := ps.size() == pf.size()
	for i in mini(ps.size(), pf.size()):
		memes = memes and String(ps[i]["nom"]) == String(pf[i]["nom"]) and (ps[i]["taille"] as Vector3).is_equal_approx(pf[i]["taille"])
	_check("séparés et fusionnés : le même kit (%d pièces), %d contre %d appels de dessin de plus" % [pf.size(),
		mi.call(separe) - mi.call(sans), mi.call(fusionne) - mi.call(sans)],
		memes and mi.call(separe) - mi.call(sans) == 2 * ps.size() and mi.call(fusionne) - mi.call(sans) == 6)
	var m: ArrayMesh = (fusionne.details()[0] as MeshInstance3D).mesh
	var a := m.surface_get_arrays(0)
	var c0: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM0]
	var nv: int = (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var marques := c0.size() == nv * 4
	for i in nv:
		marques = marques and c0[i * 4 + 3] > 5.0 and absf(c0[i * 4 + 3] - 10.0) <= PI
	var fmt := m.surface_get_format(0)
	# Et la normale locale se retrouve en tournant NORMAL de −angle : vérifié ici sur chaque sommet, contre la BoxMesh d'origine.
	var nor: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var retrouvees := true
	for i in nv:
		var ang := c0[i * 4 + 3] - 10.0
		var n := nor[i]
		var nl := Vector3(cos(ang) * n.x + sin(ang) * n.y, -sin(ang) * n.x + cos(ang) * n.y, n.z)
		retrouvees = retrouvees and absf(absf(nl.x) + absf(nl.y) + absf(nl.z) - 1.0) < 0.001
	_check("le maillage fusionné porte la boîte de chaque sommet : CUSTOM0 en flottants (RGBA_FLOAT), w = 10 + angle ; pas de CUSTOM1 ; la normale locale retrouvée sur un axe",
		marques and retrouvees and ((fmt >> Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) & Mesh.ARRAY_FORMAT_CUSTOM_MASK) == Mesh.ARRAY_CUSTOM_RGBA_FLOAT
		and (fmt & Mesh.ARRAY_FORMAT_CUSTOM1) == 0)
	for chemin in ["res://corps_iso.gdshader", "res://corps_iso_eclaire.gdshader"]:
		var code := FileAccess.get_file_as_string(chemin)
		var v := code.substr(code.find("void vertex()"), code.find("void fragment()") - code.find("void vertex()"))
		_check("%s : le sommet relit sa boîte sous CORPS_DETAIL seulement (le shader d'origine inchangé sans drapeau)"
			% chemin.get_file(), v.contains("#ifdef CORPS_DETAIL\n\t// Q33") and v.contains("if (CUSTOM0.w > 5.0) {")
			and not v.contains("CUSTOM1.")
			and v.contains("demi = abs(CUSTOM0.xyz);"))


## Q33 — la pré-passe de profondeur d'un corps détaillé est LE MÊME programme que sa couleur (ordre 424 : avec deux
## programmes, llvmpipe effaçait des pièces entières). Elle le reste quand la lumière 3D change le shader de la couleur.
func _la_pre_passe(racine: Node3D) -> void:
	print("— la pré-passe : le même programme que la couleur")
	var sans := _corps(racine, "occulteur", false)
	_check("sans drapeau : la pré-passe garde le shader de profondeur ordinaire",
		sans.materiau_profondeur().shader == load("res://corps_iso_profondeur.gdshader"))
	var avec := _corps(racine, "occulteur", true)
	var m := avec.materiau()
	var mp := avec.materiau_profondeur()
	_check("détaillé : la pré-passe porte le programme de la couleur (variante CORPS_DETAIL), passe_profondeur 1 pour elle, 0 pour la couleur",
		mp.shader == m.shader and m.shader.code.contains("#define CORPS_DETAIL\n")
		and mp.get_shader_parameter("passe_profondeur") == 1.0
		and (m.get_shader_parameter("passe_profondeur") == null or m.get_shader_parameter("passe_profondeur") == 0.0)
		and mp.render_priority == -1)
	# La lumière 3D : la présentation pose le shader éclairé puis rappelle `accorder_corps` ; la pré-passe doit suivre.
	VoxelCatalogue.forcer_detail = 1
	m.shader = load("res://corps_iso_eclaire.gdshader")
	IsoMateriaux.accorder_corps(m)
	_check("la lumière 3D : après accorder_corps, la pré-passe porte encore le programme de la couleur (la variante éclairée)",
		mp.shader == m.shader and m.shader.code.contains("#define CORPS_DETAIL\n") and m.shader.code.contains("void light()"))
	for chemin in ["res://corps_iso.gdshader", "res://corps_iso_eclaire.gdshader"]:
		var code := FileAccess.get_file_as_string(chemin)
		var debut := code.substr(code.find("void fragment() {"), 200)
		_check("%s : le fragment commence par la sortie de pré-passe, sous CORPS_DETAIL seulement" % chemin.get_file(),
			debut.begins_with("void fragment() {\n#ifdef CORPS_DETAIL") and code.contains("	if (passe_profondeur > 0.5) {")
			and code.contains("		ALPHA = 0.0;\n	} else {\n#endif") and code.contains("#ifdef CORPS_DETAIL\n	}\n#endif\n}"))


## Le débord d'une boîte tournée de `angle` autour de z, centrée en `centre` (repère du torse), hors du rectangle de la face :
## x dans [−lt/2, lt/2], y dans [0, ht]. 0 si elle tient.
func _debord(taille: Vector3, centre: Vector3, angle: float, lt: float, ht: float) -> float:
	var dx := taille.x * 0.5 * absf(cos(angle)) + taille.y * 0.5 * absf(sin(angle))
	var dy := taille.x * 0.5 * absf(sin(angle)) + taille.y * 0.5 * absf(cos(angle))
	return maxf(0.0, maxf(maxf(absf(centre.x) + dx - lt * 0.5, centre.y + dy - ht), -(centre.y - dy)))


func _la_bandouliere(racine: Node3D) -> void:
	print("— les pièces du torse dans sa face (la bandoulière : le défaut de l'essai)")
	for slug in KIT:
		var c := _corps(racine, slug, true)
		var f := VoxelCatalogue.fiche(slug)
		var lt := float(f["largeur_torse"]) * float(f["echelle"])
		var ht := float(f["hauteur_torse"])
		var pire := 0.0
		var n := 0
		for p in c.pieces_detail():
			if String((p["parent"] as Node).name) != "Torse":
				continue
			n += 1
			pire = maxf(pire, _debord(p["taille"], p["position"], float(p["angle"]), lt, ht))
		_check("%s : les %d pièces du torse, largeur comprise, dans sa face (débord %.4f tuile)" % [slug, n, pire],
			pire <= 0.0001 and n >= 1)
	# Q33 — aucune paire de pièces du torse dont les faces avant se recouvrent à la MÊME profondeur (ordre 426 : la plaque et la
	# bretelle de l'Illusionniste, face avant à 0,012 toutes deux ; l'ordre de tracé choisissait, et les deux dessins non pareil).
	var egalites := []
	for slug in KIT:
		egalites.append_array(_pieces_a_egalite(_corps(racine, slug, true).pieces_detail(), slug))
	_check("aucune paire de pièces du torse ne se recouvre à la même profondeur (face avant à 0,5 millième près), pour les dix",
		egalites.is_empty(), str(egalites))
	var faux := [{"nom": "Plaque", "parent": null, "taille": Vector3(0.065, 0.065, 0.012), "position": Vector3(-0.1, 0.27, -0.006),
		"angle": 0.0}, {"nom": "Bretelle1", "parent": null, "taille": Vector3(0.035, 0.32, 0.012), "position": Vector3(-0.11, 0.17, -0.006),
		"angle": 0.0}]
	_check("la garde rougit sur l'ancienne plaque de l'Illusionniste (à la profondeur de sa bretelle)",
		not _pieces_a_egalite(faux, "essai", false).is_empty())
	# La garde vue rougir : la longueur de l'essai du 24/09 (lt / cos × 0,98, sans la largeur) déborde.
	var f := VoxelCatalogue.fiche("pistolet")
	var lt := float(f["largeur_torse"]) * float(f["echelle"])
	var ht := float(f["hauteur_torse"])
	var angle := atan(-0.9 * (ht * 0.5) / (lt * 0.5))
	var ancienne := lt / cos(angle) * 0.98
	var debord := _debord(Vector3(ancienne, VoxelCorps.LARGEUR_BANDOULIERE, 0.014), Vector3(0, ht * 0.5, 0), angle, lt, ht)
	_check("la garde rougit sur la longueur de l'essai (%.3f → débord %.4f tuile ; aujourd'hui %.3f)"
		% [ancienne, debord, VoxelCorps.longueur_bandouliere(lt, ht, angle, VoxelCorps.LARGEUR_BANDOULIERE)], debord > 0.005)


## Les paires de pièces du torse dont les rectangles de face (x, y ; boîte englobante de la pièce tournée) se recouvrent et dont
## les faces avant sont à la même profondeur (z − demi-épaisseur, à 0,5 millième de tuile près).
func _pieces_a_egalite(pieces: Array, slug: String, filtrer := true) -> Array:
	var faces := []
	for p in pieces:
		if filtrer and String((p["parent"] as Node).name) != "Torse":
			continue
		var t: Vector3 = p["taille"]
		var a := float(p["angle"])
		var dx := t.x * 0.5 * absf(cos(a)) + t.y * 0.5 * absf(sin(a))
		var dy := t.x * 0.5 * absf(sin(a)) + t.y * 0.5 * absf(cos(a))
		var c: Vector3 = p["position"]
		faces.append([String(p["nom"]), Rect2(c.x - dx, c.y - dy, 2.0 * dx, 2.0 * dy), c.z - t.z * 0.5])
	var out := []
	for i in faces.size():
		for j in range(i + 1, faces.size()):
			if absf(float(faces[i][2]) - float(faces[j][2])) < 0.0005 and (faces[i][1] as Rect2).intersects(faces[j][1]):
				out.append("%s : %s / %s" % [slug, faces[i][0], faces[j][0]])
	return out


## Le pire rayon du corps seul (accessoires compris), debout et accroupi, à seize visées, en pixels du monde.
func _pire_rayon(c: VoxelCorps) -> float:
	var pire := 0.0
	for k in 16:
		var visee := Vector2.DOWN.rotated(TAU * float(k) / 16.0)
		var etat := {"position": Vector2.ZERO, "visee": visee, "vitesse": Vector2.ZERO, "torche": true, "arme": c.slug(),
			"tir": false, "touche": false, "mort": false, "t": 0.0}
		c.poser(etat)
		pire = maxf(pire, c.rayon_empreinte(true))
		etat["accroupi"] = true
		etat["t"] = 1.0
		c.poser(etat)
		pire = maxf(pire, c.rayon_empreinte(true))
	return pire * TUILE_PX


func _la_silhouette(racine: Node3D) -> void:
	print("— la silhouette dans le couloir")
	for slug in KIT:
		var r_sans := _pire_rayon(_corps(racine, slug, false))
		var r_avec := _pire_rayon(_corps(racine, slug, true))
		print("  SILHOUETTE %s, corps seul : %.2f px sans accessoires, %.2f px avec" % [slug, r_sans, r_avec])
		_check("%s : accessoires compris, dans le couloir (%.2f ≤ %.1f px), sous la zone de touche (%.0f px), pas plus large (%.2f)"
			% [slug, r_avec, COULOIR_PX, TOUCHE_PX, r_sans],
			r_avec <= COULOIR_PX + 0.01 and r_avec < TOUCHE_PX and r_avec <= r_sans + 0.01)
	# La garde vue rougir : l'étui du pistolet déplacé à 0,6 tuile du centre doit être refusé par la même mesure.
	var faux := _corps(racine, "pistolet", true)
	for p in faux.pieces_detail():
		if String(p["nom"]) == "Etui":
			p["position"] = Vector3(0.6, (p["position"] as Vector3).y, (p["position"] as Vector3).z)
	var r_faux := _pire_rayon(faux)
	_check("la garde rougit sur une boîte hors du couloir (%.2f px > %.1f)" % [r_faux, COULOIR_PX], r_faux > COULOIR_PX + 0.01)


func _la_visibilite() -> void:
	print("— la visibilité : la couleur, jamais plus claire")
	var sous := true
	for slug in KIT:
		var l := VoxelCatalogue.luminance_affichee(VoxelCatalogue.fiche(slug)["couleur"])
		var p := VoxelCatalogue.palette_details(slug, "sombre3", "froide")
		sous = sous and p.size() == 4
		for cle in p:
			sous = sous and VoxelCatalogue.luminance_affichee(p[cle]) <= l + 0.002
	_check("cuir, laiton, métal et cartouches à un rapport ≤ 1 du gris de leur classe, pour les dix", sous)
	var pf := VoxelCatalogue.palette_details("fumiste", "sombre3", "froide")
	var tf := VoxelCatalogue.palette_tenue("fumiste", "sombre3", "froide")
	_check("Q33 : les cartouches du kit ont la couleur des cartouches de la tenue (grises pour le Fumiste), pas le métal",
		(pf["cartouche"] as Color).is_equal_approx(Color((tf["cartouche"] as Color).r, (tf["cartouche"] as Color).g, (tf["cartouche"] as Color).b, 1.0))
		or VoxelCatalogue.luminance_affichee(pf["cartouche"]) >= VoxelCatalogue.luminance_affichee(tf["cartouche"]) - 0.002)
	_check("aucune couleur d'accessoire en gris ni en portraits (l'essai est celui de la V3)",
		VoxelCatalogue.palette_details("pistolet", "").is_empty() and VoxelCatalogue.palette_details("pistolet", "portraits").is_empty())
	var inc := FileAccess.get_file_as_string("res://iso_corps_detail.gdshaderinc")
	_check("tout sous #ifdef CORPS_DETAIL", inc.find("#ifdef CORPS_DETAIL") < inc.find("uniform float detail")
		and inc.strip_edges().ends_with("#endif"))
	_check("la matière peinte n'assombrit que (pores 0,62 et marbrage 0,86 < 1, multipliés à la fiche)",
		inc.contains("const float DETAIL_PORE = 0.62;") and inc.contains("const float DETAIL_MARBRE = 0.86;")
		and inc.contains("return c * mix(1.0, k, detail_matiere);"))
	_check("les pores s'effacent à la taille du duel (entiers sous 0,3 pixel du monde par pixel d'écran, nuls au-dessus de 0,5)",
		inc.contains("float fondu = 1.0 - smoothstep(0.3, 0.5, ecran);"))
	# Q33 (ordre 435) — la matière peinte hors du jeu : compilée sous CORPS_DETAIL_MATIERE seulement, que le jeu n'allume pas.
	var debut_mat := inc.find("#ifdef CORPS_DETAIL_MATIERE")
	_check("Q33 : la matière peinte (marbrage et pores) n'est compilée que sous CORPS_DETAIL_MATIERE ; sans lui, la couleur de l'accessoire seule",
		debut_mat > 0 and inc.find("float marbre") > debut_mat and inc.find("#else\n\treturn c;\n#endif") > inc.find("float marbre"))
	var racine_m := Node3D.new()
	root.add_child(racine_m)
	VoxelCatalogue.forcer_matiere = -1
	var au_jeu := _corps(racine_m, "pistolet", true)
	VoxelCatalogue.forcer_matiere = 1
	var au_banc := _corps(racine_m, "pistolet", true)
	VoxelCatalogue.forcer_matiere = -1
	_check("Q33 : au jeu, le corps détaillé ne compile pas la matière ; au banc (forcer_matiere = 1), si — et sa pré-passe suit",
		not au_jeu.materiau().shader.code.contains("#define CORPS_DETAIL_MATIERE\n")
		and au_banc.materiau().shader.code.contains("#define CORPS_DETAIL_MATIERE\n")
		and au_banc.materiau_profondeur().shader == au_banc.materiau().shader
		and au_jeu.materiau_profondeur().shader == au_jeu.materiau().shader)
	racine_m.queue_free()
	_check("Q33 : le marbrage aussi — à la taille du duel, plus de matière du tout (le facteur entier suit le fondu)",
		inc.contains("float k = mix(1.0, marbre * mix(1.0, DETAIL_PORE, pore), fondu);"))
	var pas_plus_sombre := true
	for slug in KIT:
		var pt := VoxelCatalogue.palette_tenue(slug, "sombre3", "froide")
		var pd := VoxelCatalogue.palette_details(slug, "sombre3", "froide")
		for cle in pd:
			pas_plus_sombre = pas_plus_sombre and VoxelCatalogue.luminance_affichee(pd[cle]) >= VoxelCatalogue.luminance_affichee(pt["ocre"]) - 0.002
	_check("Q33 : aucun accessoire plus sombre que le tissu qu'il couvre, pour les dix", pas_plus_sombre)
	_check("albédo seul : l'include n'écrit ni ALBEDO, ni EMISSION, ni light()",
		not inc.contains("ALBEDO") and not inc.contains("EMISSION") and not inc.contains("void light"))
	for chemin in ["res://corps_iso.gdshader", "res://corps_iso_eclaire.gdshader"]:
		var code := FileAccess.get_file_as_string(chemin)
		var lumiere := code.substr(code.find("void light()")) if code.contains("void light()") else ""
		_check("%s : le détail sur la fiche seule, sous le drapeau ; light() ne le connaît pas" % chemin.get_file(),
			code.contains("#ifdef CORPS_DETAIL\n\t// ISO13 — les accessoires modelés et la matière peinte : la fiche seule, assombrie jamais éclaircie.\n\tfiche = detail_fiche(")
			and not lumiere.contains("detail"))
	# Q33 — la killcam reste en aplat (décision d'Adrien) : le corps porté par le fantôme n'a aucune part éclairée, détaillé
	# ou non — sa couleur, accessoires compris, ne s'y voit pas.
	var pres := FileAccess.get_file_as_string("res://presentation_3d.gd")
	var suivre := pres.substr(pres.find("func _suivre_le_fantome("), 3000)
	_check("Q33 : la killcam reste en aplat — le corps du fantôme a une opacité de 0 dans chaque vue",
		suivre.contains('set_shader_parameter("opacite_%d" % (vue_id + 1), 0.0)'))
	_check("Protocol.VERSION reste 18 : rien sur le fil", FileAccess.get_file_as_string("res://protocol.gd").contains("const VERSION := 18"))
