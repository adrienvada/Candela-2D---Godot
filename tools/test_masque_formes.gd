## Les formes moins chères du masque de la fumée (session cloud « masque-fumée », 2026-09-27) — la garde headless.
##
## Ce que cette suite prouve, sans fenêtre :
## - **éteintes, rien ne change** : sans drapeau, le masque est éteint et la couche garde le shader des volumes d'avant ;
##   `--fumee-masque` seul pose le masque de Gadgets et AUCUN #define de forme. Et le code que le préprocesseur de Godot
##   garde du shader des volumes, rejoué ici sur le fichier, ne contient rien des formes (ni leur appel, ni le pochoir, ni le
##   juge) dans ces deux cas : le GLSL compilé est celui d'avant (vérifié aussi au texte près dans le GLSL que Mesa capture,
##   `tools/masque_fumee/compter_glsl.py`, et au pixel à l'image, planche de la session) ;
## - chaque drapeau (`IsoVolumes.FORMES_MASQUE`) allume le masque et pose EXACTEMENT les #define de sa forme, que la ligne
##   du journal relit dans le code de la variante (une prise prouve son bras par ce que le jeu dit) ;
## - la forme compacte ne recopie qu'une fois chaque surface (un seul appel au sol, à la face, au dessus) ; la bande
##   resserrée finit le sol exact par les lignes mêmes de `sol_ecrit` ; le juge du pochoir n'existe que sous le pochoir,
##   est dessiné avant les couches, couvre leurs disques tant que le tangage dépasse 45°, et chaque paramètre qu'il reçoit
##   est un uniforme de son shader ; le ruban (la toile) ne passe jamais sous le pochoir ;
## - (session « masque-fumée-2 », 2026-09-28) V4, la lumière d'abord : ses bornes sont celles du lavis (mêmes seuils, même
##   grain, même lavage), placées avant la pâte, et, rejouées sur la pâte du processeur (`IsoPate`, son miroir formule pour
##   formule) en des dizaines de milliers de points, elles ne tranchent JAMAIS autrement que les certitudes de Gadgets ;
##   V5, le juge ajusté : son polygone contient le disque de chaque couche vu depuis lui, et il est plus petit que le carré ;
## - rien sur le fil : `Protocol.VERSION` reste 18.
##
## Ce qu'elle ne prouve pas : que le GPU compile les variantes (le lanceur de série refuse toute prise dont le journal porte
## une erreur de shader) ni la réponse au pixel — `loupe-fusee-masque-formes` et `tools/masque_fumee/formes.py`.
extends SceneTree

const IsoPate := preload("res://iso_pate.gd")

var _verifications := 0
var _failures := 0


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
	print("=== LES FORMES DU MASQUE DE LA FUMÉE ===")
	await process_frame
	_eteintes_rien_ne_change()
	_chaque_drapeau_sa_forme()
	_la_forme_compacte()
	_la_bande_resserree()
	_le_pochoir()
	_la_lumiere_d_abord()
	_le_juge_ajuste()
	var version = (load("res://protocol.gd") as GDScript).get_script_constant_map().get("VERSION")
	_check("Protocol.VERSION reste 18", version == 18, str(version))
	_check("assez de vérifications (%d ≥ 20)" % _verifications, _verifications >= 20)
	print("\n%d vérifications, %d échec(s)" % [_verifications, _failures])
	quit(1 if _failures > 0 else 0)


## Le préprocesseur de Godot, pour ce qui nous regarde : `#ifdef`, `#ifndef`, `#else`, `#endif`, les `#define` du code
## lui-même, sans suivre les `#include`. Rend les lignes gardées pour l'ensemble de noms donné.
func _preprocesser(code: String, definis: Array) -> String:
	var noms := definis.duplicate()
	var pile: Array = []  # [actif_parent, condition]
	var actif := true
	var sortie := PackedStringArray()
	for ligne in code.split("\n"):
		var l := ligne.strip_edges()
		if l.begins_with("#ifdef ") or l.begins_with("#ifndef "):
			var nom := l.split(" ")[1]
			var cond := noms.has(nom) if l.begins_with("#ifdef ") else not noms.has(nom)
			pile.append([actif, cond])
			actif = actif and cond
		elif l == "#else":
			var haut: Array = pile[-1]
			actif = bool(haut[0]) and not bool(haut[1])
		elif l == "#endif":
			actif = bool(pile.pop_back()[0])
		elif actif:
			if l.begins_with("#define "):
				noms.append(l.split(" ")[1])
			sortie.append(ligne)
	return "\n".join(sortie)


func _eteintes_rien_ne_change() -> void:
	print("\n[Éteintes, rien ne change]")
	var v := IsoVolumes.new()
	_check("sans drapeau : masque éteint, forme 0", not v.masque_fumee and v.forme_masque == 0)
	var mat: ShaderMaterial = v.call("_materiau_volume")
	_check("sans drapeau : la couche garde le shader des volumes d'avant", mat.shader == IsoVolumes.SHADER_VOLUME)
	_check("sans drapeau : aucun juge (le pochoir n'existe pas)", v.get_child_count() == 0)
	v.masque_fumee = true
	var gadgets: ShaderMaterial = v.call("_materiau_volume")
	var marques := ["MASQUE_COMPACT", "MASQUE_RESSERRE", "MASQUE_POCHOIR", "MASQUE_POCHOIR_JUGE", "MASQUE_LUMIERE",
		"MASQUE_AJUSTE"]
	_check("--fumee-masque seul : le masque de Gadgets, sans aucun #define de forme",
		gadgets.shader.code.contains("#define FUMEE_MASQUE\n")
		and marques.all(func(d: String) -> bool: return not gadgets.shader.code.contains("#define %s\n" % d)))
	_check("--fumee-masque seul : la forme annoncée est celle de Gadgets",
		IsoVolumes.forme_annoncee(gadgets.shader) == IsoVolumes.NOMS_FORMES[0])
	v.free()
	var src := FileAccess.get_file_as_string("res://volume_iso.gdshader")
	var etrangers := ["masque_compact_montre_noir", "stencil_mode", "juge_couvre", "MASQUE_"]
	for definis: Array in [[], ["FUMEE_MASQUE"], ["FUMEE_MASQUE", "USURE_ESSAI"]]:
		var garde := _preprocesser(src, definis)
		var trouves := etrangers.filter(func(t: String) -> bool: return garde.contains(t))
		_check("le code gardé pour %s ne contient rien des formes" % str(definis), trouves.is_empty(), str(trouves))
	var avec := _preprocesser(src, ["FUMEE_MASQUE"])
	_check("--fumee-masque : l'appel du masque de Gadgets est gardé, une fois, au même endroit (avant la couleur)",
		avec.count("masque_montre_noir(monde, -INV_VIEW_MATRIX[2].xyz, deux,") == 1
		and avec.find("masque_montre_noir(monde") < avec.find("vec3 brute = lire_lightmap(px, deux);"))
	var sans := _preprocesser(src, [])
	_check("éteint : ni masque ni include du masque", not sans.contains("masque_montre_noir")
		and not sans.contains("volume_masque.gdshaderinc"))
	var inc := FileAccess.get_file_as_string("res://volume_masque.gdshaderinc")
	var inc_gadgets := _preprocesser(inc, ["FUMEE_MASQUE", "USURE_ESSAI"])
	_check("le masque de Gadgets n'inclut les formes que sous MASQUE_COMPACT",
		not inc_gadgets.contains("volume_masque_compact.gdshaderinc")
		and _preprocesser(inc, ["MASQUE_COMPACT"]).contains('#include "res://volume_masque_compact.gdshaderinc"'))


func _chaque_drapeau_sa_forme() -> void:
	print("\n[Chaque drapeau, sa forme]")
	var src := FileAccess.get_file_as_string("res://iso_volumes.gd")
	_check("les cinq drapeaux, dans l'ordre des formes", IsoVolumes.FORMES_MASQUE == {"--fumee-masque-compact": 1,
		"--fumee-masque-resserre": 2, "--fumee-masque-pochoir": 3, "--fumee-masque-lumiere": 4, "--fumee-masque-ajuste": 5}
		and IsoVolumes.FORME_POCHOIR == 3 and IsoVolumes.FORME_AJUSTEE == 5)
	_check("un drapeau de forme allume le masque et pose sa forme",
		src.contains("\t\telif FORMES_MASQUE.has(arg):\n\t\t\tmasque_fumee = true\n\t\t\tforme_masque = int(FORMES_MASQUE[arg])"))
	for usure in [false, true]:
		var base: Shader = IsoVolumes.variante_masque(usure)
		for k in range(1, IsoVolumes.DEFINES_FORMES.size()):
			var sh := IsoVolumes.variante_forme(base, k)
			var attendus: Array = IsoVolumes.DEFINES_FORMES[k]
			var tous := ["MASQUE_COMPACT", "MASQUE_RESSERRE", "MASQUE_POCHOIR", "MASQUE_LUMIERE", "MASQUE_AJUSTE"]
			var ok: bool = sh.code.contains("#define FUMEE_MASQUE\n") and sh.code.contains("#define USURE_ESSAI\n") == usure
			for d: String in tous:
				ok = ok and sh.code.contains("#define %s\n" % d) == attendus.has(d)
			_check("forme %d (%s) : ses #define et eux seuls, usure %s, annoncée par son nom" % [k, IsoVolumes.NOMS_FORMES[k],
				"oui" if usure else "non"], ok and IsoVolumes.forme_annoncee(sh) == IsoVolumes.NOMS_FORMES[k])
			_check("forme %d : compilée une fois (la même variante au second appel)" % k,
				IsoVolumes.variante_forme(base, k) == sh)
	var v := IsoVolumes.new()
	v.masque_fumee = true
	v.forme_masque = 2
	var mat: ShaderMaterial = v.call("_materiau_volume")
	_check("posée, la forme est retenue pour les lightmaps (les filtres par shader la reconnaissent)",
		(v.get("_formes_posees") as Dictionary).has(mat.shader) and src.contains(
			"s == SHADER_VOLUME or (s != null and s == _shader_masque) or _formes_posees.has(s)"))
	v.free()


func _la_forme_compacte() -> void:
	print("\n[La forme compacte : chaque surface écrite une fois]")
	var c := FileAccess.get_file_as_string("res://volume_masque_compact.gdshaderinc")
	var corps := _fonction(c, "bool masque_compact_montre_noir(")
	var sol := _fonction(c, "bool sol_montre_noir_compact(")
	_check("un seul appel au sol, à la face et au dessus dans le parcours",
		corps.count("sol_montre_noir_compact(") == 1 and corps.count("face_montre_noir(") == 1
		and corps.count("dessus_montre_noir(") == 1)
	_check("un seul appel au point du sol, dans une boucle à nombre de tours variable (1 ou 4)",
		sol.count("sol_montre_noir_au_point(") == 1 and sol.contains("int n = (e.x == 0.0 && e.y == 0.0) ? 1 : 4;")
		and sol.contains("for (int k = 0; k < n; k++) {"))
	_check("les côtés d'une couture dans l'ordre de Gadgets : +e, −e, (e.x, −e.y), (−e.x, e.y)",
		sol.contains("(k == 0 ? e : (k == 1 ? -e : (k == 2 ? vec2(e.x, -e.y) : vec2(-e.x, e.y))))")
		and FileAccess.get_file_as_string("res://volume_masque.gdshaderinc").contains(
			"return sol_montre_noir_au_point(px + e, deux, aa, px_monde, g_x, g_y)\n\t\t|| sol_montre_noir_au_point(px - e,"))
	# Le parcours : chaque ligne de calcul du parcours de Gadgets se retrouve, telle quelle, dans le compact.
	var g := _fonction(FileAccess.get_file_as_string("res://volume_masque.gdshaderinc"), "bool masque_montre_noir(")
	# Les seules lignes qui changent : la signature, et les normales et appels que le compact range dans sa cible (`n_cible`).
	var permises := ["bool masque_montre_noir(vec3 monde, vec3 vue, bool deux, vec3 d_x, vec3 d_y) {",
		"vec2 n_face = par_x ? vec2(-pas.x, 0.0) : vec2(0.0, -pas.y);", "aa_sol, haut, px_monde_sol);",
		"vec2 n = axe == 0 ? vec2(-pas.x, 0.0) : vec2(0.0, -pas.y);", "if (max(o_fin.r, o_fin.g) > 0.5) {",
		"vec2 n = dx < dz ? vec2(-pas.x, 0.0) : vec2(0.0, -pas.y);"]
	var manque: Array = []
	for ligne in g.split("\n"):
		var l := ligne.strip_edges()
		if l.is_empty() or l.begins_with("//") or l.begins_with("return") or l.begins_with("}") or l == "{" \
				or permises.has(l):
			continue
		if not corps.contains(l):
			manque.append(l)
	_check("les lignes de calcul du parcours de Gadgets sont dans le compact (hors les %d qui deviennent la cible)" % permises.size(),
		manque.is_empty(), str(manque))


func _la_bande_resserree() -> void:
	print("\n[La bande du sol resserrée : même réponse]")
	var c := FileAccess.get_file_as_string("res://volume_masque_compact.gdshaderinc")
	var inc := FileAccess.get_file_as_string("res://volume_masque.gdshaderinc")
	var ecrit := _fonction(inc, "vec3 sol_ecrit(")
	var depuis := _fonction(c, "vec3 sol_ecrit_depuis(")
	var fin_gadgets := ecrit.substr(ecrit.find("\tc = pate_facteur(c, matiere * dalle);"))
	var fin_ici := depuis.substr(depuis.find("\tc = pate_facteur(c, matiere * dalle);"))
	_check("le sol exact finit par les lignes mêmes de sol_ecrit (matière, température, usure, contact)",
		not fin_gadgets.is_empty() and fin_gadgets == fin_ici, "%d / %d caractères" % [fin_gadgets.length(), fin_ici.length()])
	var point := _fonction(c, "bool sol_montre_noir_resserre_au_point(")
	_check("la matière de la certitude est la lecture même de sol_ecrit (texture, adresse, niveau de mipmap)",
		point.contains("float matiere = mix(1.0, textureLod(sol_texture_sol, px / sol_periode_sol_px,\n\t\tniveau_mip(g_x / sol_periode_sol_px, g_y / sol_periode_sol_px)).r, sol_force_matiere);")
		and ecrit.contains("float matiere = mix(1.0, textureLod(sol_texture_sol, px / sol_periode_sol_px,\n\t\tniveau_mip(g_x / sol_periode_sol_px, g_y / sol_periode_sol_px)).r, sol_force_matiere);"))
	_check("la certitude « visible sûr » prend la matière exacte au lieu de son plancher, le reste inchangé",
		point.contains("float plancher_sol = matiere * dalle * contact_des_corps(px);")
		and inc.contains("float plancher_sol = (1.0 - sol_force_matiere) * dalle * contact_des_corps(px);")
		and point.contains("plancher_sol *= mix(1.0, USURE_SOL_PLUS_SOMBRE, usure * smoothstep(USURE_SEUILS.x, USURE_SEUILS.y, pate_luminance(c)));"))
	_check("le noir sûr et la lecture de la lumière sont ceux de Gadgets", point.contains(
		"if (max(c.r, max(c.g, c.b)) * SOL_HAUSSE_MAX < POINT_NOIR_ECRIT) {\n\t\treturn true;")
		and point.contains("vec3 lu = lire_lightmap(px + glisse * dalles, deux);"))


func _le_pochoir() -> void:
	print("\n[Le pochoir : le masque une fois par pixel]")
	_check("le juge est dessiné avant les couches", IsoVolumes.PRIORITE_JUGE < IsoVolumes.PRIORITE_VOLUME)
	_check("le carré du juge (rayon + hauteur) contient les disques des couches tant que le tangage dépasse 45°",
		CameraIso.TANGAGE_DEG >= 45.0, str(CameraIso.TANGAGE_DEG))
	var src := FileAccess.get_file_as_string("res://volume_iso.gdshader")
	var juge := _preprocesser(src, ["FUMEE_MASQUE", "MASQUE_COMPACT", "MASQUE_RESSERRE", "MASQUE_POCHOIR", "MASQUE_POCHOIR_JUGE"])
	var couche := _preprocesser(src, ["FUMEE_MASQUE", "MASQUE_COMPACT", "MASQUE_RESSERRE", "MASQUE_POCHOIR"])
	_check("le juge écrit 1 dans le pochoir, ne peint rien (opacité nulle) et pose la question du masque",
		juge.contains("stencil_mode write, compare_always, 1;") and juge.contains("ALPHA = 0.0;")
		and juge.contains("masque_compact_montre_noir(monde") and not juge.contains("ALBEDO = c;"))
	_check("les couches lisent le pochoir et ne posent plus la question",
		couche.contains("stencil_mode read, compare_not_equal, 1;") and not couche.contains("masque_compact_montre_noir(monde")
		and not couche.contains("masque_montre_noir(monde") and couche.contains("ALBEDO = c;"))
	var v := IsoVolumes.new()
	var e := {"genre": "fumee", "noeuds": [], "mats": [], "retires": []}
	v.call("_couches", e, 4)
	v.call("_poser_couches", e, Vector2(100, 200), 80.0, 1.0, 0.3, null, 0.0, 0.0, 0.0)
	_check("forme de Gadgets : aucun juge", not e.has("juge"))
	v.masque_fumee = true
	v.forme_masque = IsoVolumes.FORME_POCHOIR
	var e2 := {"genre": "fumee", "noeuds": [], "mats": [], "retires": []}
	v.call("_couches", e2, 4)
	v.call("_poser_couches", e2, Vector2(100, 200), 80.0, 1.0, 0.3, null, 0.0, 0.0, 0.0)
	var j: MeshInstance3D = e2.get("juge")
	_check("pochoir : un juge par volume, à la hauteur de la plus haute couche, qui les couvre",
		j != null and j.visible and is_equal_approx(j.position.y, IsoVolumes.TUILE)
		and is_equal_approx(j.scale.x, 2.0 * (80.0 + IsoVolumes.TUILE)))
	var mj := j.material_override as ShaderMaterial if j != null else null
	_check("le juge porte la variante juge et la priorité juge",
		mj != null and mj.shader.code.contains("#define MASQUE_POCHOIR_JUGE\n") and mj.render_priority == IsoVolumes.PRIORITE_JUGE)
	var couches_ok := (e2["mats"] as Array).all(func(m: ShaderMaterial) -> bool:
		return m.shader.code.contains("#define MASQUE_POCHOIR\n") and not m.shader.code.contains("#define MASQUE_POCHOIR_JUGE\n"))
	_check("pochoir : les couches portent la variante qui lit le pochoir", couches_ok)
	var manque: Array = []
	var corps := _fonction_gd(FileAccess.get_file_as_string("res://iso_volumes.gd"), "_poser_juge")
	for m in RegEx.create_from_string('set_shader_parameter\\("([A-Za-z_0-9]+)"').search_all(corps):
		if mj == null or not _a_l_uniforme(mj.shader, m.get_string(1)):
			manque.append(m.get_string(1))
	_check("chaque paramètre posé sur le juge est un uniforme de son shader", manque.is_empty() and corps != "", str(manque))
	var rayons: Vector4 = mj.get_shader_parameter("juge_rayons") if mj != null else Vector4.ZERO
	_check("le juge connaît le disque de chaque couche (rayon × (1 − 0,22 f), comme les couches)",
		is_equal_approx(rayons.x, 80.0) and is_equal_approx(rayons.w, 80.0 * 0.78))
	# Le ruban (la toile) : jamais sous le pochoir, il garde la forme d'avant.
	var ruban := ShaderMaterial.new()
	ruban.shader = IsoVolumes.SHADER_VOLUME
	ruban.set_shader_parameter("ruban", true)
	v.call("_poser_masque", ruban, true)
	_check("le ruban ne passe jamais sous le pochoir", not ruban.shader.code.contains("#define MASQUE_POCHOIR\n")
		and ruban.shader.code.contains("#define MASQUE_RESSERRE\n"))
	v.masque_fumee = false
	v.call("_poser_couches", e2, Vector2(100, 200), 80.0, 1.0, 0.3, null, 0.0, 0.0, 0.0)
	_check("masque éteint : le juge se cache", not j.visible)
	v.free()


func _la_lumiere_d_abord() -> void:
	print("\n[V4, la lumière d'abord : les certitudes du sol tirées de la lumière lue seule]")
	var c := FileAccess.get_file_as_string("res://volume_masque_compact.gdshaderinc")
	var pate := _fonction(FileAccess.get_file_as_string("res://iso_pate.gdshaderinc"), "vec3 pate(vec3 couleur,")
	var q := _fonction(c, "float lavis_q(")
	var lavis := pate.substr(pate.find("// PATE_LAVIS"))
	var memes := ["float a = 0.01;", "float e_1 = 0.02 + 0.03 * b;", "float e_2 = 0.16 + 0.08 * b;",
		"float e_3 = 0.42 + 0.1 * b;", "float q = 0.3 * smoothstep(e_1 - a, e_1 + a, l)",
		"+ 0.3 * smoothstep(e_2 - a, e_2 + a, l)", "+ 0.4 * smoothstep(e_3 - a, e_3 + a, l);"]
	var manque := memes.filter(func(l: String) -> bool:
		return not lavis.contains(l) or not q.replace("return 0.3", "float q = 0.3").contains(l))
	_check("le q de la borne est celui du lavis : mêmes seuils, mêmes poids, même demi-largeur", manque.is_empty(), str(manque))
	_check("le lavis que la borne suppose : grain dans [0,82 ; 1[, lavage à 0,35 vers la luminance, plancher 0,25",
		lavis.contains("* (0.82 + 0.18 * grain)") and lavis.contains(
		"vec3 lave = mix(couleur, vec3(pate_luminance(couleur)), 0.35) / max(l, PATE_PLANCHER);")
		and pate.contains("float l = clamp(lumiere, 0.0, 1.0);"))
	var borne := _fonction(c, "int sol_borne_lumiere(")
	_check("la borne : lavis seulement, aucune sous l'encre d'essai, marge vers le calcul d'avant",
		borne.contains("if (style != PATE_LAVIS) {\n\t\treturn 0;") and borne.contains("#ifdef ENCRE_ESSAI\n\treturn 0;")
		and borne.contains("* (1.0 + BORNE_MARGE)") and borne.contains("bas * (1.0 - BORNE_MARGE) >= POINT_NOIR_ECRIT")
		and borne.contains("bas *= mix(1.0, USURE_SOL_PLUS_SOMBRE, usure);"))
	var point := _fonction(c, "bool sol_montre_noir_resserre_au_point(")
	var i_borne := point.find("int borne = sol_borne_lumiere(")
	_check("la borne est posée APRÈS la lecture de la lumière et AVANT la pâte et la matière",
		i_borne > point.find("vec3 lu = lire_lightmap(px + glisse * dalles, deux);") and i_borne < point.find("vec3 c = pate(")
		and i_borne < point.find("textureLod(sol_texture_sol"))
	_check("son joint et son contact sont ceux de la certitude de Gadgets",
		point.contains("\tvec2 dans_dalle_l = abs(fract(px / sol_dalle_px) - 0.5) * sol_dalle_px;")
		and point.contains("\tfloat au_bord_l = sol_dalle_px * 0.5 - max(dans_dalle_l.x, dans_dalle_l.y);")
		and point.contains("dalles * pate_trait_de_bord(au_bord_l, max(sol_joint_dalle_px, px_monde), px_monde));")
		and point.contains("(1.0 - sol_force_matiere) * dalle_l * contact_des_corps(px));"))
	# Rejouée sur la pâte du processeur : la borne (même arithmétique que le GLSL) ne contredit jamais la certitude exacte.
	var pn := 8.0 / 255.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260928
	var contredit := 0
	var noirs := 0
	var visibles := 0
	var n := 40000
	for i in n:
		var l_cible := pow(rng.randf(), 2.5)
		var teinte := Vector3(rng.randf(), rng.randf(), rng.randf())
		if rng.randf() < 0.3:
			teinte = Vector3(1.0, rng.randf() * 0.3, rng.randf() * 0.15)
		var lu := (teinte * (l_cible / maxf(IsoPate.luminance(teinte), 1e-4))).clamp(Vector3.ZERO, Vector3.ONE)
		var l := IsoPate.luminance(lu)
		if l <= 0.0:
			continue
		var plancher := (1.0 - 0.5) * (0.6 if rng.randf() < 0.2 else 1.0) * (0.25 + 0.75 * rng.randf() if rng.randf() < 0.2 else 1.0)
		var usure := 1.0 if rng.randf() < 0.7 else 0.0
		var motif := Vector2(rng.randf_range(-3000.0, 3000.0), rng.randf_range(-3000.0, 3000.0))
		var cc := IsoPate.pate(lu, l, IsoPate.LAVIS, motif, Vector2.ZERO, l, 0.3)
		var r := _borne_lumiere(lu, l, plancher, usure)
		# La certitude exacte de Gadgets, au plancher le plus sombre que la borne suppose (usure lue au pire) : « noir » si le
		# canal le plus fort × 1,4 est sous le point noir ; « visible » si luminance × plancher (matière ≥ 1 − force) l'atteint.
		var noir_vrai := maxf(cc.x, maxf(cc.y, cc.z)) * 1.4 < pn
		var visible_vrai := IsoPate.luminance(cc) * plancher * lerpf(1.0, 0.45, usure) >= pn
		if r == 1:
			noirs += 1
			contredit += 0 if noir_vrai else 1
		elif r == 2:
			visibles += 1
			contredit += 0 if visible_vrai else 1
	_check("rejouée en %d points sur la pâte du processeur, la borne ne contredit jamais la certitude exacte (%d noirs, %d visibles tranchés)"
		% [n, noirs, visibles], contredit == 0 and noirs > 1000 and visibles > 1000, "%d contradictions" % contredit)


## La borne de V4 (`sol_borne_lumiere`), même arithmétique que le GLSL.
func _borne_lumiere(lu: Vector3, l: float, plancher: float, usure: float) -> int:
	var lc := clampf(l, 0.0, 1.0)
	var m := maxf(lc, 0.25)
	if _lavis_q(lc, 0.0) * (0.65 * maxf(lu.x, maxf(lu.y, lu.z)) + 0.35 * l) / m * 1.4 * (1.0 + 1e-4) < 8.0 / 255.0:
		return 1
	var bas := _lavis_q(lc, 1.0) * 0.82 * l / m * plancher * lerpf(1.0, 0.45, usure)
	return 2 if bas * (1.0 - 1e-4) >= 8.0 / 255.0 else 0


func _lavis_q(l: float, b: float) -> float:
	var a := 0.01
	var e_1 := 0.02 + 0.03 * b
	var e_2 := 0.16 + 0.08 * b
	var e_3 := 0.42 + 0.1 * b
	return 0.3 * smoothstep(e_1 - a, e_1 + a, l) + 0.3 * smoothstep(e_2 - a, e_2 + a, l) + 0.4 * smoothstep(e_3 - a, e_3 + a, l)


func _le_juge_ajuste() -> void:
	print("\n[V5, le juge ajusté : un disque au lieu du carré]")
	var v := IsoVolumes.new()
	v.masque_fumee = true
	v.forme_masque = IsoVolumes.FORME_AJUSTEE
	var e := {"genre": "fumee", "noeuds": [], "mats": [], "retires": []}
	v.call("_couches", e, 4)
	var rayon := 80.0
	v.call("_poser_couches", e, Vector2(100, 200), rayon, 1.0, 0.3, null, 0.0, 0.0, 0.0)
	var j: MeshInstance3D = e.get("juge")
	var mj := j.material_override as ShaderMaterial if j != null else null
	_check("forme 5 : le juge porte MASQUE_AJUSTE et le polygone", mj != null and mj.shader.code.contains("#define MASQUE_AJUSTE\n")
		and mj.shader.code.contains("#define MASQUE_POCHOIR_JUGE\n") and j.mesh is ArrayMesh)
	# Le polygone : son apothème vaut 0,5 (à l'échelle 1) — il contient le disque de diamètre 1.
	var sommets: PackedVector3Array = (j.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] if j != null else []
	var apotheme := INF
	for k in range(0, sommets.size(), 3):
		var a := Vector2(sommets[k + 1].x, sommets[k + 1].z)
		var b := Vector2(sommets[k + 2].x, sommets[k + 2].z)
		apotheme = minf(apotheme, absf(a.cross(b)) / (b - a).length())
	_check("le polygone du juge contient le disque de diamètre 1 (apothème %.6f)" % apotheme,
		sommets.size() == 3 * IsoVolumes.COTES_JUGE and apotheme >= 0.5 - 1e-6)
	# Le disque de chaque couche, vu depuis le juge (décalé de (haut − h) / tan(tangage), au pire dans n'importe quelle
	# direction), tient dans le disque du juge.
	var rayons: Vector4 = mj.get_shader_parameter("juge_rayons")
	var hauteurs: Vector4 = mj.get_shader_parameter("juge_hauteurs")
	var portee := j.scale.x * 0.5
	var decalage := 1.0 / tan(deg_to_rad(CameraIso.TANGAGE_DEG))
	var tient := true
	for k in 4:
		tient = tient and rayons[k] + (j.position.y - hauteurs[k]) * decalage <= portee + 1e-4
	_check("chaque couche vue depuis le juge tient dans son disque (portée %.1f, tangage %.0f°)" % [portee, CameraIso.TANGAGE_DEG],
		tient and portee < rayon + IsoVolumes.TUILE)
	_check("le disque du juge ajusté est plus petit que le carré du pochoir (%.0f contre %.0f px² de monde)"
		% [PI * portee * portee, pow(2.0 * (rayon + IsoVolumes.TUILE), 2.0)],
		IsoVolumes.COTES_JUGE * portee * portee * tan(PI / IsoVolumes.COTES_JUGE) < pow(2.0 * (rayon + IsoVolumes.TUILE), 2.0))
	_check("le juge ajusté n'ajoute aucun code GLSL : MASQUE_AJUSTE n'apparaît dans aucun shader",
		not FileAccess.get_file_as_string("res://volume_masque_compact.gdshaderinc").contains("MASQUE_AJUSTE")
		and not FileAccess.get_file_as_string("res://volume_iso.gdshader").contains("MASQUE_AJUSTE")
		and not FileAccess.get_file_as_string("res://volume_masque.gdshaderinc").contains("MASQUE_AJUSTE"))
	v.forme_masque = 4
	v.call("_poser_couches", e, Vector2(100, 200), rayon, 1.0, 0.3, null, 0.0, 0.0, 0.0)
	_check("revenu à la forme 4 : le juge reprend le carré et sa variante", j.mesh is PlaneMesh
		and is_equal_approx(j.scale.x, 2.0 * (rayon + IsoVolumes.TUILE))
		and not (j.material_override as ShaderMaterial).shader.code.contains("#define MASQUE_AJUSTE\n")
		and (j.material_override as ShaderMaterial).shader.code.contains("#define MASQUE_LUMIERE\n"))
	v.free()


func _fonction(code: String, signature: String) -> String:
	var debut := code.find(signature)
	if debut < 0:
		return ""
	var fin := code.find("\n}\n", debut)
	return code.substr(debut, fin + 3 - debut) if fin > debut else ""


func _fonction_gd(code: String, nom: String) -> String:
	var debut := code.find("\nfunc %s(" % nom)
	if debut < 0:
		return ""
	var fin := code.find("\nfunc ", debut + 1)
	var fin_statique := code.find("\nstatic func ", debut + 1)
	if fin_statique >= 0 and (fin < 0 or fin_statique < fin):
		fin = fin_statique
	return code.substr(debut, (fin if fin > 0 else code.length()) - debut)


func _a_l_uniforme(shader: Shader, nom: String) -> bool:
	for u in shader.get_shader_uniform_list():
		if u["name"] == nom:
			return true
	return false
