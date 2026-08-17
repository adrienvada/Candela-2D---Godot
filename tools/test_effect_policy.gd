## Test headless de la politique des effets visuels (`effect_policy.gd`, section
## `effets` de user://settings.cfg, et l'écran qui les affiche).
##
## Ce que la suite protège, dans l'ordre d'importance :
##
##   • LA propriété à ne jamais laisser régresser — aucun effet de la famille
##     Monde ne peut atteindre zéro en match classé, quelle que soit la route
##     empruntée : curseur, fichier trafiqué, préférence prise en local.
##   • la classification est totale : aucun effet sans famille, sans plancher
##     cohérent avec sa famille, ni sans phrase à montrer au joueur.
##   • les planchers sont bien LEVÉS en écran partagé, où rien n'est en jeu.
##   • l'écrêtage, la persistance, le fichier absent ou trafiqué.
##   • l'écran est engendré par la table : ajouter un effet ne coûte qu'une
##     ligne, et n'oblige à toucher ni l'écran ni cette suite.
##
## Lancer : godot --headless --path . --script res://tools/test_effect_policy.gd
extends SceneTree

## Jamais user://settings.cfg : les suites partagent le `user://` du jeu
## installé, et une suite qui écrit là écraserait les préférences réelles.
const TMP_SETTINGS := "user://test_effect_policy.cfg"
const REAL_SETTINGS := "user://settings.cfg"

var _failures: int = 0

## Chargés dans `_run()`, jamais dans `_init()` : en mode --script, `_init()`
## s'exécute avant les autoloads ET avant le cache des classes globales. Un
## `class_name` référencé trop tôt rend un objet nu, les SCRIPT ERROR
## n'incrémentent aucun compteur, et la suite annonce « tous les tests passent »
## sans avoir rien exécuté.
var _policy: GDScript
var _settings_script: GDScript
var _screen_script: GDScript

func _init() -> void:
	print("=== Test de la politique des effets ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame

	var real_before := _snapshot_real_settings()

	if not _preflight():
		printerr("\n✗ Aucun test exécuté : la politique des effets est absente")
		quit(1)
		return

	_test_classification()
	_test_invariant_monde()
	_test_planchers_leves_en_local()
	_test_clamping()
	_test_persistence()
	_test_contexte()
	_test_ecran()

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
# Rien ne sert de conclure sur une politique qui n'a pas compilé : on vérifie
# que les trois scripts existent, et qu'ils portent bien ce qu'on s'apprête à
# exercer, avant de compter le moindre succès.
func _preflight() -> bool:
	print("\n[Contrôle préalable]")

	_policy = load("res://effect_policy.gd") as GDScript
	_settings_script = load("res://settings_manager.gd") as GDScript
	_screen_script = load("res://screen_effects.gd") as GDScript

	var ok := true
	for pair in [["effect_policy.gd", _policy], ["settings_manager.gd", _settings_script],
			["screen_effects.gd", _screen_script]]:
		if pair[1] == null:
			printerr("  ✗ script introuvable ou non compilé : ", pair[0])
			ok = false
	if not ok:
		return false

	var table: Variant = _policy.EFFECTS
	if not (table is Dictionary) or (table as Dictionary).is_empty():
		printerr("  ✗ EFFECTS n'est pas une table non vide")
		return false
	print("  ✓ la table porte %d effets" % (table as Dictionary).size())

	for method in ["ids", "ids_of_family", "exists", "family_of", "is_world", "label_of",
			"reason_of", "floor_of", "clamp_value", "is_capped", "family_label",
			"family_rule", "context_line", "constraint_line", "intensity_to_percent",
			"percent_to_intensity"]:
		if not _policy.has_method(method):
			printerr("  ✗ EffectPolicy : méthode manquante : ", method)
			ok = false

	var probe: Node = _settings_script.new()
	for method in ["set_effect", "get_effect", "effective_effect", "current_effect",
			"is_ranked_context", "clamp_intensity"]:
		if not probe.has_method(method):
			printerr("  ✗ GameSettings : méthode manquante : ", method)
			ok = false
	if not probe.has_signal("effect_changed"):
		printerr("  ✗ GameSettings : signal manquant : effect_changed")
		ok = false
	probe.free()

	if ok:
		print("  ✓ l'API des effets est bien présente")
	return ok

## Instance détachée de l'arbre : `_ready()` n'est pas appelé, donc ni la vidéo
## ni les liaisons ne sont appliquées au passage.
func _make_settings() -> Node:
	var s: Node = _settings_script.new()
	s._settings_path = TMP_SETTINGS
	return s

# ---------------------------------------------------------------------------
# CLASSIFICATION TOTALE
# ---------------------------------------------------------------------------
#
# Un effet sans famille est un effet dont personne n'a tranché s'il obstrue une
# vue ou s'il porte de l'information. C'est exactement l'arbitrage que cette
# table existe pour rendre explicite : elle ne doit donc jamais avoir de trou.
func _test_classification() -> void:
	print("\n[Classification totale]")

	var ids: PackedStringArray = _policy.ids()
	_check("la table n'est pas vide", ids.size() > 0, str(ids.size()))

	var seen := {}
	var families := {}
	var complete := true
	for id in ids:
		var detail := "effet « %s »" % id

		if id.strip_edges() == "" or seen.has(id):
			_check("identifiant unique et non vide", false, detail)
			complete = false
			break
		seen[id] = true

		# L'identifiant sert de clé dans un ConfigFile : un caractère de
		# structure y produirait un fichier qui ne se relit plus.
		if id.contains("=") or id.contains("[") or id.contains("]") or id.contains(" "):
			_check("identifiant utilisable comme clé de fichier", false, detail)
			complete = false
			break

		var family: int = _policy.family_of(id)
		if family < 0 or _policy.family_label(family) == "":
			_check("famille déclarée", false, detail)
			complete = false
			break
		families[family] = true

		if _policy.family_rule(family) == "":
			_check("la famille a sa règle écrite", false, detail)
			complete = false
			break

		if String(_policy.label_of(id)).strip_edges() == "":
			_check("nom affichable", false, detail)
			complete = false
			break

		# Un curseur qui refuse de descendre sans dire pourquoi passe pour un
		# défaut. La phrase n'est donc pas optionnelle, même en famille Confort,
		# où elle explique l'inverse : pourquoi le zéro est permis.
		if String(_policy.reason_of(id)).strip_edges() == "":
			_check("phrase expliquant la règle au joueur", false, detail)
			complete = false
			break

		var floor_ranked: float = _policy.floor_of(id, true)
		if floor_ranked < 0.0 or floor_ranked > 1.0:
			_check("plancher dans les bornes", false, "%s → %f" % [detail, floor_ranked])
			complete = false
			break

	if complete:
		_check("chaque effet a famille, nom, phrase et plancher borné", true)

	_check("il n'existe que deux familles", families.size() <= 2, str(families.keys()))

	# `ids_of_family` est ce que parcourt l'écran : un effet qui n'en sortirait
	# pas serait réglable par le code et invisible au joueur.
	var covered := 0
	for family in families:
		covered += (_policy.ids_of_family(family) as PackedStringArray).size()
	_check("chaque effet apparaît dans exactement une famille", covered == ids.size(),
		"%d listés pour %d effets" % [covered, ids.size()])

	_check("un identifiant inconnu n'a pas de famille", int(_policy.family_of("effet_fantome")) == -1)
	_check("un identifiant inconnu n'existe pas", not bool(_policy.exists("effet_fantome")))
	_check("le contexte a sa phrase dans les deux cas",
		String(_policy.context_line(true)) != "" and String(_policy.context_line(false)) != "")

# ---------------------------------------------------------------------------
# L'INVARIANT
# ---------------------------------------------------------------------------
#
# LA propriété à ne jamais laisser régresser. Elle est vérifiée pour TOUS les
# effets de la table, par toutes les routes qui mènent à une intensité : le
# curseur, l'écrêtage direct, la relecture d'un fichier, et une préférence prise
# en écran partagé où le zéro est permis.
func _test_invariant_monde() -> void:
	print("\n[Aucun effet Monde à zéro en classé]")

	var settings := _make_settings()
	var world_count := 0
	var comfort_count := 0
	var all_ok := true
	var detail := ""

	for id in _policy.ids():
		var is_world: bool = _policy.is_world(id)
		var floor_ranked: float = _policy.floor_of(id, true)

		if is_world:
			world_count += 1
			# La famille et le plancher se contredisent-ils ? Un effet Monde
			# annulable serait rangé dans la bonne famille et se comporterait
			# comme du confort — le pire des deux mondes.
			if floor_ranked <= 0.0:
				all_ok = false
				detail = "« %s » est Monde mais son plancher vaut %f" % [id, floor_ranked]
				break
		else:
			comfort_count += 1
			if floor_ranked != 0.0:
				all_ok = false
				detail = "« %s » est Confort mais bridé à %f" % [id, floor_ranked]
				break

		if not is_world:
			continue

		# Route 1 : l'écrêtage direct, celui que le rendu appelle.
		for attempt in [0.0, -1.0, -1000.0, 0.0001]:
			var applied: float = _policy.clamp_value(id, attempt, true)
			if applied < floor_ranked or applied <= 0.0:
				all_ok = false
				detail = "« %s » : %f écrêté à %f" % [id, attempt, applied]
				break
		if not all_ok:
			break

		# Route 2 : le joueur pousse son curseur à zéro (permis en local), puis
		# entre en classé. Sa préférence est retenue, jamais appliquée telle
		# quelle.
		settings.set_effect(id, 0.0)
		if not is_zero_approx(float(settings.get_effect(id))):
			all_ok = false
			detail = "« %s » : la préférence brute a été relevée à l'écriture" % id
			break
		var in_ranked: float = settings.effective_effect(id, true)
		if in_ranked < floor_ranked or in_ranked <= 0.0:
			all_ok = false
			detail = "« %s » : %f appliqué en classé" % [id, in_ranked]
			break
		if not is_zero_approx(float(settings.effective_effect(id, false))):
			all_ok = false
			detail = "« %s » : le zéro n'est pas rendu en écran partagé" % id
			break

	_check("aucun effet Monde n'atteint zéro en classé, par aucune route", all_ok, detail)
	_check("la table contient des effets des deux familles",
		world_count > 0 and comfort_count > 0,
		"%d Monde, %d Confort" % [world_count, comfort_count])

	# Route 3 : le fichier trafiqué à la main, qui court-circuite tous les
	# setters.
	settings.free()
	_wipe_tmp()

	var tampered := ConfigFile.new()
	var world_ids: PackedStringArray = PackedStringArray()
	for id in _policy.ids():
		if _policy.is_world(id):
			world_ids.append(String(id))
			tampered.set_value("effets", String(id), 0.0)
	tampered.save(TMP_SETTINGS)

	var reader := _make_settings()
	reader._load()
	var tamper_ok := true
	var tamper_detail := ""
	for id in world_ids:
		if float(reader.effective_effect(id, true)) <= 0.0:
			tamper_ok = false
			tamper_detail = "« %s » relu à zéro en classé" % id
			break
	_check("un fichier mis à zéro à la main ne passe pas en classé", tamper_ok, tamper_detail)
	reader.free()
	_wipe_tmp()

# ---------------------------------------------------------------------------
# LES PLANCHERS SONT LEVÉS EN LOCAL
# ---------------------------------------------------------------------------
#
# L'autre moitié de la règle, aussi facile à casser que la première : un
# plancher qui déborderait sur l'écran partagé imposerait une contrainte de
# compétition à une partie où rien n'est en jeu.
func _test_planchers_leves_en_local() -> void:
	print("\n[Écran partagé : aucun plancher]")

	var all_zero := true
	var detail := ""
	for id in _policy.ids():
		if not is_zero_approx(float(_policy.floor_of(id, false))):
			all_zero = false
			detail = "« %s » garde un plancher hors classé" % id
			break
		if not is_zero_approx(float(_policy.clamp_value(id, 0.0, false))):
			all_zero = false
			detail = "« %s » : zéro refusé en écran partagé" % id
			break
		if bool(_policy.is_capped(id, false)):
			all_zero = false
			detail = "« %s » annoncé bridé hors classé" % id
			break
	_check("tout descend à zéro en écran partagé", all_zero, detail)

	# La phrase suit le contexte : en local elle ne doit pas annoncer un
	# minimum qui ne s'appliquera pas.
	var world_sample := ""
	for id in _policy.ids():
		if _policy.is_world(id):
			world_sample = String(id)
			break
	if world_sample != "":
		var local_line := String(_policy.constraint_line(world_sample, false))
		var ranked_line := String(_policy.constraint_line(world_sample, true))
		_check("la ligne affichée diffère selon le contexte", local_line != ranked_line)
		_check("en local, aucun minimum n'est annoncé",
			not local_line.contains("Minimum en classé"), local_line)
		_check("en classé, le minimum est chiffré",
			ranked_line.contains("Minimum en classé"), ranked_line)
		_check("la raison est toujours jointe à la contrainte",
			ranked_line.contains(String(_policy.reason_of(world_sample))))

# ---------------------------------------------------------------------------
# ÉCRÊTAGE
# ---------------------------------------------------------------------------

func _test_clamping() -> void:
	print("\n[Valeurs hors bornes]")

	var sample := String(_policy.ids()[0])
	_check("au-delà de 1, écrêté à 1", _policy.clamp_value(sample, 4.0, true) == 1.0,
		str(_policy.clamp_value(sample, 4.0, true)))
	_check("au-delà de 1, écrêté aussi en local",
		_policy.clamp_value(sample, 4.0, false) == 1.0)
	# NAN se propage silencieusement dans un flottant et rendrait un effet
	# invisible sans la moindre erreur : il retombe sur l'intensité d'origine.
	_check("NAN retombe sur l'intensité d'origine",
		_policy.clamp_value(sample, NAN, true) == _policy.DEFAULT,
		str(_policy.clamp_value(sample, NAN, true)))

	_check("mi-course affiche 50 %", int(_policy.intensity_to_percent(0.5)) == 50)
	_check("un pourcentage débordant est écrêté", int(_policy.intensity_to_percent(3.0)) == 100)
	_check("un pourcentage négatif est écrêté", int(_policy.intensity_to_percent(-1.0)) == 0)
	_check("35 % rend 0,35", is_equal_approx(float(_policy.percent_to_intensity(35)), 0.35))
	_check("aller-retour pourcentage",
		int(_policy.intensity_to_percent(_policy.percent_to_intensity(65))) == 65)

	var s := _make_settings()
	s.set_effect(sample, 9.0)
	_check("un curseur qui déborde est écrêté par le setter",
		float(s.get_effect(sample)) == 1.0, str(s.get_effect(sample)))
	s.set_effect(sample, -4.0)
	_check("une valeur négative est écrêtée par le setter",
		float(s.get_effect(sample)) == 0.0, str(s.get_effect(sample)))

	# Un effet retiré de la table ne doit pas pouvoir se glisser dans le fichier
	# de préférences : il y resterait sans politique, donc sans plancher.
	var emitted: Array = []
	s.effect_changed.connect(func(id: String, value: float) -> void: emitted.append(id))
	s.set_effect("effet_fantome", 0.5)
	_check("un identifiant inconnu est ignoré", not s._effects.has("effet_fantome"))
	_check("un identifiant inconnu n'émet rien", not emitted.has("effet_fantome"),
		str(emitted))
	_check("un identifiant inconnu rend l'intensité d'origine",
		float(s.get_effect("effet_fantome")) == _policy.DEFAULT)
	s.set_effect(sample, 0.6)
	_check("un réglage valide émet le signal", emitted.has(sample), str(emitted))

	_check("un effet jamais réglé rend l'intensité d'origine",
		float(_make_settings_and_read(_policy.ids()[1])) == _policy.DEFAULT)

	s.free()
	_wipe_tmp()

func _make_settings_and_read(id: String) -> float:
	var s := _make_settings()
	var value: float = s.get_effect(id)
	s.free()
	return value

# ---------------------------------------------------------------------------
# PERSISTANCE
# ---------------------------------------------------------------------------

func _test_persistence() -> void:
	print("\n[Persistance]")
	_wipe_tmp()

	var comfort := ""
	var world := ""
	for id in _policy.ids():
		if _policy.is_world(id) and world == "":
			world = String(id)
		elif not _policy.is_world(id) and comfort == "":
			comfort = String(id)
	_check("un effet de chaque famille pour l'essai", comfort != "" and world != "")

	var writer := _make_settings()
	writer.set_effect(comfort, 0.0)
	writer.set_effect(world, 0.45)
	# Un réglage d'une autre section au passage : la nouvelle section ne doit
	# pas déloger les anciennes.
	writer.set_master_volume(0.42)
	writer.set_fps_cap(120)
	writer.free()

	_check("le fichier de préférences est écrit", FileAccess.file_exists(TMP_SETTINGS))

	var cfg := ConfigFile.new()
	_check("le fichier se relit", cfg.load(TMP_SETTINGS) == OK)
	_check("section « effets » présente", cfg.has_section("effets"))
	_check("clé de l'effet de confort enregistrée", cfg.has_section_key("effets", comfort))
	_check("clé de l'effet de monde enregistrée", cfg.has_section_key("effets", world))

	var reader := _make_settings()
	reader._load()
	_check("le zéro de confort est relu tel quel",
		float(reader.get_effect(comfort)) == 0.0, str(reader.get_effect(comfort)))
	_check("l'effet de monde est relu tel quel",
		is_equal_approx(float(reader.get_effect(world)), 0.45), str(reader.get_effect(world)))
	_check("les volumes survivent à l'ajout de la section effets",
		is_equal_approx(float(reader.master_volume), 0.42), str(reader.master_volume))
	_check("les réglages vidéo survivent aussi", int(reader.fps_cap) == 120,
		str(reader.fps_cap))
	reader.free()

	# Installation neuve : aucun fichier, chaque effet à son intensité d'origine
	# et aucune section écrite pour rien.
	_wipe_tmp()
	var fresh := _make_settings()
	fresh._load()
	var all_default := true
	for id in _policy.ids():
		if float(fresh.get_effect(id)) != _policy.DEFAULT:
			all_default = false
			break
	_check("sans fichier, tout est à l'intensité d'origine", all_default)
	fresh._save()
	var neuf := ConfigFile.new()
	neuf.load(TMP_SETTINGS)
	_check("aucune section « effets » tant que rien n'est réglé",
		not neuf.has_section("effets"))
	fresh.free()
	_wipe_tmp()

	# Fichier trafiqué à la main ou écrit par une version antérieure.
	var tampered := ConfigFile.new()
	tampered.set_value("effets", comfort, "beaucoup")
	tampered.set_value("effets", world, 7.0)
	tampered.set_value("effets", "effet_disparu", 0.5)
	tampered.save(TMP_SETTINGS)

	var defensive := _make_settings()
	defensive._load()
	_check("valeur illisible → intensité d'origine",
		float(defensive.get_effect(comfort)) == _policy.DEFAULT,
		str(defensive.get_effect(comfort)))
	_check("valeur trop grande écrêtée à la relecture",
		float(defensive.get_effect(world)) == 1.0, str(defensive.get_effect(world)))
	_check("un effet disparu de la table n'est pas conservé",
		not defensive._effects.has("effet_disparu"))
	defensive._save()
	var cleaned := ConfigFile.new()
	cleaned.load(TMP_SETTINGS)
	_check("et il ne revient pas dans le fichier",
		not cleaned.has_section_key("effets", "effet_disparu"))
	defensive.free()
	_wipe_tmp()

# ---------------------------------------------------------------------------
# LE CONTEXTE
# ---------------------------------------------------------------------------
#
# Le contexte est dérivé en un seul endroit. Hors arbre de scène — outils,
# tests, éditeur — il n'y a pas de match, donc pas de classé : la réponse doit
# être stable et ne rien exiger du réseau.
func _test_contexte() -> void:
	print("\n[Contexte classé / écran partagé]")

	var s := _make_settings()
	_check("hors arbre de scène, le contexte n'est pas classé",
		not bool(s.is_ranked_context()))

	var world := ""
	for id in _policy.ids():
		if _policy.is_world(id):
			world = String(id)
			break

	s.set_effect(world, 0.0)
	_check("sans NetworkManager, `current_effect` suit le contexte non classé",
		is_zero_approx(float(s.current_effect(world))), str(s.current_effect(world)))
	_check("et `effective_effect(classé)` applique quand même le plancher",
		float(s.effective_effect(world, true)) == float(_policy.floor_of(world, true)),
		str(s.effective_effect(world, true)))

	# Le brut survit aux allers-retours : jouer un match classé entre deux
	# soirées en local ne doit pas effacer un réglage.
	var _unused: float = s.effective_effect(world, true)
	_check("la préférence brute survit à une lecture en classé",
		is_zero_approx(float(s.get_effect(world))), str(s.get_effect(world)))
	s.free()
	_wipe_tmp()

# ---------------------------------------------------------------------------
# L'ÉCRAN
# ---------------------------------------------------------------------------
#
# L'écran est engendré par la table : c'est ce qui garantit qu'ajouter un effet
# coûte une ligne et rien d'autre. On vérifie donc la correspondance ligne à
# ligne, pas l'apparence.
func _test_ecran() -> void:
	print("\n[L'écran]")

	var settings := _make_settings()
	var screen: Control = _screen_script.new()
	screen.settings_override = settings

	# Le contrat de HubScreen : `refresh()` survit à un écran jamais construit.
	screen.refresh()
	_check("rafraîchir avant construction ne plante pas", true)
	_check("l'écran a un titre", String(screen.screen_title()).strip_edges() != "")

	var body := VBoxContainer.new()
	screen.add_child(body)
	screen.build(body)

	var ids: PackedStringArray = _policy.ids()
	_check("un curseur par effet de la table", int(screen._rows.size()) == ids.size(),
		"%d curseurs pour %d effets" % [screen._rows.size(), ids.size()])

	var missing := ""
	for id in ids:
		if not screen._rows.has(id):
			missing = String(id)
			break
	_check("aucun effet sans curseur", missing == "", missing)
	_check("le curseur est atteignable au premier appui", screen.focus_seed() != null)

	# Contexte strict par défaut : un écran qui n'a pas été renseigné ne promet
	# pas un zéro que le match refusera.
	_check("le contexte par défaut est le plus strict", bool(screen.is_ranked_context()))

	screen.set_ranked_context(true)
	var ranked_ok := true
	var ranked_detail := ""
	for id in ids:
		var slider: HSlider = screen._rows[id]["slider"]
		var expected: float = float(_policy.intensity_to_percent(_policy.floor_of(id, true)))
		if not is_equal_approx(slider.min_value, expected):
			ranked_ok = false
			ranked_detail = "« %s » : course ouverte à %f, plancher à %f" % [
				id, slider.min_value, expected]
			break
		if _policy.is_world(id) and slider.min_value <= 0.0:
			ranked_ok = false
			ranked_detail = "« %s » : curseur Monde descendant à zéro" % id
			break
		if String(screen._rows[id]["notice"].text).strip_edges() == "":
			ranked_ok = false
			ranked_detail = "« %s » : contrainte affichée sans explication" % id
			break
	_check("en classé, chaque course s'arrête à son plancher, raison affichée",
		ranked_ok, ranked_detail)

	screen.set_ranked_context(false)
	var local_ok := true
	for id in ids:
		var slider: HSlider = screen._rows[id]["slider"]
		if slider.min_value != 0.0:
			local_ok = false
			ranked_detail = "« %s » : course bridée en écran partagé" % id
			break
	_check("en écran partagé, tous les curseurs descendent à zéro", local_ok, ranked_detail)

	# Le piège du réglage détruit par l'affichage : une préférence à zéro prise
	# en local, montrée en classé, ne doit pas être réécrite au plancher par le
	# simple fait de repositionner le curseur.
	var world := ""
	for id in ids:
		if _policy.is_world(id):
			world = String(id)
			break
	settings.set_effect(world, 0.0)
	screen.set_ranked_context(true)
	_check("afficher en classé ne réécrit pas la préférence brute",
		is_zero_approx(float(settings.get_effect(world))), str(settings.get_effect(world)))
	_check("mais le curseur montre bien la valeur appliquée",
		is_equal_approx(float(screen._rows[world]["slider"].value),
			float(_policy.intensity_to_percent(_policy.floor_of(world, true)))),
		str(screen._rows[world]["slider"].value))

	# Le joueur bouge le curseur : là, et seulement là, la préférence change.
	screen._on_slider_changed(80.0, world)
	_check("bouger le curseur écrit la préférence",
		is_equal_approx(float(settings.get_effect(world)), 0.8),
		str(settings.get_effect(world)))

	# Idempotence : deux rafraîchissements d'affilée donnent le même écran.
	var before: float = screen._rows[world]["slider"].value
	screen.refresh()
	screen.refresh()
	_check("deux rafraîchissements donnent le même affichage",
		is_equal_approx(float(screen._rows[world]["slider"].value), before))

	screen.free()
	settings.free()
	_wipe_tmp()

# ---------------------------------------------------------------------------
# UTILITAIRES
# ---------------------------------------------------------------------------

func _wipe_tmp() -> void:
	if FileAccess.file_exists(TMP_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SETTINGS))

## Empreinte du fichier de préférences réel. La suite doit le laisser exactement
## dans l'état où elle l'a trouvé — y compris absent.
func _snapshot_real_settings() -> String:
	if not FileAccess.file_exists(REAL_SETTINGS):
		return "<absent>"
	return FileAccess.get_file_as_string(REAL_SETTINGS)
