## Q39, deuxième tour — LA PRÉ-PASSE PORTE LE PROGRAMME DE LA COULEUR, POUR TOUTE COMBINAISON DE VARIANTES (relecture de
## Beauté, 2026-09-28 ; session cloud corps-sombre-2).
##
## Le piège (ROADMAP, « Une pré-passe de profondeur et sa couleur doivent être LE MÊME programme ») : avec deux programmes,
## llvmpipe calculait des profondeurs différentes au bit près, et une pièce entière perdait le test contre sa propre
## pré-passe (triangles noirs, 88 à 739 pixels). Q33 l'avait réglé pour `--corps-detaille` seul. Sous `--corps-soi-sombre`
## (Q39), la couleur passait à la variante CORPS_SOI_SOMBRE et la pré-passe gardait l'ancien programme ; et avec les deux
## drapeaux, `accorder_corps` accordait la pré-passe AVANT de poser CORPS_SOI_SOMBRE.
##
## Ce que la suite prouve, sans fenêtre, pour les huit combinaisons détail × matière × soi sombre, sur le shader des corps
## ET son jumeau éclairé (la lumière 3D rappelle `accorder_corps`) :
## - dès qu'une variante est posée, la pré-passe porte LE MÊME `Shader` que la couleur, `passe_profondeur` à 1 pour elle
##   et nul pour la couleur, et ce programme déclare `passe_profondeur` (il porte la sortie de pré-passe) ;
## - sans aucune variante, la couleur garde le shader d'origine et la pré-passe `corps_iso_profondeur.gdshader` ; et une
##   pré-passe qui avait suivi une variante y REVIENT quand les drapeaux s'éteignent ;
## - la méta `MATERIAU_PROFONDEUR` est posée à la construction de TOUT corps, détaillé ou non ;
## - au texte : la sortie de pré-passe ouvre `fragment()` sous CORPS_PASSE_UNIQUE dans les deux shaders, défini pour
##   CORPS_DETAIL comme pour CORPS_SOI_SOMBRE, et la liste des variantes de `IsoMateriaux` est celle du `#if` ; dans
##   `accorder_corps`, l'appel à `accorder_passe_profondeur` est unique et vient après la dernière variante.
## - **par mutation** : la même vérification, appliquée à un miroir de l'ANCIEN ordre (la pré-passe accordée sous le
##   détail, avant CORPS_SOI_SOMBRE ; la méta posée au seul `_detailler`), doit rougir — sinon la garde ne garde rien.
##
## Lancer : godot --headless --path . --script res://tools/test_passe_unique.gd
extends SceneTree

const PLANCHER := 60
const SHADER_COULEUR := "res://corps_iso.gdshader"
const SHADER_ECLAIRE := "res://corps_iso_eclaire.gdshader"
const SHADER_PROFONDEUR := "res://corps_iso_profondeur.gdshader"

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
	print("=== Q39 (2) — LA PRÉ-PASSE PORTE LE PROGRAMME DE LA COULEUR, POUR TOUTE VARIANTE ===")
	await process_frame
	var racine := Node3D.new()
	root.add_child(racine)
	_les_drapeaux_de_la_suite()
	_la_meta(racine)
	_les_combinaisons(racine)
	_le_retour(racine)
	_le_fondu(racine)
	_le_texte()
	_la_mutation(racine)
	VoxelCatalogue.forcer_soi_sombre = -1
	VoxelCatalogue.forcer_soi_fondu = -1
	VoxelCatalogue.forcer_detail = -1
	VoxelCatalogue.forcer_matiere = -1
	VoxelCatalogue.forcer_tenue = "-"
	racine.queue_free()
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	print("%d vérifications, %d échec(s)" % [_verifications, _echecs])
	quit(1 if _echecs > 0 else 0)


## Les drapeaux comme les poserait la ligne de commande : détail, matière, soi sombre ; la tenue du jeu (V3, sans laquelle
## le détail ne se construit pas).
func _poser(detail: bool, matiere: bool, soi: bool) -> void:
	VoxelCatalogue.forcer_tenue = VoxelCatalogue.TENUE_PAR_DEFAUT
	VoxelCatalogue.forcer_detail = 1 if detail else 0
	VoxelCatalogue.forcer_matiere = 1 if matiere else 0
	VoxelCatalogue.forcer_soi_sombre = 1 if soi else 0


func _corps(racine: Node3D, slug: String) -> VoxelCorps:
	var c := VoxelCorps.new()
	racine.add_child(c)
	c.construire(slug)
	return c


func _noms(sh: Shader) -> Array:
	var noms := []
	if sh == null:
		return noms
	for u in sh.get_shader_uniform_list():
		noms.append(String(u["name"]))
	return noms


func _nom(detail: bool, matiere: bool, soi: bool) -> String:
	return "détail %s, matière %s, soi sombre %s" % ["oui" if detail else "non", "oui" if matiere else "non",
		"oui" if soi else "non"]


## La règle, pour une paire couleur / pré-passe : "" si elle tient, sinon ce qui manque.
func _ecart(m: ShaderMaterial, mp: ShaderMaterial, base: Shader, detail: bool, matiere: bool, soi: bool) -> String:
	var attendus := []
	if detail:
		attendus.append("CORPS_DETAIL")
		if matiere:
			attendus.append("CORPS_DETAIL_MATIERE")
	if soi:
		attendus.append("CORPS_SOI_SOMBRE")
	for d in attendus:
		if not m.shader.code.contains("#define %s\n" % d):
			return "la couleur n'a pas %s" % d
	if not detail and m.shader.code.contains("#define CORPS_DETAIL\n"):
		return "la couleur a CORPS_DETAIL sans le drapeau"
	if not soi and m.shader.code.contains("#define CORPS_SOI_SOMBRE\n"):
		return "la couleur a CORPS_SOI_SOMBRE sans le drapeau"
	if attendus.is_empty():
		if m.shader != base:
			return "sans variante, la couleur a quitté le shader d'origine"
		if mp.shader != load(SHADER_PROFONDEUR):
			return "sans variante, la pré-passe n'est pas corps_iso_profondeur (%s)" % (mp.shader.resource_path if mp.shader else "null")
		return ""
	if mp.shader != m.shader:
		var manque := []
		for d in attendus:
			if mp.shader == null or not mp.shader.code.contains("#define %s\n" % d):
				manque.append(d)
		return "DEUX PROGRAMMES : la pré-passe n'a pas le shader de la couleur (il lui manque %s)" % ", ".join(manque)
	if mp.get_shader_parameter("passe_profondeur") != 1.0:
		return "passe_profondeur n'est pas 1 sur la pré-passe (%s)" % str(mp.get_shader_parameter("passe_profondeur"))
	var pc = m.get_shader_parameter("passe_profondeur")
	if pc != null and pc != 0.0:
		return "passe_profondeur n'est pas nul sur la couleur (%s)" % str(pc)
	if not _noms(m.shader).has("passe_profondeur"):
		return "le programme ne porte pas la sortie de pré-passe (aucun uniforme passe_profondeur)"
	if mp.render_priority != -1:
		return "la pré-passe n'est plus à la priorité -1"
	return ""


func _les_drapeaux_de_la_suite() -> void:
	print("— les drapeaux de la suite")
	VoxelCatalogue.forcer_soi_sombre = -1
	VoxelCatalogue.forcer_detail = -1
	# Depuis la 0.7.0 (Q39 = A), le corps de soi sombre est allumé par défaut ; le détail reste un essai.
	_check("par défaut : pas de --corps-detaille, le corps de soi sombre allumé (Q39, 0.7.0)",
		not VoxelCatalogue.detail_actif() and VoxelCatalogue.soi_sombre_actif())


func _la_meta(racine: Node3D) -> void:
	print("— la méta MATERIAU_PROFONDEUR, posée à la construction de tout corps")
	for detail in [false, true]:
		_poser(detail, false, false)
		for slug in ["pistolet", "occulteur", "fumiste"]:
			var c := _corps(racine, slug)
			var m := c.materiau()
			_check("%s (%s) : la couleur connaît sa pré-passe dès la construction" % [slug, "détaillé" if detail else "ordinaire"],
				m.has_meta(IsoMateriaux.MATERIAU_PROFONDEUR)
				and m.get_meta(IsoMateriaux.MATERIAU_PROFONDEUR) == c.materiau_profondeur())


func _les_combinaisons(racine: Node3D) -> void:
	print("— les huit combinaisons, sur les deux shaders des corps")
	for detail in [false, true]:
		for matiere in [false, true]:
			for soi in [false, true]:
				_poser(detail, matiere, soi)
				for slug in ["pistolet", "occulteur"]:
					var c := _corps(racine, slug)
					var m := c.materiau()
					var mp := c.materiau_profondeur()
					# La présentation : `accorder_corps` après la construction, puis la lumière 3D qui change le shader et le rappelle.
					IsoMateriaux.accorder_corps(m)
					var e := _ecart(m, mp, load(SHADER_COULEUR), detail, matiere, soi)
					_check("%s, %s — corps_iso" % [slug, _nom(detail, matiere, soi)], e == "", e)
					m.shader = load(SHADER_ECLAIRE)
					IsoMateriaux.accorder_corps(m)
					e = _ecart(m, mp, load(SHADER_ECLAIRE), detail, matiere, soi)
					_check("%s, %s — corps_iso_eclaire (lumière 3D)" % [slug, _nom(detail, matiere, soi)], e == "", e)
					# Et le retour au shader non éclairé : la pré-passe suit encore.
					m.shader = load(SHADER_COULEUR)
					IsoMateriaux.accorder_corps(m)
					e = _ecart(m, mp, load(SHADER_COULEUR), detail, matiere, soi)
					_check("%s, %s — retour de la lumière 3D" % [slug, _nom(detail, matiere, soi)], e == "", e)


## Une pré-passe qui avait suivi une variante revient au shader ordinaire quand la couleur y revient (drapeaux éteints).
func _le_retour(racine: Node3D) -> void:
	print("— le retour au shader ordinaire")
	_poser(false, false, true)
	var c := _corps(racine, "spectre")
	IsoMateriaux.accorder_corps(c.materiau())
	var suivi := c.materiau_profondeur().shader == c.materiau().shader
	_poser(false, false, false)
	c.materiau().shader = load(SHADER_COULEUR)
	IsoMateriaux.accorder_corps(c.materiau())
	_check("soi sombre allumé puis éteint : la pré-passe avait suivi, puis revient à corps_iso_profondeur",
		suivi and c.materiau_profondeur().shader == load(SHADER_PROFONDEUR))


## L'essai B (`--corps-soi-sombre=fondu`) ajoute CORPS_SOI_FONDU APRÈS CORPS_SOI_SOMBRE : la pré-passe doit le suivre aussi.
func _le_fondu(racine: Node3D) -> void:
	print("— l'essai B (fondu) : la pré-passe suit aussi CORPS_SOI_FONDU")
	for detail in [false, true]:
		_poser(detail, false, true)
		VoxelCatalogue.forcer_soi_fondu = 1
		var c := _corps(racine, "occulteur")
		var m := c.materiau()
		var mp := c.materiau_profondeur()
		IsoMateriaux.accorder_corps(m)
		var e := _ecart(m, mp, load(SHADER_COULEUR), detail, false, true)
		if e == "" and not (m.shader.code.contains("#define CORPS_SOI_FONDU\n") and mp.shader == m.shader):
			e = "la couleur n'a pas CORPS_SOI_FONDU, ou la pré-passe ne l'a pas suivie"
		_check("occulteur, détail %s, essai B — corps_iso" % ("oui" if detail else "non"), e == "", e)
		VoxelCatalogue.forcer_soi_fondu = -1


func _le_texte() -> void:
	print("— au texte")
	for chemin in [SHADER_COULEUR, SHADER_ECLAIRE]:
		var code := FileAccess.get_file_as_string(chemin)
		var debut := code.substr(code.find("void fragment() {"), 200)
		_check("%s : le fragment s'ouvre sur la sortie de pré-passe, sous CORPS_PASSE_UNIQUE, fermée sous le même" % chemin.get_file(),
			debut.begins_with("void fragment() {\n#ifdef CORPS_PASSE_UNIQUE") and code.contains("\tif (passe_profondeur > 0.5) {")
			and code.contains("\t\tALPHA = 0.0;\n\t} else {\n#endif") and code.contains("#ifdef CORPS_PASSE_UNIQUE\n\t}\n#endif\n}"))
		_check("%s : inclut iso_corps_detail.gdshaderinc (qui définit CORPS_PASSE_UNIQUE) avant fragment()" % chemin.get_file(),
			code.find("#include \"res://iso_corps_detail.gdshaderinc\"") >= 0
			and code.find("#include \"res://iso_corps_detail.gdshaderinc\"") < code.find("void fragment() {"))
	var inc := FileAccess.get_file_as_string("res://iso_corps_detail.gdshaderinc")
	var ligne := "#if defined(CORPS_DETAIL) || defined(CORPS_SOI_SOMBRE)\n#define CORPS_PASSE_UNIQUE\nuniform float passe_profondeur = 0.0;\n#endif"
	_check("iso_corps_detail.gdshaderinc : CORPS_PASSE_UNIQUE et passe_profondeur, pour CORPS_DETAIL comme pour CORPS_SOI_SOMBRE",
		inc.contains(ligne) and inc.find(ligne) < inc.find("#ifdef CORPS_DETAIL\n"))
	var dans_if := []
	for d in IsoMateriaux.VARIANTES_PASSE_UNIQUE:
		dans_if.append(inc.contains("defined(%s)" % d))
	_check("IsoMateriaux.VARIANTES_PASSE_UNIQUE = les variantes du #if (%s)" % ", ".join(IsoMateriaux.VARIANTES_PASSE_UNIQUE),
		not dans_if.has(false) and IsoMateriaux.VARIANTES_PASSE_UNIQUE.size() == ligne.count("defined("))
	for chemin in [SHADER_COULEUR, SHADER_ECLAIRE]:
		_check("%s sans variante : ne déclare pas passe_profondeur (le code d'avant)" % chemin.get_file(),
			not _noms(load(chemin)).has("passe_profondeur"))
		for d in ["CORPS_DETAIL", "CORPS_SOI_SOMBRE"]:
			_check("%s, variante %s : compile et déclare passe_profondeur" % [chemin.get_file(), d],
				_noms(IsoMateriaux.variante_definie(load(chemin), d)).has("passe_profondeur"))
	var src := FileAccess.get_file_as_string("res://iso_materiaux.gd")
	var corps := src.substr(src.find("static func accorder_corps("), 4000)
	corps = corps.substr(0, corps.find("\n\n\n"))
	var appel := corps.rfind("accorder_passe_profondeur(materiau)")
	_check("accorder_corps : un seul appel à accorder_passe_profondeur",
		corps.count("accorder_passe_profondeur(") == 1, "%d appels" % corps.count("accorder_passe_profondeur("))
	_check("accorder_corps : l'appel vient APRÈS la dernière variante posée",
		appel > corps.rfind("variante_definie(") and appel > corps.rfind("poser_encre_essai("))
	var vc := FileAccess.get_file_as_string("res://voxel_corps.gd")
	_check("voxel_corps.gd : la méta est posée à la construction (juste après la pré-passe), plus au seul _detailler",
		vc.count("set_meta(IsoMateriaux.MATERIAU_PROFONDEUR") == 1
		and vc.find("set_meta(IsoMateriaux.MATERIAU_PROFONDEUR") < vc.find("_construire_squelette()\n")
		and vc.find("set_meta(IsoMateriaux.MATERIAU_PROFONDEUR") > vc.find("_materiau_profondeur = ShaderMaterial.new()"))


## L'ANCIEN code, recopié tel qu'il était avant ce correctif (fusion 7493c82 et branche corps-sombre littérale) : la méta posée
## au seul `_detailler`, et la pré-passe accordée dans le bloc du détail, avant CORPS_SOI_SOMBRE. La garde doit le voir.
func _accorder_ancien(materiau: ShaderMaterial, suivre_apres_soi: bool) -> void:
	if VoxelCatalogue.detail_actif():
		materiau.shader = IsoMateriaux.variante_definie(materiau.shader, "CORPS_DETAIL")
		if VoxelCatalogue.matiere_detail_active():
			materiau.shader = IsoMateriaux.variante_definie(materiau.shader, "CORPS_DETAIL_MATIERE")
		_suivre_ancien(materiau)
	if VoxelCatalogue.soi_sombre_actif():
		materiau.shader = IsoMateriaux.variante_definie(materiau.shader, "CORPS_SOI_SOMBRE")
		if suivre_apres_soi:
			_suivre_ancien(materiau)


func _suivre_ancien(materiau: ShaderMaterial) -> void:
	if not materiau.has_meta(IsoMateriaux.MATERIAU_PROFONDEUR):
		return
	var p := materiau.get_meta(IsoMateriaux.MATERIAU_PROFONDEUR) as ShaderMaterial
	p.shader = materiau.shader
	p.set_shader_parameter("passe_profondeur", 1.0)


func _la_mutation(racine: Node3D) -> void:
	print("— par mutation : l'ancien ordre fait rougir la même vérification")
	for variante in [["branche corps-sombre littérale (suivi sous le détail seulement)", false],
			["fusion 7493c82 (suivi aussi après soi sombre)", true]]:
		var rouges := []
		for detail in [false, true]:
			for soi in [false, true]:
				_poser(detail, false, soi)
				var c := _corps(racine, "occulteur")
				var m := c.materiau()
				var mp := c.materiau_profondeur()
				# L'ancienne construction : la méta n'existait qu'au `_detailler`.
				if not detail:
					m.remove_meta(IsoMateriaux.MATERIAU_PROFONDEUR)
					mp.shader = load(SHADER_PROFONDEUR)
				else:
					mp.shader = m.shader
				_accorder_ancien(m, variante[1])
				if _ecart(m, mp, load(SHADER_COULEUR), detail, false, soi) != "":
					rouges.append(_nom(detail, false, soi))
		_check("%s : la garde rougit sur « soi sombre seul » (%s)" % [variante[0], "; ".join(rouges)],
			rouges.has(_nom(false, false, true)))
		if not variante[1]:
			_check("%s : la garde rougit aussi sur « détail + soi sombre » (l'ordre d'appel)" % variante[0],
				rouges.has(_nom(true, false, true)))
		_check("%s : et elle ne rougit pas sans soi sombre (l'ancien code y était juste)" % variante[0],
			not rouges.has(_nom(false, false, false)) and not rouges.has(_nom(true, false, false)))
