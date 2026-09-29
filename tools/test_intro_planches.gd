extends SceneTree

## L'intro v2 (récit A, 2026-09-28, refaite le 2026-09-29) : ce que la suite tient, et pourquoi.
##
## Les gardes de DA6.6 sont gardées, réécrites pour un film au lieu de six
## planches. Les défauts possibles ici, et **aucun ne se voit à l'écran** :
##
## 1. **Un film ou une image de repli renommés ou absents.** L'intro jouerait le
##    repli, ou sauterait un plan en silence, et raconterait une histoire amputée.
## 2. **Deux découpages qui divergent.** Le film est monté par
##    `tools/monter_intro.py`, le repli suit `IntroPlanches.PLANS` : un plan
##    ajouté d'un seul côté décalerait le repli sur la musique sans une erreur.
## 3. **Un `EffectMode` inventé.** La décision de DA6.6 était « zéro mode neuf » ;
##    l'intro n'en utilise même plus aucun, et la liste ne doit pas grossir.
## 4. **Une intro qui se met à parler.** Les mots gravés sont les quatre de la
##    règle — VOIR, SANS ÊTRE VU., TUER, SANS ÊTRE TUÉ. — et aucun autre.
## 5. **Un film trop lourd.** Chaque méga part dans chaque téléchargement et chaque
##    mise à jour : 20 Mo au plus (brief du 2026-09-28).

const MenuArtwork := preload("res://menu_artwork.gd")
const IntroPlanches := preload("res://intro_planches.gd")

## Les modes d'effet qui existaient AVANT l'intro. Un mode hors de cette liste
## signalerait un effet écrit pour une poignée d'images.
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

## Le poids maximal du film.
const POIDS_MAX_FILM := 20 * 1000 * 1000

var _echecs := 0

func _init() -> void:
	print("=== TestIntroPlanches ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_test_plans_declares()
	_test_film_et_repli_presents()
	_test_meme_decoupage_que_le_monteur()
	_test_aucun_mode_neuf()
	_test_lettrage()
	_test_reglage_persiste()
	_test_musique_suspendue()
	await _test_sequence()
	await _test_repli()

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

func _test_plans_declares() -> void:
	_check("dix-sept plans déclarés", IntroPlanches.PLANS.size() == 17,
		"%d déclaré(s)" % IntroPlanches.PLANS.size())
	var mesures := 0
	for plan in IntroPlanches.PLANS:
		var m := int(plan.get("mesures", 0))
		_check("plan d'au moins une mesure entière : " + String(plan.get("nom", "?")), m >= 1, str(m))
		mesures += m
	_check("vingt-cinq mesures en tout", mesures == 25, "%d mesures" % mesures)
	var duree := IntroPlanches.duree_totale()
	# Le brief d'Adrien : « entre 20 et 40 secondes ».
	_check("entre 20 et 40 secondes", duree >= 20.0 and duree <= 40.0, "%.2f s" % duree)
	_check("la mesure est celle de la musique (170 BPM)",
		is_equal_approx(IntroPlanches.MESURE, 240.0 / 170.0), str(IntroPlanches.MESURE))

func _test_film_et_repli_presents() -> void:
	_check("le film est présent : " + IntroPlanches.FILM.get_file(),
		ResourceLoader.exists(IntroPlanches.FILM), IntroPlanches.FILM)
	_check("le film se charge comme une vidéo",
		load(IntroPlanches.FILM) is VideoStream)
	var poids := FileAccess.get_file_as_bytes(IntroPlanches.FILM).size()
	_check("le film pèse moins de 20 Mo", poids > 0 and poids <= POIDS_MAX_FILM,
		"%.1f Mo" % (poids / 1e6))
	var images := 0
	for plan in IntroPlanches.PLANS:
		var chemin := String(plan.get("image", ""))
		if chemin == "":
			continue
		images += 1
		_check("image de repli présente : " + chemin.get_file(), ResourceLoader.exists(chemin), chemin)
		var tex := load(chemin) as Texture2D
		if tex != null:
			_check("image de repli en 16:9 : " + chemin.get_file(),
				absf(float(tex.get_width()) / tex.get_height() - 16.0 / 9.0) < 0.01,
				"%d×%d" % [tex.get_width(), tex.get_height()])
	_check("seize plans ont une image de repli (tous sauf le noir d'ouverture)", images == 16, str(images))
	_check("IntroPlanches.repli_complet() est vrai", IntroPlanches.repli_complet())
	_check("IntroPlanches.disponible() est vrai", IntroPlanches.disponible())

func _test_meme_decoupage_que_le_monteur() -> void:
	# Le monteur est du Python : on relit sa liste `PLANS`, ligne par ligne,
	# `(mesures, "nom", "source" ou None, ...)`. Mêmes mesures, mêmes noms, même
	# ordre ; et un plan a une image de repli si, et seulement si, il a une source
	# (le monteur écrit `intro_a_pNN.jpg`, NN = numéro du plan).
	var source := FileAccess.get_file_as_string("res://tools/monter_intro.py")
	_check("le monteur est au dépôt", source != "")
	var re := RegEx.new()
	re.compile("(?m)^\\s*\\((\\d+), \"([^\"]+)\", (None|\"[^\"]+\"),")
	var lus: Array[RegExMatch] = re.search_all(source)
	_check("le monteur déclare autant de plans", lus.size() == IntroPlanches.PLANS.size(),
		"%d lus dans monter_intro.py" % lus.size())
	for i in mini(lus.size(), IntroPlanches.PLANS.size()):
		var plan: Dictionary = IntroPlanches.PLANS[i]
		var nom := String(plan.get("nom", ""))
		_check("plan %d : même nom et même durée (%s)" % [i + 1, nom],
			lus[i].get_string(2) == nom and int(lus[i].get_string(1)) == int(plan.get("mesures", 0)),
			"monteur : %s mesure(s), « %s »" % [lus[i].get_string(1), lus[i].get_string(2)])
		var a_source := lus[i].get_string(3) != "None"
		var image := String(plan.get("image", ""))
		_check("plan %d : image de repli si et seulement si le monteur a une source" % (i + 1),
			(not a_source and image == "") or (a_source and image.ends_with("intro_a_p%02d.jpg" % (i + 1))),
			"monteur : %s, jeu : « %s »" % [lus[i].get_string(3), image.get_file()])

func _test_aucun_mode_neuf() -> void:
	for mode in MenuArtwork.EffectMode.values():
		if int(mode) == int(MenuArtwork.EffectMode.NONE):
			continue
		_check("mode préexistant : %s" % MenuArtwork.EffectMode.find_key(mode),
			MODES_PREEXISTANTS.has(int(mode)), "mode %d ajouté depuis l'intro" % mode)
	var source := FileAccess.get_file_as_string("res://intro_planches.gd")
	_check("l'intro n'écrit aucun effet de menu", not source.contains("EffectMode"))

func _test_lettrage() -> void:
	# Le récit n'a que les quatre mots de la règle. Ce sont les plans que le
	# monteur tire de `textes/` : une intro qui se met à parler ailleurs aurait
	# cessé d'être celle qui a été choisie.
	var source := FileAccess.get_file_as_string("res://tools/monter_intro.py")
	var re := RegEx.new()
	re.compile("(?m)^\\s*\\(\\d+, \"([^\"]+)\", \"textes/")
	var mots: Array[String] = []
	for r in re.search_all(source):
		mots.append(r.get_string(1))
	_check("les mots gravés sont les quatre de la règle, dans l'ordre",
		mots == ["VOIR", "SANS ÊTRE VU.", "TUER", "SANS ÊTRE TUÉ."], str(mots))
	var noms: Array[String] = []
	for plan in IntroPlanches.PLANS:
		noms.append(String(plan.get("nom", "")))
	_check("le film finit sur le titre", noms.back() == "CANDELA", str(noms.back()))

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

func _test_musique_suspendue() -> void:
	# Le film porte sa propre musique. Sans la pause, celle du jeu — lancée dès
	# `_ready` de GameState — jouerait dessous, et rien ne le signalerait.
	var am := FileAccess.get_file_as_string("res://audio_manager.gd")
	_check("AudioManager sait suspendre la musique", am.contains("func suspendre_musique("))
	_check("et la met en PAUSE plutôt que de l'arrêter",
		am.contains("music_player.stream_paused = suspendre"))
	var intro := FileAccess.get_file_as_string("res://intro_planches.gd")
	_check("l'intro suspend la musique pendant le film", intro.contains("_suspendre_musique(true)"))
	_check("et la rend à la fin", intro.contains("_suspendre_musique(false)"))

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
	_check("c'est le film qui joue", intro.joue_le_film())

	# N'IMPORTE QUELLE touche passe l'intro : c'est la demande d'Adrien, et
	# c'est le seul comportement qu'un joueur essaiera sans y penser.
	var touche := InputEventKey.new()
	touche.keycode = KEY_G  # une touche quelconque, sans rôle dans le jeu
	touche.pressed = true
	intro._unhandled_input(touche)
	await process_frame
	_check("une touche quelconque passe l'intro", not intro.en_cours())
	_check("la fin est annoncée", finie[0])

	# Un mouvement de souris ne doit RIEN passer : un joueur qui pose la main sur
	# la souris pour regarder ne demande pas à sauter l'intro.
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
	# Un bouton de manette, lui, la passe.
	var bouton := InputEventJoypadButton.new()
	bouton.button_index = JOY_BUTTON_A
	bouton.pressed = true
	intro2._unhandled_input(bouton)
	await process_frame
	_check("un bouton de manette passe l'intro", not intro2.en_cours())

	root.remove_child(intro)
	root.remove_child(intro2)
	intro.free()
	intro2.free()
	await process_frame

func _test_repli() -> void:
	# Sans le film, le repli rejoue le même découpage : plan par plan, à la mesure.
	var intro: CanvasLayer = IntroPlanches.new()
	intro.sans_film = true
	root.add_child(intro)
	await process_frame
	var finie := [false]
	intro.terminee.connect(func() -> void: finie[0] = true)
	intro.jouer()
	await process_frame
	_check("le repli démarre sur le premier plan", intro.plan_courant() == 0,
		"plan %d" % intro.plan_courant())
	_check("et ce n'est pas le film", not intro.joue_le_film())
	# Le premier plan écoulé (sa durée en mesures), le deuxième plan.
	intro._process(int(IntroPlanches.PLANS[0].get("mesures", 1)) * IntroPlanches.MESURE + 0.01)
	_check("le premier plan écoulé, le deuxième", intro.plan_courant() == 1,
		"plan %d" % intro.plan_courant())
	var image := intro.get_node_or_null("Cadre16x9/Scene/ImageRepli") as TextureRect
	_check("son image est posée", image != null and image.visible and image.texture != null)
	# Jusqu'au bout : chaque plan à sa durée, puis la main rendue.
	for i in range(1, IntroPlanches.PLANS.size()):
		intro._process(int(IntroPlanches.PLANS[i].get("mesures", 1)) * IntroPlanches.MESURE + 0.01)
	_check("le repli rend la main après le dernier plan", not intro.en_cours() and finie[0])
	root.remove_child(intro)
	intro.free()
	await process_frame
