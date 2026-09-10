extends SceneTree

## Finitions des menus (2026-09-10, demandées par Adrien) : ce que la suite tient.
##
## Quatre défauts possibles, et **aucun ne fait d'erreur console** :
##
## 1. **Le menu répond sous le voile.** L'allumage et l'intro recouvrent un menu
##    déjà vivant ; `ui._input` passe avant le `_unhandled_input` du voile, donc
##    la touche qui saute l'allumage déplaçait aussi la sélection, et chaque
##    déplacement tiquait sous un écran noir. On l'entend, on ne le voit pas.
## 2. **Un titre régénéré revient avec son liseré.** Les titres sortent de Gemini
##    sur un damier de « fausse transparence » ; un détourage naïf laisse un
##    anneau de pixels blanc-gris autour du cerne d'encre. Mesuré ici au pixel.
## 3. **Les sons d'interface remontent à 0 dB** au détour d'une retouche.
## 4. **L'avis de phase de test disparaît** ou le logo Godot manque.

const Charte := preload("res://charte.gd")

## Au-delà, un bord de titre est jugé bruité : part des pixels de contour qui
## sont clairs ET gris (le blanc du damier), là où l'encre est noire ou dorée.
## Avant nettoyage : 9 à 36 % selon les titres. Après : sous 1 %.
const PART_LISERE_MAX := 0.02

var _echecs := 0


func _init() -> void:
	print("=== TestMenusFinitions ===")
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_test_niveaux_sonores()
	_test_titres_sans_lisere()
	_test_logo_godot()
	await _test_menu_sourd_sous_le_voile()

	if _echecs == 0:
		print("✓ Toutes les finitions des menus tiennent")
	else:
		printerr("✗ %d échec(s) dans TestMenusFinitions" % _echecs)
	quit(1 if _echecs > 0 else 0)


func _check(libelle: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ %s" % libelle)
	else:
		_echecs += 1
		printerr("  ✗ %s%s" % [libelle, "" if detail == "" else " — " + detail])


func _test_niveaux_sonores() -> void:
	_check("le tic de navigation est discret (≤ −10 dB)",
		Charte.NIVEAU_UI_NAV <= -10.0, "%.1f dB" % Charte.NIVEAU_UI_NAV)
	_check("le massicot est sous 0 dB", Charte.NIVEAU_UI_MASSICOT < 0.0,
		"%.1f dB" % Charte.NIVEAU_UI_MASSICOT)
	_check("l'appui est sous 0 dB", Charte.NIVEAU_UI_APPUI < 0.0,
		"%.1f dB" % Charte.NIVEAU_UI_APPUI)
	_check("le déplacement est le plus bas des trois",
		Charte.NIVEAU_UI_NAV < Charte.NIVEAU_UI_APPUI
			and Charte.NIVEAU_UI_NAV < Charte.NIVEAU_UI_MASSICOT)


## Pixels opaques voisins d'un transparent, dont la part claire et grise.
func _part_lisere(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var contour := 0
	var clairs := 0
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var au_bord := img.get_pixel(x - 1, y).a <= 0.0 \
				or img.get_pixel(x + 1, y).a <= 0.0 \
				or img.get_pixel(x, y - 1).a <= 0.0 \
				or img.get_pixel(x, y + 1).a <= 0.0
			if not au_bord:
				continue
			contour += 1
			var lum := (c.r + c.g + c.b) / 3.0
			var sat := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
			if lum > 0.47 and sat < 0.16:
				clairs += 1
	return float(clairs) / float(maxi(1, contour))


func _test_titres_sans_lisere() -> void:
	var dossier := "res://assets/ui/titres/"
	var fichiers := DirAccess.get_files_at(dossier)
	var vus := 0
	for f in fichiers:
		if not f.ends_with(".png") or not (f.begins_with("titre_") or f.begins_with("verdict_")):
			continue
		var img := _png(dossier + f)
		if img == null:
			_check("%s se charge" % f, false)
			continue
		vus += 1
		var part := _part_lisere(img)
		_check("%s : bord sans liseré blanc" % f, part <= PART_LISERE_MAX,
			"%.1f %% du contour est blanc-gris" % (part * 100.0))
	_check("au moins dix titres contrôlés", vus >= 10, "%d vus" % vus)

	# Sans mipmaps, un titre de 1300 px réduit à 48 scintille : le nettoyage du
	# bord ne sert à rien si la réduction le re-bruite.
	var cfg := ConfigFile.new()
	var chemin_import := "res://assets/ui/titres/titre_accueil.png.import"
	_check("les titres sont importés avec mipmaps",
		cfg.load(chemin_import) == OK and bool(cfg.get_value("params", "mipmaps/generate", false)))


func _test_logo_godot() -> void:
	var ui_script: GDScript = load("res://ui.gd")
	var chemin := String(ui_script.get_script_constant_map().get("LOGO_GODOT", ""))
	_check("ui.gd désigne un logo Godot", chemin != "")
	_check("le logo Godot existe", chemin != "" and ResourceLoader.exists(chemin), chemin)
	if chemin == "" or not FileAccess.file_exists(chemin):
		return
	var img := _png(chemin)
	_check("le logo Godot est détouré (coins transparents)", img != null
		and img.get_pixel(0, 0).a == 0.0
		and img.get_pixel(img.get_width() - 1, img.get_height() - 1).a == 0.0)
	var icone := String(ProjectSettings.get_setting("application/config/icon", ""))
	_check("l'icône d'application existe", icone != "" and FileAccess.file_exists(icone), icone)
	var avis := String(ui_script.get_script_constant_map().get("AVIS_PHASE_DE_TEST", ""))
	_check("l'avis de phase de test est présent",
		avis.begins_with("Jeu en phase de test.") and avis.ends_with("et rien hors ligne."))


func _test_menu_sourd_sous_le_voile() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var main: Node = scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ui: Node = main.get_node_or_null("UI")
	if ui == null:
		_check("main.tscn porte son UI", false)
		return

	var allumage: Node = main.get_node_or_null("PowerOn")
	var intro: Node = main.get_node_or_null("IntroPlanches")
	_check("une cérémonie recouvre le menu au lancement", allumage != null or intro != null)
	_check("le menu est voilé tant qu'elle joue", bool(ui.get("menu_voile")))

	var avant: Variant = ui.get("p1_focus")
	ui.call("_input", _appui("p1_menu_down"))
	ui.call("_input", _appui("p1_menu_down"))
	_check("une flèche sous le voile ne déplace pas la sélection",
		ui.get("p1_focus") == avant)

	if allumage != null:
		allumage.call("terminer")
		await create_timer(0.8).timeout
	elif intro != null:
		intro.call("_terminer")
		await process_frame
	_check("le voile levé, le menu répond", not bool(ui.get("menu_voile")))

	var pose: Variant = ui.get("p1_focus")
	ui.call("_input", _appui("p1_menu_down"))
	_check("le voile levé, une flèche déplace la sélection", ui.get("p1_focus") != pose)
	main.queue_free()
	await process_frame


## Le fichier source, octet pour octet : c'est lui qu'on juge, pas la texture
## importée. `Image.load_from_file` le ferait aussi, avec un avertissement par
## image sur l'export.
func _png(chemin: String) -> Image:
	var octets := FileAccess.get_file_as_bytes(chemin)
	if octets.is_empty():
		return null
	var img := Image.new()
	return img if img.load_png_from_buffer(octets) == OK else null


func _appui(action: String) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev
