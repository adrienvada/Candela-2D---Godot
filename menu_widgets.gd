class_name MenuWidgets
extends RefCounted

## Usine de composants d'interface standardisés — Candela 2D.
##
## Centralise la création et le stylage de tous les contrôles interactifs
## (boutons, boutons de pas, panneaux, modales, sliders) pour garantir une
## cohérence visuelle absolue (coins, bordures, ombres, typographie) et un
## comportement manette / double-curseur irréprochable sur l'ensemble des menus.

## Direction artistique : Roman Graphique Brutaliste (arêtes vives, ombres portées
## franches d'encre noire, inversion de contraste franche au survol/focus).

const Charte := preload("res://charte.gd")
const MenuTheme := preload("res://menu_theme.gd")
const MenuHatchRect := preload("res://menu_hatch_rect.gd")
## La pâte d'interface — habillage iso (2026-09-15). **Préchargée**, comme tout
## shader du dépôt : compilée à la volée, elle le serait à l'ouverture du premier
## panneau, c'est-à-dire pile quand le joueur regarde.
const SHADER_PATE := preload("res://menu_pate.gdshader")

## Le matériau PARTAGÉ de la pâte : une seule instance pour tous les panneaux.
## Deux panneaux au même matériau peuvent être dessinés d'un même appel ; un
## matériau par panneau les séparerait tous.
static var _pate: ShaderMaterial = null


## Le matériau de la pâte, construit au premier appel.
##
## ⚠️ **La texture manquante CRIE.** `menu_pate.gdshader` déclare son grain en
## `hint_default_white` : sans fichier, chaque panneau s'éclaircirait
## uniformément sans une erreur — le repli muet que le voile d'éblouissement a
## déjà coûté. `tools/test_habillage.gd` vérifie en plus que le paramètre est posé.
static func materiau_pate() -> ShaderMaterial:
	if _pate != null:
		return _pate
	_pate = ShaderMaterial.new()
	_pate.shader = SHADER_PATE
	_pate.set_shader_parameter("echelle", Charte.PATE_GRAIN_ECHELLE)
	_pate.set_shader_parameter("force", Charte.PATE_GRAIN_FORCE)
	if ResourceLoader.exists(Charte.CHEMIN_PATE_GRAIN):
		_pate.set_shader_parameter("grain", load(Charte.CHEMIN_PATE_GRAIN))
	else:
		push_error("pâte d'interface : grain absent — %s" % Charte.CHEMIN_PATE_GRAIN)
	return _pate


## Pose la pâte sur un nœud d'interface : sa plaque (StyleBox ou `_draw`) prend
## le grain de lavis, ses enfants restent nets.
static func poser_pate(noeud: CanvasItem) -> void:
	if noeud != null:
		noeud.material = materiau_pate()


static var _pochoir: ShaderMaterial = null


## Le matériau du POCHOIR : la pâte, appuyée (`Charte.PATE_POCHOIR_FORCE`), pour ce
## qui est tamponné. Partagé lui aussi. Posé sur un libellé, le grain passe sur les
## lettres — voulu ici, évité partout ailleurs (`empater()` saute les boutons à
## texte propre).
static func materiau_pochoir() -> ShaderMaterial:
	if _pochoir != null:
		return _pochoir
	_pochoir = materiau_pate().duplicate() as ShaderMaterial
	_pochoir.set_shader_parameter("force", Charte.PATE_POCHOIR_FORCE)
	return _pochoir


static func poser_pochoir(noeud: CanvasItem) -> void:
	if noeud != null:
		noeud.material = materiau_pochoir()


## Les plaques qui prennent la pâte : l'aplat de leur style de repos.
const _STYLES_DE_PLAQUE := ["panel", "normal"]


## Empâte un sous-arbre : toute plaque qui dessine un aplat reçoit la pâte.
##
## **Un passage, et non un appel par site** : le menu construit ses panneaux en
## une centaine d'endroits, et un appel oublié ferait un panneau lisse au milieu
## des autres — le défaut qu'on ne voit qu'en capture. Rend le nombre de nœuds
## empâtés, pour que le banc puisse le compter.
##
## Ce qui est SAUTÉ, et pourquoi :
## - **un nœud qui porte déjà un matériau** : c'est le verre de M14 (cadre de
##   droite, rangées `Row_`) ou un effet de vitrine. Un nœud n'a qu'un matériau ;
##   l'écraser éteindrait l'effet sans une erreur. D'où l'ordre : ce passage se
##   fait APRÈS `MenuGlass.vitrer*()` ;
## - **un bouton qui porte son propre texte** (`Button.text` non vide) : le texte
##   d'un bouton est dessiné par le bouton lui-même, donc sous son matériau, et le
##   grain passerait sur les lettres. Les entrées du hub, dont le libellé est un
##   `Label` enfant, sont empâtées ;
## - **un style qui n'est pas un aplat** (`StyleBoxEmpty`, texture) : il n'y a rien
##   à grainer, et un matériau posé sur rien sépare quand même les lots de dessin.
static func empater(racine: Node) -> int:
	var n := 0
	if racine is Control:
		var c := racine as Control
		var bouton_a_texte := c is Button and (c as Button).text != ""
		if c.material == null and not bouton_a_texte:
			for nom: String in _STYLES_DE_PLAQUE:
				if c.has_theme_stylebox_override(nom) \
						and c.get_theme_stylebox(nom) is StyleBoxFlat:
					c.material = materiau_pate()
					n += 1
					break
	for enfant in racine.get_children():
		n += empater(enfant)
	return n

# --- Rayons de courbure standards (Roman Graphique Brutaliste : angles vifs) --
const CORNER_BUTTON := 0
const CORNER_PANEL := 0
const CORNER_BADGE := 0
const CORNER_STEP := 0

# --- Bordures & Ombres standards (Hard Drop Shadows d'encre noire) ------------
const BORDER_WIDTH_CONTROL := 2
const BORDER_WIDTH_PANEL := 2
const SHADOW_SIZE := 0
const SHADOW_OFFSET_BUTTON := Vector2(4, 4)
const SHADOW_OFFSET_PRESSED := Vector2(1, 1)
const SHADOW_OFFSET_PANEL := Vector2(5, 5)
const SHADOW_OFFSET_MODAL := Vector2(8, 8)
const SHADOW_COLOR_DEFAULT := Color(Charte.NOIR, 0.95)
const SHADOW_COLOR_PANEL := MenuTheme.OMBRE

# =============================================================================
# BOUTONS
# =============================================================================

## Les quatre états d'un bouton, en blocs — l'habillage voxel de [method make_button].
##
## **Un bouton principal est un bloc DÉJÀ sous la torche.** C'est ce que « plein
## énergisé » voulait dire quand son fond était un aplat de l'accent : l'œil doit
## le trouver sans le chercher. Les autres attendent dans l'ombre.
##
## ⚠️ **Et l'enfoncement DÉPLACE le libellé.** Une plaque enfoncée qui garde son
## texte à la même hauteur n'est qu'une plaque plus sombre ; c'est la descente de
## `Charte.VOXEL_ENFONCEMENT_PX` — la chute d'ombre que l'ancien bouton faisait
## déjà, devenue un mouvement de bloc — qui donne le clic sous le doigt.
static func _poser_les_blocs(btn: Button, accent: Color, primary: bool,
		marge_x: int, marge_y: int = 10, repos_neutre: bool = false) -> void:
	# ⚠️ **Une bascule ne porte AUCUN rôle au repos**, et ce n'est pas un détail :
	# la moindre teinte éclaircit la plaque sous un texte secondaire, qui y perd
	# le contraste que l'aplat d'encre lui donnait. Mesuré sur les captures :
	# 4,48:1 avant, 3,59:1 avec une teinte de joueur au repos. L'habillage pâte
	# ne teintait rien non plus tant que la plaque n'était pas touchée.
	var repos := style_de_bloc(MenuTheme.LINE if repos_neutre else accent,
		Bloc.ALLUME if primary else Bloc.REPOS)
	var survol := style_de_bloc(accent, Bloc.ALLUME)
	var enfonce := style_de_bloc(accent, Bloc.ENFONCE)
	# Désactivé : un bloc que la lumière n'atteint jamais — sa face du dessus vaut
	# déjà celle de ses flancs, donc il n'a plus de relief à montrer.
	var eteint := style_de_bloc(MenuTheme.LINE, Bloc.REPOS, Charte.VOXEL_ENFONCE)
	for s: StyleBoxTexture in [repos, survol, enfonce, eteint]:
		s.content_margin_left = marge_x
		s.content_margin_right = marge_x
		s.content_margin_top = marge_y
		s.content_margin_bottom = marge_y
	enfonce.content_margin_top += Charte.VOXEL_ENFONCEMENT_PX
	enfonce.content_margin_bottom -= Charte.VOXEL_ENFONCEMENT_PX
	btn.add_theme_stylebox_override("normal", repos)
	btn.add_theme_stylebox_override("hover", survol)
	btn.add_theme_stylebox_override("focus", survol)
	btn.add_theme_stylebox_override("pressed", enfonce)
	btn.add_theme_stylebox_override("hover_pressed", enfonce)
	btn.add_theme_stylebox_override("disabled", eteint)


## Crée un bouton standard conforme à la Charte.
## `primary` : bouton plein énergisé (action principale / engagement).
## `accent` : couleur de rôle (BLEU/J1, ROUGE/J2, ACIER/neutre, AMBRE/titres/or).
static func make_button(label: String, accent: Color = MenuTheme.ACCENT,
		primary: bool = false, font_size: int = Charte.T_COURANT,
		min_size: Vector2 = Vector2.ZERO) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_ALL
	if min_size != Vector2.ZERO:
		btn.custom_minimum_size = min_size

	Charte.appareil(btn, font_size, Charte.POIDS_APPUI if primary else Charte.POIDS_COURANT)

	if Charte.voxel_actif():
		_poser_les_blocs(btn, accent, primary,
			Charte.GAP_M if min_size.x > 180 else Charte.GAP_S)
	else:
		# --- Style normal ---
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(accent.r, accent.g, accent.b, 0.90) if primary else MenuTheme.SURFACE
		normal.set_border_width_all(BORDER_WIDTH_CONTROL)
		normal.border_color = accent if primary else (MenuTheme.LINE if accent == MenuTheme.ACCENT else Color(accent.r, accent.g, accent.b, 0.60))
		normal.set_corner_radius_all(CORNER_BUTTON)
		normal.shadow_size = 0
		normal.shadow_offset = SHADOW_OFFSET_BUTTON
		normal.shadow_color = SHADOW_COLOR_DEFAULT
		normal.content_margin_left = Charte.GAP_M if min_size.x > 180 else Charte.GAP_S
		normal.content_margin_right = Charte.GAP_M if min_size.x > 180 else Charte.GAP_S
		normal.content_margin_top = 10
		normal.content_margin_bottom = 10
		btn.add_theme_stylebox_override("normal", normal)

		# --- Style survol & focus (inversion franche de contraste) ---
		var hover := normal.duplicate() as StyleBoxFlat
		hover.border_color = MenuTheme.LUMIERE
		hover.bg_color = MenuTheme.LUMIERE if (primary or accent == MenuTheme.ACCENT) else accent
		hover.shadow_size = 0
		hover.shadow_offset = SHADOW_OFFSET_BUTTON
		hover.shadow_color = SHADOW_COLOR_DEFAULT
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("focus", hover)

		# --- Style pressé / enfoncé (enfoncement mécanique de la plaque) ---
		var pressed := hover.duplicate() as StyleBoxFlat
		pressed.bg_color = hover.bg_color
		pressed.border_color = MenuTheme.LUMIERE
		pressed.shadow_size = 0
		pressed.shadow_offset = SHADOW_OFFSET_PRESSED
		pressed.shadow_color = SHADOW_COLOR_DEFAULT
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_stylebox_override("hover_pressed", pressed)

		# --- Style désactivé ---
		var disabled := normal.duplicate() as StyleBoxFlat
		disabled.bg_color = Color(MenuTheme.SURFACE.r, MenuTheme.SURFACE.g, MenuTheme.SURFACE.b, 0.5)
		disabled.border_color = MenuTheme.LINE
		disabled.shadow_size = 0
		disabled.shadow_offset = Vector2.ZERO
		btn.add_theme_stylebox_override("disabled", disabled)

	# Couleurs de texte
	if primary:
		btn.add_theme_color_override("font_color", MenuTheme.TEXTE_SUR_PAPIER)
	else:
		btn.add_theme_color_override("font_color",
			texte_de_role(accent) if accent != MenuTheme.ACCENT else MenuTheme.LUMIERE)

	btn.add_theme_color_override("font_hover_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_focus_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_pressed_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_hover_pressed_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_disabled_color", MenuTheme.DIM * 0.70)
	return btn


## Crée un bouton à bascule / sélection d'options (ex: sélection d'arme, résolution).
static func make_choice_button(label: String, accent: Color = MenuTheme.ACCENT,
		group: ButtonGroup = null, font_size: int = Charte.T_COURANT,
		min_size: Vector2 = Vector2(160, 48)) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.button_group = group
	btn.focus_mode = Control.FOCUS_ALL
	btn.custom_minimum_size = min_size

	Charte.appareil(btn, font_size, Charte.POIDS_COURANT)

	if Charte.voxel_actif():
		# **Ici, « enfoncé » veut dire CHOISI** — c'est une bascule, pas une
		# commande. Le bloc reste rentré tant que l'option est celle qui tient,
		# et c'est exactement ce que l'ancien style disait déjà en gardant son
		# ombre courte (`SHADOW_OFFSET_PRESSED`) après le relâchement.
		_poser_les_blocs(btn, accent, false, Charte.GAP_S, 8, true)
	else:
		var normal := StyleBoxFlat.new()
		normal.bg_color = MenuTheme.SURFACE
		normal.set_border_width_all(BORDER_WIDTH_CONTROL)
		normal.border_color = MenuTheme.LINE
		normal.set_corner_radius_all(CORNER_BUTTON)
		normal.shadow_size = 0
		normal.shadow_offset = SHADOW_OFFSET_BUTTON
		normal.shadow_color = SHADOW_COLOR_DEFAULT
		normal.content_margin_left = Charte.GAP_S
		normal.content_margin_right = Charte.GAP_S
		normal.content_margin_top = 8
		normal.content_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", normal)

		var hover := normal.duplicate() as StyleBoxFlat
		hover.border_color = MenuTheme.LUMIERE
		hover.bg_color = accent if accent != MenuTheme.ACCENT else MenuTheme.LUMIERE
		hover.shadow_size = 0
		hover.shadow_offset = SHADOW_OFFSET_BUTTON
		hover.shadow_color = SHADOW_COLOR_DEFAULT
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("focus", hover)

		var pressed := normal.duplicate() as StyleBoxFlat
		pressed.border_color = MenuTheme.LUMIERE
		pressed.bg_color = accent if accent != MenuTheme.ACCENT else MenuTheme.LUMIERE
		pressed.shadow_size = 0
		pressed.shadow_offset = SHADOW_OFFSET_PRESSED
		pressed.shadow_color = SHADOW_COLOR_DEFAULT
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_stylebox_override("hover_pressed", pressed)

		var disabled := normal.duplicate() as StyleBoxFlat
		disabled.bg_color = Color(MenuTheme.SURFACE.r, MenuTheme.SURFACE.g, MenuTheme.SURFACE.b, 0.5)
		disabled.border_color = MenuTheme.LINE * 0.7
		disabled.shadow_size = 0
		disabled.shadow_offset = Vector2.ZERO
		btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_color_override("font_color", texte_second())
	btn.add_theme_color_override("font_hover_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_focus_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_pressed_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_hover_pressed_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_disabled_color", MenuTheme.DIM * 0.6)

	return btn


## Bouton pas-à-pas compact (« ‹ » ou « › ») pour la navigation manette sur sliders.
static func make_step_button(symbol: String, min_size: Vector2 = Vector2(36, 32)) -> Button:
	var btn := Button.new()
	btn.text = symbol
	btn.focus_mode = Control.FOCUS_ALL
	btn.custom_minimum_size = min_size

	Charte.appareil(btn, Charte.T_COURANT, Charte.POIDS_APPUI)

	if Charte.voxel_actif():
		# Le plus petit bloc du jeu : 36×32, dont 18 px de tranches fixes. C'est
		# assez — en dessous, la face du dessus et le rebord se toucheraient et le
		# bouton n'aurait plus de corps à montrer.
		_poser_les_blocs(btn, MenuTheme.LINE, false, 6, 2)
	else:
		var normal := StyleBoxFlat.new()
		normal.bg_color = MenuTheme.SURFACE
		normal.set_border_width_all(BORDER_WIDTH_CONTROL)
		normal.border_color = MenuTheme.LINE
		normal.set_corner_radius_all(CORNER_STEP)
		normal.shadow_size = 0
		normal.shadow_offset = SHADOW_OFFSET_BUTTON
		normal.shadow_color = SHADOW_COLOR_DEFAULT
		normal.content_margin_left = 6
		normal.content_margin_right = 6
		normal.content_margin_top = 2
		normal.content_margin_bottom = 2
		btn.add_theme_stylebox_override("normal", normal)

		var hover := normal.duplicate() as StyleBoxFlat
		hover.border_color = MenuTheme.LUMIERE
		hover.bg_color = MenuTheme.LUMIERE
		hover.shadow_size = 0
		hover.shadow_offset = SHADOW_OFFSET_BUTTON
		hover.shadow_color = SHADOW_COLOR_DEFAULT
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("focus", hover)

		var pressed := hover.duplicate() as StyleBoxFlat
		pressed.bg_color = MenuTheme.LUMIERE
		pressed.border_color = MenuTheme.LUMIERE
		pressed.shadow_size = 0
		pressed.shadow_offset = SHADOW_OFFSET_PRESSED
		pressed.shadow_color = SHADOW_COLOR_DEFAULT
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_stylebox_override("hover_pressed", pressed)

	btn.add_theme_color_override("font_color", MenuTheme.LUMIERE)
	btn.add_theme_color_override("font_hover_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_focus_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_pressed_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_hover_pressed_color", MenuTheme.TEXTE_SUR_PAPIER)

	return btn

# =============================================================================
# SLIDERS & RÉGLAGES
# =============================================================================

## Style pour le rail d'un HSlider.
static func slider_track_style(color: Color = MenuTheme.LINE) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(0)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


## Style pour la zone remplie d'un HSlider.
static func slider_fill_style(color: Color = MenuTheme.FILAMENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(0)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


## Crée un HSlider stylé (non focusable pour réserver la manette aux boutons ‹ ›).
static func make_slider(min_val: float, max_val: float, step: float,
		width: float = 200.0, accent: Color = MenuTheme.FILAMENT) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.custom_minimum_size = Vector2(width, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.add_theme_stylebox_override("slider", slider_track_style())
	slider.add_theme_stylebox_override("grabber_area", slider_fill_style(accent))
	slider.add_theme_stylebox_override("grabber_area_highlight", slider_fill_style(MenuTheme.LUMIERE))
	return slider

# =============================================================================
# LE BLOC — la plaque en relief de l'habillage voxel
# =============================================================================
#
# **Tout l'habillage voxel passe par ici, et c'est voulu.** `Charte.voxel_actif()`
# n'est lu que dans ce fichier : les deux cents sites qui demandent un style
# demandent la même chose qu'avant et reçoivent une plaque de bloc ou un aplat
# d'encre selon `--charte=`. Un `if` par site d'appel aurait fait deux habillages
# à maintenir — la faute que `network_manager.gd` évite pour le transport.
#
# Une plaque est une image en NEUF TRANCHES (`StyleBoxTexture`) : les quatre
# coins gardent leur taille, les bords s'étirent le long d'un axe, le centre se
# répète. C'est ce qui donne à un bouton de 36 px et à un panneau de 600 px la
# même face du dessus, les mêmes flancs et la même arête — sans un seul shader,
# et en gardant les plaques dans un même lot de dessin puisqu'elles partagent
# leur texture.

## Les quatre états d'un bloc : deux lumières croisées avec deux positions.
##
## - `REPOS` — dans l'ombre, sorti : l'état de presque tout.
## - `ALLUME` — sous la torche, sorti : ce qu'on survole, ce qui engage.
## - `ENFONCE` — sous la torche, rentré : ce qu'on est en train d'appuyer.
## - `RENTRE` — dans l'ombre, rentré : ce qui **reste** choisi sans être touché.
##
## `ENFONCE` n'est pas `ALLUME` assombri : sa face du dessus est passée à l'ombre,
## le reste est resté sous la torche. Et `RENTRE` n'est pas `ENFONCE` éteint : il
## porte une plaque à lui, parce qu'une entrée choisie doit rester lisible sous un
## libellé qui, lui, ne change pas de couleur.
enum Bloc { REPOS, ALLUME, ENFONCE, RENTRE, EFFLEURE }

const CHEMINS_DE_PLAQUE := {
	Bloc.REPOS: Charte.CHEMIN_VOXEL_PLAQUE,
	Bloc.ALLUME: Charte.CHEMIN_VOXEL_PLAQUE_ALLUMEE,
	Bloc.ENFONCE: Charte.CHEMIN_VOXEL_PLAQUE_ENFONCEE,
	Bloc.RENTRE: Charte.CHEMIN_VOXEL_PLAQUE_RENTREE,
	Bloc.EFFLEURE: Charte.CHEMIN_VOXEL_PLAQUE_EFFLEUREE,
}

## Les états où la lumière touche le bloc. Elle y porte la couleur du rôle
## presque en entier ; dans l'ombre, la matière domine et le rôle n'est qu'une
## teinte. C'est la seule chose qui sépare « choisi » de « posé là ».
const ETATS_ECLAIRES := [Bloc.ALLUME, Bloc.ENFONCE, Bloc.EFFLEURE]

## La valeur qui veut dire « la teinte que l'état donne », par opposition à une
## teinte imposée par l'appelant. Un bloc transparent n'a aucun autre sens :
## personne ne demande une plaque invisible.
const TEINTE_AUTO := Color.TRANSPARENT

static var _plaques: Dictionary = {}


## La texture d'un état, chargée au premier appel et gardée.
##
## ⚠️ **Le fichier manquant CRIE.** Sans lui, `StyleBoxTexture` dessine… rien :
## pas de plaque, pas de bordure, et pas la moindre erreur — les menus
## deviendraient des colonnes de texte flottant sur le noir. Même famille de
## piège que le grain de la pâte et que les textures du voile.
static func plaque(etat: int) -> Texture2D:
	if _plaques.has(etat):
		return _plaques[etat]
	var chemin: String = CHEMINS_DE_PLAQUE.get(etat, "")
	var tex: Texture2D = null
	if ResourceLoader.exists(chemin):
		tex = load(chemin) as Texture2D
	if tex == null:
		push_error("bloc d'interface : plaque absente — %s" % chemin)
	_plaques[etat] = tex
	return tex


## La couleur qui éclaire une plaque : son état, teinté par le rôle.
##
## **Un bloc de joueur 1 n'est pas un bloc bleu, c'est un bloc éclairé en bleu.**
## La matière ne porte jamais la couleur — elle n'est qu'un facteur —, donc le
## rôle entre par la lumière, à hauteur de `Charte.VOXEL_TEINTE_ROLE`. Un accent
## neutre (le filet, l'accent d'interface) ne teinte rien : il ne désigne personne.
static func teinte_de_bloc(accent: Color, etat: int, fond: Color = TEINTE_AUTO) -> Color:
	var eclaire := etat in ETATS_ECLAIRES
	var base: Color = fond
	if base == TEINTE_AUTO:
		base = Charte.VOXEL_ALLUME if eclaire else Charte.VOXEL_PLAQUE
	if accent == MenuTheme.LINE or accent == MenuTheme.ACCENT:
		return base
	# **Un bloc éclairé prend la couleur de la LUMIÈRE qui l'éclaire** ; un bloc à
	# l'ombre n'en reçoit qu'une teinte. Sans cet écart, la classe choisie de J1
	# virait au gris cerné de bleu et le bouton qui lance au plâtre beige : dans un
	# duel à deux curseurs, ce qui est choisi et ce qui lance doivent se voir
	# d'abord (revue de la session cloud, 2026-09-23).
	var part := Charte.VOXEL_TEINTE_ROLE_ALLUME if eclaire else Charte.VOXEL_TEINTE_ROLE
	var teinte := base.lerp(accent, part)
	# L'opacité appartient à l'état, pas au rôle : un panneau de joueur 2 laisse
	# voir le monde derrière lui autant qu'un panneau neutre.
	teinte.a = base.a
	return teinte


## Le texte secondaire, à la clarté que la surface sous lui exige.
##
## Un rôle de texte n'est pas une couleur, c'est un contraste tenu sur ce qu'il
## recouvre. L'aplat d'encre de la pâte et le corps de plâtre d'un bloc n'ont pas
## la même clarté, donc le même rôle n'y prend pas la même valeur.
static func texte_second() -> Color:
	return Charte.VOXEL_TEXTE_SECOND if Charte.voxel_actif() else MenuTheme.DIM


## Un rôle ÉCRIT : sa couleur, tirée vers l'halogène le temps qu'il faut pour
## tenir sur le plâtre d'un bloc. Le rôle lui-même ne bouge pas — seul ce qui
## s'écrit avec lui s'éclaircit, et seulement là où il y a un bloc dessous.
static func texte_de_role(role: Color) -> Color:
	if not Charte.voxel_actif():
		return role
	return role.lerp(Charte.HALOGENE, Charte.VOXEL_TEXTE_ROLE_HALO)


## Repeint le RÔLE d'un style déjà posé, quel que soit l'habillage.
##
## Le cadre d'une modale change de registre à chaque ouverture (`show_dialog_message`)
## et le style, lui, ne se refabrique pas. Un aplat porte son rôle sur sa bordure,
## un bloc le porte sur sa lumière : c'est le même geste, et le seul endroit du
## dépôt qui ait besoin de savoir qu'il y en a deux.
static func reteindre(style: StyleBox, accent: Color, etat: int = Bloc.REPOS) -> void:
	if style is StyleBoxFlat:
		(style as StyleBoxFlat).border_color = accent
	elif style is StyleBoxTexture:
		var tex := style as StyleBoxTexture
		var teinte := teinte_de_bloc(accent, etat)
		# L'opacité reste celle que le style s'est donnée : une modale est plus
		# opaque qu'un panneau, et ce n'est pas le registre qui en décide.
		teinte.a = tex.modulate_color.a
		tex.modulate_color = teinte


## Le style d'une plaque de bloc.
static func style_de_bloc(accent: Color = MenuTheme.LINE, etat: int = Bloc.REPOS,
		fond: Color = TEINTE_AUTO) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = plaque(etat)
	box.texture_margin_top = Charte.VOXEL_DESSUS_PX
	box.texture_margin_bottom = Charte.VOXEL_BAS_PX
	box.texture_margin_left = Charte.VOXEL_FLANC_PX
	box.texture_margin_right = Charte.VOXEL_FLANC_PX
	# ⚠️ En TILE et non en STRETCH. Étirée, la pierre d'un panneau large serait
	# quatre fois celle d'un bouton étroit, et la matière cesserait d'être une
	# matière pour devenir un motif propre à chaque boîte.
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.modulate_color = teinte_de_bloc(accent, etat, fond)
	return box


# =============================================================================
# PANNEAUX, CADRES & MODALES
# =============================================================================

## StyleBox standardisé pour un panneau ou une rangée de réglage.
static func make_panel_style(accent: Color = MenuTheme.LINE,
		corner_radius: int = CORNER_PANEL,
		border_width: int = BORDER_WIDTH_PANEL,
		bg_color: Color = MenuTheme.SURFACE,
		etat: int = Bloc.REPOS) -> StyleBox:
	if Charte.voxel_actif():
		# Le rayon et l'épaisseur ne se perdent pas : un bloc n'a ni coin arrondi
		# (ils valent 0 depuis le roman graphique) ni bordure dessinée — son arête
		# d'encre est dans la matière, à la largeur que la charte donne.
		#
		# ⚠️ **`bg_color` n'est pas lu ici, et ce n'est pas un oubli.** Un aplat de
		# fond est une notion de la pâte ; un bloc n'a pas de fond, il a une
		# matière. Ce qui le distingue, c'est la LUMIÈRE qui le touche (`accent`)
		# et son ÉTAT. Un site d'appel qui voulait un fond plus clair au survol
		# demande donc `Bloc.ALLUME`, et les deux habillages le comprennent.
		var bloc := style_de_bloc(accent, etat)
		bloc.content_margin_left = Charte.GAP_M
		bloc.content_margin_right = Charte.GAP_M
		bloc.content_margin_top = Charte.GAP_M
		bloc.content_margin_bottom = Charte.GAP_M
		return bloc
	var box := StyleBoxFlat.new()
	box.bg_color = bg_color
	box.set_border_width_all(border_width)
	box.border_color = accent
	box.set_corner_radius_all(corner_radius)
	box.shadow_size = 0
	box.shadow_offset = SHADOW_OFFSET_PANEL
	box.shadow_color = SHADOW_COLOR_PANEL
	box.content_margin_left = Charte.GAP_M
	box.content_margin_right = Charte.GAP_M
	box.content_margin_top = Charte.GAP_M
	box.content_margin_bottom = Charte.GAP_M
	return box


## StyleBox standardisé pour une fenêtre modale flottante (Choix d'arme, Dialogue).
static func make_modal_style(accent: Color = MenuTheme.ACCENT) -> StyleBox:
	if Charte.voxel_actif():
		# Une modale est un bloc plus opaque que les autres : elle interrompt.
		var teinte := teinte_de_bloc(accent, Bloc.REPOS)
		teinte.a = 0.97
		var bloc := style_de_bloc(accent, Bloc.REPOS, teinte)
		bloc.content_margin_left = Charte.GAP_L
		bloc.content_margin_right = Charte.GAP_L
		bloc.content_margin_top = Charte.GAP_M
		bloc.content_margin_bottom = Charte.GAP_M
		return bloc
	var box := StyleBoxFlat.new()
	box.bg_color = Color(MenuTheme.SURFACE.r, MenuTheme.SURFACE.g, MenuTheme.SURFACE.b, 0.97)
	box.set_border_width_all(BORDER_WIDTH_CONTROL)
	box.border_color = accent
	box.set_corner_radius_all(CORNER_PANEL)
	box.content_margin_left = Charte.GAP_L
	box.content_margin_right = Charte.GAP_L
	box.content_margin_top = Charte.GAP_M
	box.content_margin_bottom = Charte.GAP_M
	box.shadow_size = 0
	box.shadow_offset = SHADOW_OFFSET_MODAL
	box.shadow_color = SHADOW_COLOR_DEFAULT
	return box


## StyleBox pour un champ de saisie LineEdit.
static func make_line_edit_style(focused: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = MenuTheme.SURFACE
	box.set_border_width_all(BORDER_WIDTH_CONTROL)
	box.border_color = MenuTheme.LUMIERE if focused else MenuTheme.LINE
	box.set_corner_radius_all(CORNER_BUTTON)
	box.content_margin_left = Charte.GAP_S
	box.content_margin_right = Charte.GAP_S
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.shadow_size = 0
	if focused:
		box.shadow_offset = SHADOW_OFFSET_BUTTON
		box.shadow_color = SHADOW_COLOR_DEFAULT
	else:
		box.shadow_offset = Vector2.ZERO
	return box


# =============================================================================
# TRAMES D'ENCRAGE & HACHURES (« ROMAN GRAPHIQUE BRUTALISTE » - ÉTAPE 2)
# =============================================================================

## Crée une surface de trame / hachures autonome.
static func make_hatch_rect(preset: int = MenuHatchRect.PatternMode.CROSS,
		accent: Color = MenuTheme.LINE) -> MenuHatchRect:
	var h := MenuHatchRect.new()
	h.pattern_mode = preset
	h.color_ink = MenuTheme.SURFACE
	h.color_line = accent
	return h


## Crée un panneau texturé de hachures (fond inactif, encart technique ou case de BD).
static func make_hatch_panel(accent: Color = MenuTheme.LINE,
		pattern_mode: int = MenuHatchRect.PatternMode.CROSS,
		density: float = 0.35) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := make_panel_style(accent, CORNER_PANEL, BORDER_WIDTH_PANEL, Color(MenuTheme.SURFACE.r, MenuTheme.SURFACE.g, MenuTheme.SURFACE.b, 0.40))
	panel.add_theme_stylebox_override("panel", style)

	var hatch := MenuHatchRect.new()
	hatch.pattern_mode = pattern_mode
	hatch.color_ink = Color(MenuTheme.SURFACE.r, MenuTheme.SURFACE.g, MenuTheme.SURFACE.b, 0.90)
	hatch.color_line = accent * 0.75
	hatch.spacing = 12.0
	hatch.density = density
	hatch.roughness = 0.20
	hatch.border_width = 0.0
	hatch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hatch.show_behind_parent = true
	panel.add_child(hatch)

	return panel


## Crée une fenêtre modale habillée de trames d'encrage.
static func make_hatch_modal(accent: Color = MenuTheme.ACCENT) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := make_modal_style(accent)
	panel.add_theme_stylebox_override("panel", style)

	var hatch := MenuHatchRect.new()
	hatch.pattern_mode = MenuHatchRect.PatternMode.SINGLE_45
	hatch.color_ink = Color(MenuTheme.SURFACE.r, MenuTheme.SURFACE.g, MenuTheme.SURFACE.b, 0.96)
	hatch.color_line = Color(accent.r, accent.g, accent.b, 0.15)
	hatch.spacing = 14.0
	hatch.density = 0.25
	hatch.roughness = 0.10
	hatch.border_width = 0.0
	hatch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hatch.show_behind_parent = true
	panel.add_child(hatch)

	return panel
