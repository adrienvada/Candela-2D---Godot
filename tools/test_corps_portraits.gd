## ISO12 — l'aspect des corps d'après les dix portraits de classe (chantier d'ISO7 Beauté, 2026-09-22).
##
## Ce que la suite prouve, sans fenêtre :
## - **le drapeau** : sans `--corps=portraits`, rien ne change (neuf boîtes, `portrait` à 0) ;
## - **l'équité de la couleur** : le plâtre de chaque classe a la luminance de son gris d'ISO3 (sa visibilité ne change
##   pas), tout le reste est plus sombre, et rien ne dépasse `Charte.DIM`, l'enveloppe des corps ;
## - **le noir absolu et la visibilité d'hier** : la pâte décide sur le gris de la classe où la lumière se voit, et le
##   portrait ne fait que TEINDRE la lumière rendue (`portrait_teindre`) : 0 reste 0, une lumière visible le reste ;
##   aucune émission, aucun `light()` touché — dans les deux shaders des corps ;
## - **l'empreinte** : le corps seul, bouteille comprise, reste dans le couloir d'une tuile (17,5 px) debout, accroupi,
##   en marche et en enjambement, pour les dix classes ;
## - **la zone de touche** : `PLAYER_BODY_RADIUS` reste 18 px, et l'ensemble (arme comprise) ne s'étend pas plus loin
##   qu'avant ;
## - **le contraste au sol** : sous la même lumière, le plâtre et même la rouille des pieds restent plus clairs que le
##   sol peint ;
## - `Protocol.VERSION` reste 18 : rien de ceci ne passe sur le fil.
##
## Ce qu'elle ne prouve pas : l'image. Le banc des corps (`tools/banc_corps.gd --corps=portraits`) et le banc de la vue
## (`tools/banc_iso_beaute.gd --cadrage corps`) le mesurent en vraie fenêtre.
##
## Lancer : godot --headless --path . --script res://tools/test_corps_portraits.gd
extends SceneTree

const PLANCHER := 60
const COULOIR_TUILES := 0.5
const EPSILON := 0.0005
const SHADERS := ["res://corps_iso.gdshader", "res://corps_iso_eclaire.gdshader"]
const IsoPate := preload("res://iso_pate.gd")

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
	print("=== ISO12 — LES CORPS D'APRÈS LES DIX PORTRAITS ===")
	await process_frame
	_le_drapeau()
	_la_palette()
	_les_shaders()
	await _les_corps()
	_le_contraste_au_sol()
	_le_fil()
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	VoxelCatalogue.forcer_portraits = -1
	print("%d vérifications, %d échec(s)" % [_verifications, _echecs])
	quit(1 if _echecs > 0 else 0)


func _le_drapeau() -> void:
	print("— le drapeau")
	VoxelCatalogue.forcer_portraits = -1
	_check("éteint par défaut (aucun %s sur la ligne de commande)" % VoxelCatalogue.DRAPEAU_PORTRAITS,
		not VoxelCatalogue.portraits_actifs())
	_check("les dix classes ont leur portrait", VoxelCatalogue.PORTRAITS.size() == 10
		and Array(VoxelCatalogue.slugs()).all(func(s): return VoxelCatalogue.PORTRAITS.has(s)))
	var avec_bouteille := []
	for s in VoxelCatalogue.slugs():
		if bool(VoxelCatalogue.PORTRAITS[s]["bouteille"]):
			avec_bouteille.append(s)
	avec_bouteille.sort()
	_check("la bouteille dans le dos des six classes des portraits (%s)" % ", ".join(avec_bouteille),
		avec_bouteille == ["allumeur", "incendiaire", "occulteur", "pistolet", "sentinelle", "spectre"])
	_check("cartouches grises au Fumiste, rouges à l'Incendiaire",
		VoxelCatalogue.PORTRAITS["fumiste"]["cartouches"] == "grise" and VoxelCatalogue.PORTRAITS["incendiaire"]["cartouches"] == "rouge")
	var uses := []
	for s in VoxelCatalogue.slugs():
		if float(VoxelCatalogue.PORTRAITS[s]["usure"]) > 0.5:
			uses.append(s)
	uses.sort()
	_check("pistolet, occulteur et spectre plus usés (%s)" % ", ".join(uses), uses == ["occulteur", "pistolet", "spectre"])


func _la_palette() -> void:
	print("— la palette : l'équité de la couleur")
	var plafond := VoxelCatalogue.luminance_affichee(VoxelCatalogue.GRIS_PLAFOND)
	for s in VoxelCatalogue.slugs():
		var p := VoxelCatalogue.palette_portrait(s)
		var gris: float = VoxelCatalogue.luminance_affichee(VoxelCatalogue.fiche(s)["couleur"])
		var ocre := VoxelCatalogue.luminance_affichee(p["ocre"])
		var comp := VoxelCatalogue.COMPENSATION_PATINE_USEE if float(VoxelCatalogue.PORTRAITS[s]["usure"]) > 0.5 else VoxelCatalogue.COMPENSATION_PATINE
		var attendu := minf(gris * comp, plafond)
		var patine := float(p["patine"])
		_check("%s : la patine s'allège juste assez quand le plâtre bute sur DIM (%.2f)" % [s, patine],
			(patine == 1.0 and gris * comp <= plafond + 1e-6) or (patine < 1.0 and absf((1.0 - patine * (1.0 - 1.0 / comp)) * attendu - gris) < 0.002))
		_check("%s : le plâtre a la luminance de son gris d'ISO3 relevée de la patine (%.4f ≈ %.4f, gris %.4f)" % [s, ocre, attendu, gris],
			absf(ocre - attendu) < 0.002 and ocre >= gris)
		var sombres := true
		for cle in ["rouille", "brun", "arme"]:
			sombres = sombres and VoxelCatalogue.luminance_affichee(p[cle]) < ocre
		if (p["cartouche"] as Color).a > 0.0:
			sombres = sombres and VoxelCatalogue.luminance_affichee(p["cartouche"]) < ocre
		_check("%s : rouille, sangles, arme et cartouches plus sombres que le plâtre" % s, sombres)
		var max_l := 0.0
		for cle in ["ocre", "rouille", "brun", "arme", "bouteille", "cartouche"]:
			max_l = maxf(max_l, VoxelCatalogue.luminance_affichee(p[cle]))
		_check("%s : rien au-dessus de Charte.DIM (%.4f ≤ %.4f)" % [s, max_l, plafond], max_l <= plafond + 0.001)
	# `portrait_teindre`, en miroir : la lumière rendue sur le gris décide seule où le corps se voit.
	var gris_c := VoxelCatalogue.fiche("spectre")["couleur"] as Color
	var ocre_c := VoxelCatalogue.palette_portrait("spectre")["ocre"] as Color
	var nul := _teindre(Vector3.ZERO, ocre_c, gris_c)
	var faible := _teindre(_lin(gris_c) * 0.02, ocre_c, gris_c)
	_check("teinte : 0 reste 0, et une lumière faible sur le gris reste visible peinte (%.5f)" % faible.length(),
		nul == Vector3.ZERO and faible.length() > 0.0)
	var plein := _teindre(_lin(gris_c), ocre_c, gris_c)
	_check("teinte : sous le plafond du gris, jamais au-dessus du portrait", plein.x <= _lin(ocre_c).x + 1e-5
		and plein.y <= _lin(ocre_c).y + 1e-5 and plein.z <= _lin(ocre_c).z + 1e-5)
	var r := VoxelCatalogue.palette_portrait("incendiaire")["cartouche"] as Color
	_check("les cartouches de l'Incendiaire sont rouges (r > 2 g : %.2f / %.2f)" % [r.r, r.g], r.r > 2.0 * r.g)


func _les_shaders() -> void:
	print("— les shaders : albédo seul, noir absolu")
	var inc := FileAccess.get_file_as_string("res://iso_corps_portrait.gdshaderinc")
	_check("l'include n'écrit ni ALBEDO, ni EMISSION, ni DIFFUSE_LIGHT", not inc.contains("ALBEDO")
		and not inc.contains("EMISSION") and not inc.contains("DIFFUSE_LIGHT") and not inc.contains("void light"))
	for chemin in SHADERS:
		var sh := load(chemin) as Shader
		var noms := []
		for u in sh.get_shader_uniform_list():
			noms.append(String(u["name"]))
		_check("%s compile et déclare le portrait" % chemin.get_file(), noms.has("portrait") and noms.has("portrait_ocre"))
		var code := sh.code
		var i := code.find("void fragment()")
		var j := code.find("\n}\n", i)
		var frag := code.substr(i, j - i)
		var propres := true
		var vus := 0
		for brute in frag.split("\n"):
			var l := brute.strip_edges()
			if l.begins_with("//") or not _nomme_fiche(l):
				continue
			vus += 1
			# Les seuls usages permis : la couleur du portrait calculée, puis posée sur la lumière déjà rendue.
			var ok := l.begins_with("vec3 fiche = portrait_fiche(couleur_fiche.rgb,") \
				or l == "c = portrait_teindre(c, fiche, couleur_fiche.rgb);"
			if not ok:
				propres = false
				printerr("    usage de la fiche hors teinte : ", l)
		_check("%s : le portrait n'entre que par portrait_teindre (%d usages)" % [chemin.get_file(), vus], propres and vus == 2)
		var teinte := frag.find("c = portrait_teindre(c, fiche, couleur_fiche.rgb);")
		_check("%s : la pâte décide sur le gris (base = couleur_fiche…), le portrait teint après elle, avant l'encre" % chemin.get_file(),
			teinte > frag.find("c = min(c, couleur_fiche.rgb);") and teinte > frag.find("modele_du_corps(normale_monde)), couleur_fiche.rgb);")
			and teinte < frag.find("pate_encre_boite(local") and frag.contains("couleur_fiche.rgb *"))
		var lumiere := code.substr(code.find("void light()")) if code.contains("void light()") else ""
		_check("%s : light() ne connaît pas le portrait" % chemin.get_file(), not lumiere.contains("portrait")
			and not lumiere.contains("fiche"))


static func _nomme_fiche(l: String) -> bool:
	var sans := l.replace("couleur_fiche", "")
	return RegEx.create_from_string("\\bfiche\\b").search(sans) != null


func _les_corps() -> void:
	print("— les corps : bouteille, empreinte, zone de touche")
	var racine := Node3D.new()
	root.add_child(racine)
	for s in VoxelCatalogue.slugs():
		VoxelCatalogue.forcer_portraits = 0
		var gris := VoxelCorps.new()
		racine.add_child(gris)
		gris.construire(s)
		VoxelCatalogue.forcer_portraits = 1
		var peint := VoxelCorps.new()
		racine.add_child(peint)
		peint.construire(s)
		var porte := bool(VoxelCatalogue.PORTRAITS[s]["bouteille"])
		_check("%s : sans drapeau, neuf boîtes et aucun portrait" % s, gris.nombre_de_boites() == 9
			and float(gris.materiau().get_shader_parameter("portrait") if gris.materiau().get_shader_parameter("portrait") != null else 0.0) == 0.0)
		_check("%s : avec, couleur_fiche reste le gris de la classe (la pâte décide sur lui)" % s,
			peint.materiau().get_shader_parameter("couleur_fiche") == gris.materiau().get_shader_parameter("couleur_fiche"))
		_check("%s : avec, %d boîtes et le portrait posé" % [s, peint.nombre_de_boites()],
			peint.nombre_de_boites() == (10 if porte else 9) and float(peint.materiau().get_shader_parameter("portrait")) == 1.0)
		var pire := _pire_empreinte(peint, true)
		_check("%s : corps seul, accessoires compris, dans le couloir (%.1f px ≤ 17,5)" % [s, pire * 35.0],
			pire <= COULOIR_TUILES + EPSILON)
		var tout_gris := _pire_empreinte(gris, false)
		var tout_peint := _pire_empreinte(peint, false)
		_check("%s : l'ensemble, arme comprise, ne s'étend pas plus loin qu'avant (%.2f ≤ %.2f px)" % [s, tout_peint * 35.0, tout_gris * 35.0],
			tout_peint <= tout_gris + EPSILON)
		# Un leurre prend le corps de la classe de son poseur par le même `construire` : même palette.
		var leurre := VoxelCorps.new()
		racine.add_child(leurre)
		leurre.construire(s)
		_check("%s : le leurre porte la même peinture" % s,
			leurre.materiau().get_shader_parameter("portrait_ocre") == peint.materiau().get_shader_parameter("portrait_ocre")
			and leurre.nombre_de_boites() == peint.nombre_de_boites())
	VoxelCatalogue.forcer_portraits = -1
	var balle := FileAccess.get_file_as_string("res://bullet.gd")
	_check("la zone de touche reste 18 px (bullet.gd)", balle.contains("const PLAYER_BODY_RADIUS := 18.0"))
	racine.queue_free()
	await process_frame


## Le pire rayon d'empreinte sur les quatre postures de la règle d'ISO Corps (voir `tools/test_voxel_corps.gd`).
func _pire_empreinte(corps: VoxelCorps, corps_seul: bool) -> float:
	var pire := 0.0
	var base := {"position": Vector2.ZERO, "visee": Vector2.DOWN, "vitesse": Vector2.ZERO, "torche": true,
		"arme": corps.slug(), "tir": false, "touche": false, "mort": false, "t": 0.0}
	corps.poser(base)
	pire = maxf(pire, corps.rayon_empreinte(corps_seul))
	var accroupi := base.duplicate()
	accroupi["accroupi"] = true
	accroupi["t"] = 1.0
	corps.poser(accroupi)
	pire = maxf(pire, corps.rayon_empreinte(corps_seul))
	for i in 8:
		var marche := base.duplicate()
		marche["vitesse"] = Vector2(220.0, 0.0)
		marche["t"] = float(i) * 0.18
		corps.poser(marche)
		pire = maxf(pire, corps.rayon_empreinte(corps_seul))
	for i in 8:
		var enjambe := base.duplicate()
		enjambe["enjambe"] = float(i + 1) * 0.125
		corps.poser(enjambe)
		pire = maxf(pire, corps.rayon_empreinte(corps_seul))
	corps.poser(base)
	return pire


func _le_contraste_au_sol() -> void:
	print("— le contraste au sol, sous la même lumière")
	# Sous la même lampe, la vue iso rend le sol par la lightmap (lumière × le sol peint de la 2D) et le corps par la
	# lumière × sa fiche : le rapport de leurs luminances ne dépend plus de la lampe. Le sol le plus clair : `SOL_DESSIN_B`.
	var sol := VoxelCatalogue.luminance_affichee(CandelaTileSet.SOL_DESSIN_B)
	var pire_platre := INF
	var pire_rouille := INF
	var pire_classe := ""
	for s in VoxelCatalogue.slugs():
		var p := VoxelCatalogue.palette_portrait(s)
		var platre := VoxelCatalogue.luminance_affichee(p["ocre"]) / sol
		var rouille := VoxelCatalogue.luminance_affichee(p["rouille"]) / sol
		if platre < pire_platre:
			pire_platre = platre
			pire_classe = s
		pire_rouille = minf(pire_rouille, rouille)
	_check("le plâtre le plus sombre (%s) reste au moins deux fois plus clair que le sol (%.2f)" % [pire_classe, pire_platre],
		pire_platre >= 2.0)
	_check("la rouille des pieds reste plus claire que le sol (%.2f ≥ 1,15)" % pire_rouille, pire_rouille >= 1.15)
	var encre_continue := IsoMateriaux.ENCRE_VOXEL_PX > 0.0
	for chemin in SHADERS:
		encre_continue = encre_continue and (load(chemin) as Shader).code.contains(
			"c = pate_facteur(c, pate_encre_boite(local, demi, echelle, normale_locale, encre_arete, encre_reste, px_monde));")
	_check("l'encre des arêtes reste posée sur tout le corps, peinture comprise (les deux shaders)", encre_continue)


func _le_fil() -> void:
	print("— le fil")
	_check("Protocol.VERSION reste 18", FileAccess.get_file_as_string("res://protocol.gd").contains("const VERSION := 18"))


## Miroir de `portrait_teindre` (valeurs du shader : couleurs déjà décodées par `source_color`).
static func _teindre(c: Vector3, fiche: Color, gris: Color) -> Vector3:
	var k: float = IsoPate.luminance(IsoPate.depuis_affiche(c)) / maxf(IsoPate.luminance(IsoPate.depuis_affiche(_lin(gris))), 0.000001)
	return IsoPate.vers_affiche(IsoPate.depuis_affiche(_lin(fiche)) * k)


static func _lin(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)
