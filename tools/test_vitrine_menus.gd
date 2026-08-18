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

## Une ligne d'`effect_policy` manquante donnerait un effet qu'on ne peut pas
## couper ; une ligne présente sans lecture donnerait un curseur qui ne pilote
## rien. Le second cas est le plus vicieux : il ressemble trait pour trait à un
## réglage qui marche.
func _test_lignes_de_politique() -> void:
	print("\n[Les réglages de la vitrine]")
	var attendues := ["cadran_titre", "remanence_curseur", "torche_menu",
		"regard_du_noir", "passant_vitre", "encre_coulee", "gravure_code",
		"depart_au_tir"]
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
