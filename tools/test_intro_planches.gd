extends SceneTree

## DA6.6 — l'intro en planches : ce que la suite tient, et pourquoi.
##
## Trois défauts sont possibles ici, et **aucun des trois ne se voit à l'écran** :
##
## 1. **Une planche renommée ou absente.** L'intro sauterait la case en silence
##    (c'est son comportement voulu chez qui n'a pas les images) et raconterait
##    une histoire amputée à qui les a. Ce n'est pas une panne, c'est un récit
##    qui change tout seul.
## 2. **Une planche sans POI ni effet.** `MenuArtwork` rend alors un défaut —
##    torche au centre, aucun effet — et la case s'affiche parfaitement. On perd
##    la moitié du travail sans une ligne d'erreur.
## 3. **Un `EffectMode` inventé pour l'intro.** La décision d'écriture était
##    « zéro mode neuf ». Rien dans le code ne l'empêche : cette suite le fait.

const MenuArtwork := preload("res://menu_artwork.gd")
const MenuParticlesAmbiance := preload("res://menu_particles_ambiance.gd")
const IntroPlanches := preload("res://intro_planches.gd")

## Les modes d'effet qui existaient AVANT l'intro. Une planche qui sortirait de
## cette liste signalerait qu'on a écrit un effet pour six images.
const MODES_PREEXISTANTS: Array[int] = [
	MenuArtwork.EffectMode.FLICKER_DUST,
	MenuArtwork.EffectMode.HEARTBEAT_FLARE,
	MenuArtwork.EffectMode.BEAM_CLASH,
	MenuArtwork.EffectMode.BREATHING_HALO,
	MenuArtwork.EffectMode.NETWORK_LEDS,
	MenuArtwork.EffectMode.CRT_SCAN,
	MenuArtwork.EffectMode.TARGET_PULSE,
	MenuArtwork.EffectMode.ELECTRICAL_ARC,
	MenuArtwork.EffectMode.VAULT_BEAMS,
	MenuArtwork.EffectMode.DYING_EMBER,
	MenuArtwork.EffectMode.FLARE_SMOKE_LINE,
	MenuArtwork.EffectMode.FLARE_LOCAL_CRTS,
	MenuArtwork.EffectMode.BEACON_LINE,
	MenuArtwork.EffectMode.BEACON_LOCAL,
	MenuArtwork.EffectMode.ABYSS_VORTEX,
]

var _echecs := 0

func _init() -> void:
	print("=== TestIntroPlanches ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_test_planches_presentes()
	_test_poi_et_effets()
	_test_aucun_mode_neuf()
	_test_particules()
	_test_lettrage()
	_test_reglage_persiste()
	await _test_sequence()

	if _echecs == 0:
		print("✓ Tous les tests de l'intro passent")
	else:
		printerr("✗ %d échec(s) dans TestIntroPlanches" % _echecs)
	quit(1 if _echecs > 0 else 0)

func _check(libelle: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ %s" % libelle)
	else:
		_echecs += 1
		printerr("  ✗ %s%s" % [libelle, "" if detail == "" else " — " + detail])

func _test_planches_presentes() -> void:
	_check("six planches déclarées", IntroPlanches.PLANCHES.size() == 6,
		"%d déclarée(s)" % IntroPlanches.PLANCHES.size())
	for planche in IntroPlanches.PLANCHES:
		var chemin := String(planche.get("image", ""))
		_check("planche présente : " + chemin.get_file(),
			ResourceLoader.exists(chemin), chemin)
	_check("IntroPlanches.disponible() est vrai", IntroPlanches.disponible())

func _test_poi_et_effets() -> void:
	# Le POI par défaut de MenuArtwork est le centre. Une planche qui le rend
	# n'a pas de POI À ELLE — et rien ne le dirait à l'écran.
	for planche in IntroPlanches.PLANCHES:
		var cle := MenuArtwork.cle_canonique(String(planche.get("image", "")))
		var poi := MenuArtwork.poi_pour(cle)
		_check("POI propre : " + cle, poi != Vector2(0.5, 0.5),
			"rend le défaut central")
		_check("effet propre : " + cle,
			MenuArtwork.effet_pour(cle) != MenuArtwork.EffectMode.NONE,
			"rend NONE")

func _test_aucun_mode_neuf() -> void:
	for planche in IntroPlanches.PLANCHES:
		var cle := MenuArtwork.cle_canonique(String(planche.get("image", "")))
		var mode := int(MenuArtwork.effet_pour(cle))
		_check("mode préexistant : " + cle, MODES_PREEXISTANTS.has(mode),
			"mode %d écrit pour l'intro" % mode)

func _test_particules() -> void:
	for planche in IntroPlanches.PLANCHES:
		var cle := MenuArtwork.cle_canonique(String(planche.get("image", "")))
		_check("profil de particules : " + cle,
			MenuParticlesAmbiance.PROFILE_MAP.has(cle),
			"absent de PROFILE_MAP")

func _test_lettrage() -> void:
	# Le storyboard ne met du texte que sur les planches 5 et 6. Une intro qui
	# se met à parler partout aurait cessé d'être celle qui a été écrite.
	var avec_texte := 0
	for planche in IntroPlanches.PLANCHES:
		if String(planche.get("texte", "")) != "":
			avec_texte += 1
	_check("deux planches portent du texte, pas plus", avec_texte == 2,
		"%d planche(s) parlent" % avec_texte)

func _test_reglage_persiste() -> void:
	# GameSettings est un autoload : il n'existe pas sous `--script`. On vérifie
	# donc que le drapeau est bien LU ET ÉCRIT dans le fichier de réglages, en
	# lisant la source — même procédé que `test_torches.gd`, et pour la même
	# raison : un drapeau sauvegardé d'un seul côté se perd sans erreur.
	var source := FileAccess.get_file_as_string("res://settings_manager.gd")
	_check("le drapeau est LU au chargement",
		source.contains('intro_vue = cfg.get_value(SECTION_DISPLAY, "intro_vue"'))
	_check("le drapeau est ÉCRIT à la sauvegarde",
		source.contains('cfg.set_value(SECTION_DISPLAY, "intro_vue"'))
	_check("le jeu sait oublier l'intro", source.contains("func oublier_intro()"))

func _test_sequence() -> void:
	var intro: CanvasLayer = IntroPlanches.new()
	root.add_child(intro)
	await process_frame

	_check("l'intro passe au-dessus de l'interface", intro.layer > 1,
		"couche %d" % intro.layer)
	_check("l'intro tourne même en pause",
		intro.process_mode == Node.PROCESS_MODE_ALWAYS)

	var finie := [false]
	intro.terminee.connect(func() -> void: finie[0] = true)
	intro.jouer()
	await process_frame
	_check("la séquence démarre", intro.en_cours())

	# N'IMPORTE QUELLE touche passe l'intro : c'est la demande d'Adrien, et
	# c'est le seul comportement qu'un joueur essaiera sans y penser.
	var touche := InputEventKey.new()
	touche.keycode = KEY_G  # une touche quelconque, sans rôle dans le jeu
	touche.pressed = true
	intro._unhandled_input(touche)
	await process_frame
	_check("une touche quelconque passe l'intro", not intro.en_cours())
	_check("la fin est annoncée", finie[0])

	# Un mouvement de souris ne doit RIEN passer : l'intro s'éclaire à la souris,
	# et la passer en la regardant serait le contraire de ce qui est voulu.
	var intro2: CanvasLayer = IntroPlanches.new()
	root.add_child(intro2)
	await process_frame
	intro2.jouer()
	await process_frame
	var bouge := InputEventMouseMotion.new()
	bouge.position = Vector2(100, 100)
	intro2._unhandled_input(bouge)
	await process_frame
	_check("un mouvement de souris ne passe pas l'intro", intro2.en_cours())

	intro2._terminer()
	root.remove_child(intro)
	root.remove_child(intro2)
	intro.free()
	intro2.free()
	await process_frame
