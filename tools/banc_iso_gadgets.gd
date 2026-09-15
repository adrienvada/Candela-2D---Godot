## Banc des gadgets et des lumières en iso — FENÊTRÉ (Gadgets et lumières, étape 6).
##
## Ce que `tools/test_iso_gadgets.gd` ne peut pas dire en headless, parce que rien n'y est rastérisé :
##
##   1. LA HAUTEUR AU PIXEL — une lampe d'essai posée à D = 2 tuiles de la face de sortie d'un muret, à
##      0,05, 0,70 puis 1,50 tuile : dans la LIGHTMAP de chaque joueur, le sol derrière le muret se rallume
##      là où `MursBasRendu.eclaire_par_hauteur` le dit — à 2 px près, 2,67 tuiles pour 0,70, 0,73 pour
##      1,50, jamais pour 0,05. Seuls comptent les points que la même lampe éclaire SANS aucune règle (hauteur
##      « sans origine », bit des murets retiré) : un mur haut ou le bord de la lampe ne passent pas pour une
##      zone morte. J1 et J2 doivent mesurer la même fin de zone.
##   2. LES SCÈNES DE LA PLANCHE DES HAUTEURS — une fusée en vol puis posée derrière le même muret, une
##      torche de joueur derrière lui ; les deux vues ; les appels de dessin, images coupées puis rendues.
##   3. LES GADGETS — chacun posé par le vrai chemin sous la torche de J1 réglée à 0,8, capturé dans la vue
##      iso ; puis toutes lumières éteintes et la 2D coupée (`canvas_cull_mask = 0`) : l'écran doit valoir
##      0 — les volumes, les lueurs et la toile n'allument rien par eux-mêmes (le contrôle (b) du noir
##      absolu d'ISO1). La valeur lumières éteintes SANS couper la 2D est relevée pour information : les
##      dessins lumineux du jeu (nappe de braises, lentille, traces de poudre) y brillent par dessein.
##
## Relevés : lignes `BANC_ISO_GADGETS …` ; captures dans `--captures <dossier>` (défaut
## `docs/iso/captures_gadgets/`), lues par `docs/iso/planche_iso_gadgets.py`.
##
## Lancer (foyer isolé, chien de garde — voir la ROADMAP, section « Gadgets et lumières en iso ») :
##   HOME=<dossier temporaire> godot --path . res://tools/banc_iso_gadgets.tscn -- [--captures <dossier>]
extends Node

const CARTE := "res://tools/cartes/murs_bas_essai.json"
## Seuil « éclairé », celui du banc des murs bas et du prototype MB0.
const SEUIL := 10.0 / 255.0
const HAUTEURS := [0.05, 0.70, 1.50]
const TOLERANCE_PX := 2.0
const SLUGS := ["mine_magnesium", "ombre_habitee", "torche_fantome", "voile", "gresillement", "leurre",
	"cartouche_suie", "poussiere", "nappe_braises", "poudre_contact"]

var _main: Node
var _ui: Node
var _iso: Node
var _dossier := ""
var _echecs := 0
var _murs: Array = []
var _lampe: PointLight2D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--captures")
	_dossier = args[i + 1] if i >= 0 and i + 1 < args.size() \
		else ProjectSettings.globalize_path("res://docs/iso/captures_gadgets")
	DirAccess.make_dir_recursive_absolute(_dossier)
	# Pour cette exécution seulement : rien ne s'écrit dans settings.cfg, et l'intro ne joue pas par-dessus
	# le duel (piège « un foyer isolé est un joueur neuf »).
	GameSettings.pilotage_externe = true
	GameSettings.intro_vue = true
	GameSettings.mode_iso = true
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	AudioServer.set_bus_mute(0, true)
	print("=== Banc des gadgets et des lumières en iso ===")

	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node("UI")
	_ui._intended_mode = NetworkManager.GameMode.LOCAL_SPLITSCREEN
	_main._on_replay_requested()
	if not await _attendre(func(): return _main.round_active and _main.countdown_left <= 0.0, 20.0):
		_echouer("la manche n'a pas démarré")
		_finir()
		return
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string(CARTE))
	MapData.current_map_data = MapCodec.validate(json.data as Dictionary)["data"]
	_main.rebuild_arena()
	await _images(5)
	_murs = (_main.murs_bas as Array).duplicate()
	if not await _attendre(func() -> bool:
			var p := Presentation3D.instance()
			return p != null and bool(p.get("_actif")) and bool(p.get("_scinde")), 8.0):
		_echouer("la vue iso ne s'est pas allumée en écran scindé")
		_finir()
		return
	_iso = Presentation3D.instance()
	if _murs.size() != 5:
		_echouer("carte d'essai : %d murs bas au lieu de 5" % _murs.size())
		_finir()
		return
	_ui.visible = false
	_preparer_les_joueurs()
	_lampe = _nouvelle_lampe()
	await _hauteurs()
	await _scenes_des_hauteurs()
	await _gadgets()
	_finir()


# ─── 1 : la hauteur au pixel ──────────────────────────────────────────────────

func _hauteurs() -> void:
	var T := MursBas.TUILE
	var rentre := (_murs[0] as Rect2).grow(-MursBas.RETRAIT_LUMIERE)
	var source := Vector2(rentre.get_center().x, rentre.end.y - 2.0 * T)
	_lampe.global_position = source
	_lampe.enabled = true
	var formes := MursBas.forme_de_lumiere(_murs)
	var colonnes := [-8.0, 0.0, 8.0]
	# ⚠️ Chaque caméra suit SON joueur : écartés du muret, aucune des deux vues ne le cadrait (premier passage :
	# 0 point témoin dans la lightmap de J1). Les deux joueurs se tiennent donc derrière la lampe, du côté
	# opposé au muret : leurs corps ne coupent aucun rayon mesuré.
	_main.p1.global_position = source + Vector2(-50.0, -70.0)
	_main.p2.global_position = source + Vector2(50.0, -70.0)
	# Le témoin : la même lampe, sans aucune règle des murets.
	_lampe.height = MursBasRendu.HAUTEUR_SANS_ORIGINE
	_lampe.shadow_item_cull_mask = CanauxLumiere.masque_ombre_posture(_lampe.shadow_item_cull_mask, false)
	await _images(12)
	var temoins := [_lightmap(0), _lightmap(1)]
	var mesures := {}
	for h: float in HAUTEURS:
		MursBasRendu.poser_hauteur_source(_lampe, h)
		await _images(12)
		var attendue := MursBasRendu.zone_morte_source(2.0 * T, MursBas.en_pixels(h), MursBas.hauteur_mur(), 0.0)
		_sauver(get_viewport().get_texture().get_image(), "hauteur_%03d_ecran" % roundi(h * 100.0))
		for j in 2:
			var v: SubViewport = _main.vp1 if j == 0 else _main.vp2
			var img := _lightmap(j)
			_sauver(img, "hauteur_%03d_lightmap_j%d" % [roundi(h * 100.0), j + 1])
			var xf: Transform2D = v.get_final_transform() * v.get_canvas_transform()
			var fin_centre := INF
			var desaccords := 0
			var points := 0
			for dx: float in colonnes:
				var fin_mesuree := INF
				var fin_attendue := INF
				# ⚠️ Pas depuis la face de sortie : un point posé SUR la face n'est pas « derrière » le muret, la
				# jumelle le dit éclairé et la « fin de zone » tombait à 0 (premier passage). Et pas dans les
				# `RETRAIT_LUMIERE` premiers pixels : la face mesurée est celle du muret RENTRÉ, la tuile dessinée
				# déborde de 3 px derrière elle, et la lampe l'éclaire — deuxième passage, « zone de 3 px » dans
				# les deux lightmaps, 3 désaccords sur 834, tous sur la tuile. La fin de la zone est le premier
				# point de SOL éclairé derrière elle.
				for s in range(int(MursBas.RETRAIT_LUMIERE) + 2, int(8.0 * T)):
					var pt := Vector2(source.x + dx, rentre.end.y + float(s))
					var ecran: Vector2 = xf * pt
					if not Rect2(Vector2.ZERO, Vector2(img.get_size())).has_point(ecran):
						continue
					if not _allume(temoins[j], ecran):
						continue
					points += 1
					var vu := _allume(img, ecran)
					var voulu := MursBasRendu.eclaire_par_hauteur(source, pt, MursBas.en_pixels(h), 0.0, formes,
						MursBas.hauteur_mur())
					if vu and is_inf(fin_mesuree):
						fin_mesuree = float(s)
					if voulu and is_inf(fin_attendue):
						fin_attendue = float(s)
					if vu != voulu and absf(float(s) - fin_attendue if not is_inf(fin_attendue) else INF) > TOLERANCE_PX \
							and absf(float(s) - fin_mesuree if not is_inf(fin_mesuree) else INF) > TOLERANCE_PX:
						desaccords += 1
				if dx == 0.0:
					fin_centre = fin_mesuree
					var juste := (is_inf(fin_attendue) and is_inf(fin_mesuree)) \
						or absf(fin_mesuree - fin_attendue) <= TOLERANCE_PX
					print("BANC_ISO_GADGETS hauteur=%.2f vue=J%d zone_attendue=%s zone_mesuree=%s (px de monde derrière la face de sortie)" % [
						h, j + 1, _px(fin_attendue), _px(fin_mesuree)])
					_verifier("hauteur %.2f, lightmap de J%d : zone morte de %s mesurée, %s attendue (± %d px)" % [
						h, j + 1, _px(fin_mesuree), _px(attendue), int(TOLERANCE_PX)], juste)
			print("BANC_ISO_GADGETS hauteur=%.2f vue=J%d desaccords=%d points_temoin=%d" % [h, j + 1, desaccords, points])
			_verifier("hauteur %.2f, lightmap de J%d : chaque point éclairé par le témoin suit la règle (%d désaccords sur %d)" % [
				h, j + 1, desaccords, points], desaccords == 0 and points > 100)
			mesures[[h, j]] = fin_centre
		var m1: float = mesures[[h, 0]]
		var m2: float = mesures[[h, 1]]
		_verifier("hauteur %.2f : J1 et J2 mesurent la même zone morte (%s / %s)" % [h, _px(m1), _px(m2)],
			(is_inf(m1) and is_inf(m2)) or absf(m1 - m2) <= 1.0)
	_lampe.enabled = false


# ─── 2 : les scènes de la planche des hauteurs ────────────────────────────────

func _scenes_des_hauteurs() -> void:
	var T := MursBas.TUILE
	var rentre := (_murs[0] as Rect2).grow(-MursBas.RETRAIT_LUMIERE)
	var source := Vector2(rentre.get_center().x, rentre.end.y - 2.0 * T)
	var volumes: IsoVolumes = (_iso.get("_miroirs") as Node).get("volumes")
	var f: Node2D = (load("res://fusee.gd") as GDScript).new()
	f.set("depart", source)
	f.set("direction", Vector2.DOWN)
	f.set("joueurs", [_main.p1, _main.p2])
	_main.bullet_container.add_child(f)
	await get_tree().process_frame
	# Figée en vol à 1,2 tuile : la comète au-dessus du muret, sa zone morte courte derrière lui.
	f.set_physics_process(false)
	f.global_position = source
	MursBasRendu.poser_hauteur_source(f.get_node("Halo") as Light2D, 1.2)
	await _images(12)
	_sauver(get_viewport().get_texture().get_image(), "scene_fusee_vol")
	print("BANC_ISO_GADGETS scene=fusee_vol hauteur=%.2f" % float(f.call("hauteur_source")))
	f.call("forcer_age", 1.0)
	await _images(20)
	_sauver(get_viewport().get_texture().get_image(), "scene_fusee_sol")
	print("BANC_ISO_GADGETS scene=fusee_sol hauteur=%.2f" % float(f.call("hauteur_source")))
	# Le coût des images : appels de dessin, images coupées puis rendues, sur la fusée posée.
	volumes.images_actives = false
	await _images(10)
	var sans := await _appels()
	volumes.images_actives = true
	await _images(10)
	var avec := await _appels()
	print("BANC_ISO_GADGETS appels fusee_sol sans_images=%d avec_images=%d" % [sans, avec])
	f.queue_free()
	await _images(5)
	var p := _main.p1 as Node2D
	p.global_position = source - Vector2(0.0, 30.0)
	p.rotation = PI / 2.0
	p.set("flashlight_on", true)
	(p.get("flashlight") as Light2D).enabled = true
	(p.get("flashlight") as Light2D).energy = 2.5
	await _images(45)
	_sauver(get_viewport().get_texture().get_image(), "scene_torche")
	print("BANC_ISO_GADGETS scene=torche regle=jeu (bande constante d'ISO3b)")
	p.set("flashlight_on", false)
	(p.get("flashlight") as Light2D).enabled = false


# ─── 3 : les gadgets, sous lampe et dans le noir ──────────────────────────────

func _gadgets() -> void:
	var T := MursBas.TUILE
	var miroirs: Node = _iso.get("_miroirs")
	var rentre := (_murs[0] as Rect2).grow(-MursBas.RETRAIT_LUMIERE)
	# ⚠️ AU SUD du muret, sur le sol dégagé de la carte d'essai. Le premier passage posait le gadget trois
	# tuiles au nord et la torche 150 px plus au nord encore : contre le mur du haut, sa lumière n'atteignait
	# rien, et huit vignettes sur dix ne montraient que le viseur (planche du 2026-09-15, 07:26).
	var lieu := Vector2(rentre.get_center().x, rentre.end.y + 5.0 * T)
	var p := _main.p1 as Node2D
	for k in SLUGS.size():
		var slug: String = SLUGS[k]
		var avant: Array = _main.bullet_container.get_children()
		# Posé par J2 : la torche de J1 l'éclaire, et un joueur n'a qu'un gadget à la fois.
		_main._do_spawn_gadget(1, lieu, 0.0, slug, 9400 + k)
		await get_tree().create_timer(1.4).timeout
		var g: Node2D = null
		for n in _main.bullet_container.get_children():
			if not avant.has(n) and "slug" in n and String(n.get("slug")) == slug:
				g = n
		if not _verifier("« %s » posé par le vrai chemin" % slug, g != null):
			continue
		# Sous la lampe : la torche de J1 à 0,8, braquée sur le gadget.
		p.global_position = lieu + Vector2(0.0, -110.0)
		p.rotation = PI / 2.0
		p.set("flashlight_on", true)
		(p.get("flashlight") as Light2D).enabled = true
		(p.get("flashlight") as Light2D).energy = 0.8
		# La torche seule : le bandeau LED et toute autre lumière restent éteints (la torche voulue est gardée).
		for n in 30:
			_eteindre_tout()
			await RenderingServer.frame_post_draw
		var lampe := get_viewport().get_texture().get_image()
		_sauver(_recadrer(lampe, lieu, 0), "gadget_%s_lampe" % slug)
		# Le noir : toutes les lumières éteintes, tenues éteintes jusqu'à la mesure.
		p.set("flashlight_on", false)
		miroirs.call("masquer_les_quads", true)
		# ⚠️ Les corps sortent de la mesure : la silhouette de soi (ISO2b) reste visible dans le noir, par
		# dessein, et valait 125/255 dans chaque cadre au premier passage — le contrôle (b) d'ISO1 l'écarte
		# de même. On mesure ce que les GADGETS dessinent, dans le cadre du gadget.
		for j in [_main.p1, _main.p2]:
			(j.get("visual") as CanvasItem).visible = false
		for n in 12:
			_eteindre_tout()
			await RenderingServer.frame_post_draw
		var noir_a := _valeur_max(_recadrer(get_viewport().get_texture().get_image(), lieu, 0))
		var masques := [_main.vp1.canvas_cull_mask, _main.vp2.canvas_cull_mask]
		_main.vp1.canvas_cull_mask = 0
		_main.vp2.canvas_cull_mask = 0
		for n in 8:
			_eteindre_tout()
			await RenderingServer.frame_post_draw
		var noir := _recadrer(get_viewport().get_texture().get_image(), lieu, 0)
		var noir_b := _valeur_max(noir)
		_sauver(noir, "gadget_%s_noir" % slug)
		_main.vp1.canvas_cull_mask = masques[0]
		_main.vp2.canvas_cull_mask = masques[1]
		miroirs.call("masquer_les_quads", false)
		for j in [_main.p1, _main.p2]:
			(j.get("visual") as CanvasItem).visible = true
		print("BANC_ISO_GADGETS gadget=%s lampe_max=%d noir_lumieres_eteintes=%d noir_sans_2d=%d" % [
			slug, _valeur_max(_recadrer(lampe, lieu, 0)), noir_a, noir_b])
		_verifier("« %s » : lumières éteintes et 2D coupée, l'écran vaut 0 (%d/255)" % [slug, noir_b], noir_b == 0)


# ─── Outils ──────────────────────────────────────────────────────────────────

func _preparer_les_joueurs() -> void:
	for p: Node2D in [_main.p1, _main.p2]:
		p.set_physics_process(false)
		p.set("velocity", Vector2.ZERO)
		p.set("flashlight_on", false)
		p.set("dazzle_amount", 0.0)
		for nom in ["flashlight", "body_light", "ambient_light", "muzzle_flash"]:
			(p.get(nom) as Light2D).enabled = false
	# Loin du muret d'essai : aucun corps dans les mesures.
	var mur: Rect2 = _murs[0]
	_main.p1.global_position = mur.position + Vector2(-400.0, -300.0)
	_main.p2.global_position = mur.position + Vector2(400.0, -300.0)
	_eteindre_tout()


func _nouvelle_lampe() -> PointLight2D:
	var l := PointLight2D.new()
	l.name = "LampeDuBanc"
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.85, Color.WHITE)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	l.texture = t
	l.texture_scale = 1000.0 / 256.0
	l.energy = 1.0
	l.shadow_enabled = true
	l.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	l.shadow_item_cull_mask = 1
	l.range_item_cull_mask = 1 | 2 | 4
	l.enabled = false
	_main.arena.add_child(l)
	return l


## Toutes les lumières du duel éteintes, sauf la lampe du banc et la torche de J1 quand elles sont voulues —
## le bandeau LED compris, que le jeu rallume (piège d'ISO2).
func _eteindre_tout() -> void:
	var torche_voulue := bool(_main.p1.get("flashlight_on"))
	for n in _main.find_children("*", "Light2D", true, false):
		if n == _lampe and _lampe.enabled:
			continue
		if torche_voulue and n == _main.p1.get("flashlight"):
			continue
		(n as Light2D).enabled = false
		if (n as Node).name == MurLed.NOM:
			(n as Node).set_process(false)


func _lightmap(j: int) -> Image:
	return (_main.vp1 if j == 0 else _main.vp2).get_texture().get_image()


## Une région de l'écran autour d'un point du monde, dans la vue iso de `pid` (écran scindé).
func _recadrer(img: Image, monde: Vector2, pid: int) -> Image:
	var projeter: Callable = _iso.call("projecteur_ecran", pid)
	var affichages: Array = _iso.get("_affichages")
	if not projeter.is_valid() or affichages.size() <= pid:
		return img
	var cadre := (affichages[pid] as Control).get_global_rect()
	var vue := _iso.call("viewport_ecran", pid) as Viewport
	var logique: Vector2 = projeter.call(monde)
	var echelle_vue := cadre.size / vue.get_visible_rect().size
	var fenetre := get_viewport().get_visible_rect().size
	var px := Vector2(img.get_size()) / fenetre
	var centre := (cadre.position + logique * echelle_vue) * px
	var cote := 320.0 * px.x
	var r := Rect2i(Vector2i((centre - Vector2(cote, cote) * 0.5).round()), Vector2i(roundi(cote), roundi(cote)))
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	return img.get_region(r) if r.has_area() else img


func _appels() -> int:
	var valeurs := []
	for k in 30:
		await RenderingServer.frame_post_draw
		valeurs.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	valeurs.sort()
	return valeurs[valeurs.size() / 2]


func _images(n: int) -> void:
	for k in n:
		await RenderingServer.frame_post_draw


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


static func _valeur_max(img: Image) -> int:
	var rgb := img.duplicate() as Image
	rgb.convert(Image.FORMAT_RGB8)
	var m := 0
	for o in rgb.get_data():
		m = maxi(m, o)
	return m


static func _px(v: float) -> String:
	return "infinie" if is_inf(v) else "%.0f px (%.2f tuile)" % [v, v / MursBas.TUILE]


func _sauver(img: Image, nom: String) -> void:
	if _dossier != "" and img != null:
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
	print("BANC_ISO_GADGETS VERDICT=%s echecs=%d" % ["OK" if _echecs == 0 else "ECHEC", _echecs])
	GameSettings.mode_iso = false
	get_tree().quit(0 if _echecs == 0 else 1)
