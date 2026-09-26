extends "res://tools/photographe.gd"

## LE BUDGET DE RENDU — l'outil de comptage de la session cloud « budget » (2026-09-27).
##
## Il ne mesure PAS la cadence : sous Xvfb et llvmpipe (le conteneur du cloud), le jeu tourne à quelques images par seconde et
## aucun temps n'y vaut rien. Il COMPTE ce que le moteur soumet, image par image, et qui ne dépend pas du GPU :
##   - au total (`RenderingServer.get_rendering_info`) : appels de dessin, primitives, objets ; mémoire vidéo, textures, tampons ;
##   - PAR VUE (`Viewport.get_render_info`, la racine et chaque `SubViewport`), en trois passes : visible (3D), ombres (3D),
##     canevas (2D) — mais seulement pour les vues qui ont RENDU à cette image (voir `_vue_rendue`) ;
##   - les passes que les compteurs ne voient pas : les sous-vues actives, les objets visibles dont le shader DÉCLARE la texture
##     d'écran ou de profondeur (chacun fait copier l'écran, qu'il la lise ou non — ROADMAP, « Pièges connus », 2026-09-15),
##     les `BackBufferCopy` visibles, les lumières 2D et 3D allumées et celles qui portent une ombre (la passe d'ombre d'une
##     lumière 2D n'entre pas dans le compteur d'appels — `bench_framerate.gd`, `--fusee-sans-ombre2d`).
##
## Il hérite du photographe (fenêtre, manche locale, marionnettes, vue unique / écran scindé) sans le modifier. Chaque
## configuration à comparer est un LANCEMENT (ses drapeaux se lisent au démarrage : `--corps-detaille`, `--tuyaux-essai`…) ;
## `run_budget.sh` les enchaîne et `synthese.py` monte les tableaux.
##
## Deux familles de scènes (`--scenes=cartes,pompe`, les deux par défaut) :
##   - `cartes` : sur chacune des six cartes livrées, J1 à son point d'apparition, J2 à 260 px (l'écart du duel du photographe)
##     dans le premier cap libre vers le point d'apparition de J2, les deux torches allumées, chacun visant l'autre ; relevé
##     en vue unique puis en écran scindé. Immobiles, sans tir : le décor, les corps, les lumières.
##   - `pompe` : le cas le plus lourd connu, la mise en scène de `bench_framerate.gd --fusee` : les deux joueurs au POMPE
##     (`--classe=`), à 150 px, qui se tirent dessus sans fin, une fusée en pleine braise entre eux, son âge entretenu ; sur
##     la carte de la séance (celle que le banc de cadence joue), vue unique puis écran scindé.
##
##     GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" \
##         godot --path . res://tools/cloud_budget/budget.tscn -- --no-eos --lacet=45 --config=base [drapeaux…]
##
## Chaque relevé sort sur une ligne `BUDGET\t{json}` ; rien d'autre ne se lit par machine.

const CARTES_LIVREES: Array[String] = [
	"res://assets/maps/default.json",
	"res://assets/maps/map_001_le_cloitre.json",
	"res://assets/maps/map_002_l_usine.json",
	"res://assets/maps/map_003_la_croisee.json",
	"res://assets/maps/map_004_le_bunker.json",
	"res://assets/maps/arene_circulaire.json",
]
## Images de chauffe avant chaque relevé (le changement de carte ou de vue recompile, réalloue, retaille), puis images
## relevées. Les compteurs d'une scène immobile ne bougent presque pas : 12 suffisent à voir min et max.
const CHAUFFE := 20
const IMAGES := 12
## La mise en scène du pompe, celle du banc de cadence (`bench_framerate.gd`, `DUEL_DISTANCE`).
const DUEL_POMPE := 150.0

var _config := "sans-nom"
var _classe_cartes := "pistolet"
var _classe_pompe := "pompe"
var _scenes: Array[String] = ["cartes", "pompe"]
var _images := IMAGES
var _lacet_joue := 0.0
var _j1 := Vector2.ZERO
var _j2 := Vector2.ZERO
var _fusee: Fusee = null
var _pompe_actif := false
var _age := 0.0
## Le code de chaque shader, `#include` résolus, par chemin (ou par identifiant pour un shader sans chemin).
var _codes := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ le budget exige une vraie fenêtre (Xvfb suffit) : ", refus)
		_sortir(1)
		return
	_config = _valeur(args, "--config", _config)
	_classe_cartes = _valeur(args, "--classe-cartes", _classe_cartes)
	_classe_pompe = _valeur(args, "--classe", _classe_pompe)
	_images = maxi(1, int(_valeur(args, "--images", str(IMAGES))))
	var scenes := _valeur(args, "--scenes", "cartes,pompe")
	_scenes.clear()
	for s in scenes.split(","):
		if s.strip_edges() != "":
			_scenes.append(s.strip_edges())
	var cartes_voulues := _valeur(args, "--cartes", "")
	_sans_hud = true
	_taille = _lire_taille(_valeur(args, "--taille", "%dx%d" % [TAILLE_DEFAUT.x, TAILLE_DEFAUT.y]))
	print("=== Le budget de rendu — configuration « %s » ===" % _config)
	print("  arguments : %s" % " ".join(args))
	_poser_la_fenetre()
	await _lire_l_horloge()
	_mute_avant = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, true)
	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")
	# L'historique des matchs n'est pas à nous (voir le photographe).
	_main.archiver_les_matchs = false
	await _traiter_l_allumage([] as Array[Dictionary])
	var reglages := get_node_or_null(^"/root/GameSettings")
	_lacet_joue = float(reglages.call("lacet_de", 0)) if reglages != null and reglages.has_method("lacet_de") else 0.0
	print("  lacet joué (J1) : %s°" % str(_lacet_joue))

	if "cartes" in _scenes:
		var cartes := CARTES_LIVREES.duplicate()
		if cartes_voulues != "":
			cartes = cartes.filter(func(c: String) -> bool: return cartes_voulues.split(",").has(c.get_file().get_basename()))
		if not await _demarrer_une_manche(_classe_cartes):
			_sortir(1)
			return
		for chemin in cartes:
			if not _poser_la_carte(chemin):
				continue
			await _attendre_images(5)
			_placer_sur_la_carte(MapData.current_map_data)
			for vue in ["unique", "scinde"]:
				if vue == "unique":
					_vue_unique()
				else:
					_deux_vues()
				await _relever("carte", chemin.get_file().get_basename(), vue)
		_vue_unique()

	if "pompe" in _scenes:
		# La carte que le banc de cadence joue : celle de la séance, reposée depuis le catalogue.
		MapData.current_map_data = MapData.get_selected()
		_main.rebuild_arena()
		await _attendre_images(5)
		if not await _demarrer_une_manche(_classe_pompe):
			_sortir(1)
			return
		_poser_la_fusee()
		_pompe_actif = true
		for vue in ["unique", "scinde"]:
			if vue == "unique":
				_vue_unique()
			else:
				_deux_vues()
			await _relever("pompe", "pompe_sous_fusee:%s" % str(MapData.current_map_data.get("name", "?")), vue)
		_pompe_actif = false
		_vue_unique()

	AudioServer.set_bus_mute(0, _mute_avant)
	print("=== fin du budget « %s » ===" % _config)
	_sortir(0)


## Une manche locale, la classe voulue aux deux joueurs (par son SLUG, jamais par une place du râtelier : voir
## `bench_framerate.gd`, `CLASSE_PAR_DEFAUT`), puis les marionnettes. Refusée si la classe équipée n'est pas la voulue.
func _demarrer_une_manche(slug: String) -> bool:
	var BancT := load("res://tools/bench_framerate.gd")
	var idx: int = BancT.index_de_classe(_main, slug)
	if idx < 0:
		printerr("✗ aucune classe de slug « %s » au catalogue" % slug)
		return false
	_ui.hub.reset()
	_ui.hub.push(_ui.SCREEN_LOCAL)
	_ui._intended_mode = NetworkManager.GameMode.LOCAL_SPLITSCREEN
	_ui.set_weapon_selection(0, idx)
	_ui.set_weapon_selection(1, idx)
	_main._on_replay_requested()
	if not await _attendre(func() -> bool: return _main.round_active, 30.0):
		printerr("✗ la manche n'a jamais démarré")
		return false
	_prendre_les_commandes()
	if not await _attendre(func() -> bool: return _main.countdown_left <= 0.0, 30.0):
		printerr("✗ le décompte n'a jamais fini")
		return false
	var armes := []
	for j in [_main.p1, _main.p2]:
		var arme = j.get("current_weapon")
		var s := ""
		if arme != null and arme.has_method("slug"):
			s = String(arme.slug())
		elif arme != null and "slug" in arme:
			s = String(arme.slug)
		armes.append(s)
	print("  armes équipées : %s (voulue : %s)" % [str(armes), slug])
	_torches(true)
	return true


func _poser_la_carte(chemin: String) -> bool:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(chemin)) != OK or not (json.data is Dictionary):
		printerr("  ✗ carte illisible : %s" % chemin)
		return false
	var data: Dictionary = MapCodec.validate(json.data as Dictionary)["data"]
	MapData.current_map_data = data
	_main.rebuild_arena()
	return true


## J1 au centre de sa case d'apparition, J2 à `ECART_DUEL` dans le premier cap libre (sol libre, aucun mur entre les deux)
## en tournant depuis la direction du point d'apparition de J2. Chacun vise l'autre. Écrit dans les notes du relevé.
func _placer_sur_la_carte(data: Dictionary) -> void:
	var t := float(CandelaTileSet.TILE_SIZE.x)
	var s1 := Vector2(MapCodec.get_spawn(data, 0)) * t + Vector2(t, t) * 0.5
	var s2 := Vector2(MapCodec.get_spawn(data, 1)) * t + Vector2(t, t) * 0.5
	_j1 = s1
	var cap := (s2 - s1).angle()
	_j2 = s1 + Vector2.from_angle(cap) * ECART_DUEL
	for k in 24:
		var essai := s1 + Vector2.from_angle(cap + float(k) * TAU / 24.0) * ECART_DUEL
		_main.p1.global_position = _j1
		if _sol_libre(essai) and not _mur_entre(_j1, essai):
			_j2 = essai
			break
	_tenir()


func _tenir() -> void:
	if not is_instance_valid(_main.p1) or not is_instance_valid(_main.p2):
		return
	if _pompe_actif:
		_tenir_le_pompe()
		return
	_main.p1.global_position = _j1
	_main.p2.global_position = _j2
	_viser(0, _j2 - _j1)
	_viser(1, _j1 - _j2)
	_torches(true)
	_vivants()


## La charge du banc de cadence, image par image : J2 à 150 px de J1, les deux au feu, points de vie pleins, la fusée
## entretenue en pleine braise (même boucle d'âge que `bench_framerate.gd`, `_stress`).
func _tenir_le_pompe() -> void:
	_main.p2.global_position = _main.p1.global_position + Vector2(DUEL_POMPE, 0.0)
	_viser(0, Vector2.RIGHT)
	_viser(1, Vector2.LEFT)
	_age += 1.0 / 60.0
	if is_instance_valid(_fusee):
		_fusee.appliquer_age(FuseeModele.FUMEE_MONTEE
			+ fmod(_age, FuseeModele.DUREE_BRAISE - FuseeModele.FUMEE_MONTEE - 0.5))
	for p in [_main.p1, _main.p2]:
		p.hp = 100.0
		if p.shoot_cooldown <= 0.0:
			p.shoot()
	_torches(true)


func _poser_la_fusee() -> void:
	_main.p2.global_position = _main.p1.global_position + Vector2(DUEL_POMPE, 0.0)
	_fusee = Fusee.new()
	_fusee.is_replay = true
	_fusee.name = "FuseeBudget"
	_fusee.depart = _main.p1.global_position + Vector2(DUEL_POMPE * 0.5, 0.0)
	_fusee.graine = 12345
	_fusee.joueurs = [_main.p1, _main.p2]
	_main.bullet_container.add_child(_fusee)


# ---------------------------------------------------------------------------
# LE RELEVÉ
# ---------------------------------------------------------------------------

func _relever(famille: String, scene: String, vue: String) -> void:
	for i in CHAUFFE:
		_tenir()
		await get_tree().process_frame
	var series := {}
	var passes := {}
	for i in _images:
		_tenir()
		await get_tree().process_frame
		# Les compteurs d'une image se lisent APRÈS qu'elle est rendue : ceux lus ici sont ceux de l'image précédente, rendue
		# à la fin du tour précédent, pour laquelle `_tenir` avait posé la même scène.
		var echantillon := _compter()
		for cle in echantillon["nombres"]:
			if not series.has(cle):
				series[cle] = []
			series[cle].append(echantillon["nombres"][cle])
		passes = echantillon["passes"]
	var resume := {}
	for cle in series:
		var v: Array = series[cle]
		v.sort()
		resume[cle] = {"med": v[v.size() / 2], "min": v[0], "max": v[v.size() - 1]}
	var ligne := {
		"config": _config, "famille": famille, "scene": scene, "vue": vue, "lacet": _lacet_joue,
		"fenetre": [get_window().size.x, get_window().size.y], "images": _images,
		"j1": [snappedf(_j1.x, 0.1), snappedf(_j1.y, 0.1)], "j2": [snappedf(_j2.x, 0.1), snappedf(_j2.y, 0.1)],
		"compteurs": resume, "passes": passes,
	}
	print("BUDGET\t%s" % JSON.stringify(ligne))
	var total: Dictionary = resume.get("total.appels", {})
	print("  · %s / %s / %s : %s appels (min %s, max %s)" % [famille, scene, vue, str(total.get("med")),
		str(total.get("min")), str(total.get("max"))])


## Une vue a-t-elle rendu à cette image ? Une sous-vue arrêtée GARDE les compteurs de sa dernière image : les lire sans ce
## filtre compterait deux fois un rendu qui n'a pas eu lieu.
func _vue_rendue(v: Viewport) -> bool:
	if v == get_tree().root:
		return true
	var sv := v as SubViewport
	if sv == null:
		return v.is_inside_tree()
	match sv.render_target_update_mode:
		SubViewport.UPDATE_ALWAYS:
			return true
		SubViewport.UPDATE_WHEN_VISIBLE:
			return sv.is_inside_tree() and _parent_visible(sv)
		SubViewport.UPDATE_WHEN_PARENT_VISIBLE:
			return sv.is_inside_tree() and _parent_visible(sv)
	return false


func _parent_visible(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p is CanvasItem:
			return (p as CanvasItem).is_visible_in_tree()
		if p is Viewport:
			return true
		p = p.get_parent()
	return true


func _chemin_court(n: Node) -> String:
	var c := String(n.get_path())
	if c == "/root":
		return "racine"
	return c.trim_prefix("/root/")


func _compter() -> Dictionary:
	var nombres := {}
	var RS := RenderingServer
	nombres["total.appels"] = RS.get_rendering_info(RS.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	nombres["total.primitives"] = RS.get_rendering_info(RS.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	nombres["total.objets"] = RS.get_rendering_info(RS.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	nombres["mem.video_mo"] = snappedf(float(RS.get_rendering_info(RS.RENDERING_INFO_VIDEO_MEM_USED)) / 1048576.0, 0.01)
	nombres["mem.textures_mo"] = snappedf(float(RS.get_rendering_info(RS.RENDERING_INFO_TEXTURE_MEM_USED)) / 1048576.0, 0.01)
	nombres["mem.tampons_mo"] = snappedf(float(RS.get_rendering_info(RS.RENDERING_INFO_BUFFER_MEM_USED)) / 1048576.0, 0.01)

	var vues: Array[Viewport] = [get_tree().root]
	var copies_ecran: Array[String] = []
	var bbc := 0
	var lum2d := 0
	var lum2d_ombre := 0
	var lum3d := 0
	var lum3d_ombre := 0
	var occluders := 0
	var particules := 0
	var somme := {"appels": 0, "primitives": 0, "objets": 0}
	var pile: Array[Node] = [get_tree().root]
	while not pile.is_empty():
		var n: Node = pile.pop_back()
		for enfant in n.get_children():
			pile.append(enfant)
		if n is SubViewport:
			vues.append(n as Viewport)
		if n is CanvasItem:
			var ci := n as CanvasItem
			if not ci.is_visible_in_tree():
				continue
			if n is BackBufferCopy:
				bbc += 1
			elif n is Light2D:
				if (n as Light2D).enabled:
					lum2d += 1
					if (n as Light2D).shadow_enabled:
						lum2d_ombre += 1
			elif n is LightOccluder2D:
				occluders += 1
			elif (n is GPUParticles2D and (n as GPUParticles2D).emitting) or (n is CPUParticles2D and (n as CPUParticles2D).emitting):
				particules += 1
			if _lit_l_ecran(ci.material):
				copies_ecran.append("%s @ %s" % [_nom_du_shader(ci.material), _chemin_court(ci.get_viewport())])
		elif n is Node3D:
			var n3 := n as Node3D
			if not n3.is_visible_in_tree():
				continue
			if n is Light3D:
				lum3d += 1
				if (n as Light3D).shadow_enabled:
					lum3d_ombre += 1
			elif n is GPUParticles3D and (n as GPUParticles3D).emitting:
				particules += 1
			if n is GeometryInstance3D:
				for m in _materiaux_3d(n as GeometryInstance3D):
					if _lit_l_ecran(m):
						copies_ecran.append("%s @ 3D %s" % [_nom_du_shader(m), _chemin_court(n)])
						break

	var detail_vues := []
	for v in vues:
		var rendue := _vue_rendue(v)
		var d := {"vue": _chemin_court(v) if v != get_tree().root else "racine", "rendue": rendue,
			"taille": [int(v.get_visible_rect().size.x), int(v.get_visible_rect().size.y)]}
		if rendue:
			for type_nom in ["visible", "ombres", "canevas"]:
				var type: int = {"visible": Viewport.RENDER_INFO_TYPE_VISIBLE, "ombres": Viewport.RENDER_INFO_TYPE_SHADOW,
					"canevas": Viewport.RENDER_INFO_TYPE_CANVAS}[type_nom]
				var a := v.get_render_info(type, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
				var p := v.get_render_info(type, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
				var o := v.get_render_info(type, Viewport.RENDER_INFO_OBJECTS_IN_FRAME)
				d[type_nom] = [a, p, o]
				nombres["vue.%s.%s.appels" % [d["vue"], type_nom]] = a
				nombres["vue.%s.%s.primitives" % [d["vue"], type_nom]] = p
				somme["appels"] += a
				somme["primitives"] += p
				somme["objets"] += o
		detail_vues.append(d)
	nombres["somme_vues.appels"] = somme["appels"]
	nombres["somme_vues.primitives"] = somme["primitives"]
	nombres["somme_vues.objets"] = somme["objets"]
	var rendues := detail_vues.filter(func(d: Dictionary) -> bool: return d["rendue"])
	nombres["passes.vues_rendues"] = rendues.size()
	nombres["passes.copies_ecran"] = copies_ecran.size()
	nombres["passes.backbuffercopy"] = bbc
	nombres["lumieres.2d"] = lum2d
	nombres["lumieres.2d_ombre"] = lum2d_ombre
	nombres["lumieres.3d"] = lum3d
	nombres["lumieres.3d_ombre"] = lum3d_ombre
	nombres["occluders.2d"] = occluders
	nombres["particules.emetteurs"] = particules
	copies_ecran.sort()
	return {"nombres": nombres, "passes": {"vues": detail_vues, "copies_ecran": copies_ecran}}


func _materiaux_3d(g: GeometryInstance3D) -> Array[Material]:
	var sortie: Array[Material] = []
	if g.material_override != null:
		sortie.append(g.material_override)
	if g.material_overlay != null:
		sortie.append(g.material_overlay)
	if g is MeshInstance3D:
		var mi := g as MeshInstance3D
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				var m := mi.get_active_material(s)
				if m != null:
					sortie.append(m)
	return sortie


## Le shader de ce matériau DÉCLARE-t-il la texture d'écran (ou de profondeur) ? Suffisant pour une copie d'écran, qu'il la
## lise ou non à cette image (ROADMAP, « Pièges connus », 2026-09-15). Les `#include` sont résolus, récursivement.
func _lit_l_ecran(m: Material) -> bool:
	var sm := m as ShaderMaterial
	if sm == null or sm.shader == null:
		# Un matériau enchaîné (`next_pass`) peut porter la lecture.
		return m != null and m.next_pass != null and _lit_l_ecran(m.next_pass)
	var code := _code_complet(sm.shader)
	if code.contains("hint_screen_texture") or code.contains("hint_depth_texture"):
		return true
	return sm.next_pass != null and _lit_l_ecran(sm.next_pass)


func _nom_du_shader(m: Material) -> String:
	var sm := m as ShaderMaterial
	if sm == null or sm.shader == null:
		return "?"
	return sm.shader.resource_path.get_file() if sm.shader.resource_path != "" else "shader#%d" % sm.shader.get_instance_id()


func _code_complet(shader: Shader) -> String:
	var cle := shader.resource_path if shader.resource_path != "" else str(shader.get_instance_id())
	if _codes.has(cle) and shader.resource_path != "":
		return _codes[cle]
	# Sans les commentaires : un shader qui PARLE de la texture d'écran (« sans lecture de hint_screen_texture ») ne la
	# déclare pas.
	var code := _sans_commentaires(_resoudre(shader.code, {}))
	_codes[cle] = code
	return code


func _sans_commentaires(code: String) -> String:
	var bloc := RegEx.create_from_string("(?s)/\\*.*?\\*/")
	var ligne := RegEx.create_from_string("//[^\\n]*")
	return ligne.sub(bloc.sub(code, "", true), "", true)


func _resoudre(code: String, vus: Dictionary) -> String:
	var sortie := code
	for ligne in code.split("\n"):
		var l := ligne.strip_edges()
		if not l.begins_with("#include"):
			continue
		var debut := l.find("\"")
		var fin := l.rfind("\"")
		if debut < 0 or fin <= debut:
			continue
		var chemin := l.substr(debut + 1, fin - debut - 1)
		if vus.has(chemin):
			continue
		vus[chemin] = true
		var inc := load(chemin) as ShaderInclude
		if inc != null:
			sortie += "\n" + _resoudre(inc.code, vus)
	return sortie
