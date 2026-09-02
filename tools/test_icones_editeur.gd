## Les icônes de l'éditeur sont-elles vraiment là — et disent-elles ce que leur
## bouton annonce ?
##
## **Ce banc naît de deux fautes commises le même jour, et la seconde explique
## pourquoi le premier contrôle est celui-là.**
##
## ## 1. Le repli silencieux cache l'absence qu'il est censé amortir
##
## `MenuIcones` est conçu pour se taire : une icône absente retombe sur le
## libellé texte, et l'écran reste utilisable. C'est juste. Mais ce jour-là, les
## quatorze icônes d'outils étaient **posées sur le disque, jamais importées par
## Godot** — `.godot/imported/` n'en contenait aucune. Le câblage était complet,
## chaque bouton appelait `poser_outil()`, chaque appel rendait `false`, et
## l'éditeur s'affichait exactement comme avant.
##
## **Un repli qui marche rend l'absence indistinguable de la présence.** C'est
## précisément pour ça qu'il faut un contrôle qui, lui, ne se replie pas : le
## premier de ce banc échoue si un seul fichier catalogué ne se charge pas.
##
## ## 2. Une icône peut contredire son bouton, et rien ne le dit
##
## Le fichier livré sous le nom `outil_miroir_d.png` portait l'axe **↗** —
## l'anti-diagonale. Câblé tel quel, le bouton « DIAGONALE ↘ » aurait montré la
## flèche inverse de ce qu'il fait. Le joueur aurait plié sa carte sur le mauvais
## axe et n'aurait eu aucun moyen de comprendre pourquoi.
##
## **Un glyphe faux se voit ; une image fausse se croit.** Personne ne relit une
## icône, on la reconnaît — et reconnaître, c'est justement cesser de regarder.
## Le fichier a été renommé `outil_miroir_ad.png`, et la diagonale est désormais
## son **reflet calculé**, ce qui fait de l'exactitude de la paire une propriété
## du code plutôt qu'un accord entre deux dessins.
##
## Ce banc mesure donc le reflet, pixel par pixel, dans les deux sens : il est
## bien le miroir (sinon la dérivation ne sert à rien), et il n'est **pas** la
## même image (sinon la dérivation a échoué en silence et les deux boutons
## voisins montrent le même dessin).
##
## ## 3. Aucune action ne tombe entre les listes
##
## Vingt-deux actions, quatorze icônes : huit boutons n'en ont pas. Ce n'est pas
## un défaut, c'est un état — mais il doit être **déclaré**. Le contrôle exige
## que chaque `ACTION_*` figure dans `PAR_OUTIL`, `REFLET_DE` ou `SANS_ICONE`.
## Ajouter un bouton demain sans trancher la question fera rougir ce banc, ce qui
## est exactement le moment où la question se pose le mieux.
##
## ## 4. Plus un pictogramme dans un libellé
##
## L'audit ne lit que les **chaînes littérales**, jamais les commentaires : ce
## fichier-ci en est plein, et les docstrings de `menu_icones.gd` citent les
## emojis qu'elles ont fait mourir. Un audit qui compterait les commentaires
## interdirait d'expliquer ce qu'on a corrigé.
##
## Les symboles conservés sont **nommés un par un** dans `TOLERES`. C'est la
## différence entre une règle et un filtre : réintroduire `⌗` demain demandera
## de l'écrire dans cette liste, donc de le décider.

extends SceneTree

const Icones := preload("res://menu_icones.gd")

var _ok := 0
var _ko := 0


func _check(condition: bool, quoi: String) -> void:
	if condition:
		_ok += 1
	else:
		_ko += 1
		printerr("  ✗ %s" % quoi)


# ---------------------------------------------------------------------------
# 1. TOUTES LES ICÔNES D'OUTIL SE CHARGENT VRAIMENT
# ---------------------------------------------------------------------------

func _test_les_icones_sont_cuites() -> void:
	var absentes: Array[String] = []
	for slug: String in Icones.PAR_OUTIL.keys():
		var tex: Texture2D = Icones.outil(slug)
		if tex == null:
			absentes.append("%s (%s)" % [slug, Icones.PAR_OUTIL[slug]])
	_check(absentes.is_empty(),
		"ces icônes d'outil ne se chargent pas — posées mais pas importées ? %s"
			% ", ".join(absentes))

	# ⚠️ Charger n'est pas afficher : une texture de 0×0 se charge sans erreur.
	for slug: String in Icones.PAR_OUTIL.keys():
		var tex: Texture2D = Icones.outil(slug)
		if tex == null:
			continue
		_check(tex.get_width() > 0 and tex.get_height() > 0,
			"l'icône « %s » se charge mais mesure %d×%d"
				% [slug, tex.get_width(), tex.get_height()])


# ---------------------------------------------------------------------------
# 2. LE REFLET EST BIEN LE MIROIR, ET N'EST PAS L'ORIGINAL
# ---------------------------------------------------------------------------

func _image_de(slug: String) -> Image:
	var tex: Texture2D = Icones.outil(slug)
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	img = img.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	return img


func _test_le_reflet_est_un_miroir() -> void:
	for derive: String in Icones.REFLET_DE.keys():
		var source := String(Icones.REFLET_DE[derive])
		var a := _image_de(source)
		var b := _image_de(derive)
		if a == null or b == null:
			_check(false, "le couple %s / %s ne se charge pas" % [derive, source])
			continue

		_check(a.get_size() == b.get_size(),
			"%s et son reflet %s n'ont pas la même taille" % [source, derive])
		if a.get_size() != b.get_size():
			continue

		var attendu := a.duplicate() as Image
		attendu.flip_x()
		var ecarts := 0
		var identiques := 0
		var l := a.get_width()
		var h := a.get_height()
		for y in h:
			for x in l:
				if not attendu.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
					ecarts += 1
				if a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
					identiques += 1

		_check(ecarts == 0,
			"%s n'est pas le miroir de %s : %d pixels sur %d divergent"
				% [derive, source, ecarts, l * h])

		# L'autre versant, et c'est lui qui attrape l'échec SILENCIEUX : si la
		# dérivation renvoyait la source sans la retourner, le contrôle ci-dessus
		# passerait au vert sur toute image symétrique — et les deux boutons
		# voisins montreraient le même dessin.
		_check(identiques < l * h,
			"%s est RIGOUREUSEMENT identique à %s : la dérivation n'a rien fait"
				% [derive, source])


# ---------------------------------------------------------------------------
# 3. AUCUNE ACTION N'EST ORPHELINE
# ---------------------------------------------------------------------------

## Les actions déclarées par le HUD, lues dans son source.
##
## ⚠️ **Lues dans le fichier, pas demandées à la classe.** Interroger
## `MapEditorHUD` sur ses constantes reviendrait à comparer une liste à
## elle-même : c'est le motif du banc décoratif, payé quatre fois dans ce dépôt.
## La source des actions doit être indépendante des trois listes qu'on vérifie.
func _actions_du_hud() -> Array[String]:
	var out: Array[String] = []
	var texte := FileAccess.get_file_as_string("res://map_editor_hud.gd")
	for ligne in texte.split("\n"):
		var l := ligne.strip_edges()
		if not l.begins_with("const ACTION_"):
			continue
		var debut := l.find("&\"")
		var fin := l.rfind("\"")
		if debut >= 0 and fin > debut + 2:
			out.append(l.substr(debut + 2, fin - debut - 2))
	return out


func _test_aucune_action_orpheline() -> void:
	var actions := _actions_du_hud()
	_check(actions.size() >= 20,
		"seulement %d actions relevées dans map_editor_hud.gd : la lecture a raté"
			% actions.size())

	var orphelines: Array[String] = []
	for a in actions:
		var connue := Icones.PAR_OUTIL.has(a) or Icones.REFLET_DE.has(a) \
			or Icones.SANS_ICONE.has(a) or Icones.ICONE_D_ETAT.has(a)
		if not connue:
			orphelines.append(a)
	_check(orphelines.is_empty(),
		"ces actions ne sont ni illustrées ni déclarées sans icône : %s"
			% ", ".join(orphelines))

	# ⚠️ **Une action « à icône d'état » doit prouver qu'elle en a.** Sans ce
	# contrôle, `ICONE_D_ETAT` deviendrait le tiroir où l'on range ce qu'on ne
	# veut pas illustrer : il suffirait d'y jeter un slug pour éteindre le
	# contrôle ci-dessus. On exige donc que les états que l'action peut montrer
	# soient catalogués, et que `map_editor.gd` les nomme réellement.
	var editeur := FileAccess.get_file_as_string("res://map_editor.gd")
	for slug: String in Icones.ICONE_D_ETAT:
		var etats: Array[String] = []
		for cle: String in Icones.PAR_OUTIL.keys():
			if editeur.contains("\"%s\"" % cle):
				etats.append(cle)
		_check(etats.size() >= 2,
			"« %s » est déclarée à icône d'état, mais map_editor.gd ne nomme que %d icône(s) : %s"
				% [slug, etats.size(), ", ".join(etats)])

	# Et l'inverse : une entrée qui ne désigne plus rien est un fichier qu'on
	# garde pour un bouton disparu.
	var fantomes: Array[String] = []
	for slug: String in Icones.SANS_ICONE:
		if not actions.has(slug):
			fantomes.append(slug)
	_check(fantomes.is_empty(),
		"SANS_ICONE nomme des actions qui n'existent plus : %s"
			% ", ".join(fantomes))


# ---------------------------------------------------------------------------
# 4. PLUS UN PICTOGRAMME DANS UN LIBELLÉ AFFICHÉ
# ---------------------------------------------------------------------------

## Les symboles que le projet a décidé de garder, et la raison de chacun.
const TOLERES := {
	"✓": "coche de validation, panneau de l'éditeur",
	"✗": "croix d'échec, panneau de l'éditeur et sortie des bancs",
	"●": "pastille d'état (mode test, ping)",
	"−": "moins arithmétique : réduire la grille",
	"→": "flèche de conséquence dans une phrase",
	"↔": "flèche de portée dans une phrase",
	"↘": "axe de la diagonale — repli texte du bouton",
	"↗": "axe de l'anti-diagonale — repli texte du bouton",
	"✕": "la touche ✕ de la manette, nommée telle qu'elle est gravée",
	"☐": "la touche ☐ de la manette, nommée telle qu'elle est gravée",
	"≥": "comparaison dans une phrase",
	"≤": "comparaison dans une phrase",
	"≈": "approximation dans une phrase",
	"⚠": "avertissement, jamais dans un libellé de bouton",
	"─": "filet de séparation en art ASCII",
	"√": "racine, dans une formule",
	"∈": "appartenance, dans une formule",
	"⇒": "implication, dans une formule",
	"✅": "coche de journal",
	"⇔": "équivalence, dans une formule",
}

## Les fichiers dont les chaînes s'affichent. `player.gd` et consorts sont hors
## périmètre pour la même raison que dans `test_charte.gd` : domaine game feel.
const ECRANS := ["map_editor_hud.gd", "map_editor.gd", "map_gallery.gd",
	"ui.gd", "hub_screen.gd", "screen_history.gd", "screen_audio.gd",
	"screen_profile.gd", "menu_hub.gd"]


## Est-ce un caractère que seule une fonte pictographique rend ?
func _pictographique(c: String) -> bool:
	var o := c.unicode_at(0)
	if o >= 0x1F000 and o <= 0x1FAFF:
		return true       # emoji
	if o >= 0x2190 and o <= 0x2BFF:
		return true       # flèches, opérateurs, formes, dingbats
	return o == 0xFE0F    # le sélecteur de variante emoji


## Le texte des chaînes littérales d'un source GDScript, commentaires exclus.
##
## Automate minimal : suffisant parce que GDScript n'a ni littéral brut ni
## interpolation, et que `#` hors chaîne va toujours jusqu'à la fin de ligne.
func _chaines_de(source: String) -> String:
	var out := ""
	var i := 0
	var n := source.length()
	var guillemet := ""
	var commentaire := false
	while i < n:
		var c := source[i]
		if commentaire:
			if c == "\n":
				commentaire = false
		elif guillemet != "":
			if c == "\\":
				i += 2
				continue
			if c == guillemet:
				guillemet = ""
			else:
				out += c
		elif c == "#":
			commentaire = true
		elif c == "\"" or c == "'":
			guillemet = c
		i += 1
	return out


func _test_aucun_pictogramme_affiche() -> void:
	var fautes: Array[String] = []
	for f: String in ECRANS:
		var chemin: String = "res://" + f
		if not FileAccess.file_exists(chemin):
			continue
		var vus := {}
		for c in _chaines_de(FileAccess.get_file_as_string(chemin)):
			if _pictographique(c) and not TOLERES.has(c):
				vus[c] = true
		for c: String in vus.keys():
			fautes.append("%s : %s (U+%04X)" % [f, c, c.unicode_at(0)])
	_check(fautes.is_empty(),
		"pictogrammes non décidés dans des libellés affichés — les inscrire dans TOLERES ou les retirer : %s"
			% ", ".join(fautes))

	# ⚠️ Vérifié rouge : l'automate doit VOIR un pictogramme de chaîne. Sans ce
	# contrôle, une extraction qui rendrait toujours "" laisserait l'audit vert
	# sur un dépôt entièrement fautif — quatrième forme du banc décoratif.
	var temoin := _chaines_de("var x = \"AB\\\"C💾D\"  # ⌗ commentaire ⟳")
	_check(temoin.contains("💾"),
		"l'automate ne retrouve pas un emoji pourtant présent dans une chaîne")
	_check(not temoin.contains("⌗") and not temoin.contains("⟳"),
		"l'automate lit les commentaires, qu'il doit ignorer")


# ---------------------------------------------------------------------------
# 5. AUCUNE TAILLE HORS DE L'ÉCHELLE, MESURÉE SUR LES CONTRÔLES
# ---------------------------------------------------------------------------

## ⚠️ **Ce contrôle est un parcours d'arbre, et il ne pouvait pas être un grep.**
##
## Le panneau portait sept tailles (13 à 26) et **pas une** n'apparaissait au
## site du `add_theme_font_size_override` : elles étaient des ARGUMENTS passés à
## `_make_label()` et `_make_button()`, qui les posaient ensuite. Une règle
## textuelle cherchant `font_size", <nombre>` serait restée verte sur les seize
## boutons fautifs — elle aurait nommé le défaut sans jamais le voir.
##
## On construit donc le HUD et on demande à chaque `Control` la taille qu'il
## rend. Peu importe par où elle est arrivée : c'est celle-là que l'œil reçoit.
func _test_les_tailles_sont_dans_l_echelle() -> void:
	var Charte := load("res://charte.gd")
	var echelle := {
		Charte.T_MENTION: true, Charte.T_COURANT: true, Charte.T_APPUI: true,
		Charte.T_TITRE: true, Charte.T_VERDICT: true, Charte.T_ENSEIGNE: true,
		Charte.T_DECOMPTE: true,
	}

	var hud_script: GDScript = load("res://map_editor_hud.gd")
	var hud: CanvasLayer = hud_script.new()
	root.add_child(hud)
	await process_frame
	await process_frame

	var fautifs: Array[String] = []
	var vus := 0
	var pile: Array[Node] = [hud]
	while not pile.is_empty():
		var n: Node = pile.pop_back()
		for enfant in n.get_children():
			pile.append(enfant)
		if not (n is Label or n is Button):
			continue
		var ctrl := n as Control
		var taille := ctrl.get_theme_font_size("font_size")
		vus += 1
		if not echelle.has(taille):
			var quoi: String = (n as Label).text if n is Label else (n as Button).text
			fautifs.append("%s « %s » à %d px"
				% [n.get_class(), quoi.substr(0, 24), taille])

	_check(vus >= 30,
		"seulement %d libellés parcourus : le HUD ne s'est pas construit" % vus)
	_check(fautifs.is_empty(),
		"%d libellé(s) hors de l'échelle typographique : %s"
			% [fautifs.size(), " · ".join(fautifs)])

	hud.queue_free()
	await process_frame


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Les icônes de l'éditeur ===")
	# Une frame : `menu_icones.gd` charge des ressources, et `ResourceLoader`
	# n'est pleinement gréé qu'après le premier tour de boucle.
	await process_frame

	_test_les_icones_sont_cuites()
	_test_le_reflet_est_un_miroir()
	_test_aucune_action_orpheline()
	_test_aucun_pictogramme_affiche()
	await _test_les_tailles_sont_dans_l_echelle()

	print("--- %d contrôles, %d échec(s) ---" % [_ok + _ko, _ko])
	quit(1 if _ko > 0 else 0)
