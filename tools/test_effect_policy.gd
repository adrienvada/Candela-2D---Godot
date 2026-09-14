## Test headless de la politique des effets visuels (`effect_policy.gd`, section
## `effets` de user://settings.cfg, et l'écran qui les affiche).
##
## Ce que la suite protège, dans l'ordre d'importance :
##
##   • LA propriété à ne jamais laisser régresser — **aucun effet de la famille
##     Monde ne peut être réglé, par aucune route** : écran, setter, fichier
##     trafiqué, préférence héritée d'une version antérieure. Ils valent
##     `DEFAULT` pour tout le monde (décision d'Adrien, 2026-09-12).
##   • l'API des planchers est bien PARTIE, et ne revient pas par la fenêtre.
##     Un `ranked` qui réapparaîtrait rendrait au Monde sa négociabilité sans
##     qu'aucun autre contrôle ne s'en aperçoive.
##   • la classification est totale : aucun effet sans famille ni sans phrase.
##   • les quatre niveaux du confort, et l'état « personnalisé » qui les
##     accompagne.
##   • l'écrêtage, la persistance, le fichier absent ou trafiqué.
##   • l'écran est engendré par la table : ajouter un effet réglable ne coûte
##     qu'une ligne, et n'oblige à toucher ni l'écran ni cette suite.
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
	_test_niveaux()
	_test_clamping()
	_test_persistence()
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

	for method in ["ids", "ids_of_family", "ids_reglables", "exists", "family_of",
			"is_world", "reglable", "label_of", "reason_of", "clamp_value",
			"family_label", "family_rule", "context_line", "constraint_line",
			"niveau_de", "niveau_commun", "intensity_to_percent",
			"percent_to_intensity"]:
		if not _policy.has_method(method):
			printerr("  ✗ EffectPolicy : méthode manquante : ", method)
			ok = false

	var probe: Node = _settings_script.new()
	for method in ["set_effect", "get_effect", "current_effect", "clamp_intensity"]:
		if not probe.has_method(method):
			printerr("  ✗ GameSettings : méthode manquante : ", method)
			ok = false
	if not probe.has_signal("effect_changed"):
		printerr("  ✗ GameSettings : signal manquant : effect_changed")
		ok = false

	# ⚠️ **L'absence est contrôlée comme la présence.** Les planchers et le
	# contexte classé sont partis le 2026-09-12 avec le réglage du Monde ; les
	# voir revenir signifierait qu'on a rendu au joueur la main sur ce qui doit
	# être commun, et aucun autre contrôle de cette suite ne le dirait.
	for disparu in ["floor_of", "is_capped"]:
		if _policy.has_method(disparu):
			printerr("  ✗ EffectPolicy : « %s » est revenu — les planchers avec ?" % disparu)
			ok = false
	for disparu in ["effective_effect", "is_ranked_context"]:
		if probe.has_method(disparu):
			printerr("  ✗ GameSettings : « %s » est revenu" % disparu)
			ok = false
	probe.free()

	if ok:
		print("  ✓ l'API des effets est bien présente, et l'ancienne bien partie")
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

		if String(_policy.constraint_line(id)).strip_edges() == "":
			_check("ligne de contrainte affichable", false, detail)
			complete = false
			break

	if complete:
		_check("chaque effet a famille, nom, phrase et ligne de contrainte", true)

	_check("il existe exactement trois familles", families.size() == 3, str(families.keys()))

	# `ids_of_family` est ce que parcourt l'écran : un effet qui n'en sortirait
	# pas serait réglable par le code et invisible au joueur.
	var covered := 0
	for family in families:
		covered += (_policy.ids_of_family(family) as PackedStringArray).size()
	_check("chaque effet apparaît dans exactement une famille", covered == ids.size(),
		"%d listés pour %d effets" % [covered, ids.size()])

	# Les réglables sont exactement Menus + Confort, ni plus ni moins.
	var menus: int = (_policy.ids_of_family(_policy.Family.MENUS) as PackedStringArray).size()
	var confort: int = (_policy.ids_of_family(_policy.Family.CONFORT) as PackedStringArray).size()
	var monde: int = (_policy.ids_of_family(_policy.Family.MONDE) as PackedStringArray).size()
	_check("les trois familles sont peuplées", menus > 0 and confort > 0 and monde > 0,
		"%d menus, %d confort, %d monde" % [menus, confort, monde])
	_check("« réglable » recouvre exactement Menus + Confort",
		int((_policy.ids_reglables() as PackedStringArray).size()) == menus + confort,
		"%d réglables pour %d + %d" % [
			(_policy.ids_reglables() as PackedStringArray).size(), menus, confort])

	_check("un identifiant inconnu n'a pas de famille", int(_policy.family_of("effet_fantome")) == -1)
	_check("un identifiant inconnu n'existe pas", not bool(_policy.exists("effet_fantome")))
	_check("un identifiant inconnu n'est pas réglable", not bool(_policy.reglable("effet_fantome")))
	_check("le bandeau de contexte a sa phrase",
		String(_policy.context_line()).strip_edges() != "")

# ---------------------------------------------------------------------------
# L'INVARIANT
# ---------------------------------------------------------------------------
#
# LA propriété à ne jamais laisser régresser. Elle est vérifiée pour TOUS les
# effets du Monde, par toutes les routes qui mènent à une intensité : l'écrêtage
# direct, le setter, la relecture d'un fichier trafiqué, et l'écran.
#
# Elle a remplacé « aucun effet Monde n'atteint zéro en classé » : la marge qui
# restait entre le plancher et 100 % était assez large pour faire deux jeux
# différents, et un réglage qui influe sur le compétitif n'a pas de bon plancher
# — il a une valeur commune.
func _test_invariant_monde() -> void:
	print("\n[Aucun effet Monde n'est réglable]")

	var defaut: float = _policy.DEFAULT
	var familles_ok := true
	var detail := ""
	for id in _policy.ids():
		var monde: bool = _policy.is_world(id)
		if monde == bool(_policy.reglable(id)):
			familles_ok = false
			detail = "« %s » : Monde et réglable à la fois" % id
			break
	_check("Monde et réglable s'excluent, pour chaque effet", familles_ok, detail)

	# Route 1 : l'écrêtage direct, celui que le rendu appelle.
	var clamp_ok := true
	detail = ""
	for id in _policy.ids():
		if not _policy.is_world(id):
			continue
		for tentative in [0.0, -1.0, -1000.0, 0.0001, 0.5, 0.999, 42.0, NAN]:
			var applique: float = _policy.clamp_value(id, tentative)
			if not is_equal_approx(applique, defaut):
				clamp_ok = false
				detail = "« %s » : %s écrêté à %f au lieu de %f" % [
					id, str(tentative), applique, defaut]
				break
		if not clamp_ok:
			break
	_check("l'écrêtage rend l'intensité d'origine quoi qu'on lui passe", clamp_ok, detail)

	# Route 2 : le setter. Il refuse, sans rien retenir et sans rien émettre —
	# une valeur retenue mais jamais rendue est exactement le réglage qui ment.
	var settings := _make_settings()
	var emis: Array = []
	settings.effect_changed.connect(func(id: String, _v: float) -> void: emis.append(id))
	var setter_ok := true
	detail = ""
	for id in _policy.ids():
		if not _policy.is_world(id):
			continue
		settings.set_effect(String(id), 0.0)
		if settings._effects.has(id):
			setter_ok = false
			detail = "« %s » : retenu dans les préférences" % id
			break
		if not is_equal_approx(float(settings.get_effect(String(id))), defaut):
			setter_ok = false
			detail = "« %s » : get_effect rend %f" % [id, settings.get_effect(String(id))]
			break
		if not is_equal_approx(float(settings.current_effect(String(id))), defaut):
			setter_ok = false
			detail = "« %s » : current_effect rend %f" % [id, settings.current_effect(String(id))]
			break
	_check("le setter refuse un effet du Monde, sans rien retenir", setter_ok, detail)
	_check("et sans émettre le moindre signal", emis.is_empty(), str(emis))
	settings.free()
	_wipe_tmp()

	# Route 3 : le fichier. ⚠️ **Le cas réel, pas une hypothèse** — tout
	# `settings.cfg` écrit avant le 2026-09-12 porte les douze effets du Monde,
	# et celui d'Adrien les avait TOUS à leur ancien plancher. Les relire
	# laisserait son jeu à 25 % de sang et 20 % de poussière pour toujours, sans
	# qu'aucun écran ne puisse plus les remonter.
	var ancien := ConfigFile.new()
	var ids_monde := PackedStringArray()
	for id in _policy.ids():
		if _policy.is_world(id):
			ids_monde.append(String(id))
			ancien.set_value("effets", String(id), 0.25)
	ancien.save(TMP_SETTINGS)

	var lecteur := _make_settings()
	lecteur._load()
	var relu_ok := true
	detail = ""
	for id in ids_monde:
		if lecteur._effects.has(id):
			relu_ok = false
			detail = "« %s » relu depuis un fichier d'avant" % id
			break
		if not is_equal_approx(float(lecteur.current_effect(id)), defaut):
			relu_ok = false
			detail = "« %s » appliqué à %f" % [id, lecteur.current_effect(id)]
			break
	_check("une préférence héritée d'avant la décision est écartée", relu_ok, detail)

	lecteur._save()
	var nettoye := ConfigFile.new()
	nettoye.load(TMP_SETTINGS)
	var efface := true
	for id in ids_monde:
		if nettoye.has_section_key("effets", id):
			efface = false
			detail = "« %s » réécrit dans le fichier" % id
			break
	_check("et elle disparaît du fichier à la première sauvegarde", efface, detail)
	lecteur.free()
	_wipe_tmp()

# ---------------------------------------------------------------------------
# LES QUATRE NIVEAUX
# ---------------------------------------------------------------------------

func _test_niveaux() -> void:
	print("\n[Les quatre niveaux du confort]")

	var niveaux: Array = _policy.NIVEAUX
	var noms: Array = _policy.NOMS_NIVEAUX
	_check("quatre niveaux", niveaux.size() == 4, str(niveaux.size()))
	_check("autant de noms que de niveaux", noms.size() == niveaux.size(),
		"%d noms pour %d niveaux" % [noms.size(), niveaux.size()])

	var croissant := true
	for i in range(1, niveaux.size()):
		if float(niveaux[i]) <= float(niveaux[i - 1]):
			croissant = false
			break
	_check("les niveaux sont croissants", croissant, str(niveaux))
	_check("le premier est nul", is_zero_approx(float(niveaux[0])), str(niveaux[0]))
	# Le dernier niveau EST l'intensité d'origine : un joueur qui n'a jamais
	# touché à rien doit voir « ÉLEVÉ » allumé, et non un écran personnalisé.
	_check("le dernier est l'intensité d'origine",
		is_equal_approx(float(niveaux[-1]), float(_policy.DEFAULT)),
		"%f pour un défaut de %f" % [niveaux[-1], _policy.DEFAULT])

	var nommes := true
	for n in noms:
		if String(n).strip_edges() == "":
			nommes = false
			break
	_check("chaque niveau porte un nom lisible", nommes, str(noms))

	var aller_retour := true
	for i in niveaux.size():
		if int(_policy.niveau_de(float(niveaux[i]))) != i:
			aller_retour = false
			break
	_check("chaque niveau se reconnaît lui-même", aller_retour)

	# Entre deux niveaux : « personnalisé », et surtout pas un arrondi — arrondir
	# effacerait le choix à la simple ouverture de l'écran.
	_check("une valeur entre deux niveaux n'en est aucun",
		int(_policy.niveau_de(0.42)) == -1, str(_policy.niveau_de(0.42)))
	_check("NAN n'est aucun niveau", int(_policy.niveau_de(NAN)) == -1)

	_check("un ensemble homogène rend son niveau",
		int(_policy.niveau_commun([niveaux[1], niveaux[1], niveaux[1]])) == 1)
	_check("un ensemble qui diverge rend « personnalisé »",
		int(_policy.niveau_commun([niveaux[1], niveaux[2]])) == -1)
	_check("un ensemble hors niveaux rend « personnalisé »",
		int(_policy.niveau_commun([0.42, 0.42])) == -1)
	_check("un ensemble vide rend « personnalisé »",
		int(_policy.niveau_commun([])) == -1)

# ---------------------------------------------------------------------------
# ÉCRÊTAGE
# ---------------------------------------------------------------------------

func _test_clamping() -> void:
	print("\n[Valeurs hors bornes]")

	var sample := _premier_reglable()
	_check("un effet réglable pour l'essai", sample != "")
	_check("au-delà de 1, écrêté à 1", _policy.clamp_value(sample, 4.0) == 1.0,
		str(_policy.clamp_value(sample, 4.0)))
	_check("en dessous de 0, écrêté à 0", _policy.clamp_value(sample, -2.0) == 0.0,
		str(_policy.clamp_value(sample, -2.0)))
	# NAN se propage silencieusement dans un flottant et rendrait un effet
	# invisible sans la moindre erreur : il retombe sur l'intensité d'origine.
	_check("NAN retombe sur l'intensité d'origine",
		_policy.clamp_value(sample, NAN) == _policy.DEFAULT,
		str(_policy.clamp_value(sample, NAN)))

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
	# de préférences : il y resterait sans politique, donc sans personne pour
	# décider s'il s'applique.
	var emitted: Array = []
	s.effect_changed.connect(func(id: String, _value: float) -> void: emitted.append(id))
	s.set_effect("effet_fantome", 0.5)
	_check("un identifiant inconnu est ignoré", not s._effects.has("effet_fantome"))
	_check("un identifiant inconnu n'émet rien", not emitted.has("effet_fantome"),
		str(emitted))
	_check("un identifiant inconnu rend l'intensité d'origine",
		float(s.get_effect("effet_fantome")) == _policy.DEFAULT)
	s.set_effect(sample, 0.6)
	_check("un réglage valide émet le signal", emitted.has(sample), str(emitted))

	s.free()
	_wipe_tmp()

	_check("un effet jamais réglé rend l'intensité d'origine",
		float(_make_settings_and_read(sample)) == _policy.DEFAULT)

func _make_settings_and_read(id: String) -> float:
	var s := _make_settings()
	var value: float = s.get_effect(id)
	s.free()
	return value

func _premier_reglable() -> String:
	for id in _policy.ids_reglables():
		return String(id)
	return ""

func _premier_de_famille(famille: int) -> String:
	for id in _policy.ids_of_family(famille):
		return String(id)
	return ""

# ---------------------------------------------------------------------------
# PERSISTANCE
# ---------------------------------------------------------------------------

func _test_persistence() -> void:
	print("\n[Persistance]")
	_wipe_tmp()

	var menu := _premier_de_famille(_policy.Family.MENUS)
	var confort := _premier_de_famille(_policy.Family.CONFORT)
	var monde := _premier_de_famille(_policy.Family.MONDE)
	_check("un effet de chaque famille pour l'essai",
		menu != "" and confort != "" and monde != "")

	var writer := _make_settings()
	writer.set_effect(menu, 0.0)
	writer.set_effect(confort, 0.35)
	writer.set_effect(monde, 0.45)
	# Un réglage d'une autre section au passage : la section des effets ne doit
	# pas déloger les anciennes.
	writer.set_master_volume(0.42)
	writer.set_fps_cap(120)
	writer.free()

	_check("le fichier de préférences est écrit", FileAccess.file_exists(TMP_SETTINGS))

	var cfg := ConfigFile.new()
	_check("le fichier se relit", cfg.load(TMP_SETTINGS) == OK)
	_check("section « effets » présente", cfg.has_section("effets"))
	_check("clé de l'effet de menu enregistrée", cfg.has_section_key("effets", menu))
	_check("clé de l'effet de confort enregistrée", cfg.has_section_key("effets", confort))
	_check("mais aucune clé pour l'effet du monde",
		not cfg.has_section_key("effets", monde))

	var reader := _make_settings()
	reader._load()
	_check("le zéro du menu est relu tel quel",
		float(reader.get_effect(menu)) == 0.0, str(reader.get_effect(menu)))
	_check("le niveau de confort est relu tel quel",
		is_equal_approx(float(reader.get_effect(confort)), 0.35),
		str(reader.get_effect(confort)))
	_check("les volumes survivent à la section effets",
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
	tampered.set_value("effets", confort, "beaucoup")
	tampered.set_value("effets", menu, 7.0)
	tampered.set_value("effets", "effet_disparu", 0.5)
	tampered.save(TMP_SETTINGS)

	var defensive := _make_settings()
	defensive._load()
	_check("valeur illisible → intensité d'origine",
		float(defensive.get_effect(confort)) == _policy.DEFAULT,
		str(defensive.get_effect(confort)))
	_check("valeur trop grande écrêtée à la relecture",
		float(defensive.get_effect(menu)) == 1.0, str(defensive.get_effect(menu)))
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
# L'ÉCRAN
# ---------------------------------------------------------------------------
#
# Deux contrôles simples, un repli, et les curseurs fins derrière. Ce qu'on
# vérifie n'est pas l'apparence mais la correspondance : l'écran montre les
# effets réglables et eux seuls, et ses deux résumés disent la vérité sur ce que
# les préférences contiennent réellement.
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

	var reglables: PackedStringArray = _policy.ids_reglables()
	_check("un curseur par effet réglable, et rien de plus",
		int(screen._rows.size()) == reglables.size(),
		"%d curseurs pour %d effets réglables" % [screen._rows.size(), reglables.size()])

	var manquant := ""
	for id in reglables:
		if not screen._rows.has(id):
			manquant = String(id)
			break
	_check("aucun effet réglable sans curseur", manquant == "", manquant)

	# La propriété de l'écran : le Monde n'y a PAS de ligne. Pas grisée, pas
	# bridée : absente. Un curseur verrouillé ferait passer une règle de jeu
	# pour une option refusée.
	var intrus := ""
	for id in _policy.ids():
		if _policy.is_world(id) and screen._rows.has(id):
			intrus = String(id)
			break
	_check("aucun effet du Monde n'a de ligne dans l'écran", intrus == "", intrus)

	_check("le curseur est atteignable au premier appui", screen.focus_seed() != null)
	_check("les paramètres avancés sont repliés à l'ouverture",
		not screen._avance.visible)
	screen._basculer_avance()
	_check("le bouton les déplie", screen._avance.visible)
	screen._basculer_avance()
	_check("et les replie", not screen._avance.visible)

	# --- L'interrupteur des menus ------------------------------------------
	var ids_menus: PackedStringArray = _policy.ids_of_family(_policy.Family.MENUS)
	_check("à l'ouverture, les menus sont allumés",
		int(screen._etat_menus_courant()) == 1, str(screen._etat_menus_courant()))
	screen._basculer_menus()
	var tous_eteints := true
	for id in ids_menus:
		if not is_zero_approx(float(settings.get_effect(String(id)))):
			tous_eteints = false
			break
	_check("un appui éteint les quinze", tous_eteints)
	_check("et l'écran le dit", int(screen._etat_menus_courant()) == 0)
	screen._basculer_menus()
	var tous_allumes := true
	for id in ids_menus:
		if not is_equal_approx(float(settings.get_effect(String(id))), float(_policy.DEFAULT)):
			tous_allumes = false
			break
	_check("un second appui les rallume tous", tous_allumes)

	# Depuis l'état personnalisé, l'interrupteur éteint — c'est le sens de
	# lecture annoncé par la ligne d'état.
	settings.set_effect(String(ids_menus[0]), 0.0)
	screen.refresh()
	_check("un seul effet baissé rend l'état « personnalisé »",
		int(screen._etat_menus_courant()) == -1)
	screen._basculer_menus()
	_check("et depuis là, l'interrupteur éteint tout",
		int(screen._etat_menus_courant()) == 0)

	# --- Les quatre niveaux du confort --------------------------------------
	var ids_confort: PackedStringArray = _policy.ids_of_family(_policy.Family.CONFORT)
	var niveaux_ok := true
	var detail := ""
	for i in (_policy.NIVEAUX as Array).size():
		screen._poser_niveau(i)
		for id in ids_confort:
			var attendu: float = float(_policy.NIVEAUX[i])
			if not is_equal_approx(float(settings.get_effect(String(id))), attendu):
				niveaux_ok = false
				detail = "niveau %d : « %s » vaut %f au lieu de %f" % [
					i, id, settings.get_effect(String(id)), attendu]
				break
		if not niveaux_ok:
			break
		if int(screen._niveau_confort_courant()) != i:
			niveaux_ok = false
			detail = "niveau %d posé, l'écran lit %d" % [i, screen._niveau_confort_courant()]
			break
		if not screen._boutons_niveau[i].button_pressed:
			niveaux_ok = false
			detail = "niveau %d posé, bouton non enfoncé" % i
			break
	_check("chaque niveau aligne les sept effets de confort", niveaux_ok, detail)

	# Un réglage fin qui ne tombe sur aucun niveau : « personnalisé », et aucun
	# bouton enfoncé. C'est ce qui garantit qu'ouvrir l'écran n'arrondit rien.
	screen._on_slider_changed(45.0, String(ids_confort[0]))
	_check("un curseur fin écrit la préférence",
		is_equal_approx(float(settings.get_effect(String(ids_confort[0]))), 0.45),
		str(settings.get_effect(String(ids_confort[0]))))
	_check("et fait passer le résumé en « personnalisé »",
		int(screen._niveau_confort_courant()) == -1)
	var aucun_enfonce := true
	for btn in screen._boutons_niveau:
		if btn.button_pressed:
			aucun_enfonce = false
			break
	_check("aucun niveau n'est allumé à tort", aucun_enfonce)

	# Idempotence : deux rafraîchissements d'affilée donnent le même écran, et
	# n'écrasent pas la préférence qu'ils viennent montrer.
	var avant: float = screen._rows[String(ids_confort[0])]["slider"].value
	screen.refresh()
	screen.refresh()
	_check("deux rafraîchissements donnent le même affichage",
		is_equal_approx(float(screen._rows[String(ids_confort[0])]["slider"].value), avant),
		str(screen._rows[String(ids_confort[0])]["slider"].value))
	_check("et ne touchent pas à la préférence",
		is_equal_approx(float(settings.get_effect(String(ids_confort[0]))), 0.45),
		str(settings.get_effect(String(ids_confort[0]))))

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
