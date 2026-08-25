class_name MenuHub
extends Control

## Hub de navigation en deux panneaux — Phase 5, structure B.
##
## À gauche la liste des entrées, à droite ce que l'entrée sous le curseur
## raconte. Ce n'est pas une décoration : cela permet à une entrée de **montrer
## une information sans faire descendre d'un cran**. « Top 10 » n'ouvre pas un
## sous-menu, il remplit le panneau de droite. Un menu qui obligerait à entrer
## puis à ressortir pour lire trois lignes ferait payer un aller-retour pour une
## consultation.
##
## Trois natures d'entrée, et la différence se voit à l'œil :
##
## - **destination** — porte un chevron, descend d'un cran ;
## - **information** — pas de chevron, remplit le panneau de droite ;
## - **action** — pas de chevron, émet un signal (lancer, quitter).
##
## Une entrée d'information peut porter du **texte** ou un **panneau** — une
## galerie de vignettes, une grille de touches, un salon. C'est la même nature :
## « ceci se regarde à droite, sans descendre d'un cran ». Le hub a longtemps su
## attacher un panneau à un écran seulement ; « CHANGER DE CARTE » ouvrait donc un
## sous-menu pour montrer des vignettes, c'est-à-dire faisait payer un aller-retour
## pour ce que la place de droite pouvait afficher tout de suite.
##
## Une entrée peut être **indisponible** : elle reste visible, grisée, et le
## panneau de droite dit pourquoi. La masquer laisserait croire qu'elle n'existe
## pas ; la retirer du parcours du curseur ferait douter du bouton d'à côté.
##
## ## Le retour est un bouton, pas un rappel de touche
##
## La version précédente affichait « ÉCHAP · RETOUR » sans que rien ne soit
## cliquable — et sans que la touche fasse quoi que ce soit. Un libellé qui
## annonce une commande inexistante est pire qu'une absence de libellé. Le retour
## est donc une entrée comme les autres, en bas de chaque liste, atteignable au
## curseur et à la souris ; la touche le double, elle ne le remplace pas.

## Émis après chaque changement d'écran, retours compris.
signal screen_changed(id: String)
## Tentative de retour depuis l'accueil. À l'appelant d'en décider.
signal back_at_root()
## Une entrée d'action a été activée.
signal action_requested(action: String)
## Ce que l'entrée sous le curseur raconte. L'en-tête du jeu l'affiche : c'est le
## seul endroit où le regard passe déjà.
signal detail_changed(title: String, text: String)
## Le panneau de droite a changé. Ce qui s'y affiche peut engager plus que du
## texte — la calibration y règle un point de noir sur un champ mesuré — et
## l'appelant doit pouvoir réagir à sa venue comme à son départ.
signal panel_changed(key: String)

const ROOT := "accueil"

## Le panneau de texte intégré, celui que [method montrer_texte] remplit.
##
## Réservé : `register_panel()` refuse une clé déjà prise, donc personne ne peut
## le remplacer par mégarde. Il vit au même rang que les panneaux confiés de
## l'extérieur — c'est ce qui garantit qu'afficher du texte **éteint** le panneau
## précédent, au lieu de s'empiler dessus.
const PANNEAU_TEXTE := "texte"

## Marque les entrées « lanceur » — le geste qui engage une partie.
##
## Depuis le 2026-08-18, le lanceur n'a **plus de style plein** : sa couleur se
## confondait avec le liseré des curseurs, qui est peint des mêmes teintes. Il se
## reconnaît maintenant à son libellé en gras. Cette marque est donc le SEUL
## moyen de le retrouver au code — c'est par elle que M8 sait où tirer, et
## l'oublier sur une nouvelle entrée la rendrait muette sans rien casser de
## visible.
const META_LAUNCHER := "menu_launcher"

## Racine de chaque écran : c'est elle qu'on montre et qu'on cache.
var _roots: Dictionary = {}
## Colonne de gauche de chaque écran, à remplir par l'appelant.
var _lists: Dictionary = {}
## Texte de droite par défaut de chaque écran.
var _asides: Dictionary = {}
var _titles: Dictionary = {}

## Panneaux riches du panneau de droite, par clé. Tous vivent dans `_detail_host`,
## tous cachés sauf au plus un.
var _panels: Dictionary = {}
## Clé du panneau montré quand aucune entrée n'en réclame un autre, par écran.
var _screen_panels: Dictionary = {}
## Ce qui est montré en ce moment. Sans cette mémoire, chaque déplacement du
## curseur rejouerait `visible = …` sur tous les panneaux : une galerie de
## vignettes qui se cache et se remontre à chaque cran scintille.
var _shown_panel: String = ""

## Ce que chaque entrée raconte, retenu à sa création : bouton → titre, texte,
## panneau.
##
## Les deux curseurs du jeu sont maison — ils dessinent un liseré, ils
## n'appellent pas `grab_focus()`. `focus_entered` ne se déclenche donc **jamais**
## à la manette ni au clavier, et sans ce registre le panneau de droite ne
## suivrait que la souris : la galerie de cartes resterait invisible à qui joue
## au pad, c'est-à-dire à peu près tout le monde.
var _entry_details: Dictionary = {}

## Les deux apparences de chaque entrée : au repos, et sélectionnée.
##
## **Elles se posent à la main parce que la stylebox `focus` de Godot ne peut pas
## faire ce travail ici.** Le style « sélectionné » y avait été mis, et rempli par
## `focus_entered` — or les deux curseurs du jeu sont maison : ils dessinent un
## liseré et n'appellent jamais `grab_focus()`. Conséquence, relevée par Adrien à
## l'écran le 2026-08-24 : **à la manette et au clavier, aucune entrée n'était
## jamais peinte**, de toute une session ; et à la souris, l'ambre restait collé
## sur le dernier bouton cliqué même quand la sélection avait changé ailleurs.
##
## Le commentaire du code affirmait pourtant « la sélection est franche ». Il
## décrivait une intention, pas un fait — c'est le piège déjà consigné deux fois
## dans la feuille de route, et il a fallu une capture d'écran pour le voir.
##
## Le relais `reveal_entry()` avait été posé le 2026-08-18 pour la même raison, et
## il n'avait alimenté que le CADRE DE DROITE. La moitié du décrochage était
## corrigée, l'autre non.
var _entry_styles: Dictionary = {}

## Chemin courant. Jamais vide : `ROOT` en est le fond.
var _stack: PackedStringArray = PackedStringArray([ROOT])

var _title_label: Label
var _detail_host: VBoxContainer
var _detail_title: Label
var _detail_text: RichTextLabel
## Le panneau de texte, celui que [method montrer_texte] remplit.
var _texte_panneau: VBoxContainer
var _tween: Tween

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var columns := HBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation", MenuTheme.GAP_L)
	add_child(columns)

	# --- Colonne de gauche : le titre et les écrans empilés -------------------
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_theme_constant_override("separation", MenuTheme.GAP_S)
	columns.add_child(left)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", MenuTheme.T_TITRE)
	_title_label.add_theme_color_override("font_color", MenuTheme.GOLD)
	left.add_child(_title_label)

	# Les racines d'écran sont ancrées en plein cadre pour pouvoir glisser
	# latéralement sans perturber la mise en page.
	var host := Control.new()
	host.custom_minimum_size = Vector2(0, 420)
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.clip_contents = true
	left.add_child(host)
	_host = host

	# Dernier enfant de `_host`, donc dessinée par-dessus les colonnes : un
	# ménisque passant sous les entrées qu'il allume ne s'expliquerait pas.
	_ink = MenuInk.new()
	host.add_child(_ink)

	# --- Colonne de droite : ce que l'entrée sous le curseur raconte ----------
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = MenuTheme.SURFACE
	style.set_border_width_all(1)
	style.border_color = MenuTheme.LINE
	style.set_corner_radius_all(12)
	style.content_margin_left = MenuTheme.GAP_M
	style.content_margin_right = MenuTheme.GAP_M
	style.content_margin_top = MenuTheme.GAP_M
	style.content_margin_bottom = MenuTheme.GAP_M
	right.add_theme_stylebox_override("panel", style)
	columns.add_child(right)
	_right = right

	# Aligné en haut : un contenu centré verticalement saute d'un écran à l'autre
	# selon sa hauteur, et le regard doit le rattraper à chaque fois.
	_detail_host = VBoxContainer.new()
	_detail_host.alignment = BoxContainer.ALIGNMENT_BEGIN
	_detail_host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_detail_host.add_theme_constant_override("separation", MenuTheme.GAP_S)
	right.add_child(_detail_host)

	# ⚠️ **DA4.18 — ces deux `Control` ont passé des semaines cachés, à recevoir
	# du texte que personne ne voyait.**
	#
	# La décision d'origine était bonne : la description d'une entrée est montée
	# dans l'en-tête, sous le titre, parce que *lire l'explication d'une entrée ne
	# devrait pas demander de traverser l'écran du regard*. Ce qu'elle n'a pas
	# prévu, c'est qu'en retirant la description on ne laissait **rien** à la
	# place — et que `show_detail()` continuait d'écrire ici, dans le vide.
	#
	# Deux entrées le promettaient pourtant **au joueur, en toutes lettres** :
	# « MON RANG — affichés à droite », « TOP 10 — affiché à droite, sans quitter
	# cet écran ». On cliquait, la phrase promettait, il ne se passait rien.
	#
	# **Le remède n'est pas de les rallumer** — la description reviendrait alors à
	# deux endroits à la fois, ce que la décision d'origine évitait à juste titre.
	# Le remède est d'en faire **un panneau comme les autres**, avec sa clé, que
	# seul un appelant qui veut vraiment remplir le cadre demande, par un verbe qui
	# le dit : [method montrer_texte].
	_texte_panneau = VBoxContainer.new()
	_texte_panneau.name = "PanneauTexte"
	_texte_panneau.add_theme_constant_override("separation", MenuTheme.GAP_XS)

	_detail_title = Label.new()
	Charte.appareil(_detail_title, MenuTheme.T_APPUI)
	_detail_title.add_theme_color_override("font_color", MenuTheme.GOLD)
	_texte_panneau.add_child(_detail_title)

	_detail_text = RichTextLabel.new()
	_detail_text.bbcode_enabled = true
	_detail_text.fit_content = true
	# Sans cette largeur, un `RichTextLabel` posé dans un panneau caché naît à
	# **un pixel** de large et n'en ressort jamais : mesuré à `(1.0, 1296.0)` au
	# moment du diagnostic. Le texte existait, il était rendu sur une colonne d'un
	# pixel — ce qui aurait ressemblé à « le cadre est vide » même une fois visible.
	_detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_text.custom_minimum_size = Vector2(0, Charte.GAP_XL)
	_detail_text.add_theme_font_size_override("normal_font_size", MenuTheme.T_COURANT)
	_detail_text.add_theme_color_override("default_color", MenuTheme.DIM)
	_texte_panneau.add_child(_detail_text)

	register_panel(PANNEAU_TEXTE, _texte_panneau)

var _host: Control
var _right: PanelContainer

## M6 — l'encre qui écrit l'écran entrant. Vit dans `_host`, donc clippée comme
## les colonnes qu'elle balaie.
var _ink: MenuInk
## Hauteur globale du dernier geste d'entrée, d'où part l'encre. Négatif = « on
## ne sait pas d'où », ce qui arrive au premier affichage et après `reset()`.
var _geste_y: float = -1.0

# ---------------------------------------------------------------------------
# DÉCLARATION
# ---------------------------------------------------------------------------

## Déclare un écran et rend sa colonne de gauche, à remplir par l'appelant.
##
## Attention : `body_of()` rend la **racine** de l'écran — celle qu'on montre et
## qu'on cache — et non cette colonne. Les deux sont distinctes depuis le passage
## en deux panneaux.
func add_screen(id: String, title: String) -> VBoxContainer:
	_titles[id] = title
	if _lists.has(id):
		return _lists[id]

	var root := HBoxContainer.new()
	root.name = "Screen_" + id
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.hide()
	_host.add_child(root)

	var list := VBoxContainer.new()
	list.alignment = BoxContainer.ALIGNMENT_BEGIN
	list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", MenuTheme.GAP_XS)
	root.add_child(list)

	_roots[id] = root
	_lists[id] = list
	return list

## Texte de droite montré quand aucune entrée n'a de contenu propre.
func set_aside(id: String, title: String, text: String) -> void:
	_asides[id] = {"titre": title, "texte": text}

## Confie un affichage riche au panneau de droite, sous une clé. Le hub en devient
## le seul propriétaire : il l'ajoute, le cache, et décide quand il se montre.
##
## Un même panneau peut servir plusieurs écrans et plusieurs entrées — le salon
## sert les cinq écrans de préparation. C'est même la raison de la clé : un nœud
## n'a qu'un parent, donc « le même panneau à deux endroits » ne peut être qu'un
## seul nœud désigné deux fois.
func register_panel(key: String, content: Control) -> void:
	if key == "" or content == null or _panels.has(key):
		return
	content.hide()
	_panels[key] = content
	_detail_host.add_child(content)

## Le panneau enregistré sous cette clé, ou `null`.
##
## **Existe pour que personne n'ait à compter les enfants de `detail_host()`.**
## Les bancs le faisaient — `get_children()[2]`, `[3]` — et l'arrivée d'un panneau
## intégré ([constant PANNEAU_TEXTE]) les a tous décalés d'un cran. Ils sont
## sortis avec **deux erreurs de script et un code 0** : seul le grep de
## `run_suites.sh` les a attrapés. Une position n'est pas une identité.
func panneau(key: String) -> Control:
	return _panels.get(key, null)

## Panneau montré à l'entrée dans un écran, tant qu'aucune entrée ne parle.
func set_screen_panel(id: String, key: String) -> void:
	_screen_panels[id] = key

## Le panneau par défaut d'un écran, ou une chaîne vide s'il n'en a pas.
##
## Existe pour qu'un appelant puisse poser un défaut **sans écraser** celui d'un
## écran qui en a déjà un : le lit d'ambiance de DA4.18 ne doit remplir que les
## cadres réellement vides, jamais prendre la place du salon ou de la galerie.
func screen_panel(id: String) -> String:
	return String(_screen_panels.get(id, ""))

## Montre un panneau sans passer par le survol d'une entrée.
func show_panel(key: String) -> void:
	_apply_panel(key)

func has_screen(id: String) -> bool:
	return _lists.has(id)

func body_of(id: String) -> Control:
	return _roots.get(id, null)

func list_of(id: String) -> VBoxContainer:
	return _lists.get(id, null)

# ---------------------------------------------------------------------------
# NAVIGATION
# ---------------------------------------------------------------------------

func current_id() -> String:
	return _stack[_stack.size() - 1]

func depth() -> int:
	return _stack.size() - 1

## Écran d'où l'on vient. Vide à l'accueil.
##
## Un écran atteint par deux chemins n'est pas le même selon le chemin — c'est
## exactement le cas de la recherche d'adversaire, qui sert la file amicale et la
## file classée. La pile porte déjà la réponse ; la recopier dans une variable
## d'état créerait une seconde vérité à tenir d'accord avec la première.
func parent_id() -> String:
	return _stack[_stack.size() - 2] if _stack.size() >= 2 else ""

func push(id: String) -> bool:
	if not _lists.has(id) or id == current_id():
		return false
	_stack.append(id)
	_apply(1.0)
	return true

func back() -> bool:
	if _stack.size() <= 1:
		back_at_root.emit()
		return false
	_stack.remove_at(_stack.size() - 1)
	_apply(-1.0)
	return true

func reset() -> void:
	_stack = PackedStringArray([ROOT])
	_apply(0.0)

func _apply(direction: float) -> void:
	var id := current_id()
	for key in _roots.keys():
		var root: Control = _roots[key]
		if root != null and key != id:
			root.hide()

	var target: Control = _roots.get(id, null)
	if target == null:
		return
	target.show()

	_title_label.text = String(_titles.get(id, id)).to_upper()
	# La sélection ne survit pas au changement d'écran : elle désignerait une
	# entrée d'un autre écran, et le cadre montrerait ce qu'on vient de quitter.
	# **On l'éteint avant de l'oublier** — sinon elle reste allumée derrière soi,
	# et l'écran d'à côté garde une entrée choisie qui ne commande plus rien.
	_peindre(_selected_entry, false)
	_selected_entry = null
	_show_aside(id)

	if direction != 0.0:
		_slide(target, direction)
	else:
		_reset_transform(target)

	screen_changed.emit(id)

func _slide(body: Control, direction: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	var offset := MenuTheme.SLIDE * direction
	body.modulate.a = 0.0
	body.offset_left = offset
	body.offset_right = offset

	# La traversée d'écran prend la courbe d'ENTRÉE de la charte — la même que
	# tout ce qui arrive à l'écran dans ce jeu. Elle remplace un `TRANS_CUBIC`
	# choisi ici et nulle part ailleurs : c'est ce genre de réglage local, répété
	# cinq fois avec cinq valeurs différentes, qui fait qu'un jeu paraît « tweené »
	# plutôt qu'animé.
	_tween = create_tween()
	_tween.set_parallel(true)
	MenuTheme.C.animer(_tween, body, "modulate:a", 0.0, 1.0, MenuTheme.FADE,
		MenuTheme.C.Courbe.ENTREE)
	MenuTheme.C.animer(_tween, body, "offset_left", offset, 0.0, MenuTheme.FADE,
		MenuTheme.C.Courbe.ENTREE)
	MenuTheme.C.animer(_tween, body, "offset_right", offset, 0.0, MenuTheme.FADE,
		MenuTheme.C.Courbe.ENTREE)

	# L'encre est un second animateur, pas un remplaçant : le glissement reste ce
	# qu'il était, l'encre ne touche qu'aux alphas des entrées et à son ménisque.
	#
	# **Et elle ne coule QUE sur un geste connu.** Sans doigt posé, il n'y a pas
	# de lumière à faire couler — mais surtout, une navigation appelée par du code
	# accompagne presque toujours l'ouverture du menu, et M10 est alors en train
	# d'allumer le panneau qui contient cette colonne. Deux effets qui animent des
	# `modulate` imbriqués sur les mêmes pixels ne se composent pas : ils se
	# marchent dessus, et ça se voit comme un défaut d'affichage. Ils ont chacun
	# leur domaine — M10 la traversée arène ↔ menu, M6 la navigation à l'intérieur.
	if _ink != null and _geste_y >= 0.0:
		_host.move_child(_ink, -1)
		_ink.couler(list_of(current_id()), _geste_y, MenuTheme.P1)
	_geste_y = -1.0

func _reset_transform(body: Control) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	body.modulate.a = 1.0
	body.offset_left = 0.0
	body.offset_right = 0.0

# ---------------------------------------------------------------------------
# PANNEAU DE DROITE
# ---------------------------------------------------------------------------

## L'entrée qui commande le cadre de droite. Le survol la laisse intacte.
var _selected_entry: Button = null

## Sélectionner : le cadre suit, l'entrée s'allume, et les deux **restent**
## jusqu'à la prochaine sélection.
func _select_entry(btn: Button) -> void:
	if _selected_entry == btn:
		_show_entry(btn)
		return
	_peindre(_selected_entry, false)
	_selected_entry = btn
	_peindre(btn, true)
	_show_entry(btn)


## Pose l'une des deux apparences d'une entrée.
##
## `normal` ET `hover` : sans le second, promener la souris sur l'entrée
## sélectionnée la ferait **régresser** vers la lueur de survol, c'est-à-dire
## paraître moins choisie au moment où on la vise.
func _peindre(btn: Button, choisie: bool) -> void:
	if not is_instance_valid(btn) or btn.disabled:
		return
	var s: Variant = _entry_styles.get(btn, null)
	if not s is Dictionary:
		return
	var jeu: Dictionary = s
	var cle := "choisie" if choisie else "repos"
	btn.add_theme_stylebox_override("normal", jeu[cle])
	btn.add_theme_stylebox_override("hover", jeu["choisie"] if choisie else jeu["survol"])

## Survoler : le cadre montre, sans que le choix bouge.
func _preview_entry(btn: Button) -> void:
	_show_entry(btn)

## La souris s'en va : on remet ce que la sélection commandait. Retomber sur le
## défaut de l'écran effacerait un choix que le joueur vient de faire.
func _restore_selection() -> void:
	if is_instance_valid(_selected_entry):
		_show_entry(_selected_entry)
	else:
		_show_aside(current_id())

func _show_entry(btn: Button) -> void:
	var d: Variant = _entry_details.get(btn, null)
	if not d is Dictionary:
		return
	var e: Dictionary = d
	show_detail(String(e.get("titre", "")), String(e.get("texte", "")),
		String(e.get("panneau", "")))

## Contenu par défaut de l'écran courant : ce qu'on lit quand rien n'est survolé.
func _show_aside(id: String) -> void:
	var a: Variant = _asides.get(id, null)
	if a is Dictionary:
		show_detail(String((a as Dictionary)["titre"]), String((a as Dictionary)["texte"]))
	else:
		show_detail(String(_titles.get(id, "")), "")

## Ce que raconte l'entrée sous le curseur. **Alimente l'en-tête, pas le cadre.**
##
## ⚠️ **Le nom ment un peu, et il ment depuis longtemps** — « detail » laisse
## croire que cette fonction remplit le panneau de droite. Elle ne le fait pas :
## la description part par `detail_changed` vers l'en-tête, sous le titre, et
## seule la clé `panel` décide de ce que le cadre montre.
##
## C'est ce malentendu qui a coûté DA4.18 : deux appelants passaient ici du texte
## destiné au cadre, il partait dans l'en-tête — où il était aussitôt écrasé par
## la description suivante — et le cadre restait noir. Pour remplir le cadre avec
## du texte, c'est [method montrer_texte].
func show_detail(title: String, text: String, panel: String = "") -> void:
	_apply_panel(panel)
	detail_changed.emit(title, text)


## Remplit le CADRE DE DROITE avec un titre et un texte, et le montre.
##
## Le verbe dit ce qu'il fait, et c'est tout l'intérêt : le cadre est le plus
## grand rectangle de l'interface, y écrire doit se demander explicitement. Un
## appelant qui veut seulement expliquer une entrée passe par [method show_detail]
## et son texte va sous le titre.
##
## Le texte accepte le bbcode — `_detail_text` est un `RichTextLabel` — et un
## titre vide efface simplement la ligne de titre.
func montrer_texte(title: String, text: String) -> void:
	_detail_title.text = title
	_detail_title.visible = title.strip_edges() != ""
	_detail_text.text = text
	_apply_panel(PANNEAU_TEXTE)

## Montre un panneau et un seul. Une clé vide ne veut pas dire « rien » mais
## « ce que l'écran montre par défaut » : sans ce repli, survoler une entrée sans
## panneau viderait la droite, et le salon disparaîtrait dès que le curseur se
## pose sur « PRÊT ».
## Le panneau actuellement montré, ou une chaîne vide.
func shown_panel() -> String:
	return _shown_panel

func _apply_panel(key: String) -> void:
	var wanted := key if key != "" else String(_screen_panels.get(current_id(), ""))
	if wanted == _shown_panel:
		return
	_shown_panel = wanted
	for k in _panels.keys():
		var content: Control = _panels[k]
		if content != null:
			content.visible = k == wanted
	panel_changed.emit(wanted)

## Rend le panneau de droite pour qu'un appelant y installe un affichage riche
## (un tableau, une liste). À utiliser avec parcimonie : le texte suffit presque
## toujours, et un panneau qui se reconstruit à chaque déplacement du curseur
## scintille.
## L'encre coulée, pour que l'interface lui passe l'intensité réglée par le
## joueur. Le hub en est propriétaire : elle est née avec ses colonnes.
func ink() -> MenuInk:
	return _ink

## Retient d'où part la prochaine coulée : le centre du bouton qu'on vient
## d'activer, en coordonnées globales.
##
## Public, parce que toutes les navigations ne passent pas par un bouton : Échap
## et les gâchettes remontent d'un cran sans qu'on ait rien pressé. Ce sont bien
## des gestes du joueur, et l'encre doit couler pour eux aussi — l'interface leur
## dit d'où, puisqu'elle seule sait où le curseur se trouvait.
func noter_geste(btn: Control) -> void:
	if btn != null and is_instance_valid(btn):
		_geste_y = btn.get_global_rect().get_center().y

## Le cadre de droite lui-même, pour qui veut poser une matière dessus (M14).
## Son contenu appartient au hub ; sa surface est une affaire de rendu.
func right_panel() -> PanelContainer:
	return _right

func detail_host() -> VBoxContainer:
	return _detail_host

# ---------------------------------------------------------------------------
# ENTRÉES
# ---------------------------------------------------------------------------

## Une entrée de la colonne de gauche.
##
## `target` non vide en fait une destination ; sinon `action` en fait une action ;
## sinon c'est une entrée d'information, qui ne fait que remplir la droite.
## `reason` non vide la rend indisponible : visible, grisée, et le panneau de
## droite dit pourquoi.
## `launcher` marque le geste qui engage une partie — lancer, chercher, se
## déclarer prêt ; **pas** quitter, qui n'engage aucune partie :
## le libellé passe en gras. Il ne teinte plus le fond ni le cadre au repos —
## `accent` y est aussi la couleur d'un des deux curseurs (`MenuTheme.P1` /
## `MenuTheme.P2`), et un bouton déjà bordé de cette teinte se confondait avec
## le liseré de sélection qui l'entoure quand un joueur s'y arrête vraiment.
## Le chevron reste la seule marque de couleur qui compte : il dit « ceci ouvre
## un écran », son absence dit « ceci s'active sur place ».
## `panel` désigne un affichage riche confié à `register_panel()` : l'entrée le
## fait apparaître à droite au lieu de descendre d'un cran.
func make_entry(label: String, detail: String, target: String = "",
		accent: Color = MenuTheme.P1, action: String = "",
		reason: String = "", launcher: bool = false,
		panel: String = "") -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 54)
	btn.focus_mode = Control.FOCUS_ALL
	btn.disabled = reason != ""

	var normal := StyleBoxFlat.new()
	normal.bg_color = MenuTheme.SURFACE
	normal.set_border_width_all(1)
	normal.border_color = MenuTheme.LINE
	normal.set_corner_radius_all(10)
	normal.content_margin_left = MenuTheme.GAP_S
	normal.content_margin_right = MenuTheme.GAP_S
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("disabled", normal)

	# ## Un rôle, une couleur (arbitrage d'Adrien, 2026-08-24)
	#
	# **Le survol et la sélection ne portaient pas des états, ils portaient des
	# SUJETS.** Chaque entrée teintait ses deux styles avec son propre accent :
	# rien que sur l'accueil, quatre couleurs — bleu pour les modes, ambre pour le
	# compétitif, gris pour les réglages, rouge pour quitter. Survoler le
	# compétitif donnait donc de l'ambre et survoler sa voisine du bleu pâle sur
	# du noir, c'est-à-dire presque rien. « Ambre » ne voulait pas dire
	# « sélectionné », il voulait dire « cette entrée-là est dorée ».
	#
	# Et les deux états ne différaient que par l'opacité — 6 % contre 12 % — et un
	# pixel de bordure. À la souris, indiscernables.
	#
	# Trois signaux, trois couleurs, et elles ne dépendent plus du sujet :
	#   · **acier** — le curseur de la souris passe ici ;
	#   · **ambre** — c'est cette entrée que le cadre de droite montre ;
	#   · **bleu / rouge** — le liseré d'un des deux curseurs du jeu.
	#
	# L'accent propre à l'entrée survit là où il dit quelque chose de vrai : le
	# chevron. Le compétitif reste doré et QUITTER rouge, sans que ça déteigne sur
	# la lecture de l'état.
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Color(MenuTheme.ACCENT, 0.55)
	hover.bg_color = Color(MenuTheme.ACCENT, 0.07)
	btn.add_theme_stylebox_override("hover", hover)

	# L'apparence de l'entrée SÉLECTIONNÉE — celle qui commande le cadre de droite.
	#
	# **Discrète, et voulue telle** (arbitrage d'Adrien, 2026-08-24) : bleu autour,
	# ambre dedans.
	#
	# C'est la BORDURE qui identifie — deux pixels d'ambre plein, lisibles d'un
	# coup d'œil dans une colonne — et le fond ne fait que réchauffer. Un premier
	# essai à un quart d'opacité donnait un aplat : l'entrée cessait d'être choisie
	# pour devenir un bouton d'une autre couleur, et le libellé y perdait son
	# contraste. À un huitième, l'ambre se voit sans couvrir, et le liseré bleu du
	# curseur reste le premier lu — ce qu'il doit être, puisqu'il dit où l'on est.
	var choisie := normal.duplicate() as StyleBoxFlat
	choisie.border_color = MenuTheme.GOLD
	choisie.set_border_width_all(2)
	choisie.bg_color = Color(MenuTheme.GOLD, 0.12)
	_entry_styles[btn] = {"repos": normal, "survol": hover, "choisie": choisie}

	# **Le focus de Godot ne peint plus rien**, et c'est le correctif du défaut
	# qu'Adrien a vu : il portait l'apparence choisie, en plus de la peinture
	# explicite de `_peindre()`. Deux mécanismes pour un même signal, sur deux
	# déclencheurs différents — un clic donne le focus Godot, qui survit à la
	# sélection suivante. Une entrée s'allumait donc sans être choisie, et se
	# rallumait au survol.
	#
	# La sélection est désormais peinte à un seul endroit. Le focus de Godot n'est
	# de toute façon pas le curseur du joueur : le jeu a les siens, qui dessinent
	# leur liseré par-dessus.
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_stylebox_override("focus_hover", hover)
	# L'appui, lui, montre déjà ce que l'entrée est sur le point de devenir.
	btn.add_theme_stylebox_override("pressed", choisie)
	btn.add_theme_stylebox_override("hover_pressed", choisie)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,
		Control.PRESET_MODE_MINSIZE, MenuTheme.GAP_S)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)

	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", MenuTheme.T_APPUI)
	lbl.add_theme_color_override("font_color",
		MenuTheme.DIM if btn.disabled else MenuTheme.LUMIERE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Le gras remplace la couleur pour marquer un geste qui engage : la couleur
	# est réservée aux deux curseurs, un accent posé ici s'y confondrait au repos.
	if launcher and not btn.disabled:
		var bold_font := FontVariation.new()
		bold_font.base_font = ThemeDB.fallback_font
		bold_font.variation_embolden = 1.2
		lbl.add_theme_font_override("font", bold_font)
	row.add_child(lbl)

	# Le chevron distingue « on descend » de « ça s'affiche à droite ». Sans lui,
	# le joueur ne sait pas si activer l'entrée va le déplacer.
	if target != "" and not btn.disabled:
		var chevron := Label.new()
		chevron.text = "›"
		chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chevron.add_theme_font_size_override("font_size", MenuTheme.T_TITRE)
		chevron.add_theme_color_override("font_color", accent)
		chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chevron)
	elif btn.disabled:
		var lock := Label.new()
		lock.text = "—"
		lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock.add_theme_font_size_override("font_size", MenuTheme.T_COURANT)
		lock.add_theme_color_override("font_color", MenuTheme.DIM)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lock)

	# Le panneau de droite suit le curseur ET la souris : c'est le même geste de
	# « je regarde ceci », quel que soit le périphérique.
	var texte := reason if btn.disabled else detail
	var titre := label
	# Une entrée indisponible n'emmène nulle part, panneau compris : montrer la
	# galerie sous une entrée grisée laisserait croire qu'elle est utilisable.
	var vitrine := "" if btn.disabled else panel
	_entry_details[btn] = {"titre": titre, "texte": texte, "panneau": vitrine}
	# **La sélection fige, le survol ne fait que passer.** Deux gestes distincts
	# pour deux intentions distinctes : on choisit avec le curseur — manette ou
	# clavier — et on regarde avec la souris. Sans cette distinction, promener la
	# souris effaçait ce qu'on venait de sélectionner, et le cadre de droite ne
	# répondait plus qu'au dernier mouvement, jamais à la décision.
	btn.focus_entered.connect(func() -> void: _select_entry(btn))
	btn.mouse_entered.connect(func() -> void: _preview_entry(btn))
	# Au départ de la souris, le cadre revient à la sélection — et non au défaut de
	# l'écran, qui effacerait le choix en cours.
	btn.mouse_exited.connect(func() -> void: _restore_selection())

	# M8 lit cette marque pour ne tirer que sur le geste qui engage une partie.
	# Le gras la porte à l'œil, la marque la porte au code : les deux naissent
	# du même paramètre, et rien ne peut les désaccorder.
	if launcher:
		btn.set_meta(META_LAUNCHER, true)

	if btn.disabled:
		return btn
	if target != "":
		btn.pressed.connect(func() -> void:
			noter_geste(btn)
			push(target))
	elif action != "":
		btn.pressed.connect(func() -> void: action_requested.emit(action))
	else:
		# Entrée d'information : activer ne déplace rien, cela remet simplement le
		# panneau de droite sur son contenu.
		btn.pressed.connect(func() -> void: show_detail(titre, texte, vitrine))
	return btn

## Change le libellé d'une entrée déjà construite.
##
## Le texte vit dans un `Label` enfoui sous le bouton, ce qui n'est l'affaire de
## personne au-dehors : une entrée dont le sens change — « PRÊT » qui devient
## « REJOUER » après un match — reste la même entrée, au même endroit, avec le
## même style. La déplacer ou la reconstruire ferait sauter le curseur.
func set_entry_label(btn: Button, text: String) -> void:
	if btn == null:
		return
	for row in btn.get_children():
		for child in row.get_children():
			if child is Label and String((child as Label).text) not in ["›", "—"]:
				(child as Label).text = text
				return

## Fait raconter à l'entrée ce qu'elle raconte, sans passer par le focus de
## Godot. C'est le relais qu'appelle un curseur maison quand il se pose sur elle.
##
## Faux si le contrôle n'est pas une entrée du hub — une vignette de carte, un
## bouton d'arme : le panneau de droite ne doit alors pas bouger, on est en train
## de s'en servir.
func reveal_entry(control: Control) -> bool:
	var d: Variant = _entry_details.get(control, null)
	if not d is Dictionary:
		return false
	# **`_select_entry` et non `show_detail` seul.** Ce relais existe parce que les
	# curseurs maison ne déclenchent pas `focus_entered` ; il alimentait le cadre
	# de droite et **laissait l'entrée non peinte** — donc à la manette, rien ne
	# disait jamais laquelle commandait ce cadre. Parcourir sélectionne, comme le
	# dit le contrat de `make_entry()` : c'est ici qu'il fallait le rendre vrai.
	_select_entry(control as Button)
	return true

## Ajoute le retour en bas d'une liste. À appeler pour **chaque** écran non
## racine : c'est la seule sortie garantie, souris comprise.
##
## Rend le bouton, parce que certains écrans ont plus à faire que remonter d'un
## cran — quitter un salon coupe aussi le lien. L'appelant y branche ce qui le
## concerne ; le retour lui-même reste le même partout.
func add_back_entry(id: String, detail: String = "") -> Button:
	var list := list_of(id)
	if list == null:
		return null
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, MenuTheme.GAP_XS)
	list.add_child(spacer)
	var btn := make_entry("‹  RETOUR",
		detail if detail != "" else "Remonte d'un cran. La touche Échap fait la même chose.",
		"", MenuTheme.DIM)
	btn.pressed.connect(func() -> void:
		noter_geste(btn)
		back())
	list.add_child(btn)
	return btn
