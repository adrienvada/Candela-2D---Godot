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
	_test_le_voxel_descend_de_la_vitrine()
	_test_la_patine_ne_mange_pas_le_texte()
	_test_l_interrupteur_de_charte()
	_test_les_plaques_de_bloc()
	_test_les_plaques_sont_partagees()
	_test_l_habillage_va_jusqu_au_style()
	_test_les_surcouches_n_ont_pas_de_plaque()
	_test_la_matiere_est_posee()
	_test_le_voile_de_killcam_porte_son_crochet()
	_test_le_menu_est_empate()
	_test_les_fichiers_bascules_parlent_la_pate()
	_test_la_preparation_recopie_la_charte()
	_test_les_ressources_de_l_habillage()
	_test_les_portraits_de_classe(main)
	_test_le_hud_parle_la_pate()
	_test_la_killcam_porte_la_pate()
	_test_l_estampe_garde_sa_forme_et_change_de_matiere()
	_test_l_affiche_pose_son_illustration()

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
	var blocs := 0
	var rangees := 0
	var rangees_sans_verre := 0
	var pile: Array[Node] = [racine]
	while not pile.is_empty():
		var n: Node = pile.pop_back()
		if n is CanvasItem and (n as CanvasItem).material == pate:
			empatees += 1
			if n is Button and (n as Button).text != "":
				lettres_grainees += 1
		if n is Control:
			for style: String in MenuWidgets._STYLES_DE_PLAQUE:
				if (n as Control).has_theme_stylebox_override(style) \
						and (n as Control).get_theme_stylebox(style) is StyleBoxTexture:
					blocs += 1
					break
		if n is PanelContainer and String(n.name).begins_with(MenuGlass.PREFIXE_RANGEE):
			rangees += 1
			if (n as CanvasItem).material == null or (n as CanvasItem).material == pate:
				rangees_sans_verre += 1
		pile.append_array(n.get_children())
	# **La matière change de support avec l'habillage, l'exigence non.** En pâte,
	# elle est un grain posé par un matériau ; en voxel, elle est DANS la texture
	# de la plaque, et poser le grain par-dessus la mangerait. On compte donc les
	# plaques habillées, pas les plaques empâtées — sans quoi ce contrôle
	# rougirait précisément parce que l'habillage voxel marche.
	if C.voxel_actif():
		_check(blocs >= 8, "le menu n'est pas en blocs : %d plaques seulement" % blocs)
	else:
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
	# Étape 5 : la killcam.
	"cadre_photo.gd", "estampe_de_kill.gd",
	# Étape 6 : les fins et l'intro.
	"affiche_de_fin.gd", "carte_de_soiree.gd", "intro_planches.gd",
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
	"res://assets/ui/matiere/tampon_encre.png": Vector2i(1024, 340),
	"res://assets/ui/fin_victoire.jpg": Vector2i(1920, 1080),
	"res://assets/ui/fin_defaite.jpg": Vector2i(1920, 1080),
	"res://assets/ui/carte_soiree_fond.png": Vector2i(1080, 1350),
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


## Le HUD de match — étape 4 : il parle la pâte, et ses panneaux en portent la
## matière.
##
## ⚠️ **La plage relue d'`ui.gd` est bornée par des MARQUEURS, pas par des numéros
## de ligne** : de la classe `CircularCooldown` à `_build_status_bar`. Un numéro
## est un constat daté (piège déjà consigné) ; le fichier gagne des lignes à
## chaque étape, et un contrôle borné en dur relirait bientôt autre chose que le
## HUD. Même règle que `_test_les_fichiers_bascules_parlent_la_pate` : aucun neutre
## d'appareil, aucune couleur chiffrée ; `HALOGENE` reste permis, c'est la lumière
## (les curseurs, la jauge d'une réserve).
func _test_le_hud_parle_la_pate() -> void:
	var fa := FileAccess.open("res://ui.gd", FileAccess.READ)
	_check(fa != null, "ui.gd illisible")
	if fa == null:
		return
	var neutres := RegEx.new()
	neutres.compile("\\b(Charte|C)\\.(ACIER|SURFACE|LINE|DIM|BACKDROP)\\b")
	var chiffres := RegEx.new()
	chiffres.compile("\\bColor\\(\\s*[0-9.]")
	var dedans := false
	var vu_debut := false
	var vu_fin := false
	var n := 0
	while not fa.eof_reached():
		var ligne := fa.get_line()
		n += 1
		if ligne.begins_with("class CircularCooldown"):
			dedans = true
			vu_debut = true
		elif ligne.begins_with("func _build_status_bar"):
			dedans = false
			vu_fin = true
		if not dedans:
			continue
		var code := ligne
		var diese := ligne.find("#")
		if diese >= 0:
			code = ligne.substr(0, diese)
		if neutres.search(code) != null:
			_check(false, "ui.gd:%d (HUD) nomme encore un neutre d'appareil : %s" % [n, ligne.strip_edges()])
		if chiffres.search(code) != null:
			_check(false, "ui.gd:%d (HUD) écrit une couleur chiffrée : %s" % [n, ligne.strip_edges()])
	_check(vu_debut and vu_fin,
		"les marqueurs de la plage du HUD ont disparu d'ui.gd : le contrôle ne relit plus rien")

	# Les panneaux joueur et le chrono portent la matière de leur habillage : le
	# grain de la pâte, ou RIEN en voxel — la plaque du bloc porte la sienne dans
	# sa texture, et un grain par-dessus repeindrait aussi le liseré du joueur,
	# qui est une information.
	var pate := MenuWidgets.materiau_pate()
	var attendu: Material = null if C.voxel_actif() else pate
	for champ: String in ["p1_panel", "p2_panel"]:
		var panneau = _ui.get(champ)
		_check(panneau != null and (panneau as CanvasItem).material == attendu,
			"ui.%s ne porte pas la matière de son habillage" % champ)
	var chrono = _ui.get("time_label")
	var cartouche: Node = chrono
	while cartouche != null and not cartouche.get("is_center_panel"):
		cartouche = cartouche.get_parent()
	_check(cartouche != null and (cartouche as CanvasItem).material == attendu,
		"la cartouche du chrono ne porte pas la matière de son habillage")

	# ⚠️ **Et le HUD reste un DESSIN, pas une image de cadre.** `test_hud_style`
	# refuse une `StyleBoxTexture` sur les panneaux joueur depuis l'éradication de
	# `cadre_hud.png` ; l'habillage voxel dessine son bloc par `StyleBox.draw()`
	# et laisse le thème vide. Ce contrôle-ci fige l'accord entre les deux : si un
	# jour quelqu'un pose la plaque en override, les deux suites le diront.
	for champ: String in ["p1_panel", "p2_panel"]:
		var panneau = _ui.get(champ)
		if panneau != null:
			var boite = (panneau as Control).get_theme_stylebox("panel")
			_check(not (boite is StyleBoxTexture),
				"ui.%s a repris une image de cadre : %s" % [champ, boite])


## La killcam — étape 5 : le voile reçoit la pâte par son crochet, les bandes de
## format cinéma existent et restent cachées hors killcam, et le mot a quitté la
## frange bleu/ambre d'un moniteur vidéo.
func _test_la_killcam_porte_la_pate() -> void:
	var voile = _ui.get("killcam_overlay")
	_check(voile != null and voile.material != null, "le voile de killcam n'a pas de matériau")
	if voile != null and voile.material != null:
		var virage = voile.material.get_shader_parameter("virage")
		_check(virage is Vector4 and absf((virage as Vector4).w - C.PATE_VIRAGE_KILLCAM) < 0.001,
			"le voile de killcam ne reçoit pas le virage de la charte : %s" % str(virage))
		var trait_c = voile.material.get_shader_parameter("trait_couleur")
		_check(trait_c is Vector3 and absf((trait_c as Vector3).x - C.PAPIER.r) < 0.001,
			"le trait du voile n'est pas passé au papier : %s" % str(trait_c))
	var bandes = _ui.get("killcam_bandes")
	_check(bandes != null and (bandes as Control).get_child_count() == 2,
		"les bandes de format cinéma de la killcam n'existent pas")
	if bandes != null:
		_check(not (bandes as Control).visible, "les bandes de killcam sont visibles hors killcam")
		# ⚠️ **« Sous le HUD », pas « premier enfant »** : `_build_menu()` passe après
		# `_build_killcam()` et place la torche du menu en tête du calque, si bien que
		# les bandes n'y sont plus premières. La propriété qui compte est leur rang
		# par rapport au HUD — le premier jet de ce contrôle exigeait l'index 0 et
		# aurait échoué sans défaut.
		var hud = _ui.get("match_hud")
		_check(hud != null and (bandes as Node).get_index() < (hud as Node).get_index(),
			"les bandes de killcam passent PAR-DESSUS le HUD de match")
	for champ: String in ["killcam_label_shadow1", "killcam_label_shadow2"]:
		var l = _ui.get(champ)
		if l != null:
			var c: Color = (l as Label).get_theme_color("font_color")
			_check(not c.is_equal_approx(Color(C.BLEU, 0.5)) and not c.is_equal_approx(Color(C.AMBRE, 0.5)),
				"ui.%s porte encore la frange d'un moniteur vidéo : %s" % [champ, c])
	var mot = _ui.get("killcam_label")
	_check(mot != null and (mot as CanvasItem).material == MenuWidgets.materiau_pochoir(),
		"le mot KILLCAM ne porte pas le pochoir")


## L'estampe de kill — étape 5 : sa FORME est celle qu'Adrien a jugée (le texte, la
## place au centre, l'inclinaison), sa MATIÈRE change (pochoir, cadre d'encre).
func _test_l_estampe_garde_sa_forme_et_change_de_matiere() -> void:
	var estampe := EstampeDeKill.poser(root, {"temps": 72.0})
	var tampon: Label = null
	for n in estampe.find_children("*", "Label", true, false):
		if (n as Label).text.begins_with("KILL"):
			tampon = n
	_check(tampon != null, "l'estampe n'a plus son tampon « KILL — mm:ss »")
	if tampon != null:
		_check(tampon.text == "KILL — 01:12", "le texte du tampon a changé : %s" % tampon.text)
		_check(is_equal_approx(tampon.rotation, EstampeDeKill.INCLINAISON),
			"l'inclinaison du tampon a changé")
		_check(tampon.material == MenuWidgets.materiau_pochoir(), "le tampon ne porte pas le pochoir")
		var cadre := tampon.get_node_or_null("CadreDeTampon") as TextureRect
		_check(cadre != null and cadre.texture != null, "le tampon n'a pas son cadre d'encre")
		if cadre != null:
			_check(cadre.show_behind_parent, "le cadre du tampon est dessiné PAR-DESSUS le mot")
			_check(cadre.self_modulate.is_equal_approx(C.CARMIN), "le cadre du tampon n'est pas carmin")
	estampe.free()


## L'affiche de fin — étape 6 : l'illustration suit le mot LU, retournée, et
## l'égalité garde son noir.
func _test_l_affiche_pose_son_illustration() -> void:
	var cas := [
		[{"vainqueur": 0, "local_idx": 0}, AfficheDeFin.FIN_VICTOIRE],
		[{"vainqueur": 1, "local_idx": 0}, AfficheDeFin.FIN_DEFAITE],
		[{"vainqueur": 0, "local_idx": -1}, AfficheDeFin.FIN_VICTOIRE],
		[{"vainqueur": -1}, ""],
	]
	for c: Array in cas:
		var affiche := AfficheDeFin.poser(root, c[0])
		var ill := affiche.find_child("Illustration", true, false) as TextureRect
		if String(c[1]) == "":
			_check(ill == null, "l'égalité ne doit pas porter d'illustration")
		else:
			_check(ill != null and ill.texture == load(String(c[1])),
				"l'affiche (%s) ne pose pas %s" % [str(c[0]), c[1]])
			if ill != null:
				_check(ill.flip_h, "l'illustration de fin n'est pas retournée : le mot tomberait sur la lumière")
		affiche.free()


## La luma perceptuelle sur les valeurs sRGB TELLES QUELLES — la formule avec
## laquelle le rapport 2,46 a été relevé sur la vitrine (Rec. 709 appliqué aux
## octets de l'image, sans linéarisation).
##
## ⚠️ **Distincte de `_lum`, et les deux doivent le rester.** `_lum` linéarise
## parce que les seuils de lecture l'exigent ; celle-ci ne linéarise pas parce
## que la mesure d'origine ne l'a pas fait. Les confondre donnerait 4,9 au lieu
## de 2,46 — un rapport juste qu'on rougirait, ou un faux qu'on laisserait passer.
static func _luma_srgb(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## Le voxel tient-il de la vitrine, ou d'un goût ?
##
## Chaque constante de la famille est soit la mesure elle-même, soit une dérivée
## que ce contrôle REFAIT. Sans lui, les littéraux de `charte.gd` seraient des
## affirmations : ils disent « lerp(ENCRE, PAPIER, 0.41) » en toutes lettres, et
## rien n'obligerait ce commentaire à rester vrai après une retouche à l'œil.
func _test_le_voxel_descend_de_la_vitrine() -> void:
	for d: Array in [[C.VOXEL_FLANC, 0.11, "VOXEL_FLANC"], [C.VOXEL_DESSUS, 0.41, "VOXEL_DESSUS"]]:
		var attendu: Color = C.ENCRE.lerp(C.PAPIER, d[1])
		_check(_ecart(d[0], attendu) < 0.0005,
			"%s n'est plus lerp(ENCRE, PAPIER, %.2f) : %s contre %s" % [d[2], d[1], d[0], attendu])

	# Le rapport RELEVÉ sur le cube de la vitrine, recalculé sur les constantes.
	var rapport := _luma_srgb(C.VOXEL_DESSUS) / _luma_srgb(C.VOXEL_FLANC)
	_check(absf(rapport - C.VOXEL_RAPPORT_ECLAIRE) <= 0.05,
		"le dessus n'éclaire plus le flanc dans le rapport mesuré : %.2f contre %.2f"
		% [rapport, C.VOXEL_RAPPORT_ECLAIRE])

	# Une plaque ne porte qu'UNE couleur : son flanc doit tomber du dessus par un
	# simple facteur, sinon la texture devrait porter deux teintes et la matière
	# cesserait d'être un facteur de la lumière.
	var flanc_calcule := Color(C.VOXEL_DESSUS.r * C.VOXEL_FACTEUR_FLANC,
		C.VOXEL_DESSUS.g * C.VOXEL_FACTEUR_FLANC, C.VOXEL_DESSUS.b * C.VOXEL_FACTEUR_FLANC)
	_check(_ecart(flanc_calcule, C.VOXEL_FLANC) < 0.004,
		"le flanc n'est plus le dessus × %.2f : %s contre %s"
		% [C.VOXEL_FACTEUR_FLANC, flanc_calcule, C.VOXEL_FLANC])

	# Les deux parts du rôle, et leur ordre. Une plaque éclairée doit porter la
	# couleur de sa lumière, pas une teinte de celle-ci : c'est ce qui sépare
	# « choisi » de « posé là », et c'est l'ajustement demandé le 2026-09-23.
	_check(C.VOXEL_TEINTE_ROLE_ALLUME > C.VOXEL_TEINTE_ROLE * 2.0,
		"la part du rôle sous lumière n'est plus franchement supérieure à celle de l'ombre : %.2f contre %.2f"
		% [C.VOXEL_TEINTE_ROLE_ALLUME, C.VOXEL_TEINTE_ROLE])
	_check(C.VOXEL_TEINTE_ROLE_ALLUME < 1.0,
		"la part du rôle sous lumière atteint 1,00 : l'encre ne tient plus 4,5:1 sur un bloc éclairé en ROUGE")

	var arete := Color(C.VOXEL_FLANC.r * C.VOXEL_ARETE_RESTE,
		C.VOXEL_FLANC.g * C.VOXEL_ARETE_RESTE, C.VOXEL_FLANC.b * C.VOXEL_ARETE_RESTE)
	_check(_ecart(C.VOXEL_ARETE, arete) < 0.0005,
		"VOXEL_ARETE n'est plus le flanc × %.2f : %s contre %s"
		% [C.VOXEL_ARETE_RESTE, C.VOXEL_ARETE, arete])

	# ⚠️ Le doublon assumé avec le jeu : `charte.gd` recopie `ENCRE_ARETE_RESTE`
	# plutôt que de charger les textures du duel pour le lire. Un doublon qu'on
	# accepte est un doublon qu'on surveille.
	var iso: Script = load("res://iso_materiaux.gd") as Script
	_check(iso != null, "iso_materiaux.gd ne se charge pas — l'arête du jeu n'est plus comparée")
	if iso != null:
		var reste: float = iso.get_script_constant_map().get("ENCRE_ARETE_RESTE", -1.0)
		_check(absf(reste - C.VOXEL_ARETE_RESTE) < 0.0001,
			"l'encre de l'interface a divergé de celle du jeu : %.3f contre %.3f"
			% [C.VOXEL_ARETE_RESTE, reste])

	# Les règles dures de la charte, et la bande de teinte PROPRE au voxel : la
	# rouille de l'ombre est plus rouge (19°) que le papier de la lumière (30°),
	# donc la bande 20-40° de la pâte ne peut pas s'y appliquer telle quelle.
	var famille := {"ROUILLE": C.ROUILLE, "VOXEL_FLANC": C.VOXEL_FLANC, "VOXEL_DESSUS": C.VOXEL_DESSUS}
	for nom: String in famille.keys():
		var c: Color = famille[nom]
		_check(c.s <= 0.7501, "%s dépasse le plafond de saturation : %.3f" % [nom, c.s])
		for canal: float in [c.r, c.g, c.b]:
			_check(canal > 0.0 and canal < 1.0, "%s porte une valeur pure : %s" % [nom, c])
		var teinte := c.h * 360.0
		# ⚠️ La bande monte à 34° et non à 32, et le surplus n'est pas du jeu : un
		# `lerp` RGB entre deux couleurs à 30° ne rend pas 30°. `VOXEL_DESSUS`
		# ressort à 32,8° — mesuré, pas choisi. La borne basse, elle, est celle de
		# la rouille de la vitrine (19°).
		_check(teinte >= 18.0 and teinte <= 34.0,
			"%s sort des teintes relevées sur la vitrine (18-34°) : %.1f°" % [nom, teinte])

	# Les rôles : la plaque est sa face du dessus, l'enfoncée est son propre flanc.
	_check(_ecart(C.VOXEL_PLAQUE, Color(C.VOXEL_DESSUS, 0.94)) < 0.0005,
		"VOXEL_PLAQUE n'est plus le dessus à 94 %% : %s" % C.VOXEL_PLAQUE)
	_check(_ecart(C.VOXEL_ENFONCE, Color(C.VOXEL_FLANC, 0.94)) < 0.0005,
		"VOXEL_ENFONCE n'est plus le flanc à 94 %% : %s" % C.VOXEL_ENFONCE)
	_check(_ecart(C.VOXEL_ALLUME, C.PATE_SURVOL) < 0.0005,
		"la plaque allumée a quitté le survol de la pâte : le contraste du texte survolé n'est plus celui vérifié")

	# Les deux tailles que `charte.gd` annonce comme REPRISES d'ailleurs. Une
	# valeur qu'on dit héritée et qui ne l'est plus est un commentaire qui ment.
	_check(C.VOXEL_ARETE_PX == MenuWidgets.BORDER_WIDTH_CONTROL,
		"l'arête du bloc ne vaut plus la bordure des contrôles : %d contre %d"
		% [C.VOXEL_ARETE_PX, MenuWidgets.BORDER_WIDTH_CONTROL])
	var chute := int(MenuWidgets.SHADOW_OFFSET_BUTTON.y - MenuWidgets.SHADOW_OFFSET_PRESSED.y)
	_check(C.VOXEL_ENFONCEMENT_PX == chute,
		"l'enfoncement ne vaut plus la chute d'ombre d'un bouton : %d contre %d"
		% [C.VOXEL_ENFONCEMENT_PX, chute])


## Ce que la plaque peut se permettre de patine, et pourquoi il y a un plafond.
##
## La rouille mesurée est CLAIRE (luma 76) à côté du flanc (35) : une tache de
## patine remonte la luminance locale, donc RAPPROCHE la plaque du papier écrit
## dessus. Le seuil n'est donc pas un goût, c'est la limite où le texte cesse de
## se lire — et `tools/fabrique_bloc_ui.py` la fait respecter pixel par pixel.
func _test_la_patine_ne_mange_pas_le_texte() -> void:
	var plafond := (_lum(C.PAPIER) + 0.05) / 4.5 - 0.05
	_check(absf(C.VOXEL_PATINE_LUM_MAX - plafond) < 0.0005,
		"le plafond de patine n'est plus celui du seuil 4,5:1 : %.4f contre %.4f"
		% [C.VOXEL_PATINE_LUM_MAX, plafond])
	_check(_lum(C.VOXEL_FLANC) < C.VOXEL_PATINE_LUM_MAX,
		"la plaque au repos dépasse déjà le plafond de patine : il ne resterait rien à tacher")
	_check(_lum(C.ROUILLE) > C.VOXEL_PATINE_LUM_MAX,
		"la rouille ne dépasse plus le plafond : il ne protège plus de rien, ou la mesure a changé")
	_check(_contraste(C.PAPIER, C.VOXEL_FLANC) >= 7.0,
		"le texte courant ne tient plus 7:1 sur une plaque au repos : %.2f:1"
		% _contraste(C.PAPIER, C.VOXEL_FLANC))


## L'interrupteur répond-il, et répond-il la bonne chose quand on lui ment ?
func _test_l_interrupteur_de_charte() -> void:
	var cas := [
		[PackedStringArray(), C.HABILLAGE_VOXEL, "sans drapeau, l'habillage de la branche"],
		[PackedStringArray(["--charte=voxel"]), C.HABILLAGE_VOXEL, "--charte=voxel"],
		[PackedStringArray(["--charte=pate"]), C.HABILLAGE_PATE, "--charte=pate"],
		[PackedStringArray(["--iso", "--charte=pate", "--zoom=1.5"]), C.HABILLAGE_PATE,
			"--charte=pate au milieu d'autres drapeaux"],
		[PackedStringArray(["--charte=voxal"]), C.HABILLAGE_VOXEL, "une valeur inconnue"],
		[PackedStringArray(["--charte"]), C.HABILLAGE_VOXEL, "le drapeau sans sa valeur"],
	]
	for c: Array in cas:
		var lu: String = C.habillage_par_argument(c[0])
		_check(lu == c[1], "%s donne « %s » au lieu de « %s »" % [c[2], lu, c[1]])
	_check(C.habillage() == C.HABILLAGE_VOXEL or C.habillage() == C.HABILLAGE_PATE,
		"l'habillage en vigueur n'est ni voxel ni pâte : « %s »" % C.habillage())
	_check(C.voxel_actif() == (C.habillage() == C.HABILLAGE_VOXEL),
		"voxel_actif() ne dit plus la même chose que habillage()")


## Les quatre plaques : le fichier, sa taille, et ce qu'on lit dessus.
##
## ⚠️ **C'est le contrôle qui vaut, parce qu'il MESURE l'image livrée.** Tout le
## reste de la famille voxel vérifie des constantes entre elles — un accord des
## chiffres, qui resterait vert si `tools/fabrique_bloc_ui.py` écrivait du noir.
## Celui-ci ouvre les PNG, lit leur corps au pixel, le compose avec la couleur que
## l'habillage lui donnera, et exige les seuils de lecture sur le résultat.
func _test_les_plaques_de_bloc() -> void:
	var etats := {
		C.CHEMIN_VOXEL_PLAQUE: "au repos",
		C.CHEMIN_VOXEL_PLAQUE_ALLUMEE: "allumée",
		C.CHEMIN_VOXEL_PLAQUE_ENFONCEE: "enfoncée",
		C.CHEMIN_VOXEL_PLAQUE_RENTREE: "rentrée",
		C.CHEMIN_VOXEL_PLAQUE_EFFLEUREE: "effleurée",
	}
	var largeur := C.VOXEL_FLANC_PX * 2 + C.VOXEL_TUILE_PX
	var hauteur := C.VOXEL_DESSUS_PX + C.VOXEL_TUILE_PX + C.VOXEL_BAS_PX
	for chemin: String in etats.keys():
		var nom: String = etats[chemin]
		_check(ResourceLoader.exists(chemin), "la plaque %s n'existe pas : %s" % [nom, chemin])
		var tex := load(chemin) as Texture2D
		_check(tex != null, "la plaque %s ne se charge pas (cache d'import construit ?)" % nom)
		if tex == null:
			continue
		# La taille n'est pas décorative : les neuf tranches sont posées en dur
		# depuis la charte (`texture_margin_*`). Une image d'une autre taille
		# étirerait le centre au lieu de le répéter, sans une erreur.
		_check(tex.get_width() == largeur and tex.get_height() == hauteur,
			"la plaque %s fait %d×%d au lieu de %d×%d — les neuf tranches ne tomberaient plus juste"
			% [nom, tex.get_width(), tex.get_height(), largeur, hauteur])

	# Le corps d'une plaque, lu au centre de l'image : c'est le facteur que la
	# matière applique là où le texte se pose.
	var corps_repos := _facteur_au_centre(C.CHEMIN_VOXEL_PLAQUE)
	var corps_allume := _facteur_au_centre(C.CHEMIN_VOXEL_PLAQUE_ALLUMEE)
	_check(corps_repos != Color.BLACK, "la plaque au repos est NOIRE en son centre — matière perdue")
	if corps_repos == Color.BLACK or corps_allume == Color.BLACK:
		return

	# Le texte courant sur une plaque au repos, et le texte sombre sur une plaque
	# allumée : les deux sens de lecture de l'habillage, mesurés sur l'image.
	var au_repos := _composer(corps_repos, C.VOXEL_PLAQUE)
	var allumee := _composer(corps_allume, C.VOXEL_ALLUME)
	var r1 := _contraste(C.PATE_TEXTE, au_repos)
	_check(r1 >= 4.5, "le texte courant ne tient pas sur une plaque au repos : %.2f:1" % r1)
	var r2 := _contraste(C.PATE_TEXTE_SUR_PAPIER, allumee)
	_check(r2 >= 4.5, "le texte d'une plaque allumée ne tient pas : %.2f:1" % r2)

	# ⚠️ **Le texte SECONDAIRE est le plus exposé, et ce banc ne le regardait pas.**
	# Il vérifiait le texte courant, qui a de la marge ; le béton clair, lui, est
	# réglé au plus juste (4,8:1 sur l'aplat d'encre), et c'est lui qui est passé
	# sous le seuil quand la plaque a changé de clarté — 3,59:1 mesuré sur une
	# capture, pendant que tous les contrôles restaient verts.
	# ⚠️ La valeur VOXEL est lue en direct, et non par `MenuWidgets.texte_second()`
	# qui suit l'habillage actif : sans cela, ce banc rougirait sur un dépôt sain
	# lancé avec `--charte=pate`. Un contrôle ne doit pas dépendre du drapeau sous
	# lequel on l'exécute pour dire vrai.
	var r3 := _contraste(C.VOXEL_TEXTE_SECOND, au_repos)
	_check(r3 >= 4.5,
		"le texte secondaire ne tient plus sur le corps d'une plaque au repos : %.2f:1" % r3)

	# **Chaque rôle doit rester lisible**, et c'est là que la teinte de rôle peut
	# faire une faute silencieuse : un bloc éclairé en bleu est plus clair qu'un
	# bloc neutre, donc plus près du papier écrit dessus.
	var roles := [[C.BLEU, "joueur 1"], [C.ROUGE, "joueur 2"], [C.AMBRE, "le filament"],
		[C.ETAT_OK, "ce qui est prêt"], [C.ETAT_FAUTE, "ce qui a échoué"]]
	for r: Array in roles:
		var teinte: Color = MenuWidgets.teinte_de_bloc(r[0], MenuWidgets.Bloc.REPOS)
		var plaque := _composer(corps_repos, teinte)
		var ratio := _contraste(C.PATE_TEXTE, plaque)
		_check(ratio >= 4.5,
			"le texte courant ne tient plus sur une plaque à l'ombre teintée par %s : %.2f:1" % [r[1], ratio])

	# **Un rôle ÉCRIT sur une plaque de son propre rôle** : le cas le plus serré
	# du dépôt, parce que la teinte de la plaque et la couleur du texte se
	# rapprochent. C'est lui qui a montré que `ROUGE`, couleur sombre, ne tenait
	# plus sur le plâtre — 5,37:1 sur l'aplat d'encre, 4,20:1 sur un bloc.
	for r: Array in roles:
		var teinte: Color = MenuWidgets.teinte_de_bloc(r[0], MenuWidgets.Bloc.REPOS)
		var plaque := _composer(corps_repos, teinte)
		var ratio := _contraste(r[0].lerp(C.HALOGENE, C.VOXEL_TEXTE_ROLE_HALO), plaque)
		_check(ratio >= 4.5,
			"le libellé de %s ne tient plus sur sa propre plaque : %.2f:1" % [r[1], ratio])

	# ⚠️ **Et sur une plaque ÉCLAIRÉE, c'est l'encre qui doit tenir**, parce que
	# c'est elle qu'on y écrit. Ce contrôle est le garde-fou de la part de rôle
	# portée à 0,80 : à 1,00, le bloc éclairé en ROUGE tombe à 4,40:1 et ce
	# contrôle rougit. Il dit donc exactement ce que coûterait un rouge plus franc.
	for r: Array in roles:
		var teinte: Color = MenuWidgets.teinte_de_bloc(r[0], MenuWidgets.Bloc.ALLUME)
		var plaque := _composer(corps_allume, teinte)
		var ratio := _contraste(C.PATE_TEXTE_SUR_PAPIER, plaque)
		_check(ratio >= 4.5,
			"l'encre ne tient plus sur une plaque éclairée par %s : %.2f:1" % [r[1], ratio])

	# L'ÉCART entre le repos et le survol, mesuré sur la face du dessus — la seule
	# qui bouge pour les surfaces dont le libellé ne peut pas changer de couleur.
	# Seuil 3:1, celui des états d'interface. Demandé par la session cloud le
	# 2026-09-23 : « garantis un changement visible, mesure-le et donne-moi l'écart ».
	var dessus_repos := _composer(_facteur_du_dessus(C.CHEMIN_VOXEL_PLAQUE), C.VOXEL_PLAQUE)
	var dessus_effleure := _composer(_facteur_du_dessus(C.CHEMIN_VOXEL_PLAQUE_EFFLEUREE),
		C.VOXEL_ALLUME)
	var ecart := _contraste(dessus_repos, dessus_effleure)
	_check(ecart >= 3.0,
		"le survol ne se voit plus sur la face du dessus : %.2f:1 pour 3:1 exigés" % ecart)
	print("    · écart repos → survol sur la face du dessus : %.2f:1" % ecart)


## Le facteur de matière sur la FACE DU DESSUS d'une plaque — la bande du haut,
## sous l'arête. C'est elle qui porte l'état d'une surface dont le libellé ne
## change pas de couleur, donc c'est sur elle que l'écart se mesure.
func _facteur_du_dessus(chemin: String) -> Color:
	var img := _image_de_plaque(chemin)
	if img == null:
		return Color.BLACK
	return img.get_pixel(img.get_width() / 2, C.VOXEL_ARETE_PX + 2)


## Le facteur de matière au centre d'une plaque, lu dans le fichier.
##
## Rend `Color.BLACK` si l'image ne peut pas être lue — un cas qu'il faut
## distinguer d'une plaque noire, d'où le contrôle qui suit chaque appel.
func _facteur_au_centre(chemin: String) -> Color:
	var img := _image_de_plaque(chemin)
	if img == null:
		return Color.BLACK
	return img.get_pixel(img.get_width() / 2, img.get_height() / 2)


## L'image d'une plaque, prête à être lue au pixel.
func _image_de_plaque(chemin: String) -> Image:
	var tex := load(chemin) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		# ⚠️ Une texture compressée ne se lit pas au pixel. On la décompresse
		# plutôt que de rendre une valeur fausse en silence.
		if img.decompress() != OK:
			return null
	return img


## La plaque telle qu'elle s'affiche : le facteur de la texture multiplié par la
## teinte, le tout composé sur le noir de la vue (la plaque est translucide).
func _composer(facteur: Color, teinte: Color) -> Color:
	var r := facteur.r * teinte.r
	var g := facteur.g * teinte.g
	var b := facteur.b * teinte.b
	return Color(r * teinte.a, g * teinte.a, b * teinte.a)


## Une plaque est-elle bien UNE texture partagée ?
##
## ⚠️ **C'est la condition du « aucun coût par image notable ».** Deux boutons
## dont les plaques sont deux instances de la même image sont dessinés en deux
## lots ; le menu en compte des dizaines. La texture doit donc être chargée une
## fois et rendue telle quelle — et c'est justement ce qu'un cache mal écrit
## perd sans que rien ne le dise.
func _test_les_plaques_sont_partagees() -> void:
	for etat: int in [MenuWidgets.Bloc.REPOS, MenuWidgets.Bloc.ALLUME,
			MenuWidgets.Bloc.ENFONCE, MenuWidgets.Bloc.RENTRE, MenuWidgets.Bloc.EFFLEURE]:
		var a := MenuWidgets.plaque(etat)
		var b := MenuWidgets.plaque(etat)
		_check(a != null and a == b,
			"la plaque de l'état %d n'est pas partagée : chaque bouton ferait son propre lot" % etat)
	var styles: Array[StyleBoxTexture] = [
		MenuWidgets.style_de_bloc(C.BLEU, MenuWidgets.Bloc.REPOS),
		MenuWidgets.style_de_bloc(C.ROUGE, MenuWidgets.Bloc.REPOS),
	]
	_check(styles[0].texture == styles[1].texture,
		"deux plaques de rôles différents ne partagent plus leur texture — la couleur doit venir de la teinte, pas d'une image par rôle")


## L'interrupteur tient-il jusqu'au bout de la chaîne ?
##
## La charte peut dire « voxel » et les styles rendre des aplats : entre les deux
## il y a `Charte.voxel_actif()`, lu dans trois fabriques. Ce contrôle part du
## style rendu et remonte — le sens dans lequel un joueur le verrait.
func _test_l_habillage_va_jusqu_au_style() -> void:
	var attendu_bloc := C.voxel_actif()
	var panneau := MenuWidgets.make_panel_style()
	_check((panneau is StyleBoxTexture) == attendu_bloc,
		"le panneau ne suit pas l'habillage : %s pour un habillage « %s »"
		% [panneau.get_class(), C.habillage()])
	var modale := MenuWidgets.make_modal_style()
	_check((modale is StyleBoxTexture) == attendu_bloc,
		"la modale ne suit pas l'habillage : %s" % modale.get_class())
	var bouton := MenuWidgets.make_button("ESSAI")
	var repos := bouton.get_theme_stylebox("normal")
	_check((repos is StyleBoxTexture) == attendu_bloc,
		"le bouton ne suit pas l'habillage : %s" % repos.get_class())

	if attendu_bloc:
		# Le geste du bloc : le libellé DESCEND quand la plaque s'enfonce.
		var enfonce := bouton.get_theme_stylebox("pressed")
		var descente := enfonce.content_margin_top - repos.content_margin_top
		_check(is_equal_approx(descente, float(C.VOXEL_ENFONCEMENT_PX)),
			"le libellé ne descend pas de l'enfoncement : %.1f px pour %d attendus"
			% [descente, C.VOXEL_ENFONCEMENT_PX])
		_check(enfonce.texture != repos.texture,
			"le bouton enfoncé porte la même plaque qu'au repos : l'enfoncement ne se verrait pas")
	bouton.queue_free()


## Les fichiers des SURCOUCHES : killcam, affiches de fin, carte de soirée.
##
## Aucun ne construit de plaque, et c'est la réponse de l'étape 5 : il n'y a rien
## à rendre voxel là-dedans. Une killcam est un voile, des bandes, un mot tamponné
## et un cadre dessiné ; une affiche est une illustration sous un titre. Ce sont
## des IMAGES, pas des objets d'interface.
const FICHIERS_SANS_PLAQUE := [
	"affiche_de_fin.gd", "estampe_de_kill.gd", "panneau_de_soiree.gd",
	"carte_de_soiree.gd", "cadre_photo.gd",
]


## Le constat de l'étape 5, figé pour qu'il ne se perde pas.
##
## ⚠️ **Un contrôle qui dit « rien à faire » vaut mieux qu'un silence.** Sans
## lui, le jour où quelqu'un pose un panneau dans la killcam ou sur une affiche
## de fin, personne ne saura que ces écrans avaient été regardés et laissés tels
## quels : la plaque naîtra en aplat d'encre au milieu d'une interface en blocs,
## et on ne le verra qu'en capture, des semaines plus tard. Ici, elle rougit tout
## de suite — avec ce qu'il faut faire : une plaque d'interface est un bloc
## (`MenuWidgets.style_de_bloc`), ou elle n'est pas une plaque.
func _test_les_surcouches_n_ont_pas_de_plaque() -> void:
	for nom: String in FICHIERS_SANS_PLAQUE:
		var chemin := "res://%s" % nom
		var fa := FileAccess.open(chemin, FileAccess.READ)
		_check(fa != null, "%s illisible" % nom)
		if fa == null:
			continue
		var n := 0
		while not fa.eof_reached():
			var ligne := fa.get_line()
			n += 1
			var code := ligne
			var diese := ligne.find("#")
			if diese >= 0:
				code = ligne.substr(0, diese)
			if code.contains("StyleBoxFlat") or code.contains("make_panel_style"):
				_check(false, "%s:%d pose une plaque d'aplat dans une surcouche — "
					% [nom, n] + "elle doit être un bloc (MenuWidgets.style_de_bloc) : %s"
					% ligne.strip_edges())
