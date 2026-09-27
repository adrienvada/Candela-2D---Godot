extends "res://tools/photographe.gd"

## La planche des ENSEIGNES EN ESSAI (`--enseignes-essai`, `enseignes_iso.gd`) — le photographe, une séance à lui, sur le
## patron de `tools/photo_tuyaux.gd` (dont il reprend tels quels le maintien des joueurs, les prises d'un même instant et le
## relevé des appels de dessin).
##
## Devant une enseigne de la sorte demandée (`--sorte=ARENA` ou `--sorte=ZONE`) que la caméra de J1 dessine à son lacet, il
## prend dans le MÊME lancement, jeu en pause (même instant) :
##   A1 — avec les enseignes, torche allumée ;  S — sans (le nœud caché) ;  A2 — avec, de nouveau ;  M — leur emprise
##   (l'instrument `emprise_preuve` : les enseignes en blanc) ; puis N1, NS, MN — les mêmes, torches éteintes.
## Les mesures (lignes `MESURE`) : le bruit (A1 contre A2), les noirs allumés (seuil 7,5/255 et strict 0 → plus), les pixels
## plus clairs que sans EN LUMINANCE (Rec. 709 des valeurs sRGB, la règle des pochoirs) et au canal maximal, pour mémoire ;
## l'emprise, non vide, et ce qui s'y allume torches éteintes. `CADRE` imprime les coins de l'enseigne à l'écran, pour que
## la planche la recadre à 1:1 et à ×3.
##
## Voir J2 à 45° B, c'est voir la caméra de 225° : `--lacet=-135` pose ce lacet sur la caméra de J1 (la seule photographiée),
## qui dessine alors les enseignes des faces nord et ouest, celles de J2.
##
##     GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . res://tools/photo_enseignes.tscn \
##         -- --enseignes-essai --no-eos --lacet=0 --sorte=ARENA --sortie=user://enseignes_l0_arena
##
## Il EXIGE une vraie fenêtre, comme le photographe.

const EnseignesIsoT := preload("res://enseignes_iso.gd")
const TuyauxIsoT := preload("res://tuyaux_iso.gd")
const CARTE_ENSEIGNES := "res://assets/maps/map_001_le_cloitre.json"

var _j1 := Vector2.ZERO
var _visee_j1 := Vector2.UP
var _torches_allumees := true
var _lacet := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ la planche des enseignes exige une vraie fenêtre : ", refus)
		_sortir(1)
		return
	if not EnseignesIsoT.essai_actif():
		printerr("✗ lancer avec --enseignes-essai : sans lui, aucune enseigne n'est construite")
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", "user://photos_enseignes")
	_sans_hud = true
	_carte_duel = _valeur(args, "--carte-duel", CARTE_ENSEIGNES)
	var sorte := _valeur(args, "--sorte", "ARENA")
	_zoom = maxf(0.2, float(_valeur(args, "--zoom", "1.0")))
	_taille = _lire_taille(_valeur(args, "--taille", "%dx%d" % [TAILLE_DEFAUT.x, TAILLE_DEFAUT.y]))
	print("=== La planche des enseignes ===")
	_poser_la_fenetre()
	# Le cloud (`--fixed-fps 60`, rendu logiciel) : attentes et repos comptés en images de jeu, comme le photographe.
	await _lire_l_horloge()
	_mute_avant = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, true)
	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")
	_main.rendu_racine_autorise = false
	_main.archiver_les_matchs = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dossier))
	await _traiter_l_allumage([] as Array[Dictionary])

	_ui.hub.reset()
	_ui.hub.push(_ui.SCREEN_LOCAL)
	_main._on_replay_requested()
	if not await _attendre(func() -> bool: return _main.round_active, 20.0):
		printerr("✗ la manche n'a jamais démarré")
		_sortir(1)
		return
	_prendre_les_commandes()
	if not await _attendre(func() -> bool: return _main.countdown_left <= 0.0, 20.0):
		printerr("✗ le décompte n'a jamais fini")
		_sortir(1)
		return
	_torches(true)
	_vue_unique()
	await _passer_sur_la_carte_des_murs_bas()
	var reglages := get_node_or_null(^"/root/GameSettings")
	_lacet = float(reglages.call("lacet_de", 0)) if reglages != null else 0.0

	var c := EnseignesIsoT.construire(MapData.current_map_data)
	var choisie := {}
	for e in c["enseignes"]:
		var f: Dictionary = c["faces"][int(e["face"])]
		if String(e["sorte"]).begins_with(sorte) and TuyauxIsoT.face_dessinee(f["n"], _lacet):
			choisie = e
			break
	if choisie.is_empty():
		printerr("✗ aucune enseigne « %s » dessinée au lacet %s° sur %s" % [sorte, str(_lacet), _carte_duel])
		_sortir(1)
		return
	var face: Dictionary = c["faces"][int(choisie["face"])]
	var n: Vector2 = face["n"]
	var t := Vector2(-n.y, n.x)
	var pied := n * float(face["d"]) + t * float(choisie["s"])
	_j1 = pied + n * (3.2 * float(CandelaTileSet.TILE_SIZE.x)) + t * 20.0
	# Le cône en biais sur la face (`--biais=18`, degrés) : l'enseigne sous la lampe, son bord vers l'ombre.
	_visee_j1 = (-n).rotated(deg_to_rad(float(_valeur(args, "--biais", "18"))))
	print("  · « %s », face %s, J1 %s, lacet %s°" % [choisie["sorte"], str(face["cle"]), str(_j1), str(_lacet)])

	var iso := Presentation3D.instance()
	var noeud: MeshInstance3D = iso.get("_noeud_enseignes") if iso != null else null
	if noeud == null:
		printerr("✗ aucun nœud d'enseignes dans la présentation")
		_sortir(1)
		return
	var materiau := noeud.material_override as ShaderMaterial
	var suffixe := "lacet%d_%s" % [int(round(_lacet)), sorte.to_lower()]
	await _tenir_pendant(1.5)
	var sous_la_lampe := await _sandwich(noeud, materiau, ["A1", "S", "A2", "M"], ["avec", "sans", "avec", "emprise"])
	_torches_allumees = false
	_torches(false)
	await _tenir_pendant(1.2)
	var dans_le_noir := await _sandwich(noeud, materiau, ["N1", "NS", "MN"], ["avec", "sans", "emprise"])
	_torches_allumees = true
	_torches(true)
	for prises in [sous_la_lampe, dans_le_noir]:
		for cle in prises:
			(prises[cle] as Image).save_png(ProjectSettings.globalize_path("%s/enseignes_%s_%s.png" % [_dossier, suffixe, cle]))
	_mesurer(suffixe, sous_la_lampe, dans_le_noir)
	_cadre(face, choisie, (sous_la_lampe["A1"] as Image).get_size())

	await _relever_les_appels(noeud, "vue unique")
	AudioServer.set_bus_mute(0, _mute_avant)
	print("images : %s" % ProjectSettings.globalize_path(_dossier))
	_sortir(0)


## Les quatre coins de l'enseigne photographiée, en pixels de l'image : de quoi la recadrer sur la planche.
func _cadre(face: Dictionary, e: Dictionary, taille_image: Vector2i) -> void:
	var iso := Presentation3D.instance()
	var cam = iso.call("_camera_de", 0) if iso != null else null
	var vue: Viewport = iso.viewport_ecran(0) if iso != null else null
	if cam == null or vue == null:
		return
	var logique := vue.get_visible_rect().size
	var texte := "CADRE"
	for q in EnseignesIsoT.coins(face, e):
		var p: Vector2 = cam.vers_ecran(Vector2(q.x, q.z), logique, q.y) * Vector2(taille_image) / logique
		texte += " %.1f,%.1f" % [p.x, p.y]
	print(texte)


func _tenir() -> void:
	if not is_instance_valid(_main.p1) or not is_instance_valid(_main.p2):
		return
	_main.p1.global_position = _j1
	_main.p2.global_position = _j1 + Vector2(0.0, 4000.0)
	_viser(0, _visee_j1)
	_viser(1, Vector2.RIGHT)
	if _pantins.size() > 1:
		_pantins[0].torche = _torches_allumees
		_pantins[1].torche = false
	Input.action_release("p2_torch")
	_main.p2.flashlight_on = false
	if not _torches_allumees:
		_main.p1.flashlight_on = false
	_vivants()


func _tenir_pendant(secondes: float) -> void:
	var fin := _maintenant() + secondes
	while _maintenant() < fin:
		_tenir()
		await get_tree().process_frame
	_tenir()


## Les prises d'un même instant : l'arbre en pause ; entre deux images, seul change le nœud des enseignes (montré, caché) ou
## l'instrument de son emprise (les enseignes en blanc).
func _sandwich(noeud: MeshInstance3D, materiau: ShaderMaterial, cles: Array, modes: Array) -> Dictionary:
	var sortie := {}
	get_tree().paused = true
	await _attendre_images(3)
	for k in cles.size():
		noeud.visible = modes[k] != "sans"
		materiau.set_shader_parameter("emprise_preuve", modes[k] == "emprise")
		await _attendre_images(3)
		var img: Image = await _capturer("vue")
		if img == null:
			printerr("  ✗ prise %s perdue" % cles[k])
			img = Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
		img.convert(Image.FORMAT_RGBA8)
		sortie[cles[k]] = img
	noeud.visible = true
	materiau.set_shader_parameter("emprise_preuve", false)
	get_tree().paused = false
	return sortie


## Le plus fort des trois canaux de chaque pixel, en 0..255.
func _maxima(img: Image) -> PackedByteArray:
	var octets := img.get_data()
	var sortie := PackedByteArray()
	sortie.resize(octets.size() / 4)
	for i in sortie.size():
		sortie[i] = maxi(octets[4 * i], maxi(octets[4 * i + 1], octets[4 * i + 2]))
	return sortie


## Les pixels où deux images diffèrent, sur un canal au moins.
func _ecarts(a: Image, b: Image) -> PackedByteArray:
	var oa := a.get_data()
	var ob := b.get_data()
	var sortie := PackedByteArray()
	sortie.resize(oa.size() / 4)
	for i in sortie.size():
		sortie[i] = 1 if (oa[4 * i] != ob[4 * i] or oa[4 * i + 1] != ob[4 * i + 1] or oa[4 * i + 2] != ob[4 * i + 2]) else 0
	return sortie


## La luminance Rec. 709 des valeurs sRGB de chaque pixel, en 0..255 (la règle « jamais plus clair » des pochoirs).
func _luminances(img: Image) -> PackedFloat32Array:
	var octets := img.get_data()
	var sortie := PackedFloat32Array()
	sortie.resize(octets.size() / 4)
	for i in sortie.size():
		sortie[i] = 0.2126 * octets[4 * i] + 0.7152 * octets[4 * i + 1] + 0.0722 * octets[4 * i + 2]
	return sortie


## Les mesures de la planche, imprimées `MESURE` : le noir, dans toute l'image et SUR l'emprise des enseignes (non vide) ;
## les pixels plus clairs que sans, en luminance (la règle) et au canal maximal (pour mémoire).
func _mesurer(suffixe: String, lampe: Dictionary, noir: Dictionary) -> void:
	var seuil := 7.5
	var bruit := _ecarts(lampe["A1"], lampe["A2"]).count(1)
	print("MESURE %s bruit (A1 contre A2, même instant) : %d pixels différents" % [suffixe, bruit])
	for cas in [["torche allumée", lampe["A1"], lampe["S"], lampe["M"]], ["torches éteintes", noir["N1"], noir["NS"], noir["MN"]]]:
		var avec := _maxima(cas[1])
		var sans := _maxima(cas[2])
		var l_avec := _luminances(cas[1])
		var l_sans := _luminances(cas[2])
		var emprise := _ecarts(cas[3], cas[2])
		var changes := _ecarts(cas[1], cas[2]).count(1)
		var n_emprise := 0
		var emprise_allumee := 0
		var emprise_strict := 0
		var emprise_eclairee := 0
		var assombris := 0
		var noirs := 0
		var noirs_stricts := 0
		var plus_clairs_lum := 0
		var plus_clairs_canal := 0
		var pire := ""
		for i in avec.size():
			var a := avec[i]
			var s := sans[i]
			if s <= seuil and a > seuil:
				noirs += 1
			if s == 0 and a > 0:
				noirs_stricts += 1
			if l_avec[i] > l_sans[i] + 0.001:
				plus_clairs_lum += 1
				if pire == "":
					pire = " (premier : pixel %d, %.1f → %.1f)" % [i, l_sans[i], l_avec[i]]
			if a > s + 1:
				plus_clairs_canal += 1
			if l_avec[i] < l_sans[i] - 0.001:
				assombris += 1
			if emprise[i] == 1:
				n_emprise += 1
				if s > seuil:
					emprise_eclairee += 1
				if a > seuil:
					emprise_allumee += 1
				if a > 0:
					emprise_strict += 1
		print("MESURE %s %s : %d pixels d'emprise des enseignes à l'écran (%d sur un mur éclairé au-dessus de 7,5/255), dont %d au-dessus de 7,5/255 et %d au-dessus de 0 avec elles ; %d pixels changés, %d assombris" % [
			suffixe, cas[0], n_emprise, emprise_eclairee, emprise_allumee, emprise_strict, changes, assombris])
		print("MESURE %s %s : noirs allumés %d (seuil 7,5), %d (stricts, 0 → plus) ; plus clairs que sans %d en luminance%s, %d au canal maximal (+2 ou plus)" % [
			suffixe, cas[0], noirs, noirs_stricts, plus_clairs_lum, pire, plus_clairs_canal])


## Les appels de dessin et les primitives de l'image entière (le serveur de rendu, toutes vues comprises), enseignes montrées
## puis cachées, en moyenne sur vingt images, torche allumée.
func _relever_les_appels(noeud: MeshInstance3D, ou: String) -> void:
	var iso := Presentation3D.instance()
	# Les vues qui rendent la 3D : la fenêtre en vue unique, les deux sous-vues iso en écran scindé.
	var vues: Array[Viewport] = [get_window()]
	for v in (iso.get("_vues3d") as Array if iso != null else []):
		if (v as SubViewport).render_target_update_mode != SubViewport.UPDATE_DISABLED:
			vues.append(v as Viewport)
	for montre in [true, false]:
		noeud.visible = montre
		var total := PackedInt32Array()
		var prims := PackedInt32Array()
		var par_vue := PackedInt32Array()
		await _attendre_images(5)
		for k in 20:
			_tenir()
			await get_tree().process_frame
			total.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			prims.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
			var s := 0
			for v in vues:
				s += v.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
			par_vue.append(s)
		print("MESURE appels %s lacet %d° %s enseignes : total %s (min %d, max %d), primitives %s (min %d, max %d), passe visible des vues 3D %s (min %d, max %d)" % [
			ou, int(round(_lacet)), "AVEC" if montre else "SANS", _moyenne(total), _min(total), _max(total),
			_moyenne(prims), _min(prims), _max(prims), _moyenne(par_vue), _min(par_vue), _max(par_vue)])
	noeud.visible = true


func _moyenne(a: PackedInt32Array) -> String:
	var s := 0
	for v in a:
		s += v
	return "%.1f" % (float(s) / maxf(1.0, float(a.size())))


func _min(a: PackedInt32Array) -> int:
	var m := 1 << 40
	for v in a:
		m = mini(m, v)
	return m


func _max(a: PackedInt32Array) -> int:
	var m := -1
	for v in a:
		m = maxi(m, v)
	return m
