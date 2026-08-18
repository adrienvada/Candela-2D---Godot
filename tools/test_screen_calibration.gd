## Test headless de l'écran de calibration de luminosité (`screen_calibration.gd`).
##
## Ce que la suite protège, dans l'ordre d'importance :
##
##   • LA propriété à ne jamais laisser régresser — la cible perceptive encadre le
##     réglage des DEUX côtés. Il existe une fenêtre non vide, strictement à
##     l'intérieur de la course, où le repère se voit et la limite reste cachée ;
##     hors de cette fenêtre, l'écran le dit. Une cible qui ne poserait qu'un
##     plancher laisserait chacun monter, et l'écran ne servirait plus à rien ;
##   • la valeur annoncée est celle qui est affichée : le pourcentage lu, la
##     jauge, l'aperçu et la charge utile parlent tous du même réglage ;
##   • le réglage est borné et aligné sur un cran, par toutes les routes — bouton,
##     jauge, valeur adoptée, NAN, infini ;
##   • aux extrêmes, l'écran tient : rien ne disparaît de sous le curseur, rien
##     n'est annoncé deux fois, et le retour au repère neutre reste offert ;
##   • `refresh()` est idempotent, y compris avant toute construction.
##
## CE QUI N'EST PAS COUVERT ICI : le dessin. Un test headless ne peint rien, et
## juger « la silhouette est visible » demanderait un œil. On vérifie donc la
## seule chose vérifiable et la seule qui puisse régresser en silence : les
## couleurs posées sur le champ, et le modèle qui les produit.
##
## Lancer : godot --headless --path . --script res://tools/test_screen_calibration.gd
extends SceneTree

## Marge autour des bornes de la fenêtre, exclue du balayage : à la frontière
## exacte, deux chemins de calcul flottants peuvent trancher différemment, et ce
## n'est pas ce que la suite protège.
const EPS := 0.001

## L'écran ne persiste rien : la suite le vérifie en comparant le fichier de
## préférences réel avant et après.
const REAL_SETTINGS := "user://settings.cfg"

var _failures: int = 0

## Chargés dans `_run()`, jamais dans `_init()` : en mode --script, `_init()`
## s'exécute avant les autoloads ET avant le cache des classes globales. Un
## `class_name` référencé trop tôt rend un objet nu, les SCRIPT ERROR
## n'incrémentent aucun compteur, et la suite annonce « tous les tests passent »
## sans avoir rien exécuté.
var _screen_script: GDScript
var _theme: GDScript

## Grammaire des verdicts relue dans l'écran plutôt que recopiée ici : une
## énumération recopiée dans une suite finit par tester autre chose que ce que le
## jeu exécute.
var _V: Dictionary = {}

## Tout ce qui a été instancié, à libérer à la fin — un test qui fuit finit par
## masquer une vraie fuite.
var _trash: Array[Node] = []

func _init() -> void:
	print("=== Test de l'écran de calibration ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame

	var real_before := _snapshot_real_settings()

	if not _preflight():
		printerr("\n✗ Aucun test exécuté : l'écran de calibration est absent ou incomplet")
		quit(1)
		return

	_test_echelle()
	_test_modele()
	_test_fenetre()
	_test_bornes()
	_test_avant_construction()
	_test_affichage()
	_test_emission()
	_test_manette()
	_test_extremes()
	_test_retour_au_repere()
	_test_apercu_local()
	_test_idempotence()

	_check("les préférences réelles du joueur sont intactes",
		_snapshot_real_settings() == real_before,
		"user://settings.cfg a été touché par le test")

	for node in _trash:
		if is_instance_valid(node):
			node.free()

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
# Rien ne sert de conclure sur un écran qui n'a pas compilé : sans ce contrôle,
# une classe absente du catalogue global se solderait par une suite qui « passe »
# sans avoir rien exercé.

func _preflight() -> bool:
	print("\n[Contrôle préalable]")

	_screen_script = load("res://screen_calibration.gd") as GDScript
	_theme = load("res://menu_theme.gd") as GDScript

	var ok := true
	for pair in [["screen_calibration.gd", _screen_script], ["menu_theme.gd", _theme]]:
		if pair[1] == null:
			printerr("  ✗ script introuvable ou non compilé : ", pair[0])
			ok = false
	if not ok:
		return false

	var declared := ""
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) == "ScreenCalibration":
			declared = String(entry.get("path", ""))
	_check("ScreenCalibration est au catalogue des classes globales", declared != "",
		"catalogue vide ou classe absente — lancer : Godot --headless --path . --import")
	_check("déclarée à la racine", declared == "res://screen_calibration.gd", declared)
	if declared == "":
		return false

	# Le modèle est fait de fonctions statiques : elles se cherchent sur le script
	# lui-même, où `has_method` ne rend justement que celles-là.
	var missing := ""
	for method in ["clamp_level", "snap_level", "gamma_for", "level_for_gamma",
			"perceived", "is_patch_visible", "visible_count", "verdict_for", "window",
			"level_to_percent", "percent_to_level", "field_black", "patch_color",
			"patch_colors", "verdict_line", "verdict_color"]:
		if not _screen_script.has_method(method):
			missing += method + " "
	_check("le modèle perceptif est exposé en fonctions pures", missing == "", missing)

	# Les méthodes d'instance, elles, se cherchent sur une instance.
	var probe: Node = _screen_script.new()
	_trash.append(probe)
	var missing_inst := ""
	for method in ["screen_title", "build", "refresh", "focus_seed", "current_level",
			"current_percent", "current_verdict", "payload", "adopt_level"]:
		if not probe.has_method(method):
			missing_inst += method + " "
	_check("l'écran porte tout ce que la suite exerce", missing_inst == "", missing_inst)

	# Le contrat de `HubScreen` : c'est par ces deux signaux, et seulement par eux,
	# qu'un écran s'adresse au reste du jeu.
	_check("l'écran respecte le contrat de HubScreen",
		probe.has_signal("action_requested") and probe.has_signal("navigate_requested"))
	_check("le titre de l'écran est renseigné",
		String(probe.screen_title()).strip_edges() != "")
	_check("le nom d'action est renseigné",
		String(_screen_script.ACTION).strip_edges() != "", String(_screen_script.ACTION))

	var verdicts: Variant = _screen_script.Verdict
	if not verdicts is Dictionary:
		printerr("  ✗ ScreenCalibration.Verdict n'est pas une énumération lisible")
		return false
	_V = verdicts as Dictionary
	for name in ["TROP_SOMBRE", "JUSTE", "TROP_CLAIR"]:
		if not _V.has(name):
			missing_inst += name + " "
	_check("les trois verdicts sont là", missing_inst == "", missing_inst)

	return missing == "" and missing_inst == ""

# ---------------------------------------------------------------------------
# OUTILLAGE
# ---------------------------------------------------------------------------

## Un écran construit, sans hub — c'est le contrat de `HubScreen` — mais DANS
## l'arbre.
##
## Le piège coûte cher et ne se voit pas : `Range.value_changed` n'est émis que
## si le nœud est dans l'arbre. Hors arbre, `jauge.value = 80` change la valeur
## en silence. Une suite qui exercerait la jauge hors arbre ne prouverait donc
## rien — ni que la souris écrit le réglage, ni que `refresh()` s'abstient de
## l'annoncer, ce dernier contrôle devenant vide au moment même où il compte.
##
## Le corps est enfant de l'écran : une seule libération suffit.
func _make_screen() -> Control:
	var screen: Control = _screen_script.new()
	screen.name = "CalibrationEssai%d" % _trash.size()
	var body := VBoxContainer.new()
	screen.add_child(body)
	screen.build(body)
	root.add_child(screen)
	_trash.append(screen)
	return screen

func _press(button: BaseButton) -> void:
	button.pressed.emit()

## Empreinte de tout ce que l'écran montre. Deux empreintes égales, c'est le même
## écran — c'est la mesure de l'idempotence.
func _signature(screen: Control) -> String:
	var parts := PackedStringArray([
		"%.4f" % float(screen.current_level()), str(screen.current_percent()),
		screen._value_label.text, "%.2f" % float(screen._gauge.value),
		screen._verdict_label.text, str(screen._bound_notice.visible),
		str(screen._verdict_label.get_theme_color(&"font_color")),
		str(screen._field.background)])
	for color in screen._field.patches:
		parts.append(str(color))
	return "|".join(parts)

func _juste() -> int:
	return int(_V["JUSTE"])

# ---------------------------------------------------------------------------
# L'ÉCHELLE
# ---------------------------------------------------------------------------
#
# La cible n'a de sens que si les deux marques encadrent VRAIMENT le seuil, et
# qu'elles sont voisines : deux crans éloignés laisseraient une fenêtre si large
# que n'importe quel réglage y tomberait, et l'écran serait décoratif.

func _test_echelle() -> void:
	print("\n[L'échelle des silhouettes]")

	var ladder: Array = _screen_script.LADDER
	var reveal := int(_screen_script.INDEX_REVEAL)
	var hide := int(_screen_script.INDEX_HIDE)
	var threshold := float(_screen_script.THRESHOLD)

	_check("l'échelle a plusieurs crans", ladder.size() >= 3, str(ladder.size()))

	var decreasing := true
	for i in range(1, ladder.size()):
		if float(ladder[i]) >= float(ladder[i - 1]):
			decreasing = false
			break
	_check("les crans vont du plus clair au plus sombre, strictement", decreasing,
		str(ladder))

	_check("les deux marques sont des crans de l'échelle",
		reveal >= 0 and reveal < ladder.size() and hide >= 0 and hide < ladder.size(),
		"%d et %d" % [reveal, hide])
	_check("la limite est le cran juste sous le repère", hide == reveal + 1,
		"%d puis %d" % [reveal, hide])

	# LE cœur de la cible : au repère neutre, le seuil de perception passe ENTRE
	# les deux marques. Sans cela il n'y a pas de fenêtre, seulement un plancher.
	var default_level := float(_screen_script.LEVEL_DEFAULT)
	_check("au repère neutre, le repère est au-dessus du seuil",
		float(_screen_script.perceived(ladder[reveal], default_level)) > threshold,
		str(_screen_script.perceived(ladder[reveal], default_level)))
	_check("et la limite en dessous",
		float(_screen_script.perceived(ladder[hide], default_level)) < threshold,
		str(_screen_script.perceived(ladder[hide], default_level)))

	# Une silhouette invisible vaut EXACTEMENT le fond. Posée en absolu, la plus
	# sombre serait plus sombre que le champ, donc parfaitement visible en négatif
	# — l'inverse de ce que la cible demande.
	var back: Color = _screen_script.field_black()
	var darkest: Color = _screen_script.patch_color(0.0, default_level)
	_check("un cran éteint se confond avec le fond", darkest.is_equal_approx(back),
		"%s pour un fond %s" % [str(darkest), str(back)])
	_check("le fond du champ est opaque", is_equal_approx(back.a, 1.0), str(back.a))
	# Le fond est la RÉFÉRENCE de la mesure, pas une couleur d'interface. Le fond
	# de hub, volontairement moins noir que le jeu, décalerait chaque joueur du
	# même côté et sans que rien ne le montre : un noir relevé écrase le contraste
	# des crans bas, chacun compenserait en montant.
	_check("le champ se mesure sur le noir du match",
		is_zero_approx(back.r) and is_zero_approx(back.g) and is_zero_approx(back.b),
		str(back))
	_check("il n'emprunte donc pas le fond de hub, plus clair",
		not back.is_equal_approx(_theme.BACKDROP), str(back))
	# Et il reste très en dessous du plus bas cran, sinon il masquerait l'échelle
	# par le bas.
	_check("le fond reste sous le plus bas cran",
		maxf(maxf(back.r, back.g), back.b) < float(ladder[ladder.size() - 1]),
		"%s contre %f" % [str(back), float(ladder[ladder.size() - 1])])

# ---------------------------------------------------------------------------
# LE MODÈLE
# ---------------------------------------------------------------------------

func _test_modele() -> void:
	print("\n[Le modèle perceptif]")

	_check("mi-course ne corrige rien",
		is_equal_approx(float(_screen_script.gamma_for(0.5)), 1.0),
		str(_screen_script.gamma_for(0.5)))
	# La course est symétrique en logarithme : deux corrections successives
	# multiplient leurs exposants, un demi-tour vers le clair doit donc annuler
	# exactement un demi-tour vers le sombre.
	_check("la course est symétrique autour du repère neutre",
		is_equal_approx(float(_screen_script.gamma_for(0.0))
			* float(_screen_script.gamma_for(1.0)), 1.0),
		"%f × %f" % [_screen_script.gamma_for(0.0), _screen_script.gamma_for(1.0)])

	var monotone := true
	var previous := INF
	for i in 101:
		var gamma := float(_screen_script.gamma_for(float(i) / 100.0))
		if gamma >= previous:
			monotone = false
			break
		previous = gamma
	_check("monter le réglage relève les noirs, toujours", monotone)

	var inverse_ok := true
	var inverse_detail := ""
	for i in 101:
		var level := float(i) / 100.0
		var round_trip := float(_screen_script.level_for_gamma(
			_screen_script.gamma_for(level)))
		if absf(round_trip - level) > 0.0001:
			inverse_ok = false
			inverse_detail = "%f → %f" % [level, round_trip]
			break
	_check("l'exposant se relit en réglage sans dérive", inverse_ok, inverse_detail)

	# Ce que voit le joueur ne peut qu'augmenter quand il monte le réglage. Un
	# aperçu non monotone rendrait la cible impossible à viser : le joueur
	# corrigerait dans le mauvais sens sans jamais comprendre pourquoi.
	var counts_ok := true
	var counts_detail := ""
	var last_count := -1
	for i in 201:
		var level := float(i) / 200.0
		var count := int(_screen_script.visible_count(level))
		if count < last_count:
			counts_ok = false
			counts_detail = "à %f : %d après %d" % [level, count, last_count]
			break
		last_count = count
	_check("le nombre de silhouettes visibles ne décroît jamais", counts_ok, counts_detail)

	var ladder_size := int((_screen_script.LADDER as Array).size())
	# Au plus sombre l'écran ne doit pas devenir noir : le joueur y perdrait tout
	# point de repère, et jusqu'au moyen de savoir ce qu'il règle.
	_check("au plus sombre, il reste quelque chose à voir",
		int(_screen_script.visible_count(0.0)) >= 1,
		str(_screen_script.visible_count(0.0)))
	_check("au plus clair, toute l'échelle est visible",
		int(_screen_script.visible_count(1.0)) == ladder_size,
		str(_screen_script.visible_count(1.0)))

# ---------------------------------------------------------------------------
# LA FENÊTRE — LA PROPRIÉTÉ À NE JAMAIS LAISSER RÉGRESSER
# ---------------------------------------------------------------------------
#
# Une cible qui ne dirait que « montez jusqu'à voir ceci » ne poserait qu'un
# plancher : rien n'empêcherait d'aller plus haut, et c'est précisément plus haut
# que se trouve l'avantage. La fenêtre doit donc exister, être bornée des deux
# côtés, et être atteignable au cran près.

func _test_fenetre() -> void:
	print("\n[La fenêtre honnête]")

	var window: Vector2 = _screen_script.window()
	var low := window.x
	var high := window.y
	var notch := float(_screen_script.NOTCH)

	_check("la fenêtre n'est pas vide", high > low, "%f → %f" % [low, high])
	_check("elle est bornée par le bas, dans la course", low > float(_screen_script.LEVEL_MIN),
		str(low))
	_check("et par le haut, dans la course", high < float(_screen_script.LEVEL_MAX), str(high))
	_check("le repère neutre y tombe",
		float(_screen_script.LEVEL_DEFAULT) >= low and float(_screen_script.LEVEL_DEFAULT) < high,
		"%f hors de [%f, %f[" % [_screen_script.LEVEL_DEFAULT, low, high])

	# Une fenêtre plus étroite qu'un cran serait injoignable : le joueur
	# n'atteindrait jamais le verdict juste et l'écran passerait pour cassé.
	var notches := 0
	for i in 21:
		var level := float(i) * notch
		if int(_screen_script.verdict_for(level)) == _juste():
			notches += 1
	_check("plusieurs crans y tombent, elle est donc joignable", notches >= 3, str(notches))
	# À l'inverse, une fenêtre trop large ne contraindrait plus rien.
	_check("mais pas toute la course", notches <= 9, str(notches))

	# Le verdict et la fenêtre sont deux calculs différents de la même chose :
	# c'est ici qu'on vérifie qu'ils ne divergent pas.
	var mismatch := ""
	for i in 1001:
		var level := float(i) / 1000.0
		if absf(level - low) < EPS or absf(level - high) < EPS:
			continue
		var inside := level >= low and level < high
		var juste := int(_screen_script.verdict_for(level)) == _juste()
		if inside != juste:
			mismatch = "à %f : fenêtre=%s, verdict=%s" % [level, str(inside), str(juste)]
			break
	_check("le verdict dit exactement la fenêtre, sur toute la course", mismatch == "",
		mismatch)

	_check("sous la fenêtre, c'est trop sombre",
		int(_screen_script.verdict_for(low - 10.0 * EPS)) == int(_V["TROP_SOMBRE"]))
	_check("au-dessus, c'est trop clair",
		int(_screen_script.verdict_for(high + 10.0 * EPS)) == int(_V["TROP_CLAIR"]))

	# Chaque verdict a sa phrase, et une phrase qui ne dit pas la même chose que
	# les autres : sans elle, un joueur bloqué hors fenêtre n'a aucune idée de la
	# direction à prendre.
	var lines := {}
	for name in ["TROP_SOMBRE", "JUSTE", "TROP_CLAIR"]:
		var line := String(_screen_script.verdict_line(int(_V[name])))
		_check("le verdict « %s » a sa phrase" % name, line.strip_edges().length() > 20, line)
		lines[line] = true
	_check("les trois phrases sont distinctes", lines.size() == 3, str(lines.size()))
	_check("le juste ne se peint pas comme un avertissement",
		_screen_script.verdict_color(_juste()) == _theme.GOLD)
	_check("les deux dérives, si", _screen_script.verdict_color(int(_V["TROP_SOMBRE"]))
		== _theme.WARN and _screen_script.verdict_color(int(_V["TROP_CLAIR"])) == _theme.WARN)

# ---------------------------------------------------------------------------
# BORNES ET ÉCRÊTAGE
# ---------------------------------------------------------------------------

func _test_bornes() -> void:
	print("\n[Bornes et crans]")

	_check("en dessous de la course, écrêté au minimum",
		is_equal_approx(float(_screen_script.clamp_level(-5.0)),
			float(_screen_script.LEVEL_MIN)))
	_check("au-dessus, écrêté au maximum",
		is_equal_approx(float(_screen_script.clamp_level(5.0)),
			float(_screen_script.LEVEL_MAX)))
	# NAN se propage silencieusement dans un flottant : il rendrait l'aperçu noir
	# sans la moindre erreur. Il retombe sur le repère neutre.
	_check("NAN retombe sur le repère neutre",
		is_equal_approx(float(_screen_script.clamp_level(NAN)),
			float(_screen_script.LEVEL_DEFAULT)),
		str(_screen_script.clamp_level(NAN)))
	_check("l'infini est écrêté comme le reste",
		is_equal_approx(float(_screen_script.clamp_level(INF)), float(_screen_script.LEVEL_MAX))
		and is_equal_approx(float(_screen_script.clamp_level(-INF)),
			float(_screen_script.LEVEL_MIN)))

	var notch := float(_screen_script.NOTCH)
	var snapped_ok := true
	var snapped_detail := ""
	for raw in [-3.0, 0.0, 0.013, 0.037, 0.5, 0.6123, 0.999, 1.0, 42.0, NAN]:
		var value := float(_screen_script.snap_level(raw))
		if value < 0.0 or value > 1.0:
			snapped_ok = false
			snapped_detail = "%f hors bornes" % value
			break
		if absf(value - snappedf(value, notch)) > 0.0001:
			snapped_ok = false
			snapped_detail = "%f n'est pas sur un cran" % value
			break
	_check("toute valeur entrante est bornée ET posée sur un cran", snapped_ok,
		snapped_detail)

	_check("mi-course affiche 50 %", int(_screen_script.level_to_percent(0.5)) == 50)
	_check("un réglage débordant est écrêté à 100 %",
		int(_screen_script.level_to_percent(3.0)) == 100)
	_check("un réglage négatif est écrêté à 0 %",
		int(_screen_script.level_to_percent(-1.0)) == 0)
	_check("35 % rend 0,35", is_equal_approx(float(_screen_script.percent_to_level(35)), 0.35))
	_check("aller-retour pourcentage",
		int(_screen_script.level_to_percent(_screen_script.percent_to_level(65))) == 65)
	_check("un pourcentage aberrant est écrêté",
		is_equal_approx(float(_screen_script.percent_to_level(999)), 1.0)
		and is_equal_approx(float(_screen_script.percent_to_level(-999)), 0.0))

# ---------------------------------------------------------------------------
# AVANT TOUTE CONSTRUCTION
# ---------------------------------------------------------------------------
#
# Le hub appelle `refresh()` sur des écrans qu'il n'a pas encore montrés, et
# parfois jamais construits. Un plantage ici ne se verrait qu'à l'ouverture d'un
# AUTRE écran, ce qui est le pire endroit pour chercher la cause.

func _test_avant_construction() -> void:
	print("\n[Avant construction]")

	var screen: Control = _screen_script.new()
	_trash.append(screen)

	screen.refresh()
	screen.refresh()
	_check("rafraîchir un écran jamais construit ne plante pas", true)
	_check("aucun contrôle à viser", screen.focus_seed() == null)
	_check("le réglage part du repère neutre",
		is_equal_approx(float(screen.current_level()), float(_screen_script.LEVEL_DEFAULT)),
		str(screen.current_level()))

	var payload: Dictionary = screen.payload()
	_check("la charge utile est complète avant tout affichage",
		payload.has("valeur") and payload.has("pourcent") and payload.has("dans_la_fenetre"),
		str(payload.keys()))
	_check("et elle annonce un réglage dans la fenêtre",
		bool(payload["dans_la_fenetre"]), str(payload))

	# Adopter une valeur sur un écran non construit doit tenir : c'est exactement
	# ce que fera l'hôte qui relit les préférences avant le premier affichage.
	screen.adopt_level(0.2)
	_check("adopter un réglage avant construction ne plante pas",
		int(screen.current_percent()) == 20, str(screen.current_percent()))

	screen.build(null)
	_check("construire sans corps ne plante pas", true)

	var body := VBoxContainer.new()
	screen.add_child(body)
	screen.build(body)
	var count := body.get_child_count()
	_check("l'écran se remplit", count > 0, str(count))
	screen.build(body)
	_check("construire deux fois ne double pas le contenu",
		body.get_child_count() == count, "%d puis %d" % [count, body.get_child_count()])
	_check("et le réglage adopté avant la construction est celui qui s'affiche",
		screen._value_label.text == "20 %", screen._value_label.text)

# ---------------------------------------------------------------------------
# CE QUI EST AFFICHÉ
# ---------------------------------------------------------------------------

func _test_affichage() -> void:
	print("\n[L'affichage suit le réglage]")

	var screen := _make_screen()
	var drift := ""
	for percent in [0, 15, 40, 50, 65, 100]:
		screen.adopt_level(float(percent) / 100.0)
		var level: float = screen.current_level()

		if int(screen.current_percent()) != percent:
			drift = "%d %% adopté, %d %% retenu" % [percent, screen.current_percent()]
			break
		if screen._value_label.text != "%d %%" % percent:
			drift = "%d %% retenu, « %s » affiché" % [percent, screen._value_label.text]
			break
		if not is_equal_approx(float(screen._gauge.value), float(percent)):
			drift = "%d %% affiché, jauge à %f" % [percent, screen._gauge.value]
			break
		if int(screen.payload()["pourcent"]) != percent:
			drift = "%d %% affiché, %s annoncé" % [percent, str(screen.payload())]
			break
		if screen._verdict_label.text != String(_screen_script.verdict_line(
				_screen_script.verdict_for(level))):
			drift = "verdict désaccordé à %d %%" % percent
			break

		# L'aperçu aussi : c'est lui que le joueur regarde, et une image figée
		# pendant que le chiffre bouge est le pire des deux mondes.
		var expected: PackedColorArray = _screen_script.patch_colors(level)
		if screen._field.patches != expected:
			drift = "aperçu désaccordé à %d %%" % percent
			break
	_check("chiffre, jauge, verdict, aperçu et charge utile parlent du même réglage",
		drift == "", drift)

	_check("une marque par cran de l'échelle",
		screen._marks.get_child_count() == int((_screen_script.LADDER as Array).size()),
		str(screen._marks.get_child_count()))
	var reveal_mark: Label = screen._marks.get_child(int(_screen_script.INDEX_REVEAL))
	var hide_mark: Label = screen._marks.get_child(int(_screen_script.INDEX_HIDE))
	# Savoir OÙ regarder fait partie de la mesure : un joueur qui cherche la
	# limite au hasard conclut « je ne la vois pas » aussi bien quand elle est là
	# que quand elle n'y est pas.
	_check("le repère est nommé sous sa silhouette",
		reveal_mark.text.strip_edges() != "", reveal_mark.text)
	_check("la limite aussi, bien qu'elle doive rester invisible",
		hide_mark.text.strip_edges() != "", hide_mark.text)
	_check("les deux marques ne disent pas la même chose", reveal_mark.text != hide_mark.text)

# ---------------------------------------------------------------------------
# CE QUI SORT DE L'ÉCRAN
# ---------------------------------------------------------------------------

func _test_emission() -> void:
	print("\n[Ce que l'écran annonce]")

	var screen := _make_screen()
	var actions: Array[String] = []
	var payloads: Array = []
	screen.action_requested.connect(func(action: String, payload: Variant) -> void:
		actions.append(action)
		payloads.append(payload))

	screen.adopt_level(0.5)
	_check("adopter un réglage n'annonce rien", actions.is_empty(), str(actions))

	_press(screen._btn_brighter)
	_check("un pas annonce exactement une fois", actions.size() == 1, str(actions))
	_check("sous le nom d'action documenté",
		actions.size() == 1 and actions[0] == String(_screen_script.ACTION), str(actions))

	var payload: Dictionary = payloads[0] if not payloads.is_empty() else {}
	_check("la charge utile porte les trois clés",
		payload.has("valeur") and payload.has("pourcent") and payload.has("dans_la_fenetre"),
		str(payload.keys()))
	_check("la valeur annoncée est celle qui est affichée",
		is_equal_approx(float(payload.get("valeur", -1.0)), float(screen.current_level()))
		and int(payload.get("pourcent", -1)) == int(screen.current_percent())
		and screen._value_label.text == "%d %%" % int(payload.get("pourcent", -1)),
		"%s pour « %s »" % [str(payload), screen._value_label.text])
	_check("la valeur annoncée est bornée et sur un cran",
		is_equal_approx(float(payload.get("valeur", -1.0)),
			float(_screen_script.snap_level(payload.get("valeur", -1.0)))), str(payload))
	_check("et le verdict annoncé est celui qui est écrit",
		bool(payload.get("dans_la_fenetre", false))
		== (int(screen.current_verdict()) == _juste()), str(payload))

	# La souris tire la jauge : même chemin, même annonce. Deux chemins d'écriture
	# qui divergeraient produiraient un réglage affiché ici et un autre retenu.
	actions.clear()
	payloads.clear()
	screen._gauge.value = 80.0
	_check("tirer la jauge annonce aussi", actions.size() == 1, str(actions))
	_check("et annonce le même réglage que celui qu'elle montre",
		int(screen.current_percent()) == 80
		and not payloads.is_empty() and int((payloads[0] as Dictionary)["pourcent"]) == 80,
		"%d / %s" % [screen.current_percent(), str(payloads)])

	# Repositionner la jauge pendant un affichage n'est PAS un choix du joueur.
	# Contrôle vide hors de l'arbre — `Range` n'y émet rien — et c'est justement
	# là qu'il compte : dans l'arbre, chaque `refresh()` fait bouger la jauge.
	actions.clear()
	screen.refresh()
	screen.refresh()
	_check("rafraîchir n'annonce rien", actions.is_empty(), str(actions))
	_check("et l'affichage n'a pas dérivé au passage",
		int(screen.current_percent()) == 80, str(screen.current_percent()))

	# Le retour au repère est offert sans condition, y compris quand on y est
	# déjà : un bouton désactivé sort des candidats du curseur.
	actions.clear()
	_press(screen._btn_reset)
	_check("le retour au repère neutre annonce", actions.size() == 1, str(actions))
	_check("et ramène bien au repère",
		is_equal_approx(float(screen.current_level()), float(_screen_script.LEVEL_DEFAULT)),
		str(screen.current_level()))
	actions.clear()
	_press(screen._btn_reset)
	_check("y revenir quand on y est déjà n'annonce rien de plus", actions.is_empty(),
		str(actions))
	_check("mais le bouton reste offert", not screen._btn_reset.disabled)

# ---------------------------------------------------------------------------
# LA MANETTE
# ---------------------------------------------------------------------------
#
# Gauche et droite DÉPLACENT LE CURSEUR dans ce jeu (`ui.gd` les résout
# géométriquement, parce que deux joueurs naviguent en même temps). Un contrôle
# focalisé ne les reçoit donc jamais, et une jauge réglée par gauche/droite
# serait morte à la manette. D'où la disposition qu'on vérifie ici.

func _test_manette() -> void:
	print("\n[Navigation à la manette]")

	var screen := _make_screen()

	_check("le pas vers le sombre est atteignable au curseur",
		screen._btn_darker.focus_mode != Control.FOCUS_NONE and not screen._btn_darker.disabled)
	_check("le pas vers le clair aussi",
		screen._btn_brighter.focus_mode != Control.FOCUS_NONE
		and not screen._btn_brighter.disabled)
	# Pousser à gauche doit amener sur le bouton qui assombrit : le geste et
	# l'effet vont alors dans le même sens, et il n'y a rien à mémoriser.
	_check("« plus sombre » est à gauche de « plus clair »",
		screen._btn_darker.get_parent() == screen._btn_brighter.get_parent()
		and screen._btn_darker.get_index() < screen._btn_brighter.get_index(),
		"%d puis %d" % [screen._btn_darker.get_index(), screen._btn_brighter.get_index()])
	# Un contrôle que la manette ne peut pas régler n'a rien à faire sous le
	# curseur : il ne ferait qu'avaler un cran de navigation pour rien.
	_check("la jauge ne retient pas le curseur",
		screen._gauge.focus_mode == Control.FOCUS_NONE)
	_check("son pas est celui des boutons",
		is_equal_approx(float(screen._gauge.step), float(_screen_script.NOTCH) * 100.0),
		str(screen._gauge.step))

	_check("le curseur se pose sur un contrôle atteignable",
		screen.focus_seed() != null and screen.focus_seed().focus_mode != Control.FOCUS_NONE)
	# Dans ce jeu, c'est le trop clair qui donne l'avantage : le premier geste
	# offert est celui qui n'en donne aucun.
	_check("et il se pose du côté qui n'avantage personne",
		screen.focus_seed() == screen._btn_darker)

	# Aucune fenêtre modale : un écran navigué à deux curseurs n'a pas de quoi en
	# refermer une, et la valeur sort à chaque changement plutôt qu'à une
	# validation qu'on pourrait manquer en ressortant par le retour.
	var popups := 0
	for node in _all_nodes(screen):
		if node is Popup or node is AcceptDialog:
			popups += 1
	_check("aucune fenêtre modale", popups == 0, str(popups))

func _test_extremes() -> void:
	print("\n[Aux extrêmes]")

	var screen := _make_screen()
	var actions: Array[String] = []
	screen.action_requested.connect(func(action: String, _payload: Variant) -> void:
		actions.append(action))

	for i in 40:
		_press(screen._btn_darker)
	_check("le bout sombre s'atteint et ne se dépasse pas",
		int(screen.current_percent()) == 0, str(screen.current_percent()))
	# Dix crans depuis le repère, et pas un de plus : appuyer dans le vide ne
	# doit rien annoncer, sans quoi le journal — et le disque, le jour où la
	# persistance sera branchée — se remplit d'un réglage identique répété.
	_check("les appuis dans le vide n'annoncent rien", actions.size() == 10,
		"%d annonces pour 40 appuis" % actions.size())
	_check("c'est annoncé comme trop sombre",
		int(screen.current_verdict()) == int(_V["TROP_SOMBRE"]))
	_check("et le bout de course est expliqué", screen._bound_notice.visible)
	_check("la limite reste invisible",
		not bool(_screen_script.is_patch_visible(
			(_screen_script.LADDER as Array)[int(_screen_script.INDEX_HIDE)], 0.0)))
	# L'écran ne doit pas devenir noir : le joueur y perdrait le moyen même de
	# savoir ce qu'il règle.
	_check("il reste quelque chose à l'écran",
		int(_screen_script.visible_count(0.0)) >= 1)
	# Rien ne disparaît de sous le curseur au bout de la course.
	_check("les deux pas restent offerts",
		not screen._btn_darker.disabled and not screen._btn_brighter.disabled)

	actions.clear()
	for i in 40:
		_press(screen._btn_brighter)
	_check("le bout clair s'atteint et ne se dépasse pas",
		int(screen.current_percent()) == 100, str(screen.current_percent()))
	_check("vingt crans annoncés pour quarante appuis", actions.size() == 20,
		str(actions.size()))
	_check("c'est annoncé comme trop clair",
		int(screen.current_verdict()) == int(_V["TROP_CLAIR"]))
	_check("le bout de course est expliqué là aussi", screen._bound_notice.visible)
	_check("la charge utile signale le hors-fenêtre",
		not bool((screen.payload() as Dictionary)["dans_la_fenetre"]), str(screen.payload()))

	screen.adopt_level(float(_screen_script.LEVEL_DEFAULT))
	_check("au milieu, plus de mention de bout de course", not screen._bound_notice.visible)

## Ce qu'un joueur récupère après avoir réglé n'importe quoi : le repère neutre,
## en un geste, sans avoir à savoir quel chiffre c'était.
func _test_retour_au_repere() -> void:
	print("\n[Revenir]")

	var screen := _make_screen()
	for garbage in [NAN, INF, -INF, 999.0, -999.0, 0.0, 1.0]:
		screen.adopt_level(garbage)
		var level: float = screen.current_level()
		if level < 0.0 or level > 1.0 or is_nan(level):
			_check("une valeur aberrante ne sort jamais de la course", false, str(garbage))
			return
	_check("aucune valeur aberrante ne sort de la course", true)

	_press(screen._btn_reset)
	_check("un seul geste ramène au repère neutre",
		is_equal_approx(float(screen.current_level()), float(_screen_script.LEVEL_DEFAULT)),
		str(screen.current_level()))
	_check("l'affichage suit", screen._value_label.text
		== "%d %%" % int(_screen_script.level_to_percent(_screen_script.LEVEL_DEFAULT)),
		screen._value_label.text)
	_check("et le verdict redevient juste", int(screen.current_verdict()) == _juste())

# ---------------------------------------------------------------------------
# L'APERÇU RESTE CHEZ LUI
# ---------------------------------------------------------------------------
#
# Un écran de réglage qui toucherait au monde du jeu — `CanvasModulate` global,
# arène chargée pour l'occasion — laisserait derrière lui un état que personne ne
# pense à défaire, et le défaut se verrait en match, pas ici.

func _test_apercu_local() -> void:
	print("\n[L'aperçu ne sort pas de l'écran]")

	var screen := _make_screen()
	var intrus := ""
	for node in _all_nodes(screen):
		if node is CanvasModulate or node is CanvasLayer or node is Camera2D \
				or node is Light2D or node is SubViewport:
			intrus = node.get_class()
			break
	_check("l'écran ne fabrique ni lumière, ni caméra, ni calque global", intrus == "",
		intrus)

	_check("le champ de mesure est bien dans l'écran",
		screen.is_ancestor_of(screen._field))
	_check("et il peint son propre noir, opaque",
		is_equal_approx(float(screen._field.background.a), 1.0),
		str(screen._field.background))

func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		out.append(node)
		for child in node.get_children():
			stack.append(child)
	return out

# ---------------------------------------------------------------------------
# IDEMPOTENCE
# ---------------------------------------------------------------------------
#
# Le hub rafraîchit à chaque fois qu'un écran redevient visible, et parfois
# avant. Un `refresh()` qui dériverait d'un appel à l'autre produirait un défaut
# qui dépend de l'ordre d'ouverture des écrans — c'est-à-dire un défaut qui ne se
# voit que sur la machine de quelqu'un d'autre.

func _test_idempotence() -> void:
	print("\n[Idempotence]")

	var screen := _make_screen()
	var derive := ""
	for percent in [0, 25, 50, 75, 100]:
		screen.adopt_level(float(percent) / 100.0)
		var first := _signature(screen)
		screen.refresh()
		screen.refresh()
		screen.refresh()
		if _signature(screen) != first:
			derive = "%d %% :\n    %s\n    %s" % [percent, first, _signature(screen)]
			break
	_check("trois rafraîchissements donnent le même écran, sur toute la course",
		derive == "", derive)

	# Y compris après un choix du joueur, qui repasse par `refresh()` par un autre
	# chemin.
	_press(screen._btn_darker)
	var apres := _signature(screen)
	screen.refresh()
	_check("un pas laisse un écran stable", _signature(screen) == apres,
		"%s\n    %s" % [apres, _signature(screen)])

	# Adopter deux fois la même valeur ne doit rien changer non plus : c'est ce
	# que fera l'hôte à chaque ouverture de l'écran.
	screen.adopt_level(0.35)
	var adopte := _signature(screen)
	screen.adopt_level(0.35)
	_check("adopter deux fois le même réglage aussi", _signature(screen) == adopte)

# ---------------------------------------------------------------------------
# UTILITAIRES
# ---------------------------------------------------------------------------

## Empreinte du fichier de préférences réel. L'écran n'écrit rien : la suite doit
## le laisser exactement dans l'état où elle l'a trouvé — y compris absent.
func _snapshot_real_settings() -> String:
	if not FileAccess.file_exists(REAL_SETTINGS):
		return "<absent>"
	return FileAccess.get_file_as_string(REAL_SETTINGS)
