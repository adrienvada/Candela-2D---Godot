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
	_test_la_pate_descend_de_deux_couleurs()
	_test_la_pate_se_lit()
	_test_la_matiere_est_posee()
	_test_le_voile_de_killcam_porte_son_crochet()
	_test_le_menu_est_empate()
	_test_les_fichiers_bascules_parlent_la_pate()
	_test_la_preparation_recopie_la_charte()
	_test_les_ressources_de_l_habillage()
	_test_les_portraits_de_classe(main)

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


# =============================================================================
# LA PÂTE — l'habillage iso (2026-09-15)
# =============================================================================
#
# La charte d'appareil disait « LED » ; les planches iso disent encre et papier.
# Ces contrôles tiennent la famille ajoutée à `charte.gd` à ce qu'elle affirme :
# deux couleurs mesurées et des dérivées qui en sont des FORMULES, une teinte
# chaude, et une lecture que les chiffres garantissent plutôt que l'œil.


## Écart maximal entre deux couleurs, sur les quatre canaux.
static func _ecart(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)),
		maxf(absf(a.b - b.b), absf(a.a - b.a)))


## Luminance relative au sens des contrastes de lecture (sRGB linéarisé).
static func _lum(c: Color) -> float:
	var canaux: Array[float] = []
	for v: float in [c.r, c.g, c.b]:
		canaux.append(v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * canaux[0] + 0.7152 * canaux[1] + 0.0722 * canaux[2]


static func _contraste(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## ⚠️ **Un fond translucide se lit sur ce qu'il recouvre.** Le fond de panneau est
## à 94 % ; mesuré seul, il vaudrait sa couleur pleine, et le contraste serait
## calculé sur un panneau qui n'existe pas à l'écran. Il recouvre le noir de la
## vue : c'est sur ce noir qu'on le compose.
static func _sur_le_noir(fond: Color) -> Color:
	return Color(fond.r * fond.a, fond.g * fond.a, fond.b * fond.a)


func _test_la_pate_descend_de_deux_couleurs() -> void:
	for d: Array in [[C.TERRE, 0.22, "TERRE"], [C.BETON, 0.50, "BETON"],
			[C.BETON_CLAIR, 0.65, "BETON_CLAIR"]]:
		var attendu: Color = C.ENCRE.lerp(C.PAPIER, d[1])
		_check(_ecart(d[0], attendu) < 0.0005,
			"%s n'est plus lerp(ENCRE, PAPIER, %.2f) : %s contre %s" % [d[2], d[1], d[0], attendu])
	_check(_ecart(C.PATE_FOND, Color(C.ENCRE, 0.94)) < 0.0005,
		"PATE_FOND n'est plus l'encre à 94 %% : %s" % C.PATE_FOND)
	var rideau := Color(C.ENCRE.r * 0.5, C.ENCRE.g * 0.5, C.ENCRE.b * 0.5, 0.96)
	_check(_ecart(C.PATE_RIDEAU, rideau) < 0.0005,
		"PATE_RIDEAU n'est plus ENCRE × 0,5 à 96 %% : %s contre %s" % [C.PATE_RIDEAU, rideau])

	# Les règles dures de la charte valent pour la pâte : saturation plafonnée,
	# aucune valeur pure. Et la sienne : la pâte est CHAUDE — c'est la mesure des
	# planches (teinte 26 à 32°), et c'est ce qui la sépare de l'appareil.
	var famille := {"ENCRE": C.ENCRE, "PAPIER": C.PAPIER, "TERRE": C.TERRE,
		"BETON": C.BETON, "BETON_CLAIR": C.BETON_CLAIR}
	for nom: String in famille.keys():
		var c: Color = famille[nom]
		_check(c.s <= 0.7501, "%s dépasse le plafond de saturation : %.3f" % [nom, c.s])
		for canal: float in [c.r, c.g, c.b]:
			_check(canal > 0.0 and canal < 1.0, "%s porte une valeur pure : %s" % [nom, c])
		var teinte := c.h * 360.0
		_check(teinte >= 20.0 and teinte <= 40.0,
			"%s n'est plus dans les teintes chaudes des planches (20-40°) : %.1f°" % [nom, teinte])


## Les seuils de lecture : 4,5:1 pour tout texte, 7:1 pour le texte courant, qui
## se lit longtemps. Mesurés : papier 9,9 ; béton clair 4,8 ; filament 10,1.
func _test_la_pate_se_lit() -> void:
	var fond := _sur_le_noir(C.PATE_FOND)
	var cas := [
		[C.PATE_TEXTE, fond, 7.0, "le texte courant sur un panneau"],
		[C.PATE_TEXTE_SECOND, fond, 4.5, "le texte secondaire sur un panneau"],
		[C.PATE_FILAMENT, fond, 4.5, "le filament sur un panneau"],
		[C.PATE_TEXTE_SUR_PAPIER, C.PATE_SURVOL, 7.0, "le texte d'une plaque survolée"],
		[C.PATE_TEXTE, _sur_le_noir(C.PATE_RIDEAU), 7.0, "le texte courant sur un rideau"],
	]
	for c: Array in cas:
		var r := _contraste(c[0], c[1])
		_check(r >= c[2], "%s ne se lit plus : %.2f:1 pour %.1f:1 exigés" % [c[3], r, c[2]])


## La matière est un fichier, un matériau et un paramètre : les trois doivent y
## être, et aucun des trois ne crie tout seul s'il manque.
func _test_la_matiere_est_posee() -> void:
	_check(ResourceLoader.exists(C.CHEMIN_PATE_GRAIN),
		"le grain de la pâte n'existe pas : %s" % C.CHEMIN_PATE_GRAIN)
	var tex := load(C.CHEMIN_PATE_GRAIN) as Texture2D
	_check(tex != null, "le grain de la pâte ne se charge pas (cache d'import construit ?)")
	if tex != null:
		_check(tex.get_width() == int(C.PATE_GRAIN_ECHELLE) and tex.get_height() == int(C.PATE_GRAIN_ECHELLE),
			"le grain n'a plus le côté de sa tuile : %d×%d pour %d" % [
				tex.get_width(), tex.get_height(), int(C.PATE_GRAIN_ECHELLE)])
		# Le shader AJOUTE (g − 0,5) : un grain décentré assombrirait ou
		# éclaircirait chaque panneau, uniformément et sans erreur.
		var img := tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			var somme := 0.0
			var n := 0
			for y in range(0, img.get_height(), 4):
				for x in range(0, img.get_width(), 4):
					somme += img.get_pixel(x, y).r
					n += 1
			var moyenne := somme / float(maxi(n, 1))
			_check(absf(moyenne - 0.5) < 0.02,
				"le grain n'est plus centré : moyenne %.3f pour 0,5" % moyenne)
	var m := MenuWidgets.materiau_pate()
	_check(m != null and m.shader != null, "le matériau de la pâte n'a pas son shader")
	if m != null:
		_check(m.get_shader_parameter("grain") != null,
			"le matériau de la pâte ne porte pas son grain : chaque panneau s'éclaircirait sans erreur")
		_check(MenuWidgets.materiau_pate() == m,
			"le matériau de la pâte n'est plus partagé : un matériau par panneau les sépare tous au dessin")


## Le crochet posé dans le voile de killcam, lu dans le TEXTE du shader.
##
## ⚠️ **Pas par `get_shader_uniform_list()`** : en headless, le serveur de rendu
## factice peut rendre une liste vide, et le contrôle échouerait pour une raison
## qui n'a rien à voir. Et `set_shader_parameter` sur un nom absent ne dit rien :
## sans ce contrôle, un uniform renommé laisserait `ui.gd` pousser dans le vide.
func _test_le_voile_de_killcam_porte_son_crochet() -> void:
	var sh := load("res://killcam_overlay.gdshader") as Shader
	_check(sh != null, "killcam_overlay.gdshader ne se charge pas")
	if sh == null:
		return
	var code := sh.code
	for decl: String in ["uniform vec3 trait_couleur", "uniform vec4 virage"]:
		var i := code.find(decl)
		_check(i >= 0, "le voile de killcam ne déclare plus « %s »" % decl)
		if i >= 0:
			var ligne := code.substr(i, code.find("\n", i) - i)
			_check(not ligne.contains("source_color"),
				"« %s » porte un hint source_color : sous gl_compatibility le défaut ne rendrait plus le même trait" % decl)
	_check(code.contains("uniform vec3 trait_couleur = vec3(0.98, 0.91, 0.80);"),
		"le trait par défaut n'est plus le littéral qu'il remplace : la killcam changerait sans qu'on le demande")
	_check(code.contains("uniform vec4 virage = vec4(0.0, 0.0, 0.0, 0.0);"),
		"le virage par défaut n'est plus éteint")
	# ⚠️ Visé sur le littéral du TRAIT, pas sur « mix(postere, vec3( » : la trame
	# d'encre juste au-dessus s'écrit `mix(postere, vec3(0.0), …)`, et le premier jet
	# de ce contrôle la prenait pour l'ancien trait — un échec qui accusait le crochet.
	_check(not code.contains("mix(postere, vec3(0.98"),
		"le trait lit encore un littéral au lieu de trait_couleur")


## Le passage d'empâtement a eu lieu sur le menu — et il n'a rien écrasé.
##
## ⚠️ **Les deux échecs possibles sont muets à l'écran**, et c'est pourquoi ils
## se comptent : un passage oublié laisse des panneaux lisses que seule une
## capture montre ; un passage fait AVANT le verre de M14 serait écrasé par lui,
## et un passage fait APRÈS sans garde éteindrait le verre — dans les deux cas
## sans une erreur, un nœud n'ayant qu'un matériau.
func _test_le_menu_est_empate() -> void:
	var pate := MenuWidgets.materiau_pate()
	var hub = _ui.get("hub")
	var racine = _ui.get("game_over_panel")
	_check(hub != null and racine != null, "ui.hub ou ui.game_over_panel introuvable")
	if hub == null or racine == null:
		return
	var empatees := 0
	var lettres_grainees := 0
	var rangees := 0
	var rangees_sans_verre := 0
	var pile: Array[Node] = [racine]
	while not pile.is_empty():
		var n: Node = pile.pop_back()
		if n is CanvasItem and (n as CanvasItem).material == pate:
			empatees += 1
			if n is Button and (n as Button).text != "":
				lettres_grainees += 1
		if n is PanelContainer and String(n.name).begins_with(MenuGlass.PREFIXE_RANGEE):
			rangees += 1
			if (n as CanvasItem).material == null or (n as CanvasItem).material == pate:
				rangees_sans_verre += 1
		pile.append_array(n.get_children())
	_check(empatees >= 8, "le menu n'est pas empâté : %d plaques seulement" % empatees)
	_check(lettres_grainees == 0,
		"%d boutons portent la pâte sur leur propre texte : le grain passe sur les lettres" % lettres_grainees)
	var droite: Control = hub.right_panel()
	_check(droite != null and droite.material != null and droite.material != pate,
		"le cadre de droite a perdu son verre (M14)")
	_check(rangees_sans_verre == 0,
		"%d rangées de réglage sur %d ont perdu leur verre (M14)" % [rangees_sans_verre, rangees])
	var pause = _ui.get("pause_panel")
	if pause != null:
		var n_pause := MenuWidgets.empater(pause)
		_check(n_pause == 0,
			"la pause avait encore %d plaques sans pâte après la construction" % n_pause)


## Les fichiers d'interface déjà basculés vers la pâte. La liste GRANDIT d'étape en
## étape (HUD, killcam, fins) : un fichier y entre quand il est repris, jamais
## avant — sinon le contrôle rougirait sur un travail pas encore fait.
const FICHIERS_PATE := [
	"menu_theme.gd", "menu_widgets.gd", "menu_hub.gd", "menu_recitatif.gd",
	"menu_comic_panel.gd", "menu_fiche_classe.gd", "map_gallery.gd",
	"map_editor_hud.gd", "menu_icones.gd", "menu_apercu.gd", "menu_hatch_rect.gd",
	"menu_rivets_overlay.gd",
]


## « Aucune couleur en dur hors `charte.gd` », vérifié en LISANT les fichiers.
##
## Deux interdits, et une permission :
## - les neutres d'APPAREIL (`ACIER`, `SURFACE`, `LINE`, `DIM`, `BACKDROP`) — froids,
##   et partagés avec le jeu : un fichier d'interface qui les nomme encore a
##   échappé à la bascule ;
## - tout littéral chiffré `Color(0…` — une couleur qui n'a pas de nom n'a pas de
##   formule, et c'est ainsi que le dépôt avait accumulé 220 `Color(...)`.
## - **permis** : `HALOGENE` et `AMBRE`, qui sont la LUMIÈRE et non un neutre (le
##   cône dessiné de la fiche, le cœur du filament), et `Color.WHITE`, qui n'est
##   pas une couleur mais une modulation neutre.
## Les commentaires sont exclus : ils nomment l'ancienne couleur pour dire
## pourquoi elle est partie.
func _test_les_fichiers_bascules_parlent_la_pate() -> void:
	var neutres := RegEx.new()
	neutres.compile("\\b(Charte|C)\\.(ACIER|SURFACE|LINE|DIM|BACKDROP)\\b")
	var chiffres := RegEx.new()
	chiffres.compile("\\bColor\\(\\s*[0-9.]")
	var lus := 0
	for f: String in FICHIERS_PATE:
		var fa := FileAccess.open("res://" + f, FileAccess.READ)
		if fa == null:
			_check(false, "fichier basculé illisible : %s" % f)
			continue
		lus += 1
		var n := 0
		while not fa.eof_reached():
			var ligne := fa.get_line()
			n += 1
			var code := ligne
			var diese := ligne.find("#")
			if diese >= 0:
				code = ligne.substr(0, diese)
			if neutres.search(code) != null:
				_check(false, "%s:%d nomme encore un neutre d'appareil : %s" % [f, n, ligne.strip_edges()])
			if chiffres.search(code) != null:
				_check(false, "%s:%d écrit une couleur chiffrée : %s" % [f, n, ligne.strip_edges()])
	_check(lus == FICHIERS_PATE.size(), "tous les fichiers basculés ont été lus")


## `tools/preparer_habillage.py` recopie l'encre, le béton et le papier pour le
## virage des portraits. Une copie est une vérité de plus : on la relit ici.
func _test_la_preparation_recopie_la_charte() -> void:
	var fa := FileAccess.open("res://tools/preparer_habillage.py", FileAccess.READ)
	_check(fa != null, "tools/preparer_habillage.py illisible")
	if fa == null:
		return
	var texte := fa.get_as_text()
	var attendus := {"ENCRE": C.ENCRE, "BETON": C.BETON, "PAPIER": C.PAPIER}
	for nom: String in attendus.keys():
		var re := RegEx.new()
		re.compile("(?m)^%s = \\(([0-9.]+), ([0-9.]+), ([0-9.]+)\\)" % nom)
		var m := re.search(texte)
		_check(m != null, "preparer_habillage.py ne déclare plus %s" % nom)
		if m == null:
			continue
		var c: Color = attendus[nom]
		var copie := Color(float(m.get_string(1)), float(m.get_string(2)), float(m.get_string(3)))
		_check(_ecart(Color(c, 1.0), copie) < 0.0005,
			"preparer_habillage.py a divergé de charte.gd sur %s : %s contre %s" % [nom, copie, c])


## Chaque ressource de l'habillage : présente, chargée, à sa taille, connue de git.
##
## ⚠️ **« Connue de git » n'est pas une coquetterie.** Une image posée dans le
## worktree et jamais ajoutée passe toutes les suites de la machine qui l'a
## fabriquée, puis manque partout ailleurs — et le repli de l'appelant la
## cacherait. `git ls-files --error-unmatch` le dit avant le commit.
const RESSOURCES_HABILLAGE := {
	"res://assets/ui/matiere/pate_grain.png": Vector2i(256, 256),
	"res://assets/ui/fond_hub_iso.jpg": Vector2i(1920, 1071),
}


func _test_les_ressources_de_l_habillage() -> void:
	var depot := ProjectSettings.globalize_path("res://")
	for chemin: String in RESSOURCES_HABILLAGE.keys():
		var tex := load(chemin) as Texture2D if ResourceLoader.exists(chemin) else null
		_check(tex != null, "ressource d'habillage absente ou non importée : %s" % chemin)
		if tex != null:
			var attendu: Vector2i = RESSOURCES_HABILLAGE[chemin]
			_check(Vector2i(tex.get_width(), tex.get_height()) == attendu,
				"%s n'a plus sa taille : %d×%d pour %s" % [chemin, tex.get_width(), tex.get_height(), attendu])
		var sortie: Array = []
		var code := OS.execute("git", ["-C", depot, "ls-files", "--error-unmatch",
			chemin.trim_prefix("res://")], sortie, true)
		_check(code == 0, "%s n'est pas connu de git : il manquerait sur toute autre machine" % chemin)
	# Et ce sont bien celles que le hub montre.
	_check(String(_ui.get("KEY_ART")) == "res://assets/ui/fond_hub_iso.jpg",
		"le fond du hub n'est plus le bunker iso : %s" % _ui.get("KEY_ART"))
	var ill: Dictionary = _ui.get("ILLUSTRATIONS")
	_check(ill != null and String(ill.get("ill_accueil", "")) == "res://assets/ui/fond_hub_iso.jpg",
		"l'illustration d'accueil n'est plus le bunker iso")
	_check(MenuArtwork.cle_canonique("res://assets/ui/fond_hub_iso.jpg") == "ill_accueil",
		"le bunker iso ne se rattache plus à la clé ill_accueil (POI et effet)")


## Les portraits iso — étape 3 : un par classe DU CATALOGUE, jamais d'une liste
## recopiée ici (une onzième classe sans portrait doit rougir, pas passer), à
## 256 px, connus de git ; et la fiche les montre à la place du sprite vu de dessus.
func _test_les_portraits_de_classe(main: Node) -> void:
	var catalogue: Array = main.call("classes") if main.has_method("classes") else []
	_check(catalogue.size() == int(_ui.get("NB_CLASSES")),
		"le catalogue des classes n'a pas été lu : %d classes" % catalogue.size())
	var depot := ProjectSettings.globalize_path("res://")
	for c in catalogue:
		var chemin := MenuFicheClasse.chemin_portrait(String(c.slug()))
		var tex := load(chemin) as Texture2D if ResourceLoader.exists(chemin) else null
		_check(tex != null, "portrait absent ou non importé : %s" % chemin)
		if tex != null:
			_check(tex.get_width() == 256 and tex.get_height() == 256,
				"%s n'a plus 256 px : %d×%d" % [chemin, tex.get_width(), tex.get_height()])
		var sortie: Array = []
		var code := OS.execute("git", ["-C", depot, "ls-files", "--error-unmatch",
			chemin.trim_prefix("res://")], sortie, true)
		_check(code == 0, "%s n'est pas connu de git" % chemin)
	if catalogue.is_empty():
		return
	var fiche := MenuFicheClasse.new()
	root.add_child(fiche)
	fiche.batir(Charte.BLEU)
	var premiere = catalogue[0]
	fiche.montrer(premiere, catalogue)
	var attendu := load(MenuFicheClasse.chemin_portrait(String(premiere.slug())))
	_check(fiche._portrait.texture == attendu,
		"la fiche ne montre pas le portrait iso de %s" % premiere.slug())
	fiche.queue_free()
