class_name MenuFicheClasse
extends PanelContainer

## La fiche d'une classe — chantier CLASSES, étape 7, réduite le 2026-09-10.
##
## ## Ce qu'elle montre, et rien d'autre
##
## **Le sprite, le gadget, les six caractéristiques de l'arme.** Demandé par
## Adrien le 2026-09-10, quand le choix de classe a quitté son panneau pour
## revenir dans le salon, sous l'affiche du match : *« mets les statistiques de
## l'arme, le gadget, le sprite, et rien d'autres […] Pas besoin de description,
## du rang etc. »*
##
## ⚠️ **La contrainte qui a tranché est l'écran scindé.** Deux joueurs y
## choisissent en même temps, chacun sa liste et sa fiche, côte à côte dans le
## même cadre. La première version — rang, nom, arme, deux lignes de prose,
## fusées — s'empilait déjà resserrée à deux ; Adrien l'a réduite pour que les
## deux tiennent de front, à côté de leur liste. Ce qui est parti ne s'est pas perdu : le nom est sur le bouton coché juste à
## côté, et le rang ordonne la liste. La description reste dans `ClassData`,
## que rien d'autre n'affiche aujourd'hui.
##
## La même fiche sert partout où l'on choisit une classe — salon, entraînement,
## fenêtre de choix du compétitif. Une seule forme : deux gabarits auraient été
## deux façons de lire la même classe.
##
## ## Les jauges ne disent pas « mieux », elles disent « plus »
##
## ⚠️ **Règle de lecture, et elle vaut pour les six lignes** : un cran allumé de
## plus veut dire *davantage de la chose nommée*, jamais *meilleur*. La barre de
## RECHARGE pleine est un défaut, celle de DÉGÂTS une qualité, et les deux se
## dessinent pareil. L'alternative — inverser les barres « où moins vaut mieux »
## — obligerait le joueur à se souvenir de quelles lignes mentent, et le premier
## réglage d'équilibrage qui changerait le sens d'une ligne le ferait en silence.
##
## Ce qui distingue les deux familles est la **couleur** : la puissance porte la
## teinte du joueur, le coût porte l'ambre. C'est une information, pas un
## ornement — et elle survit au daltonisme parce que le libellé est écrit à côté.
##
## ## L'échelle vient du CATALOGUE, jamais d'une constante
##
## Une jauge a besoin d'un maximum. L'écrire ici — « 100 dégâts = plein » —
## aurait créé une seconde vérité, périmée au premier équilibrage, et périmée
## **sans bruit** : la barre ne serait pas fausse à l'écran, elle serait juste
## mal remplie. Les bornes se mesurent donc sur les dix classes à chaque
## affichage : la jauge répond « où cette classe se situe parmi les dix », qui
## est exactement la question qu'on se pose devant un écran de sélection.
##
## ## Rien n'est inventé quand une donnée manque
##
## Pas de sprite ? La vignette reste vide et le cadre se voit. Pas de gadget
## livré ? La ligne le dit. C'est la règle « câbler, taire, diagnostiquer » du
## dépôt : un repli plausible se prend pour une intention.

const ClassDataT := preload("res://class_data.gd")

## Les six lignes de caractéristiques, dans l'ordre d'affichage.
##
## `cout` marque celles où la barre pleine est une mauvaise nouvelle. `champ` est
## purement documentaire : le calcul vit dans `_mesure()`, en un seul endroit,
## pour que la valeur affichée et la part de barre ne puissent pas diverger.
const LIGNES: Array[Dictionary] = [
	{"cle": "degats", "libelle": "DÉGÂTS", "cout": false},
	{"cle": "cadence", "libelle": "CADENCE", "cout": false},
	{"cle": "chargeur", "libelle": "CHARGEUR", "cout": false},
	{"cle": "faisceau", "libelle": "FAISCEAU", "cout": false},
	{"cle": "recharge", "libelle": "RECHARGE", "cout": true},
	{"cle": "immobilisation", "libelle": "IMMOBILISATION", "cout": true},
]

## Le sprite est désormais la seule image de la fiche : il prend la place que
## la prose occupait, et se lit mieux à 96 qu'à 60.
const COTE_PORTRAIT := 96.0

## ⚠️ **Un fond de béton, pas du noir.** Les sprites sont des silhouettes encrées
## en noir : posées sur un fond noir, elles ne se voyaient pas — vérifié à la
## capture, le Parasite était un carré vide. Un gris désaturé rend la découpe
## lisible sans rien peindre sur la figure. Public : les cartes de classe de
## l'affiche du match (`ui.gd`) montrent le même sprite, et le même fond.
const FOND_SPRITE := Color(0.28, 0.30, 0.33)

var _teinte: Color = Charte.BLEU

var _portrait: TextureRect
var _gadget: Label
var _gadget_tag: Label
var _jauges: Dictionary = {}     # cle -> Jauge
var _valeurs: Dictionary = {}    # cle -> Label
## La classe affichée. Lue par les bancs : maintenant que la fiche n'écrit plus
## le nom, c'est le seul moyen de savoir laquelle elle montre.
var _classe: ClassDataT = null


## Une barre crantée. Douze crans pleins ou creux, pas de dégradé, pas d'arrondi :
## c'est la même grammaire que le reste des menus — encre franche, arêtes dures.
##
## ⚠️ **Aucune couleur n'est lue depuis la charte ici.** La teinte arrive par
## `regler()`. Une classe interne qui irait chercher sa propre palette donnerait
## deux endroits où décider de la couleur d'une même barre.
class Jauge extends Control:
	const CRANS := 12

	var part: float = 0.0
	var teinte: Color = Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(132, 11)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func regler(nouvelle_part: float, nouvelle_teinte: Color) -> void:
		part = clampf(nouvelle_part, 0.0, 1.0)
		teinte = nouvelle_teinte
		queue_redraw()

	func _draw() -> void:
		var pas := size.x / float(CRANS)
		var large := maxf(2.0, pas - 3.0)
		# ⚠️ `ceil` et non `round` : une classe qui a la plus petite valeur des dix
		# garde UN cran allumé. Un zéro absolu se réserve aux vrais zéros — le
		# Spectre n'a pas « aucun flash arrondi », il n'a aucun flash.
		var pleins := 0 if part <= 0.0 else int(ceil(part * CRANS))
		var creux := Color(teinte.r, teinte.g, teinte.b, 0.18)
		for i in CRANS:
			var r := Rect2(i * pas, 0.0, large, size.y)
			if i < pleins:
				draw_rect(r, teinte)
			else:
				draw_rect(r, creux, false, 1.0)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	if _portrait != null:
		return
	_batir()


## Monte la fiche à la teinte de son joueur. Appelable avant l'entrée dans
## l'arbre — `_ready()` ne la remonte pas deux fois.
func batir(teinte: Color) -> void:
	_teinte = teinte
	if _portrait == null:
		_batir()


func _batir() -> void:
	add_theme_stylebox_override("panel",
		MenuWidgets.make_panel_style(Charte.LINE, MenuWidgets.CORNER_PANEL, 2))

	# La trame d'encre, DERRIÈRE le contenu (`show_behind_parent`) : c'est le
	# fond de case de bande dessinée, pas un voile posé sur le texte.
	var trame := MenuHatchRect.new()
	trame.name = "Trame"
	trame.pattern_mode = MenuHatchRect.PatternMode.SINGLE_45
	trame.color_ink = Color(Charte.SURFACE.r, Charte.SURFACE.g, Charte.SURFACE.b, 0.94)
	trame.color_line = Color(_teinte.r, _teinte.g, _teinte.b, 0.10)
	trame.spacing = 13.0
	trame.density = 0.22
	trame.roughness = 0.12
	trame.border_width = 0.0
	trame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trame.show_behind_parent = true
	trame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(trame)

	# ⚠️ **Pas de `MarginContainer` ici** : `make_panel_style` pose déjà des marges
	# de contenu de GAP_M sur les quatre côtés. En ajouter un second jeu doublerait
	# la respiration sans que personne ne voie d'où vient l'écart.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Charte.GAP_XS)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	# --- Le haut : le sprite, et le gadget à côté ---------------------------
	var haut := HBoxContainer.new()
	haut.add_theme_constant_override("separation", Charte.GAP_S)
	haut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(haut)

	var cadre := PanelContainer.new()
	cadre.custom_minimum_size = Vector2(COTE_PORTRAIT, COTE_PORTRAIT)
	cadre.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ⚠️ Style monté à la main, et pas `make_panel_style` : celui-là pose GAP_M de
	# marge intérieure sur les quatre côtés, ce qui ne laisserait à une vignette de
	# 96 px que 48 px de sprite — la moitié du cadre en respiration.
	var style_cadre := StyleBoxFlat.new()
	style_cadre.bg_color = FOND_SPRITE
	style_cadre.set_border_width_all(1)
	style_cadre.border_color = Color(_teinte.r, _teinte.g, _teinte.b, 0.45)
	style_cadre.set_corner_radius_all(MenuWidgets.CORNER_BADGE)
	style_cadre.content_margin_left = 4
	style_cadre.content_margin_right = 4
	style_cadre.content_margin_top = 4
	style_cadre.content_margin_bottom = 4
	cadre.add_theme_stylebox_override("panel", style_cadre)
	haut.add_child(cadre)

	_portrait = TextureRect.new()
	# ⚠️ `EXPAND_IGNORE_SIZE` : sans lui un `TextureRect` impose la taille NATIVE
	# de sa texture — la vignette ferait la largeur du sprite, pas celle du cadre.
	# Même piège que `icon_max_width` sur les boutons, payé le 2026-08-24.
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(_portrait)

	# Le gadget se lit à côté du sprite plutôt qu'en pied de fiche : c'est une
	# ligne, et le sprite laissait à sa droite une colonne vide de sa hauteur.
	var colonne_gadget := VBoxContainer.new()
	colonne_gadget.add_theme_constant_override("separation", Charte.GAP_XXS)
	colonne_gadget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne_gadget.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	colonne_gadget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haut.add_child(colonne_gadget)

	var etiquette_gadget := Label.new()
	etiquette_gadget.text = "GADGET"
	Charte.appareil(etiquette_gadget, Charte.T_MENTION)
	etiquette_gadget.add_theme_color_override("font_color", Charte.DIM)
	colonne_gadget.add_child(etiquette_gadget)

	_gadget = Label.new()
	Charte.appareil(_gadget, Charte.T_APPUI, Charte.POIDS_APPUI)
	_gadget.add_theme_color_override("font_color", Charte.HALOGENE)
	_gadget.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonne_gadget.add_child(_gadget)

	# Le seul marqueur de la fiche, et il porte une vraie règle du jeu : un gadget
	# qui éblouit change ce que l'adversaire voit, pas seulement ce qu'il heurte.
	_gadget_tag = Label.new()
	_gadget_tag.text = "ÉBLOUIT"
	Charte.appareil(_gadget_tag, Charte.T_MENTION, Charte.POIDS_APPUI)
	_gadget_tag.add_theme_color_override("font_color", Charte.AMBRE)
	colonne_gadget.add_child(_gadget_tag)

	col.add_child(_filet(Color(_teinte.r, _teinte.g, _teinte.b, 0.55), 2))

	# --- Les six jauges ------------------------------------------------------
	var grille := GridContainer.new()
	grille.columns = 3
	grille.add_theme_constant_override("h_separation", Charte.GAP_XS)
	grille.add_theme_constant_override("v_separation", 4)
	grille.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grille)

	for ligne in LIGNES:
		var cle := String(ligne["cle"])

		var etiquette := Label.new()
		etiquette.text = String(ligne["libelle"])
		Charte.appareil(etiquette, Charte.T_MENTION)
		etiquette.add_theme_color_override("font_color", Charte.DIM)
		etiquette.custom_minimum_size = Vector2(112, 0)
		grille.add_child(etiquette)

		var jauge := Jauge.new()
		jauge.custom_minimum_size = Vector2(120, 10)
		grille.add_child(jauge)
		_jauges[cle] = jauge

		var valeur := Label.new()
		Charte.appareil(valeur, Charte.T_MENTION, Charte.POIDS_APPUI)
		valeur.add_theme_color_override("font_color", Charte.HALOGENE)
		valeur.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		valeur.custom_minimum_size = Vector2(72, 0)
		grille.add_child(valeur)
		_valeurs[cle] = valeur

func _filet(couleur: Color, epaisseur: int) -> Control:
	# ⚠️ Pas `trait` : c'est un mot réservé de GDScript, et le message d'erreur
	# — « Expected variable name after "var" » — ne le dit pas.
	var filet := ColorRect.new()
	filet.color = couleur
	filet.custom_minimum_size = Vector2(0, epaisseur)
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return filet


## Remplit la fiche. `catalogue` sert d'échelle aux jauges — sans lui, une barre
## n'aurait aucun maximum honnête à afficher.
func montrer(classe: ClassDataT, catalogue: Array) -> void:
	if _portrait == null:
		_batir()
	_classe = classe
	if classe == null:
		_vider()
		return

	# Le sprite du joueur SERT de portrait : c'est exactement la silhouette que
	# l'adversaire découpera dans le faisceau. Une illustration séparée aurait
	# promis une allure que le jeu ne rend pas.
	var chemin := classe.chemin_sprite()
	_portrait.texture = load(chemin) as Texture2D if ResourceLoader.exists(chemin) \
		else null

	for ligne in LIGNES:
		var cle := String(ligne["cle"])
		var mesure := _mesure(classe, cle)
		var part := _part(catalogue, cle, float(mesure["valeur"]))
		var teinte: Color = Charte.AMBRE if bool(ligne["cout"]) else _teinte
		(_jauges[cle] as Jauge).regler(part, teinte)
		(_valeurs[cle] as Label).text = String(mesure["texte"])

	if classe.gadget != null:
		_gadget.text = String(classe.gadget.libelle)
		_gadget_tag.visible = classe.gadget.eblouit
	else:
		_gadget.text = "—"
		_gadget_tag.visible = false


## La classe que la fiche montre, ou `null`.
func classe_affichee() -> ClassDataT:
	return _classe


func _vider() -> void:
	_portrait.texture = null
	for cle in _jauges:
		(_jauges[cle] as Jauge).regler(0.0, Charte.DIM)
		(_valeurs[cle] as Label).text = "—"
	_gadget.text = "—"
	_gadget_tag.visible = false


## La valeur brute d'une ligne, et son texte. **Un seul endroit** : si le calcul
## et l'affichage vivaient séparément, une barre finirait par contredire le
## nombre écrit juste à côté d'elle.
func _mesure(classe: ClassDataT, cle: String) -> Dictionary:
	match cle:
		"degats":
			var texte := "%d / %d" % [int(round(classe.damage_center)),
				int(round(classe.damage_edge))]
			if classe.projectile_count > 1:
				texte = "%d × %s" % [classe.projectile_count, texte]
			return {"valeur": classe.damage_center * classe.projectile_count,
				"texte": texte}
		"cadence":
			var par_seconde := 0.0 if classe.cooldown <= 0.0 else 1.0 / classe.cooldown
			return {"valeur": par_seconde, "texte": "%s /s" % _nombre(par_seconde, 1)}
		"chargeur":
			return {"valeur": float(classe.max_ammo), "texte": str(classe.max_ammo)}
		"faisceau":
			# Le demi-angle est ce que porte la donnée ; l'ouverture est ce que le
			# joueur voit. On affiche donc le cône entier, pas la moitié.
			var cone := classe.torch_angle_deg * 2.0
			return {"valeur": cone, "texte": "%d°" % int(round(cone))}
		"recharge":
			return {"valeur": classe.reload_time,
				"texte": "%s s" % _nombre(classe.reload_time, 1)}
		"immobilisation":
			var duree := 0.0 if classe.root == null else classe.root.duree
			return {"valeur": duree, "texte": "%s s" % _nombre(duree, 2)}
	return {"valeur": 0.0, "texte": "—"}


## Où cette valeur se situe entre la plus faible et la plus forte des dix.
##
## Le bas de l'échelle n'est pas zéro mais le **minimum du catalogue** : sur
## quatre secondes de recharge dont la plus courte fait deux, une barre partant
## de zéro dirait « moitié moins » là où l'écart réel est du simple au double.
## Un catalogue à valeur unique rend une barre pleine — il n'y a rien à comparer.
func _part(catalogue: Array, cle: String, valeur: float) -> float:
	var plancher := INF
	var plafond := -INF
	for c in catalogue:
		if c == null:
			continue
		var v := float(_mesure(c, cle)["valeur"])
		plancher = minf(plancher, v)
		plafond = maxf(plafond, v)
	if plancher == INF or plafond <= plancher:
		return 1.0
	# Le plancher visuel : la plus faible des dix garde un cran, sauf si elle vaut
	# vraiment zéro. « Zéro fusée » et « la plus courte des dix » ne sont pas la
	# même information et ne doivent pas se dessiner pareil.
	if valeur <= 0.0:
		return 0.0
	return clampf(0.08 + 0.92 * (valeur - plancher) / (plafond - plancher), 0.0, 1.0)


## Un nombre en français : la virgule décimale, et pas de zéro inutile.
func _nombre(valeur: float, decimales: int) -> String:
	var texte := String.num(valeur, decimales)
	return texte.replace(".", ",")
