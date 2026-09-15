## Banc de la zone morte au rendu — chantier MURS BAS, étape MB3c. FENÊTRÉ.
##
## Ce que `tools/test_murs_bas_rendu.gd` ne peut pas dire en headless : que le
## PIXEL du vrai jeu suive `MursBas.franchit`. Le banc ouvre le vrai `main.tscn`,
## pose la carte d'essai (`tools/cartes/murs_bas_essai.json`), met en scène une
## torche debout au nord du long mur bas et l'adversaire derrière, et mesure :
##
##   1. ACCORD SOL — chaque point du sol que la torche éclaire SANS la règle est lu
##      à l'écran et comparé à `MursBas.franchit` (murs rentrés, comme leurs
##      occluders) ; et aucun point noir sans la règle ne s'allume avec elle ;
##   2. ACCORD CORPS — accroupi à L − 12 px : noir ; à L + 12 : éclairé ; debout à
##      L − 12 : éclairé (« un mur bas laisse voir une tête debout ») ;
##   3. HORS ZONE — là où la règle laisse passer, le pixel est celui de l'ancien
##      matériau additif (`CanvasItemMaterial`), au niveau près ;
##   4. NOIR ABSOLU — toutes lumières éteintes, rien de plus clair qu'avec l'ancien
##      matériau ;
##   5. COÛT — appels de dessin et durée d'image (ancien matériau, règle sans mur,
##      carte d'essai, 40 murs), et le coût CPU de la poussée des uniformes.
##      Ordre de grandeur, pas un relevé au protocole de `bench_framerate`.
##
## 1 à 3 se jouent pour la vue de chaque joueur en écran scindé (sous-vues), puis
## en vue unique (la racine rend le duel) : la transformation écran n'y est pas
## la même, et c'est elle qui place la zone morte.
##
## ⚠️ La source de la torche n'est PAS le centre du joueur : `_rapprocher_la_lampe`
## l'avance le long de la visée. La vérité lit `flashlight.global_position`.
##
## Lancer : godot --path . res://tools/banc_murs_bas.tscn -- [--captures <dossier>]
extends Node

const CARTE := "res://tools/cartes/murs_bas_essai.json"
const Conditions := preload("res://conditions_de_match.gd")
## Seuil « éclairé », le même que le prototype MB0 (`proto_murs_bas.gd`).
const SEUIL := 10.0 / 255.0
## Écart toléré avec l'ancien matériau hors zone morte, en niveaux sur 255.
const ECART_ANCIEN_MAX := 2
## Portée d'échantillonnage du sol autour de la torche, et pas de la grille.
const PORTEE := 260.0
const PAS := 6.0

var _main: Node
var _ui: Node
var _dossier := ""
var _echecs := 0
## Les murs bas de la carte d'essai, et les matériaux posés par `rebuild_arena`.
var _murs: Array = []
var _mat_sol: Array = [null, null]
var _mat_decor: Array = [null, null]
var _ancien_sol := CanvasItemMaterial.new()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--captures")
	if i >= 0 and i + 1 < args.size():
		_dossier = args[i + 1]
		DirAccess.make_dir_recursive_absolute(_dossier)
	_ancien_sol.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	GameSettings.pilotage_externe = true
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# macOS bride une fenêtre au second plan au point que `frame_post_draw` cesse
	# d'être émis (remède de `photographe.gd`, repris par le prototype MB0).
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	AudioServer.set_bus_mute(0, true)
	print("=== Banc zone morte au rendu (MB3c) ===")

	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node("UI")
	var manquants := preconditions_manquantes(_ui, _main)
	if not manquants.is_empty():
		for m in manquants:
			_echouer("le banc ne peut pas démarrer — %s" % m)
		printerr("  Voir tools/test_banc.gd, qui vérifie ces appuis en headless.")
		_finir()
		return
	_ui._intended_mode = NetworkManager.GameMode.LOCAL_SPLITSCREEN
	_main._on_replay_requested()
	if not await _attendre(func(): return _main.round_active and _main.countdown_left <= 0.0, 20.0):
		_echouer("la manche n'a pas démarré")
		_finir()
		return

	# La carte d'essai, posée sous la manche lancée : même chemin que tout
	# changement de carte (`rebuild_arena`), sans dépendre du catalogue.
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string(CARTE))
	MapData.current_map_data = MapCodec.validate(json.data as Dictionary)["data"]
	_main.rebuild_arena()
	await _images(5)
	_murs = _main.murs_bas.duplicate()
	if _murs.size() != 5:
		_echouer("carte d'essai : %d murs bas au lieu de 5" % _murs.size())
		_finir()
		return
	for j in 2:
		var sol: CanvasItem = _main.arena.get_node("CustomFloor_P%d" % (j + 1))
		var decor: CanvasItem = _main.arena.get_node_or_null("ArenaDecor_P%d" % (j + 1))
		_mat_sol[j] = sol.material
		_mat_decor[j] = decor.material if decor != null else null
		_verifier("vue %d : le sol porte le shader de la zone morte" % (j + 1),
			sol.material is ShaderMaterial and (sol.material as ShaderMaterial).shader == MursBasRendu.SHADER_SOL)
	_verifier("les deux vues ont chacune leur matériau de sol", _mat_sol[0] != _mat_sol[1])
	_ui.visible = false
	_eteindre_le_bandeau()

	for j in 2:
		await _scenes("ecran_scinde", j)
	_main.vp2.get_parent().visible = false
	_main._accorder_rendu_aux_vues()
	await _images(5)
	if _verifier("vue unique : la racine rend le duel", _main._rendu_racine == true):
		await _scenes("vue_unique", 0)
	_main.vp2.get_parent().visible = true
	_main._accorder_rendu_aux_vues()
	await _images(5)

	await _noir_absolu()
	await _cout()
	_finir()


## Les appuis du banc sur le jeu — la consigne de `tools/test_banc.gd` : un outil
## qui ouvre une fenêtre n'est dans aucune suite headless, donc il se périme en
## silence ; il expose ses hypothèses pour qu'une suite les vérifie.
##
## Ce banc touche à beaucoup de choses internes (la poussée de la zone morte, le
## rendu racine, l'état des lampes et de l'éblouissement) : c'est ce qui le rend
## fragile, et ce qui rend cette liste utile.
static func preconditions_manquantes(ui: Node, main: Node) -> Array[String]:
	var absents: Array[String] = []
	if ui == null or main == null:
		absents.append("main.tscn n'expose plus UI ou GameState")
		return absents
	if not "_intended_mode" in ui:
		absents.append("UI._intended_mode a disparu")
	for prop in ["round_active", "countdown_left", "p1", "p2", "arena", "vp1", "vp2",
			"murs_bas", "_materiaux_zone_morte", "_zone_morte_vide_poussee", "_rendu_racine"]:
		if not prop in main:
			absents.append("GameState.%s a disparu" % prop)
	for methode in ["_on_replay_requested", "rebuild_arena", "_accorder_rendu_aux_vues",
			"_pousser_zone_morte"]:
		if not main.has_method(methode):
			absents.append("GameState.%s() a disparu" % methode)
	var joueur: Node = main.get("p1") if "p1" in main else null
	if joueur == null:
		absents.append("GameState.p1 n'existe pas encore après le chargement de main.tscn")
	else:
		for prop in ["flashlight", "body_light", "ambient_light", "muzzle_flash", "flashlight_on",
				"dazzle_amount", "aim_line", "accroupi", "visual", "visual_enemy", "player_id"]:
			if not prop in joueur:
				absents.append("Player.%s a disparu" % prop)
		if not joueur.has_method("poser_posture"):
			absents.append("Player.poser_posture() a disparu")
	if not ResourceLoader.exists(CARTE):
		absents.append("carte d'essai absente : %s" % CARTE)
	else:
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(CARTE)) != OK:
			absents.append("carte d'essai illisible")
		else:
			var lu: Dictionary = MapCodec.validate(json.data as Dictionary)
			var murs := MapGeometry.rects_monde(lu.get("data", {}), MapGeometry.Kind.LOW_WALLS) \
				if lu.get("ok", false) else []
			if murs.size() != 5:
				absents.append("carte d'essai : %d murs bas au lieu des 5 que les scènes supposent"
					% murs.size())
	return absents


# ─── Mise en scène ───────────────────────────────────────────────────────────

## `j` regarde : il tient la torche, debout, au nord du long mur bas ; l'autre est
## posé derrière le mur. Les joueurs ne simulent plus — rien ne doit bouger entre
## deux captures.
func _poser(j: int, cible: Vector2, cible_accroupie: bool) -> void:
	var porteur: Node2D = _joueur(j)
	var autre: Node2D = _joueur(1 - j)
	for p in [porteur, autre]:
		p.set_physics_process(false)
		p.velocity = Vector2.ZERO
		# ⚠️ Couper aussi l'INTENTION : un joueur qui a tenu la torche à la scène
		# précédente garde `flashlight_on`, et ses lampes se rallument — il est
		# alors éclairé de son côté, ce que la règle autorise à juste titre
		# (troisième passage : seule la première scène après un changement de main
		# échouait, des deux côtés).
		p.flashlight_on = false
		# ⚠️ Et l'ÉBLOUISSEMENT : à la scène précédente, celui qui regarde maintenant
		# se tenait dans la torche de l'autre. Sa vue sort floutée (`brouillage.gd`)
		# pendant qu'il récupère — capture de la règle floue, murets et corps
		# effacés, la suivante nette. Quatrième passage : c'était la vraie cause
		# des échecs « première scène après un changement de main ».
		p.dazzle_amount = 0.0
		# La ligne de visée et le viseur sont dessinés SANS lumière, droit dans
		# l'axe du porteur — donc à travers la cible. Lus au centre du corps, ils
		# passent pour un corps éclairé.
		if p.aim_line != null:
			p.aim_line.visible = false
		var viseur := p.get_node_or_null("Viseur") as CanvasItem
		if viseur != null:
			viseur.visible = false
		for lampe: Light2D in [p.flashlight, p.body_light, p.ambient_light, p.muzzle_flash]:
			lampe.enabled = false
	var mur: Rect2 = _murs[0]
	porteur.global_position = Vector2(mur.get_center().x, mur.position.y - 90.0)
	porteur.rotation = PI / 2.0
	porteur.poser_posture(false)
	porteur.flashlight_on = true
	porteur.flashlight.enabled = true
	porteur.flashlight.energy = 2.5
	autre.global_position = cible
	autre.poser_posture(cible_accroupie)
	# ⚠️ Sous la torche, le corps d'en face reste SOMBRE, liseré du côté de la
	# lampe : ses propres occluders l'ombrent (`CanauxLumiere.couche_ombre_corps`).
	# Lu en son centre, il est donc noir avec ou sans la règle — premier passage du
	# banc. On retire ses occluders le temps de la mesure : la règle n'en dépend pas.
	for occ: LightOccluder2D in autre.find_children("*", "LightOccluder2D", true, false):
		occ.visible = false


func _joueur(j: int) -> Node2D:
	return _main.p1 if j == 0 else _main.p2


## `regle` : les murs bas vont aux matériaux. `ancien` : le sol et le décor de la
## vue reprennent les matériaux d'avant MB3c.
func _mode(j: int, regle: bool, ancien: bool, murs: Array = _murs) -> void:
	_main.murs_bas = murs if regle else []
	_main._zone_morte_vide_poussee = false
	var sol: CanvasItem = _main.arena.get_node("CustomFloor_P%d" % (j + 1))
	var decor: CanvasItem = _main.arena.get_node_or_null("ArenaDecor_P%d" % (j + 1))
	sol.material = _ancien_sol if ancien else _mat_sol[j]
	if decor != null:
		decor.material = null if ancien else _mat_decor[j]


func _eteindre_le_bandeau() -> void:
	var led := _main.arena.get_node_or_null(MurLed.NOM) as Light2D
	if led != null:
		led.set_process(false)
		led.enabled = false


func _viewport(vue: String, j: int) -> Viewport:
	if vue == "vue_unique":
		return get_viewport()
	return _main.vp1 if j == 0 else _main.vp2


# ─── 1 à 3 : accord ──────────────────────────────────────────────────────────

func _scenes(vue: String, j: int) -> void:
	var mur: Rect2 = _murs[0]
	var l_acc := MursBas.longueur_zone_morte(MursBas.hauteur_mur(),
		MursBas.en_pixels(MursBas.HAUTEUR_ACCROUPI), MursBas.ANGLE_FRANCHISSEMENT)
	var x := mur.get_center().x
	var scenes := [
		["accroupi a L-12", Vector2(x, mur.end.y + l_acc - 12.0), true, false],
		["accroupi a L+12", Vector2(x, mur.end.y + l_acc + 12.0), true, true],
		["debout a L-12", Vector2(x, mur.end.y + l_acc - 12.0), false, true],
	]
	var v := _viewport(vue, j)
	var arene_xf: Transform2D = (_main.arena as Node2D).global_transform
	for scene: Array in scenes:
		_poser(j, scene[1], scene[2])
		# ⚠️ Attendre que la VUE soit posée, pas un nombre d'images : la caméra
		# rejoint le joueur téléporté en plusieurs images, et trois captures prises
		# pendant qu'elle glisse ne regardent pas le même monde (premier passage :
		# 423 points « allumés par la règle », tous dans la première scène après un
		# changement de vue).
		var ecran := await _vue_posee(v)
		# ⚠️ Et laisser la TORCHE s'établir : à sa première mise en marche après
		# avoir changé de main, son cône sort mou et élargi pendant quelques images
		# (vu sur la capture du deuxième passage : tout le cône diffère, pas la
		# seule zone morte). Ce n'est pas la règle, c'est la lampe.
		await _images(45)
		var images := {}
		for m: Array in [["regle", true, false], ["sans_regle", false, false], ["ancien", false, true]]:
			_mode(j, m[1], m[2])
			await _images(4)
			images[m[0]] = v.get_texture().get_image()
			_sauver(images[m[0]], "%s_j%d_%s_%s" % [vue, j + 1, (scene[0] as String).replace(" ", "_"), m[0]])
			var apres := v.get_final_transform() * v.get_canvas_transform()
			if not apres.is_equal_approx(ecran):
				_echouer("%s J%d « %s » : la vue a bougé pendant les captures" % [vue, j + 1, scene[0]])
			# 0,06 reste en permanence, y compris dans les scènes nettes et justes :
			# ce n'est pas la récupération qui floutait les captures (≫ 0,1).
			if float(_joueur(j).dazzle_amount) > 0.1:
				_echouer("%s J%d « %s » : capture prise ébloui (%.3f)" % [vue, j + 1, scene[0],
					_joueur(j).dazzle_amount])
		_mode(j, true, false)
		var porteur := _joueur(j)
		var src: Vector2 = arene_xf.affine_inverse() * (porteur.flashlight.global_position as Vector2)
		_accord_sol(vue, j, scene[0], images, ecran * arene_xf, src, porteur.global_position, (scene[1] as Vector2))
		_accord_corps(vue, j, scene, images, ecran * _joueur(1 - j).global_position)
		# Diagnostic du corps : ce que son matériau a reçu, et qui est allumé.
		var cible := _joueur(1 - j)
		var mat := cible.visual_enemy.material as ShaderMaterial
		var lampes := []
		for p: Node2D in [_joueur(0), _joueur(1)]:
			lampes.append("J%d[torche=%s retro=%s halo=%s flash=%s]" % [int(p.player_id) + 1,
				p.flashlight.enabled, p.body_light.enabled, p.ambient_light.enabled, p.muzzle_flash.enabled])
		# Ce qui est VRAIMENT dessiné de la cible dans cette vue : tout CanvasItem
		# visible dont la couche est vue par ce viewport et que la torche éclaire.
		var masque_vue: int = v.canvas_cull_mask
		for n: Node in cible.find_children("*", "CanvasItem", true, false):
			var ci := n as CanvasItem
			if not ci.is_visible_in_tree() or (ci.visibility_layer & masque_vue) == 0:
				continue
			var m := ci.material
			var nom_shader := "aucun"
			if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
				nom_shader = (m as ShaderMaterial).shader.resource_path.get_file()
			elif m != null:
				nom_shader = m.get_class()
			print("DIAG_NOEUD vue=%s joueur=%d scene=« %s » %s (%s) couche=%d lumiere=%d parent_mat=%s materiau=%s partage_visual=%s" % [
				vue, j + 1, scene[0], cible.get_path_to(ci), ci.get_class(), ci.visibility_layer,
				ci.light_mask, ci.use_parent_material, nom_shader, m != null and m == cible.visual.material])
		print("DIAG_CLASSES J1=%s J2=%s" % [_joueur(0).current_weapon.name, _joueur(1).current_weapon.name])
		print("DIAG_CORPS vue=%s joueur=%d scene=« %s » cible_accroupie=%s zone=%.1f au_centre=%s centre=%s attendu=%s nb=%d %s" % [
			vue, j + 1, scene[0], cible.accroupi, mat.get_shader_parameter("mb_zone_morte"),
			mat.get_shader_parameter("mb_au_centre"), mat.get_shader_parameter("mb_centre"),
			(ecran * cible.global_position).round(), mat.get_shader_parameter("mb_nb_murs"), " ".join(lampes)])


func _accord_sol(vue: String, j: int, nom: String, images: Dictionary, xf: Transform2D,
		src: Vector2, pos_porteur: Vector2, pos_cible: Vector2) -> void:
	var A: Image = images["regle"]
	var B: Image = images["sans_regle"]
	var C: Image = images["ancien"]
	var h_mur := MursBas.hauteur_mur()
	var h_src := MursBas.hauteur_de_posture(false)
	var rentres := []
	for r: Rect2 in _murs:
		rentres.append(r.grow(-MapGeometry.OCCLUDER_INSET))
	var jeu := Rect2(105, 105, 910, 910).grow(-6.0)
	var total := 0
	var bons := 0
	var noircis := 0
	var ajoutes := 0
	var ecart_ancien := 0
	var ecarts := []
	var y := src.y - PORTEE
	while y <= src.y + PORTEE:
		var xx := src.x - PORTEE
		while xx <= src.x + PORTEE:
			var pt := Vector2(xx, y)
			xx += PAS
			if pt.distance_to(src) > PORTEE or not jeu.has_point(pt):
				continue
			if pt.distance_to(pos_porteur) < 34.0 or pt.distance_to(pos_cible) < 34.0:
				continue
			# La ligne de visée pointillée du porteur est dessinée sans lumière : elle
			# se lit « éclairée » partout, zone morte comprise. Le porteur vise plein
			# sud, droit sur son axe.
			if absf(pt.x - pos_porteur.x) < 5.0 and pt.y > pos_porteur.y:
				continue
			var pres := false
			for r: Rect2 in _murs:
				pres = pres or r.grow(6.0).has_point(pt)
			if pres:
				continue
			var e := xf * pt
			if e.x < 2 or e.y < 2 or e.x > A.get_width() - 3 or e.y > A.get_height() - 3:
				continue
			var verite := MursBas.franchit(src, pt, h_src, 0.0, rentres, h_mur, MursBas.ANGLE_FRANCHISSEMENT)
			var stable := true
			for d: Vector2 in [Vector2(5, 0), Vector2(-5, 0), Vector2(0, 5), Vector2(0, -5)]:
				stable = stable and MursBas.franchit(src, pt + d, h_src, 0.0, rentres, h_mur,
					MursBas.ANGLE_FRANCHISSEMENT) == verite
			if not stable:
				continue
			var lu_a := _allume(A, e)
			if not _allume(B, e):
				if lu_a:
					ajoutes += 1
				continue
			total += 1
			if not verite:
				noircis += 1
			if lu_a == verite:
				bons += 1
			elif ecarts.size() < 6:
				ecarts.append("%s attendu=%s lu=%s" % [pt.round(), verite, lu_a])
			if verite:
				ecart_ancien = maxi(ecart_ancien, _ecart(A, C, e))
		y += PAS
	print("ACCORD_SOL vue=%s joueur=%d scene=« %s » sol=%d/%d zone_morte=%d allumes_par_la_regle=%d ecart_ancien=%d/255" % [
		vue, j + 1, nom, bons, total, noircis, ajoutes, ecart_ancien])
	for t in ecarts:
		print("  ECART ", t)
	_verifier("%s J%d « %s » : le sol suit la règle" % [vue, j + 1, nom], total > 200 and bons == total)
	_verifier("%s J%d « %s » : la scène exerce la zone morte (> 20 points)" % [vue, j + 1, nom], noircis > 20)
	_verifier("%s J%d « %s » : la règle n'allume rien" % [vue, j + 1, nom], ajoutes == 0)
	_verifier("%s J%d « %s » : hors zone, l'ancien pixel (≤ %d/255)" % [vue, j + 1, nom, ECART_ANCIEN_MAX],
		ecart_ancien <= ECART_ANCIEN_MAX)


func _accord_corps(vue: String, j: int, scene: Array, images: Dictionary, centre: Vector2) -> void:
	var attendu: bool = scene[3]
	var sans_regle := _max_autour(images["sans_regle"], centre, 2) > SEUIL
	var lu := _max_autour(images["regle"], centre, 2) > SEUIL
	print("ACCORD_CORPS vue=%s joueur=%d scene=« %s » sans_regle=%s regle=%s attendu=%s" % [
		vue, j + 1, scene[0], sans_regle, lu, attendu])
	_verifier("%s J%d « %s » : éclairé sans la règle (scène bien posée)" % [vue, j + 1, scene[0]], sans_regle)
	_verifier("%s J%d « %s » : corps %s" % [vue, j + 1, scene[0], "éclairé" if attendu else "noir"], lu == attendu)


# ─── 4 : noir absolu ─────────────────────────────────────────────────────────

func _noir_absolu() -> void:
	_poser(0, (_murs[0] as Rect2).end + Vector2(-80, 30), true)
	_main.p1.flashlight_on = false
	_main.p1.flashlight.enabled = false
	for j in 2:
		var v := _viewport("ecran_scinde", j)
		await _vue_posee(v)
		# Règle, ancien, règle encore : ce qui bouge seul d'une capture à l'autre
		# (poussière, traces qui s'effacent) ne doit pas passer pour un effet de la
		# règle. Premier passage : vue 2 à 119 contre 75, sans ce témoin.
		var mesures := []
		for m: Array in [["regle", true, false], ["ancien", false, true], ["regle_bis", true, false]]:
			_mode(j, m[1], m[2])
			await _images(6)
			var img := v.get_texture().get_image()
			_sauver(img, "noir_vue%d_%s" % [j + 1, m[0]])
			mesures.append([m[0], _valeur_max(img), _position_du_max(img)])
		_mode(j, true, false)
		var avec: int = mini(mesures[0][1], mesures[2][1])
		var avant: int = mesures[1][1]
		print("NOIR_ABSOLU vue=%d %s" % [j + 1, " ".join(mesures.map(func(e): return "%s=%d/255@%s" % e))])
		_verifier("vue %d : toutes lumières éteintes, rien de plus clair qu'avant" % (j + 1), avec <= avant)


# ─── 5 : coût ────────────────────────────────────────────────────────────────

func _cout() -> void:
	var mur: Rect2 = _murs[0]
	_poser(0, Vector2(mur.get_center().x, mur.end.y + 30.0), true)
	var quarante := _murs.duplicate()
	for k in 35:
		quarante.append(Rect2(300.0 + (k % 7) * 110.0, 420.0 + (k / 7) * 60.0, 35.0, 35.0))
	var rid: RID = _main.vp1.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	print("COUT fenetre=%s focus=%s (ordre de grandeur, pas un relevé au protocole)" % [
		DisplayServer.window_get_size(), "premier_plan" if get_window().has_focus() else "second_plan"])
	var configs := [["ancien", false, true, []], ["regle_0_mur", true, false, []],
			["regle_carte_5", true, false, _murs], ["regle_40_murs", true, false, quarante]]
	# Trois tours ENTRELACÉS, et la médiane des tours : premier passage, un seul
	# tour dans l'ordre, les 40 murs ont valu 6,3 puis 8,8 ms d'une exécution à
	# l'autre — la machine qui chauffe se lit comme un coût de la config suivante.
	var medianes := {}
	var appels_par_config := {}
	for tour in 3:
		for config: Array in configs:
			for j in 2:
				_mode(j, config[1], config[2], config[3])
			await _images(30)
			var durees := PackedFloat32Array()
			var appels := []
			var debut := Time.get_ticks_usec()
			for k in 360:
				await RenderingServer.frame_post_draw
				var maintenant := Time.get_ticks_usec()
				durees.append(float(maintenant - debut) / 1e6)
				debut = maintenant
				appels.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			appels.sort()
			var st: Dictionary = Conditions.statistiques(durees)
			medianes.get_or_add(config[0], []).append(1000.0 / maxf(0.001, st["fps_median"]))
			appels_par_config[config[0]] = appels[appels.size() / 2]
	for config: Array in configs:
		var tours: Array = medianes[config[0]]
		tours.sort()
		print("COUT config=%s murs_envoyes=%d appels=%d image_mediane=%.2f ms (tours %s)" % [
			config[0], (config[3] as Array).size() if config[1] else 0, appels_par_config[config[0]],
			tours[1], ", ".join(tours.map(func(t): return "%.2f" % t))])
	var t0 := Time.get_ticks_usec()
	for k in 1000:
		_main._pousser_zone_morte()
	print("COUT poussee_uniformes=%.1f µs par image (40 murs, deux vues, six matériaux)" % [
		float(Time.get_ticks_usec() - t0) / 1000.0])
	for j in 2:
		_mode(j, true, false)


# ─── Outils ──────────────────────────────────────────────────────────────────

func _images(n: int) -> void:
	for k in n:
		await RenderingServer.frame_post_draw


## Attend que la transformation écran de `v` ne bouge plus d'une image à l'autre
## (au plus 3 s), et la rend.
func _vue_posee(v: Viewport) -> Transform2D:
	var avant := v.get_final_transform() * v.get_canvas_transform()
	var stables := 0
	var fin := Time.get_ticks_msec() + 3000
	while stables < 5 and Time.get_ticks_msec() < fin:
		await RenderingServer.frame_post_draw
		var maintenant := v.get_final_transform() * v.get_canvas_transform()
		stables = stables + 1 if maintenant.is_equal_approx(avant) else 0
		avant = maintenant
	return avant


static func _position_du_max(img: Image) -> Vector2i:
	var rgb := img.duplicate() as Image
	rgb.convert(Image.FORMAT_RGB8)
	var octets := rgb.get_data()
	var meilleur := 0
	var indice := 0
	for k in octets.size():
		if octets[k] > meilleur:
			meilleur = octets[k]
			indice = k
	var pixel := indice / 3
	return Vector2i(pixel % rgb.get_width(), pixel / rgb.get_width())


func _attendre(condition: Callable, delai: float) -> bool:
	var fin := Time.get_ticks_msec() + int(delai * 1000.0)
	while Time.get_ticks_msec() < fin:
		if condition.call():
			return true
		await get_tree().process_frame
	return false


static func _allume(img: Image, p: Vector2) -> bool:
	var c := img.get_pixel(int(p.x), int(p.y))
	return maxf(c.r, maxf(c.g, c.b)) > SEUIL


static func _ecart(a: Image, b: Image, p: Vector2) -> int:
	var ca := a.get_pixel(int(p.x), int(p.y))
	var cb := b.get_pixel(int(p.x), int(p.y))
	return roundi(255.0 * maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))))


static func _max_autour(img: Image, p: Vector2, rayon: int) -> float:
	var m := 0.0
	for dy in range(-rayon, rayon + 1):
		for dx in range(-rayon, rayon + 1):
			var x := clampi(int(p.x) + dx, 0, img.get_width() - 1)
			var y := clampi(int(p.y) + dy, 0, img.get_height() - 1)
			var c := img.get_pixel(x, y)
			m = maxf(m, maxf(c.r, maxf(c.g, c.b)))
	return m


## Valeur maximale sur R, G, B, en 0-255 — même méthode que le prototype : une
## égalité d'octets tranche le cas attendu, la boucle lente ne chiffre qu'un écart.
static func _valeur_max(img: Image) -> int:
	var rgb := img.duplicate() as Image
	rgb.convert(Image.FORMAT_RGB8)
	var octets := rgb.get_data()
	var zeros := PackedByteArray()
	zeros.resize(octets.size())
	if octets == zeros:
		return 0
	var m := 0
	for o in octets:
		m = maxi(m, o)
	return m


func _sauver(img: Image, nom: String) -> void:
	if _dossier != "":
		img.save_png(_dossier.path_join(nom + ".png"))


func _verifier(libelle: String, condition: bool) -> bool:
	if condition:
		print("  ✓ ", libelle)
	else:
		_echecs += 1
		printerr("  ✗ ", libelle)
	return condition


func _echouer(raison: String) -> void:
	_echecs += 1
	printerr("  ✗ ", raison)


func _finir() -> void:
	print("BANC_MURS_BAS VERDICT=%s echecs=%d" % ["OK" if _echecs == 0 else "ECHEC", _echecs])
	get_tree().quit(0 if _echecs == 0 else 1)
