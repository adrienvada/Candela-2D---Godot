## Q40 — la lampe claire, à l'essai (`--lampe-claire`, session cloud « lampe-claire », 2026-09-28).
##
## Ce que la suite prouve, sans fenêtre :
## - **éteinte par défaut, et éteinte veut dire « au bit »** : sans le drapeau, la force posée vaut 0 ; le shader teste la
##   force EN TÊTE et rend alors `c` tel quel, avant tout calcul ;
## - **à la sortie, et seulement là** : les quatre matériaux du sol et des murs l'appellent juste avant `ALBEDO`, et
##   personne d'autre — aucun capteur, aucun corps, aucun script de jeu ne la connaît. C'est ce qui la tient à l'écart de
##   ce que le jeu LIT de la lumière (capteurs, seuil de Q32, éblouissement, lightmap) ;
## - **la courbe** (sa copie GDScript, recopiée ligne pour ligne) : l'identité sous le genou, 0 → 0, monotone, jamais plus
##   sombre, une lumière colorée intacte (fusée, LED ambre, carmin) ;
## - **le noir** : le genou est au-dessus du point noir écrit du masque de la fumée (8/255, × sa hausse maximale 1,4) :
##   « noir ou pas » ne change pour aucun pixel ;
## - `Protocol.VERSION` reste 18.
##
## Ce qu'elle ne prouve pas : l'image. `tools/photo_lampe.gd` la prend, au même instant, avec et sans l'essai.
##
## Lancer : godot --headless --path . --script res://tools/test_lampe_claire.gd
extends SceneTree

const LampeClaire := preload("res://lampe_claire.gd")
const TestBanc := preload("res://tools/test_banc.gd")

const SHADERS := ["sol_iso", "sol_iso_eclaire", "mur_iso", "mur_iso_eclaire"]

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
	print("=== Q40 — LA LAMPE CLAIRE, À L'ESSAI ===")
	await process_frame

	# --- Éteinte par défaut.
	_check("le drapeau n'est pas posé : la lampe claire n'est pas demandée", not LampeClaire.demandee())
	var mat := ShaderMaterial.new()
	mat.shader = load("res://sol_iso.gdshader")
	LampeClaire.accorder(mat, false)
	_check("éteinte, seule la force est posée, et elle vaut 0",
		float(mat.get_shader_parameter("lampe_claire")) == 0.0 and mat.get_shader_parameter("lampe_claire_paleur") == null)
	LampeClaire.accorder(mat, true)
	_check("allumée, la force vaut 1 et les réglages sont posés",
		float(mat.get_shader_parameter("lampe_claire")) == 1.0
		and is_equal_approx(float(mat.get_shader_parameter("lampe_claire_paleur")), LampeClaire.PALEUR))

	var inc := FileAccess.get_file_as_string("res://lampe_claire.gdshaderinc")
	_check("le shader : force 0 par défaut", inc.contains("uniform float lampe_claire : hint_range(0.0, 1.0) = 0.0;"))
	var sur := TestBanc._fonction_de_shader(inc, "vec3 lampe_claire_sur(vec3 c, vec3 brute)")
	var tete := sur.find("if (lampe_claire <= 0.0) {\n\t\treturn c;\n\t}")
	_check("le shader : la force testée EN TÊTE, `c` rendu tel quel avant tout calcul",
		tete >= 0 and tete < sur.find("pate_luminance"), "test absent ou placé après la première mesure")
	var genou := sur.find("if (w <= 0.0 || x <= 0.0) {\n\t\treturn c;\n\t}")
	_check("le shader : sous le genou (poids nul), `c` rendu tel quel",
		genou >= 0 and genou < sur.find("float h = "))
	var sol := TestBanc._fonction_de_shader(inc, "vec3 lampe_claire_au_sol(vec3 c, vec2 px, bool deux)")
	_check("le sol : éteinte, aucune lecture de la lightmap de plus",
		sol.find("if (lampe_claire <= 0.0) {\n\t\treturn c;\n\t}") >= 0
		and sol.find("if (lampe_claire <= 0.0)") < sol.find("lire_lightmap"))

	# --- La courbe, copie GDScript = shader (les mêmes expressions).
	for morceau in ["lampe_claire * smoothstep(lampe_claire_genou.x, lampe_claire_genou.y, x)",
			"float h = max(x, lampe_claire_plafond * (1.0 - pow(1.0 - clamp(x, 0.0, 1.0), lampe_claire_gamma)));",
			"float y = x + w * (h - x);",
			"return smoothstep(lampe_claire_neutre.x, lampe_claire_neutre.y, 1.0 - (mx - mn) / mx);"]:
		_check("la copie GDScript suit le shader : « %s »" % morceau.left(60), inc.contains(morceau))
	_check("les valeurs par défaut du shader sont celles de l'essai",
		inc.contains("uniform vec2 lampe_claire_genou = vec2(%.2f, %.2f);" % [LampeClaire.GENOU.x, LampeClaire.GENOU.y])
		and inc.contains("uniform float lampe_claire_gamma = %.1f;" % LampeClaire.GAMMA)
		and inc.contains("lampe_claire_plafond : hint_range(0.0, 1.0) = %.2f;" % LampeClaire.PLAFOND)
		and inc.contains("lampe_claire_paleur : hint_range(0.0, 1.0) = %.1f;" % LampeClaire.PALEUR)
		and inc.contains("uniform vec2 lampe_claire_neutre = vec2(%.2f, %.2f);" % [LampeClaire.NEUTRE.x, LampeClaire.NEUTRE.y]))

	var identite_sous_genou := true
	var monotone := true
	var jamais_plus_sombre := true
	var eteinte_identite := true
	for k in 11:
		var n := k / 10.0
		var avant := -1.0
		for i in 1001:
			var x := i / 1000.0
			var y := LampeClaire.luminance_ecrite(x, n)
			if x <= LampeClaire.GENOU.x and y != x:
				identite_sous_genou = false
			if y < avant - 1e-9:
				monotone = false
			if y < x - 1e-9:
				jamais_plus_sombre = false
			if LampeClaire.luminance_ecrite(x, n, 0.0) != x:
				eteinte_identite = false
			avant = y
	_check("la courbe : l'identité sous le genou (%.2f), à toute neutralité" % LampeClaire.GENOU.x, identite_sous_genou)
	_check("la courbe : monotone", monotone)
	_check("la courbe : jamais plus sombre", jamais_plus_sombre)
	_check("la courbe : force 0 ⇒ l'identité", eteinte_identite)
	_check("la courbe : 0 → 0", LampeClaire.luminance_ecrite(0.0, 1.0) == 0.0)
	_check("la courbe : le cœur du cône relevé (126/255 → %.0f/255)" % (255.0 * LampeClaire.luminance_ecrite(126.0 / 255.0, 1.0)),
		LampeClaire.luminance_ecrite(126.0 / 255.0, 1.0) > 200.0 / 255.0)
	# Les lumières colorées : neutralité de la fusée (lightmap 126, 36, 27), de la LED ambre (0,96 ; 0,69 ; 0,24), du carmin.
	var colorees := {"fusée": Vector3(126, 36, 27) / 255.0, "LED ambre": Vector3(0.96, 0.69, 0.24),
		"détresse": Vector3(0.96, 0.293, 0.334)}
	for nom in colorees:
		var c: Vector3 = colorees[nom]
		var mx := maxf(c.x, maxf(c.y, c.z))
		var mn := minf(c.x, minf(c.y, c.z))
		var n := 1.0 - (mx - mn) / mx
		var intacte := true
		for i in 101:
			var x := i / 100.0
			if LampeClaire.luminance_ecrite(x, n) != x:
				intacte = false
		_check("une lumière colorée reste intacte : %s (neutralité %.2f)" % [nom, n], intacte)
	# La torche (l'halogène), elle, est pleinement relevée.
	var hal := LampeClaire.CREME
	var n_hal := 1.0 - (hal.r - hal.b) / hal.r
	_check("l'halogène de la torche est pleinement dans l'essai (neutralité %.2f)" % n_hal,
		smoothstep(LampeClaire.NEUTRE.x, LampeClaire.NEUTRE.y, n_hal) >= 1.0)

	# --- Le noir : le point noir écrit du masque de la fumée, × sa hausse maximale, est sous le genou (même espace, écrit).
	var noir_ecrit := 8.0 / 255.0 * 1.4
	_check("le noir : le point noir écrit (8/255 × 1,4 = %.4f) est sous le genou (%.2f)" % [noir_ecrit, LampeClaire.GENOU.x],
		noir_ecrit < LampeClaire.GENOU.x)

	# --- À la sortie des quatre matériaux, et nulle part ailleurs.
	for nom in SHADERS:
		var texte := FileAccess.get_file_as_string("res://%s.gdshader" % nom)
		var appel := "c2d = lampe_claire_au_sol(c2d, px_lu, deux);" if nom == "sol_iso_eclaire" \
			else ("c = lampe_claire_au_sol(c, px_lu, deux);" if nom == "sol_iso" else "c = lampe_claire_sur(c, brute);")
		var i_appel := texte.find(appel)
		var i_albedo := texte.find("ALBEDO = ", i_appel)
		var entre := texte.substr(i_appel + appel.length(), i_albedo - i_appel - appel.length()) if i_appel >= 0 else ""
		# Entre l'appel et l'écriture : au plus la fermeture d'un bloc et le test du masque de preuve (mur éclairé).
		var net := entre.replace("\t", "").replace("\n", "").replace("}", "").replace("if (masque_preuve == 1) {", "")
		_check("%s inclut la lampe claire et l'appelle en dernier, juste avant ALBEDO" % nom,
			texte.contains("#include \"res://lampe_claire.gdshaderinc\"") and i_appel >= 0 and net == "",
			"appel absent, ou suivi d'une autre étape : « %s »" % net)
	var intrus: PackedStringArray = []
	for dossier in ["res://"]:
		for f in DirAccess.get_files_at(dossier):
			if not (f.ends_with(".gd") or f.ends_with(".gdshader") or f.ends_with(".gdshaderinc")):
				continue
			if f in ["lampe_claire.gd", "lampe_claire.gdshaderinc", "presentation_3d.gd"] \
					or f.get_basename() in SHADERS:
				continue
			var t := FileAccess.get_file_as_string(dossier + f)
			if t.contains("lampe_claire") or t.contains("LampeClaire"):
				intrus.append(f)
	_check("personne d'autre ne connaît la lampe claire (capteurs, corps, jeu)", intrus.is_empty(), ", ".join(intrus))
	var pose := FileAccess.get_file_as_string("res://presentation_3d.gd")
	_check("la présentation la lit du drapeau et la repose après chaque accord du sol et des murs",
		pose.contains("var lampe_claire := LampeClaire.demandee()")
		and pose.count("LampeClaire.accorder(_mat_mur, lampe_claire)") == 2
		and pose.count("LampeClaire.accorder(mat, lampe_claire)") == 1
		and pose.count("LampeClaire.accorder(m, lampe_claire)") == 1)
	_check("Protocol.VERSION reste 18",
		FileAccess.get_file_as_string("res://protocol.gd").contains("const VERSION := 18"))

	print("")
	if _echecs == 0:
		print("✓ %d vérifications, toutes passent" % _verifications)
		quit(0)
	else:
		printerr("✗ %d échec(s) sur %d vérifications" % [_echecs, _verifications])
		quit(1)
