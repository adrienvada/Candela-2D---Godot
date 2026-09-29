extends "res://tools/photographe.gd"
## LE POINT DE BRAISE DE LA FUSÉE, À CHAQUE ÂGE — la planche avant / après (2026-09-29).
##
## Adrien, 2026-09-29 (à la question « le point rouge de la fusée, quand elle retombe en braise, est 3,6 fois moins lumineux
## que l'ancien point orange, et le repère se perd : le rendre aussi lumineux que sa lumière, en gardant le rouge ? ») :
## « Le point rouge : oui, dans la 0.8.0 ». Cet outil MESURE, à l'image, ce que chaque joueur voit du point, à chaque âge de la
## fusée : il ne change rien au jeu.
##
## ## Ce qu'il monte
##
## Le vrai `main.tscn` (les deux vues iso, 45° B : J1 à 45°, J2 à 225°), sur l'arène standard (ouverte : rien ne coupe la fumée ni
## la lumière). Une fusée POSÉE au centre de la carte, vieillie sur place (`forcer_age`, jamais par l'horloge : l'âge est écrit, donc
## exact). J1 et J2 sont posés de part et d'autre, à `DISTANCE` px de la fusée, torches éteintes, chacun regardant vers elle :
## au-delà des 400 px où une fusée éblouit, donc aucun voile d'éblouissement sur la mesure ; et à la même distance, sur l'axe de la
## caméra de chacun — la fusée est en haut de l'écran de J1 comme en haut de l'écran de J2.
##
## ## Deux façons de regarder (`--vue=`), parce que le jeu en a deux et qu'elles n'écrivent pas les mêmes valeurs
##
## - `scinde` (défaut) : l'ÉCRAN SCINDÉ, les deux vues à la fois — la texture de chaque sous-vue 3D, telle que le joueur local la voit ;
## - `unique1` / `unique2` : la VUE UNIQUE, celle du jeu en ligne et de l'entraînement — la fenêtre entière, la racine rendant la
##   vue de J1 (ou de J2), interface cachée. **Sa sortie 3D a une courbe** (point noir à 7,5/255, hautes lumières tassées vers 230 :
##   « Pièges connus », 2026-09-25) que la texture d'une sous-vue n'a pas. Les planches de la session « fusée-point » (27/09) sont
##   prises ainsi : c'est là qu'Adrien a lu (221, 71, 80) au braise et (39, 10, 12) au résidu.
##
## ## Trois prises par âge
##
## - `apres`  : le point tel que le code le dessine ;
## - `sans`   : le même instant SANS le point (`IsoVolumes.coeur_fusee = 0`) — ce qui diffère entre les deux est le point seul, qu'on
##   mesure alors là où il est, et non comme « le pixel le plus lumineux » (sur un sol orange, ce peut être le sol) ;
## - `ancien` : le même instant avec l'ANCIEN point, celui d'avant la correction de `78fb380` (Q34 = C) — additif, de la couleur de
##   la lumière, jusqu'à la couleur du blanc quand l'énergie relative monte. C'est « l'ancien point orange » d'Adrien : son éclat sur
##   le sol de cette scène est la référence de luminance. Il est reconstitué ICI, à l'image (le matériau du point est échangé
##   contre le shader additif juste avant le rendu, `_avant_le_rendu`) : aucune ligne du jeu ne le porte plus. `--sans-ancien` la saute.
##
## `--variantes=court,long` : le plein feu de 2 s (`FuseeModele.poser_rouge_long(false)`, le jeu d'avant la 0.7.0) et de 4 s (le
## défaut depuis Q35). Les deux se jouent dans le même processus : le modèle est statique, l'horloge de la fusée le relit.
##
## ## Le même instant, à l'image près
##
## La caméra glisse vers son regard (`RegardDuel.lisser`, exponentiel, 8 par seconde) : les joueurs posés, elle met plus d'une
## seconde de jeu à s'arrêter, et deux prises en cours de glissement ne se superposent pas (premier essai : 7 544 pixels
## « différents » entre `apres` et `sans`, tous des translations). La séance attend donc `IMAGES_STABILISATION` images à temps
## accéléré, puis vérifie que la position du point à l'écran ne bouge plus (`_position_du_point`), et le dit dans le journal.
##
## ## Ce qu'il écrit
## - `<dossier>/<variante>_a<âge>_<J1|J2>_<apres|sans|ancien>.png` : un recadrage de `RECADRAGE` px, à la résolution de la vue,
##   centré sur le point projeté (le même recadrage pour les trois prises d'un âge) ;
## - `<dossier>/journal.json` : pour chaque (variante, âge) l'âge lu, l'acte, l'énergie et la couleur de la lumière, l'éclat et les
##   paramètres du point (couleur, intensité, shader), l'éblouissement des deux joueurs, où est le point dans chaque vue, et de
##   combien il a bougé entre les prises ;
## - avec `--images` : la vue entière (réduite de moitié) de chaque joueur, prise `apres`.
## `docs/iso/braise/mesurer.py` en tire les couleurs, les luminances et la planche.
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . --resolution 1920x1080 res://tools/planche_braise.tscn -- \
##     --sortie=<dossier> --led-murs-fige=0.5 --no-eos [--vue=scinde|unique1|unique2] [--ages=1.5,2.5,3,3.5,5,8,16] \
##     [--variantes=court,long] [--sans-ancien] [--images] [--torches]
##
## Avant / après : lancer la même planche dans l'arbre de la base, puis dans celui de la branche.

const AGES_DEFAUT := [1.5, 2.5, 3.0, 3.5, 5.0, 8.0, 16.0]
## Où poser les joueurs : au-delà du rayon d'éblouissement d'une fusée (`GameState.RAYON_EBLOUISSEMENT_FUSEE`, 400 px).
const DISTANCE := 460.0
## Le recadrage écrit autour du point, en pixels de la vue.
const RECADRAGE := 128
## Le nombre d'images laissées au jeu après un changement d'âge ou de dessin : la lumière 2D est rendue dans les
## lightmaps, que la vue 3D ne lit qu'à l'image suivante.
const IMAGES_REPOS := 4
const IMAGES_BASCULE := 3
## Le glissement de la caméra vers son regard : e^(−8 t) — à temps ×4, 40 images valent 160 pas de 1/60 s, soit e^(−21) : rien.
const IMAGES_STABILISATION := 40
const GRAINE := 4242

var _iso: Presentation3D
var _volumes: IsoVolumes
var _fusee: Node2D
var _centre := Vector2.ZERO
var _haut := Vector2.UP
var _ancien := false
var _images := false
var _sans_ancien := false
## `--sans-courbe` : seulement les âges demandés, sans ceux qui montrent la fin de la vie (`_ages_de_la_courbe`).
var _sans_courbe := false
## `--distance=300` : poser les joueurs plus près, DANS le rayon d'éblouissement — pour voir ce que le voile d'éblouissement fait au point.
var _distance := DISTANCE
## `--torches` : les torches des deux joueurs ALLUMÉES, chacune tournée vers la fusée. Éteintes par défaut : on ne mesure alors que le point sur
## le sol qu'éclaire la fusée seule, ce que les chiffres de la ROADMAP disent. Allumées, le sol autour du point peut être plus clair que sa
## propre lumière — c'est le cas où un point qui COUVRE le sol (le mélange) peut lui être inférieur, là où l'ancien point s'y ajoutait.
var _torches_allumees := false
## `scinde` : les deux sous-vues ; sinon l'indice (0 ou 1) du joueur dont la vue occupe la fenêtre.
var _vue := "scinde"
var _regarde := -1
var _journal: Array = []
var _fichiers: Array = []
var _derniere_position: Array = [Vector2.ZERO, Vector2.ZERO]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ planche_braise : ", refus)
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", "user://braise")
	_images = _drapeau(args, "--images")
	_sans_ancien = _drapeau(args, "--sans-ancien")
	_sans_courbe = _drapeau(args, "--sans-courbe")
	_torches_allumees = _drapeau(args, "--torches")
	_distance = float(_valeur(args, "--distance", str(DISTANCE)))
	_vue = _valeur(args, "--vue", "scinde")
	_regarde = {"unique1": 0, "unique2": 1}.get(_vue, -1)
	if _vue != "scinde" and _regarde < 0:
		printerr("✗ --vue=%s : scinde, unique1 ou unique2" % _vue)
		_sortir(1)
		return
	_taille = _lire_taille(_valeur(args, "--taille", "1920x1080"))
	var ages: Array = []
	var voulus := _valeur(args, "--ages", "").strip_edges()
	if voulus == "":
		ages = AGES_DEFAUT
	else:
		for a in voulus.split(","):
			ages.append(float(a))
	var variantes: Array = []
	for v in _valeur(args, "--variantes", "court,long").split(","):
		variantes.append(String(v).strip_edges())
	print("=== Planche du point de braise : la fusée à chaque âge (vue : %s) ===" % _vue)
	_poser_la_fenetre()
	AudioServer.set_bus_mute(0, true)
	var intro_vue_avant: bool = GameSettings.intro_vue
	GameSettings.intro_vue = true
	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	GameSettings.intro_vue = intro_vue_avant
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")
	_main.rendu_racine_autorise = true
	_main.archiver_les_matchs = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dossier))
	var allumage := _main.get_node_or_null(^"PowerOn")
	if allumage != null and allumage.has_method("terminer"):
		allumage.terminer()
		await _attendre_disparition(allumage, 3.0)

	_ui.hub.reset()
	_ui.hub.push(_ui.SCREEN_LOCAL)
	_main._on_replay_requested()
	if not await _attendre(func() -> bool: return _main.round_active, 120.0):
		printerr("✗ la manche n'a jamais démarré")
		_sortir(1)
		return
	_prendre_les_commandes()
	# Le décompte de trois secondes se compte en images de jeu (`--fixed-fps 60`) : sous rendu logiciel, cent quatre-vingts
	# images coûtent des minutes. Le temps du jeu accéléré, le temps d'un décompte seulement.
	Engine.time_scale = 4.0
	var decompte_fini: bool = await _attendre(func() -> bool: return _main.countdown_left <= 0.0, 240.0)
	Engine.time_scale = 1.0
	if not decompte_fini:
		printerr("✗ le décompte n'a jamais fini")
		_sortir(1)
		return
	_torches(_torches_allumees)
	_sans_hud = true
	if _ui.match_hud != null:
		_ui.match_hud.hide()
	_carte_duel = "res://assets/maps/default.json"
	await _passer_sur_la_carte_des_murs_bas()
	_iso = Presentation3D.instance()
	if _iso == null:
		printerr("✗ aucune Presentation3D : la vue iso n'est pas en place")
		_sortir(1)
		return
	if _iso.viewport_ecran(0) == null or _iso.viewport_ecran(1) == null:
		printerr("✗ les deux vues iso ne sont pas regardées (écran scindé attendu au départ)")
		_sortir(1)
		return
	var miroirs = _iso.get("_miroirs")
	_volumes = miroirs.get("volumes") if miroirs != null else null
	if _volumes == null:
		printerr("✗ volumes iso introuvables")
		_sortir(1)
		return
	for j in [_main.p1, _main.p2]:
		(j.noise as FastNoiseLite).frequency = 0.0
	RenderingServer.frame_pre_draw.connect(_avant_le_rendu)

	var grille := Vector2(MapCodec.get_grid_size(MapData.current_map_data)) * Vector2(CandelaTileSet.TILE_SIZE)
	_centre = (grille * 0.5).round()
	# « Haut de l'écran » de J1 en coordonnées du monde : à l'opposé de la direction qui va vers sa caméra.
	_haut = -(IsoGeometrie.vers_camera(GameSettings.lacet_duel))
	print("  arène %s, fusée en %s, « haut » de J1 %s, lacet %s %s, zoom %s" % [str(MapData.current_map_data.get("name", "?")),
		str(_centre), str(_haut), str(GameSettings.lacet_duel), GameSettings.option_lacet, str(_main.cam1.zoom)])
	print("  point de braise (coeur_fusee) = %d ; plein feu %.1f s, braise %.1f s" % [
		int(_volumes.get("coeur_fusee")), FuseeModele.duree_plein_feu, FuseeModele.duree_braise])
	print("  masque de la fumée : %s ; faisceau dans l'air : %s ; usure : %s" % [
		"allumé" if _volumes.get("masque_fumee") else "éteint", "allumé" if _volumes.get("faisceau_air") else "éteint",
		str(IsoMateriaux.usure_essai_active())])

	await _poser_la_fusee()
	if _regarde >= 0:
		await _regarder_seul(_regarde)
	Engine.time_scale = 4.0
	await _laisser_passer(IMAGES_STABILISATION)
	Engine.time_scale = 1.0
	await _laisser_passer(2)
	var stable := _position_du_point()
	print("  caméra stabilisée : point à %s (J1) / %s (J2)" % [str(stable[0]), str(stable[1])])

	for v in variantes:
		var long: bool = String(v) == "long"
		FuseeModele.poser_rouge_long(long)
		print("\n=== variante %s : plein feu %.1f s, braise %.1f s, vie %.1f s ===" % [v, FuseeModele.duree_plein_feu,
			FuseeModele.duree_braise, FuseeModele.duree_combustion()])
		var liste: Array = ages.duplicate()
		if not _sans_courbe:
			for a in _ages_de_la_courbe():
				liste.append(a)
		for age: float in liste:
			# Après 12 s, les deux variantes sont dans le même état (plein feu + braise = 12 s dans les deux) : une seule prise.
			if String(v) == "court" and age >= FuseeModele.duree_plein_feu + FuseeModele.duree_braise - 1e-6 and variantes.has("long"):
				continue
			await _age(String(v), age)
	FuseeModele.poser_rouge_long(true)

	var f := FileAccess.open("%s/journal.json" % _dossier, FileAccess.WRITE)
	f.store_string(JSON.stringify({"commit": _commit(), "fenetre": [_taille.x, _taille.y], "zoom": _main.cam1.zoom.x,
		"vue": _vue, "lacet": GameSettings.lacet_duel, "option_lacet": GameSettings.option_lacet,
		"carte": MapData.current_map_data.get("name", "?"),
		"centre": [_centre.x, _centre.y], "distance": _distance, "torches": _torches_allumees, "recadrage": RECADRAGE, "graine": GRAINE,
		"taille_du_point_monde": IsoVolumes.TAILLE_COEUR_FUSEE, "hauteur_du_point_monde": IsoVolumes.HAUTEUR_COEUR_FUSEE_PX,
		"prises": _journal}, "  "))
	f.close()
	print("\n%d prise(s), %d fichier(s) dans %s" % [_journal.size(), _fichiers.size(), ProjectSettings.globalize_path(_dossier)])
	_sortir(0)


# ---------------------------------------------------------------------------
# LA MISE EN SCÈNE
# ---------------------------------------------------------------------------

func _poser_la_fusee() -> void:
	var f: Node2D = (load("res://fusee.gd") as GDScript).new()
	f.set("depart", _centre)
	f.set("direction", Vector2.DOWN)
	f.set("graine", GRAINE)
	f.set("joueurs", [_main.p1, _main.p2])
	_main.bullet_container.add_child(f)
	await get_tree().process_frame
	f.set_physics_process(false)
	f.global_position = _centre
	f.call("forcer_age", 0.0)
	_fusee = f


## La vue UNIQUE du joueur `k` : la racine rend son duel, l'interface est rangée comme le fait `_vue_unique()` du photographe
## (qui ne sait montrer que J1).
func _regarder_seul(k: int) -> void:
	var c1 := _main.vp1.get_parent() as Control
	var c2 := _main.vp2.get_parent() as Control
	(c2 if k == 0 else c1).hide()
	(c1 if k == 0 else c2).show()
	_ui.center_line.hide()
	_main._accorder_rendu_aux_vues()
	_ui._voile_scinde = false
	if _ui.hud_panneau_p2 != null:
		_ui.hud_panneau_p2.visible = false
	if _ui.match_hud != null:
		_ui.match_hud.hide()
	await _laisser_passer(6)
	var ecran := _iso.viewport_ecran(k)
	print("  vue unique de J%d : %s rend son écran (racine : %s)" % [k + 1, str(ecran), str(ecran == get_window())])


## Les âges qui montrent la fin de la vie : le creux de l'agonie (le quasi-noir entre deux sursauts), le sommet d'un sursaut, et le
## résidu — là où le point était perdu. Lus sur le modèle, à la graine de la fusée.
func _ages_de_la_courbe() -> Array:
	var fenetres := FuseeModele.fenetres_agonie(GRAINE)
	var debut := FuseeModele.duree_plein_feu + FuseeModele.duree_braise
	var creux := debut + 1.0
	var e_creux := INF
	var sursaut := debut + 1.0
	var e_sursaut := -INF
	var t := debut
	while t < debut + FuseeModele.DUREE_AGONIE:
		var e := FuseeModele.energie_a(t, fenetres)
		if e < e_creux:
			e_creux = e
			creux = t
		if e > e_sursaut:
			e_sursaut = e
			sursaut = t
		t += 1.0 / 60.0
	var out: Array = [snappedf(creux, 0.01), snappedf(sursaut, 0.01)]
	for r in [15.5, 17.0, 18.0, 19.0]:
		out.append(r)
	return out


## Les joueurs restent où on les a posés, l'un en haut de l'autre en bas de l'écran de l'autre : à `DISTANCE` de la fusée, sur
## l'axe de la caméra de chacun, regardant vers elle. Rappelé à CHAQUE image.
func _tenir() -> void:
	var p1 := _centre - _haut * _distance
	var p2 := _centre + _haut * _distance
	for k in 2:
		var j = _main.p1 if k == 0 else _main.p2
		var ou := p1 if k == 0 else p2
		var vers := (_centre - ou).normalized()
		j.global_position = ou
		j.velocity = Vector2.ZERO
		j.set("_dust_accum", -1.0e9)
		_viser(k, vers)
		j.global_rotation = vers.angle()
	_vivants()
	for cam in [_main.cam1, _main.cam2]:
		if is_instance_valid(cam):
			cam.reset_smoothing()


func _laisser_passer(n: int) -> void:
	for i in n:
		_tenir()
		await get_tree().process_frame


## Où est le point à l'écran de chaque joueur, en pixels de la vue (physique, pas logique) ; `Vector2.INF` si la vue n'est pas regardée.
func _position_du_point() -> Array:
	var out: Array = []
	for k in 2:
		var vue := _iso.viewport_ecran(k)
		if vue == null:
			out.append(Vector2.INF)
			continue
		var cam := _iso._camera_de(k)
		var logique := vue.get_visible_rect().size
		var taille: Vector2 = Vector2(vue.get_texture().get_size()) if vue != get_window() else Vector2(get_window().size)
		out.append(cam.vers_ecran(_centre, logique, IsoVolumes.HAUTEUR_COEUR_FUSEE_PX) * taille / logique)
	return out


## Juste avant le rendu, après le `_process` de la présentation (qui a posé les paramètres du point) : le point à son état voulu.
## `_ancien` faux : le point du jeu, en mélange. Vrai : l'ancien, additif, dans la couleur de la lumière — reconstitué ici avec la
## formule d'avant `78fb380` (`_suivre_coeur_fusee` : `couleur = lumière.lerp(blanc, smoothstep(0,6 → 0,95, énergie relative))`,
## éclat = max(énergie / 0,8 × opacité du cœur, opacité), halo à bord franc).
func _avant_le_rendu() -> void:
	if _volumes == null or _fusee == null or not is_instance_valid(_fusee):
		return
	var e: Dictionary = _volumes.suivi_de(_fusee, 2)
	if e.is_empty() or (e["mats"] as Array).is_empty():
		return
	var mat: ShaderMaterial = e["mats"][0]
	var mi := e["noeuds"][0] as MeshInstance3D
	if not _ancien:
		if mat.shader != IsoVolumes.SHADER_HALO_MELANGE:
			mat.shader = IsoVolumes.SHADER_HALO_MELANGE
		return
	var p := _ancien_point()
	mat.shader = IsoVolumes.SHADER_HALO
	mat.set_shader_parameter("couleur", p["couleur"])
	mat.set_shader_parameter("intensite", p["intensite"])
	mat.set_shader_parameter("forme", 1)
	mi.visible = float(p["intensite"]) > 0.002


## Les paramètres de l'ancien point à l'état courant de la fusée (couleur, intensité) — additif, sans plancher.
func _ancien_point() -> Dictionary:
	var lumiere := _fusee.get_node("Halo") as Light2D
	var energie := lumiere.energy if lumiere.enabled else 0.0
	var opacite := (_fusee.get_node("Coeur") as CanvasItem).modulate.a
	var eclat := maxf(clampf(energie / 0.8, 0.0, 1.5) * opacite, opacite)
	var relative := float(_fusee.call("energie_relative"))
	var couleur := lumiere.color.lerp(IsoVolumes.COULEUR_COEUR_BLANC, smoothstep(0.6, 0.95, relative))
	return {"couleur": couleur, "intensite": eclat if eclat > 0.002 else 0.0}


# ---------------------------------------------------------------------------
# LA PRISE
# ---------------------------------------------------------------------------

func _age(variante: String, age: float) -> void:
	_fusee.call("forcer_age", age)
	_ancien = false
	_volumes.set("coeur_fusee", 2)
	await _laisser_passer(IMAGES_REPOS)
	var lu := float(_fusee.call("age_combustion"))
	var lumiere := _fusee.get_node("Halo") as Light2D
	var energie := lumiere.energy if lumiere.enabled else 0.0
	var opacite := (_fusee.get_node("Coeur") as CanvasItem).modulate.a
	var base := "%s_a%s" % [variante, String.num(age, 2).replace(".", "_")]
	var ligne := {
		"variante": variante, "age_demande": age, "age_lu": lu, "nom": base,
		"acte": FuseeModele.Acte.keys()[FuseeModele.acte_a(lu)], "energie": energie,
		"couleur_lumiere": [lumiere.color.r, lumiere.color.g, lumiere.color.b], "lumiere_active": lumiere.enabled,
		"energie_relative": float(_fusee.call("energie_relative")), "opacite_coeur": opacite,
		"alpha_fumee": float(_fusee.call("alpha_fumee")), "rayon_fumee": float(_fusee.call("rayon_fumee")),
		"duree_plein_feu": FuseeModele.duree_plein_feu, "coeur_fusee": int(_volumes.get("coeur_fusee")),
		"eblouissement": [float(_main.p1.dazzle_amount), float(_main.p2.dazzle_amount)],
		"ancien": {}, "point": {}, "vues": {}, "fichiers": [], "glissement_px": 0.0,
	}
	var e: Dictionary = _volumes.suivi_de(_fusee, 2)
	if not e.is_empty() and not (e["mats"] as Array).is_empty():
		var mat: ShaderMaterial = e["mats"][0]
		var c: Color = mat.get_shader_parameter("couleur")
		ligne["point"] = {"couleur": [c.r, c.g, c.b, c.a], "intensite": float(mat.get_shader_parameter("intensite")),
			"melange": mat.shader == IsoVolumes.SHADER_HALO_MELANGE}
	var anc := _ancien_point()
	var ca: Color = anc["couleur"]
	ligne["ancien"] = {"couleur": [ca.r, ca.g, ca.b, ca.a], "intensite": float(anc["intensite"])}

	await _recadrer_les_vues(ligne, "apres")
	if _images:
		await _vue_entiere(base)
	_volumes.set("coeur_fusee", 0)
	await _laisser_passer(IMAGES_BASCULE)
	await _recadrer_les_vues(ligne, "sans")
	_volumes.set("coeur_fusee", 2)
	if not _sans_ancien:
		await _laisser_passer(IMAGES_BASCULE)
		_ancien = true
		await _laisser_passer(IMAGES_BASCULE)
		await _recadrer_les_vues(ligne, "ancien")
		_ancien = false
	_journal.append(ligne)
	var p: Dictionary = ligne["point"]
	print("  %-14s âge lu %6.3f  %-9s énergie %.3f  éclat du point (intensité) %s  éblouissement %.3f / %.3f  glissement %.2f px" % [
		base, lu, ligne["acte"], energie, ("%.3f" % float(p.get("intensite", 0.0))) if not p.is_empty() else "absent",
		ligne["eblouissement"][0], ligne["eblouissement"][1], float(ligne["glissement_px"])])


## Écrit, pour chaque vue regardée, le recadrage autour du point projeté. Le recadrage est décidé à la première prise de l'âge
## (`apres`) et gardé pour les autres ; la position du point est relue à chaque prise, et l'écart maximal est journalisé.
func _recadrer_les_vues(ligne: Dictionary, mode: String) -> void:
	var vues_regardees: Array = [_regarde] if _regarde >= 0 else [0, 1]
	var racine: Image = null
	if _regarde >= 0:
		# La fenêtre entière, l'interface cachée (comme `_capturer_la_vue_iso` du photographe).
		var caches: Array[Node] = []
		for enfant in _ui.get_children():
			if (enfant is CanvasLayer or enfant is CanvasItem) and bool(enfant.get("visible")):
				enfant.set("visible", false)
				caches.append(enfant)
		_au_premier_plan()
		racine = await Commun.capturer(get_tree(), 30000)
		for enfant in caches:
			if is_instance_valid(enfant):
				enfant.set("visible", true)
		if racine == null:
			printerr("  ✗ prise perdue : %s %s" % [ligne["nom"], mode])
			return
	else:
		await RenderingServer.frame_post_draw
	var positions := _position_du_point()
	for k: int in vues_regardees:
		var img: Image
		if racine != null:
			img = racine
		else:
			img = _iso.viewport_ecran(k).get_texture().get_image()
		var ecran: Vector2 = positions[k]
		var vues: Dictionary = ligne["vues"]
		var cle := "J%d" % (k + 1)
		var x0 := 0
		var y0 := 0
		if vues.has(cle):
			x0 = int(vues[cle]["origine_du_recadrage"][0])
			y0 = int(vues[cle]["origine_du_recadrage"][1])
			var derive := ecran.distance_to(Vector2(vues[cle]["point"][0], vues[cle]["point"][1]))
			ligne["glissement_px"] = maxf(float(ligne["glissement_px"]), derive)
		else:
			x0 = clampi(int(ecran.x) - RECADRAGE / 2, 0, maxi(0, img.get_width() - RECADRAGE))
			y0 = clampi(int(ecran.y) - RECADRAGE / 2, 0, maxi(0, img.get_height() - RECADRAGE))
			vues[cle] = {"point": [ecran.x, ecran.y], "vue": [img.get_width(), img.get_height()],
				"origine_du_recadrage": [x0, y0],
				"dans_la_vue": ecran.x >= 0.0 and ecran.y >= 0.0 and ecran.x < img.get_width() and ecran.y < img.get_height()}
		var coupe := img.get_region(Rect2i(x0, y0, RECADRAGE, RECADRAGE))
		var nom := "%s_%s_%s.png" % [ligne["nom"], cle, mode]
		coupe.save_png("%s/%s" % [_dossier, nom])
		(ligne["fichiers"] as Array).append(nom)
		_fichiers.append(nom)


## La vue entière de chaque joueur regardé, réduite de moitié : le cadrage, et la fusée dans son décor.
func _vue_entiere(base: String) -> void:
	var vues_regardees: Array = [_regarde] if _regarde >= 0 else [0, 1]
	var racine: Image = null
	if _regarde >= 0:
		var caches: Array[Node] = []
		for enfant in _ui.get_children():
			if (enfant is CanvasLayer or enfant is CanvasItem) and bool(enfant.get("visible")):
				enfant.set("visible", false)
				caches.append(enfant)
		racine = await Commun.capturer(get_tree(), 30000)
		for enfant in caches:
			if is_instance_valid(enfant):
				enfant.set("visible", true)
	else:
		await RenderingServer.frame_post_draw
	for k: int in vues_regardees:
		var img: Image = racine.duplicate() if racine != null else _iso.viewport_ecran(k).get_texture().get_image()
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
		img.save_png("%s/%s_J%d_vue.png" % [_dossier, base, k + 1])
