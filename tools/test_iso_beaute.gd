## ISO7 Beauté — l'habillage de la vue iso ne dit rien de plus que la lightmap.
##
## Brief de la session cloud (2026-09-15, mandat d'Adrien) : matière sur les murs, le sol et les
## objets, encre d'arête, pâte de roman graphique — sans jamais trahir le noir absolu ni l'équité.
##
## Ce que cette suite prouve, sans fenêtre :
## - **les textures** du catalogue (`IsoMateriaux`) existent, sont connues de git, se tuilent sans
##   couture ni lumière cuite (`tools/verifie_tuilable.py`), et sont importées avec mipmaps et
##   filtrées (décision actée : « aucune texture en `nearest` ») ;
## - **le noir absolu** sur le miroir processeur des murs : 0 à lumière 0 quelle que soit la matière,
##   l'encre ou le liseré ; monotone en la lumière ; un point éclairé reste éclairé (le facteur le plus
##   bas est strictement positif) ;
## - **l'équité** : la matière ne lit que le MONDE (jamais la caméra ni la lightmap choisie), donc
##   vaut la même chose pour J1 et J2 ; toute couleur du shader des murs dérive d'une lecture de
##   lightmap (aucun terme qui éclaire de lui-même) ;
## - **les crochets** posés dans `presentation_3d.gd` sont là (la leçon du 2026-09-09 : une fusion
##   peut effacer une fonction sans aucune erreur), et la grille des murs est la masse même des boîtes ;
## - **le coût** : les boîtes gardent UN matériau commun — aucun appel de dessin de plus que la
##   géométrie d'ISO1 (les appels réels se comptent au banc).
##
## Ce qu'elle ne prouve pas : l'image. `tools/banc_iso_beaute.gd` mesure au pixel en vraie fenêtre.
extends SceneTree

const IsoPate := preload("res://iso_pate.gd")
const SHADER_MUR := preload("res://mur_iso.gdshader")

var _failures := 0
var _verifications := 0

## Les seuils de `tools/verifie_tuilable.py`, recopiés (voir `mesurer_tuilable`).
const RAPPORT_MAX := 1.6
const ECART_QUARTS_MAX := 12.0


## Miroir de `tools/verifie_tuilable.py`, formule pour formule : la couture (bord droit contre bord
## gauche, bas contre haut) rapportée à l'écart ORDINAIRE entre deux voisins, et l'écart entre les
## moyennes des quatre quarts (la lumière cuite). Niveaux sur 255, canal rouge (textures en gris).
static func mesurer_tuilable(image: Image) -> Dictionary:
	var w := image.get_width()
	var h := image.get_height()
	var colonnes := func(a: int, b: int) -> float:
		var s := 0.0
		for y in h:
			s += absf(image.get_pixel(a, y).r - image.get_pixel(b, y).r)
		return s * 255.0 / h
	var lignes := func(a: int, b: int) -> float:
		var s := 0.0
		for x in w:
			s += absf(image.get_pixel(x, a).r - image.get_pixel(x, b).r)
		return s * 255.0 / w
	var voisins_x := 0.0
	var n := 0
	for x in range(maxi(1, w / 11), w - 1, maxi(1, w / 11)):
		voisins_x += colonnes.call(x, x + 1)
		n += 1
	voisins_x /= maxi(1, n)
	var voisins_y := 0.0
	n = 0
	for y in range(maxi(1, h / 11), h - 1, maxi(1, h / 11)):
		voisins_y += lignes.call(y, y + 1)
		n += 1
	voisins_y /= maxi(1, n)
	var r_x: float = colonnes.call(w - 1, 0) / maxf(voisins_x, 0.5)
	var r_y: float = lignes.call(h - 1, 0) / maxf(voisins_y, 0.5)
	var quarts: Array[float] = []
	for q in [Rect2i(0, 0, w / 2, h / 2), Rect2i(w / 2, 0, w - w / 2, h / 2), Rect2i(0, h / 2, w / 2, h - h / 2),
			Rect2i(w / 2, h / 2, w - w / 2, h - h / 2)]:
		var s := 0.0
		var k := 0
		for y in range(q.position.y, q.end.y, 2):
			for x in range(q.position.x, q.end.x, 2):
				s += image.get_pixel(x, y).r
				k += 1
		quarts.append(s * 255.0 / maxi(1, k))
	var ecart: float = quarts.max() - quarts.min()
	return {"rapport_x": r_x, "rapport_y": r_y, "ecart_quarts": ecart,
		"tuilable": r_x <= RAPPORT_MAX and r_y <= RAPPORT_MAX, "plate": ecart <= ECART_QUARTS_MAX}


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== ISO7 — LA BEAUTÉ DE LA VUE ISO ===")
	await process_frame
	_les_textures()
	_le_noir_absolu()
	_l_equite_du_shader()
	_les_crochets_et_la_grille()
	_le_sol()
	_le_banc()
	print("%d vérifications, %d échec(s)" % [_verifications, _failures])
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# LE SOL — voie (b) : la lightmap fois la matière
# ---------------------------------------------------------------------------

func _le_sol() -> void:
	print("— le sol habillé")
	var shader_sol: Shader = load("res://sol_iso.gdshader")
	var pres := FileAccess.get_file_as_string("res://presentation_3d.gd")
	_check("crochet : le sol de la présentation est sol_iso.gdshader", pres.contains('preload("res://sol_iso.gdshader")'))
	_check("crochet : IsoMateriaux.accorder_sol dans presentation_3d.gd", pres.contains("IsoMateriaux.accorder_sol(mat)"))
	_check("le catalogue porte la matière du sol", IsoMateriaux.textures().has("res://assets/iso/sol.png"))
	var mat := ShaderMaterial.new()
	mat.shader = shader_sol
	IsoMateriaux.accorder_sol(mat)
	_check("la matière du sol est posée et allumée", mat.get_shader_parameter("texture_sol") == IsoMateriaux.TEXTURE_SOL
		and float(mat.get_shader_parameter("force_matiere")) > 0.0)
	var code := shader_sol.code
	_check("sol : unshaded", code.contains("render_mode unshaded"))
	_check("sol : la couleur naît de la lightmap", code.contains("vec3 c = lightmap_pateuse(px, px, aa, deux);"))
	_check("sol : la matière multiplie (c *= matiere), aucun terme additif",
		code.contains("c *= matiere;") and not code.contains("c += ") and not code.contains("c -= "))
	var ligne_uv := ""
	for l in code.split("\n"):
		if l.contains("texture(texture_sol"):
			ligne_uv = l
	_check("sol : la matière ne lit que le monde", ligne_uv.contains("px /") and not ligne_uv.contains("deux"), ligne_uv)
	# Le noir absolu du miroir, et le seuil tenu : un point éclairé reste éclairé.
	var faux := 0
	var eteints := 0
	for mi in 6:
		var matiere := IsoMateriaux.PLANCHER + (1.0 - IsoMateriaux.PLANCHER) * mi / 5.0
		for li in 21:
			var brute := Vector3(0.9, 0.8, 0.6) * (li / 20.0)
			var l := IsoPate.luminance(brute)
			var pateuse := IsoPate.pate(brute, l, IsoPate.LAVIS, Vector2(mi * 11.0, li * 3.0), Vector2.ZERO, l, 0.1)
			var c := IsoMateriaux.sol(pateuse, matiere, IsoMateriaux.FORCE_MATIERE_SOL)
			if li == 0 and c != Vector3.ZERO:
				faux += 1
			if IsoPate.luminance(pateuse) > 0.0 and IsoPate.luminance(c) <= 0.0:
				eteints += 1
	_check("sol : noir à lumière 0 sous toute matière", faux == 0, "%d non nuls" % faux)
	_check("sol : un point éclairé reste éclairé", eteints == 0, "%d éteints" % eteints)


# ---------------------------------------------------------------------------
# LE BANC — ses appuis, sans fenêtre
# ---------------------------------------------------------------------------

func _le_banc() -> void:
	print("— les appuis du banc ISO7")
	var banc: GDScript = load("res://tools/banc_iso_beaute.gd")
	_check("le banc se charge (hérite de banc_iso.gd)", banc != null and banc.can_instantiate())
	if banc == null:
		return
	# Les mesures, sur des images fabriquées : un habillage honnête, un qui éteint, un qui allume une surface.
	var avant := Image.create_empty(20, 10, false, Image.FORMAT_RGB8)
	avant.fill(Color(0, 0, 0))
	avant.fill_rect(Rect2i(0, 0, 10, 10), Color(0.5, 0.4, 0.3))
	var honnete := avant.duplicate() as Image
	honnete.fill_rect(Rect2i(0, 0, 10, 10), Color(0.4, 0.33, 0.25))
	honnete.set_pixel(10, 0, Color(0.3, 0.3, 0.3))
	var m: Dictionary = banc.mesurer(avant, honnete)
	_check("banc : un habillage honnête n'éteint rien (%d)" % m["eteints"], m["eteints"] == 0)
	_check("banc : un liseré se compte comme allumé neuf (%d)" % m["neufs"], m["neufs"] == 1)
	var eteignant := avant.duplicate() as Image
	eteignant.set_pixel(3, 3, Color(0, 0, 0))
	_check("banc : un pixel clair éteint est vu", (banc.mesurer(avant, eteignant) as Dictionary)["eteints"] == 1)
	var allumant := avant.duplicate() as Image
	allumant.fill_rect(Rect2i(10, 0, 10, 10), Color(0.2, 0.2, 0.2))
	var part := float((banc.mesurer(avant, allumant) as Dictionary)["part_neuve"])
	_check("banc : une surface qui s'allume dépasse la part permise (%.2f > %.2f)" % [part, banc.PART_NEUVE_MAX],
		part > banc.PART_NEUVE_MAX)
	var neutres: Dictionary = banc.NEUTRES
	for p in ["force_matiere", "encre_arete_px", "lisere_sommet_px", "seuil_muret_px"]:
		_check("banc : l'avant neutralise %s" % p, neutres.has(p) and float(neutres[p]) == 0.0)
	_check("banc : la scène du banc existe", ResourceLoader.exists("res://tools/banc_iso_beaute.tscn"))


# ---------------------------------------------------------------------------
# LES TEXTURES
# ---------------------------------------------------------------------------

func _les_textures() -> void:
	print("— les textures")
	var textures := IsoMateriaux.textures()
	_check("le catalogue porte au moins la face de mur", textures.has("res://assets/iso/face_mur.png"),
		str(textures.keys()))
	for chemin: String in textures:
		var tex: Texture2D = textures[chemin]
		_check("%s : chargée, 512 px ou moins" % chemin, tex != null and tex.get_width() <= 512
			and tex.get_width() == tex.get_height(), "%s" % [tex.get_size() if tex != null else "absente"])
		var disque := ProjectSettings.globalize_path(chemin)
		var sortie := []
		var code := OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "ls-files",
			"--error-unmatch", disque], sortie, true)
		_check("%s : connue de git" % chemin, code == 0, "".join(sortie).strip_edges())
		var import := FileAccess.get_file_as_string(chemin + ".import")
		_check("%s : importée avec mipmaps" % chemin, import.contains("mipmaps/generate=true"))
		_check("%s : le .import est connu de git" % chemin, OS.execute("git", ["-C",
			ProjectSettings.globalize_path("res://"), "ls-files", "--error-unmatch", disque + ".import"], [], true) == 0)
		var image := tex.get_image()
		if image != null and image.is_compressed():
			image.decompress()
		# ⚠️ **Mesuré ici en GDScript, pas en appelant `tools/verifie_tuilable.py`.** Le lot exporte un
		# `HOME` isolé : le Python de l'utilisateur y perd ses paquets (PIL vit dans
		# `~/Library/Python/…/site-packages`), le vérificateur sortait en erreur d'import, et la suite
		# rougissait dans le lot en passant seule (2026-09-15). Mêmes formules, mêmes seuils.
		var t := mesurer_tuilable(image) if image != null else {}
		_check("%s : tuilable sans couture (x %.2f, y %.2f, max %.1f)" % [chemin, t.get("rapport_x", -1.0),
			t.get("rapport_y", -1.0), RAPPORT_MAX], bool(t.get("tuilable", false)))
		_check("%s : sans lumière cuite (quarts ±%.1f, max %.0f)" % [chemin, t.get("ecart_quarts", -1.0),
			ECART_QUARTS_MAX], bool(t.get("plate", false)))
		# Un FACTEUR : le plus sombre texel reste au-dessus du plancher, jamais à zéro.
		var bas := 1.0
		if image != null:
			for y in range(0, image.get_height(), 7):
				for x in range(0, image.get_width(), 7):
					bas = minf(bas, image.get_pixel(x, y).r)
		_check("%s : facteur borné par le plancher (%.2f ≥ %.2f)" % [chemin, bas, IsoMateriaux.PLANCHER - 0.02],
			bas >= IsoMateriaux.PLANCHER - 0.02)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_MUR
	IsoMateriaux.accorder_mur(mat)
	_check("la face de mur est posée sur le matériau", mat.get_shader_parameter("texture_face") == IsoMateriaux.TEXTURE_FACE_MUR)
	_check("la matière est allumée (force %s)" % mat.get_shader_parameter("force_matiere"),
		float(mat.get_shader_parameter("force_matiere")) > 0.0)
	var source := SHADER_MUR.code
	_check("la face est lue en mipmaps filtrés, en répétition", source.contains("texture_face : hint_default_white, filter_linear_mipmap, repeat_enable"))


# ---------------------------------------------------------------------------
# LE NOIR ABSOLU — miroir processeur, balayé
# ---------------------------------------------------------------------------

func _le_noir_absolu() -> void:
	print("— le noir absolu sur le miroir des murs")
	var zeros_faux := 0
	var non_monotones := 0
	var eteints := 0
	var n := 0
	var bas := INF
	for mi in 11:
		var matiere := IsoMateriaux.PLANCHER + (1.0 - IsoMateriaux.PLANCHER) * mi / 10.0
		for ei in 5:
			var encre := ei / 4.0
			# La lumière reçue : une couleur de lightmap passée à la pâte D, sur un lieu du monde.
			var lieu := Vector2(13.7 * mi + 3.1 * ei, 7.9 * ei - 2.3 * mi)
			var precedent := -1.0
			for li in 41:
				var niveau := li / 40.0
				var brute := Vector3(1.0, 0.86, 0.62) * niveau
				var l := IsoPate.luminance(brute)
				var pateuse := IsoPate.pate(brute, l, IsoPate.LAVIS, lieu, Vector2.ZERO, l, 0.1)
				for c: Vector3 in [IsoMateriaux.face(pateuse, matiere, 1.0, encre),
						IsoMateriaux.sommet(pateuse, encre), IsoMateriaux.dessus_muret(pateuse, encre)]:
					n += 1
					if niveau == 0.0 and c != Vector3.ZERO:
						zeros_faux += 1
				var face := IsoMateriaux.face(pateuse, matiere, 1.0, encre)
				var lf := IsoPate.luminance(face)
				if lf + 1e-6 < precedent:
					non_monotones += 1
				precedent = lf
				if IsoPate.luminance(pateuse) > 0.0:
					if lf <= 0.0:
						eteints += 1
					bas = minf(bas, lf / IsoPate.luminance(pateuse))
	_check("à lumière 0, mur, sommet et muret sont noirs (%d cas)" % n, zeros_faux == 0, "%d non nuls" % zeros_faux)
	_check("la face est monotone en la lumière", non_monotones == 0, "%d reculs" % non_monotones)
	_check("un point éclairé reste éclairé sous matière et encre", eteints == 0, "%d éteints" % eteints)
	_check("le facteur le plus bas (matière × encre) reste > 0 (%.3f)" % bas, bas > 0.0)
	# Le sabotage que ce contrôle sait voir : une ambiance additive de 1 %.
	var ambiance := IsoMateriaux.face(Vector3.ZERO, 1.0, 1.0, 0.0) + Vector3.ONE * 0.01
	_check("témoin : une ambiance de 1 % serait refusée", ambiance != Vector3.ZERO)


# ---------------------------------------------------------------------------
# L'ÉQUITÉ, LUE DANS LE SHADER
# ---------------------------------------------------------------------------

func _l_equite_du_shader() -> void:
	print("— l'équité dans mur_iso.gdshader")
	var lignes := SHADER_MUR.code.split("\n")
	var dans_fragment := false
	var affectations := []
	var uv_matiere := ""
	for brute in lignes:
		var ligne := brute.strip_edges()
		if ligne.begins_with("void fragment()"):
			dans_fragment = true
		if not dans_fragment or ligne.begins_with("//"):
			continue
		if ligne.begins_with("c = ") or ligne.begins_with("vec3 c = "):
			affectations.append(ligne)
		if ligne.contains("texture(texture_face"):
			uv_matiere = ligne
	_check("le fragment affecte la couleur", not affectations.is_empty())
	var sources_propres := true
	for a: String in affectations:
		if not (a.contains("lightmap_pateuse(") or a.contains("vec3(0.0)")):
			sources_propres = false
			printerr("    affectation hors lightmap : ", a)
	_check("toute couleur de mur naît d'une lecture de lightmap ou du noir", sources_propres)
	var multiplications := 0
	for brute in lignes:
		var ligne := brute.strip_edges()
		if ligne.begins_with("c += ") or ligne.begins_with("c -= "):
			sources_propres = false
		if ligne.begins_with("c *= "):
			multiplications += 1
	_check("aucun terme additif sur la couleur (c += / c -=)", sources_propres)
	_check("l'encre multiplie (%d c *=)" % multiplications, multiplications >= 2)
	_check("la matière est accrochée au monde", uv_matiere.contains("monde"), uv_matiere)
	_check("la matière ne dépend ni de la caméra ni du joueur", not uv_matiere.contains("deux")
		and not uv_matiere.contains("CAMERA") and not uv_matiere.contains("VIEW"), uv_matiere)
	_check("aucune Light3D ni lumière du moteur (unshaded)", SHADER_MUR.code.contains("render_mode unshaded"))


# ---------------------------------------------------------------------------
# LES CROCHETS ET LA GRILLE
# ---------------------------------------------------------------------------

func _les_crochets_et_la_grille() -> void:
	print("— les crochets et la grille des murs")
	var pres := FileAccess.get_file_as_string("res://presentation_3d.gd")
	_check("crochet : IsoMateriaux.accorder_mur dans presentation_3d.gd", pres.contains("IsoMateriaux.accorder_mur(_mat_mur)"))
	_check("crochet : IsoMateriaux.accorder_grille dans presentation_3d.gd",
		pres.contains("IsoMateriaux.accorder_grille(_mat_mur, data)"))
	var cartes := root.get_node_or_null("MapData")
	var essais := []
	if cartes != null and cartes.has_method("get_selected"):
		essais.append(cartes.get_selected())
	var murs_bas := FileAccess.get_file_as_string("res://tools/cartes/murs_bas_essai.json")
	if murs_bas != "":
		var d = JSON.parse_string(murs_bas)
		if d is Dictionary:
			essais.append(d)
	_check("au moins une carte à éprouver", not essais.is_empty())
	var tuile := float(CandelaTileSet.TILE_SIZE.x)
	for data: Dictionary in essais:
		var mat := ShaderMaterial.new()
		mat.shader = SHADER_MUR
		IsoMateriaux.accorder_mur(mat)
		var murs := IsoGeometrie.build_meshes(data, mat)
		IsoMateriaux.accorder_grille(mat, data)
		var image := IsoMateriaux.image_grille(data)
		var hors := 0
		var boites := 0
		var materiaux := {}
		for boite: MeshInstance3D in murs.get_children():
			boites += 1
			materiaux[boite.material_override] = true
			var bas := String(boite.name).begins_with("MurBas")
			var canal := 1 if bas else 0
			# Chaque case couverte par la boîte doit porter la masse, dans le bon canal.
			var x0 := boite.position.x - boite.scale.x * 0.5
			var z0 := boite.position.z - boite.scale.z * 0.5
			var nx := int(round(boite.scale.x / tuile))
			var nz := int(round(boite.scale.z / tuile))
			for i in nx:
				for k in nz:
					var gx := int(floor((x0 + (i + 0.5) * tuile) / tuile)) + MapGeometry.BORDER
					var gz := int(floor((z0 + (k + 0.5) * tuile) / tuile)) + MapGeometry.BORDER
					var ok := gx >= 0 and gz >= 0 and gx < image.get_width() and gz < image.get_height() \
						and (image.get_pixel(gx, gz).r if canal == 0 else image.get_pixel(gx, gz).g) > 0.5
					if not ok:
						hors += 1
		var nom := String(data.get("name", data.get("nom", "carte")))
		_check("%s : chaque case de chaque boîte est dans la grille (%d boîtes)" % [nom, boites], hors == 0 and boites > 0,
			"%d cases hors grille" % hors)
		_check("%s : un seul matériau pour toutes les boîtes (aucun appel de dessin de plus)" % nom, materiaux.size() == 1,
			"%d matériaux" % materiaux.size())
		_check("%s : la grille est posée et active" % nom, bool(mat.get_shader_parameter("grille_active"))
			and mat.get_shader_parameter("grille_cases") == Vector2(image.get_size()))
		murs.free()
