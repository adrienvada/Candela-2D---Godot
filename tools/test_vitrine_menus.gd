## Test headless de la vitrine des menus — Phase 5, vague M.
##
## Ces effets sont décoratifs, mais **ils éteignent des contrôles pour les
## rallumer**. Une coulée interrompue, une intensité passée à zéro au mauvais
## moment, et une entrée reste à alpha 0 : le joueur voit un menu à trous et
## n'a aucun moyen de comprendre pourquoi. Un effet de confort qui casse la
## navigation est pire que pas d'effet du tout.
##
## Ce banc vérifie donc surtout des **retours à l'état sain**, pas des jolis
## rendus : quoi qu'on fasse, tout se rallume.
##
## Lancer : godot --headless --path . --script res://tools/test_vitrine_menus.gd
extends SceneTree

var _failures: int = 0

func _init() -> void:
	print("=== Test de la vitrine des menus (vague M) ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_test_encre_repos()
	_test_encre_progression()
	_test_encre_restaure_toujours()
	_test_encre_depart()
	_test_tracante()
	_test_gravure()
	await _test_extinction()
	_test_lignes_de_politique()

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

## Une colonne d'entrées à géométrie connue : les conteneurs de Godot placent
## leurs enfants au fil des images, et un banc qui attendrait leur mise en page
## mesurerait l'ordonnanceur au lieu de mesurer l'effet.
func _colonne(nb: int) -> Control:
	var col := Control.new()
	col.position = Vector2(0, 0)
	col.size = Vector2(300, nb * 60)
	for i in nb:
		var e := Control.new()
		e.position = Vector2(0, i * 60)
		e.size = Vector2(300, 54)
		col.add_child(e)
	root.add_child(col)
	return col

func _alphas(col: Control) -> Array[float]:
	var out: Array[float] = []
	for c in col.get_children():
		out.append((c as Control).modulate.a)
	return out

func _tous_a_un(col: Control) -> bool:
	for a in _alphas(col):
		if not is_equal_approx(a, 1.0):
			return false
	return true

# ---------------------------------------------------------------------------

func _test_encre_repos() -> void:
	print("\n[L'encre au repos]")
	var encre := MenuInk.new()
	root.add_child(encre)
	var col := _colonne(4)

	encre.set_intensite(0.0)
	encre.couler(col, 0.0, Color.WHITE)
	# À zéro, le menu doit être **pixel pour pixel** celui d'avant l'effet : pas
	# une entrée éteinte, pas un tween lancé.
	_check("intensité nulle : aucune entrée n'est touchée", _tous_a_un(col),
		str(_alphas(col)))

	encre.set_intensite(1.0)
	encre.couler(null, 0.0, Color.WHITE)
	_check("une colonne absente ne fait rien planter", true)

	var vide := Control.new()
	vide.size = Vector2.ZERO
	root.add_child(vide)
	encre.couler(vide, 0.0, Color.WHITE)
	_check("une colonne de hauteur nulle est ignorée", true)

	col.free()
	vide.free()
	encre.free()

func _test_encre_progression() -> void:
	print("\n[L'encre écrit la colonne]")
	var encre := MenuInk.new()
	root.add_child(encre)
	var col := _colonne(4)

	encre.set_intensite(1.0)
	encre.couler(col, 0.0, Color.WHITE)
	# Devant le front, tout est éteint : c'est ce qui fait que l'écran s'écrit
	# au lieu d'apparaître.
	var eteintes: Array[float] = [0.0, 0.0, 0.0, 0.0]
	_check("au départ, toutes les entrées sont éteintes",
		_alphas(col) == eteintes, str(_alphas(col)))

	encre._avancer(1.0)
	# À l'arrivée, plus aucune entrée ne doit rester sous 1 : la dernière allumée
	# est celle qui décide si le menu est utilisable.
	var toutes_allumees := true
	for a in _alphas(col):
		if a < 1.0:
			toutes_allumees = false
	_check("à la fin, aucune entrée n'est restée sous sa valeur",
		toutes_allumees, str(_alphas(col)))

	# Le front part du geste et s'écarte des deux côtés : à mi-course, l'entrée
	# la plus proche du départ est plus allumée que la plus lointaine.
	encre.couler(col, 0.0, Color.WHITE)
	encre._avancer(0.5)
	var a := _alphas(col)
	_check("l'entrée proche du geste s'allume avant la lointaine",
		a[0] >= a[3], str(a))

	encre._arreter()
	col.free()
	encre.free()

## Le test qui compte vraiment.
func _test_encre_restaure_toujours() -> void:
	print("\n[Quoi qu'il arrive, tout se rallume]")
	var encre := MenuInk.new()
	root.add_child(encre)
	var col := _colonne(5)
	encre.set_intensite(1.0)

	encre.couler(col, 0.0, Color.WHITE)
	encre._arreter()
	_check("un arrêt en pleine coulée rallume tout", _tous_a_un(col), str(_alphas(col)))

	encre.couler(col, 0.0, Color.WHITE)
	# Le joueur baisse le curseur pendant que l'écran s'écrit : c'est le chemin
	# par lequel on se retrouverait avec un menu à trous, définitivement.
	encre.set_intensite(0.0)
	_check("passer l'intensité à zéro en pleine coulée rallume tout",
		_tous_a_un(col), str(_alphas(col)))

	encre.set_intensite(1.0)
	encre.couler(col, 0.0, Color.WHITE)
	# Deux navigations qui se chevauchent : la seconde ne doit pas abandonner les
	# entrées de la première dans le noir.
	var col2 := _colonne(3)
	encre.couler(col2, 0.0, Color.WHITE)
	_check("une seconde coulée rallume la colonne de la première",
		_tous_a_un(col), str(_alphas(col)))

	encre._arreter()
	col.free()
	col2.free()
	encre.free()

func _test_encre_depart() -> void:
	print("\n[D'où part l'encre]")
	var encre := MenuInk.new()
	root.add_child(encre)
	var col := _colonne(4)
	encre.set_intensite(1.0)

	# Un push venu du code, sans bouton : on ne sait pas où le doigt s'est posé.
	# Partir du haut est le sens de lecture, et n'oblige aucun appelant à mentir.
	encre.couler(col, -1.0, Color.WHITE)
	encre._avancer(0.35)
	var haut := _alphas(col)
	_check("sans geste connu, l'encre part du haut", haut[0] >= haut[3], str(haut))

	# Un geste hors de la colonne — souris sur un bouton d'une autre zone — ne
	# doit pas envoyer le front à l'infini : la portée serait fausse et la
	# dernière entrée s'allumerait après la fin de l'animation.
	encre.couler(col, 100000.0, Color.WHITE)
	encre._avancer(1.0)
	var plancher := 2.0
	for v in _alphas(col):
		plancher = minf(plancher, v)
	_check("un départ hors colonne est ramené dans la colonne", plancher >= 1.0,
		str(_alphas(col)))

	encre._arreter()
	col.free()
	encre.free()

func _test_tracante() -> void:
	print("\n[La traçante]")
	var t := MenuTracer.new()
	root.add_child(t)

	t.set_intensite(0.0)
	t.tirer(Vector2(100, 100), 1.0, Color.WHITE)
	_check("intensité nulle : aucun tir, aucun traitement", not t.is_processing())

	t.set_intensite(1.0)
	t.tirer(Vector2(100, 100), 1.0, Color.WHITE)
	_check("un tir met la traçante en vol", t.is_processing())

	# Coût nul au repos : la règle commune à toute la vitrine. Une traçante qui
	# continuerait à se redessiner après extinction coûterait pour rien, à chaque
	# image, jusqu'à la fermeture du jeu.
	var horloge := 0.0
	while horloge < MenuTracer.VOL + 0.05 and t.is_processing():
		t._process(0.016)
		horloge += 0.016
	_check("elle s'éteint seule et cesse de se traiter", not t.is_processing(),
		"%.3f s" % horloge)

	t.tirer(Vector2(10, 10), -1.0, Color.WHITE)
	_check("un sens négatif est accepté (retour)", t.is_processing())
	t.set_intensite(0.0)
	_check("l'extinction en plein vol coupe le traitement", not t.is_processing())

	t.free()

func _test_gravure() -> void:
	print("\n[Le code gravé]")
	var g := MenuEngraver.new()
	root.add_child(g)
	g.set_intensite(1.0)

	g.set_code("ab3d9f")
	_check("le code est retenu en majuscules", g.code() == "AB3D9F", g.code())
	_check("la gravure démarre", g.is_processing())

	# Le bloc salon se rafraîchit à chaque signal réseau, pour des raisons sans
	# rapport avec le code. Si la gravure rejouait à chaque fois, l'événement
	# perdrait tout son poids et le code clignoterait sans arrêt.
	g._finir()
	g.set_code("AB3D9F")
	_check("le même code ne regrave pas", not g.is_processing())

	g.marquer_copie()
	_check("la coche ne touche pas au code", g.code() == "AB3D9F", g.code())

	g.set_code("")
	_check("un salon fermé vide le code", g.code() == "", g.code())
	_check("et ne grave rien", not g.is_processing())

	# Six cases de largeur fixe : le gabarit occupe la même place avec un code,
	# sans code, et pendant la gravure. Sinon le bouton COPIER se déplacerait
	# sous le doigt qui le vise.
	var cases := g.get_node_or_null(^"Cases")
	_check("les six cases existent", cases != null and cases.get_child_count() >= MenuEngraver.CASES)
	if cases != null:
		var largeurs_fixes := true
		for i in MenuEngraver.CASES:
			var lbl := cases.get_child(i) as Label
			if lbl == null or lbl.custom_minimum_size.x <= 0.0:
				largeurs_fixes = false
		_check("chacune a une largeur imposée", largeurs_fixes)

	g.set_intensite(0.0)
	g.set_code("ZZZZZZ")
	_check("à intensité nulle le code est posé sans cérémonie",
		g.code() == "ZZZZZZ" and not g.is_processing(), g.code())

	g.free()

## M10 — l'extinction des feux.
##
## Le test qui compte est **le contrat de la reprise** : pendant le fondu de
## fermeture, `visible` est encore vrai mais le panneau doit compter comme fermé.
## Sans ça, `is_pause_menu_open()` resterait vrai un dixième de seconde après que
## le joueur a repris — en ligne, où le monde n'a jamais cessé de tourner, c'est
## une mort qu'on ne comprend pas.
func _test_extinction() -> void:
	print("\n[L'extinction des feux]")
	# `ui.gd` nomme des autoloads : le charger depuis `_init` ne compilerait pas,
	# et la suite pendrait au lieu d'échouer. D'où l'attente d'une image avant le
	# `load`, comme dans `test_pause_menu.gd`.
	var ui: Node = (load("res://ui.tscn") as PackedScene).instantiate()
	ui.name = "UI"
	root.add_child(ui)
	await process_frame

	# Le harnais vérifie son propre contrat avant de conclure : une erreur de
	# script n'échoue pas un test, seul un `_check` le fait.
	for m in ["_allumer", "_eteindre", "_fermer_sec", "_ouvrir_sec",
			"_panneau_ouvert", "_rideau_de", "_surfaces_de", "is_pause_menu_open"]:
		if not ui.has_method(m):
			_check("le harnais atteint %s()" % m, false)
			ui.queue_free()
			return

	var pause: Control = ui.pause_panel
	var menu: Control = ui.game_over_panel
	_check("les deux panneaux existent", pause != null and menu != null)
	if pause == null or menu == null:
		ui.queue_free()
		return

	# Le rideau et la colonne de cascade sont désignés à la construction : les
	# deviner casserait le jour où un conteneur s'intercale.
	_check("le menu a son rideau nommé", ui._rideau_de(menu) != null)
	_check("la pause a son rideau nommé", ui._rideau_de(pause) != null)
	_check("le menu a une colonne à rallumer", not ui._surfaces_de(menu).is_empty())
	_check("la pause a une colonne à rallumer", not ui._surfaces_de(pause).is_empty())

	ui._m10 = 1.0
	ui._allumer(pause, true)
	_check("allumer montre le panneau tout de suite", pause.visible)
	_check("et il compte comme ouvert", ui._panneau_ouvert(pause))

	ui._eteindre(pause, true)
	# LE contrat. `visible` ment pendant le fondu ; `_panneau_ouvert` dit vrai.
	_check("pendant le fondu, le panneau est encore visible", pause.visible)
	_check("mais il ne compte PLUS comme ouvert", not ui._panneau_ouvert(pause))
	_check("et la pause est donc déjà levée pour le jeu",
		not ui.is_pause_menu_open())

	# Rouvrir pendant le fondu doit reprendre la main proprement, sans laisser le
	# panneau dans les limbes.
	ui._allumer(pause, true)
	_check("rouvrir pendant le fondu rend le panneau ouvert",
		ui._panneau_ouvert(pause) and pause.visible)

	# Quoi qu'il arrive, tout se rallume : même discipline que l'encre.
	ui._eteindre(pause, true)
	ui._fermer_sec(pause)
	_check("une fermeture sèche referme vraiment", not pause.visible)
	_check("et vide l'état d'extinction", not ui._panneau_ouvert(pause))
	var rideau: ColorRect = ui._rideau_de(pause)
	_check("le rideau est rendu à son opacité de nuit",
		is_equal_approx(rideau.color.a, float(rideau.get_meta("alpha_nuit"))),
		"%.3f" % rideau.color.a)
	var noir := false
	var surfaces: Array = ui._surfaces_de(pause)
	for s2 in surfaces:
		if (s2 as Control).modulate != Color.WHITE:
			noir = true
	_check("et aucune surface ne reste dans le noir", not noir)

	# À zéro, le show/hide sec d'avant l'effet — pixel pour pixel.
	ui._m10 = 0.0
	ui._allumer(menu)
	_check("intensité nulle : le menu s'ouvre sec", menu.visible
		and ui._panneau_ouvert(menu))
	ui._eteindre(menu)
	_check("et se ferme sec, sans fondu ni délai",
		not menu.visible and not ui._panneau_ouvert(menu))

	ui.queue_free()
	await process_frame

## Une ligne d'`effect_policy` manquante donnerait un effet qu'on ne peut pas
## couper ; une ligne présente sans lecture donnerait un curseur qui ne pilote
## rien. Le second cas est le plus vicieux : il ressemble trait pour trait à un
## réglage qui marche.
func _test_lignes_de_politique() -> void:
	print("\n[Les réglages de la vitrine]")
	var attendues := ["cadran_titre", "remanence_curseur", "torche_menu",
		"regard_du_noir", "passant_vitre", "encre_coulee", "gravure_code",
		"depart_au_tir", "extinction_menu"]
	for cle in attendues:
		var ligne: Variant = EffectPolicy.EFFECTS.get(cle, null)
		if not ligne is Dictionary:
			_check("%s : ligne présente" % cle, false)
			continue
		var d: Dictionary = ligne
		# Plancher 0.0 sans discussion : ces effets n'apprennent rien sur
		# l'adversaire, ne se voient jamais en match, et n'existent que pour le
		# plaisir de qui les garde.
		_check("%s : confort, coupable à zéro" % cle,
			int(d["famille"]) == EffectPolicy.Family.CONFORT
			and is_zero_approx(float(d["plancher"]))
			and String(d["phrase"]) != "")
