extends "res://tools/photographe.gd"

## La planche des TUYAUX EN ESSAI (`--tuyaux-essai`, `tuyaux_iso.gd`) — le photographe, une seule séance à lui.
##
## Il hérite de tout (fenêtre, manche locale, marionnettes, carte du duel, capture de la vue iso sans l'interface) — sans
## toucher `photographe.gd` — et ne fait qu'une chose : devant une face de mur qui porte des tuyaux, prendre dans le MÊME
## lancement, jeu en pause (même instant) :
##   A1 — avec les tuyaux, torche allumée ;  S — sans (le nœud caché) ;  A2 — avec, de nouveau ;  M — l'emprise des tuyaux
##   (l'instrument `emprise_preuve` : les tuyaux en blanc) ; puis N1, NS, MN — les mêmes, torches éteintes.
## A1 contre A2 dit le bruit (0 attendu : le jeu est figé) ; A contre S dit ce que les tuyaux changent ; M contre S, où ils
## sont — un zéro compté sur une emprise non vide. Les mesures (lignes `MESURE`) : noirs allumés au seuil de 7,5/255 et au
## pixel strict (0 → plus), pixels plus clairs que sans, et les pixels d'emprise au-dessus de 7,5/255 et de 0. Une
## comparaison entre deux LANCEMENTS ne prouverait rien (ROADMAP, usure, levier 1). Il relève aussi les appels de dessin et
## les primitives de l'image, tuyaux montrés puis cachés, en vue unique puis en écran scindé, et imprime `REPERES` : les
## coins du pilier projetés, pour en tracer le contour sur la planche là où il est noir.
##
##     xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . res://tools/photo_tuyaux.tscn -- --tuyaux-essai --no-eos \
##         --zoom=2.5 --lacet=0 --biais=28 --sortie=user://final_l0_bord
##     … `--lacet=45`, `--biais=0` (la face entière sous la lampe) ; `docs/iso/tuyaux/planche_tuyaux.py` monte la planche.
##
## Il EXIGE une vraie fenêtre, comme le photographe.

const TuyauxIsoT := preload("res://tuyaux_iso.gd")
const CARTE_TUYAUX := "res://assets/maps/map_001_le_cloitre.json"
## Le seuil du noir : 7,5/255, c'est-à-dire tout pixel qui s'affiche à 8/255 ou plus sur l'un de ses canaux.
const SEUIL_NOIR := 7.5 / 255.0

var _j1 := Vector2.ZERO
var _visee_j1 := Vector2.UP
var _torches_allumees := true
var _lacet := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ la planche des tuyaux exige une vraie fenêtre : ", refus)
		_sortir(1)
		return
	if not TuyauxIsoT.essai_actif():
		printerr("✗ lancer avec --tuyaux-essai : sans lui, aucun tuyau n'est construit")
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", "user://photos_tuyaux")
	_sans_hud = true
	_carte_duel = _valeur(args, "--carte-duel", CARTE_TUYAUX)
	# Le cadrage : celui du jeu par défaut (`--zoom` absent) ; `--zoom=3` pour la loupe. Déclaré à la console.
	_zoom = maxf(0.2, float(_valeur(args, "--zoom", "1.0")))
	_taille = _lire_taille(_valeur(args, "--taille", "%dx%d" % [TAILLE_DEFAUT.x, TAILLE_DEFAUT.y]))
	print("=== La planche des tuyaux ===")
	_poser_la_fenetre()
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

	var face := _choisir_la_face(MapData.current_map_data)
	if face.is_empty():
		printerr("✗ aucune face meublée tournée vers la caméra sur %s" % _carte_duel)
		_sortir(1)
		return
	var n: Vector2 = face["n"]
	var t := Vector2(-n.y, n.x)
	var milieu := (float(face["s0"]) + float(face["s1"])) * 0.5
	var pied := n * float(face["d"]) + t * milieu
	_j1 = pied + n * (3.2 * float(CandelaTileSet.TILE_SIZE.x)) + t * 20.0
	# Le cône en biais sur la face (`--biais=28`, degrés) : une partie des tuyaux dans la lumière, l'autre dans le noir, et le
	# bord entre les deux. `--biais=0` : la face entière sous la lampe.
	_visee_j1 = (-n).rotated(deg_to_rad(float(_valeur(args, "--biais", "28"))))
	print("  · face %s, %d cases, J1 %s, lacet %s°" % [str(face["cle"]), int(face["cases"]), str(_j1), str(_lacet)])

	var iso := Presentation3D.instance()
	var noeud: MeshInstance3D = iso.get("_noeud_tuyaux") if iso != null else null
	if noeud == null:
		printerr("✗ aucun nœud de tuyaux dans la présentation")
		_sortir(1)
		return
	var materiau := noeud.material_override as ShaderMaterial
	var suffixe := "lacet%d" % int(round(_lacet))
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
			(prises[cle] as Image).save_png(ProjectSettings.globalize_path("%s/tuyaux_%s_%s.png" % [_dossier, suffixe, cle]))
	_mesurer(suffixe, sous_la_lampe, dans_le_noir)
	_reperes(face, (sous_la_lampe["A1"] as Image).get_size())

	await _relever_les_appels(noeud, "vue unique")
	_deux_vues()
	await _tenir_pendant(1.0)
	await _relever_les_appels(noeud, "écran scindé")
	_vue_unique()
	AudioServer.set_bus_mute(0, _mute_avant)
	print("images : %s" % ProjectSettings.globalize_path(_dossier))
	_sortir(0)


## La face à photographier : une face sud intérieure (la caméra de J1 la voit à 0° comme à 45°) qui porte le plus de
## sortes de pièces — conduite et câbles d'abord, puis conduite et descente —, la plus longue à égalité.
func _choisir_la_face(data: Dictionary) -> Dictionary:
	var faces := TuyauxIsoT.faces(data)
	var grille := Vector2(MapCodec.get_grid_size(data)) * float(CandelaTileSet.TILE_SIZE.x)
	var rang_de := {1: 3, 3: 2, 0: 1, 2: 1}
	var meilleure := {}
	var meilleur := -1
	for f in faces:
		var n: Vector2 = f["n"]
		if n != Vector2(0, 1) or int(f["cases"]) < 3:
			continue
		var d := float(f["d"])
		if d < 4.0 * 35.0 or d > grille.y - 6.0 * 35.0:
			continue
		var rang := int(rang_de.get(TuyauxIsoT.programme_de(f), 0)) * 100 + int(f["cases"])
		if rang > meilleur:
			meilleur = rang
			meilleure = f
	return meilleure


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
	var fin := Time.get_ticks_msec() + int(secondes * 1000.0)
	while Time.get_ticks_msec() < fin:
		_tenir()
		await get_tree().process_frame
	_tenir()


## Les coins de la boîte de mur derrière la face photographiée, en pixels de l'image (au sol et à l'arête) : de quoi poser
## le dessin du mur sur la planche, là où il est noir, pour juger à l'œil que l'emprise des tuyaux reste sur ses faces.
func _reperes(face: Dictionary, taille_image: Vector2i) -> void:
	var iso := Presentation3D.instance()
	var cam = iso.call("_camera_de", 0) if iso != null else null
	var vue: Viewport = iso.viewport_ecran(0) if iso != null else null
	if cam == null or vue == null:
		return
	var logique := vue.get_visible_rect().size
	var h := TuyauxIsoT.hauteur_mur_px()
	var n: Vector2 = face["n"]
	var t := Vector2(-n.y, n.x)
	var coin := n * float(face["d"])
	var a := coin + t * float(face["s0"])
	var b := coin + t * float(face["s1"])
	# La boîte : la longueur de la face vers l'intérieur du mur (le pilier photographié est carré ; sinon, un repère
	# approché, dit comme tel).
	var profondeur := float(face["s1"]) - float(face["s0"])
	var coins := [a, b, b - n * profondeur, a - n * profondeur]
	var texte := "REPERES"
	for p in coins:
		for y in [0.0, h]:
			var e: Vector2 = cam.vers_ecran(p, logique, y) * Vector2(taille_image) / logique
			texte += " %.1f,%.1f" % [e.x, e.y]
	print(texte)


## Les prises d'un même instant : l'arbre en pause ; entre deux images, seul change le nœud des tuyaux (montré, caché) ou
## l'instrument de son emprise (les tuyaux en blanc).
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


## Les mesures de la planche, imprimées `MESURE` : le noir, dans toute l'image et SUR l'emprise des tuyaux (non vide).
## 7,5/255 : un pixel qui s'affiche à 8 ou plus sur un canal. « Strict » : 0 sans les tuyaux, plus de 0 avec.
func _mesurer(suffixe: String, lampe: Dictionary, noir: Dictionary) -> void:
	var seuil := 7.5
	var bruit := _ecarts(lampe["A1"], lampe["A2"]).count(1)
	print("MESURE %s bruit (A1 contre A2, même instant) : %d pixels différents" % [suffixe, bruit])
	for cas in [["torche allumée", lampe["A1"], lampe["S"], lampe["M"]], ["torches éteintes", noir["N1"], noir["NS"], noir["MN"]]]:
		var avec := _maxima(cas[1])
		var sans := _maxima(cas[2])
		var emprise := _ecarts(cas[3], cas[2])
		var changes := _ecarts(cas[1], cas[2]).count(1)
		var n_emprise := 0
		var emprise_allumee := 0
		var emprise_strict := 0
		var noirs := 0
		var noirs_stricts := 0
		var au_dessus_avec := 0
		var au_dessus_sans := 0
		var plus_clairs := 0
		for i in avec.size():
			var a := avec[i]
			var s := sans[i]
			if a > seuil:
				au_dessus_avec += 1
			if s > seuil:
				au_dessus_sans += 1
			if s <= seuil and a > seuil:
				noirs += 1
			if s == 0 and a > 0:
				noirs_stricts += 1
			if a > s + 1:
				plus_clairs += 1
			if emprise[i] == 1:
				n_emprise += 1
				if a > seuil:
					emprise_allumee += 1
				if a > 0:
					emprise_strict += 1
		print("MESURE %s %s : %d pixels d'emprise des tuyaux à l'écran, dont %d au-dessus de 7,5/255 et %d au-dessus de 0 ; %d pixels changés par les tuyaux" % [
			suffixe, cas[0], n_emprise, emprise_allumee, emprise_strict, changes])
		print("MESURE %s %s : image entière, %d pixels au-dessus de 7,5/255 avec les tuyaux, %d sans ; noirs allumés %d (seuil 7,5), %d (stricts, 0 → plus) ; plus clairs que sans %d" % [
			suffixe, cas[0], au_dessus_avec, au_dessus_sans, noirs, noirs_stricts, plus_clairs])


## Les appels de dessin et les primitives de l'image entière (le serveur de rendu, toutes vues comprises), tuyaux montrés
## puis cachés, en moyenne sur vingt images, torche allumée.
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
		print("MESURE appels %s lacet %d° %s tuyaux : total %s (min %d, max %d), primitives %s (min %d, max %d), passe visible des vues 3D %s (min %d, max %d)" % [
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
