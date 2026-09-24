## ISO13, lot C — l'usure en essai : murs abîmés, sol jonché (chantier d'ISO7 Beauté, 2026-09-24).
##
## Ce que la suite prouve, sans fenêtre :
## - **le drapeau** : `--usure-essai` éteint par défaut ; les matériaux de murs et de sols gardent alors leurs shaders
##   d'origine, qui ne déclarent pas un uniforme de l'usure (rien de plus à exécuter) ;
## - **les variantes** : `IsoMateriaux.variante_definie` compile les quatre shaders avec USURE_ESSAI, une fois par shader,
##   se cumule avec l'encre d'essai, et seul le sol y gagne la grille des murs (pour masser ses gravats au pied des murs) ;
## - **les impacts** : les plus récents seulement, au format du shader, à une hauteur tirée de la position (la même sur
##   chaque machine), dans la bande du torse ;
## - **les garanties écrites dans le shader** : un facteur posé par `pate_facteur` (0 reste 0 : rien dans le noir), borné
##   par USURE_RESTE, effacé sous les seuils d'« allumé reste allumé » ; aucune face nommée — tout se lit dans le repère de
##   la face (normale, tangente), prêt pour le lacet de 45° ; un impact ne marque que la face DEVANT laquelle il est posé.
##
## Ce qu'elle ne prouve pas : l'image. La planche d'usure (`--usure-essai`, banc des lumières) la mesure en vraie fenêtre.
##
## Lancer : godot --headless --path . --script res://tools/test_iso_usure.gd
extends SceneTree

const PLANCHER := 24
const MURS := ["res://mur_iso.gdshader", "res://mur_iso_eclaire.gdshader"]
const SOLS := ["res://sol_iso.gdshader", "res://sol_iso_eclaire.gdshader"]

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
	print("=== ISO13 — L'USURE EN ESSAI ===")
	await process_frame
	_le_drapeau()
	_les_variantes()
	_les_impacts()
	_le_shader()
	_la_presentation()
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	print("%d vérifications, %d échec(s)" % [_verifications, _echecs])
	quit(1 if _echecs > 0 else 0)


func _noms(sh: Shader) -> Array:
	var noms := []
	for u in sh.get_shader_uniform_list():
		noms.append(String(u["name"]))
	return noms


func _le_drapeau() -> void:
	print("— le drapeau : éteint par défaut, les shaders d'origine")
	_check("--usure-essai n'est pas sur la ligne de commande de la suite", not IsoMateriaux.usure_essai_active())
	var mur := ShaderMaterial.new()
	mur.shader = load(MURS[0])
	IsoMateriaux.accorder_mur(mur)
	_check("drapeau éteint : le mur garde son shader d'origine", mur.shader == load(MURS[0]))
	var sol := ShaderMaterial.new()
	sol.shader = load(SOLS[0])
	IsoMateriaux.accorder_sol(sol)
	_check("drapeau éteint : le sol garde son shader d'origine", sol.shader == load(SOLS[0]))
	for chemin in MURS + SOLS:
		var noms := _noms(load(chemin))
		_check("%s d'origine : aucun uniforme de l'usure" % chemin.get_file(),
			not noms.has("usure") and not noms.has("usure_impacts"))


func _les_variantes() -> void:
	print("— les variantes USURE_ESSAI")
	for chemin in MURS + SOLS:
		var sh := load(chemin) as Shader
		var v := IsoMateriaux.variante_definie(sh, "USURE_ESSAI")
		var noms := _noms(v)
		var sol := SOLS.has(chemin)
		_check("%s : la variante compile et déclare l'usure et ses impacts" % chemin.get_file(),
			noms.has("usure") and noms.has("usure_impacts") and noms.has("usure_impacts_n"))
		_check("%s : une variante par shader, et la variante d'une variante est elle-même" % chemin.get_file(),
			IsoMateriaux.variante_definie(sh, "USURE_ESSAI") == v and IsoMateriaux.variante_definie(v, "USURE_ESSAI") == v)
		if sol:
			_check("%s : le sol gagne la grille des murs sous le drapeau, pas avant" % chemin.get_file(),
				noms.has("grille_murs") and not _noms(sh).has("grille_murs"))
	var sol := load(SOLS[0]) as Shader
	var deux := IsoMateriaux.variante_definie(IsoMateriaux.variante_encre(sol), "USURE_ESSAI")
	var noms := _noms(deux)
	_check("l'encre et l'usure se cumulent : la variante porte les hachures ET l'usure",
		noms.has("pate_hachures") and noms.has("usure") and deux.code.contains("#define ENCRE_ESSAI\n")
		and deux.code.contains("#define USURE_ESSAI\n"))
	var m := ShaderMaterial.new()
	m.shader = sol
	IsoMateriaux.poser_usure_essai(m, true)
	var allume := m.shader
	IsoMateriaux.poser_usure_essai(m, false)
	_check("poser puis retirer : la variante reste, l'usure tombe à 0 (bascule du banc dans la même partie)",
		allume != sol and m.shader == allume and float(m.get_shader_parameter("usure")) == 0.0)


func _les_impacts() -> void:
	print("— les impacts : les plus récents, à hauteur de torse, la même partout")
	var points := PackedVector2Array()
	for i in 60:
		points.append(Vector2(100.0 + 7.0 * i, 40.0 + 3.0 * i))
	var impacts := IsoMateriaux.impacts_usure(points)
	_check("au plus USURE_IMPACTS_MAX (%d)" % IsoMateriaux.USURE_IMPACTS_MAX, impacts.size() == IsoMateriaux.USURE_IMPACTS_MAX)
	_check("les plus récents : le premier gardé est le 13e, le dernier est le dernier",
		Vector2(impacts[0].x, impacts[0].y) == points[12] and Vector2(impacts[-1].x, impacts[-1].y) == points[59])
	var tuile := float(CandelaTileSet.TILE_SIZE.x)
	var bas := (IsoMateriaux.USURE_IMPACT_HAUTEUR_TUILES - IsoMateriaux.USURE_IMPACT_ECART_TUILES) * tuile
	var haut := (IsoMateriaux.USURE_IMPACT_HAUTEUR_TUILES + IsoMateriaux.USURE_IMPACT_ECART_TUILES) * tuile
	var dans := true
	var distinctes := {}
	for v in impacts:
		# `Vector4` garde des flottants 32 bits : 2,2 n'y revient pas égal au 2,2 du script, d'où `is_equal_approx`.
		dans = dans and v.z >= bas - 0.001 and v.z <= haut + 0.001 and is_equal_approx(v.w, IsoMateriaux.USURE_IMPACT_RAYON_PX)
		distinctes[snappedf(v.z, 0.01)] = true
	_check("toutes dans la bande du torse (%.1f à %.1f px), au rayon de l'impact" % [bas, haut], dans)
	_check("des hauteurs qui varient d'un impact à l'autre (%d distinctes)" % distinctes.size(), distinctes.size() > 20)
	_check("la même hauteur au même point, à chaque appel (aucun randf)",
		IsoMateriaux.hauteur_impact(Vector2(321.5, 87.25)) == IsoMateriaux.hauteur_impact(Vector2(321.5, 87.25)))
	_check("aucun impact, aucun point", IsoMateriaux.impacts_usure(PackedVector2Array()).is_empty())


func _le_shader() -> void:
	print("— les garanties écrites dans le shader")
	var inc := FileAccess.get_file_as_string("res://iso_usure.gdshaderinc")
	_check("tout sous #ifdef USURE_ESSAI", inc.find("#ifdef USURE_ESSAI") < inc.find("uniform float usure")
		and inc.strip_edges().ends_with("#endif"))
	_check("un facteur posé sur la valeur affichée, effacé sous les seuils d'« allumé reste allumé »",
		inc.contains("float w = smoothstep(USURE_SEUILS.x, USURE_SEUILS.y, pate_luminance(c));")
		and inc.contains("return mix(1.0, f, w);"))
	_check("les deux facteurs bornés par USURE_RESTE, 1 quand l'usure est éteinte",
		inc.count("return mix(1.0, max(f, USURE_RESTE), usure);") == 2 and inc.count("if (usure <= 0.0) {\n\t\treturn 1.0;") == 2)
	_check("aucune face nommée : ni « sud » ni axe du monde dans la face, tout dans le repère de la face",
		not inc.contains("vec2(0.0, 1.0)") and not inc.contains("vec2(0.0, -1.0)") and inc.contains("float u = dot(xz, tangente);"))
	_check("un impact ne marque que la face devant laquelle il est posé",
		inc.contains("float devant = dot(dp, n);\n\t\tif (devant < -1.5 || devant > 9.0) {\n\t\t\tcontinue;"))
	for chemin in MURS:
		var code := FileAccess.get_file_as_string(chemin)
		var encre := code.find("encre_plancher_affiche);\n#ifdef USURE_ESSAI\n\t\tc = pate_facteur(c, usure_poids(c, usure_face(")
		_check("%s : l'usure après la matière et l'encre de la face verticale, sous le drapeau" % chemin.get_file(), encre > 0)
	for chemin in SOLS:
		var code := FileAccess.get_file_as_string(chemin)
		_check("%s : les gravats avant l'ombre de contact des corps, sous le drapeau" % chemin.get_file(),
			code.contains("#ifdef USURE_ESSAI\n\tc = pate_facteur(c, usure_poids(c, usure_sol(px, usure_mur_pres(px), px_monde)));\n#endif\n\tc = pate_facteur(c, contact_des_corps(px));")
			and code.contains("#define USURE_SOL\n#include \"res://iso_usure.gdshaderinc\""))


func _la_presentation() -> void:
	print("— la présentation : les impacts du jeu, seulement quand ils changent")
	var pres := FileAccess.get_file_as_string("res://presentation_3d.gd")
	_check("drapeau lu une fois, suivi des impacts seulement sous lui",
		pres.contains("var _usure := IsoMateriaux.usure_essai_active()") and pres.contains("\t\tif _usure:\n\t\t\t_suivre_usure()"))
	_check("reposés seulement quand un éclat arrive ou part",
		pres.contains("if empreinte == _usure_empreinte:\n\t\treturn"))
	_check("les originaux seulement, pas leurs copies J2",
		pres.contains("not (e as Node).is_in_group(\"wall_impact_p2\")"))
