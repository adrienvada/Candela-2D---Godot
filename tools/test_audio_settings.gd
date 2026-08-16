## Test headless des réglages de volume audio (section `audio` de
## user://settings.cfg).
##
## Vérifie les hypothèses dont dépendent les quatre curseurs de volume :
##   • la conversion amplitude linéaire ↔ décibels, dans les deux sens
##   • le zéro, qui vaut moins l'infini en décibels et doit couper franchement
##   • l'écrêtage des valeurs hors bornes, à l'écriture comme à la relecture
##   • la persistance : écrire, relire, retrouver la même valeur
##   • un bus absent de la disposition, qui ne doit rien faire planter
##
## Lancer : godot --headless --path . --script res://tools/test_audio_settings.gd
extends SceneTree

## `settings_manager.gd` est l'autoload GameSettings : indisponible en mode
## --script, où `_init()` s'exécute avant l'enregistrement des autoloads. On
## charge donc le script directement, comme test_arena_build.gd le fait pour
## MapData.
const Settings := preload("res://settings_manager.gd")

## Jamais user://settings.cfg : les tests headless partagent le `user://` du jeu
## installé, et une suite qui écrit là écraserait les préférences réelles.
const TMP_SETTINGS := "user://test_audio_settings.cfg"
const REAL_SETTINGS := "user://settings.cfg"

## Tolérance des comparaisons en décibels : on compare des niveaux audibles,
## pas des flottants exacts.
const DB_TOLERANCE := 0.01

var _failures: int = 0

func _init() -> void:
	print("=== Test réglages audio ===")

	var real_before := _snapshot_real_settings()

	if not _preflight():
		printerr("\n✗ Aucun test exécuté : l'API audio est absente")
		quit(1)
		return

	_test_conversion()
	_test_silence()
	_test_clamping()
	_test_percent_helpers()
	_test_bus_application()
	_test_persistence()
	_test_missing_bus()

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
# Un script qui n'a pas compilé rend un objet nu : les appels suivants échouent
# sans incrémenter aucun compteur, et la suite annonce « tous les tests
# passent » sans avoir rien exécuté. On vérifie donc que ce qu'on s'apprête à
# tester existe réellement avant de conclure quoi que ce soit.
func _preflight() -> bool:
	print("\n[Contrôle préalable]")

	var probe := Settings.new()
	if probe == null:
		printerr("  ✗ settings_manager.gd n'a pas produit d'instance")
		return false

	var ok := true
	for method in ["set_master_volume", "set_music_volume", "set_sfx_volume",
			"set_speaker_volume", "volume_to_db", "db_to_volume", "clamp_volume"]:
		if not probe.has_method(method):
			printerr("  ✗ méthode manquante : ", method)
			ok = false
	for prop in ["master_volume", "music_volume", "sfx_volume", "speaker_volume"]:
		if probe.get(prop) == null:
			printerr("  ✗ propriété manquante : ", prop)
			ok = false
	probe.free()

	if ok:
		print("  ✓ l'API audio est bien présente sur GameSettings")
	return ok

## Instance détachée de l'arbre : `_ready()` n'est pas appelé, donc rien de
## l'état vidéo ou des liaisons n'est appliqué au passage.
func _make_settings() -> Node:
	var s := Settings.new()
	s._settings_path = TMP_SETTINGS
	return s

# ---------------------------------------------------------------------------
# CONVERSION LINÉAIRE ↔ DÉCIBELS
# ---------------------------------------------------------------------------

func _test_conversion() -> void:
	print("\n[Conversion linéaire ↔ décibels]")

	_check("le nominal vaut 0 dB", is_zero_approx(Settings.volume_to_db(1.0)),
		str(Settings.volume_to_db(1.0)))
	_check("la moitié d'amplitude vaut ≈ -6 dB",
		absf(Settings.volume_to_db(0.5) + 6.0206) < DB_TOLERANCE,
		str(Settings.volume_to_db(0.5)))
	_check("le quart d'amplitude vaut ≈ -12 dB",
		absf(Settings.volume_to_db(0.25) + 12.0412) < DB_TOLERANCE,
		str(Settings.volume_to_db(0.25)))

	# C'est tout l'intérêt de la conversion : un curseur droit sur l'échelle des
	# décibels placerait le milieu de course vers -40 dB, c'est-à-dire déjà
	# quasi inaudible. Les trois quarts de la course ne serviraient à rien.
	_check("la mi-course reste largement audible",
		Settings.volume_to_db(0.5) > Settings.SILENCE_DB / 2.0,
		"%f dB" % Settings.volume_to_db(0.5))

	var monotone := true
	var previous := Settings.volume_to_db(0.0)
	for step in range(1, 101):
		var current := Settings.volume_to_db(float(step) / 100.0)
		if current <= previous:
			monotone = false
			break
		previous = current
	_check("la conversion est strictement croissante sur toute la course", monotone)

	var roundtrip_ok := true
	for linear in [0.02, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]:
		var back: float = Settings.db_to_volume(Settings.volume_to_db(linear))
		if not is_equal_approx(back, linear):
			roundtrip_ok = false
			_check("aller-retour linéaire → dB → linéaire", false,
				"%f → %f" % [linear, back])
			break
	if roundtrip_ok:
		_check("aller-retour linéaire → dB → linéaire", true)

	var db_roundtrip_ok := true
	for db in [-40.0, -24.0, -12.0, -6.0, -0.5, 0.0]:
		var back: float = Settings.volume_to_db(Settings.db_to_volume(db))
		if absf(back - db) > DB_TOLERANCE:
			db_roundtrip_ok = false
			_check("aller-retour dB → linéaire → dB", false, "%f → %f" % [db, back])
			break
	if db_roundtrip_ok:
		_check("aller-retour dB → linéaire → dB", true)

# ---------------------------------------------------------------------------
# LE ZÉRO
# ---------------------------------------------------------------------------

func _test_silence() -> void:
	print("\n[Le zéro]")

	# La raison d'être du garde-fou, vérifiée sur la fonction du moteur
	# elle-même : c'est cette valeur qu'AudioServer ne doit jamais recevoir.
	_check("linear_to_db(0) vaut bien moins l'infini", is_inf(linear_to_db(0.0)))

	var floor_db: float = Settings.volume_to_db(0.0)
	_check("un volume nul ne rend jamais moins l'infini",
		not is_inf(floor_db) and not is_nan(floor_db), str(floor_db))
	_check("un volume nul rend le plancher", is_equal_approx(floor_db, Settings.SILENCE_DB),
		str(floor_db))
	_check("juste sous le seuil de silence, plancher aussi",
		is_equal_approx(Settings.volume_to_db(Settings.SILENCE_LINEAR * 0.5),
			Settings.SILENCE_DB))

	# La réciproque doit rendre un zéro franc, pas un résidu inaudible mais non
	# nul : sinon un curseur poussé à fond en bas ne reviendrait jamais à zéro.
	_check("le plancher redonne un zéro exact", Settings.db_to_volume(Settings.SILENCE_DB) == 0.0,
		str(Settings.db_to_volume(Settings.SILENCE_DB)))
	_check("en dessous du plancher, zéro aussi", Settings.db_to_volume(-200.0) == 0.0)
	_check("moins l'infini ne casse pas la réciproque", Settings.db_to_volume(-INF) == 0.0)

# ---------------------------------------------------------------------------
# ÉCRÊTAGE
# ---------------------------------------------------------------------------

func _test_clamping() -> void:
	print("\n[Valeurs hors bornes]")

	_check("valeur négative écrêtée à zéro", Settings.clamp_volume(-3.0) == 0.0)
	_check("valeur supérieure à 1 écrêtée au nominal", Settings.clamp_volume(2.5) == 1.0)
	# Aucun réglage ne doit pouvoir amplifier au-delà du mixage d'origine : ce
	# serait de la saturation, pas du volume.
	_check("jamais de gain positif", is_zero_approx(Settings.volume_to_db(4.0)),
		str(Settings.volume_to_db(4.0)))

	var s := _make_settings()
	s.set_master_volume(5.0)
	_check("un curseur qui déborde est écrêté par le setter",
		s.master_volume == 1.0, str(s.master_volume))
	s.set_music_volume(-1.0)
	_check("une valeur négative est écrêtée par le setter",
		s.music_volume == 0.0, str(s.music_volume))
	s.set_sfx_volume(0.6)
	_check("une valeur valide passe telle quelle",
		is_equal_approx(s.sfx_volume, 0.6), str(s.sfx_volume))
	s.free()
	_wipe_tmp()

func _test_percent_helpers() -> void:
	print("\n[Curseurs gradués de 0 à 100]")

	_check("mi-course affiche 50 %", Settings.volume_to_percent(0.5) == 50)
	_check("nominal affiche 100 %", Settings.volume_to_percent(1.0) == 100)
	_check("silence affiche 0 %", Settings.volume_to_percent(0.0) == 0)
	_check("un pourcentage négatif est écrêté", Settings.volume_to_percent(-2.0) == 0)
	_check("un pourcentage débordant est écrêté", Settings.volume_to_percent(3.0) == 100)
	_check("35 % rend 0,35", is_equal_approx(Settings.percent_to_volume(35), 0.35),
		str(Settings.percent_to_volume(35)))
	_check("150 % est écrêté au nominal", Settings.percent_to_volume(150) == 1.0)
	_check("-20 % est écrêté à zéro", Settings.percent_to_volume(-20) == 0.0)
	_check("aller-retour pourcentage",
		Settings.volume_to_percent(Settings.percent_to_volume(73)) == 73)

# ---------------------------------------------------------------------------
# APPLICATION SUR LES BUS
# ---------------------------------------------------------------------------

func _test_bus_application() -> void:
	print("\n[Application sur les bus]")

	for bus in [Settings.BUS_MASTER, Settings.BUS_MUSIC, Settings.BUS_SFX,
			Settings.BUS_SPEAKER]:
		_check("le bus « %s » existe dans la disposition" % bus,
			AudioServer.get_bus_index(bus) != -1)

	var music_idx := AudioServer.get_bus_index(Settings.BUS_MUSIC)
	var sfx_idx := AudioServer.get_bus_index(Settings.BUS_SFX)
	if music_idx == -1 or sfx_idx == -1:
		return

	var s := _make_settings()

	# Relevé avant/après plutôt que valeur absolue : le mixage a pu être bougé
	# par un test précédent, ce qui est justement ce qu'on veut ne PAS voir
	# arriver d'un bus à l'autre.
	var sfx_before := AudioServer.get_bus_volume_db(sfx_idx)
	s.set_music_volume(0.5)
	_check("le bus Music reçoit -6 dB et non 50 dB de n'importe quoi",
		absf(AudioServer.get_bus_volume_db(music_idx) + 6.0206) < DB_TOLERANCE,
		str(AudioServer.get_bus_volume_db(music_idx)))
	_check("le bus Music n'est pas coupé", not AudioServer.is_bus_mute(music_idx))
	_check("régler la musique ne touche pas aux effets",
		is_equal_approx(AudioServer.get_bus_volume_db(sfx_idx), sfx_before),
		"%f → %f" % [sfx_before, AudioServer.get_bus_volume_db(sfx_idx)])

	s.set_music_volume(0.0)
	_check("volume nul → bus coupé net", AudioServer.is_bus_mute(music_idx))
	_check("volume nul → décibels finis sur le bus",
		not is_inf(AudioServer.get_bus_volume_db(music_idx)),
		str(AudioServer.get_bus_volume_db(music_idx)))

	s.set_music_volume(1.0)
	_check("retour au nominal → bus rouvert",
		not AudioServer.is_bus_mute(music_idx)
		and is_zero_approx(AudioServer.get_bus_volume_db(music_idx)))

	# Les quatre bus doivent être servis d'un coup au démarrage, pas seulement
	# celui qu'on vient de bouger.
	s.master_volume = 0.3
	s.music_volume = 0.4
	s.sfx_volume = 0.5
	s.speaker_volume = 0.6
	s._apply_audio()
	var applied_ok := true
	for pair in [[Settings.BUS_MASTER, 0.3], [Settings.BUS_MUSIC, 0.4],
			[Settings.BUS_SFX, 0.5], [Settings.BUS_SPEAKER, 0.6]]:
		var idx := AudioServer.get_bus_index(pair[0])
		var expected: float = Settings.volume_to_db(pair[1])
		if absf(AudioServer.get_bus_volume_db(idx) - expected) > DB_TOLERANCE:
			applied_ok = false
			_check("application groupée du bus « %s »" % pair[0], false,
				"%f attendu, %f obtenu" % [expected, AudioServer.get_bus_volume_db(idx)])
			break
	if applied_ok:
		_check("les quatre bus reçoivent leur niveau au démarrage", true)

	s.free()
	_wipe_tmp()

# ---------------------------------------------------------------------------
# PERSISTANCE
# ---------------------------------------------------------------------------

func _test_persistence() -> void:
	print("\n[Persistance]")
	_wipe_tmp()

	var writer := _make_settings()
	writer.set_master_volume(0.42)
	writer.set_music_volume(0.0)
	writer.set_sfx_volume(1.0)
	writer.set_speaker_volume(0.77)
	# Un réglage vidéo au passage : la nouvelle section ne doit pas déloger les
	# anciennes.
	writer.set_fps_cap(120)
	writer.free()

	_check("le fichier de préférences est écrit", FileAccess.file_exists(TMP_SETTINGS))

	var cfg := ConfigFile.new()
	_check("le fichier se relit", cfg.load(TMP_SETTINGS) == OK)
	_check("section « audio » présente", cfg.has_section(Settings.SECTION_AUDIO))
	for key in ["master", "music", "sfx", "speaker"]:
		_check("clé « %s » enregistrée" % key,
			cfg.has_section_key(Settings.SECTION_AUDIO, key))

	var reader := _make_settings()
	reader._load()
	_check("volume général relu", is_equal_approx(reader.master_volume, 0.42),
		str(reader.master_volume))
	_check("musique coupée relue", reader.music_volume == 0.0, str(reader.music_volume))
	_check("effets relus", is_equal_approx(reader.sfx_volume, 1.0), str(reader.sfx_volume))
	_check("annonceur relu", is_equal_approx(reader.speaker_volume, 0.77),
		str(reader.speaker_volume))
	_check("les réglages vidéo survivent à l'ajout de la section audio",
		reader.fps_cap == 120, str(reader.fps_cap))
	reader.free()

	# Installation neuve : aucun fichier, tout au nominal, aucun bus touché.
	_wipe_tmp()
	var fresh := _make_settings()
	fresh._load()
	_check("sans fichier, tout est au niveau nominal",
		fresh.master_volume == 1.0 and fresh.music_volume == 1.0
		and fresh.sfx_volume == 1.0 and fresh.speaker_volume == 1.0)
	fresh.free()

	# Fichier trafiqué à la main ou écrit par une version antérieure : il ne doit
	# ni empêcher le démarrage, ni laisser passer une valeur aberrante.
	var tampered := ConfigFile.new()
	tampered.set_value(Settings.SECTION_AUDIO, "master", "beaucoup")
	tampered.set_value(Settings.SECTION_AUDIO, "music", 5.0)
	tampered.set_value(Settings.SECTION_AUDIO, "sfx", -2.0)
	tampered.save(TMP_SETTINGS)

	var defensive := _make_settings()
	defensive._load()
	_check("valeur illisible → niveau nominal", defensive.master_volume == 1.0,
		str(defensive.master_volume))
	_check("valeur trop grande écrêtée à la relecture", defensive.music_volume == 1.0,
		str(defensive.music_volume))
	_check("valeur négative écrêtée à la relecture", defensive.sfx_volume == 0.0,
		str(defensive.sfx_volume))
	_check("clé absente → niveau nominal", defensive.speaker_volume == 1.0,
		str(defensive.speaker_volume))
	defensive.free()

	_wipe_tmp()

# ---------------------------------------------------------------------------
# BUS ABSENT
# ---------------------------------------------------------------------------
#
# Une disposition audio remplacée ou un bus renommé rend -1. Un réglage de
# confort n'a aucune raison d'empêcher le jeu de démarrer : ce cas doit se
# traverser sans bruit, et les autres bus doivent quand même être servis.
func _test_missing_bus() -> void:
	print("\n[Bus absent de la disposition]")

	_check("un nom inconnu rend bien -1",
		AudioServer.get_bus_index("BusQuiNExistePas") == -1)
	Settings._apply_bus_volume("BusQuiNExistePas", 0.5)
	_check("appliquer un volume sur un bus inconnu ne plante pas", true)

	var speaker_idx := AudioServer.get_bus_index(Settings.BUS_SPEAKER)
	if speaker_idx == -1:
		return
	var speaker_send := AudioServer.get_bus_send(speaker_idx)
	AudioServer.remove_bus(speaker_idx)
	_check("bus Speaker retiré pour l'essai",
		AudioServer.get_bus_index(Settings.BUS_SPEAKER) == -1)

	var s := _make_settings()
	s.set_speaker_volume(0.4)
	_check("régler un volume dont le bus a disparu ne plante pas",
		is_equal_approx(s.speaker_volume, 0.4), str(s.speaker_volume))
	_check("la valeur est quand même retenue pour la prochaine fois",
		FileAccess.file_exists(TMP_SETTINGS))

	s.master_volume = 0.25
	s._apply_audio()
	var master_idx := AudioServer.get_bus_index(Settings.BUS_MASTER)
	_check("les bus encore présents reçoivent leur niveau malgré le manquant",
		absf(AudioServer.get_bus_volume_db(master_idx) - Settings.volume_to_db(0.25))
			< DB_TOLERANCE,
		str(AudioServer.get_bus_volume_db(master_idx)))
	s.free()

	# Remise en état : les tests suivants ne doivent pas hériter d'un mixage
	# amputé.
	AudioServer.add_bus(speaker_idx)
	AudioServer.set_bus_name(speaker_idx, Settings.BUS_SPEAKER)
	AudioServer.set_bus_send(speaker_idx, speaker_send)
	_check("bus Speaker rétabli",
		AudioServer.get_bus_index(Settings.BUS_SPEAKER) == speaker_idx)

	_wipe_tmp()

# ---------------------------------------------------------------------------
# UTILITAIRES
# ---------------------------------------------------------------------------

func _wipe_tmp() -> void:
	if FileAccess.file_exists(TMP_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SETTINGS))

## Empreinte du fichier de préférences réel. Le test doit le laisser exactement
## dans l'état où il l'a trouvé — y compris absent.
func _snapshot_real_settings() -> String:
	if not FileAccess.file_exists(REAL_SETTINGS):
		return "<absent>"
	return FileAccess.get_file_as_string(REAL_SETTINGS)
