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
	_la_pate_des_voxels()
	_les_faces_et_le_bain()
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
	_check("sol : la couleur naît de la lightmap (tonée avant la pâte)", code.contains("vec3 c = lightmap_pateuse_sol(px_lu, px, aa, deux);")
		and code.contains("vec3 c = lire_lightmap(p, deux) * ton_du_sol(p);"))
	_check("sol : la matière passe par pate_facteur, aucun terme additif",
		code.contains("c = pate_facteur(c, matiere * dalle);") and not code.contains("c *= ") and not code.contains("c += ") and not code.contains("c -= "))
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
# LA PÂTE — l'encre des arêtes des voxels (étape 5)
# ---------------------------------------------------------------------------

func _la_pate_des_voxels() -> void:
	print("— la pâte : l'encre des arêtes")
	var inc := FileAccess.get_file_as_string("res://iso_pate.gdshaderinc")
	_check("la pâte offre pate_trait_de_bord et pate_encre_boite",
		inc.contains("float pate_trait_de_bord(") and inc.contains("float pate_encre_boite("))
	_check("les murs utilisent l'encre partagée (aucune copie locale)",
		SHADER_MUR.code.contains("pate_trait_de_bord(") and not SHADER_MUR.code.contains("float trait_de_bord("))
	var reste := IsoMateriaux.ENCRE_VOXEL_RESTE
	var largeur := IsoMateriaux.ENCRE_VOXEL_PX
	# Deux constructions de boîte : le cube unité mis à l'échelle (murs) et la BoxMesh à sa vraie taille
	# sous l'ancre d'une tuile (voxels, `voxel_corps.gd:_boite`) — même face, mêmes distances au monde.
	var constructions := {
		"cube unité × (20, 30, 14)": [Vector3(0.5, 0.5, 0.5), Vector3(20.0, 30.0, 14.0)],
		"BoxMesh (0,57 ; 0,86 ; 0,4) × tuile": [Vector3(0.2857, 0.4286, 0.2), Vector3(35.0, 35.0, 35.0)],
	}
	for nom: String in constructions:
		var demi: Vector3 = constructions[nom][0]
		var echelle: Vector3 = constructions[nom][1]
		var centre := IsoPate.encre_boite(Vector3(demi.x, 0.0, 0.0), demi, echelle, Vector3.RIGHT, largeur, reste, 0.3)
		var bord := IsoPate.encre_boite(Vector3(demi.x, demi.y, 0.0), demi, echelle, Vector3.RIGHT, largeur, reste, 0.3)
		# À un pixel de monde du bord haut : hors du trait de 0,9 px (aa 0,3) → encore presque 1.
		var pres := IsoPate.encre_boite(Vector3(demi.x, demi.y - 1.6 / echelle.y, 0.0), demi, echelle, Vector3.RIGHT,
			largeur, reste, 0.3)
		_check("encre (%s) : 1 au milieu de la face (%.3f)" % [nom, centre], is_equal_approx(centre, 1.0))
		_check("encre (%s) : le reste sur l'arête (%.3f ≈ %.2f)" % [nom, bord, reste], absf(bord - reste) < 0.01)
		_check("encre (%s) : le trait se mesure en pixels de monde (%.3f à 1,6 px)" % [nom, pres], pres > 0.99)
		var hors := 0
		for i in 21:
			for k in 21:
				for n: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
					var local := Vector3(-demi.x + 2.0 * demi.x * i / 20.0, -demi.y + 2.0 * demi.y * k / 20.0,
						demi.z - demi.z * (i + k) / 20.0)
					var f := IsoPate.encre_boite(local, demi, echelle, n, largeur, reste, 0.3)
					if f < reste - 1e-5 or f > 1.0 + 1e-5:
						hors += 1
		_check("encre (%s) : le facteur reste dans [reste, 1] sur toute la boîte" % nom, hors == 0, "%d hors" % hors)
	_check("encre : largeur 0 = aucun effet", is_equal_approx(IsoPate.encre_boite(Vector3.ONE * 0.5, Vector3.ONE * 0.5,
		Vector3.ONE, Vector3.RIGHT, 0.0, reste, 0.3), 1.0))
	var pres := FileAccess.get_file_as_string("res://presentation_3d.gd")
	_check("crochet : IsoMateriaux.accorder_corps dans presentation_3d.gd", pres.contains("IsoMateriaux.accorder_corps(mat)"))
	var mat := ShaderMaterial.new()
	IsoMateriaux.accorder_corps(mat)
	_check("accorder_corps pose l'encre des voxels", is_equal_approx(float(mat.get_shader_parameter("encre_arete")), largeur)
		and is_equal_approx(float(mat.get_shader_parameter("encre_reste")), reste))

	print("— la lumière vue : la température (étape 6)")
	_check("la pâte offre pate_temperature", inc.contains("vec3 pate_temperature(vec3 c, float force)"))
	var t := IsoMateriaux.TEMPERATURE
	var ecart_lum := 0.0
	var zeros := 0
	for i in 12:
		for k in 12:
			var c := Vector3(i / 11.0, k / 11.0, (i + k) / 22.0)
			var r := IsoPate.temperature(c, t)
			if c == Vector3.ZERO and r != Vector3.ZERO:
				zeros += 1
			ecart_lum = maxf(ecart_lum, absf(IsoPate.luminance(r) - IsoPate.luminance(c)))
	_check("température : 0 reste 0", zeros == 0 and IsoPate.temperature(Vector3.ZERO, 1.0) == Vector3.ZERO)
	_check("température : la luminance est gardée (écart max %.8f)" % ecart_lum, ecart_lum < 1e-5)
	var gris := IsoPate.temperature(Vector3(0.5, 0.5, 0.5), t)
	_check("température : un gris devient chaud (%s)" % str(gris), gris.x > gris.y and gris.y > gris.z)
	var rouge := Vector3(0.9, 0.08, 0.05)
	var rouge_t := IsoPate.temperature(rouge, t)
	_check("température : une lumière saturée garde sa teinte (%s)" % str(rouge_t), rouge_t.distance_to(rouge) < 0.01)
	var halogene := Vector3(Charte.HALOGENE.r, Charte.HALOGENE.g, Charte.HALOGENE.b)
	var lave := halogene.lerp(Vector3.ONE * IsoPate.luminance(halogene), 0.35)
	var rechauffe := IsoPate.temperature(lave, t)
	_check("température : l'halogène lavé par la pâte D retrouve de la chaleur (b/r %.3f < %.3f)"
		% [rechauffe.z / rechauffe.x, lave.z / lave.x], rechauffe.z / rechauffe.x < lave.z / lave.x)
	var mur := ShaderMaterial.new()
	mur.shader = SHADER_MUR
	IsoMateriaux.accorder_mur(mur)
	var sol := ShaderMaterial.new()
	sol.shader = load("res://sol_iso.gdshader")
	IsoMateriaux.accorder_sol(sol)
	# ⚠️ Un uniform utilisé mais non déclaré ne fait qu'un `SHADER ERROR` dans le journal, qu'aucun contrôle
	# ne voit (piège consigné, et repayé ici le 2026-09-15 : le lot est sorti vert avec le mur cassé).
	_check("mur et sol DÉCLARENT l'uniform temperature", SHADER_MUR.code.contains("uniform float temperature")
		and (load("res://sol_iso.gdshader") as Shader).code.contains("uniform float temperature"))
	_check("mur et sol déclarent tous les uniforms que le catalogue pose", _uniforms_declares())
	_check("température posée sur le mur et le sol (graduée, ISO7b)", is_equal_approx(float(mur.get_shader_parameter("temperature")),
		IsoMateriaux.TEMPERATURE_GRADUEE) and is_equal_approx(float(sol.get_shader_parameter("temperature")), IsoMateriaux.TEMPERATURE_GRADUEE))
	_check("sol : la température s'applique après la matière", (load("res://sol_iso.gdshader") as Shader).code.contains(
		"c = pate_facteur(c, matiere * dalle);\n\t// ISO7b"))
	# Le facteur se VOIT tel qu'il est écrit : la raison d'être de pate_facteur (banc du 2026-09-15).
	var gris_ecrit := Vector3(0.37, 0.37, 0.37)
	var affiche := IsoPate.luminance(IsoPate.vers_affiche(IsoPate.facteur(gris_ecrit, 0.25))) / IsoPate.luminance(IsoPate.vers_affiche(gris_ecrit))
	_check("pate_facteur : 0,25 posé se voit 0,25 (%.4f)" % affiche, absf(affiche - 0.25) < 1e-3)
	_check("pate_facteur : 0 reste 0, et facteur 1 rend la couleur", IsoPate.facteur(Vector3.ZERO, 0.7) == Vector3.ZERO
		and IsoPate.facteur(gris_ecrit, 1.0).distance_to(gris_ecrit) < 1e-5)
	_check("la pâte offre pate_facteur et pate_matiere_et_encre", inc.contains("vec3 pate_facteur(vec3 c, float f)")
		and inc.contains("vec3 pate_matiere_et_encre("))
	# Le cas du banc : une face à 21/255 sous une encre pleine tombait à 1/255.
	var sombre := IsoPate.depuis_affiche(Vector3.ONE * (21.0 / 255.0))
	var vue := IsoPate.luminance(IsoPate.vers_affiche(IsoMateriaux.face(sombre, 1.0, 0.0, 1.0))) * 255.0
	_check("encre pleine sur une face à 21/255 : reste au-dessus de 2/255 (%.1f)" % vue, vue > 2.0)
	var claire := IsoPate.depuis_affiche(Vector3.ONE * (200.0 / 255.0))
	var vue_claire := IsoPate.luminance(IsoPate.vers_affiche(IsoMateriaux.face(claire, 1.0, 0.0, 1.0))) * 255.0
	_check("encre pleine sur une face à 200/255 : l'arête se voit (%.1f ≤ 60)" % vue_claire, vue_claire <= 60.0)


## Chaque `set_shader_parameter("x", …)` des fonctions d'accord du catalogue (murs et grille → mur_iso,
## sol → sol_iso) nomme un uniform que le shader DÉCLARE. `accorder_corps` est exclu : ses uniforms
## vivent chez ISO Corps, et le paramètre est ignoré tant qu'elle ne les déclare pas (voulu).
func _uniforms_declares() -> bool:
	var source := FileAccess.get_file_as_string("res://iso_materiaux.gd")
	var codes := {"mur": SHADER_MUR.code, "grille": SHADER_MUR.code,
		"sol": (load("res://sol_iso.gdshader") as Shader).code, "corps": (load("res://corps_iso.gdshader") as Shader).code}
	var parametre := RegEx.create_from_string("set_shader_parameter\\(\"([a-z_0-9]+)\"")
	var ok := true
	var vus := 0
	for bloc in source.split("static func accorder_").slice(1):
		var nom := bloc.get_slice("(", 0)
		if not codes.has(nom):
			continue
		# Le bloc s'arrête à la fonction suivante, quelle qu'elle soit.
		var corps := bloc.get_slice("\nstatic func ", 0)
		for m in parametre.search_all(corps):
			vus += 1
			var u := m.get_string(1)
			var declaration := RegEx.create_from_string("uniform [^;]*\\b%s\\b" % u)
			if declaration.search(codes[nom]) == null:
				ok = false
				printerr("    uniform non déclaré dans le shader « %s » : %s" % [nom, u])
	return ok and vus >= 15


# ---------------------------------------------------------------------------
# ISO7b — LES FACES PRENNENT LA LUMIÈRE, LE BAIN EST CHAUD, LE SOL EN DALLES
# ---------------------------------------------------------------------------

func _les_faces_et_le_bain() -> void:
	print("— ISO7b : les faces, le bain, les dalles")
	# Sous la MÊME lightmap — une torche posée à 3 tuiles devant un mur, dont la lumière décroît avec la distance —,
	# la face qui la regarde et la face de profil (la torche sur son côté) lisent quatre valeurs différentes.
	var source := Vector2(0.0, 105.0)
	var lumiere := func(p: Vector2) -> float:
		return maxf(0.0, 1.0 - p.distance_to(source) / 200.0)
	var pas := IsoMateriaux.LAMBERT_PAS_PX
	# Face qui regarde +y (vers la torche), pied en (0, 8).
	var pied_face := Vector2(0.0, 8.0)
	var face := IsoMateriaux.lambert(lumiere.call(pied_face), lumiere.call(pied_face + Vector2(0, pas)),
		lumiere.call(pied_face + Vector2(pas, 0)), lumiere.call(pied_face - Vector2(pas, 0)))
	# Face qui regarde +x, pied à 3 tuiles à gauche de la torche : la lumière vient de son côté.
	var pied_profil := Vector2(-8.0, 105.0) + Vector2(-60.0, 0.0)
	var n := Vector2(-1.0, 0.0)
	var t := Vector2(0.0, -1.0)
	var profil := IsoMateriaux.lambert(lumiere.call(pied_profil), lumiere.call(pied_profil + n * pas),
		lumiere.call(pied_profil + t * pas), lumiere.call(pied_profil - t * pas))
	_check("sous la même lightmap, la face qui regarde la torche est plus claire que celle de dos (%.2f > %.2f)" % [face, profil],
		face > profil + 0.2)
	_check("la face qui regarde la torche garde toute sa lumière (%.2f)" % face, face > 0.95)
	_check("la face de dos ne descend pas sous le plancher (%.2f ≥ %.2f)" % [profil, IsoMateriaux.LAMBERT_PLANCHER],
		profil >= IsoMateriaux.LAMBERT_PLANCHER - 1e-4)
	_check("lumière uniforme : aucune direction, la face garde sa lumière", is_equal_approx(IsoMateriaux.lambert(0.5, 0.5, 0.5, 0.5), 1.0))
	_check("plancher 1 : le Lambert est éteint", is_equal_approx(IsoMateriaux.lambert(0.1, 0.9, 0.0, 0.0, 1.0), 1.0))
	var code_mur := SHADER_MUR.code
	_check("le gradient se lit DEVANT la face, jamais derrière", code_mur.contains("pied_px + n * lambert_pas_px")
		and not code_mur.contains("pied_px - n * lambert_pas_px"))
	_check("Lambert et contact multiplient la matière", code_mur.contains("matiere * lambert * contact"))
	# Les rayures des faces (constat de la session cloud, 2026-09-15 12:10) : la lecture au pied tombait dans les hachures.
	var portee_max := MurEncre.HACHURE_PORTEE * 1.2
	_check("la face lit sa lumière au-delà des hachures d'encre (pied %.1f > portée %.1f)" % [IsoMateriaux.PIED_FACE_PX, portee_max],
		IsoMateriaux.PIED_FACE_PX > portee_max + 1.0)
	_check("la face et le liseré lisent une moyenne le long du mur, sur une période de hachure",
		code_mur.contains("c = lightmap_pateuse_moyenne(monde.xz + n * pied, tangente") and code_mur.contains("lightmap_pateuse_moyenne(monde.xz + sortie")
		and is_equal_approx(1.875 + 1.875, MurEncre.HACHURE_PAS * 0.75))
	# La température graduée : plus chaude en basse lumière, luminance gardée.
	var bas := IsoPate.temperature_graduee(IsoPate.depuis_affiche(Vector3.ONE * 0.06), 0.8, IsoMateriaux.TEMPERATURE_SEUIL_BAS,
		IsoMateriaux.TEMPERATURE_SEUIL_HAUT)
	var haut := IsoPate.temperature_graduee(IsoPate.depuis_affiche(Vector3.ONE * 0.7), 0.8, IsoMateriaux.TEMPERATURE_SEUIL_BAS,
		IsoMateriaux.TEMPERATURE_SEUIL_HAUT)
	_check("bain : plus chaud au bord (r/g %.2f) qu'au centre (r/g %.2f)" % [bas.x / bas.y, haut.x / haut.y],
		bas.x / bas.y > haut.x / haut.y + 0.1)
	var gris := IsoPate.depuis_affiche(Vector3.ONE * 0.3)
	_check("bain : luminance gardée", absf(IsoPate.luminance(IsoPate.temperature_graduee(gris, 0.8, 0.08, 0.45)) - IsoPate.luminance(gris)) < 1e-5)
	_check("bain : 0 reste 0", IsoPate.temperature_graduee(Vector3.ZERO, 1.0, 0.08, 0.45) == Vector3.ZERO)
	# Les dalles : le damier est ASSOMBRI, jamais éclairci.
	var sol_code := (load("res://sol_iso.gdshader") as Shader).code
	_check("dalles : la case claire est assombrie (ton_a < ton_b)", CandelaTileSet.SOL_DESSIN_A.get_luminance() < CandelaTileSet.SOL_DESSIN_B.get_luminance()
		and sol_code.contains("pow(ton_a / ton_b, ton_exposant)"))
	var mur := ShaderMaterial.new()
	mur.shader = SHADER_MUR
	IsoMateriaux.accorder_mur(mur)
	var sol := ShaderMaterial.new()
	sol.shader = load("res://sol_iso.gdshader")
	IsoMateriaux.accorder_sol(sol)
	# ISO7b, ordre 17 — le modelé des corps : même gradient, faces du voxel.
	var g_lampe := Vector2(0.0, 0.2)   # la lumière monte vers +z (la lampe est au sud du corps)
	var face_sud := IsoMateriaux.lambert_du_corps(g_lampe, 0.6, Vector3(0, 0, 1))
	var face_nord := IsoMateriaux.lambert_du_corps(g_lampe, 0.6, Vector3(0, 0, -1))
	var face_est := IsoMateriaux.lambert_du_corps(g_lampe, 0.6, Vector3(1, 0, 0))
	var dessus := IsoMateriaux.lambert_du_corps(g_lampe, 0.6, Vector3(0, 1, 0))
	_check("corps : la face vers la lampe garde sa lumière (%.2f), le dos descend au plancher (%.2f)" % [face_sud, face_nord],
		face_sud > 0.95 and absf(face_nord - IsoMateriaux.LAMBERT_PLANCHER) < 1e-4)
	_check("corps : la face de profil est entre les deux (%.2f), le dessus monte à 1,15 (%.2f)" % [face_est, dessus],
		face_est >= IsoMateriaux.LAMBERT_PLANCHER - 1e-4 and face_est < face_sud and is_equal_approx(dessus, 1.15))
	# Le modelé RÉPARTIT (retour de la session cloud, 12:30) : la face que le joueur lit n'est jamais la plus sombre.
	var lampe_ouest := Vector2(-0.2, 0.0)
	var visibles := [Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]
	var somme := 0.0
	for nv: Vector3 in visibles:
		somme += IsoMateriaux.lambert_du_corps(lampe_ouest, 0.6, nv)
	_check("corps : la moyenne des faces visibles reste la lumière du capteur (%.2f ≈ 1)" % (somme / visibles.size()),
		absf(somme / visibles.size() - 1.0) < 0.1)
	var sud_de_cote := IsoMateriaux.lambert_du_corps(lampe_ouest, 0.6, Vector3(0, 0, 1))
	var sud_devant := IsoMateriaux.lambert_du_corps(Vector2(0.0, 0.2), 0.6, Vector3(0, 0, 1))
	_check("corps : la face sud ne passe jamais sous 0,7 lampe de côté (%.2f) ou devant (%.2f)" % [sud_de_cote, sud_devant],
		sud_de_cote >= 0.7 and sud_devant >= 0.7)
	# Décidé à 12:50 : lampe de côté, la face sud tombe à 0,9 et le dessus monte à 1,15 — le volume se lit à la caméra.
	_check("corps : lampe de côté, dessus plus clair que la face sud (%.2f > %.2f)" % [IsoMateriaux.lambert_du_corps(lampe_ouest, 0.6, Vector3(0, 1, 0)), sud_de_cote],
		is_equal_approx(sud_de_cote, 0.9) and IsoMateriaux.lambert_du_corps(lampe_ouest, 0.6, Vector3(0, 1, 0)) > sud_de_cote + 0.2)
	_check("corps : lumière uniforme, aucun modelé (dessus compris)", is_equal_approx(IsoMateriaux.lambert_du_corps(Vector2.ZERO, 0.6, Vector3(0, 1, 0)), 1.0)
		or is_equal_approx(IsoMateriaux.lambert_du_corps(Vector2(0.001, 0.0), 0.6, Vector3(0, 1, 0)), 1.0))
	var code_corps := (load("res://corps_iso.gdshader") as Shader).code
	_check("corps : le modelé est re-plafonné à la fiche", code_corps.contains("normale_monde, lambert_plancher)), couleur_fiche.rgb);"))
	_check("corps : le modelé passe par pate_facteur, avant l'encre et jamais sur la silhouette",
		code_corps.find("lambert_du_corps(vec2(") > 0 and code_corps.find("lambert_du_corps(vec2(") < code_corps.find("pate_encre_boite(local")
		and code_corps.find("lambert_du_corps(vec2(") < code_corps.find("silhouette.rgb * s"))
	var corps_mat := ShaderMaterial.new()
	corps_mat.shader = load("res://corps_iso.gdshader")
	IsoMateriaux.accorder_corps(corps_mat)
	_check("corps : accorder_corps pose le modelé", is_equal_approx(float(corps_mat.get_shader_parameter("lambert_plancher")), IsoMateriaux.LAMBERT_PLANCHER))
	_check("ISO7b posé : Lambert, contact, dalles, température graduée",
		is_equal_approx(float(mur.get_shader_parameter("lambert_plancher")), IsoMateriaux.LAMBERT_PLANCHER)
		and float(mur.get_shader_parameter("contact_px")) > 0.0 and float(sol.get_shader_parameter("dalles")) == 1.0
		and float(sol.get_shader_parameter("temperature_seuil_haut")) > 0.0)


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
	# ISO7b — le masque de dérive : un pixel que le JEU a changé entre les deux « avant » ne compte ni comme éteint
	# ni comme allumé (torche qui bascule, fusée qui grandit : 7 221 faux éteints au banc du 2026-09-15).
	var avant_bis := avant.duplicate() as Image
	avant_bis.set_pixel(3, 3, Color(0, 0, 0))
	var derive: Image = banc.masque_de_derive(avant, avant_bis)
	_check("banc : le masque de dérive voit le pixel qui a bougé entre les deux avant",
		derive.get_pixel(3, 3).r > 0.5 and derive.get_pixel(4, 4).r < 0.5)
	var m_derive: Dictionary = banc.mesurer(avant, eteignant, derive)
	_check("banc : un pixel en dérive n'est pas compté éteint (%d éteint, %d en dérive)" % [m_derive["eteints"], m_derive["derive"]],
		m_derive["eteints"] == 0 and m_derive["derive"] == 1)
	var neutres_iso7b: Dictionary = banc.NEUTRES_ISO7B
	for p in ["lambert_plancher", "contact_px", "dalles", "temperature_seuil_haut"]:
		_check("banc : l'avant ISO7 neutralise %s" % p, neutres_iso7b.has(p))
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
			var precedent_recu := -1.0
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
				# ⚠️ **La monotonie se juge À L'ÉCRAN, et relativement à la lumière reçue.** L'encre raisonne en
				# luminance affichée ; la pâte D change la teinte d'un niveau à l'autre, et une luminance
				# prise dans l'espace du shader peut alors reculer d'un cheveu sans que l'écran recule (9 reculs
				# lus ainsi le 2026-09-15). La règle : si la lumière reçue monte à l'écran, la face ne descend pas.
				var recu_affiche := IsoPate.luminance(IsoPate.vers_affiche(pateuse))
				var face_affiche := IsoPate.luminance(IsoPate.vers_affiche(face))
				if recu_affiche + 1e-6 >= precedent_recu and face_affiche + 1e-6 < precedent:
					non_monotones += 1
				precedent = face_affiche
				precedent_recu = recu_affiche
				if IsoPate.luminance(pateuse) > 0.0:
					if lf <= 0.0:
						eteints += 1
					bas = minf(bas, IsoPate.luminance(IsoPate.vers_affiche(face)) / IsoPate.luminance(IsoPate.vers_affiche(pateuse)))
	_check("à lumière 0, mur, sommet et muret sont noirs (%d cas)" % n, zeros_faux == 0, "%d non nuls" % zeros_faux)
	_check("la face est monotone en la lumière", non_monotones == 0, "%d reculs" % non_monotones)
	_check("un point éclairé reste éclairé sous matière et encre", eteints == 0, "%d éteints" % eteints)
	# ⚠️ Pas seulement > 0 : au banc, un facteur de 0,05 (encre × matière) éteignait au noir les pixels
	# éclairés de 25 à 40/255. Le plancher combiné doit laisser un pixel à 25 au-dessus de 2.
	_check("le facteur le plus bas sous matière et encre reste ≥ 0,2 (%.3f)" % bas, bas >= 0.2 - 1e-4)
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
		# La température (étape 6) réécrit `c` à partir de `c` lui-même, luminance gardée : pas une source.
		# ISO7b — `lightmap_pateuse_moyenne(` (la lecture au pied moyennée le long du mur) est une lecture de lightmap.
		if not (a.contains("lightmap_pateuse(") or a.contains("lightmap_pateuse_moyenne(") or a.contains("vec3(0.0)") or a == "c = pate_temperature(c, temperature);"
				or a.begins_with("c = pate_facteur(c, ") or a.begins_with("c = pate_matiere_et_encre(c, ")
				or a == "c = temperature_seuil_haut > 0.0"):
			sources_propres = false
			printerr("    affectation hors lightmap : ", a)
	_check("toute couleur de mur naît d'une lecture de lightmap ou du noir", sources_propres)
	var multiplications := 0
	for brute in lignes:
		var ligne := brute.strip_edges()
		if ligne.begins_with("c += ") or ligne.begins_with("c -= "):
			sources_propres = false
		if ligne.begins_with("c *= "):
			sources_propres = false
		if ligne.contains("pate_facteur(") or ligne.contains("pate_matiere_et_encre("):
			multiplications += 1
	_check("aucun terme additif sur la couleur (c += / c -=)", sources_propres)
	_check("matière, encre et liseré passent par pate_facteur, jamais par c *= (%d)" % multiplications, multiplications >= 3 and sources_propres)
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
