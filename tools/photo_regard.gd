extends "res://tools/photo_peinture_perimee.gd"

## CE QUE L'INTERFACE LAISSE PAR-DESSUS LE MATCH — une séance du photographe (session cloud « restes », 2026-09-28).
## Aucun défaut du jeu ne change.
##
## La question (RAPPORT disque-violace, piège 5) : `ui._set_focus` pose la torche du menu (corrigée à part), le fond de
## menu (`menu_backdrop.viser`) et le regard (`menu_watcher.reveiller`). Restent-ils actifs ou peints pendant le match ?
## Plus largement : que laisse l'interface allumé dans le noir, torches éteintes ?
##
## Une manche lancée depuis le menu comme un joueur (`--mode=scinde` : l'écran 1v1 local puis JOUER ; `--mode=unique` :
## l'accueil puis ENTRAÎNEMENT, la vue unique), torches éteintes, personne ne bouge. Prises de l'ÉCRAN (interface
## comprise — les prises « vue » la cachent, un défaut d'interface y est invisible), chacune en paire :
##   <nom>_ui     — l'écran tel que le joueur le voit ;
##   <nom>_sansui — le calque d'interface (`Main/UI`) caché.
## Un pixel noir (≤ 7) dans `_sansui` et allumé dans `_ui` est un pixel que l'interface allume dans le noir. La ligne
## `FUITE` les compte ; `DESCENTE` cache un à un les enfants de l'interface qui dessinent et dit lesquels les éteignent.
## Instants : `t08` (8 s de jeu) et `regard` (le regard du noir, s'il vient, à la moitié de sa vie ; attendu jusqu'à
## 40 s de jeu). Le regard vit en `PROCESS_MODE_ALWAYS` : il est figé (`set_process(false)`) le temps d'une paire,
## puis relâché — la pause du jeu ne l'arrêterait pas.
##
##     GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . \
##         res://tools/photo_regard.tscn -- --no-eos --led-murs-fige --mode=scinde --sortie=user://regard/scinde
##
## Il EXIGE une vraie fenêtre, comme le photographe.

var _mode := "scinde"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	seed(int(_valeur(args, "--graine", "20260928")))
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ la séance exige une vraie fenêtre : ", refus)
		_sortir(1)
		return
	_mode = _valeur(args, "--mode", "scinde")
	_dossier = _valeur(args, "--sortie", "user://regard/%s" % _mode)
	_chemin = _mode
	_sans_hud = true
	_taille = _lire_taille(_valeur(args, "--taille", "%dx%d" % [TAILLE_DEFAUT.x, TAILLE_DEFAUT.y]))
	print("=== Ce que l'interface laisse sur le match — %s ===" % _mode)
	print("  drapeaux : %s" % " ".join(args))
	_poser_la_fenetre()
	await _lire_l_horloge()
	if _pas_fixe <= 0.0:
		printerr("✗ lancer avec --fixed-fps 60")
		_sortir(1)
		return
	_mute_avant = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, true)
	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")
	_main.archiver_les_matchs = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dossier))
	for enfant in _main.get_children():
		if enfant.get_script() == preload("res://intro_planches.gd"):
			enfant.emit_signal("terminee")
	await _traiter_l_allumage([] as Array[Dictionary])

	# --- Le menu, comme un joueur : l'écran du mode (sa graine de focus pose curseurs, torche, fond et regard), JOUER.
	_ui.hub.reset()
	await _attendre_images(20)
	if _mode == "unique":
		_ui._on_hub_action("entrainement")
		await _attendre(func() -> bool: return _main.training_mode and _main.sandbox_mode, 30.0)
	else:
		_ui.hub.push(_ui.SCREEN_LOCAL)
		await _attendre_images(20)
		_main._on_replay_requested()
	if not await _manche_prete():
		return
	_torches(false)
	for action in ["p1_torch", "p2_torch"]:
		Input.action_release(action)
	var depart := _secondes()
	print("MANCHE : vue %s, écran scindé %s, menu ouvert %s" % [
		"iso" if GameSettings.mode_iso else "de dessus", str(_main.vp2.get_parent().visible), str(_ui._is_main_menu)])
	_etat_des_effets("début de manche")

	while _secondes() - depart < 8.0:
		await get_tree().process_frame
	await _paire("t08")

	var regard: Node = _ui.get("menu_watcher")
	var vu := false
	while _secondes() - depart < 40.0:
		if regard != null and float(regard.get("_vie")) > 0.0 and float(regard.get("_vie")) < 0.6 * 2.5:
			vu = true
			break
		await get_tree().process_frame
	_etat_des_effets("après %.1f s de jeu" % (_secondes() - depart))
	if vu:
		regard.set_process(false)
		print("REGARD venu à %.1f s de jeu, à %s" % [_secondes() - depart, str(regard.get("_pos"))])
		await _paire("regard")
		regard.set_process(true)
	else:
		print("REGARD jamais venu en 40 s de jeu")
		await _paire("t40")
	AudioServer.set_bus_mute(0, _mute_avant)
	print("images : %s" % ProjectSettings.globalize_path(_dossier))
	_sortir(0)


func _secondes() -> float:
	return float(Engine.get_process_frames()) * _pas_fixe


## Les effets de vitrine que `_set_focus` et les écrans posent, tels qu'ils sont.
func _etat_des_effets(etape: String) -> void:
	var t: Node = _ui.get("menu_torch")
	var r: Node = _ui.get("menu_watcher")
	var a: Node = _ui.get("menu_after_image")
	var tr: Node = _ui.get("menu_tracer")
	print("EFFETS %s : torche %s (cibles %d) · regard visible %s, traitement %s, repos %.1f s, vie %.2f · rémanence %d fantômes · traçante t %.2f · hub visible %s" % [
		etape, str(t.is_visible_in_tree()) if t else "-", (t.get("_cibles") as Dictionary).size() if t else -1,
		str(r.is_visible_in_tree()) if r else "-", str(r.is_processing()) if r else "-",
		float(r.get("_repos")) if r else -1.0, float(r.get("_vie")) if r else -1.0,
		(a.get("_fantomes") as Array).size() if a else -1, float(tr.get("_t")) if tr else -9.0,
		str(_ui.hub.is_visible_in_tree())])


## Une paire de prises (interface / sans interface), le compte des pixels que l'interface allume dans le noir, et, s'il
## y en a, la descente parmi les enfants de l'interface.
func _paire(nom: String) -> void:
	var avec: Image = await _prise_ecran("%s_ui" % nom)
	_ui.visible = false
	await _attendre_images(2)
	var sans: Image = await _prise_ecran("%s_sansui" % nom)
	_ui.visible = true
	await _attendre_images(2)
	if avec == null or sans == null:
		return
	var fuite := _fuite(avec, sans)
	print("FUITE %s : %d pixels noirs sans l'interface, allumés avec (boîte %s, max %d/255)" % [
		nom, fuite["n"], str(fuite["boite"]), fuite["max"]])
	# La descente : chaque enfant de l'interface qui dessine, caché seul ; on garde ceux qui éteignent des pixels de fuite
	# HORS du HUD (le HUD allume légitimement ses propres cadres : on ne compte que les pixels qui changent).
	for enfant in _ui.get_children():
		if not (enfant is CanvasItem) or not (enfant as CanvasItem).visible:
			continue
		(enfant as CanvasItem).visible = false
		await _attendre_images(2)
		var img: Image = await _capturer("ecran")
		(enfant as CanvasItem).visible = true
		await _attendre_images(1)
		if img == null:
			continue
		img.convert(Image.FORMAT_RGB8)
		var eteints := _eteints(avec, img, sans)
		if eteints > 0:
			print("DESCENTE %s : %s (%s) éteint %d pixels de fuite" % [nom, enfant.name, enfant.get_class(), eteints])


func _prise_ecran(nom: String) -> Image:
	var img: Image = await _capturer("ecran")
	if img == null:
		printerr("  ✗ prise %s perdue" % nom)
		_perdues += 1
		return null
	img.convert(Image.FORMAT_RGB8)
	img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [_dossier, nom]))
	print("PRISE %s %s" % [_mode, nom])
	return img


func _fuite(avec: Image, sans: Image) -> Dictionary:
	var n := 0
	var mx := 0
	var boite := Rect2i()
	var a := avec.get_data()
	var s := sans.get_data()
	var w := avec.get_width()
	for i in range(0, a.size(), 3):
		var ms := maxi(s[i], maxi(s[i + 1], s[i + 2]))
		if ms > 7:
			continue
		var ma := maxi(a[i], maxi(a[i + 1], a[i + 2]))
		if ma > 7:
			n += 1
			mx = maxi(mx, ma)
			var p := Vector2i((i / 3) % w, (i / 3) / w)
			boite = Rect2i(p, Vector2i.ONE) if n == 1 else boite.expand(p)
	return {"n": n, "max": mx, "boite": boite}


## Les pixels de fuite (noirs sans l'interface, allumés avec) qu'un enfant caché ramène au noir.
func _eteints(avec: Image, sans_enfant: Image, sans: Image) -> int:
	var n := 0
	var a := avec.get_data()
	var e := sans_enfant.get_data()
	var s := sans.get_data()
	for i in range(0, a.size(), 3):
		if maxi(s[i], maxi(s[i + 1], s[i + 2])) > 7 or maxi(a[i], maxi(a[i + 1], a[i + 2])) <= 7:
			continue
		if maxi(e[i], maxi(e[i + 1], e[i + 2])) <= 7:
			n += 1
	return n
