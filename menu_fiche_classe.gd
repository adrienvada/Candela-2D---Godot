class_name MenuFicheClasse
extends PanelContainer

## La fiche d'une classe — chantier CLASSES, étape 7, réduite le 2026-09-10.
##
## ## Ce qu'elle montre, et rien d'autre
##
## **Le sprite, le gadget et sa phrase, sept jauges.** Demandé par Adrien le
## 2026-09-10, quand le choix de classe a quitté son panneau pour revenir dans le
## salon, sous l'affiche du match : *« mets les statistiques de l'arme, le gadget,
## le sprite, et rien d'autres […] Pas besoin de description, du rang etc. »*
##
## ⚠️ **Amendé le même jour, et pour une bonne raison.** Réduite à ce point, la
## fiche taisait deux règles que seule la prose portait : le Spectre n'a aucune
## fusée — c'est son identité —, et le nom d'un gadget ne dit pas ce qu'il fait.
## Adrien a donc rendu *« dans les stats le nombre de fusées max »* et *« une
## courte description du gadget »*. La description de CLASSE, elle, reste absente.
##
## ⚠️ **Recomposée le soir même** (Adrien, 2026-09-10) : *« l'arme définit
## autant la classe »*. En haut, trois cases de même taille — le sprite, l'icône
## de l'arme, et un aperçu dessiné du cône de torche qui remplace la jauge
## FAISCEAU. En bas, sous les jauges, le gadget avec son image et sa phrase.
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
## ⚠️ **Règle de lecture, et elle vaut pour les sept lignes** : un cran allumé de
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

## Les sept lignes de caractéristiques, dans l'ordre d'affichage : ce que la
## classe apporte d'abord, ce qu'elle coûte ensuite.
##
## `cout` marque celles où la barre pleine est une mauvaise nouvelle. `champ` est
## purement documentaire : le calcul vit dans `_mesure()`, en un seul endroit,
## pour que la valeur affichée et la part de barre ne puissent pas diverger.
const LIGNES: Array[Dictionary] = [
	{"cle": "degats", "libelle": "DÉGÂTS", "cout": false},
	{"cle": "cadence", "libelle": "CADENCE", "cout": false},
	{"cle": "chargeur", "libelle": "CHARGEUR", "cout": false},
	# Plus de ligne FAISCEAU (Adrien, 2026-09-10) : l'angle se MONTRE, dans la
	# troisième case du haut (`Cone`), au lieu de se lire en degrés sur une barre.
	{"cle": "fusees", "libelle": "FUSÉES", "cout": false},
	{"cle": "recharge", "libelle": "RECHARGE", "cout": true},
	{"cle": "immobilisation", "libelle": "IMMOBILISATION", "cout": true},
]

## **Trois cases de même taille en haut : le sprite, l'arme, la torche**
## (Adrien, 2026-09-10 : « l'arme définit autant la classe »). 92 et non 96 :
## trois cases et deux gouttières doivent tenir dans une fiche d'écran scindé,
## qui n'a guère plus de 300 px de contenu.
const COTE_PORTRAIT := 92.0
## La case du gadget, en bas, sous les jauges. Plus petite : elle illustre une
## phrase, elle ne porte pas la classe.
const COTE_GADGET := 64.0

## ⚠️ **Un fond de béton, pas du noir.** Les sprites sont des silhouettes encrées
## en noir : posées sur un fond noir, elles ne se voyaient pas — vérifié à la
## capture, le Parasite était un carré vide. Un gris désaturé rend la découpe
## lisible sans rien peindre sur la figure. Public : les cartes de classe de
## l'affiche du match (`ui.gd`) montrent le même sprite, et le même fond.
const FOND_SPRITE := Color(0.28, 0.30, 0.33)

var _teinte: Color = Charte.BLEU

var _portrait: TextureRect
var _arme: TextureRect
var _cone: Cone
var _cone_valeur: Label
var _gadget_image: TextureRect
var _gadget: Label
var _gadget_tag: Label
var _gadget_description: Label
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


## L'aperçu du faisceau : le cône que la torche de la classe ouvre, vu de dessus.
##
## **Dessiné depuis les données, pas depuis le cookie.** Le cookie est un masque
## blanc pensé pour être projeté au sol ; affiché tel quel dans une case, il ne
## montre qu'un carré clair. Le demi-angle (`torch_angle_deg`) et la portée
## (`portee_torche()`) sont les deux nombres que le jeu utilise pour éclairer :
## les dessiner, c'est montrer exactement ce que la torche fera.
##
## La portée est RELATIVE au catalogue, comme les jauges : la plus longue des dix
## touche le haut de la case. Une échelle absolue aurait rendu l'arbalète
## illisible (un fil) ou les autres minuscules.
class Cone extends Control:
	## Couches du dégradé. Peu, exprès : l'escalier léger est la signature du
	## halo de l'allumage (`power_on.gd`), et un dégradé lisse redevient le défaut
	## « personne n'a choisi ça ».
	const COUCHES := 7
	const SEGMENTS := 24

	var demi_angle: float = 0.0
	var part_portee: float = 0.0
	var teinte: Color = Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func regler(nouveau_demi_angle: float, nouvelle_part: float, nouvelle_teinte: Color) -> void:
		demi_angle = clampf(nouveau_demi_angle, 0.0, PI)
		part_portee = clampf(nouvelle_part, 0.0, 1.0)
		teinte = nouvelle_teinte
		queue_redraw()

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		# Le porteur en bas, au centre ; le faisceau monte.
		var origine := Vector2(size.x * 0.5, size.y - 8.0)
		var longueur := (size.y - 14.0) * lerpf(0.3, 1.0, part_portee)
		if demi_angle > 0.0 and part_portee > 0.0:
			for c in COUCHES:
				var t := float(c + 1) / float(COUCHES)
				var rayon := longueur * t
				var points := PackedVector2Array([origine])
				for s in SEGMENTS + 1:
					var a := -demi_angle + 2.0 * demi_angle * float(s) / float(SEGMENTS)
					# Angle compté depuis la verticale : `a = 0` pointe vers le haut.
					points.append(origine + Vector2(sin(a), -cos(a)) * rayon)
				# Du plus large au plus serré, chacun par-dessus : le centre
				# s'accumule, le bord s'efface — ce que fait une torche.
				var alpha := 0.16 + 0.10 * (1.0 - t)
				draw_colored_polygon(points, Color(Charte.HALOGENE, alpha))
			# Les deux bords du cône, à l'encre claire : l'angle se lit à eux.
			for signe in [-1.0, 1.0]:
				var bord: float = signe * demi_angle
				draw_line(origine, origine + Vector2(sin(bord), -cos(bord)) * longueur,
					Color(Charte.HALOGENE, 0.85), 1.5, true)
		draw_circle(origine, 4.0, teinte)


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

	# --- Le haut : trois cases de même taille — sprite, arme, torche ---------
	# L'arme définit autant la classe que la silhouette (Adrien, 2026-09-10) : elle
	# a sa case, à égalité. La troisième montre le faisceau au lieu de le chiffrer.
	var haut := HBoxContainer.new()
	haut.add_theme_constant_override("separation", Charte.GAP_XS)
	haut.alignment = BoxContainer.ALIGNMENT_CENTER
	haut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(haut)

	_portrait = _image_dans(_case(haut, COTE_PORTRAIT, FOND_SPRITE))
	_arme = _image_dans(_case(haut, COTE_PORTRAIT, FOND_SPRITE))

	# La torche sur NOIR, et c'est la seule : un faisceau ne se lit que dans le
	# noir, qui est la règle du jeu entier.
	var case_torche := _case(haut, COTE_PORTRAIT, Charte.NOIR)
	_cone = Cone.new()
	case_torche.add_child(_cone)
	# L'ouverture en degrés reste écrite, dans le coin : l'œil compare les cônes,
	# le nombre sert à qui veut comparer deux classes au degré près. **En bas à
	# droite** : le cône part du bas-centre et monte, ce coin-là reste noir quelle
	# que soit l'ouverture — en haut, il mordait sur le faisceau.
	_cone_valeur = Label.new()
	Charte.appareil(_cone_valeur, Charte.T_MENTION, Charte.POIDS_APPUI)
	_cone_valeur.add_theme_color_override("font_color", Charte.HALOGENE)
	_cone_valeur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ⚠️ **Enfant du cône, ancré, et pas du `PanelContainer`** : posé dans la case
	# avec un simple alignement « bas », il restait à mi-hauteur — mesuré à la
	# capture. Un `Control` nu, lui, respecte les ancres.
	_cone.add_child(_cone_valeur)
	_cone_valeur.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_cone_valeur.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_cone_valeur.grow_vertical = Control.GROW_DIRECTION_BEGIN

	col.add_child(_filet(Color(_teinte.r, _teinte.g, _teinte.b, 0.55), 2))

	_batir_jauges(col)

	col.add_child(_filet(Color(_teinte.r, _teinte.g, _teinte.b, 0.30), 1))

	# --- Le bas : le gadget, son image, sa phrase ------------------------------
	# Sous les jauges (Adrien, 2026-09-10) : il a désormais une image, et une
	# phrase qu'on lit en entier plutôt que coincée à côté du sprite.
	var bas := HBoxContainer.new()
	bas.add_theme_constant_override("separation", Charte.GAP_S)
	bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bas)

	_gadget_image = _image_dans(_case(bas, COTE_GADGET, FOND_SPRITE))

	var colonne_gadget := VBoxContainer.new()
	colonne_gadget.add_theme_constant_override("separation", Charte.GAP_XXS)
	colonne_gadget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne_gadget.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	colonne_gadget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bas.add_child(colonne_gadget)

	# « GADGET », et à côté le seul marqueur de la fiche. Sur la même ligne : la
	# phrase du gadget a besoin de la hauteur que le marqueur prenait dessous.
	var entete_gadget := HBoxContainer.new()
	entete_gadget.add_theme_constant_override("separation", Charte.GAP_XS)
	entete_gadget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne_gadget.add_child(entete_gadget)

	var etiquette_gadget := Label.new()
	etiquette_gadget.text = "GADGET"
	Charte.appareil(etiquette_gadget, Charte.T_MENTION)
	etiquette_gadget.add_theme_color_override("font_color", Charte.DIM)
	entete_gadget.add_child(etiquette_gadget)

	# Il porte une vraie règle du jeu : un gadget qui éblouit change ce que
	# l'adversaire voit, pas seulement ce qu'il heurte.
	_gadget_tag = Label.new()
	_gadget_tag.text = "ÉBLOUIT"
	Charte.appareil(_gadget_tag, Charte.T_MENTION, Charte.POIDS_APPUI)
	_gadget_tag.add_theme_color_override("font_color", Charte.AMBRE)
	entete_gadget.add_child(_gadget_tag)

	_gadget = Label.new()
	Charte.appareil(_gadget, Charte.T_APPUI, Charte.POIDS_APPUI)
	_gadget.add_theme_color_override("font_color", Charte.HALOGENE)
	_gadget.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonne_gadget.add_child(_gadget)

	# Ce que le gadget FAIT — le nom seul ne le dit pas (Adrien, 2026-09-10).
	_gadget_description = Label.new()
	Charte.appareil(_gadget_description, Charte.T_MENTION)
	_gadget_description.add_theme_color_override("font_color", Charte.ACIER)
	_gadget_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonne_gadget.add_child(_gadget_description)


## Les jauges, une ligne par entrée de `LIGNES`.
func _batir_jauges(col: VBoxContainer) -> void:
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

## Une case d'image carrée, posée dans `parent`.
##
## ⚠️ Style monté à la main, et pas `make_panel_style` : celui-là pose GAP_M de
## marge intérieure sur les quatre côtés, ce qui ne laisserait à une vignette de
## 92 px que 44 px d'image — la moitié de la case en respiration.
func _case(parent: Control, cote: float, fond: Color) -> PanelContainer:
	var case := PanelContainer.new()
	case.custom_minimum_size = Vector2(cote, cote)
	case.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	case.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.set_border_width_all(1)
	style.border_color = Color(_teinte.r, _teinte.g, _teinte.b, 0.45)
	style.set_corner_radius_all(MenuWidgets.CORNER_BADGE)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	case.add_theme_stylebox_override("panel", style)
	parent.add_child(case)
	return case


## L'image d'une case.
func _image_dans(case: PanelContainer) -> TextureRect:
	var image := TextureRect.new()
	# ⚠️ `EXPAND_IGNORE_SIZE` : sans lui un `TextureRect` impose la taille NATIVE
	# de sa texture — la vignette ferait la largeur du sprite, pas celle du cadre.
	# Même piège que `icon_max_width` sur les boutons, payé le 2026-08-24.
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	case.add_child(image)
	return image


## La texture d'un chemin, ou `null` s'il n'existe pas : une case vide se voit,
## une image d'emprunt se prendrait pour la bonne.
func _texture_si(chemin: String) -> Texture2D:
	return load(chemin) as Texture2D if chemin != "" and ResourceLoader.exists(chemin) \
		else null


static var _recadrages: Dictionary = {}

## La même texture, recadrée sur ce qu'elle peint.
##
## ⚠️ **Les sprites de joueur flottent dans une toile presque vide** : le corps
## occupe le tiers central, le reste est transparent pour laisser tourner la
## figure en jeu. Posé tel quel dans une case de 92 px, le Parasite y faisait
## trente pixels de large — mesuré à la capture du 2026-09-10. Le cadrage se
## calcule une fois par chemin (`get_used_rect`), la texture d'origine n'est pas
## touchée : le jeu garde sa toile, la fiche montre la figure.
static func _recadree(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var cle := tex.resource_path
	if cle != "" and _recadrages.has(cle):
		return _recadrages[cle]
	var img := tex.get_image()
	var resultat: Texture2D = tex
	if img != null:
		if img.is_compressed():
			img = img.duplicate() as Image
			img.decompress()
		var zone := img.get_used_rect()
		if zone.size.x > 0 and zone.size.y > 0 and zone.size != img.get_size():
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(zone)
			resultat = atlas
	if cle != "":
		_recadrages[cle] = resultat
	return resultat


## La portée de cette torche rapportée à la plus longue du catalogue.
func _part_portee(catalogue: Array, portee: float) -> float:
	var plus_longue := 0.0
	for c in catalogue:
		if c != null:
			plus_longue = maxf(plus_longue, float(c.portee_torche()))
	return 1.0 if plus_longue <= 0.0 else portee / plus_longue


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
	_portrait.texture = _recadree(_texture_si(classe.chemin_sprite()))
	# L'icône d'arme, en couleurs d'origine : la même que sur le bouton de la liste.
	_arme.texture = MenuIcones.arme(classe.slug())
	_cone.regler(classe.demi_angle_torche(),
		_part_portee(catalogue, classe.portee_torche()), _teinte)
	# Le demi-angle est ce que porte la donnée ; l'ouverture est ce que le joueur
	# voit. On écrit donc le cône entier, pas la moitié.
	_cone_valeur.text = "%d°" % int(round(classe.torch_angle_deg * 2.0))

	for ligne in LIGNES:
		var cle := String(ligne["cle"])
		var mesure := _mesure(classe, cle)
		var part := _part(catalogue, cle, float(mesure["valeur"]))
		var teinte: Color = Charte.AMBRE if bool(ligne["cout"]) else _teinte
		(_jauges[cle] as Jauge).regler(part, teinte)
		(_valeurs[cle] as Label).text = String(mesure["texte"])

	if classe.gadget != null:
		_gadget.text = String(classe.gadget.libelle)
		_gadget_description.text = String(classe.gadget.description)
		_gadget_tag.visible = classe.gadget.eblouit
		_gadget_image.texture = _recadree(_texture_si(classe.gadget.chemin_icone()))
	else:
		_gadget.text = "—"
		_gadget_description.text = ""
		_gadget_tag.visible = false
		_gadget_image.texture = null


## La classe que la fiche montre, ou `null`.
func classe_affichee() -> ClassDataT:
	return _classe


func _vider() -> void:
	_portrait.texture = null
	_arme.texture = null
	_cone.regler(0.0, 0.0, Charte.DIM)
	_cone_valeur.text = ""
	_gadget_image.texture = null
	for cle in _jauges:
		(_jauges[cle] as Jauge).regler(0.0, Charte.DIM)
		(_valeurs[cle] as Label).text = "—"
	_gadget.text = "—"
	_gadget_description.text = ""
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
		"fusees":
			# Le PLAFOND, pas le stock de départ : ce que la réserve peut contenir,
			# recharge comprise. Zéro pour le Spectre, et donc aucun cran allumé —
			# `_part()` réserve le vide aux vrais zéros.
			var plafond := 0 if classe.fusees == null else classe.fusees.plafond_effectif()
			return {"valeur": float(plafond), "texte": str(plafond)}
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
