## ISO12 — l'aspect des corps d'après les dix portraits de classe (chantier d'ISO7 Beauté, 2026-09-22).
##
## Ce que la suite prouve, sans fenêtre :
## - **le drapeau** : sans `--corps=portraits`, rien ne change (neuf boîtes, `portrait` à 0) ;
## - **l'équité de la couleur** : toutes les couleurs d'une classe ont la clarté de son gris d'ISO3 — la peinture change la
##   couleur, jamais la visibilité — et rien ne dépasse `Charte.DIM`, l'enveloppe des corps ;
## - **le noir absolu et la visibilité d'hier** : la pâte décide sur le gris de la classe où la lumière se voit, et le
##   portrait ne fait que TEINDRE la lumière rendue (`portrait_teindre`) : 0 reste 0, une lumière visible le reste ;
##   aucune émission, aucun `light()` touché — dans les deux shaders des corps ;
## - **l'empreinte** : le corps seul, bouteille comprise, reste dans le couloir d'une tuile (17,5 px) debout, accroupi,
##   en marche et en enjambement, pour les dix classes ;
## - **la zone de touche** : `PLAYER_BODY_RADIUS` reste 18 px, et l'ensemble (arme comprise) ne s'étend pas plus loin
##   qu'avant ;
## - **le contraste au sol** : la clarté relative de chaque pièce au sol est celle du gris (l'écart de couleur, lui, se
##   mesure au banc) ;
## - `Protocol.VERSION` reste 18 : rien de ceci ne passe sur le fil.
##
## - **les tenues sombres** (`--corps=sombre`, `sombre2`, `sombre3`, 2026-09-23 soir) : éteintes par défaut, chaque rôle à
##   son rapport de clarté au gris (borné par `Charte.DIM`), V2 jamais au-dessus du gris, le noir absolu dans le miroir de la
##   teinte (sous le seuil : assombri ou laissé gris, jamais éclairci), la tête reconnue sur une seule boîte, et la même
##   géométrie que les portraits (bouteille, empreinte).
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
	_le_banc()
	await _les_tenues_sombres()
	_le_fil()
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	VoxelCatalogue.forcer_portraits = -1
	VoxelCatalogue.forcer_tenue = "-"
	VoxelCatalogue.forcer_teinte = ""
	print("%d vérifications, %d échec(s)" % [_verifications, _echecs])
	quit(1 if _echecs > 0 else 0)


func _le_drapeau() -> void:
	print("— le drapeau")
	VoxelCatalogue.forcer_portraits = -1
	# Mis à jour le 2026-09-24 (décision d'Adrien : V3 froide, la tenue du jeu) : sans drapeau, les corps sont PEINTS — en V3,
	# pas d'après les portraits. Ce que ce contrôle gardait (les portraits éteints sans leur drapeau) reste vrai et vérifié.
	_check("les portraits éteints par défaut (aucun %s sur la ligne de commande) ; la tenue du jeu, peinte, est %s"
		% [VoxelCatalogue.DRAPEAU_PORTRAITS, VoxelCatalogue.tenue()],
		VoxelCatalogue.tenue() != "portraits" and VoxelCatalogue.tenue() == VoxelCatalogue.TENUE_PAR_DEFAUT
		and VoxelCatalogue.portraits_actifs())
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
		# La peinture change la couleur, jamais la visibilité : toutes les couleurs à la clarté du gris (une teinte très saturée
		# peut y perdre un peu, quand un canal bute sur 1 — jamais y gagner).
		var egales := true
		var detail := ""
		for cle in ["ocre", "rouille", "brun", "arme", "bouteille", "cartouche"]:
			if cle == "cartouche" and (p[cle] as Color).a <= 0.0:
				continue
			var l := VoxelCatalogue.luminance_affichee(p[cle])
			if not (l <= gris + 0.003 and l >= gris - 0.02):
				egales = false
				detail += "%s %.4f " % [cle, l]
		_check("%s : toutes les couleurs à la clarté du gris (%.4f), jamais au-dessus" % [s, gris], egales, detail)
		var d_rouille := _ecart_de_teinte(p["ocre"], p["rouille"])
		var d_sangle := _ecart_de_teinte(p["ocre"], p["brun"])
		_check("%s : à clarté égale, la rouille et les sangles se détachent du plâtre par la teinte (%.2f, %.2f)" % [s, d_rouille, d_sangle],
			d_rouille > 0.05 and d_sangle > 0.05)
		var max_l := 0.0
		for cle in ["ocre", "rouille", "brun", "arme", "bouteille", "cartouche"]:
			max_l = maxf(max_l, VoxelCatalogue.luminance_affichee(p[cle]))
		_check("%s : rien au-dessus de Charte.DIM (%.4f ≤ %.4f)" % [s, max_l, plafond], max_l <= plafond + 0.001)
	# `portrait_teindre`, en miroir : la lumière rendue sur le gris décide seule où le corps se voit.
	var gris_c := VoxelCatalogue.fiche("spectre")["couleur"] as Color
	var ocre_c := VoxelCatalogue.palette_portrait("spectre")["ocre"] as Color
	var nul := _teindre(Vector3.ZERO, ocre_c, gris_c)
	var faible := _teindre(_brut(gris_c) * 0.2, ocre_c, gris_c)
	_check("teinte : 0 reste 0, et une lumière faible sur le gris reste visible peinte (%.5f)" % faible.length(),
		nul == Vector3.ZERO and faible.length() > 0.0)
	var seuil := _brut(gris_c) * 0.05
	var sous := _teindre(seuil, ocre_c, gris_c)
	_check("teinte : sous le seuil du noir, le gris sans teinte, à l'arrondi des canaux près (%.6f ≈ %.6f)" % [sous.length(), seuil.length()],
		sous.x <= seuil.x and sous.y <= seuil.y and sous.z <= seuil.z and sous.length() >= seuil.length() * 0.98)
	var milieu := _brut(gris_c) * 0.5
	var lum_milieu := IsoPate.luminance(_teindre(milieu, ocre_c, gris_c))
	var lum_gris_milieu := IsoPate.luminance(milieu)
	_check("teinte : à clarté égale de palette, la clarté à l'écran est celle du gris (%.4f ≈ %.4f)" % [lum_milieu, lum_gris_milieu],
		absf(lum_milieu - lum_gris_milieu) < 0.004)
	var plein := _teindre(_brut(gris_c), ocre_c, gris_c)
	_check("teinte : sous le plafond du gris, jamais au-dessus du portrait", plein.x <= _brut(ocre_c).x + 1e-5
		and plein.y <= _brut(ocre_c).y + 1e-5 and plein.z <= _brut(ocre_c).z + 1e-5)
	var r := VoxelCatalogue.palette_portrait("incendiaire")["cartouche"] as Color
	_check("les cartouches de l'Incendiaire sont rouges (r > 2 g : %.2f / %.2f)" % [r.r, r.g], r.r > 2.0 * r.g)


func _les_shaders() -> void:
	print("— les shaders : albédo seul, noir absolu")
	var inc := FileAccess.get_file_as_string("res://iso_corps_portrait.gdshaderinc")
	_check("l'include laisse le gris tel quel sous 10/255, la teinte en fondu jusqu'à 24/255 (le miroir prend les mêmes seuils)",
		inc.contains("const float PORTRAIT_SEUIL_NOIR = 10.0 / 255.0;") and inc.contains("const float PORTRAIT_SEUIL_TEINTE = 24.0 / 255.0;")
		and inc.contains("uniform vec2 portrait_seuils = vec2(0.0392157, 0.0941176);")
		and inc.contains("float bas = max(portrait_seuils.x, PORTRAIT_SEUIL_NOIR);") and inc.contains("if (l < bas) {")
		and inc.contains("smoothstep(bas, haut, l)"))
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
		_check("%s : la pâte décide sur le gris (base = couleur_fiche…), le portrait teint en dernier, encre comprise" % chemin.get_file(),
			teinte > frag.find("c = min(c, couleur_fiche.rgb);") and teinte > frag.find("modele_du_corps(normale_monde)), couleur_fiche.rgb);")
			and teinte > frag.find("pate_encre_boite(local") and frag.contains("couleur_fiche.rgb *"))
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
	# Toutes les couleurs à la clarté du gris : le rapport de clarté au sol est celui d'aujourd'hui, pour toutes les classes et
	# toutes les pièces. Ce que la teinte fait à la LISIBILITÉ se mesure au banc, en écart de couleur (ΔE, `--cadrage corps`).
	var sol := VoxelCatalogue.luminance_affichee(CandelaTileSet.SOL_DESSIN_B)
	var ecart := 0.0
	for s in VoxelCatalogue.slugs():
		var p := VoxelCatalogue.palette_portrait(s)
		var gris: float = VoxelCatalogue.luminance_affichee(VoxelCatalogue.fiche(s)["couleur"])
		ecart = maxf(ecart, absf(VoxelCatalogue.luminance_affichee(p["rouille"]) / sol - gris / sol))
	_check("au sol, la clarté relative de chaque pièce est celle du gris (écart max %.3f)" % ecart, ecart < 0.05)
	var encre_continue := IsoMateriaux.ENCRE_VOXEL_PX > 0.0
	for chemin in SHADERS:
		encre_continue = encre_continue and (load(chemin) as Shader).code.contains(
			"c = pate_facteur(c, pate_encre_boite(local, demi, echelle, normale_locale, encre_arete, encre_reste, px_monde));")
	_check("l'encre des arêtes reste posée sur tout le corps, peinture comprise (les deux shaders)", encre_continue)


func _le_banc() -> void:
	print("— le banc du contraste")
	var banc: GDScript = load("res://tools/banc_iso_beaute.gd")
	_check("le cadrage « corps » existe", (banc.CADRAGES as Array).has("corps"))
	var blanc: Vector3 = banc.lab(Color(1, 1, 1))
	var noir: Vector3 = banc.lab(Color(0, 0, 0))
	var ocre: Vector3 = banc.lab(VoxelCatalogue.TEINTE_OCRE)
	_check("CIELAB : blanc (%.1f, %.1f, %.1f), noir 0, l'ocre chaud (b* > 40 : %.1f)" % [blanc.x, blanc.y, blanc.z, ocre.z],
		absf(blanc.x - 100.0) < 0.5 and blanc.length() < 100.6 and noir.length() < 0.01 and ocre.z > 40.0)


func _les_tenues_sombres() -> void:
	print("— les tenues sombres")
	VoxelCatalogue.forcer_tenue = "-"
	VoxelCatalogue.forcer_portraits = -1
	# Mis à jour le 2026-09-24 : la tenue du jeu est V3 (décision d'Adrien, Q21), et non plus le gris ; le gris reste joignable
	# par `--corps=gris`, et un nom inconnu revient au défaut du jeu comme une ligne sans drapeau.
	_check("V3 par défaut, décision d'Adrien (aucune tenue sur la ligne de commande : %s)" % VoxelCatalogue.tenue(),
		VoxelCatalogue.tenue() == "sombre3" and VoxelCatalogue.TENUE_PAR_DEFAUT == "sombre3")
	_check("la ligne de commande : gris → le gris d'ISO3, sombre → V1, sombre2, sombre3, portraits ; un nom inconnu → V3",
		VoxelCatalogue.tenue_de(PackedStringArray(["--corps=gris"])) == ""
		and VoxelCatalogue.tenue_de(PackedStringArray(["--corps=sombre"])) == "sombre1"
		and VoxelCatalogue.tenue_de(PackedStringArray(["--corps=sombre2"])) == "sombre2"
		and VoxelCatalogue.tenue_de(PackedStringArray(["--x", "--corps=sombre3"])) == "sombre3"
		and VoxelCatalogue.tenue_de(PackedStringArray(["--corps=portraits"])) == "portraits"
		and VoxelCatalogue.tenue_de(PackedStringArray(["--corps=sombre9"])) == "sombre3"
		and VoxelCatalogue.tenue_de(PackedStringArray()) == "sombre3")
	_check("trois variantes", VoxelCatalogue.TENUES_SOMBRES.keys() == ["sombre1", "sombre2", "sombre3"])
	# La teinte (drapeau séparé, éteint) : la chromaticité seule, les rapports de clarté intacts.
	VoxelCatalogue.forcer_teinte = ""
	# Mis à jour le 2026-09-24 : la teinte du jeu est la froide (décision d'Adrien, Q23, 12:42) ; l'olive reste joignable.
	_check("teinte : froide par défaut (décision d'Adrien), --teinte=olive la remet, un nom inconnu revient à la froide",
		VoxelCatalogue.teinte() == "froide" and VoxelCatalogue.teinte_de(PackedStringArray(["--teinte=olive"])) == "olive"
		and VoxelCatalogue.teinte_de(PackedStringArray(["--teinte=rose"])) == "froide"
		and VoxelCatalogue.teinte_de(PackedStringArray()) == "froide")
	var memes := true
	var bleus := true
	for nom in VoxelCatalogue.TENUES_SOMBRES:
		for sl in VoxelCatalogue.slugs():
			var po := VoxelCatalogue.palette_tenue(sl, nom, "olive")
			var pf := VoxelCatalogue.palette_tenue(sl, nom, "froide")
			for cle in ["ocre", "rouille", "brun", "arme", "bouteille", "cartouche", "tete", "arete"]:
				var co: Color = po[cle]
				var cf: Color = pf[cle]
				if absf(VoxelCatalogue.luminance_affichee(co) - VoxelCatalogue.luminance_affichee(cf)) > 0.003 or co.a != cf.a:
					memes = false
			for cle in ["ocre", "rouille", "arme", "tete"]:
				var cf: Color = pf[cle]
				if not (cf.b > cf.r + 0.02):
					bleus = false
			if pf["cartouche"] != po["cartouche"] or pf["brun"] != po["brun"]:
				memes = false
	_check("teinte froide : chaque rôle à la clarté de sa version olive, cartouches et cuir inchangés (trois tenues, dix classes)", memes)
	_check("teinte froide : le drap, l'usure, le métal et la tête dans les bleus (b > r)", bleus)
	var plafond := VoxelCatalogue.luminance_affichee(VoxelCatalogue.GRIS_PLAFOND)
	for nom in VoxelCatalogue.TENUES_SOMBRES:
		var r: Dictionary = VoxelCatalogue.TENUES_SOMBRES[nom]
		var justes := true
		var sous_plafond := true
		var detail := ""
		for s in VoxelCatalogue.slugs():
			var p := VoxelCatalogue.palette_tenue(s, nom)
			var gris: float = VoxelCatalogue.luminance_affichee(VoxelCatalogue.fiche(s)["couleur"])
			for pair in [["ocre", "tissu"], ["rouille", "usure"], ["brun", "cuir"], ["arme", "arme"], ["bouteille", "bouteille"],
					["cartouche", "cartouche"], ["tete", "tete"], ["arete", "arete"]]:
				var c: Color = p[pair[0]]
				if (pair[0] == "cartouche" or pair[0] == "arete") and c.a <= 0.0:
					continue
				var l := VoxelCatalogue.luminance_affichee(c)
				var voulu := minf(gris * float(r[pair[1]]), plafond)
				if not (l <= voulu + 0.003 and l >= voulu - 0.02):
					justes = false
					detail += "%s/%s %.4f≠%.4f " % [s, pair[0], l, voulu]
				if l > plafond + 0.001:
					sous_plafond = false
		_check("%s : chaque rôle à son rapport au gris de sa classe, dans les dix classes" % nom, justes, detail)
		_check("%s : rien au-dessus de Charte.DIM" % nom, sous_plafond)
		var gris_sp := VoxelCatalogue.fiche("spectre")["couleur"] as Color
		var p_sp := VoxelCatalogue.palette_tenue("spectre", nom)
		_check("%s : le cuir et l'usure se détachent du tissu par la teinte (%.2f, %.2f)" % [nom,
			_ecart_de_teinte(p_sp["ocre"], p_sp["brun"]), _ecart_de_teinte(p_sp["ocre"], p_sp["rouille"])],
			_ecart_de_teinte(p_sp["ocre"], p_sp["brun"]) > 0.03 and _ecart_de_teinte(p_sp["ocre"], p_sp["rouille"]) > 0.03)
		var r_inc := VoxelCatalogue.palette_tenue("incendiaire", nom)["cartouche"] as Color
		_check("%s : les cartouches de l'Incendiaire restent rouges (%.2f / %.2f)" % [nom, r_inc.r, r_inc.g], r_inc.r > 2.0 * r_inc.g)
		# Le noir absolu, dans le miroir de la teinte : sous le seuil, jamais un canal plus haut que le gris.
		var sous_seuil := bool(r["sous_seuil"])
		var monte := false
		for cle in ["ocre", "brun", "tete", "arete"]:
			var fc: Color = p_sp[cle]
			if fc.a <= 0.0:
				continue
			for k in [0.0, 0.01, 0.03, 0.05]:
				var c: Vector3 = _brut(gris_sp) * float(k)
				var t := _teindre(c, fc, gris_sp, sous_seuil, r["seuils"])
				if IsoPate.luminance(c) < 10.0 / 255.0 and (t.x > c.x + 1e-6 or t.y > c.y + 1e-6 or t.z > c.z + 1e-6):
					monte = true
		_check("%s : sous le seuil du noir, aucun canal ne monte (0 reste 0)" % nom, not monte
			and _teindre(Vector3.ZERO, p_sp["tete"], gris_sp, sous_seuil, r["seuils"]) == Vector3.ZERO)
		_check("%s : la teinte ne commence jamais sous 10/255 (%.1f/255)" % [nom, (r["seuils"] as Vector2).x * 255.0],
			(r["seuils"] as Vector2).x >= 10.0 / 255.0 - 1e-6 and (r["seuils"] as Vector2).y > (r["seuils"] as Vector2).x)
		if sous_seuil:
			var c5 := _brut(gris_sp) * 0.03
			var t5 := _teindre(c5, p_sp["ocre"], gris_sp, true)
			_check("%s : sous le seuil, le tissu assombrit le gris de son rapport (%.3f)" % [nom, t5.length() / c5.length()],
				absf(t5.length() / c5.length() - float(r["tissu"])) < 0.02)
	var v2 := VoxelCatalogue.TENUES_SOMBRES["sombre2"] as Dictionary
	var sous_un := true
	for cle in ["tissu", "usure", "cuir", "arme", "bouteille", "cartouche", "tete"]:
		sous_un = sous_un and float(v2[cle]) < 1.0
	_check("V2 : tous les rôles plus sombres que le gris, aucun liseré", sous_un and float(v2["arete"]) == 0.0)
	_check("V1 : laisse le gris sous le seuil du noir et teint plus haut (sa promesse est la visibilité d'aujourd'hui)",
		not bool(VoxelCatalogue.TENUES_SOMBRES["sombre1"]["sous_seuil"])
		and (VoxelCatalogue.TENUES_SOMBRES["sombre1"]["seuils"] as Vector2).x > 10.0 / 255.0)
	var gris_v1 := VoxelCatalogue.fiche("occulteur")["couleur"] as Color
	var tissu_v1 := VoxelCatalogue.palette_tenue("occulteur", "sombre1")["ocre"] as Color
	var bas_v1 := _brut(gris_v1) * (14.0 / 255.0) / IsoPate.luminance(_brut(gris_v1))
	_check("V1 : une lumière rendue à 14/255 reste le gris d'aujourd'hui (le tissu sombre n'y mord pas)",
		_teindre(bas_v1, tissu_v1, gris_v1, false, VoxelCatalogue.TENUES_SOMBRES["sombre1"]["seuils"]) == bas_v1)
	var inc := FileAccess.get_file_as_string("res://iso_corps_portrait.gdshaderinc")
	_check("l'include : la tête avant les pièces, le liseré après, l'assombrissement sous le seuil réglé par portrait_sous_seuil",
		inc.contains("if (portrait_tete.a > 0.0 && portrait_est(demi, portrait_demi_tete)) {")
		and inc.find("portrait_arete.rgb") > inc.find("portrait_cartouche.rgb")
		and inc.contains("vec3 sombre = c * mix(1.0, min(1.0, pate_luminance(fiche) / lg), portrait_sous_seuil);"))
	for chemin in SHADERS:
		var noms := []
		for u in (load(chemin) as Shader).get_shader_uniform_list():
			noms.append(String(u["name"]))
		_check("%s déclare la tête, le liseré et le seuil" % chemin.get_file(), noms.has("portrait_tete")
			and noms.has("portrait_demi_tete") and noms.has("portrait_arete") and noms.has("portrait_sous_seuil"))
	# Les corps : même géométrie que les portraits, la tête reconnue sur UNE boîte, le leurre pareil.
	var racine := Node3D.new()
	root.add_child(racine)
	var bascule_ok := true
	for s in VoxelCatalogue.slugs():
		VoxelCatalogue.forcer_tenue = "portraits"
		var ref := VoxelCorps.new()
		racine.add_child(ref)
		ref.construire(s)
		for nom in VoxelCatalogue.TENUES_SOMBRES:
			VoxelCatalogue.forcer_tenue = nom
			var corps := VoxelCorps.new()
			racine.add_child(corps)
			corps.construire(s)
			var m := corps.materiau()
			var demi_tete: Vector3 = m.get_shader_parameter("portrait_demi_tete")
			var tetes := 0
			for mi in corps.find_children("Boite", "MeshInstance3D", true, false):
				var taille: Vector3 = ((mi as MeshInstance3D).mesh as BoxMesh).size * 0.5
				var d := (taille - demi_tete).abs()
				if maxf(d.x, maxf(d.y, d.z)) < 0.0005:
					tetes += 1
			var ok: bool = float(m.get_shader_parameter("portrait")) == 1.0 and corps.nombre_de_boites() == ref.nombre_de_boites() \
				and absf(_pire_empreinte(corps, true) - _pire_empreinte(ref, true)) < EPSILON and tetes == 1 \
				and m.get_shader_parameter("portrait_ocre") == VoxelCatalogue.palette_tenue(s, nom)["ocre"]
			if not ok or s == "pistolet":
				_check("%s en %s : la tenue posée, la géométrie des portraits (%d boîtes), la tête sur une seule boîte (%d)"
					% [s, nom, corps.nombre_de_boites(), tetes], ok)
		# Le gris et la bascule par uniformes, qu'emploient les bancs.
		ref.porter_tenue("")
		var eteint := float(ref.materiau().get_shader_parameter("portrait")) == 0.0
		ref.porter_tenue("sombre2")
		if not eteint or ref.materiau().get_shader_parameter("portrait_tete") != VoxelCatalogue.palette_tenue(s, "sombre2")["tete"]:
			bascule_ok = false
			printerr("    porter_tenue ne bascule pas : ", s)
	_check("porter_tenue bascule le gris et les tenues sur la même matière (dix classes)", bascule_ok)
	VoxelCatalogue.forcer_tenue = "-"
	racine.queue_free()
	await process_frame


func _le_fil() -> void:
	print("— le fil")
	_check("Protocol.VERSION reste 18", FileAccess.get_file_as_string("res://protocol.gd").contains("const VERSION := 18"))


## Miroir de `portrait_teindre`, dans l'espace brut du shader (valeurs affichées : le rendu Compatibility montre les couleurs
## de fiche telles quelles — voir l'en-tête de `corps_iso.gdshader`, « Pas de conversion sRGB »).
static func _teindre(c: Vector3, fiche: Color, gris: Color, sous_seuil := true,
		seuils := Vector2(10.0, 24.0) / 255.0) -> Vector3:
	var l: float = IsoPate.luminance(Vector3(maxf(c.x, 0.0), maxf(c.y, 0.0), maxf(c.z, 0.0)))
	var lg := maxf(IsoPate.luminance(_brut(gris)), 0.000001)
	var sombre: Vector3 = c * (minf(1.0, IsoPate.luminance(_brut(fiche)) / lg) if sous_seuil else 1.0)
	var bas := maxf(seuils.x, 10.0 / 255.0)
	var haut := maxf(seuils.y, bas + 1.0 / 255.0)
	if l < bas:
		return sombre
	var teinte: Vector3 = _brut(fiche) * (l / lg)
	return sombre.lerp(teinte, smoothstep(bas, haut, l))


static func _brut(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


## L'écart de teinte entre deux couleurs à clarté égale : la distance de leurs chromaticités (r, g, b) / (r + g + b).
static func _ecart_de_teinte(a: Color, b: Color) -> float:
	var sa := maxf(a.r + a.g + a.b, 0.0001)
	var sb := maxf(b.r + b.g + b.b, 0.0001)
	return Vector3(a.r / sa - b.r / sb, a.g / sa - b.g / sb, a.b / sa - b.b / sb).length()
