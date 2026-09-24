## ISO13 — le personnage détaillé à l'essai (`--corps-detaille`, une classe : le pistolet ; chantier d'ISO7 Beauté, 2026-09-24).
##
## Ce que la suite prouve, sans fenêtre :
## - **le drapeau** : éteint par défaut ; sans lui, le pistolet garde ses dix boîtes et le shader d'origine, qui ne déclare
##   rien du détail ;
## - **les accessoires** : onze boîtes de plus sur le pistolet seul, aucune sur les autres classes ; des demi-tailles
##   distinctes entre elles et de celles du corps (le shader les reconnaît à leur taille) ; le compte d'appels de dessin et de
##   triangles ajoutés ;
## - **la silhouette** : le corps seul, accessoires compris, dans le couloir de 17,5 px (sous la zone de touche de 18 px), debout
##   et accroupi, à seize visées — et la garde VUE ROUGIR : une boîte posée hors du couloir est bien refusée ;
## - **la visibilité** : les couleurs des accessoires, à un rapport ≤ 1 du gris de la classe ; la matière peinte ne fait
##   qu'assombrir (pores et marbrage < 1) ; albédo seul, ni `light()` ni émission ; `Protocol.VERSION` 18.
##
## Ce qu'elle ne prouve pas : l'image. La planche du pistolet (banc des lumières et banc des corps) la mesure.
##
## Lancer : godot --headless --path . --script res://tools/test_corps_detail.gd
extends SceneTree

const PLANCHER := 24
const TUILE_PX := 35.0
const COULOIR_PX := 17.5
const TOUCHE_PX := 18.0
const ACCESSOIRES := 11

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
	var avec := _corps(racine, "pistolet", true)
	_check("le pistolet détaillé porte %d accessoires (%d boîtes en tout)" % [avec.details().size(), avec.nombre_de_boites()],
		avec.details().size() == ACCESSOIRES and avec.nombre_de_boites() == 10 + ACCESSOIRES)
	var autres := true
	for s in ["fusil", "occulteur", "allumeur"]:
		var c := _corps(racine, s, true)
		autres = autres and c.details().is_empty()
	_check("les autres classes n'en portent aucun (l'essai est d'une classe)", autres)
	# Les demi-tailles : celles des accessoires, et celles des boîtes du corps sans eux.
	var sans := _corps(racine, "pistolet", false)
	var du_corps := []
	for b in sans.boites():
		du_corps.append(((b as MeshInstance3D).mesh as BoxMesh).size * 0.5)
	var confondues := []
	for b in avec.details():
		var d: Vector3 = ((b as MeshInstance3D).mesh as BoxMesh).size * 0.5
		for r in du_corps:
			if d.distance_to(r) < 0.001:
				confondues.append(String((b as Node).name))
	_check("aucun accessoire n'a la taille d'une boîte du corps (le shader les distingue)", confondues.is_empty(), str(confondues))
	var tailles := {}
	for b in avec.details():
		tailles[String((b as Node).name).rstrip("0123456789")] = ((b as MeshInstance3D).mesh as BoxMesh).size
	var distinctes := {}
	for k in tailles:
		distinctes[str(tailles[k])] = true
	_check("une taille par sorte d'accessoire (%d sortes, %d tailles)" % [tailles.size(), distinctes.size()],
		tailles.size() == distinctes.size())
	_check("le shader connaît chaque taille (detail_n = %d)" % int(avec.materiau().get_shader_parameter("detail_n")),
		int(avec.materiau().get_shader_parameter("detail_n")) == distinctes.size() and distinctes.size() <= 10)
	# Le coût : chaque accessoire, une boîte de couleur et son double de profondeur ; 12 triangles chacune.
	var mi_avec := avec.find_children("*", "MeshInstance3D", true, false).size()
	var mi_sans := sans.find_children("*", "MeshInstance3D", true, false).size()
	print("  COÛT appels de dessin ajoutés par corps : %d (couleur et profondeur) ; triangles ajoutés : %d"
		% [mi_avec - mi_sans, (mi_avec - mi_sans) * 12])
	_check("le coût annoncé : %d appels de dessin de plus par corps, %d triangles" % [mi_avec - mi_sans, (mi_avec - mi_sans) * 12],
		mi_avec - mi_sans == 2 * ACCESSOIRES)
	_check("les accessoires suivent le corps : chacun est l'enfant d'une pièce animée (torse, bouteille, arme)",
		avec.details().all(func(b): return ["Torse", "Bouteille", "Arme"].has(String((b as Node).get_parent().name))))


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
	var sans := _corps(racine, "pistolet", false)
	var avec := _corps(racine, "pistolet", true)
	var r_sans := _pire_rayon(sans)
	var r_avec := _pire_rayon(avec)
	print("  SILHOUETTE pistolet, corps seul : %.2f px sans accessoires, %.2f px avec" % [r_sans, r_avec])
	_check("accessoires compris, le corps seul reste dans le couloir (%.2f ≤ %.1f px) et sous la zone de touche (%.0f px)"
		% [r_avec, COULOIR_PX, TOUCHE_PX], r_avec <= COULOIR_PX + 0.01 and r_avec < TOUCHE_PX)
	# La garde vue rougir : l'étui du pistolet déplacé à 0,6 tuile du centre doit être refusé par la même mesure.
	var faux := _corps(racine, "pistolet", true)
	var etui := faux.find_child("Etui", true, false) as Node3D
	etui.position = Vector3(0.6, etui.position.y, etui.position.z)
	var r_faux := _pire_rayon(faux)
	_check("la garde rougit sur une boîte hors du couloir (%.2f px > %.1f)" % [r_faux, COULOIR_PX], r_faux > COULOIR_PX + 0.01)


func _la_visibilite() -> void:
	print("— la visibilité : la couleur, jamais plus claire")
	var l := VoxelCatalogue.luminance_affichee(VoxelCatalogue.fiche("pistolet")["couleur"])
	var p := VoxelCatalogue.palette_details("pistolet", "sombre3", "froide")
	var sous := true
	for cle in p:
		sous = sous and VoxelCatalogue.luminance_affichee(p[cle]) <= l + 0.002
	_check("cuir, laiton et métal à un rapport ≤ 1 du gris du pistolet", sous and p.size() == 3)
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
	_check("albédo seul : l'include n'écrit ni ALBEDO, ni EMISSION, ni light()",
		not inc.contains("ALBEDO") and not inc.contains("EMISSION") and not inc.contains("void light"))
	for chemin in ["res://corps_iso.gdshader", "res://corps_iso_eclaire.gdshader"]:
		var code := FileAccess.get_file_as_string(chemin)
		var lumiere := code.substr(code.find("void light()")) if code.contains("void light()") else ""
		_check("%s : le détail sur la fiche seule, sous le drapeau ; light() ne le connaît pas" % chemin.get_file(),
			code.contains("#ifdef CORPS_DETAIL\n\t// ISO13 — les accessoires modelés et la matière peinte : la fiche seule, assombrie jamais éclaircie.\n\tfiche = detail_fiche(")
			and not lumiere.contains("detail"))
	_check("Protocol.VERSION reste 18 : rien sur le fil", FileAccess.get_file_as_string("res://protocol.gd").contains("const VERSION := 18"))
