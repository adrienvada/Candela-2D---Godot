## Test headless de l'écran « Audio » (`screen_audio.gd`).
##
## Ce que la suite protège, dans l'ordre d'importance :
##
##   • LA propriété à ne jamais laisser régresser — **afficher l'écran n'écrit
##     rien**. Les curseurs qu'on repositionne émettent `value_changed` comme si
##     le joueur les avait bougés : sans garde-fou, ouvrir l'écran resauvegarde
##     les quatre volumes, et un réglage fait à la main dans le fichier serait
##     perdu au premier passage ;
##   • la conversion reste celle de `settings_manager` — l'écran affiche des
##     pourcents d'amplitude LINÉAIRE, jamais des décibels, faute de quoi tout le
##     changement perçu se tasse dans les derniers pourcents de la course ;
##   • le zéro se dit « coupé » et pas « 0 % » : le bus est coupé net, pas très
##     bas ;
##   • un changement s'entend, sur le bus concerné — un curseur audio muet ne se
##     règle qu'au chiffre — mais pas une audition par cran traversé ;
##   • un bus absent de la disposition ne casse ni l'écran ni l'audition ;
##   • `refresh()` est idempotent, y compris avant toute construction.
##
## Les suites partagent le `user://` du jeu installé : toute écriture passe par
## `_settings_path`, dérivé sur un fichier d'essai, et la dernière vérification
## est que `user://settings.cfg` n'a pas bougé d'un octet.
##
## Lancer : godot --headless --path . --script res://tools/test_screen_audio.gd
extends SceneTree

## Jamais user://settings.cfg : ce sont les vraies préférences du joueur.
const TMP_SETTINGS := "user://test_screen_audio.cfg"
const REAL_SETTINGS := "user://settings.cfg"

var _failures: int = 0

## Chargés dans `_run()`, jamais dans `_init()` : en mode --script, `_init()`
## s'exécute avant les autoloads ET avant le cache des classes globales. Un
## `class_name` référencé trop tôt rend un objet nu, les SCRIPT ERROR
## n'incrémentent aucun compteur, et la suite annonce « tous les tests passent »
## sans avoir rien exercé.
var _screen_script: GDScript
var _settings_script: GDScript
var _theme_script: GDScript

## Constantes de l'écran, relues plutôt que recopiées : un pas ou un mot changé
## là-bas doit changer ce que la suite exerce, pas la faire mentir.
var _K: Dictionary = {}
var _ids: PackedStringArray = PackedStringArray()

## Tout ce qui a été instancié, à libérer à la fin — un test qui fuit finit par
## masquer une vraie fuite.
var _trash: Array[Node] = []

# ---------------------------------------------------------------------------
# DOUBLURES
# ---------------------------------------------------------------------------

## Doublure de `GameSettings` qui COMPTE les écritures. C'est le seul moyen de
## prouver qu'afficher l'écran n'en déclenche aucune : un compteur à zéro dit ce
## qu'aucune valeur relue ne dirait, puisque réécrire la même valeur ne se voit
## nulle part.
class EspionReglages extends Node:
	var master_volume: float = 1.0
	var music_volume: float = 1.0
	var sfx_volume: float = 1.0
	var speaker_volume: float = 1.0
	var ecritures: int = 0

	func set_master_volume(linear: float) -> void:
		ecritures += 1
		master_volume = clampf(linear, 0.0, 1.0)

	func set_music_volume(linear: float) -> void:
		ecritures += 1
		music_volume = clampf(linear, 0.0, 1.0)

	func set_sfx_volume(linear: float) -> void:
		ecritures += 1
		sfx_volume = clampf(linear, 0.0, 1.0)

	func set_speaker_volume(linear: float) -> void:
		ecritures += 1
		speaker_volume = clampf(linear, 0.0, 1.0)

## Lecteur de musique factice : seul son état « en train de jouer » intéresse
## l'écran.
class FauxLecteur extends RefCounted:
	var playing: bool = false

## Doublure d'`AudioManager` : elle ne joue rien, elle note ce qu'on lui a
## demandé de jouer et sur quel bus.
class FauxAudio extends Node:
	var joues: Array[Dictionary] = []
	var music_player: Object = null
	## Sons que la doublure prétend connaître. Vide par défaut, comme le dépôt :
	## `res://assets/audio/speaker/` n'existe pas encore.
	var connus: PackedStringArray = PackedStringArray()

	func play_sfx(key: Variant, _pitch: float = 1.0, _db: float = 0.0,
			bus: String = "SFX") -> Variant:
		joues.append({"cle": String(key), "bus": bus})
		return null

	func play_speaker(key: Variant, _db: float = 0.0) -> void:
		joues.append({"cle": String(key), "bus": "Speaker"})

	func get_audio_stream(key: Variant) -> Variant:
		return AudioStreamWAV.new() if connus.has(String(key)) else null

	func oublie() -> void:
		joues.clear()

# ---------------------------------------------------------------------------

func _init() -> void:
	print("=== Test de l'écran Audio ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame

	var real_before := _snapshot_real_settings()

	if not _preflight():
		printerr("\n✗ Aucun test exécuté : l'écran Audio est absent ou incomplet")
		quit(1)
		return

	_test_avant_construction()
	_test_affichage()
	_test_zero_franc()
	_test_reglage_et_persistance()
	_test_ecretage()
	_test_conversion_deleguee()
	_test_idempotence()
	_test_aucune_reecriture()
	_test_audition()
	_test_delai_de_garde()
	_test_bus_absent()

	for node in _trash:
		if is_instance_valid(node):
			node.free()
	_wipe_tmp()

	_check("les préférences réelles du joueur sont intactes",
		_snapshot_real_settings() == real_before,
		"user://settings.cfg a été touché par le test")

	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

# ---------------------------------------------------------------------------
# CONTRÔLE PRÉALABLE
# ---------------------------------------------------------------------------
#
# Rien ne sert de conclure sur un écran qui n'a pas compilé : un script absent
# rend `null`, une instance nue avale tous les appels, et la suite annoncerait
# « tous les tests passent » sans avoir rien exercé.

func _preflight() -> bool:
	print("\n[Contrôle préalable]")

	_screen_script = load("res://screen_audio.gd") as GDScript
	_settings_script = load("res://settings_manager.gd") as GDScript
	_theme_script = load("res://menu_theme.gd") as GDScript

	var ok := true
	for pair in [["screen_audio.gd", _screen_script],
			["settings_manager.gd", _settings_script], ["menu_theme.gd", _theme_script]]:
		if pair[1] == null:
			printerr("  ✗ script introuvable ou non compilé : ", pair[0])
			ok = false
	if not ok:
		return false

	var declared := ""
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) == "ScreenAudio":
			declared = String(entry.get("path", ""))
	_check("ScreenAudio est au catalogue des classes globales", declared != "",
		"catalogue vide ou classe absente — lancer : Godot --headless --path . --import")
	_check("déclarée à la racine", declared == "res://screen_audio.gd", declared)
	if declared == "":
		return false

	_K = _screen_script.get_script_constant_map()
	for name in ["ROWS", "SLIDER_STEP", "SLIDER_MIN", "SLIDER_MAX", "MUTED_TEXT",
			"PREVIEW_NEUTRAL", "PREVIEW_SFX", "PREVIEW_SPEAKER"]:
		if not _K.has(name):
			printerr("  ✗ constante manquante : ", name)
			ok = false
	if not ok:
		return false

	# Les méthodes d'instance se cherchent sur une instance : `has_method` posé
	# sur le script lui-même ne rend que les fonctions statiques.
	var probe: Node = _screen_script.new()
	var missing := ""
	for method in ["screen_title", "build", "refresh", "focus_seed", "set_percent",
			"nudge", "percent_of", "value_text", "notice_text", "is_muted", "has_bus"]:
		if not probe.has_method(method):
			missing += method + " "
	for method in ["spec_of", "ids"]:
		if not _screen_script.has_method(method):
			missing += method + "(statique) "
	_check("l'écran porte tout ce que la suite exerce", missing == "", missing)
	_check("le titre de l'écran est renseigné",
		String(probe.screen_title()).strip_edges() != "")
	probe.free()
	if missing != "":
		return false

	_ids = _screen_script.ids()
	_check("les quatre volumes du mixage sont là",
		Array(_ids) == ["master", "music", "sfx", "speaker"], str(_ids))

	# La table de l'écran désigne des propriétés et des setters de
	# `settings_manager` : un renommage là-bas doit échouer ici, pas se traduire
	# par un curseur qui ne pilote plus rien.
	var settings := _make_settings()
	var lien_ok := true
	for id in _ids:
		var spec: Dictionary = _screen_script.spec_of(String(id))
		if settings.get(String(spec["prop"])) == null:
			lien_ok = false
			_check("propriété « %s » absente de GameSettings" % spec["prop"], false)
		if not settings.has_method(String(spec["setter"])):
			lien_ok = false
			_check("setter « %s » absent de GameSettings" % spec["setter"], false)
	if lien_ok:
		_check("chaque ligne est reliée à une préférence et à son setter", true)

	return _ids.size() == 4 and lien_ok

# ---------------------------------------------------------------------------
# OUTILLAGE
# ---------------------------------------------------------------------------

## Instance détachée de l'arbre : `_ready()` n'est pas appelé, donc ni la vidéo
## ni les liaisons de touches ne sont appliquées au passage. Le chemin de
## sauvegarde est dérivé AVANT tout usage.
func _make_settings() -> Node:
	var s: Node = _settings_script.new()
	s._settings_path = TMP_SETTINGS
	_trash.append(s)
	return s

## Un écran construit sur ses doublures — sans hub et sans autoload, comme le
## veut le contrat de `HubScreen`.
##
## `dans_arbre` n'est pas un détail de confort : **un `Range` hors de l'arbre
## n'émet jamais `value_changed`** (`Range::Shared::emit_value_changed()` saute
## les propriétaires détachés). Un écran testé détaché ne rejouerait donc ni le
## glissement à la souris, ni — surtout — le repositionnement des curseurs par
## `refresh()`, c'est-à-dire exactement le signal contre lequel le garde-fou
## anti-réécriture existe. La suite passerait sans rien prouver.
##
## Les doublures sont donc obligatoires ici : dans l'arbre, un écran sans
## `settings_override` s'adresserait à `/root/GameSettings` — l'autoload réel,
## qui écrit les vraies préférences d'un joueur.
func _make_screen(settings: Node, audio: Node, dans_arbre: bool = true) -> Control:
	var screen: Control = _screen_script.new()
	screen.name = "EcranAudioEssai%d" % _trash.size()
	screen.settings_override = settings
	screen.audio_override = audio
	if dans_arbre:
		root.add_child(screen)
	var body := VBoxContainer.new()
	screen.add_child(body)
	screen.build(body)
	_trash.append(screen)
	return screen

func _make_audio() -> Node:
	var audio := FauxAudio.new()
	_trash.append(audio)
	return audio

## Empreinte de tout ce que l'écran montre. Deux empreintes égales, c'est le même
## écran — c'est la mesure de l'idempotence.
func _signature(screen: Control) -> String:
	var parts := PackedStringArray()
	for id in _ids:
		parts.append("%s=%d/%s/%s" % [id, screen.percent_of(String(id)),
			screen.value_text(String(id)), screen.notice_text(String(id))])
	return "|".join(parts)

func _value_color(screen: Control, id: String) -> Color:
	return (screen._rows[id]["value"] as Label).get_theme_color(&"font_color")

func _step() -> int:
	return int(_K["SLIDER_STEP"])

func _muted_text() -> String:
	return String(_K["MUTED_TEXT"])

func _wipe_tmp() -> void:
	if FileAccess.file_exists(TMP_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SETTINGS))

## Empreinte du fichier de préférences réel. Le test doit le laisser exactement
## dans l'état où il l'a trouvé — y compris absent.
func _snapshot_real_settings() -> String:
	if not FileAccess.file_exists(REAL_SETTINGS):
		return "<absent>"
	return FileAccess.get_file_as_string(REAL_SETTINGS)

# ---------------------------------------------------------------------------
# AVANT TOUTE CONSTRUCTION
# ---------------------------------------------------------------------------
#
# Le hub appelle `refresh()` sur des écrans qu'il n'a pas encore montrés, et
# parfois jamais construits. Un plantage ici ne se verrait qu'à l'ouverture d'un
# autre écran, ce qui est le pire endroit pour en chercher la cause.

func _test_avant_construction() -> void:
	print("\n[Avant construction]")

	var screen: Control = _screen_script.new()
	_trash.append(screen)

	screen.refresh()
	screen.refresh()
	_check("rafraîchir un écran jamais construit ne plante pas", true)
	_check("aucun contrôle à viser", screen.focus_seed() == null)

	screen.build(null)
	_check("construire sans corps ne plante pas", true)

	screen.set_percent("master", 50)
	screen.nudge("master", -1)
	_check("régler avant construction ne plante pas", true)

	screen.set_percent("bus_inconnu", 50)
	screen.nudge("bus_inconnu", 1)
	_check("un identifiant inconnu est ignoré en silence", true)
	_check("et ne fabrique aucune ligne", screen.value_text("bus_inconnu") == "")

	# Sans préférences du tout — ni autoload, ni doublure — l'écran doit tenir :
	# c'est le cas de toute suite headless.
	var body := VBoxContainer.new()
	screen.add_child(body)
	screen.build(body)
	screen.refresh()
	var count := body.get_child_count()
	_check("un écran sans préférences s'affiche quand même", count > 0, str(count))
	_check("et montre le niveau nominal", screen.percent_of("master") == 100,
		str(screen.percent_of("master")))

	screen.build(body)
	_check("construire deux fois ne double pas le contenu",
		body.get_child_count() == count, "%d puis %d" % [count, body.get_child_count()])

# ---------------------------------------------------------------------------
# L'AFFICHAGE REFLÈTE LES VALEURS RÉELLES
# ---------------------------------------------------------------------------

func _test_affichage() -> void:
	print("\n[Affichage]")

	var settings := _make_settings()
	settings.master_volume = 0.7
	settings.music_volume = 0.3
	settings.sfx_volume = 1.0
	settings.speaker_volume = 0.5

	var screen := _make_screen(settings, _make_audio())
	_check("le général affiche le niveau retenu", screen.percent_of("master") == 70,
		str(screen.percent_of("master")))
	_check("la musique aussi", screen.percent_of("music") == 30,
		str(screen.percent_of("music")))
	_check("les effets aussi", screen.percent_of("sfx") == 100,
		str(screen.percent_of("sfx")))
	_check("l'annonceur aussi", screen.percent_of("speaker") == 50,
		str(screen.percent_of("speaker")))
	_check("le pourcentage affiché est bien celui de settings_manager",
		screen.percent_of("music") == _settings_script.volume_to_percent(0.3))
	_check("le chiffre est écrit en pourcents", screen.value_text("master") == "70 %",
		screen.value_text("master"))
	_check("la ligne explique ce qu'on règle",
		screen.notice_text("sfx") == String(_screen_script.spec_of("sfx")["detail"]),
		screen.notice_text("sfx"))

	# L'écran ne garde pas de copie : un volume changé ailleurs — un autre écran,
	# une remise à zéro — doit apparaître au rafraîchissement suivant.
	settings.speaker_volume = 0.1
	screen.refresh()
	_check("un volume changé ailleurs s'affiche au rafraîchissement",
		screen.percent_of("speaker") == 10, str(screen.percent_of("speaker")))

# ---------------------------------------------------------------------------
# LE ZÉRO EST FRANC
# ---------------------------------------------------------------------------
#
# `settings_manager` coupe le bus à zéro plutôt que de lui envoyer moins
# l'infini. « 0 % » se lirait comme un niveau très bas ; l'écran doit dire que
# c'est coupé.

func _test_zero_franc() -> void:
	print("\n[Le zéro]")

	var settings := _make_settings()
	settings.music_volume = 0.0
	var screen := _make_screen(settings, _make_audio())

	_check("le zéro s'écrit « %s »" % _muted_text(),
		screen.value_text("music") == _muted_text(), screen.value_text("music"))
	_check("et ne s'écrit pas en pourcents",
		not screen.value_text("music").contains("%"), screen.value_text("music"))
	_check("l'écran le signale comme coupé", screen.is_muted("music"))
	_check("dans la couleur des avertissements, qui ne sont pas des erreurs",
		_value_color(screen, "music") == Color(_theme_script.get_script_constant_map()["WARN"]),
		str(_value_color(screen, "music")))

	# Les autres lignes ne sont pas contaminées : couper la musique ne coupe pas
	# le reste.
	_check("les autres volumes restent des pourcentages",
		screen.value_text("sfx").ends_with("%"), screen.value_text("sfx"))
	_check("et ne se disent pas coupés", not screen.is_muted("sfx"))

	screen.nudge("music", 1)
	_check("un cran au-dessus de zéro redevient un pourcentage",
		screen.value_text("music") == "%d %%" % _step(), screen.value_text("music"))
	_check("et n'est plus coupé", not screen.is_muted("music"))

	screen.set_percent("music", 0)
	_check("retour à zéro : le mot revient", screen.value_text("music") == _muted_text(),
		screen.value_text("music"))
	_wipe_tmp()

# ---------------------------------------------------------------------------
# RÉGLER, ET RETROUVER LE RÉGLAGE AU LANCEMENT SUIVANT
# ---------------------------------------------------------------------------

func _test_reglage_et_persistance() -> void:
	print("\n[Réglage et persistance]")
	_wipe_tmp()

	var settings := _make_settings()
	var screen := _make_screen(settings, _make_audio())

	screen.set_percent("sfx", 40)
	_check("le réglage arrive dans les préférences",
		is_equal_approx(settings.sfx_volume, 0.4), str(settings.sfx_volume))
	_check("et l'écran l'affiche", screen.percent_of("sfx") == 40,
		str(screen.percent_of("sfx")))
	_check("le fichier de préférences est écrit", FileAccess.file_exists(TMP_SETTINGS))

	var relu := _make_settings()
	relu._load()
	_check("et relu au lancement suivant", is_equal_approx(relu.sfx_volume, 0.4),
		str(relu.sfx_volume))

	# Le chemin de la manette : un cran par activation d'un bouton de pas.
	screen.nudge("sfx", 1)
	_check("un cran ajoute le pas de la table",
		screen.percent_of("sfx") == 40 + _step(), str(screen.percent_of("sfx")))
	screen.nudge("sfx", -1)
	_check("le cran inverse le retire", screen.percent_of("sfx") == 40,
		str(screen.percent_of("sfx")))

	# Le chemin de la souris : bouger le curseur emprunte le même code. Il faut
	# l'écran dans l'arbre pour l'exercer — voir `_make_screen()`.
	(screen._rows["sfx"]["slider"] as HSlider).value = 20.0
	_check("glisser le curseur écrit aussi la préférence",
		is_equal_approx(settings.sfx_volume, 0.2), str(settings.sfx_volume))
	_check("et l'affichage suit", screen.value_text("sfx") == "20 %",
		screen.value_text("sfx"))

	# Les quatre lignes sont indépendantes : régler l'une ne touche pas les
	# autres, faute de quoi un seul curseur piloterait tout le mixage.
	_check("régler les effets n'a pas bougé le général",
		is_equal_approx(settings.master_volume, 1.0), str(settings.master_volume))
	_check("ni la musique", is_equal_approx(settings.music_volume, 1.0),
		str(settings.music_volume))
	_check("ni l'annonceur", is_equal_approx(settings.speaker_volume, 1.0),
		str(settings.speaker_volume))
	_wipe_tmp()

# ---------------------------------------------------------------------------
# ÉCRÊTAGE AUX BORNES
# ---------------------------------------------------------------------------

func _test_ecretage() -> void:
	print("\n[Bornes]")

	var settings := _make_settings()
	var screen := _make_screen(settings, _make_audio())

	screen.set_percent("master", 250)
	_check("au-delà de la course, on s'arrête au nominal",
		screen.percent_of("master") == 100, str(screen.percent_of("master")))
	_check("et aucun gain n'est fabriqué", is_equal_approx(settings.master_volume, 1.0),
		str(settings.master_volume))
	screen.nudge("master", 1)
	_check("un cran de plus au sommet ne déborde pas",
		screen.percent_of("master") == 100, str(screen.percent_of("master")))

	screen.set_percent("master", -80)
	_check("en deçà de la course, on s'arrête à zéro",
		screen.percent_of("master") == 0, str(screen.percent_of("master")))
	_check("et la préférence est bien nulle", settings.master_volume == 0.0,
		str(settings.master_volume))
	screen.nudge("master", -1)
	_check("un cran de moins au plancher ne passe pas sous zéro",
		screen.percent_of("master") == 0, str(screen.percent_of("master")))
	_check("le plancher se dit toujours « %s »" % _muted_text(),
		screen.value_text("master") == _muted_text(), screen.value_text("master"))

	# Le curseur lui-même ne doit pas offrir plus que la course permise.
	var slider := screen._rows["master"]["slider"] as HSlider
	_check("la course du curseur est celle de la table",
		slider.min_value == float(_K["SLIDER_MIN"]) and slider.max_value == float(_K["SLIDER_MAX"]),
		"%f → %f" % [slider.min_value, slider.max_value])
	_wipe_tmp()

# ---------------------------------------------------------------------------
# LA CONVERSION N'EST PAS REFAITE ICI
# ---------------------------------------------------------------------------
#
# La valeur retenue est une amplitude LINÉAIRE ; c'est `settings_manager` qui la
# convertit en décibels au moment de l'appliquer. Un écran qui graduerait sa
# course en décibels tasserait tout le changement perçu dans les derniers
# pourcents — les trois premiers quarts du curseur ne serviraient à rien.

func _test_conversion_deleguee() -> void:
	print("\n[Conversion]")

	var settings := _make_settings()
	var screen := _make_screen(settings, _make_audio())

	screen.set_percent("music", 50)
	_check("la mi-course vaut une amplitude de 0,5",
		is_equal_approx(settings.music_volume, 0.5), str(settings.music_volume))
	_check("soit environ -6 dB une fois appliquée, et non la mi-course des décibels",
		absf(_settings_script.volume_to_db(settings.music_volume) + 6.0206) < 0.01,
		str(_settings_script.volume_to_db(settings.music_volume)))

	var aller_retour := true
	for percent in [0, 10, 30, 50, 70, 90, 100]:
		screen.set_percent("sfx", percent)
		if screen.percent_of("sfx") != percent:
			aller_retour = false
			_check("aller-retour pourcentage → amplitude → affichage", false,
				"%d → %d" % [percent, screen.percent_of("sfx")])
			break
		if not is_equal_approx(settings.sfx_volume, _settings_script.percent_to_volume(percent)):
			aller_retour = false
			_check("l'amplitude retenue est celle de percent_to_volume()", false,
				"%d → %f" % [percent, settings.sfx_volume])
			break
	if aller_retour:
		_check("toute la course se relit à l'identique, sans dérive", true)
	_wipe_tmp()

# ---------------------------------------------------------------------------
# IDEMPOTENCE
# ---------------------------------------------------------------------------

func _test_idempotence() -> void:
	print("\n[Idempotence]")

	var settings := _make_settings()
	settings.master_volume = 0.6
	settings.music_volume = 0.0
	settings.sfx_volume = 0.25
	var screen := _make_screen(settings, _make_audio())

	var before := _signature(screen)
	screen.refresh()
	screen.refresh()
	_check("deux rafraîchissements de suite donnent le même écran",
		_signature(screen) == before, "%s\n     puis %s" % [before, _signature(screen)])

	# Y compris avec un volume coupé : le mot ne doit pas se transformer en
	# pourcentage au second passage.
	_check("le volume coupé le reste", screen.value_text("music") == _muted_text(),
		screen.value_text("music"))

# ---------------------------------------------------------------------------
# AFFICHER N'EST PAS ÉCRIRE
# ---------------------------------------------------------------------------
#
# LE test de la suite. Repositionner un curseur émet `value_changed` comme si le
# joueur l'avait bougé : sans garde-fou, ouvrir l'écran réécrit et resauvegarde
# les quatre volumes. Le défaut est invisible tant que les valeurs coïncident,
# et se paie le jour où elles ne coïncident plus.

func _test_aucune_reecriture() -> void:
	print("\n[Afficher n'est pas écrire]")
	_wipe_tmp()

	var settings := _make_settings()
	# Posé sans passer par le setter : rien n'est sauvegardé à cet instant.
	settings.master_volume = 0.42
	settings.music_volume = 0.0
	var screen := _make_screen(settings, _make_audio())
	screen.refresh()
	screen.refresh()

	_check("afficher l'écran n'écrit aucun fichier de préférences",
		not FileAccess.file_exists(TMP_SETTINGS))
	_check("et ne modifie aucune valeur", is_equal_approx(settings.master_volume, 0.42),
		str(settings.master_volume))
	_check("le zéro non plus n'est pas relevé", settings.music_volume == 0.0,
		str(settings.music_volume))

	# Le compteur dit ce qu'aucune valeur relue ne dirait : réécrire la même
	# valeur ne se voit nulle part, mais sauvegarde quand même.
	var espion := EspionReglages.new()
	_trash.append(espion)
	espion.master_volume = 0.42
	espion.music_volume = 0.0
	var espionne := _make_screen(espion, _make_audio())
	espionne.refresh()
	espionne.refresh()
	_check("aucun setter n'est appelé au simple affichage", espion.ecritures == 0,
		"%d appel(s)" % espion.ecritures)

	espionne.set_percent("master", 20)
	_check("mais un vrai réglage passe bien par le setter", espion.ecritures == 1,
		"%d appel(s)" % espion.ecritures)

	# Régler à la valeur déjà retenue n'a rien à sauvegarder non plus.
	espionne.set_percent("master", 20)
	_check("régler à la valeur déjà en place n'écrit pas une seconde fois",
		espion.ecritures == 1, "%d appel(s)" % espion.ecritures)
	_wipe_tmp()

# ---------------------------------------------------------------------------
# UN RÉGLAGE QU'ON N'ENTEND PAS NE SE RÈGLE PAS
# ---------------------------------------------------------------------------

func _test_audition() -> void:
	print("\n[Audition]")

	var settings := _make_settings()
	var audio := _make_audio()
	var screen := _make_screen(settings, audio)
	# Le délai de garde a sa propre section : ici on veut voir chaque audition.
	screen.preview_cooldown_ms = 0

	audio.oublie()
	screen.set_percent("master", 80)
	_check("régler le général fait sonner le bus Master",
		audio.joues.size() == 1 and audio.joues[0]["bus"] == "Master", str(audio.joues))

	audio.oublie()
	screen.set_percent("sfx", 70)
	_check("régler les effets joue le son du duel, sur le bus SFX",
		audio.joues.size() == 1 and audio.joues[0]["cle"] == String(_K["PREVIEW_SFX"])
		and audio.joues[0]["bus"] == "SFX", str(audio.joues))

	# La voix de l'annonceur n'est pas encore dans le dépôt : sans repli, le
	# curseur ne ferait aucun bruit, ce qui ne se distingue pas d'un curseur
	# cassé.
	audio.oublie()
	screen.set_percent("speaker", 60)
	_check("sans voix d'annonceur, la mire passe quand même par le bus Speaker",
		audio.joues.size() == 1 and audio.joues[0]["bus"] == "Speaker", str(audio.joues))
	audio.connus = PackedStringArray([String(_K["PREVIEW_SPEAKER"])])
	audio.oublie()
	screen.set_percent("speaker", 50)
	_check("le jour où la voix existe, c'est elle qu'on entend",
		audio.joues.size() == 1 and audio.joues[0]["cle"] == String(_K["PREVIEW_SPEAKER"]),
		str(audio.joues))

	# La musique du menu tourne déjà pendant qu'on la règle : elle EST l'audition.
	var lecteur := FauxLecteur.new()
	lecteur.playing = true
	audio.music_player = lecteur
	audio.oublie()
	screen.set_percent("music", 40)
	_check("musique en cours : rien ne vient se superposer", audio.joues.is_empty(),
		str(audio.joues))
	lecteur.playing = false
	audio.oublie()
	screen.set_percent("music", 30)
	_check("musique à l'arrêt : une mire passe par le bus Musique",
		audio.joues.size() == 1 and audio.joues[0]["bus"] == "Music", str(audio.joues))

	# À zéro le silence EST la réponse : jouer quelque chose reviendrait à ne
	# rien jouer, en occupant une voix.
	audio.oublie()
	screen.set_percent("sfx", 0)
	_check("à zéro, aucune audition", audio.joues.is_empty(), str(audio.joues))
	audio.oublie()
	screen.nudge("sfx", -1)
	_check("insister sous le plancher n'en déclenche pas davantage",
		audio.joues.is_empty(), str(audio.joues))

	# Un écran sans AudioManager — toute suite headless — ne doit pas plus
	# planter qu'un écran sans préférences.
	var muet := _make_screen(_make_settings(), null, false)
	muet.set_percent("master", 30)
	_check("sans AudioManager, régler ne plante pas", muet.percent_of("master") == 30,
		str(muet.percent_of("master")))
	_wipe_tmp()

func _test_delai_de_garde() -> void:
	print("\n[Délai de garde]")

	var settings := _make_settings()
	var audio := _make_audio()
	var screen := _make_screen(settings, audio)
	_check("le délai par défaut n'est pas nul", int(screen.preview_cooldown_ms) > 0,
		str(screen.preview_cooldown_ms))

	# Trois crans dans la même milliseconde : c'est un glissement à la souris, pas
	# trois décisions du joueur.
	audio.oublie()
	screen.set_percent("master", 70)
	screen.set_percent("master", 60)
	screen.set_percent("master", 50)
	_check("un glissement ne déclenche pas une audition par cran",
		audio.joues.size() == 1, str(audio.joues))
	_check("mais toutes les valeurs ont bien été écrites",
		screen.percent_of("master") == 50 and is_equal_approx(settings.master_volume, 0.5),
		str(settings.master_volume))

	# Le délai est par bus : passer d'un volume à l'autre s'entend tout de suite,
	# sinon le premier réglage bâillonnerait le suivant.
	audio.oublie()
	screen.set_percent("sfx", 40)
	_check("un autre volume s'entend immédiatement", audio.joues.size() == 1,
		str(audio.joues))

	# Le relâchement du curseur rejoue la valeur définitive : sans cela, le
	# dernier cran d'un glissement rapide serait avalé par le délai, et on aurait
	# entendu l'avant-dernier.
	audio.oublie()
	(screen._rows["master"]["slider"] as HSlider).drag_ended.emit(true)
	_check("le relâchement fait entendre la valeur définitive malgré le délai",
		audio.joues.size() == 1, str(audio.joues))
	audio.oublie()
	(screen._rows["master"]["slider"] as HSlider).drag_ended.emit(false)
	_check("un clic qui n'a rien changé ne joue rien", audio.joues.is_empty(),
		str(audio.joues))
	_wipe_tmp()

# ---------------------------------------------------------------------------
# BUS ABSENT DE LA DISPOSITION
# ---------------------------------------------------------------------------
#
# Une disposition audio remplacée ou un bus renommé rend un index -1.
# `settings_manager` traverse déjà le cas en silence ; l'écran, lui, doit rester
# lisible et dire pourquoi rien ne changera à l'oreille — sans quoi le joueur
# conclut que le curseur est cassé.

func _test_bus_absent() -> void:
	print("\n[Bus absent]")

	var bus := String(_screen_script.spec_of("speaker")["bus"])
	var idx := AudioServer.get_bus_index(bus)
	_check("le bus « %s » est présent au départ" % bus, idx != -1,
		"disposition audio non importée — lancer : Godot --headless --path . --import")
	if idx == -1:
		return

	var send := AudioServer.get_bus_send(idx)
	AudioServer.remove_bus(idx)

	var settings := _make_settings()
	settings.speaker_volume = 0.6
	var audio := _make_audio()
	var screen := _make_screen(settings, audio)

	_check("la ligne reste lisible", screen.percent_of("speaker") == 60,
		str(screen.percent_of("speaker")))
	_check("l'écran ne prétend pas que le bus est là", not screen.has_bus("speaker"))
	_check("et il nomme le bus manquant", screen.notice_text("speaker").contains(bus),
		screen.notice_text("speaker"))
	_check("les autres lignes ne sont pas contaminées",
		screen.has_bus("master")
		and screen.notice_text("master") == String(_screen_script.spec_of("master")["detail"]),
		screen.notice_text("master"))

	audio.oublie()
	screen.set_percent("speaker", 40)
	_check("régler un volume dont le bus a disparu ne plante pas",
		is_equal_approx(settings.speaker_volume, 0.4), str(settings.speaker_volume))
	_check("la valeur est quand même retenue pour le jour où le bus revient",
		screen.percent_of("speaker") == 40, str(screen.percent_of("speaker")))
	_check("et rien n'est envoyé sonner dans le vide", audio.joues.is_empty(),
		str(audio.joues))

	# Remise en état : les tests suivants ne doivent pas hériter d'un mixage
	# amputé.
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus)
	AudioServer.set_bus_send(idx, send)
	_check("bus rétabli", AudioServer.get_bus_index(bus) == idx)

	screen.refresh()
	_check("le bus rétabli, la ligne redevient normale",
		screen.notice_text("speaker") == String(_screen_script.spec_of("speaker")["detail"]),
		screen.notice_text("speaker"))
	_wipe_tmp()
