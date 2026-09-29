extends SceneTree

## LE CARTON DE FIN, IMAGE PAR IMAGE — le salon ne se montre jamais avant que le carton ne l'ait couvert.
##
## Adrien, 2026-09-29 vers 15:26 : « juste avant ce carton, après la killcam, il arrive que je vois subrepticement
## le menu de rejeu avant l'affichage du carton ».
##
## ## La cause, mesurée à l'image (Xvfb, `--fixed-fps 60`, 1920×1080, sur `c442870d`)
##
## `GameState._do_end_round` fait, dans la MÊME image, `ui.show_game_over()` — le salon s'allume : ses surfaces
## noires, son rideau de nuit, puis ses cartes de classe — et `AfficheDeFin.poser()`. Or l'affiche entrait en
## fondu : son fond passait de 0 à 1 en 0,34 s sur `Courbe.SORTIE`, qui TRAÎNE avant de filer. Relevé sur le jeu réel :
##
##     image 557  salon ouvert, carton posé, couverture 0,00
##     image 565  rideau du salon 0,96                    couverture 0,09
##     image 570  cartes de classe lisibles               couverture 0,28
##     image 580  le carton l'emporte enfin
##
## Le joueur voyait donc le menu de rejeu se construire pendant une quinzaine d'images, AVANT que le carton ne
## soit seulement à moitié là. Ce n'est pas un défaut d'ordre entre deux appels — les deux partent dans la même
## image — mais d'ORDRE DE COUVERTURE : le salon est là plein, le carton à zéro. La correction n'est pas de
## retarder le salon (`ui.show_game_over` pose aussi le titre que l'affiche LIT) mais de rendre le fond du carton
## opaque dès sa première image : ce qui entre en fondu est l'illustration et le mot, sur le noir.
##
## ## Ce que la suite tient
##
## Sur le VRAI chemin — un joueur tué par `take_damage`, la killcam passée comme le fait la manette (l'action
## `p1_skip_killcam`, par `Input`), le tampon, les deux secondes, `show_game_over`, `_poser_affiche_de_fin` —,
## la suite relève À CHAQUE IMAGE : la visibilité du salon (visible dans l'arbre, et l'opacité cumulée de sa
## chaîne de parents) et la couverture du carton (`AfficheDeFin.couverture()`). La fuite d'une image est
##
##     fuite = opacité du salon × (1 − couverture du carton)
##
## — ce que l'œil voit du salon à travers le carton. Elle doit être nulle de la première image du kill à la
## sortie du carton. C'est une garde du RÉSULTAT (« le salon ne se voit pas »), pas d'un mécanisme : un fond opaque,
## un salon tenu invisible ou un salon allumé plus tard la tiennent tous, et un fondu qui repartirait de zéro la
## fait rougir — ce que la mesure de `c442870d` confirme (fuite de 1,00 à l'image de la pose).
##
## Elle vérifie aussi ses TÉMOINS (le carton est venu, le salon s'est ouvert, dans la même image ou après lui) — sans
## eux, « aucune fuite » se vérifierait d'une suite qui n'a rien vu —, et l'état final : le carton parti, le salon
## est plein et REJOUER est libre.
##
## ## Deux façons de la lancer
##
##   Sans fenêtre (le lot) :  godot --headless --path . --script res://tools/test_carton_transition.gd
##
##   Sous Xvfb, pour LIRE la transition — une bande d'images consécutives, `<dossier>/img_NNNN.png`, et un vrai clic
##   de souris sur le carton (impossible sans fenêtre : l'interface n'y traite aucun clic) :
##     xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --fixed-fps 60 \
##       --script res://tools/test_carton_transition.gd -- --captures <dossier> [--classes=fumiste,spectre] [--killcam-entiere]
##
##   `--fixed-fps 60` : chaque image vaut 1/60 s de jeu, quel que soit le temps que le rendu logiciel y met — c'est ce
##   qui rend la bande comparable à ce que voit un joueur à 60 images par seconde.
##   `--trace` imprime toutes les images relevées, pas seulement les fautives.

## Ce que la suite doit avoir vu pour dire quoi que ce soit.
const PLANCHER := 11
## En dessous, ce qui reste du salon à travers le carton n'est plus qu'un arrondi de mise en page.
const SEUIL_FUITE := 0.02
## Images gardées AVANT la pose du carton, puis APRÈS, pour la bande.
const IMAGES_AVANT := 6
const IMAGES_APRES := 45
## Le plafond d'un passage, en TEMPS RÉEL : sans fenêtre une image dure une milliseconde et toute la fin de manche
## tient en quatre secondes ; sous Xvfb, une image de rendu logiciel dure une demi-seconde et la bande en prend cent.
## Une suite qui ne sort pas est pire qu'une rouge.
const LIMITE_MS_SANS_FENETRE := 60000
const LIMITE_MS_FENETRE := 1500000

var _echecs := 0
var _verifications := 0
var _main: Node
var _ui: Node
var _fenetre := false
var _dossier := ""
var _bavard := false
var _entiere := false
var _classes: PackedStringArray = ["fumiste", "spectre"]
var _trace: Array[Dictionary] = []
var _anneau: Array = []
var _ecrites := 0
var _legende_lue := ""
var _legende_attendue := ""


func _check(libelle: String, condition: bool, detail: String = "") -> void:
	_verifications += 1
	if condition:
		print("  ✓ %s" % libelle)
	else:
		_echecs += 1
		printerr("  ✗ %s%s" % [libelle, ("  → " + detail) if detail != "" else ""])


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== LE CARTON DE FIN, IMAGE PAR IMAGE ===")
	_fenetre = DisplayServer.get_name() != "headless"
	for a in OS.get_cmdline_user_args():
		if a == "--trace":
			_bavard = true
		elif a == "--killcam-entiere":
			_entiere = true
		elif a.begins_with("--classes="):
			_classes = a.trim_prefix("--classes=").split(",")
	var args := OS.get_cmdline_user_args()
	var i := args.find("--captures")
	if i >= 0 and i + 1 < args.size():
		_dossier = args[i + 1]
		DirAccess.make_dir_recursive_absolute(_dossier)
	if _dossier != "" and not _fenetre:
		printerr("  (--captures ignoré : sans fenêtre, rien n'est rastérisé)")
		_dossier = ""

	var reglages: Node = root.get_node("GameSettings")
	# Un joueur neuf voit l'intro par-dessus le menu : elle rendrait le menu sourd et n'a rien à faire ici.
	reglages.intro_vue = true
	if _fenetre:
		reglages.pilotage_externe = true
		AudioServer.set_bus_mute(0, true)
	await process_frame
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await process_frame
	await process_frame
	_ui = _main.get_node_or_null("UI")
	if _ui == null:
		printerr("✗ main.tscn n'a pas son UI")
		quit(1)
		return
	var allumage: Node = _main.get_node_or_null("PowerOn")
	if allumage != null:
		allumage.call("terminer")
		await create_timer(0.7).timeout

	if not await _demarrer_une_manche():
		quit(1)
		return
	await _jouer_la_fin()
	_analyser()

	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	Engine.time_scale = 1.0
	_main.queue_free()
	if _echecs == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _echecs)
	quit(1 if _echecs > 0 else 0)


# ---------------------------------------------------------------------------
# LE MONTAGE : une vraie manche, deux classes, un mort
# ---------------------------------------------------------------------------

func _demarrer_une_manche() -> bool:
	_ui._intended_mode = 0  # LOCAL_SPLITSCREEN — le nom d'autoload ne résout pas en `--script`
	_main._on_replay_requested()
	var fin := Time.get_ticks_msec() + 30000
	while not (_main.round_active and _main.countdown_left > 0.0):
		if Time.get_ticks_msec() > fin:
			printerr("✗ la manche n'a pas démarré")
			return false
		await process_frame
	_main.countdown_left = 0.001
	for k in 20:
		await process_frame
	# Deux classes neuves, dont les armes se disent « Pistolet lourd » et « Pistolet silencieux » : ce que l'ancien carton
	# écrivait n'était pas ce qu'on avait choisi.
	var deux: Array = []
	for slug in _classes:
		for c in _main.classes():
			if String(c.slug()) == String(slug):
				deux.append(c)
	if deux.size() != 2:
		printerr("✗ --classes : deux slugs du catalogue attendus, trouvé %d" % deux.size())
		return false
	_main.p1.equip_weapon(deux[0])
	_main.p2.equip_weapon(deux[1])
	_legende_attendue = "%s / %s" % [String(deux[0].libelle).to_upper(), String(deux[1].libelle).to_upper()]
	# De quoi remplir le tampon de rejeu : l'enregistrement tourne à 60 Hz de physique.
	for k in 40:
		await physics_frame
	return true


func _image_suivante() -> void:
	if _fenetre:
		await RenderingServer.frame_post_draw
	else:
		await process_frame


## L'action de la manette, par `Input` : le tampon d'événements ne la livre qu'au début de l'image suivante,
## là où `Input.is_action_just_pressed` la lit — ce qu'un `action_press` posé en fin d'image ne ferait pas.
func _passer_la_killcam(presse: bool) -> void:
	var e := InputEventAction.new()
	e.action = &"p1_skip_killcam"
	e.pressed = presse
	Input.parse_input_event(e)


# ---------------------------------------------------------------------------
# LA FIN : le relevé, image par image
# ---------------------------------------------------------------------------

func _jouer_la_fin() -> void:
	print("\n[De la mort de J1 au carton, image par image]")
	var rejeu: Node = root.get_node("ReplaySystem")
	_main.p1.take_damage(9999.0, _main.p2)
	var image := 0
	var passee := false
	var relachee := false
	var pose := -1
	var apres := 0
	var armee_vue := false
	var congedie := false
	var essais := 0
	var limite := Time.get_ticks_msec() + (LIMITE_MS_FENETRE if _fenetre else LIMITE_MS_SANS_FENETRE)
	while Time.get_ticks_msec() < limite:
		await _image_suivante()
		image += 1
		if not _entiere and not passee and bool(rejeu.get("playing_back")):
			passee = true
			_passer_la_killcam(true)
		elif passee and not relachee:
			relachee = true
			_passer_la_killcam(false)
		elif passee and bool(rejeu.get("playing_back")):
			# Le geste n'a pas pris (image de départ manquée) : on le dit, et on passe la killcam comme la manette le ferait.
			essais += 1
			if essais == 6:
				printerr("  (le geste de la manette n'a pas passé la killcam : `playing_back` forcé)")
				rejeu.set("playing_back", false)
		var releve := _relever(image)
		_trace.append(releve)
		if _bavard:
			print("  ", _ligne(releve))

		var affiche: Node = _main.get_node_or_null("AfficheDeFin")
		if affiche != null and pose < 0:
			pose = image
			var mention: Node = affiche.find_child("Legende", true, false)
			_legende_lue = String(mention.get("text")) if mention != null else ""
		# La bande : quelques images avant la pose, toutes celles d'après.
		if _dossier != "":
			var img := root.get_texture().get_image()
			if pose < 0:
				_anneau.append([img, image])
				if _anneau.size() > IMAGES_AVANT:
					_anneau.pop_front()
			else:
				for e in _anneau:
					_ecrire(e[0], e[1])
				_anneau.clear()
				_ecrire(img, image)
		if pose >= 0:
			apres += 1
			if apres >= IMAGES_APRES:
				break
	_check("le carton est venu", pose >= 0, "aucun carton en %d images" % image)
	if pose < 0:
		return
	if _dossier != "":
		var f := FileAccess.open(_dossier.path_join("pose.txt"), FileAccess.WRITE)
		if f != null:
			f.store_string("image de la pose du carton : %d\n" % pose)
			f.close()
		print("  %d images écrites dans %s (carton posé à l'image %d)" % [_ecrites, _dossier, pose])

	# Le carton entre, puis on le passe — par le geste d'un joueur, pas par `congedier()` : c'est un chemin de plus
	# éprouvé, celui des entrées, sur ce même montage. Sous une fenêtre, c'est un vrai clic de souris.
	var affiche_vivante: Node = _main.get_node_or_null("AfficheDeFin")
	var fin_entree := Time.get_ticks_msec() + 20000
	while is_instance_valid(affiche_vivante) and not bool(affiche_vivante.call("est_armee")):
		if Time.get_ticks_msec() > fin_entree:
			break
		await _image_suivante()
		image += 1
		_trace.append(_relever(image))
	armee_vue = is_instance_valid(affiche_vivante) and bool(affiche_vivante.call("est_armee"))
	_check("le carton finit d'entrer, et s'arme", armee_vue)
	if armee_vue:
		var geste: InputEvent
		var nom: String
		if _fenetre:
			var clic := InputEventMouseButton.new()
			clic.button_index = MOUSE_BUTTON_LEFT
			clic.pressed = true
			clic.position = Vector2(400.0, 300.0)
			clic.global_position = clic.position
			geste = clic
			nom = "un clic de souris"
		else:
			var touche := InputEventKey.new()
			touche.physical_keycode = KEY_A
			touche.keycode = KEY_A
			touche.pressed = true
			geste = touche
			nom = "une touche du clavier"
		Input.parse_input_event(geste)
		for k in 3:
			await _image_suivante()
			image += 1
			_trace.append(_relever(image))
		congedie = not bool(affiche_vivante.call("est_active")) if is_instance_valid(affiche_vivante) else true
		_check("%s congédie le carton, sur le jeu réel" % nom, congedie)
		var relache: InputEvent = geste.duplicate()
		if relache is InputEventKey or relache is InputEventMouseButton:
			relache.set("pressed", false)
			Input.parse_input_event(relache)
	# Jusqu'à la disparition du carton (sa sortie dure un quart de seconde), plus quelques images.
	var fin_sortie := Time.get_ticks_msec() + 20000
	while is_instance_valid(_main.get_node_or_null("AfficheDeFin")):
		if Time.get_ticks_msec() > fin_sortie:
			break
		await _image_suivante()
		image += 1
		_trace.append(_relever(image))
	for k in 6:
		await _image_suivante()
		image += 1
		_trace.append(_relever(image))


func _ecrire(img: Image, numero: int) -> void:
	img.save_png(_dossier.path_join("img_%04d.png" % numero))
	_ecrites += 1


## L'opacité cumulée d'un nœud d'interface : le produit des `modulate.a` de la chaîne, jusqu'à la couche.
func _opacite(n: CanvasItem) -> float:
	var a := 1.0
	var c: Node = n
	while c != null and c is CanvasItem:
		a *= (c as CanvasItem).modulate.a
		c = c.get_parent()
	return a


## Ce que voit le joueur du salon à cet instant : rien s'il n'est pas visible dans l'arbre, sinon son opacité cumulée.
func _relever(image: int) -> Dictionary:
	var salon: Control = _ui.game_over_panel
	var visible: bool = salon.is_visible_in_tree()
	var affiche: Node = _main.get_node_or_null("AfficheDeFin")
	var couverture := 0.0
	var active := false
	if affiche != null:
		couverture = float(affiche.call("couverture"))
		active = bool(affiche.call("est_active"))
	var hud: CanvasItem = _ui.match_hud
	return {
		"image": image,
		"rejeu": bool(root.get_node("ReplaySystem").get("playing_back")),
		"fin_de_manche": bool(_main._end_sequence_active),
		"game_over": bool(_main.game_over),
		"salon_visible": visible,
		"salon": _opacite(salon) if visible else 0.0,
		"affiche": affiche != null,
		"active": active,
		"couverture": couverture,
		"hud": _opacite(hud) if hud != null and hud.visible else 0.0,
	}


func _fuite(releve: Dictionary) -> float:
	return float(releve["salon"]) * (1.0 - float(releve["couverture"]))


func _ligne(r: Dictionary) -> String:
	return "img %4d  rejeu=%s fin=%s game_over=%s  salon=%.2f  carton=%s couverture=%.2f  → fuite %.2f  (hud %.2f)" % [
		r["image"], str(r["rejeu"]), str(r["fin_de_manche"]), str(r["game_over"]), r["salon"],
		str(r["affiche"]), r["couverture"], _fuite(r), r["hud"]]


# ---------------------------------------------------------------------------
# LE VERDICT
# ---------------------------------------------------------------------------

func _analyser() -> void:
	print("\n[Le salon derrière le carton]")
	var premiere_salon := -1
	var premiere_carton := -1
	var derniere_active := -1
	for r in _trace:
		if premiere_salon < 0 and float(r["salon"]) > 0.0:
			premiere_salon = int(r["image"])
		if premiere_carton < 0 and bool(r["affiche"]):
			premiere_carton = int(r["image"])
		if bool(r["active"]):
			derniere_active = int(r["image"])
	print("  %d images relevées ; salon vu à l'image %d, carton posé à l'image %d, carton actif jusqu'à l'image %d"
		% [_trace.size(), premiere_salon, premiere_carton, derniere_active])
	_check("témoin : le salon s'est ouvert pendant le relevé", premiere_salon >= 0)
	_check("témoin : le carton a été posé", premiere_carton >= 0)
	if premiere_salon < 0 or premiere_carton < 0:
		return

	# Le salon ne se montre jamais SANS carton : le carton est posé dans la même image, ou avant.
	_check("le carton est là dès l'image où le salon se montre (image %d, carton %d)" % [premiere_salon, premiere_carton],
		premiere_carton <= premiere_salon)
	# Et sur ce même montage, il nomme les deux CLASSES (demande d'Adrien, même séance).
	_check("le carton nomme les deux classes : « %s »" % _legende_attendue, _legende_lue.contains(_legende_attendue),
		_legende_lue)

	# La fuite : de la mort au moment où le carton commence sa sortie — ensuite le salon SE RÉVÈLE, et c'est voulu.
	var fautives: Array[Dictionary] = []
	var pire := 0.0
	var vues := 0
	for r in _trace:
		if int(r["image"]) > derniere_active:
			break
		vues += 1
		var f := _fuite(r)
		pire = maxf(pire, f)
		if f > SEUIL_FUITE:
			fautives.append(r)
	var detail := ""
	if not fautives.is_empty():
		var lignes: Array[String] = []
		for r in fautives.slice(0, 8):
			lignes.append(_ligne(r))
		detail = "\n      " + "\n      ".join(lignes)
		if fautives.size() > 8:
			detail += "\n      … et %d de plus" % (fautives.size() - 8)
	_check("aucune image où le salon se voit à travers le carton (%d images, pire fuite %.2f)" % [vues, pire],
		fautives.is_empty(), "%d image(s) fautive(s), de %d à %d%s" % [fautives.size(),
			int(fautives[0]["image"]) if not fautives.is_empty() else 0,
			int(fautives[-1]["image"]) if not fautives.is_empty() else 0, detail])

	# La couverture est pleine dès la pose : c'est ce qui fait la garde tenir même si le salon s'allume plus tôt.
	var pose_couverture := 0.0
	for r in _trace:
		if int(r["image"]) == premiere_carton:
			pose_couverture = float(r["couverture"])
	_check("le carton couvre tout dès sa première image (%.2f)" % pose_couverture, pose_couverture >= 0.999)

	# Après la sortie du carton, le salon est là, plein, et REJOUER est libre.
	var dernier: Dictionary = _trace[-1]
	_check("le carton parti, le salon est visible", bool(dernier["salon_visible"]))
	_check("… plein, sans qu'un voile d'opacité reste posé (%.2f)" % float(dernier["salon"]),
		float(dernier["salon"]) >= 0.999)
	_check("… et REJOUER est de nouveau libre", not _ui.btn_replay.disabled and not _ui.panel_launch.disabled)
