class_name MenuArene
extends Control

## DA4.18 — **la carte sous la torche.** Le lit d'ambiance du cadre de droite.
##
## Le plus grand rectangle de l'interface était noir : sur le menu principal,
## aucune entrée n'a de panneau, et rien ne s'y affichait. Ce nœud le remplit avec
## la seule image que ce jeu-ci peut montrer et qu'aucun autre ne peut copier —
## **une arène dans le noir absolu, révélée par une lumière qui passe.**
##
## ## Pourquoi ce contenu-là, et pas une capture d'écran
##
## Une capture est une image morte qui vieillit à chaque changement de carte.
## Ceci est **la carte réellement sélectionnée**, rendue par le même moteur, avec
## les mêmes occluders que le match qui va suivre. C'est donc à la fois un décor
## et une information : on voit le terrain avant de s'engager. Et le jour où
## Adrien dessine une carte, elle apparaît ici sans que personne n'y touche.
##
## ## La règle du dépôt qu'il ne fallait pas enfreindre
##
## `CLAUDE.md` est catégorique : la géométrie produit **toujours ensemble**
## collision et occlusion, depuis les mêmes rectangles fusionnés — sans occluder,
## la lumière traverse les murs et la mécanique centrale disparaît.
##
## Ce panneau n'a que faire des collisions : rien ne s'y déplace. Il aurait donc
## été tentant de dessiner les murs à la main. **On ne le fait pas.** Les
## rectangles dessinés et les occluders sortent du **même appel** à
## `MapGeometry.merge_rects(MapGeometry.build_grid(...))` : deux vues d'une seule
## vérité. Un mur qu'on verrait sans qu'il porte d'ombre serait un mensonge sur la
## mécanique du jeu, affiché en permanence sur l'écran d'accueil.
##
## ## Le coût, et ce qui le borne
##
## Un `SubViewport` qui se redessine à chaque image, parce que la lumière bouge.
## Il est **petit** (la taille du cadre), il ne contient que des `Polygon2D` et
## une `PointLight2D`, et il s'éteint dès qu'il n'est pas visible — un panneau
## caché ne coûte rien. L'effet est déclaré `CONFORT` dans `effect_policy.gd`,
## donc réglable jusqu'à zéro : à zéro, le rendu s'arrête et le cadre reste noir,
## ce qui est exactement l'état d'avant.

const Charte := preload("res://charte.gd")

## Durée d'un aller-retour complet de la lumière, en secondes. Lent, délibérément :
## une lumière qui balaie vite devient un gyrophare et vole l'attention à la
## colonne de gauche, qui est ce qu'on est venu lire.
const CYCLE := 23.0
## Portée de la lumière, **en fraction de la plus grande dimension de la carte**.
##
## ⚠️ **C'était 460 pixels-monde en dur, et c'est la première des trois causes du
## premier rendu raté.** Une portée fixe est juste pour une carte de 700 px et
## fausse pour toutes les autres : sur une grande carte elle donne une lampe de
## poche perdue dans un hangar. La portée d'une lumière d'ambiance se dit par
## rapport à ce qu'elle doit révéler, jamais en valeur absolue — même famille que
## le coefficient de case réglé sur une fonte.
const PORTEE_RELATIVE := 0.62
## Part de la carte que la lumière peut parcourir, en fraction de son étendue.
## Elle reste loin des bords : une lampe qui sort du cadre laisse un écran noir,
## et la moitié du cycle serait perdue.
const COURSE := Vector2(0.26, 0.20)

var _viewport: SubViewport
var _monde: Node2D
var _murs: Node2D
var _lumiere: PointLight2D
var _vue: TextureRect
var _t: float = 0.0
var _intensite: float = 1.0
var _etendue: Rect2 = Rect2()
var _carte_posee: String = ""


func _init() -> void:
	name = "PanneauArene"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	# ⚠️ **Ce nombre est une HAUTEUR, pas un plancher décoratif, et il est le seul
	# du fichier qui ne se déduise de rien.**
	#
	# `_detail_host` est aligné en haut (`SHRINK_BEGIN`) — décision du hub, pour
	# qu'un contenu ne saute pas d'un écran à l'autre selon sa hauteur. Un enfant
	# ne s'y étire donc **pas**, même en `SIZE_EXPAND_FILL` : sa taille est sa
	# taille minimale. Mesuré à la sonde : sans plancher, 0 px de haut, et le cadre
	# reste noir pour une raison qui n'a rien à voir avec le rendu — défaut déjà
	# payé par la galerie de cartes et par l'écran des EFFETS.
	#
	# ⚠️ **CE NOMBRE EST LE DÉFAUT QUI RESTE, et il est mesuré : 500 est demandé,
	# ~330 est obtenu.** Vu à la planche le 2026-08-25 — le panneau n'occupe qu'une
	# bande dans le haut d'un cadre de ~545 px, et le reste du cadre est vide.
	#
	# **La conséquence dépasse la hauteur.** Le cadrage COUVRE (voir `_cadrer()`) :
	# sur un viewport de 860 × 330 et une carte carrée, le facteur est imposé par
	# la largeur, et l'on ne voit plus qu'une **tranche horizontale de 38 % de la
	# carte**. D'où l'impression de zoom, et d'où les bandes sombres — ce sont les
	# murs du bord vus de très près, pas un défaut de lumière.
	#
	# **Ce qu'il faut faire, et pourquoi ce n'est pas une ligne :** `_detail_host`
	# est `SHRINK_BEGIN` (décision du hub, pour qu'un contenu ne saute pas d'un
	# écran à l'autre), donc aucun enfant ne s'y étire — un plancher plus grand ne
	# suffira pas, il faut soit desserrer ce conteneur pour ce panneau, soit le
	# poser sur `hub.right_panel()` en lit de fond plutôt que comme panneau. Le
	# second est probablement le bon : un lit d'ambiance n'est pas un panneau parmi
	# d'autres, il est ce qu'on voit quand aucun panneau ne parle.
	custom_minimum_size = Vector2(0, 500)

	_viewport = SubViewport.new()
	_viewport.name = "Arene"
	# `DISABLED` par défaut : rien ne se rend tant que le panneau n'est pas montré.
	# C'est ce qui rend l'effet gratuit quand il est caché, et il l'est presque
	# toujours — un seul panneau est visible à la fois.
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.transparent_bg = false
	_viewport.disable_3d = true
	# Aucune entrée ne descend là-dedans : c'est une image, pas une scène jouable.
	_viewport.handle_input_locally = false
	_viewport.gui_disable_input = true
	add_child(_viewport)

	_monde = Node2D.new()
	_monde.name = "Monde"
	_viewport.add_child(_monde)

	# Le noir du monde, posé comme dans l'arène : sans lui, un `Polygon2D` se
	# rendrait à pleine couleur et la lumière n'aurait rien à révéler.
	# ⚠️ **`NOIR` pur, et c'était la deuxième cause.** Dans l'arène, le noir absolu
	# EST le jeu : ne rien voir hors de sa torche est la mécanique centrale. Mais
	# ce panneau n'est pas l'arène, c'est un **décor de menu** — et un décor dont
	# 90 % de la surface est un noir mathématique ne décore rien. On voyait une
	# écharde parce qu'il n'y avait rien d'autre à voir.
	#
	# Le sol est donc relevé au ras du visible : assez pour qu'on devine la forme
	# de l'arène, assez peu pour que la torche reste ce qui la RÉVÈLE. C'est la
	# différence entre citer la mécanique et la rejouer.
	var nuit := CanvasModulate.new()
	nuit.color = Charte.NOIR.lerp(Charte.SOL_A, 0.42)
	_monde.add_child(nuit)

	_murs = Node2D.new()
	_murs.name = "Murs"
	_monde.add_child(_murs)

	_lumiere = PointLight2D.new()
	_lumiere.name = "Torche"
	_lumiere.color = Charte.HALOGENE
	_lumiere.energy = 1.15
	_lumiere.shadow_enabled = true
	_lumiere.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	_lumiere.texture = LightTextures.radial(256)
	_monde.add_child(_lumiere)

	_vue = TextureRect.new()
	_vue.name = "Vue"
	_vue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ⚠️ `EXPAND_KEEP_SIZE` est le défaut, et il impose la taille de la texture
	# comme taille MINIMALE du contrôle — piège signalé par DA1 le 2026-08-24,
	# qui a posé 265 px et vu l'écran en afficher 1600.
	_vue.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vue.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_vue)

	visibility_changed.connect(_sur_visibilite)
	resized.connect(_sur_taille)


func _ready() -> void:
	# Les menus tournent arbre en pause : sans cela, la lumière se fige à
	# l'ouverture du menu, c'est-à-dire tout le temps.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	# ⚠️ **Ici et pas dans `_init()`.** Une `ViewportTexture` retient le CHEMIN de
	# son viewport, pas le viewport : demandée avant que l'arbre existe, elle naît
	# avec un chemin invalide et ne se répare jamais — le `TextureRect` reste
	# vide, sans erreur, ce qui ressemble trait pour trait à un rendu qui ne
	# démarre pas.
	_vue.texture = _viewport.get_texture()
	_sur_taille()
	_sur_visibilite()


## Intensité réglée par le joueur (`effect_policy`). À zéro l'effet s'arrête
## vraiment — le viewport cesse de se rendre — au lieu de tourner en transparent.
func set_intensite(valeur: float) -> void:
	_intensite = clampf(valeur, 0.0, 1.0)
	_vue.modulate.a = _intensite
	_sur_visibilite()


## La carte sélectionnée a changé — reconstruire au prochain affichage.
##
## On ne reconstruit pas ici : la sélection change souvent depuis la galerie,
## qui occupe le cadre à ce moment-là. Reconstruire un panneau caché coûterait
## pour rien et, pire, ferait clignoter celui qui est visible s'il partageait
## une ressource.
func rafraichir() -> void:
	_carte_posee = ""
	if is_visible_in_tree():
		_poser_la_carte()


func _sur_visibilite() -> void:
	var vivant := is_visible_in_tree() and _intensite > 0.0
	set_process(vivant)
	if _viewport != null:
		_viewport.render_target_update_mode = (SubViewport.UPDATE_ALWAYS if vivant
			else SubViewport.UPDATE_DISABLED)
	if vivant:
		_poser_la_carte()


func _sur_taille() -> void:
	if _viewport == null:
		return
	var s := size.floor()
	if s.x < 2.0 or s.y < 2.0:
		return
	_viewport.size = Vector2i(s)
	_cadrer()


## Construit la carte sélectionnée, une seule fois par carte.
##
## Reconstruire à chaque affichage ferait clignoter le panneau à chaque
## déplacement du curseur — même défaut que la galerie de vignettes, et c'est la
## raison d'être de la mémoire `_shown_panel` du hub.
func _poser_la_carte() -> void:
	var md := get_node_or_null(^"/root/MapData")
	if md == null:
		return
	var id := String(md.get("selected_map_id"))
	if id == _carte_posee and _murs.get_child_count() > 0:
		return
	var data: Dictionary = md.call("get_selected")
	if data.is_empty():
		return
	_carte_posee = id

	for enfant in _murs.get_children():
		_murs.remove_child(enfant)
		enfant.queue_free()

	# ⚠️ **Un seul appel, deux emplois.** Les rectangles dessinés ci-dessous et les
	# occluders construits juste après sortent de la MÊME fusion : c'est ce qui
	# garantit qu'aucun mur visible ne laisse passer la lumière. Voir la note de
	# tête.
	var tuile := Vector2(CandelaTileSet.TILE_SIZE)
	var rects := MapGeometry.merge_rects(
		MapGeometry.build_grid(data, MapGeometry.Kind.WALLS))

	# ⚠️ **LE SOL D'ABORD, et son absence était le défaut du premier jet.**
	#
	# Premier rendu à l'écran : une écharde de lumière dans une boîte noire. La
	# géométrie était juste — 4 rectangles, 4 occluders, la sonde le disait — et
	# il n'y avait **rien à révéler.** Dans l'arène, ce que la torche montre c'est
	# le SOL ; les murs n'en sont que l'arête. Un panneau qui ne dessine que les
	# murs donne une lampe braquée sur le vide.
	#
	# Pire : `MapGeometry` pose ses occluders avec un retrait de 3 px **à
	# l'intérieur** du rectangle du mur — pour que la face du mur prenne la
	# lumière au lieu d'être dans sa propre ombre. Sans sol, ces 3 px étaient la
	# seule chose éclairée de tout le panneau. C'est exactement l'écharde qu'on
	# voyait.
	#
	# La leçon, et elle vaut au-delà d'ici : **une sonde qui compte les objets ne
	# dit rien de ce qu'ils rendent.** 4 rectangles et 4 occluders, tout était
	# « vert », et l'écran était noir.
	var sol := Polygon2D.new()
	sol.name = "Sol"
	var boite_sol := _etendue_des(rects, tuile)
	sol.polygon = _quad(boite_sol)
	# Le plus sombre des deux sols du damier : on ne dessine pas le damier lui-même
	# — à cette échelle il ferait un moiré — mais on en garde la matière, pour que
	# le sol du menu et celui du jeu soient de la même couleur.
	sol.color = Charte.SOL_A
	_murs.add_child(sol)

	var etendue := Rect2()
	var premier := true
	for r: Rect2i in rects:
		var boite := Rect2(Vector2(r.position) * tuile, Vector2(r.size) * tuile)
		var poly := Polygon2D.new()
		poly.polygon = _quad(boite)
		# La couleur d'une arête éclairée. Le `CanvasModulate` la ramène à zéro
		# partout où la torche n'atteint pas : ce qu'on peint ici, c'est ce que la
		# lumière RÉVÉLERAIT, pas ce qui s'affiche.
		poly.color = Charte.HALOGENE
		_murs.add_child(poly)
		etendue = boite if premier else etendue.merge(boite)
		premier = false

	# Les occluders, depuis les mêmes rectangles. `build_collisions` produit les
	# deux corps et leurs `LightOccluder2D` ; les formes de collision ne coûtent
	# rien ici puisque rien ne se déplace, et les reconstruire à la main aurait
	# rouvert la seule règle que `CLAUDE.md` écrit en majuscules.
	MapGeometry.build_collisions(data, _murs)

	_etendue = etendue
	_cadrer()


## Le quadrilatère d'un rectangle, dans l'ordre horaire.
static func _quad(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		r.position,
		r.position + Vector2(r.size.x, 0.0),
		r.end,
		r.position + Vector2(0.0, r.size.y),
	])


## L'étendue couverte par des rectangles de grille, en pixels-monde.
static func _etendue_des(rects: Array[Rect2i], tuile: Vector2) -> Rect2:
	var out := Rect2()
	var premier := true
	for r: Rect2i in rects:
		var boite := Rect2(Vector2(r.position) * tuile, Vector2(r.size) * tuile)
		out = boite if premier else out.merge(boite)
		premier = false
	return out


## Cadre la caméra du viewport sur l'étendue de la carte, avec une marge.
func _cadrer() -> void:
	if _etendue.size.x <= 0.0 or _etendue.size.y <= 0.0:
		return
	var vue := Vector2(_viewport.size)
	if vue.x < 2.0 or vue.y < 2.0:
		return
	# ⚠️ **`maxf` et non `minf` : on COUVRE, on ne contient pas.**
	#
	# Premier jet en « contenir » : la carte est carrée, le cadre fait trois fois
	# plus large que haut, et le résultat était un petit carré perdu au milieu de
	# deux grandes marges noires — une vignette, pas une fenêtre.
	#
	# Couvrir rogne les bords de la carte, et c'est le bon prix : **ce panneau
	# n'est pas un plan, c'est une vue.** Le plan existe déjà ailleurs, dans la
	# fiche de carte du salon (`map_card`), avec son échelle et ses points
	# d'apparition. Ici on veut la sensation d'être dans le noir avec une lampe,
	# et un diagramme centré ne la donne pas.
	var facteur: float = maxf(vue.x / _etendue.size.x, vue.y / _etendue.size.y)
	_monde.scale = Vector2(facteur, facteur)
	_monde.position = vue * 0.5 - _etendue.get_center() * facteur
	# ⚠️ **Troisième cause du premier rendu : la portée se posait UNE FOIS, à la
	# construction, avant que la carte ne soit connue.** Elle vit ici, où l'on
	# connaît enfin l'étendue — et elle est en pixels-monde, donc la mise à
	# l'échelle du monde s'y applique toute seule.
	var portee: float = maxf(_etendue.size.x, _etendue.size.y) * PORTEE_RELATIVE
	_lumiere.texture_scale = portee / 128.0
	# La portée de la lumière est exprimée en pixels-monde : elle suit donc la
	# mise à l'échelle toute seule, et une grande carte n'est pas révélée par une
	# lampe minuscule.


func _process(delta: float) -> void:
	_t += delta
	if _etendue.size.x <= 0.0:
		return
	# Une figure de Lissajous plutôt qu'un aller-retour : les deux axes ne
	# repassent jamais au même endroit au même moment, si bien que le trajet ne se
	# devine pas. Un balayage périodique évident se lit comme une animation en
	# boucle ; celui-ci se lit comme quelqu'un qui cherche.
	var a := TAU * _t / CYCLE
	var p := Vector2(sin(a), sin(a * 1.618 + 1.1)) * COURSE
	_lumiere.position = _etendue.get_center() + p * _etendue.size
	# La lampe respire très légèrement — un filament, pas une LED.
	_lumiere.energy = 1.15 + 0.07 * sin(a * 3.3)
