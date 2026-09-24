## ISO13, lot A — les corps lus comme les mannequins des illustrations (chantier d'ISO7 Beauté, 2026-09-24).
##
## Ce que la suite prouve, sans fenêtre :
## - **le drapeau** : `--mannequin` éteint par défaut ; allumé, les demi-tailles du torse, des bras et des jambes reconnaissent
##   exactement leurs boîtes, et rien d'autre ne change : neuf boîtes (dix avec une bouteille), même empreinte, zone de
##   touche à 18 px ;
## - **la lumière qui modèle ne s'inverse pas** : `MannequinIso.direction_dominante` pointe sur une lampe seule dans les
##   seize directions d'un tour, s'éteint derrière un mur, hors d'un cône ou hors de portée, s'annule entre deux lampes
##   égales et opposées, et suit la plus forte de deux ;
## - **le modelé n'éclaire jamais, et le nord vaut le sud** (miroir de `mannequin_facteur`) : la face dos à la lumière
##   s'assombrit, lumière au sud ce sont les dessus, et la perte vue est la même dans les deux cas ; tout facteur ≤ 1 ;
## - **les shaders** : le côté de la lumière après le modelé d'ISO7b, les segments et le contour après l'encre, le plafond
##   après la teinte ; `light()` ne connaît pas le mannequin.
##
## - **ISO13, lot B — l'encre en essai** (`--encre-essai`, éteint) : les hachures dans la pénombre (`IsoPate.hachures_facteur`,
##   miroir de `pate_hachures_facteur`) sont nulles dans le noir et en pleine lumière, n'éclairent jamais, et ne touchent le
##   lavis que sous le drapeau.
##
## Ce qu'elle ne prouve pas : l'image. Le banc des corps (`--mannequin --directions-mannequin`) la mesure en vraie fenêtre.
##
## Lancer : godot --headless --path . --script res://tools/test_corps_mannequin.gd
extends SceneTree

const PLANCHER := 34
const SHADERS := ["res://corps_iso.gdshader", "res://corps_iso_eclaire.gdshader"]

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
	print("=== ISO13 — LES CORPS EN MANNEQUINS ===")
	await process_frame
	_le_drapeau()
	await _les_corps()
	_la_direction()
	_le_modele()
	_les_shaders()
	_l_encre()
	_le_contour()
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	VoxelCatalogue.forcer_mannequin = -1
	VoxelCatalogue.forcer_tenue = "-"
	print("%d vérifications, %d échec(s)" % [_verifications, _echecs])
	quit(1 if _echecs > 0 else 0)


func _l_encre() -> void:
	print("— l'encre en essai : les hachures dans la pénombre")
	_check("éteinte par défaut (aucun %s sur la ligne de commande)" % IsoMateriaux.DRAPEAU_ENCRE_ESSAI, not IsoMateriaux.encre_essai_active())
	var IsoPateT: GDScript = load("res://iso_pate.gd")
	IsoPateT.set("hachures", 0.0)
	var motif := Vector2(12.3, 40.1)
	var sans := IsoPateT.call("pate", Vector3(0.3, 0.3, 0.3), 0.1, 3, motif, Vector2.ZERO, 0.1, 0.05) as Vector3
	IsoPateT.set("hachures", IsoMateriaux.HACHURES_ESSAI)
	var jamais_plus := true
	var nul_au_noir := true
	var nul_en_pleine := true
	var mord := false
	for i in 200:
		var l := float(i) / 200.0
		for k in 20:
			var m := Vector2(float(k) * 0.73, float(k) * 1.31)
			var fa: float = IsoPateT.call("hachures_facteur", l, m, 0.05)
			if fa > 1.0 or fa < 0.0:
				jamais_plus = false
			if l <= 0.01 and fa != 1.0:
				nul_au_noir = false
			if l >= 0.32 and fa != 1.0:
				nul_en_pleine = false
			if fa < 0.9:
				mord = true
	_check("les hachures n'éclairent jamais (facteur entre 0 et 1, deux cents lumières, vingt lieux)", jamais_plus)
	_check("nulles dans le noir (lumière ≤ 1 %) et en pleine lumière (≥ 32 %)", nul_au_noir and nul_en_pleine)
	_check("elles mordent dans la pénombre (un facteur sous 0,9 quelque part entre les deux)", mord)
	var zero := IsoPateT.call("pate", Vector3.ZERO, 0.1, 3, motif, Vector2.ZERO, 0.1, 0.05) as Vector3
	_check("0 reste 0 sous les hachures (le contrat du noir absolu de la pâte)", zero == Vector3.ZERO)
	IsoPateT.set("hachures", 0.0)
	var encore := IsoPateT.call("pate", Vector3(0.3, 0.3, 0.3), 0.1, 3, motif, Vector2.ZERO, 0.1, 0.05) as Vector3
	_check("éteintes, le lavis d'avant formule pour formule", encore == sans)
	var inc := FileAccess.get_file_as_string("res://iso_pate.gdshaderinc")
	_check("le shader : même pénombre, même trait que le miroir, posés sur le seul lavis",
		inc.contains("float penombre = smoothstep(0.01, 0.05, l) * (1.0 - smoothstep(0.14, 0.32, l));")
		and inc.contains("return 1.0 - pate_hachures * 0.6 * penombre * pate_trait(motif.x + motif.y, 5.0, 0.28, aa);")
		and inc.contains("return lave * q * (0.82 + 0.18 * grain) * pate_hachures_facteur(l, motif, aa);"))
	_check("drapeau éteint, rien à exécuter : les hachures sous #ifdef ENCRE_ESSAI, et le lavis d'avant tel quel sinon",
		inc.contains("#ifdef ENCRE_ESSAI\nuniform float pate_hachures") and inc.contains("#else\n\treturn lave * q * (0.82 + 0.18 * grain);\n#endif"))
	var sol := load("res://sol_iso.gdshader") as Shader
	var variante := IsoMateriaux.variante_encre(sol)
	var noms := []
	for u in variante.get_shader_uniform_list():
		noms.append(String(u["name"]))
	var noms_sol := []
	for u in sol.get_shader_uniform_list():
		noms_sol.append(String(u["name"]))
	_check("la variante du sol compile et porte pate_hachures ; le shader d'origine ne le porte pas",
		noms.has("pate_hachures") and not noms_sol.has("pate_hachures") and IsoMateriaux.variante_encre(sol) == variante)


func _le_contour() -> void:
	print("— le contour des personnages : une coque noire, qui suit l'opacité du corps")
	var sh := FileAccess.get_file_as_string("res://corps_iso_contour.gdshader")
	_check("la coque : faces arrière, agrandie axe par axe, noire, jamais d'éclat",
		sh.contains("cull_front") and sh.contains("VERTEX += sign(VERTEX) * contour_unites;") and sh.contains("ALBEDO = vec3(0.0);")
		and not sh.contains("EMISSION"))
	_check("la coque disparaît avec le corps (opacité nulle, ou pas de contour : discard)",
		sh.contains("if (contour_unites <= 0.0 || o <= 0.0001 || abs(normale_coque.y) > 0.5) {") and sh.contains("ALPHA = o;"))
	_check("la coque sans ses faces horizontales (sa face de dessous traçait une ceinture noire devant les jambes)",
		sh.contains("normale_coque = NORMAL;") and sh.contains("abs(normale_coque.y) > 0.5"))
	var racine := Node3D.new()
	root.add_child(racine)
	var corps := VoxelCorps.new()
	racine.add_child(corps)
	corps.construire("pistolet")
	_check("hors essai, aucune coque (la matière n'a pas de passe suivante)", corps.materiau().next_pass == null)
	corps.definir_contour(IsoMateriaux.CONTOUR_PX_EPAIS)
	var coque := corps.materiau_contour()
	_check("definir_contour pose la coque en passe suivante, à l'épaisseur demandée (%.4f tuile)" % float(coque.get_shader_parameter("contour_unites")),
		corps.materiau().next_pass == coque
		and absf(float(coque.get_shader_parameter("contour_unites")) - IsoMateriaux.CONTOUR_PX_EPAIS / float(CandelaTileSet.TILE_SIZE.x)) < 1e-6)
	corps.definir_opacite(0.0)
	_check("definir_opacite règle aussi la coque (0 : l'adversaire effacé ne montre pas son contour)",
		float(coque.get_shader_parameter("opacite_1")) == 0.0 and float(coque.get_shader_parameter("opacite_2")) == 0.0)
	var pres := FileAccess.get_file_as_string("res://presentation_3d.gd")
	_check("la présentation règle l'opacité de la coque à chaque image, comme celle du corps (joueurs et fantômes)",
		pres.count("for m in [_mat_corps[j], _mat_profondeur[j], (_mat_corps[j] as ShaderMaterial).next_pass]:") == 2)
	racine.queue_free()


func _le_drapeau() -> void:
	print("— le drapeau")
	VoxelCatalogue.forcer_mannequin = -1
	_check("éteint par défaut (aucun %s sur la ligne de commande)" % VoxelCatalogue.DRAPEAU_MANNEQUIN,
		not VoxelCatalogue.mannequin_actif())
	VoxelCatalogue.forcer_mannequin = 1
	_check("forcer_mannequin l'allume", VoxelCatalogue.mannequin_actif())
	VoxelCatalogue.forcer_mannequin = -1
	var cat := FileAccess.get_file_as_string("res://voxel_catalogue.gd")
	_check("la ligne de commande n'est lue qu'une fois (la présentation demande le drapeau à chaque image)",
		cat.contains("if _mannequin_ligne < 0:") and cat.count("OS.get_cmdline_user_args().has(DRAPEAU_MANNEQUIN)") == 1)
	_check("le drapeau lu vrai s'annonce une fois dans le journal : « [mannequin] allumé »",
		cat.contains('print("[mannequin] allumé') and cat.count("[mannequin] allumé") == 1)
	var pres := FileAccess.get_file_as_string("res://presentation_3d.gd")
	_check("drapeau éteint : ni lampes relues, ni direction, ni rayon de physique (tout derrière `if mannequin`)",
		pres.contains("MannequinIso.lampes_du_jeu(_main) if mannequin else []") and pres.contains("\t\t\tif mannequin:\n\t\t\t\t(_voxels[j] as VoxelCorps).eclairer_mannequin("))


func _les_corps() -> void:
	print("— les corps : les boîtes reconnues, rien d'autre ne bouge")
	var racine := Node3D.new()
	root.add_child(racine)
	for tenue in ["", "sombre3"]:
		VoxelCatalogue.forcer_tenue = tenue
		for s in VoxelCatalogue.slugs():
			VoxelCatalogue.forcer_mannequin = 0
			var avant := VoxelCorps.new()
			racine.add_child(avant)
			avant.construire(s)
			VoxelCatalogue.forcer_mannequin = 1
			var apres := VoxelCorps.new()
			racine.add_child(apres)
			apres.construire(s)
			var m := apres.materiau()
			var comptes := {}
			for cle in ["torse", "bras", "jambe"]:
				var ref: Vector3 = m.get_shader_parameter("mannequin_demi_%s" % cle)
				var n := 0
				for mi in apres.find_children("Boite", "MeshInstance3D", true, false):
					var d := (((mi as MeshInstance3D).mesh as BoxMesh).size * 0.5 - ref).abs()
					if maxf(d.x, maxf(d.y, d.z)) < 0.0005:
						n += 1
				comptes[cle] = n
			var ok: bool = float(m.get_shader_parameter("mannequin")) == 1.0 and comptes["torse"] == 1 \
				and comptes["bras"] == 2 and comptes["jambe"] == 2
			var meme: bool = apres.nombre_de_boites() == avant.nombre_de_boites() \
				and absf(apres.rayon_empreinte(true) - avant.rayon_empreinte(true)) < 0.0005 \
				and absf(apres.rayon_empreinte(false) - avant.rayon_empreinte(false)) < 0.0005
			if not ok or not meme or s == "pistolet":
				_check("%s%s : torse %d, bras %d, jambes %d reconnus ; %d boîtes et l'empreinte d'avant"
					% [s, (" en " + tenue) if tenue != "" else "", comptes["torse"], comptes["bras"], comptes["jambe"],
					apres.nombre_de_boites()], ok and meme)
			if s == "pistolet":
				var eteint: Variant = avant.materiau().get_shader_parameter("mannequin")
				_check("%s%s : éteint, le matériau ne porte pas le mannequin" % [s, (" en " + tenue) if tenue != "" else ""],
					eteint == null or float(eteint) == 0.0)
	VoxelCatalogue.forcer_mannequin = -1
	VoxelCatalogue.forcer_tenue = "-"
	var balle := FileAccess.get_file_as_string("res://bullet.gd")
	_check("la zone de touche reste 18 px (bullet.gd)", balle.contains("const PLAYER_BODY_RADIUS := 18.0"))
	_check("Protocol.VERSION reste 18 : rien sur le fil", FileAccess.get_file_as_string("res://protocol.gd").contains("const VERSION := 18"))
	racine.queue_free()
	await process_frame


func _omni(p: Vector2, intensite := 1.0, rayon := 300.0) -> Dictionary:
	return {"position": p, "intensite": intensite, "rayon": rayon, "cone": Vector2.ZERO, "demi_angle": PI}


func _la_direction() -> void:
	print("— la direction : elle pointe sur la lumière, et ne s'inverse jamais")
	var corps := Vector2(500, 400)
	var pire := 1.0
	for k in 16:
		var sens := Vector2.RIGHT.rotated(TAU * float(k) / 16.0)
		for dist in [20.0, 100.0, 250.0]:
			var d := MannequinIso.direction_dominante(corps, [_omni(corps + sens * dist)])
			pire = minf(pire, d.normalized().dot(sens) if d != Vector2.ZERO else -1.0)
	_check("une lampe seule, seize directions, trois distances : la direction pointe sur elle (pire cosinus %.4f)" % pire,
		pire > 0.999)
	var une := MannequinIso.direction_dominante(corps, [_omni(corps + Vector2(120, 0))])
	_check("une lampe seule : netteté 1 (%.3f)" % une.length(), absf(une.length() - 1.0) < 0.001)
	var mur := func(_a: Vector2, _b: Vector2) -> bool: return true
	_check("derrière un mur : aucune direction", MannequinIso.direction_dominante(corps, [_omni(corps + Vector2(120, 0))], mur) == Vector2.ZERO)
	_check("hors de portée : aucune direction", MannequinIso.direction_dominante(corps, [_omni(corps + Vector2(400, 0), 1.0, 300.0)]) == Vector2.ZERO)
	var torche_vers := {"position": corps + Vector2(0, 150), "intensite": 1.0, "rayon": 300.0, "cone": Vector2(0, -1),
		"demi_angle": deg_to_rad(30.0)}
	var torche_dos := torche_vers.duplicate()
	torche_dos["cone"] = Vector2(0, 1)
	var dv := MannequinIso.direction_dominante(corps, [torche_vers])
	_check("une torche braquée sur le corps depuis le sud : la direction pointe au sud (%s)" % str(dv), dv.normalized().dot(Vector2(0, 1)) > 0.999)
	_check("la même torche braquée ailleurs : aucune direction", MannequinIso.direction_dominante(corps, [torche_dos]) == Vector2.ZERO)
	var torche_de_biais := torche_vers.duplicate()
	torche_de_biais["cone"] = Vector2(0, -1).rotated(deg_to_rad(60.0))
	_check("le corps hors du cône (60° pour un demi-cône de 30°) : aucune direction",
		MannequinIso.direction_dominante(corps, [torche_de_biais]) == Vector2.ZERO)
	var opposees := MannequinIso.direction_dominante(corps, [_omni(corps + Vector2(100, 0)), _omni(corps - Vector2(100, 0))])
	_check("deux lampes égales et opposées : le modelé s'efface (netteté %.4f)" % opposees.length(), opposees.length() < 0.001)
	var forte := MannequinIso.direction_dominante(corps, [_omni(corps + Vector2(100, 0), 3.0), _omni(corps - Vector2(100, 0), 1.0)])
	_check("deux lampes inégales : la plus forte l'emporte (%s)" % str(forte), forte.x > 0.4 and forte.x < 1.0)
	var proche := MannequinIso.direction_dominante(corps, [_omni(corps + Vector2(50, 0)), _omni(corps - Vector2(250, 0))])
	_check("à intensité égale, la plus proche l'emporte (%s)" % str(proche), proche.x > 0.0)
	_check("dans le noir : aucune direction", MannequinIso.direction_dominante(corps, []) == Vector2.ZERO)
	# La traversée d'un cône, qui inversait le Lambert d'ISO7b : un corps qui passe d'un bord à l'autre du faisceau voit sa
	# lumière venir de la lampe, jamais du bord de la tache.
	var lampe := Vector2(500, 700)
	var inverse := false
	for i in 41:
		var x := 400.0 + 5.0 * float(i)
		var p := Vector2(x, 400.0)
		var t := {"position": lampe, "intensite": 1.0, "rayon": 500.0, "cone": Vector2(0, -1), "demi_angle": deg_to_rad(30.0)}
		var d := MannequinIso.direction_dominante(p, [t])
		if d != Vector2.ZERO and d.normalized().dot((lampe - p).normalized()) < 0.999:
			inverse = true
	_check("un corps qui traverse le faisceau d'un bord à l'autre : la lumière vient toujours de la lampe", not inverse)


## Miroir de `mannequin_facteur` (iso_corps_mannequin.gdshaderinc). `camera` : la direction horizontale vers la caméra, (0, 1)
## au lacet 0.
static func _facteur(n: Vector3, l: Vector2, contraste: float, report: float, camera := Vector2(0, 1)) -> float:
	var nette := minf(l.length(), 1.0)
	if nette < 0.001:
		return 1.0
	var u := l / l.length()
	var v := camera.normalized() if camera.length() > 0.001 else Vector2(0, 1)
	if n.y > 0.5:
		return clampf(1.0 - contraste * nette * maxf(u.dot(v), 0.0) * report, 0.0, 1.0)
	var h := Vector2(n.x, n.z)
	if h.length() < 0.001:
		return 1.0
	return clampf(1.0 - contraste * nette * maxf(-h.normalized().dot(u), 0.0), 0.0, 1.0)


func _le_modele() -> void:
	print("— le modelé : le côté dos à la lumière s'assombrit, rien ne s'éclaire, et le nord vaut le sud")
	var c := VoxelCatalogue.MANNEQUIN_CONTRASTE
	var r := VoxelCatalogue.MANNEQUIN_REPORT
	var sud := Vector3(0, 0, 1)
	var dessus := Vector3(0, 1, 0)
	_check("lumière au nord : la face sud (dos à elle) s'assombrit (%.2f), le dessus garde sa lumière (%.2f)"
		% [_facteur(sud, Vector2(0, -1), c, r), _facteur(dessus, Vector2(0, -1), c, r)],
		_facteur(sud, Vector2(0, -1), c, r) < 1.0 and _facteur(dessus, Vector2(0, -1), c, r) == 1.0)
	_check("lumière au sud : la face sud garde sa lumière (%.2f), le dessus, rasé, s'assombrit (%.2f)"
		% [_facteur(sud, Vector2(0, 1), c, r), _facteur(dessus, Vector2(0, 1), c, r)],
		_facteur(sud, Vector2(0, 1), c, r) == 1.0 and _facteur(dessus, Vector2(0, 1), c, r) < 1.0)
	_check("lumière à l'est : la face ouest s'assombrit, l'est, la face sud et le dessus gardent leur lumière",
		_facteur(Vector3(-1, 0, 0), Vector2(1, 0), c, r) < 1.0 and _facteur(Vector3(1, 0, 0), Vector2(1, 0), c, r) == 1.0
		and _facteur(sud, Vector2(1, 0), c, r) == 1.0 and _facteur(dessus, Vector2(1, 0), c, r) == 1.0)
	# L'équité nord / sud : la face sud (aire 1) perd, lumière au nord, ce que les dessus (aire 1/report) perdent, lumière au sud.
	var perte_nord := 1.0 - _facteur(sud, Vector2(0, -1), c, r)
	var perte_sud := (1.0 - _facteur(dessus, Vector2(0, 1), c, r)) / r
	_check("équité : la perte vue est la même, lumière au nord ou au sud (%.3f / %.3f)" % [perte_nord, perte_sud],
		absf(perte_nord - perte_sud) < 1e-6)
	var jamais_plus := true
	for k in 16:
		var l := Vector2.RIGHT.rotated(TAU * float(k) / 16.0)
		for n in [sud, dessus, Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1)]:
			var fa := _facteur(n, l, c, r)
			if fa > 1.0 or fa < 0.0:
				jamais_plus = false
	# ISO13, 04:38 — À TOUT LACET : la caméra tournée de θ voit deux faces latérales, d'aires vues cos θ et sin θ (base carrée).
	# Lumière dans son dos, elles perdent contraste × cos chacune ; lumière de son côté, les dessus perdent contraste × report.
	var equitable := true
	var au_lacet_nul := true
	for k in 12:
		var theta := TAU * float(k) / 12.0
		var v := Vector2(0, 1).rotated(-theta)
		var perte_faces := 0.0
		for f in 4:
			var h := Vector2(0, 1).rotated(-theta + PI * 0.5 * float(f))
			var aire := maxf(h.dot(v), 0.0)
			perte_faces += aire * (1.0 - _facteur(Vector3(h.x, 0, h.y), -v, c, r, v))
		var perte_dessus := (1.0 - _facteur(dessus, v, c, r, v)) / r
		if absf(perte_faces - perte_dessus) > 1e-5:
			equitable = false
		for f in 4:
			var l := Vector2(0, 1).rotated(PI * 0.5 * float(f))
			for n in [sud, dessus, Vector3(1, 0, 0)]:
				if k == 0 and _facteur(n, l, c, r, v) != _facteur(n, l, c, r):
					au_lacet_nul = false
	_check("à tout lacet (douze, base carrée) : la perte vue des faces, lumière dans le dos de la caméra, vaut celle des dessus, lumière de son côté",
		equitable)
	_check("au lacet 0, la caméra au sud : le modelé d'avant, facteur pour facteur", au_lacet_nul)
	_check("tout facteur entre 0 et 1, dans toutes les directions : le mannequin n'éclaire jamais — aucun pixel voyant, aucun noir rallumé",
		jamais_plus)
	_check("le contraste est modéré (%.2f) : la face dos à la lumière garde %.0f %% de sa lumière" % [c, (1.0 - c) * 100.0],
		c > 0.0 and c <= 0.5 and c * r <= 1.0)


func _les_shaders() -> void:
	print("— les shaders")
	var inc := FileAccess.get_file_as_string("res://iso_corps_mannequin.gdshaderinc")
	_check("l'include n'écrit ni ALBEDO, ni EMISSION, ni DIFFUSE_LIGHT", not inc.contains("ALBEDO") and not inc.contains("EMISSION")
		and not inc.contains("DIFFUSE_LIGHT") and not inc.contains("void light"))
	_check("l'include : le miroir de la suite est la formule du shader (dessus et faces latérales)",
		inc.contains("return clamp(1.0 - mannequin_contraste * nette * max(dot(l, v), 0.0) * mannequin_report, 0.0, 1.0);")
		and inc.contains("return clamp(1.0 - mannequin_contraste * nette * max(-dot(h / lh, l), 0.0), 0.0, 1.0);"))
	_check("l'include : le côté de la lumière passe par pate_facteur, en fondu selon la lumière reçue par le corps",
		inc.contains("return pate_facteur(c, mix(1.0, mannequin_facteur(n, camera), w));"))
	var t0 := CameraIso.transform_pour(Transform2D.IDENTITY, Vector2(1920, 1080), CameraIso.TANGAGE_DEG, 0.0)
	var t45 := CameraIso.transform_pour(Transform2D.IDENTITY, Vector2(1920, 1080), CameraIso.TANGAGE_DEG, 45.0)
	var v0 := Vector2(t0.basis.z.x, t0.basis.z.z).normalized()
	var v45 := Vector2(t45.basis.z.x, t45.basis.z.z).normalized()
	_check("la colonne z de la caméra pointe vers elle : (0, 1) au lacet 0 (%s), tournée de 45° au lacet 45 (%s)" % [v0, v45],
		v0.distance_to(Vector2(0, 1)) < 1e-5 and absf(absf(v45.angle_to(v0)) - PI / 4.0) < 1e-4)
	_check("l'include : aucun « sud » en dur — la caméra est un argument, lu par l'appelant dans la matrice de vue",
		not inc.contains("max(l.y, 0.0)") and inc.contains("float mannequin_facteur(vec3 n, vec2 camera) {"))
	_check("l'include : rien sous le seuil (modelé, segments et contour pèsent mannequin_poids, nul sous 12/255)",
		inc.contains("uniform vec2 mannequin_seuils = vec2(0.0470588, 0.1254902);")
		and inc.contains("smoothstep(mannequin_seuils.x, mannequin_seuils.y, niveau)")
		and inc.count("float w = mannequin_poids(niveau);") == 2)
	for chemin in SHADERS:
		var sh := load(chemin) as Shader
		var noms := []
		for u in sh.get_shader_uniform_list():
			noms.append(String(u["name"]))
		_check("%s compile et déclare le mannequin" % chemin.get_file(), noms.has("mannequin") and noms.has("mannequin_lumiere"))
		var code := sh.code
		var i := code.find("void fragment()")
		var frag := code.substr(i)
		var modele := frag.find("modele_du_corps(normale_monde)")
		var cote := frag.find("c = mannequin_modeler(c, normale_monde, niveau, INV_VIEW_MATRIX[2].xz);")
		var encre := frag.find("pate_encre_boite(local, demi, echelle, normale_locale, encre_arete, encre_reste, px_monde)")
		var segments := frag.find("c = pate_facteur(c, mannequin_segments(")
		var teinte := frag.find("c = portrait_teindre(c, fiche, couleur_fiche.rgb);")
		var borne := frag.find("c = mannequin_borner(c);")
		_check("%s : le côté après le modelé, les segments après l'encre, le plafond après la teinte" % chemin.get_file(),
			modele > 0 and cote > modele and segments > encre and encre > cote and borne > teinte and teinte > segments)
		var lumiere := code.substr(code.find("void light()")) if code.contains("void light()") else ""
		_check("%s : light() ne connaît pas le mannequin" % chemin.get_file(), not lumiere.contains("mannequin"))
		_check("%s : les segments gardés par le drapeau (inchangé au bit sans lui)" % chemin.get_file(),
			frag.contains("if (mannequin >= 0.5) {\n\t\tc = pate_facteur(c, mannequin_segments("))
	var pres := FileAccess.get_file_as_string("res://presentation_3d.gd")
	_check("la présentation relit les lampes une fois par image et éclaire chaque corps, seulement sous le drapeau",
		pres.contains("var mannequin := corps_voxel and _main != null and VoxelCatalogue.mannequin_actif()")
		and pres.contains("MannequinIso.lampes_du_jeu(_main) if mannequin else []")
		and pres.contains(".eclairer_mannequin(MannequinIso.direction_dominante(p, lampes_mannequin,"))
