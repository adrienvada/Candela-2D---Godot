## Q39 — son propre corps, sombre avec un liseré, à l'essai (`--corps-soi-sombre`, session cloud corps-sombre, 2026-09-28).
##
## Ce que la suite prouve, sans fenêtre :
## - **le drapeau, éteint par défaut, ne change rien au bit** : sans lui, `accorder_corps` laisse le shader d'origine, qui
##   ne déclare aucun uniforme de l'essai ; tout le code de l'essai est sous `#ifdef CORPS_SOI_SOMBRE` (l'include ET les
##   lignes de `corps_iso.gdshader`), donc le préprocesseur rend le shader d'hier ;
## - **allumé** : la variante compile, déclare l'essai, survit à un changement de shader (le crochet `accorder_corps`) et se
##   compose avec le personnage détaillé ;
## - **seule la vue de soi change** : dans le shader, l'essai n'est atteint que sous `s > 0` (la silhouette de soi, nulle
##   dans la vue d'en face — `Presentation3D.silhouette_du_corps(joueur, false)` rend un alpha nul) ;
## - **la règle de l'essai**, sur un miroir de `soi_sombre_composer` écrit ici : dans le noir, rien hors de la bande du
##   repère ; le repère à la valeur de la silhouette d'aujourd'hui, jamais plus ; sans lumière dominante, aucun liseré ;
##   jamais plus clair que le corps éclairé d'aujourd'hui ou que la silhouette ; le liseré du côté de la lumière seulement ;
## - `Protocol.VERSION` reste 18 ; aucun fichier de simulation ne connaît le drapeau.
##
## Ce qu'elle ne prouve pas : l'image. La planche (`docs/iso/cloud/corps-sombre/`) la mesure, vue de l'adversaire comprise.
##
## Lancer : godot --headless --path . --script res://tools/test_corps_soi_sombre.gd
extends SceneTree

const PLANCHER := 30
const INC := "res://iso_corps_soi_sombre.gdshaderinc"
const SHADER := "res://corps_iso.gdshader"
## Les réglages de l'include (ses défauts), relus dans le texte par la suite pour que le miroir ne dérive pas.
const FACTEUR := 0.4
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
	print("=== Q39 — SON PROPRE CORPS, SOMBRE AVEC UN LISERÉ (essai) ===")
	await process_frame
	var racine := Node3D.new()
	root.add_child(racine)
	_le_drapeau(racine)
	_le_texte()
	_la_regle()
	VoxelCatalogue.forcer_soi_sombre = -1
	VoxelCatalogue.forcer_detail = -1
	racine.queue_free()
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	print("%d vérifications, %d échec(s)" % [_verifications, _echecs])
	quit(1 if _echecs > 0 else 0)


func _noms(sh: Shader) -> Array:
	var noms := []
	for u in sh.get_shader_uniform_list():
		noms.append(String(u["name"]))
	return noms


func _le_drapeau(racine: Node3D) -> void:
	print("— le drapeau : éteint par défaut, rien ne change")
	VoxelCatalogue.forcer_soi_sombre = -1
	_check("--corps-soi-sombre n'est pas sur la ligne de commande de la suite", not VoxelCatalogue.soi_sombre_actif())
	_check("le drapeau s'écrit --corps-soi-sombre", VoxelCatalogue.DRAPEAU_SOI_SOMBRE == "--corps-soi-sombre")
	var origine: Shader = load(SHADER)
	_check("le shader d'origine ne déclare aucun uniforme de l'essai",
		not _noms(origine).has("soi_lumiere") and not _noms(origine).has("soi_sombre_facteur"))
	var c := VoxelCorps.new()
	racine.add_child(c)
	c.construire("pistolet")
	_check("sans drapeau : un corps construit garde le shader d'origine", c.materiau().shader == origine)
	var m := ShaderMaterial.new()
	m.shader = origine
	IsoMateriaux.accorder_corps(m)
	_check("sans drapeau : accorder_corps laisse le shader d'origine", m.shader == origine)

	print("— allumé : la variante")
	VoxelCatalogue.forcer_soi_sombre = 1
	_check("forcé à 1 : actif", VoxelCatalogue.soi_sombre_actif())
	var v := IsoMateriaux.variante_definie(origine, "CORPS_SOI_SOMBRE")
	var noms := _noms(v)
	_check("la variante CORPS_SOI_SOMBRE compile et déclare l'essai",
		noms.has("soi_lumiere") and noms.has("soi_sombre_facteur") and noms.has("soi_lisere_px"), str(noms))
	_check("la variante garde l'interface d'hier (opacité, silhouette, capteur)",
		noms.has("opacite_1") and noms.has("silhouette_2") and noms.has("capteur_1"))
	var m2 := ShaderMaterial.new()
	m2.shader = origine
	IsoMateriaux.accorder_corps(m2)
	_check("accorder_corps pose la variante", m2.shader.code.contains("#define CORPS_SOI_SOMBRE\n"))
	IsoMateriaux.accorder_corps(m2)
	_check("accorder_corps rappelé : la variante n'est pas redoublée",
		m2.shader.code.count("#define CORPS_SOI_SOMBRE\n") == 1)
	VoxelCatalogue.forcer_detail = 1
	var m3 := ShaderMaterial.new()
	m3.shader = origine
	IsoMateriaux.accorder_corps(m3)
	var noms3 := _noms(m3.shader)
	_check("avec le personnage détaillé : les deux variantes, et elles compilent ensemble",
		m3.shader.code.contains("#define CORPS_SOI_SOMBRE\n") and m3.shader.code.contains("#define CORPS_DETAIL\n")
		and noms3.has("soi_lumiere") and noms3.has("detail"))
	VoxelCatalogue.forcer_detail = 0
	var c2 := VoxelCorps.new()
	racine.add_child(c2)
	c2.construire("fusil")
	IsoMateriaux.accorder_corps(c2.materiau())
	_check("un corps construit, accordé, porte la variante", c2.materiau().shader.code.contains("#define CORPS_SOI_SOMBRE\n"))
	VoxelCatalogue.forcer_soi_sombre = 0
	_check("forcé à 0 : éteint", not VoxelCatalogue.soi_sombre_actif())

	print("— la vue d'en face : aucune silhouette, donc aucun essai")
	var joueur := Node2D.new()
	var dim := Polygon2D.new()
	dim.color = Color(0.5, 0.7, 0.9, 0.5)
	joueur.set("visual_dim", dim)
	_check("silhouette_du_corps(le_sien = faux) est transparente (s = 0)",
		Presentation3D.silhouette_du_corps(joueur, false).a == 0.0)
	dim.free()
	joueur.free()


func _le_texte() -> void:
	print("— le texte : tout l'essai sous #ifdef, et sous s > 0")
	var inc := FileAccess.get_file_as_string(INC)
	var debut := inc.find("#ifdef CORPS_SOI_SOMBRE")
	_check("l'include : tout sous #ifdef CORPS_SOI_SOMBRE", debut >= 0 and debut < inc.find("uniform vec2 soi_lumiere")
		and inc.strip_edges().ends_with("#endif"))
	_check("l'include n'écrit ni ALBEDO, ni ALPHA, ni EMISSION, ni light()",
		not inc.contains("ALBEDO") and not inc.contains("ALPHA") and not inc.contains("EMISSION") and not inc.contains("void light"))
	_check("le facteur sombre par défaut est celui du miroir (%s)" % FACTEUR,
		inc.contains("uniform float soi_sombre_facteur : hint_range(0.0, 1.0) = 0.4;"))
	var code := FileAccess.get_file_as_string(SHADER)
	# Hors des blocs #ifdef CORPS_SOI_SOMBRE … #endif, aucune ligne du shader ne nomme l'essai (hors commentaires et include).
	var dehors := []
	var dedans := false
	for ligne in code.split("\n"):
		var l := String(ligne).strip_edges()
		if l == "#ifdef CORPS_SOI_SOMBRE":
			dedans = true
			continue
		if dedans and l == "#endif":
			dedans = false
			continue
		if dedans or l.begins_with("//") or l.begins_with("#include"):
			continue
		if l.contains("soi_") or l.contains("axe_x_monde") or l.contains("axe_z_monde"):
			dehors.append(l)
	_check("corps_iso.gdshader : aucune ligne de l'essai hors de #ifdef CORPS_SOI_SOMBRE", dehors.is_empty(), str(dehors))
	_check("corps_iso.gdshader : l'essai n'est atteint que sous s > 0 (le corps de soi dans sa vue)",
		code.contains("#ifdef CORPS_SOI_SOMBRE\n\t// Q39") and code.contains("\tif (s > 0.0) {\n\t\tvec3 soi = soi_sombre_composer("))
	_check("corps_iso.gdshader : l'alpha d'hier, posé après l'essai et hors de lui",
		code.find("ALPHA = a;") > code.find("vec3 soi = soi_sombre_composer("))
	_check("le shader éclairé (lumière 3D) ne porte pas l'essai — dit dans le rapport",
		not FileAccess.get_file_as_string("res://corps_iso_eclaire.gdshader").contains("CORPS_SOI_SOMBRE"))
	_check("Protocol.VERSION reste 18 : rien sur le fil",
		FileAccess.get_file_as_string("res://protocol.gd").contains("const VERSION := 18"))
	var sim_propre := true
	for f in ["res://player.gd", "res://game_state.gd", "res://network_manager.gd", "res://protocol.gd"]:
		sim_propre = sim_propre and not FileAccess.get_file_as_string(f).contains("soi_sombre")
	_check("ni player.gd, ni game_state.gd, ni le réseau ne connaissent l'essai", sim_propre)


# ---------------------------------------------------------------------------
# Le miroir de `soi_sombre_composer` (iso_corps_soi_sombre.gdshaderinc), ramené à ce qu'il décide : `bande` (1 sur le bord
# d'une face, 0 au milieu), `face` (l'orientation du bord vers la lumière × sa netteté).
# ---------------------------------------------------------------------------
func _composer(c: Vector3, sil: Vector3, s: float, bande: float, face: float) -> Vector3:
	var corps := IsoPate.facteur(c, FACTEUR)
	corps = corps.lerp(c, bande * face)
	return corps.max(sil * s * bande)


func _face(direction_du_bord: Vector2, lumiere: Vector2) -> float:
	var nette := minf(lumiere.length(), 1.0)
	if nette <= 0.001:
		return 0.0
	return nette * maxf(direction_du_bord.dot(lumiere.normalized()), 0.0)


func _la_regle() -> void:
	print("— la règle de l'essai, sur son miroir")
	var bleu := Vector3(0.53, 0.8, 0.98)
	var noir := Vector3.ZERO
	var fiche := Vector3(0.5, 0.53, 0.57)
	_check("dans le noir, au milieu d'une face : 0 (rien ne s'allume hors de la bande)",
		_composer(noir, bleu, 0.5, 0.0, 0.0) == Vector3.ZERO)
	_check("dans le noir, sur le bord : le repère, à la valeur de la silhouette d'aujourd'hui",
		_composer(noir, bleu, 0.5, 1.0, 0.0).is_equal_approx(bleu * 0.5))
	var aujourd_hui_noir := bleu * 0.5  # (0·o·(1−s) + sil·s)/a, à o = 1, s = 0,5
	var jamais := true
	var sombre := true
	var cote := true
	for lum in [0.0, 0.05, 0.2, 0.5, 1.0]:
		var c: Vector3 = fiche * lum
		var aujourd_hui: Vector3 = (c * 0.5 + bleu * 0.5)
		for b in [0.0, 0.5, 1.0]:
			for f in [0.0, 0.3, 1.0]:
				var r := _composer(c, bleu, 0.5, b, f)
				jamais = jamais and r.x <= maxf(c.x, aujourd_hui_noir.x) + 1e-6 and r.y <= maxf(c.y, aujourd_hui_noir.y) + 1e-6 \
					and r.z <= maxf(c.z, aujourd_hui_noir.z) + 1e-6
				jamais = jamais and IsoPate.luminance(r) <= maxf(IsoPate.luminance(aujourd_hui), IsoPate.luminance(c)) + 1e-6
		# Au milieu d'une face, le corps éclairé ne dépasse jamais 0,4 fois (en valeur affichée) sa lumière d'aujourd'hui.
		var milieu := _composer(c, bleu, 0.5, 0.0, 1.0)
		sombre = sombre and IsoPate.luminance(milieu) <= IsoPate.luminance(c) + 1e-6
		cote = cote and (lum == 0.0 or IsoPate.luminance(_composer(c, bleu, 0.5, 1.0, 1.0))
			>= IsoPate.luminance(_composer(c, bleu, 0.5, 1.0, 0.0)) - 1e-6)
	_check("jamais plus clair que le corps éclairé ou la silhouette d'aujourd'hui, canal par canal", jamais)
	_check("au milieu d'une face : le corps éclairé, assombri, jamais plus clair", sombre)
	_check("le bord tourné vers la lumière est au moins aussi clair que le bord qui lui tourne le dos", cote)
	_check("sans lumière dominante : aucun liseré", _face(Vector2.RIGHT, Vector2.ZERO) == 0.0)
	_check("le liseré du côté de la lumière seulement (dos : 0)",
		_face(Vector2.LEFT, Vector2(0.8, 0.0)) == 0.0 and is_equal_approx(_face(Vector2.RIGHT, Vector2(0.8, 0.0)), 0.8))
	var pleine := fiche
	var milieu_plein := IsoPate.luminance(_composer(pleine, bleu, 0.5, 0.0, 1.0))
	_check("en pleine lumière, le corps vaut ~0,4 de sa lumière d'aujourd'hui en valeur affichée (%.3f)" % milieu_plein,
		milieu_plein < IsoPate.luminance(pleine) * 0.75)
