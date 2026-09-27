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
##   resserrée finit le sol exact par les lignes mêmes de `sol_ecrit`, et sa matière est la lecture même du sol exact ;
## - rien sur le fil : `Protocol.VERSION` reste 18.
##
## Ce qu'elle ne prouve pas : que le GPU compile les variantes (le lanceur de série refuse toute prise dont le journal porte
## une erreur de shader) ni la réponse au pixel — `loupe-fusee-masque-formes` et `tools/masque_fumee/formes.py`.
extends SceneTree

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
	var marques := ["MASQUE_COMPACT", "MASQUE_RESSERRE", "MASQUE_POCHOIR", "MASQUE_POCHOIR_JUGE"]
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
	_check("les deux drapeaux, dans l'ordre des formes", IsoVolumes.FORMES_MASQUE == {"--fumee-masque-compact": 1,
		"--fumee-masque-resserre": 2})
	_check("un drapeau de forme allume le masque et pose sa forme",
		src.contains("\t\telif FORMES_MASQUE.has(arg):\n\t\t\tmasque_fumee = true\n\t\t\tforme_masque = int(FORMES_MASQUE[arg])"))
	for usure in [false, true]:
		var base: Shader = IsoVolumes.variante_masque(usure)
		for k in range(1, IsoVolumes.DEFINES_FORMES.size()):
			var sh := IsoVolumes.variante_forme(base, k)
			var attendus: Array = IsoVolumes.DEFINES_FORMES[k]
			var tous := ["MASQUE_COMPACT", "MASQUE_RESSERRE", "MASQUE_POCHOIR"]
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
