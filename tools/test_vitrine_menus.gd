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

## Budget d'attente d'une animation, en millisecondes.
##
## **On attend une CONDITION, jamais un nombre d'images.** Une boucle de quarante
## `process_frame` mesure la machine, pas le code : en headless la cadence n'est
## pas plafonnée, et quarante images valent une demi-seconde sur un poste calme
## comme quarante millisecondes juste après vingt-trois autres lancements. Cette
## suite a passé au vert seule et rouge dans le lot pour cette seule raison, le
## 2026-08-18 — la même famille de défaut que le tampon de killcam dimensionné en
## images.
const BUDGET_MS := 4000

func _init() -> void:
	print("=== Test de la vitrine des menus (vague M) ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_test_encre_repos()
	_test_encre_progression()
	_test_encre_restaure_toujours()
	_test_encre_depart()
	_test_encre_respecte_le_grisage()
	_test_tracante()
	_test_gravure()
	_test_fond()
	_test_titre()
	_test_voile()
	await _test_squelettes()
	await _test_verre()
	await _test_extinction()
	await _test_extinction_lisible()
	await _test_calibration()
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

## L'encre rend ce qu'elle a emprunté, PAS une valeur choisie d'avance.
##
## `modulate` ne lui appartient pas : une entrée « PRÊT » grisée faute d'un second
## joueur est peinte à alpha 0,45 par le même canal. L'encre qui rallumerait tout
## à 1,0 rendrait ce bouton pleinement lumineux alors qu'il reste `disabled` — un
## contrôle qui a l'air disponible et ne répond pas, c'est-à-dire exactement ce
## que le contrat « grisées, jamais masquées » veut éviter.
func _test_encre_respecte_le_grisage() -> void:
	print("\n[Ce que l'encre n'a pas le droit de rallumer]")
	var encre := MenuInk.new()
	root.add_child(encre)
	var col := _colonne(3)
	# La deuxième entrée est grisée, comme « PRÊT » quand il manque un joueur.
	var grisee := col.get_child(1) as Control
	grisee.modulate = Color(1.0, 1.0, 1.0, 0.45)
	encre.set_intensite(1.0)

	encre.couler(col, 0.0, Color.WHITE)
	encre._arreter()
	_check("une entrée grisée reste grisée après la coulée",
		is_equal_approx(grisee.modulate.a, 0.45), "%.2f" % grisee.modulate.a)
	_check("et les autres sont bien rendues pleines",
		is_equal_approx((col.get_child(0) as Control).modulate.a, 1.0))

	# Et par le chemin de l'extinction, qui est celui où le joueur baisse le
	# curseur pendant que l'écran s'écrit.
	encre.couler(col, 0.0, Color.WHITE)
	encre.set_intensite(0.0)
	_check("l'extinction en pleine coulée rend aussi le grisage",
		is_equal_approx(grisee.modulate.a, 0.45), "%.2f" % grisee.modulate.a)

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

	# La mesure remontée au parent. Sans elle, un `Control` nu rend une taille
	# minimale nulle et le bouton COPIER se pose PAR-DESSUS le code — c'est le
	# défaut qu'Adrien a vu à l'écran le 2026-08-18, sur les deux rangées.
	g.set_code("AB3D9F")
	_check("le bloc réserve sa place dans la rangée",
		g.get_combined_minimum_size().x > 0.0 and g.get_combined_minimum_size().y > 0.0,
		str(g.get_combined_minimum_size()))

	g.set_intensite(0.0)
	g.set_code("ZZZZZZ")
	_check("à intensité nulle le code est posé sans cérémonie",
		g.code() == "ZZZZZZ" and not g.is_processing(), g.code())

	g.free()

	# Mesure libre : l'adresse IP n'a pas de longueur connue d'avance, et un point
	# d'IPv4 dans une case de chiffre laisserait un trou visible.
	var ip := MenuEngraver.new(0, 20, Color.WHITE)
	root.add_child(ip)
	ip.set_intensite(1.0)
	ip.set_code("10.193.192.235")
	_check("l'adresse est gravée telle quelle", ip.code() == "10.193.192.235",
		ip.code())
	var cases_ip: Node = ip.get_node_or_null(^"Cases")
	# Quatorze caractères, plus la coche de copie.
	_check("une case par caractère, ni plus ni moins",
		cases_ip != null and cases_ip.get_child_count() == 15,
		str(cases_ip.get_child_count()) if cases_ip != null else "pas de boîte")
	_check("et elle réserve sa place elle aussi",
		ip.get_combined_minimum_size().x > 0.0)
	# Une adresse plus courte doit RENDRE les cases en trop : sinon le bloc
	# garderait à jamais la largeur de la plus longue jamais affichée.
	ip.set_code("10.0.0.7")
	_check("une adresse plus courte rend ses cases",
		cases_ip.get_child_count() == 9, str(cases_ip.get_child_count()))
	ip.free()

## M11 — le titre incandescent.
func _test_titre() -> void:
	print("\n[Le titre incandescent]")
	var t := MenuTitle.new()
	root.add_child(t)
	var lbl := Label.new()
	lbl.text = "CANDELA 2D"
	lbl.size = Vector2(420, 70)
	root.add_child(lbl)

	t.adopter(lbl)
	_check("le titre reçoit le matériau", lbl.material is ShaderMaterial)
	var mat: ShaderMaterial = lbl.material
	_check("et c'est bien le shader du titre", mat.shader == MenuTitle.SHADER)
	# La largeur est ce que le shader ne peut pas connaître : sans elle, l'onde se
	# replierait au milieu du mot.
	_check("la largeur du bloc lui est donnée",
		is_equal_approx(float(mat.get_shader_parameter("largeur")), 420.0),
		str(mat.get_shader_parameter("largeur")))
	lbl.size = Vector2(700, 70)
	t._mesurer()
	_check("et elle suit le redimensionnement",
		is_equal_approx(float(mat.get_shader_parameter("largeur")), 700.0))

	t.set_intensite(1.0)
	t.embraser()
	_check("l'embrasement part de la braise",
		float(mat.get_shader_parameter("embrasement")) < 0.05,
		str(mat.get_shader_parameter("embrasement")))
	_check("avec son dépassement",
		float(mat.get_shader_parameter("depassement")) > 0.0)

	# Le verdict : la victoire flambe, la défaite tombe de moitié. C'est le même
	# shader qui signe l'écran de fin, sans qu'un contrôle bouge.
	t.verdict(false)
	_check("une défaite divise l'onde par deux",
		is_equal_approx(float(mat.get_shader_parameter("amplitude")),
			MenuTitle.AMPLITUDE_DEFAITE),
		str(mat.get_shader_parameter("amplitude")))
	_check("et ne flambe pour personne",
		is_zero_approx(float(mat.get_shader_parameter("flambee"))))
	t.verdict(true)
	_check("une victoire rend son amplitude pleine",
		is_equal_approx(float(mat.get_shader_parameter("amplitude")), 1.0))

	# Un verdict ne doit pas colorer l'ouverture suivante : on rouvre le menu
	# après un match perdu, et le titre repart neuf.
	t.verdict(false)
	t.embraser()
	_check("rouvrir le menu efface le verdict précédent",
		is_equal_approx(float(mat.get_shader_parameter("amplitude")), 1.0)
		and is_zero_approx(float(mat.get_shader_parameter("flambee"))))

	t.set_intensite(0.0)
	_check("à zéro, le titre est rendu tel quel",
		is_zero_approx(float(mat.get_shader_parameter("intensite")))
		and is_equal_approx(float(mat.get_shader_parameter("embrasement")), 1.0))

	lbl.free()
	t.free()

## M15 — le voile d'objectif.
func _test_voile() -> void:
	print("\n[Le voile d'objectif]")
	# Le voile s'ancre en plein cadre : sa taille lui vient de son parent, jamais
	# d'une valeur posée à la main. On lui en donne donc un.
	var cadre := Control.new()
	cadre.size = Vector2(1600, 900)
	root.add_child(cadre)
	var v := MenuVeil.new()
	cadre.add_child(v)
	var mat: ShaderMaterial = v.material
	_check("le voile porte son shader",
		mat != null and mat.shader == MenuVeil.SHADER)
	v._mesurer()
	# La frange se mesure en PIXELS : sans la taille réelle, elle vaudrait un
	# pixel et demi d'une image imaginaire, donc rien de constant à l'écran.
	_check("il connaît la taille réelle du cadre",
		(mat.get_shader_parameter("taille") as Vector2) == v.size,
		"%s contre %s" % [mat.get_shader_parameter("taille"), v.size])
	_check("et cette taille est bien celle du parent",
		v.size == cadre.size, "%s contre %s" % [v.size, cadre.size])

	v.set_intensite(1.0)
	_check("allumé, il est dessiné", v.visible)
	# À zéro il relirait l'écran pour le rendre identique : une copie d'écran et
	# trois lectures pour rien. On le retire du dessin.
	v.set_intensite(0.0)
	_check("éteint, il n'est plus dessiné du tout", not v.visible)

	cadre.free()

## M13 — les squelettes de lumière.
func _test_squelettes() -> void:
	print("\n[Les squelettes de lumière]")
	var cadre := Control.new()
	cadre.size = Vector2(800, 400)
	root.add_child(cadre)
	var k := MenuSkeleton.new()
	cadre.add_child(k)
	await process_frame

	var mat: ShaderMaterial = k.material
	_check("le squelette porte son shader",
		mat != null and mat.shader == MenuSkeleton.SHADER)
	# `top_level` : les conteneurs de Godot sautent leurs enfants top-level, donc
	# le squelette se pose dans la colonne du tableau sans y prendre de place.
	_check("il ne prend aucune place dans son conteneur", k.top_level)
	# Jamais dans le parcours du curseur : ce sont des barres, pas des contrôles.
	_check("et jamais dans le parcours du curseur",
		k.focus_mode == Control.FOCUS_NONE
		and k.mouse_filter == Control.MOUSE_FILTER_IGNORE)

	var lignes: Array = []
	for i in 4:
		var cellules: Array = []
		for j in 3:
			var c := Control.new()
			c.position = Vector2(j * 120, i * 30)
			c.size = Vector2(100, 24)
			cadre.add_child(c)
			cellules.append(c)
		lignes.append(cellules)
	k.suivre(lignes)
	k.set_intensite(1.0)

	k.attendre()
	_check("en attente, les barres sont là", k.visible)
	_check("et la torche balaie",
		is_equal_approx(float(mat.get_shader_parameter("balayage")), 1.0))

	# L'absence n'est pas une panne : un tableau qui continuerait à faire semblant
	# de chercher ce qu'il ne trouvera pas mentirait sur son état.
	k.figer()
	_check("après un échec, les barres restent", k.visible)
	_check("mais la torche s'éteint",
		is_zero_approx(float(mat.get_shader_parameter("balayage"))))

	# Le fondu part de la première ligne : à mi-parcours, la première a plus
	# disparu que la dernière.
	k.attendre()
	k._poser_revelation(0.5)
	_check("les lignes s'effacent l'une après l'autre",
		k._opacite(0) < k._opacite(3),
		"%.2f contre %.2f" % [k._opacite(0), k._opacite(3)])
	k._poser_revelation(1.0)
	_check("à la fin, plus une seule barre",
		is_zero_approx(k._opacite(0)) and is_zero_approx(k._opacite(3)))

	k.taire()
	_check("se taire referme tout", not k.visible)

	# À zéro, l'écran d'avant l'effet : ni barres, ni balayage.
	k.attendre()
	k.set_intensite(0.0)
	k.attendre()
	_check("intensité nulle : rien n'est montré", not k.visible)

	cadre.free()

## M14 — le verre fumé, et surtout ce qu'il ne vitre PAS.
func _test_verre() -> void:
	print("\n[Le verre fumé]")
	var g := MenuGlass.new()
	root.add_child(g)

	var cadre := PanelContainer.new()
	cadre.size = Vector2(500, 600)
	root.add_child(cadre)
	g.vitrer(cadre)
	var mat: ShaderMaterial = cadre.material
	_check("la surface reçoit le matériau",
		mat != null and mat.shader == MenuGlass.SHADER)
	_check("avec sa taille", (mat.get_shader_parameter("taille") as Vector2) == cadre.size,
		str(mat.get_shader_parameter("taille")))
	# Une surface vitrée deux fois aurait deux matériaux, donc deux tailles à
	# tenir d'accord, et un seul des deux serait mis à jour.
	g.vitrer(cadre)
	_check("vitrer deux fois ne change rien", cadre.material == mat)

	# Le focus d'une rangée vient du CURSEUR qu'elle contient : elle-même n'est
	# pas focalisable. Le brancher à la main sur chaque écran aurait fini par
	# manquer sur le prochain.
	var rangee := PanelContainer.new()
	rangee.name = "Row_essai"
	var boite := VBoxContainer.new()
	rangee.add_child(boite)
	var curseur := HSlider.new()
	boite.add_child(curseur)
	var muette := PanelContainer.new()
	muette.name = "Ligne_1"
	var arbre := VBoxContainer.new()
	arbre.add_child(rangee)
	arbre.add_child(muette)
	root.add_child(arbre)

	g.vitrer_rangees(arbre)
	_check("une rangée de réglage est vitrée", rangee.material is ShaderMaterial)
	# LE point de l'effet : un effet de matière se pose sur ce qu'on MANIPULE,
	# pas sur ce qu'on LIT. Une ligne de classement porte des données, et une
	# luisance sur un chiffre est un coût de lisibilité pour un gain décoratif.
	_check("une ligne de données ne l'est pas", muette.material == null)

	var mr: ShaderMaterial = rangee.material
	_check("au repos, aucune lueur d'arête",
		is_zero_approx(float(mr.get_shader_parameter("focus"))))
	curseur.focus_entered.emit()
	_check("le focus du curseur allume l'arête de sa rangée",
		is_equal_approx(float(mr.get_shader_parameter("focus")), 1.0))
	curseur.focus_exited.emit()
	_check("et la rend au repos en sortant",
		is_zero_approx(float(mr.get_shader_parameter("focus"))))

	g.set_intensite(0.0)
	_check("à zéro, toutes les surfaces sont rendues telles quelles",
		is_zero_approx(float(mat.get_shader_parameter("intensite")))
		and is_zero_approx(float(mr.get_shader_parameter("intensite"))))

	cadre.free()
	arbre.free()
	g.free()

## Les deux instants où M10 passait pour un défaut d'affichage.
##
## Relevé par Adrien à l'usage : « on pourrait croire à des bugs d'affichage ».
## Ce n'était pas une impression, c'étaient deux trous de calibrage, et ils se
## disent tous les deux comme un invariant :
##
## 1. **Aucune surface éclairée tant que l'arène se voit encore.** Les surfaces
##    partent en silhouettes noires ; tant que le rideau n'est pas tombé, ce sont
##    des blocs noirs posés sur une partie en cours — ça ne ressemble à rien
##    d'autre qu'à un panneau qui a raté son dessin.
## 2. **Jamais un écran entièrement noir à la fermeture.** Si les surfaces
##    finissaient de se noyer avant que le rideau commence à se lever, il
##    resterait un trou noir entre les deux mondes, et ce trou se lit comme une
##    image perdue.
func _test_extinction_lisible() -> void:
	print("\n[Ce qui faisait croire à un défaut]")
	var ui: Node = (load("res://ui.tscn") as PackedScene).instantiate()
	ui.name = "UI3"
	root.add_child(ui)
	await process_frame

	var menu: Control = ui.game_over_panel
	var rideau: ColorRect = ui._rideau_de(menu)
	var surfaces: Array = ui._surfaces_de(menu)
	if rideau == null or surfaces.is_empty():
		_check("le harnais tient le panneau", false)
		ui.queue_free()
		return
	var nuit := float(rideau.get_meta("alpha_nuit"))

	ui._allumer(menu)
	var trahison := 0.0
	var fin := Time.get_ticks_msec() + BUDGET_MS
	while Time.get_ticks_msec() < fin:
		var couverture := rideau.color.a / nuit
		var vive := 2.0
		for s in surfaces:
			var v: float = (s as Control).modulate.r
			# L'arène se voit encore tant que le rideau n'est pas majoritairement là.
			if couverture < 0.6:
				trahison = maxf(trahison, v)
			vive = minf(vive, v)
		if vive >= 0.99:
			break
		await process_frame
	_check("rien ne s'allume tant que l'arène se voit", is_zero_approx(trahison),
		"%.3f de luminance en trop" % trahison)
	var toutes := true
	for s in surfaces:
		if (s as Control).modulate.r < 0.99:
			toutes = false
	_check("et à la fin tout est rallumé", toutes)

	ui._eteindre(menu)
	var noir := 0
	fin = Time.get_ticks_msec() + BUDGET_MS
	while menu.visible and Time.get_ticks_msec() < fin:
		var couverture := rideau.color.a / nuit
		var vive := 0.0
		for s in surfaces:
			vive = maxf(vive, (s as Control).modulate.r)
		if couverture > 0.9 and vive < 0.02:
			noir += 1
		await process_frame
	_check("aucune image d'écran entièrement noir", noir == 0, "%d images" % noir)
	_check("et le panneau a fini par disparaître", not menu.visible)

	ui.queue_free()
	await process_frame

## M12 + M5 — la brume d'abysse et le bruit de l'œil, dans un seul matériau.
func _test_fond() -> void:
	print("\n[Le fond des menus]")
	var f := MenuBackdrop.new()
	root.add_child(f)
	var rect := ColorRect.new()
	root.add_child(rect)

	f.adopter(rect)
	_check("l'aplat reçoit le matériau", rect.material is ShaderMaterial)
	var mat: ShaderMaterial = rect.material
	_check("et c'est bien le shader de fond", mat.shader == MenuBackdrop.SHADER)

	f.set_brume(1.0)
	f.set_bruit(1.0)
	f.viser(0, Vector2(640, 360), 250.0, Vector2(1280, 720))
	var t1: Vector4 = mat.get_shader_parameter("torche_p1")
	_check("la torche est posée en UV", is_equal_approx(t1.x, 0.5)
		and is_equal_approx(t1.y, 0.5), str(t1))
	# Le rayon vit dans l'espace normalisé en HAUTEUR : c'est ce qui rend les
	# anneaux ronds quel que soit le format de la fenêtre.
	_check("et son rayon est normalisé sur la hauteur",
		is_equal_approx(t1.w, 250.0 / 720.0), str(t1.w))
	_check("le format est transmis",
		is_equal_approx(float(mat.get_shader_parameter("ratio")), 1280.0 / 720.0))

	# Le décor glisse à l'OPPOSÉ du curseur : dans le même sens, tout partirait
	# d'un bloc et le relief disparaîtrait.
	f.viser(0, Vector2(1280, 360), 250.0, Vector2(1280, 720))
	_check("un curseur à droite pousse le décor à gauche", f._cible.x < 0.0,
		str(f._cible))
	_check("et le rattrapage se met en marche", f.is_processing())

	# Coût nul au repos, la règle commune de la vitrine.
	var tours := 0
	while f.is_processing() and tours < 600:
		f._process(0.016)
		tours += 1
	_check("la parallaxe se pose et cesse de tourner", not f.is_processing(),
		"%d images" % tours)
	_check("posée exactement sur sa cible", f._parallaxe == f._cible)

	f.viser(0, null, 250.0, Vector2(1280, 720))
	var eteinte: Vector4 = mat.get_shader_parameter("torche_p1")
	_check("une torche éteinte a un rayon nul", is_zero_approx(eteinte.w))

	# À zéro, l'aplat statique d'avant l'effet — parallaxe comprise : c'est le
	# décor qui glissait, pas le panneau.
	f.viser(0, Vector2(1280, 360), 250.0, Vector2(1280, 720))
	f.set_brume(0.0)
	_check("brume à zéro : plus de parallaxe", f._parallaxe == Vector2.ZERO
		and not f.is_processing())
	_check("et le shader le sait",
		is_zero_approx(float(mat.get_shader_parameter("intensite_brume"))))

	rect.free()
	f.free()

## Le garde-fou de la calibration, et c'est le seul de la vitrine qui ne soit pas
## une question de goût.
##
## Le joueur y règle son point de noir sur un champ mesuré. Trois centièmes de
## luminance parasite décaleraient ce réglage — pour lui, et donc pour tous ceux
## qui calibrent de la même façon. Le garde-fou est au seul endroit par lequel
## passent les onze effets, plutôt que répété dans chacun, où il finirait par
## manquer au douzième.
func _test_calibration() -> void:
	print("\n[L'écran de mesure]")
	var ui: Node = (load("res://ui.tscn") as PackedScene).instantiate()
	ui.name = "UI2"
	root.add_child(ui)
	await process_frame

	if not ui.has_method("_intensite_vitrine"):
		_check("le harnais atteint _intensite_vitrine()", false)
		ui.queue_free()
		return

	var effets := ["cadran_titre", "remanence_curseur", "torche_menu",
		"regard_du_noir", "passant_vitre", "encre_coulee", "gravure_code",
		"depart_au_tir", "extinction_menu", "brume_menu", "bruit_de_l_oeil",
		"titre_vivant", "voile_menu", "balayage_attente", "verre_panneaux"]

	var hors_mesure := true
	for cle in effets:
		if float(ui._intensite_vitrine(cle)) <= 0.0:
			hors_mesure = false
	_check("hors calibration, les onze effets vivent", hors_mesure)

	# Le déclencheur a changé deux fois le 2026-08-18, et la seconde fois explique
	# pourquoi il est branché là. La calibration est d'abord devenue un PANNEAU du
	# cadre de droite ; un garde-fou branché sur l'écran courant ne se serait alors
	# plus levé du tout. Puis les quatre réglages d'affichage ont fusionné dans un
	# seul panneau, et le champ de mesure a cessé d'avoir une clé à lui.
	#
	# Le contrôle suit la cause réelle — **le champ de mesure est-il à l'écran** —
	# et non le nom de l'endroit où il se trouvait ce jour-là. C'est la seule
	# formulation qui ait survécu aux deux déplacements sans être réécrite.
	#
	# Ce qu'il protège ne se signale jamais quand il tombe : le champ resterait
	# grainé, embrumé et vignetté sans que rien paraisse anormal, et la mesure
	# serait fausse pour tous ceux qui calibrent de la même façon.
	ui.hub.show_detail("Affichage", "", ui.PANEL_DISPLAY)
	var eteints := true
	for cle in effets:
		if float(ui._intensite_vitrine(cle)) != 0.0:
			eteints = false
			_check("  %s éteint sur le champ de mesure" % cle, false)
	_check("sur la calibration, les onze s'éteignent", eteints)
	# Et pas seulement en théorie : les nœuds ont reçu l'ordre.
	_check("la torche est réellement coupée",
		is_zero_approx(float(ui.menu_torch.get("_intensite"))))
	_check("la brume aussi",
		is_zero_approx(float(ui.menu_backdrop.get("_brume"))))

	ui.hub.show_detail("Accueil", "")
	_check("en sortant, tout se rallume",
		float(ui._intensite_vitrine("torche_menu")) > 0.0
		and float(ui.menu_torch.get("_intensite")) > 0.0)

	ui.queue_free()
	await process_frame

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
	# **Les quinze, sans exception.** Cette liste a perdu quatre entrées le
	# 2026-08-18 en passant de main en main entre deux sessions, et rien ne l'a
	# signalé : un effet non listé ne fait pas échouer un test, il se contente de
	# ne plus être vérifié. D'où le contrôle de compte juste en dessous, qui lui
	# se plaint quand la liste décroche de la table.
	var attendues := ["cadran_titre", "remanence_curseur", "torche_menu",
		"regard_du_noir", "passant_vitre", "encre_coulee", "gravure_code",
		"depart_au_tir", "extinction_menu", "brume_menu", "bruit_de_l_oeil",
		"titre_vivant", "voile_menu", "balayage_attente", "verre_panneaux"]
	_check("la vitrine compte bien quinze effets", attendues.size() == 15,
		str(attendues.size()))
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
