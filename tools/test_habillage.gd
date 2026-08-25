## L'interface porte-t-elle vraiment la charte — ou seulement sa moitié ?
##
## **Ce banc naît d'un constat chiffré.** DA1.2 a livré deux fontes, leurs
## licences, l'axe variable et sa vérification. Six jours plus tard,
## `Charte.police_display()` n'était appelée que depuis **trois** sites, tous en
## espace-monde. Les 5 000 lignes de `ui.gd` — tous les menus, le HUD, la
## killcam, l'écran de fin — ne l'appelaient **jamais**. Le dépôt avait deux
## fontes et n'en portait qu'une, et rien ne le disait.
##
## `tools/test_charte.gd` ne pouvait pas l'attraper, et ce n'est pas un oubli de
## sa part : **il vérifie la charte, pas son emploi.** Il mesure que les chiffres
## d'Oxanium sont tabulaires, que l'axe de graisse agit, que l'échelle compte six
## crans. Toutes ces affirmations restent vraies dans un dépôt où plus personne
## n'appliquerait la charte à quoi que ce soit. Ce banc-ci mesure l'inverse : ce
## que les `Control` rendent réellement à l'écran.
##
## ## Les quatre contrôles, et pourquoi chacun est une MESURE
##
## 1. **Aucun compteur ne tremble.** Pour chaque étiquette qui se remplace sur
##    place — chrono, ping, timecode, recharge —, on mesure les dix chiffres dans
##    la fonte que le `Control` résout *effectivement*, et on exige la même
##    chasse. C'est le contrôle qui compte : `BigShouldersDisplay` fait `00:00` en
##    83 px et `11:11` en 49 à `T_VERDICT`. Un chrono qui passerait en enseigne
##    changerait de largeur à chaque seconde.
##
##    ⚠️ **Formulé sur la mesure, jamais sur le nom de la fonte.** « Le chrono
##    n'est pas en display » serait vrai aujourd'hui et vide demain — il suffirait
##    d'une troisième fonte pour que le contrôle passe au vert sur un défaut. Ce
##    qu'on interdit, c'est le tremblement, pas un fichier.
##
## 2. **Le bloc du code de salon ne bouge pas selon les lettres tirées.** La
##    promesse existait en commentaire depuis la vague M ; elle tenait par un
##    coefficient réglé sur Oxanium. Elle est maintenant vérifiée en gravant six
##    `W` puis six `J` et en comparant les deux largeurs.
##
## 3. **Le registre suit le gabarit.** Un code est une enseigne, une adresse IP
##    est de l'appareil, et c'est la forme du bloc qui tranche — pas l'appelant.
##
## 4. **La graisse agit, elle n'est pas seulement écrite.** Même famille de piège
##    que `TAG_WGHT` et que `tnum` : on pose quelque chose de correct, rien ne
##    proteste, et l'effet n'a pas lieu. Deux graisses doivent rendre deux
##    largeurs.
##
## Lancer : godot --headless --path . --script res://tools/test_habillage.gd
extends SceneTree

const C := preload("res://charte.gd")

## Les étiquettes qui se REMPLACENT SUR PLACE, par leur nom de champ dans `ui.gd`.
##
## Le critère d'entrée dans cette liste n'est pas « ça affiche un nombre » : les
## nombres de dégâts de `bullet.gd` sont en enseigne et ils y sont bien, parce
## qu'ils naissent, montent et meurent sans jamais se substituer l'un à l'autre
## dans la même boîte. Le critère est la substitution en place.
const COMPTEURS := [
	"time_label",       # le chrono de manche — celui qui bat à la seconde
	"ping_label",       # « ● 42 ms »
	"killcam_timecode", # le timecode de la killcam
	"p1_cd_label",      # « 0.4s » de recharge, deux fois par seconde
	"p2_cd_label",
	"fps_label",        # panneau F3 — la grille de diagnostic, DA4.16
	"dbg_ping",
	"dbg_lumieres",
	"dbg_particules",
	"dbg_noeuds",
	"dbg_cartes",
	"net_debug_label",
]

## Les étiquettes qui doivent porter l'ENSEIGNE — le versant positif de la règle.
##
## **Sans cette liste, le banc ne saurait qu'interdire.** Un dépôt qui n'emploie
## nulle part la fonte d'affichage passe tous les contrôles de tremblement : c'est
## exactement l'état dans lequel le projet a vécu six jours après DA1.2, deux
## fontes livrées et une seule portée. Interdire le mauvais registre ne dit rien
## sur l'emploi du bon.
const ENSEIGNES := [
	"game_over_title",  # CANDELA 2D, OPTIONS, et les trois verdicts
	"countdown_label",  # 3 — 2 — 1
	"killcam_label",    # KILLCAM
]

var _ok := 0
var _ko := 0
var _ui: Node


func _check(condition: bool, quoi: String) -> void:
	if condition:
		_ok += 1
	else:
		_ko += 1
		printerr("  ✗ %s" % quoi)


## L'écart de chasse entre les dix chiffres, dans une fonte et une taille données.
## Zéro = tabulaire, donc rien ne peut trembler.
func _ecart_des_chiffres(f: Font, taille: int) -> float:
	var mini := INF
	var maxi := -INF
	for d in "0123456789":
		var l := f.get_string_size(d, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		mini = minf(mini, l)
		maxi = maxf(maxi, l)
	return maxi - mini


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== L'interface habillée ===")
	# Après une frame : les autoloads que `ui.gd` référence n'existent pas encore
	# au moment de `_init`, et la scène rendrait un nœud nu dont les erreurs
	# n'incrémentent aucun compteur. Motif repris de `test_audit_menus.gd`.
	await process_frame
	var scene: PackedScene = load("res://main.tscn")
	if scene == null:
		printerr("✗ main.tscn introuvable")
		quit(1)
		return
	var main: Node = scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_ui = main.get_node_or_null("UI")
	if _ui == null or not _ui.has_method("show_pick_window"):
		printerr("✗ l'interface n'a pas son script")
		quit(1)
		return

	_test_les_polices_sont_chargees()
	_test_aucun_compteur_ne_tremble()
	_test_les_enseignes_portent_l_enseigne()
	_test_le_code_ne_bouge_pas()
	_test_le_registre_suit_le_gabarit()
	_test_la_graisse_agit()
	_test_la_table_des_graisses()

	main.queue_free()
	if _ko == 0:
		print("✓ %d contrôles passent" % _ok)
		quit(0)
	else:
		printerr("✗ %d échecs sur %d contrôles" % [_ko, _ok + _ko])
		quit(1)


## ⚠️ **Sans ce garde-fou, tout le reste du banc passe au vert pour rien.**
##
## Une fonte absente rend `null`, aucun override n'est posé, et chaque `Control`
## retombe sur la fonte par défaut de Godot — qui est tabulaire. Les contrôles de
## tremblement passeraient donc **tous**, et le banc annoncerait que l'interface
## est habillée alors qu'elle est nue.
##
## Le cas n'est pas théorique : il s'est produit ici même. Un **worktree git neuf
## n'a pas de `.godot/imported/`**, si bien que `ResourceLoader.exists()` répond
## vrai et que `load()` échoue quand même. `test_charte` est passé au rouge pour
## cette seule raison, sans qu'une ligne de code soit en cause.
func _test_les_polices_sont_chargees() -> void:
	var manquantes := C.polices_manquantes()
	_check(manquantes.is_empty(),
		"fichiers de fonte absents : %s" % str(manquantes))
	_check(C.police_ui(C.POIDS_COURANT) != null,
		"la fonte d'interface se charge (cache d'import construit ?)")
	_check(C.police_display(C.POIDS_ENSEIGNE) != null,
		"la fonte d'enseigne se charge (cache d'import construit ?)")


## Le contrôle central : ce qui se remplace sur place ne change pas de largeur.
func _test_aucun_compteur_ne_tremble() -> void:
	var vus := 0
	for champ: String in COMPTEURS:
		var lbl := _ui.get(champ) as Control
		if lbl == null:
			# Un compteur disparu ne fait pas échouer le lot pour la mauvaise
			# raison : il fait perdre la couverture, ce qui est pire. On le dit.
			printerr("  ! compteur introuvable, plus surveillé : ui.%s" % champ)
			_ko += 1
			continue
		vus += 1
		var f := lbl.get_theme_font("font")
		var taille := lbl.get_theme_font_size("font_size")
		if f == null:
			_check(false, "ui.%s ne résout aucune fonte" % champ)
			continue
		var ecart := _ecart_des_chiffres(f, taille)
		_check(ecart < 0.01,
			"ui.%s tremble : %.1f px d'écart entre ses chiffres à %d px" % [
				champ, ecart, taille])
	_check(vus == COMPTEURS.size(), "tous les compteurs ont été mesurés")


## Le versant positif : les mots d'enseigne sont bien dans l'autre registre.
##
## ⚠️ **Formulé comme « ce n'est pas la fonte d'interface », et non comme « c'est
## BigShouldersDisplay ».** Nommer le fichier attendu rendrait le contrôle faux le
## jour où l'enseigne change — or c'est justement le jour où l'on a besoin qu'il
## tienne. Ce qu'on affirme, c'est que ces mots ne sont pas rendus dans la fonte
## de tout le reste ; c'est la propriété qui porte le sens.
##
## La comparaison se fait sur une **chasse mesurée** plutôt que sur l'identité des
## objets `Font` : deux `FontVariation` distinctes peuvent envelopper le même
## fichier, et l'égalité d'objets répondrait alors « différentes » sans que rien
## ne le soit à l'écran.
func _test_les_enseignes_portent_l_enseigne() -> void:
	var vus := 0
	for champ: String in ENSEIGNES:
		var lbl := _ui.get(champ) as Control
		if lbl == null:
			printerr("  ! enseigne introuvable, plus surveillée : ui.%s" % champ)
			_ko += 1
			continue
		vus += 1
		var f := lbl.get_theme_font("font")
		var taille := lbl.get_theme_font_size("font_size")
		if f == null:
			_check(false, "ui.%s ne résout aucune fonte" % champ)
			continue
		var ui_font := C.police_ui(C.graisse_pour(taille, C.Registre.APPAREIL))
		if ui_font == null:
			continue
		var mot := "VICTOIRE"
		var a := f.get_string_size(mot, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		var b := ui_font.get_string_size(mot, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		_check(absf(a - b) > 1.0,
			"ui.%s rend « %s » exactement comme la fonte d'interface (%.1f px) : elle n'est pas habillée" % [
				champ, mot, a])
	_check(vus == ENSEIGNES.size(), "toutes les enseignes ont été mesurées")


## DA4.9 — six `W` et six `J` occupent exactement la même place.
func _test_le_code_ne_bouge_pas() -> void:
	var g := MenuEngraver.new()
	root.add_child(g)

	# `W` est le glyphe le plus large de l'alphabet des codes, `J` l'un des plus
	# étroits. S'il existe une largeur qui bouge, c'est entre ces deux-là.
	g.set_code("WWWWWW")
	var large := g.get_combined_minimum_size()
	g.set_code("JJJJJJ")
	var etroit := g.get_combined_minimum_size()
	_check(absf(large.x - etroit.x) < 0.01,
		"le bloc du code change de largeur : %.1f px en W, %.1f px en J" % [
			large.x, etroit.x])
	_check(absf(large.y - etroit.y) < 0.01,
		"le bloc du code change de hauteur : %.1f px en W, %.1f px en J" % [
			large.y, etroit.y])

	# Et la case contient réellement son caractère : une case plus étroite que le
	# glyphe le rognerait, une case beaucoup plus large disloquerait le code.
	var f := g.police()
	if f != null:
		var taille := g._taille as int
		var w := f.get_string_size("W", HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		var case := large.x / float(LobbyCode.LENGTH + 1)
		_check(case >= w,
			"la case (%.1f px) est plus étroite que le W qu'elle contient (%.1f px)" % [
				case, w])

	g.queue_free()


## Un code est une enseigne, une adresse IP est de l'appareil, et c'est la FORME
## du bloc qui tranche — le gabarit fixe étant précisément ce qui rend une fonte
## non tabulaire inoffensive.
func _test_le_registre_suit_le_gabarit() -> void:
	var code := MenuEngraver.new()
	var adresse := MenuEngraver.new(0, C.T_APPUI, Charte.AMBRE)
	root.add_child(code)
	root.add_child(adresse)

	_check(code.registre() == C.Registre.ENSEIGNE,
		"le code de salon (gabarit fixe) doit être en registre enseigne")
	_check(adresse.registre() == C.Registre.APPAREIL,
		"l'adresse (mesure libre) doit être en registre appareil")

	# L'adresse est de l'appareil, donc ses chiffres ne peuvent pas trembler —
	# c'est la contrepartie de la mesure libre, qui n'a aucun gabarit pour la
	# protéger.
	var fa := adresse.police()
	if fa != null:
		_check(_ecart_des_chiffres(fa, C.T_APPUI) < 0.01,
			"l'adresse en mesure libre doit rester dans une fonte tabulaire")

	# Et les deux registres rendent bien deux fontes différentes, sans quoi la
	# distinction ne serait qu'un nom.
	var fc := code.police()
	if fc != null and fa != null:
		var a := fc.get_string_size("CANDELA", HORIZONTAL_ALIGNMENT_LEFT, -1, 42).x
		var b := fa.get_string_size("CANDELA", HORIZONTAL_ALIGNMENT_LEFT, -1, 42).x
		_check(absf(a - b) > 1.0,
			"les deux registres rendent la même chasse (%.1f px) : la distinction est vide" % a)

	code.queue_free()
	adresse.queue_free()


## Même famille de piège que `TAG_WGHT` : on pose quelque chose de correct, rien
## ne proteste, et l'effet n'a pas lieu. Seule une mesure distingue « la graisse
## est appliquée » de « la graisse est écrite ».
func _test_la_graisse_agit() -> void:
	var maigre := Label.new()
	var gras := Label.new()
	root.add_child(maigre)
	root.add_child(gras)
	C.enseigne(maigre, C.T_VERDICT, 200)
	C.enseigne(gras, C.T_VERDICT, 900)

	var fm := maigre.get_theme_font("font")
	var fg := gras.get_theme_font("font")
	if fm != null and fg != null:
		var a := fm.get_string_size("CANDELA", HORIZONTAL_ALIGNMENT_LEFT, -1, C.T_VERDICT).x
		var b := fg.get_string_size("CANDELA", HORIZONTAL_ALIGNMENT_LEFT, -1, C.T_VERDICT).x
		_check(b > a,
			"la graisse ne change pas la chasse : %.1f px en 200, %.1f px en 900" % [a, b])

	# La taille se pose, elle, même quand la fonte manque — c'est ce qui distingue
	# « la fonte manque » de « la mise en page a disparu ».
	_check(maigre.get_theme_font_size("font_size") == C.T_VERDICT,
		"habiller doit poser la taille demandée")

	maigre.queue_free()
	gras.queue_free()


## La graisse est une FORMULE, pas un choix au site d'appel — même discipline que
## les couleurs dérivées. Et chacun des quatre poids a un seul domicile : les
## deux premiers à l'appareil, les deux autres à l'enseigne. Un poids employé des
## deux côtés ne dirait plus rien de l'endroit où on le lit.
func _test_la_table_des_graisses() -> void:
	_check(C.graisse_pour(C.T_MENTION) == C.POIDS_COURANT,
		"une mention est en poids courant")
	_check(C.graisse_pour(C.T_COURANT) == C.POIDS_COURANT,
		"le texte courant est en poids courant")
	_check(C.graisse_pour(C.T_APPUI) == C.POIDS_APPUI,
		"une valeur d'appui monte en poids d'appui")
	_check(C.graisse_pour(C.T_TITRE) == C.POIDS_APPUI,
		"un titre d'écran monte en poids d'appui")
	# L'appareil PLAFONNE : le gras d'affiche appartient à l'enseigne.
	_check(C.graisse_pour(C.T_ENSEIGNE) == C.POIDS_APPUI,
		"l'appareil ne dépasse jamais le poids d'appui, même à la plus grande taille")

	_check(C.graisse_pour(C.T_TITRE, C.Registre.ENSEIGNE) == C.POIDS_DISPLAY,
		"une enseigne de petite taille est en poids display")
	_check(C.graisse_pour(C.T_VERDICT, C.Registre.ENSEIGNE) == C.POIDS_ENSEIGNE,
		"un verdict est en poids d'enseigne")
	_check(C.graisse_pour(C.T_DECOMPTE, C.Registre.ENSEIGNE) == C.POIDS_ENSEIGNE,
		"le décompte est en poids d'enseigne")

	# Chaque poids a un seul domicile : aucun ne doit être atteignable des deux
	# côtés, sinon le lire ne dit plus dans quel registre on est.
	var appareil := {}
	var enseigne := {}
	for t in [C.T_MENTION, C.T_COURANT, C.T_APPUI, C.T_TITRE, C.T_VERDICT,
			C.T_ENSEIGNE, C.T_DECOMPTE]:
		appareil[C.graisse_pour(t, C.Registre.APPAREIL)] = true
		enseigne[C.graisse_pour(t, C.Registre.ENSEIGNE)] = true
	for poids: int in appareil.keys():
		_check(not enseigne.has(poids),
			"le poids %d sert dans les deux registres : il ne dit plus lequel" % poids)
