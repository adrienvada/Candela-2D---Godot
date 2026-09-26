extends Node
## LE PILOTE DE LA RÉPÉTITION — rejoue sous Xvfb ce qu'Adrien fera à la main.
##
## Session cloud `claude/cloud-repetition` (2026-09-27). Il monte `main.tscn` comme scène
## COURANTE (et non comme enfant, comme le photographe) : l'éditeur de cartes s'ouvre par
## `change_scene_to_file`, qui libère la scène courante — le pilote, frère de la scène sous
## la racine, survit au changement et peut revenir.
##
## Il passe par les gestes du joueur autant que possible : les entrées du hub sont
## « cliquées » (`pressed.emit()`, le signal même d'un clic), F3 et F6 sont de vraies
## touches injectées (`Input.parse_input_event`), l'intro se saute à la touche. Les joueurs,
## eux, sont tenus par une marionnette (le point d'entrée prévu : `_set_player_input_provider`),
## faute de mains sous Xvfb.
##
## Chaque étape imprime `[pilote] >>> <étape>` : le journal de la console se découpe
## ainsi étape par étape, et chaque erreur se rattache à ce qui l'a produite.
##
##   GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" \
##     ./tools/cloud_repetition/run_pilote.sh --etapes=menus,local,entrainement,editeur,diag
##
## Les images (JPEG) vont dans `--sortie=<dossier absolu>`.

const Commun := preload("res://tools/rendu_commun.gd")

const ETAPES := ["demarrage", "menus", "local", "entrainement", "editeur", "diag", "quitter"]

class Marionnette extends InputProvider:
	var visee := Vector2.RIGHT
	var torche := true
	var tir := false
	var marche := Vector2.ZERO

	func get_movement_vector() -> Vector2:
		return marche

	func get_aim_direction(_pos: Vector2) -> Vector2:
		return visee

	func is_shoot_pressed() -> bool:
		return tir

	func is_flashlight_pressed() -> bool:
		return torche

	func is_flare_pressed() -> bool:
		return false

	func is_reload_pressed() -> bool:
		return false


var _main: Node
var _ui: Node
var _sortie := ""
var _etapes: Array = []
var _cartes: Array = []
var _images := 0
var _bilan: Array[String] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_sortie = _valeur(args, "--sortie", ProjectSettings.globalize_path("user://repetition"))
	DirAccess.make_dir_recursive_absolute(_sortie)
	_etapes = _valeur(args, "--etapes", ",".join(ETAPES)).split(",", false)
	var cartes := _valeur(args, "--cartes", "")
	if cartes != "":
		_cartes = Array(cartes.split(",", false))
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("[pilote] ✗ ", refus)
		get_tree().quit(1)
		return
	var fenetre := DisplayServer.window_get_size()
	if get_window().size != fenetre:
		get_window().size = fenetre
	print("[pilote] fenêtre %s, rendu %s, carte graphique %s" % [
		get_window().size, RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name()])
	# Le pilote est la scène de départ ; il cède la place de scène courante au jeu.
	await get_tree().process_frame
	_main = load("res://main.tscn").instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")
	var manquants := Commun.preconditions_manquantes(_ui, _main)
	if not manquants.is_empty():
		printerr("[pilote] ✗ appuis manquants : ", manquants)
		get_tree().quit(1)
		return
	# Comme le photographe : ne pas écrire de faux matchs dans l'historique.
	_main.archiver_les_matchs = false
	await _lancer()


func _lancer() -> void:
	if "demarrage" in _etapes:
		await _etape_demarrage()
	else:
		await _passer_les_ceremonies()
	if "menus" in _etapes:
		await _etape_menus()
	if "local" in _etapes:
		for slug in _slugs():
			await _etape_local(slug)
	if "entrainement" in _etapes:
		for slug in _slugs():
			await _etape_entrainement(slug)
	if "diag" in _etapes:
		await _etape_diag()
	if "editeur" in _etapes:
		await _etape_editeur()
	print("\n[pilote] === BILAN ===")
	for ligne in _bilan:
		print("[pilote] ", ligne)
	print("[pilote] %d image(s) dans %s" % [_images, _sortie])
	if "quitter" in _etapes:
		print("[pilote] >>> quitter (chemin du jeu : QUITTER du menu)")
		_marquer("quitter")
		if is_instance_valid(_main) and _main.has_method("_on_quit_requested"):
			_main._on_quit_requested()
			return
	get_tree().quit(0)


# ---------------------------------------------------------------------------
# ÉTAPES
# ---------------------------------------------------------------------------

func _etape_demarrage() -> void:
	_marquer("demarrage")
	var intro := _main.get_node_or_null("IntroPlanches")
	var allumage := _main.get_node_or_null("PowerOn")
	_noter("démarrage : intro %s, allumage %s" % [intro != null, allumage != null])
	await _images_de_jeu(20)
	await _capturer("00_demarrage_premiere_image")
	if intro != null:
		await _images_de_jeu(240)
		await _capturer("01_intro_planche")
		# Se saute à la touche, comme le joueur.
		await _touche(KEY_SPACE)
		await _attendre(func() -> bool: return _main.get_node_or_null("IntroPlanches") == null, 30.0)
	if allumage != null:
		await _attendre(func() -> bool: return _main.get_node_or_null("PowerOn") == null, 15.0)
	await _images_de_jeu(30)
	await _capturer("02_accueil")


func _passer_les_ceremonies() -> void:
	var intro := _main.get_node_or_null("IntroPlanches")
	if intro != null:
		await _touche(KEY_SPACE)
		await _attendre(func() -> bool: return _main.get_node_or_null("IntroPlanches") == null, 30.0)
	var allumage := _main.get_node_or_null("PowerOn")
	if allumage != null and allumage.has_method("terminer"):
		allumage.terminer()
	await _attendre(func() -> bool: return _main.get_node_or_null("PowerOn") == null, 15.0)
	await _images_de_jeu(10)


func _etape_menus() -> void:
	_marquer("menus")
	var hub = _ui.hub
	hub.reset()
	await _images_de_jeu(20)
	await _capturer("10_hub_accueil")
	# Créer local : l'entrée « 1V1 ÉCRANS SCINDÉS » de l'accueil.
	await _cliquer("1V1 ÉCRANS SCINDÉS")
	await _capturer("11_salon_local")
	await _cliquer("CHANGER DE CARTE")
	await _capturer("12_choix_de_carte")
	await _cliquer("PRÉPARER LE MATCH")
	await _capturer("13_salon_des_armes")
	hub.reset()
	await _images_de_jeu(10)
	await _cliquer("PERSONNALISATION")
	await _capturer("14_personnalisation")
	var liste = hub.list_of(hub.current_id())
	var i := 0
	if liste != null:
		for enfant in liste.get_children():
			var btn := enfant as Button
			if btn == null or btn.disabled:
				continue
			var nom := _libelle(btn)
			if nom.begins_with("‹") or nom.to_upper().ends_with("RETOUR"):
				continue
			i += 1
			btn.grab_focus()
			btn.pressed.emit()
			await _images_de_jeu(20)
			await _capturer("15_reglages_%02d_%s" % [i, _ardoise(nom)])
	hub.reset()
	await _cliquer("S'ENTRAÎNER")
	await _capturer("16_ecran_entrainement")
	hub.reset()
	await _cliquer("1V1 AMICAL")
	await _capturer("17_amical")
	hub.reset()
	await _images_de_jeu(10)


## Un match local 1v1 (écran scindé) sur une carte choisie dans la galerie du salon.
func _etape_local(slug: String) -> void:
	_marquer("local " + slug)
	var hub = _ui.hub
	hub.reset()
	await _images_de_jeu(5)
	await _cliquer("1V1 ÉCRANS SCINDÉS")
	await _cliquer("CHANGER DE CARTE")
	if not await _choisir_la_carte(slug):
		return
	await _capturer("20_%s_galerie" % slug)
	await _cliquer("PRÉPARER LE MATCH")
	var lanceur: Button = _ui.panel_launch
	if lanceur == null or not lanceur.visible or lanceur.disabled:
		_noter("✗ local %s : bouton de lancement absent ou grisé" % slug)
		return
	_noter("local %s : bouton « %s », action %s" % [slug, lanceur.text,
		lanceur.get_meta(_ui.META_LAUNCH_ACTION, "?")])
	lanceur.pressed.emit()
	if not await _attendre(func() -> bool: return _main.round_active, 30.0):
		_noter("✗ local %s : la manche n'a jamais démarré" % slug)
		return
	var carte_jouee: String = String(MapData.selected_map_id)
	_noter("local %s : carte jouée id=%s, mode_rendu=%s, lacet J1=%.0f J2=%.0f, zoom=%.2f, décalage=%.2f, écran scindé=%s" % [
		slug, carte_jouee, GameSettings.mode_rendu(), GameSettings.lacet_de(0), GameSettings.lacet_de(1),
		GameSettings.zoom_duel, GameSettings.decalage_visee, _deux_vues_visibles()])
	await _images_de_jeu(30)
	await _capturer("21_%s_decompte" % slug)
	await _attendre(func() -> bool: return _main.countdown_left <= 0.0, 20.0)
	var pantins := _poser_les_marionnettes()
	# Les deux joueurs marchent un peu, torche allumée.
	for k in 90:
		pantins[0].marche = Vector2(1, 0).rotated(float(k) * 0.03)
		pantins[1].marche = Vector2(-1, 0).rotated(float(k) * 0.03)
		await get_tree().process_frame
	pantins[0].marche = Vector2.ZERO
	pantins[1].marche = Vector2.ZERO
	await _images_de_jeu(10)
	await _capturer("22_%s_ecran_scinde" % slug)
	await _tuer(pantins, slug)
	# La killcam.
	if await _attendre(func() -> bool: return ReplaySystem.playing_back, 20.0):
		await _images_de_jeu(60)
		await _capturer("23_%s_killcam" % slug)
		await _attendre(func() -> bool: return not ReplaySystem.playing_back, 40.0)
	else:
		_noter("✗ local %s : pas de killcam" % slug)
	await _images_de_jeu(90)
	await _capturer("24_%s_fin" % slug)
	_noter("local %s : game_over=%s, écran de fin visible=%s" % [slug, _main.game_over,
		_ui.game_over_panel.visible if _ui.game_over_panel != null else "?"])
	await _vers_le_menu()


## L'entraînement, après avoir choisi la carte `slug` dans son écran.
func _etape_entrainement(slug: String) -> void:
	_marquer("entrainement " + slug)
	var hub = _ui.hub
	hub.reset()
	await _images_de_jeu(5)
	await _cliquer("S'ENTRAÎNER")
	await _cliquer("CHANGER DE CARTE")
	if not await _choisir_la_carte(slug):
		return
	var choisie := String(MapData.selected_map_id)
	await _cliquer("PRÉPARER L'ENTRAÎNEMENT")
	var lanceur: Button = _ui.panel_launch
	if lanceur == null or not lanceur.visible or lanceur.disabled:
		_noter("✗ entraînement %s : bouton de lancement absent ou grisé" % slug)
		return
	lanceur.pressed.emit()
	if not await _attendre(func() -> bool: return _main.training_mode, 30.0):
		_noter("✗ entraînement %s : pas de mode entraînement" % slug)
		return
	await _images_de_jeu(120)
	var jouee := String(MapData.selected_map_id)
	_noter("entraînement %s : carte choisie id=%s, carte jouée id=%s%s, vue unique=%s, mode_rendu=%s" % [
		slug, choisie, jouee, "" if jouee == choisie else "  ⚠ DIFFÉRENTE",
		not _deux_vues_visibles(), GameSettings.mode_rendu()])
	var pantins := _poser_les_marionnettes()
	for k in 60:
		pantins[0].marche = Vector2(0, 1).rotated(float(k) * 0.05)
		await get_tree().process_frame
	pantins[0].marche = Vector2.ZERO
	# Un tir sur la cible, pour voir flash et impact.
	pantins[0].tir = true
	await _images_de_jeu(2)
	pantins[0].tir = false
	await _images_de_jeu(6)
	await _capturer("30_%s_entrainement" % slug)
	await _vers_le_menu()


func _etape_diag() -> void:
	_marquer("diag")
	# F3 et F6 pendant un match local : c'est là qu'Adrien les pressera.
	var hub = _ui.hub
	hub.reset()
	await _cliquer("1V1 ÉCRANS SCINDÉS")
	await _cliquer("PRÉPARER LE MATCH")
	_ui.panel_launch.pressed.emit()
	await _attendre(func() -> bool: return _main.round_active and _main.countdown_left <= 0.0, 40.0)
	_poser_les_marionnettes()
	await _images_de_jeu(30)
	await _touche(KEY_F3)
	await _images_de_jeu(40)
	_noter("F3 : panneau visible=%s" % _ui.debug_panel.visible)
	await _capturer("40_f3")
	var diag := "user://diagnostic.txt"
	var avant := FileAccess.get_modified_time(diag) if FileAccess.file_exists(diag) else 0
	await _touche(KEY_F6)
	await _images_de_jeu(20)
	var existe := FileAccess.file_exists(diag)
	_noter("F6 : diagnostic.txt %s (%s)" % ["écrit" if existe else "ABSENT",
		"neuf" if existe and FileAccess.get_modified_time(diag) >= avant else "inchangé"])
	if existe:
		var texte := FileAccess.get_file_as_string(diag)
		var f := FileAccess.open(_sortie.path_join("diagnostic_f6.txt"), FileAccess.WRITE)
		if f != null:
			f.store_string(texte)
		print("[pilote] --- diagnostic F6 ---\n", texte, "\n[pilote] --- fin du diagnostic ---")
	await _capturer("41_f6")
	await _touche(KEY_F3)
	await _images_de_jeu(5)
	# F5 pendant le match : CLAUDE.md dit « F5 l'éditeur de cartes ».
	var scene_avant := get_tree().current_scene
	await _touche(KEY_F5)
	await _images_de_jeu(30)
	_noter("F5 en match : scène courante %s" % ("INCHANGÉE (F5 n'ouvre rien)"
		if get_tree().current_scene == scene_avant else String(get_tree().current_scene.name)))
	await _vers_le_menu()


## L'éditeur : ouvert comme le joueur l'ouvre (galerie → ÉDITEUR ›), F5 pour le bac à sable.
func _etape_editeur() -> void:
	_marquer("editeur")
	var hub = _ui.hub
	hub.reset()
	await _cliquer("1V1 ÉCRANS SCINDÉS")
	await _cliquer("CHANGER DE CARTE")
	var galerie := _trouver(_ui, func(n: Node) -> bool: return n is MapGallery and n.is_visible_in_tree())
	if galerie == null:
		_noter("✗ éditeur : galerie introuvable")
		return
	var bouton: Button = galerie.get("_btn_editor")
	if bouton == null:
		_noter("✗ éditeur : bouton ÉDITEUR introuvable")
		return
	bouton.pressed.emit()
	await _images_de_jeu(60)
	var scene := get_tree().current_scene
	_noter("éditeur : scène courante %s" % (scene.scene_file_path if scene != null else "nulle"))
	await _capturer("50_editeur")
	await _touche(KEY_F5)
	await _images_de_jeu(90)
	await _capturer("51_editeur_f5_bac_a_sable")
	await _touche(KEY_F5)
	await _images_de_jeu(30)
	await _capturer("52_editeur_retour")
	# Retour au jeu, comme le bouton de sortie de l'éditeur.
	await _touche(KEY_ESCAPE)
	await _images_de_jeu(90)
	scene = get_tree().current_scene
	_noter("éditeur, après Échap : scène courante %s" % (scene.scene_file_path if scene != null else "nulle"))
	await _capturer("53_apres_editeur")
	if scene != null and scene.scene_file_path == "res://main.tscn" and scene != _main:
		_main = scene
		_ui = _main.get_node_or_null("UI")


# ---------------------------------------------------------------------------
# GESTES
# ---------------------------------------------------------------------------

func _choisir_la_carte(slug: String) -> bool:
	var entree: Dictionary = MapData.get_map_by_slug(slug)
	if entree.is_empty():
		_noter("✗ carte %s absente du catalogue" % slug)
		return false
	var id := String(entree["id"])
	var galerie := _trouver(_ui, func(n: Node) -> bool: return n is MapGallery and n.is_visible_in_tree())
	if galerie == null:
		_noter("✗ %s : galerie non affichée après CHANGER DE CARTE" % slug)
		return false
	# Le geste de la vignette : `_on_tile_pressed`, branché sur son clic.
	galerie._on_tile_pressed(id)
	await _images_de_jeu(20)
	if String(MapData.selected_map_id) != id:
		_noter("✗ %s : la vignette n'a pas sélectionné la carte (id %s, sélectionnée %s)" % [
			slug, id, MapData.selected_map_id])
		return false
	return true


func _poser_les_marionnettes() -> Array:
	var pantins := []
	for j in [_main.p1, _main.p2]:
		if not is_instance_valid(j):
			pantins.append(Marionnette.new())
			continue
		var m := Marionnette.new()
		m.name = "MarionnetteDuPilote"
		m.visee = Vector2.RIGHT
		_main._set_player_input_provider(j, m)
		pantins.append(m)
	return pantins


## J1 tue J2 d'un vrai tir si une ligne dégagée existe, sinon par dégâts directs (dit).
func _tuer(pantins: Array, slug: String) -> void:
	var p1: Node2D = _main.p1
	var p2: Node2D = _main.p2
	if not is_instance_valid(p1) or not is_instance_valid(p2):
		_noter("✗ %s : joueurs absents" % slug)
		return
	var espace := p1.get_world_2d().direct_space_state
	var choisi := Vector2.ZERO
	for k in 16:
		var d := Vector2.RIGHT.rotated(TAU * float(k) / 16.0)
		var q := PhysicsRayQueryParameters2D.create(p1.global_position, p1.global_position + d * 200.0)
		q.exclude = [p1.get_rid(), p2.get_rid()]
		if espace.intersect_ray(q).is_empty():
			choisi = d
			break
	var par_tir := false
	if choisi != Vector2.ZERO:
		p2.global_position = p1.global_position + choisi * 150.0
		pantins[0].visee = choisi
		pantins[1].visee = -choisi
		await _images_de_jeu(20)
		await _capturer("22b_%s_face_a_face" % slug)
		for k in 240:
			pantins[0].tir = (k % 6) < 3
			await get_tree().process_frame
			if not _main.round_active or p2.get("dead"):
				par_tir = true
				break
		pantins[0].tir = false
	if not par_tir and _main.round_active:
		_noter("%s : aucun tir n'a tué en 4 s (ligne dégagée %s) — dégâts directs" % [slug, choisi != Vector2.ZERO])
		p2.take_damage(9999.0, p1)
	else:
		_noter("%s : J2 tué par un vrai tir de J1" % slug)


func _vers_le_menu() -> void:
	if _main.has_method("_on_main_menu_requested"):
		_main._on_main_menu_requested()
	await _images_de_jeu(30)
	get_tree().paused = false


func _cliquer(libelle: String) -> bool:
	var hub = _ui.hub
	var liste = hub.list_of(hub.current_id())
	if liste != null:
		for enfant in liste.get_children():
			var btn := enfant as Button
			if btn != null and _libelle(btn).to_upper().contains(libelle.to_upper()):
				btn.grab_focus()
				btn.pressed.emit()
				await _images_de_jeu(20)
				return true
	_noter("✗ entrée « %s » introuvable sur l'écran %s" % [libelle, hub.current_id()])
	return false


func _touche(code: Key) -> void:
	for presse in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = presse
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame


# ---------------------------------------------------------------------------
# OUTILS
# ---------------------------------------------------------------------------

func _slugs() -> Array:
	if not _cartes.is_empty():
		return _cartes
	var out := []
	for f in DirAccess.get_files_at("res://assets/maps"):
		if f.ends_with(".json"):
			out.append(f.trim_suffix(".json"))
	out.sort()
	return out


func _deux_vues_visibles() -> bool:
	var c2 := _main.vp2.get_parent() as Control
	return c2 != null and c2.is_visible_in_tree()


func _capturer(nom: String) -> void:
	var img: Image = await Commun.capturer(get_tree(), 20000)
	if img == null:
		_noter("✗ capture %s : aucune image" % nom)
		return
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	var chemin := _sortie.path_join(nom + ".jpg")
	img.save_jpg(chemin, 0.85)
	_images += 1
	print("[pilote]   image %s (%dx%d)" % [nom, img.get_width(), img.get_height()])


func _marquer(etape: String) -> void:
	print("\n[pilote] >>> %s (image %d)" % [etape, Engine.get_process_frames()])


func _noter(ligne: String) -> void:
	_bilan.append(ligne)
	print("[pilote]   · ", ligne)


func _images_de_jeu(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Attente comptée en images de jeu (60 par seconde de jeu sous `--fixed-fps 60`).
func _attendre(predicat: Callable, secondes: float) -> bool:
	var n := int(secondes * 60.0)
	for i in n:
		if predicat.call():
			return true
		await get_tree().process_frame
	return bool(predicat.call())


func _trouver(racine: Node, predicat: Callable) -> Node:
	if racine == null:
		return null
	if predicat.call(racine):
		return racine
	for enfant in racine.get_children():
		var r := _trouver(enfant, predicat)
		if r != null:
			return r
	return null


func _libelle(btn: Button) -> String:
	# La lecture du photographe : le libellé d'une entrée du hub vit dans un Label d'une rangée.
	if btn == null:
		return ""
	for rangee in btn.get_children():
		for enfant in rangee.get_children():
			var lbl := enfant as Label
			if lbl != null and not String(lbl.text) in ["›", "—", ""]:
				return String(lbl.text).strip_edges()
	return String(btn.text).strip_edges()


func _ardoise(texte: String) -> String:
	var t := texte.to_lower().strip_edges()
	var out := ""
	for c in t:
		out += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "_"
	return out.substr(0, 24)


func _valeur(args: PackedStringArray, nom: String, defaut: String) -> String:
	for a in args:
		if a.begins_with(nom + "="):
			return a.substr(nom.length() + 1)
	return defaut
