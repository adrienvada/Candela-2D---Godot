## Q39, deuxième tour — L'ESSAI B, « FONDU » (`--corps-soi-sombre=fondu`, avis de jeu de Beauté ; session cloud
## corps-sombre-2, 2026-09-28) : le corps de soi sombre à liseré (l'essai A) SEULEMENT là où le corps d'aujourd'hui se fond
## dans le sol autour de lui ; ailleurs, le corps d'aujourd'hui.
##
## Ce que la suite prouve, sans fenêtre :
## - **le drapeau, éteint par défaut, ne change rien** : ni `--corps-soi-sombre` ni `=fondu` sur la ligne de la suite ;
##   sans lui, `accorder_corps` ne pose pas CORPS_SOI_FONDU ; B n'existe jamais sans A (il se compose sur lui) ; tout le
##   code de B est sous `#ifdef CORPS_SOI_FONDU`, dans l'include ET dans `corps_iso.gdshader` ;
## - **seule la vue de soi change** : le code de B est DANS le bloc `if (s > 0.0)` de l'essai A ; il n'ajoute aucun
##   `varying` (piège 1 du premier tour : deux varyings de plus changeaient le corps dans la vue d'en face) ;
## - **ce qu'il lit, et l'équité** : le sol autour du joueur dans la lightmap de LA VUE QUI DESSINE (`deux`), sur un cercle
##   de huit points régulièrement espacés posé dans le monde 2D autour de `centre` (invariant par le lacet de la caméra) ;
##   rien de l'autre joueur, du réseau ni de l'état du jeu ;
## - **la règle**, sur un miroir de `soi_fondu_poids` (seuils relus dans le texte) : poids 1 quand le corps d'aujourd'hui
##   vaut le sol, 0 au-delà du seuil haut, décroissant entre les deux ; le mélange n'est jamais plus clair que la plus claire
##   des deux couleurs (aujourd'hui, essai A) — noir absolu et règle des pochoirs tenus ;
## - `Protocol.VERSION` reste 19 ; aucun fichier de simulation ne connaît le drapeau.
##
## Ce qu'elle ne prouve pas : l'image. `docs/iso/cloud/corps-sombre-2/` la mesure, vue de l'adversaire comprise.
##
## Lancer : godot --headless --path . --script res://tools/test_corps_soi_fondu.gd
extends SceneTree

const PLANCHER := 24
const INC := "res://iso_corps_soi_sombre.gdshaderinc"
const SHADER := "res://corps_iso.gdshader"

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
	print("=== Q39 (2) — L'ESSAI B, « FONDU » ===")
	await process_frame
	_le_drapeau()
	_le_texte()
	_la_regle()
	_le_relais()
	_le_reste_du_jeu()
	VoxelCatalogue.forcer_soi_sombre = -1
	VoxelCatalogue.forcer_soi_fondu = -1
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	print("%d vérifications, %d échec(s)" % [_verifications, _echecs])
	quit(1 if _echecs > 0 else 0)


func _noms(sh: Shader) -> Array:
	var noms := []
	for u in sh.get_shader_uniform_list():
		noms.append(String(u["name"]))
	return noms


func _accorde(soi: int, fondu: int) -> Shader:
	VoxelCatalogue.forcer_soi_sombre = soi
	VoxelCatalogue.forcer_soi_fondu = fondu
	var m := ShaderMaterial.new()
	m.shader = load(SHADER)
	IsoMateriaux.accorder_corps(m)
	return m.shader


func _le_drapeau() -> void:
	print("— le drapeau : éteint par défaut, jamais sans l'essai A")
	VoxelCatalogue.forcer_soi_sombre = -1
	VoxelCatalogue.forcer_soi_fondu = -1
	# Depuis la 0.7.0 (Q39 = A), l'essai A est allumé par défaut ; B reste un essai éteint.
	_check("par défaut : l'essai A allumé (Q39, 0.7.0), l'essai B éteint",
		VoxelCatalogue.soi_sombre_actif() and not VoxelCatalogue.soi_fondu_actif())
	_check("le drapeau s'écrit --corps-soi-sombre=fondu", VoxelCatalogue.DRAPEAU_SOI_FONDU == "--corps-soi-sombre=fondu")
	var src := FileAccess.get_file_as_string("res://voxel_catalogue.gd")
	var f := src.substr(src.find("static func soi_fondu_actif()"), 300)
	var a_src := src.substr(src.find("static func soi_sombre_actif()"), 400)
	_check("B se compose sur A : sans A (--sans-corps-soi-sombre), pas de B ; A allumé par défaut",
		f.contains("if not soi_sombre_actif():\n\t\treturn false")
		and a_src.contains("DrapeauxDeLancement.present(DRAPEAU_SANS_SOI_SOMBRE)"))
	var sans := _accorde(0, 0)
	_check("drapeaux éteints : accorder_corps laisse le shader d'origine", sans == load(SHADER))
	var a := _accorde(1, 0)
	_check("essai A seul : CORPS_SOI_SOMBRE, pas CORPS_SOI_FONDU",
		a.code.contains("#define CORPS_SOI_SOMBRE\n") and not a.code.contains("#define CORPS_SOI_FONDU\n"))
	var b := _accorde(1, 1)
	_check("essai B : CORPS_SOI_SOMBRE et CORPS_SOI_FONDU",
		b.code.contains("#define CORPS_SOI_SOMBRE\n") and b.code.contains("#define CORPS_SOI_FONDU\n"))
	var seul := _accorde(0, 1)
	_check("B sans A : rien (soi_fondu_actif est faux, le shader d'origine)", seul == load(SHADER)
		and not VoxelCatalogue.soi_fondu_actif())
	var noms_b := _noms(b)
	_check("la variante B compile et déclare ses réglages (rayon, seuils)",
		noms_b.has("soi_fondu_rayon_px") and noms_b.has("soi_fondu_bas") and noms_b.has("soi_fondu_haut"))
	_check("la variante A seule ne déclare rien de B", not _noms(a).has("soi_fondu_bas"))
	_check("le shader d'origine ne déclare rien de B", not _noms(load(SHADER)).has("soi_fondu_bas"))


func _le_texte() -> void:
	print("— au texte : sous #ifdef, dans la vue de soi, sans varying")
	var inc := FileAccess.get_file_as_string(INC)
	var debut := inc.find("#ifdef CORPS_SOI_FONDU")
	var fin := inc.find("#endif", debut)
	_check("l'include : tout le code de B entre #ifdef CORPS_SOI_FONDU et son #endif", debut > 0 and fin > debut
		and inc.find("soi_fondu") > debut and inc.rfind("soi_fondu") < fin
		and inc.find("soi_sol_autour") > debut and inc.rfind("soi_sol_autour") < fin)
	_check("l'include : B est lui-même DANS le bloc CORPS_SOI_SOMBRE", inc.find("#ifdef CORPS_SOI_SOMBRE") < debut
		and inc.substr(fin).begins_with("#endif\n#endif"))
	var code := FileAccess.get_file_as_string(SHADER)
	var bloc_a := code.find("\tif (s > 0.0) {", code.find("#ifdef CORPS_SOI_SOMBRE\n\t// Q39"))
	var bloc_b := code.find("#ifdef CORPS_SOI_FONDU")
	var fin_b := code.find("#endif", bloc_b)
	var fin_a := code.find("\t\tALBEDO = soi;", bloc_a)
	_check("corps_iso : le code de B est sous #ifdef CORPS_SOI_FONDU, DANS le bloc `if (s > 0.0)` de l'essai A",
		bloc_a > 0 and bloc_b > bloc_a and fin_b > bloc_b and fin_a > fin_b
		and code.find("soi_fondu_poids") > bloc_b and code.rfind("soi_fondu_poids") < fin_b)
	var avant := FileAccess.get_file_as_string(SHADER).count("\nvarying ")
	_check("corps_iso : six varyings, pas un de plus (piège 1 du premier tour : la vue d'en face bougeait)", avant == 6,
		"%d" % avant)
	_check("B ne lit pas le temps", not inc.substr(debut, fin - debut).contains("TIME")
		and not code.substr(bloc_b, fin_b - bloc_b).contains("TIME"))
	var appel := code.substr(bloc_b, fin_b - bloc_b)
	_check("B lit le sol dans la lightmap de LA VUE QUI DESSINE, autour du joueur : soi_sol_autour(centre, deux)",
		appel.contains("soi_sol_autour(centre, deux)"))
	_check("B lit le corps d'aujourd'hui par le capteur de cette même vue (deux), jamais par l'autre silhouette",
		appel.contains("lumiere_du_capteur(deux,") and not appel.contains("silhouette_1") and not appel.contains("silhouette_2")
		and not appel.contains("opacite_1") and not appel.contains("opacite_2"))
	var cercle := inc.substr(inc.find("float soi_sol_autour("), 400)
	_check("le cercle : huit points régulièrement espacés (pas de 2π/8), autour de centre_px, au rayon réglé",
		cercle.contains("for (int i = 0; i < 8; i++)") and cercle.contains("float(i) * 0.785398")
		and cercle.contains("centre_px + vec2(cos(t), sin(t)) * soi_fondu_rayon_px") and cercle.contains("* 0.125"))


## Les seuils, relus dans le texte de l'include.
func _defaut(nom: String) -> float:
	var inc := FileAccess.get_file_as_string(INC)
	var i := inc.find("uniform float %s = " % nom)
	var ligne := inc.substr(i, inc.find(";", i) - i)
	return float(ligne.split("= ")[1])


func _luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## Miroir de `soi_fondu_poids`.
func _poids(hier: Color, sol: float) -> float:
	var l := _luminance(hier)
	var contraste := absf(l - sol) / maxf(maxf(l, sol), 0.0001)
	return 1.0 - smoothstep(_defaut("soi_fondu_bas"), _defaut("soi_fondu_haut"), contraste)


func _la_regle() -> void:
	print("— la règle, sur un miroir")
	var bas := _defaut("soi_fondu_bas")
	var haut := _defaut("soi_fondu_haut")
	_check("les seuils se lisent (bas %.2f < haut %.2f < 1)" % [bas, haut], bas > 0.0 and bas < haut and haut < 1.0)
	var corps := Color(0.4, 0.45, 0.5)
	var l := _luminance(corps)
	_check("le corps d'aujourd'hui vaut le sol : poids 1 (l'essai A en entier)", is_equal_approx(_poids(corps, l), 1.0))
	_check("le sol noir autour d'un corps visible (sa torche, le noir) : poids 0 (le corps d'aujourd'hui)",
		is_equal_approx(_poids(corps, 0.0), 0.0))
	_check("le sol bien plus clair que le corps : poids 0", is_equal_approx(_poids(corps, l / (1.0 - haut) + 0.05), 0.0))
	var precedent := 2.0
	var decroissant := true
	for i in 21:
		var sol := l * (1.0 - float(i) / 20.0)
		var p := _poids(corps, sol)
		if p > precedent + 1e-6:
			decroissant = false
		precedent = p
	_check("le poids décroît quand le contraste croît (sol de la clarté du corps jusqu'au noir)", decroissant)
	_check("un corps noir sur un sol noir : poids 1, sans division par zéro", is_equal_approx(_poids(Color.BLACK, 0.0), 1.0))
	var jamais_plus_clair := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 39
	for i in 500:
		var hier := Color(rng.randf(), rng.randf(), rng.randf())
		var a := Color(rng.randf(), rng.randf(), rng.randf())
		var w := _poids(hier, rng.randf())
		var r := hier.lerp(a, w)
		for k in 3:
			if r[k] > maxf(hier[k], a[k]) + 1e-6 or r[k] < minf(hier[k], a[k]) - 1e-6:
				jamais_plus_clair = false
	_check("500 tirages : le mélange reste entre le corps d'aujourd'hui et l'essai A, canal par canal", jamais_plus_clair)


func _le_relais() -> void:
	print("— la lightmap relayée à tout corps reconstruit")
	var pres := FileAccess.get_file_as_string("res://presentation_3d.gd")
	var f := pres.substr(pres.find("func _accorder_le_slug("), 4000)
	f = f.substr(0, f.find("\n\n\n"))
	_check("Presentation3D._accorder_le_slug pose lumiere_1 et lumiere_2 sur le matériau neuf (sinon B ne lit que du vide "
		+ "après un changement de classe)", f.contains("mat.set_shader_parameter(\"lumiere_1\", _main.vp1.get_texture())")
		and f.contains("mat.set_shader_parameter(\"lumiere_2\", _main.vp2.get_texture())"))


func _le_reste_du_jeu() -> void:
	print("— le reste du jeu n'en sait rien")
	_check("Protocol.VERSION reste 19", Protocol.VERSION == 19)
	for chemin in ["res://player.gd", "res://game_state.gd", "res://network_manager.gd", "res://protocol.gd"]:
		if FileAccess.file_exists(chemin):
			var t := FileAccess.get_file_as_string(chemin)
			_check("%s ne connaît pas l'essai B" % chemin.get_file(), not t.contains("SOI_FONDU") and not t.contains("soi_fondu"))
